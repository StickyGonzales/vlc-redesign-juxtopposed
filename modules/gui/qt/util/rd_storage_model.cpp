/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
#include "rd_storage_model.hpp"

#include <QDir>
#include <QJsonArray>

#include <algorithm>

namespace rdstorage {

namespace {

QString kindName(Kind kind)
{
    return kind == Kind::Movie ? QStringLiteral("movie") : QStringLiteral("show");
}

QString artifactName(ArtifactKind kind)
{
    switch (kind)
    {
    case ArtifactKind::Waveform:
        return QStringLiteral("waveform");
    case ArtifactKind::Download:
        return QStringLiteral("download");
    case ArtifactKind::Picture:
        break;
    }
    return QStringLiteral("picture");
}

ArtifactKind artifactKind(const QString& name)
{
    if (name == QLatin1String("waveform"))
        return ArtifactKind::Waveform;
    if (name == QLatin1String("download"))
        return ArtifactKind::Download;
    return ArtifactKind::Picture;
}

// the same file: the same name and the exact same size
QString identity(const FileId& file)
{
    return file.name + QLatin1Char('\n') + QString::number(file.size);
}

QString joined(const QString& root, const QString& relative)
{
    return relative.isEmpty() ? root : root + QLatin1Char('/') + relative;
}

} // namespace

Presence presenceOf(FileSystem& fs, const QString& path, const QString& volume, QString* volumeNow)
{
    switch (fs.exists(path))
    {
    case FileSystem::Answer::Yes:
    {
        const QString now = fs.volumeOf(path);
        if (volumeNow)
            *volumeNow = now;
        // the same path, on another volume now (another drive took the letter): not this one
        if (!volume.isEmpty() && !now.isEmpty() && now != volume)
            return Presence::Disconnected;
        return Presence::Present;
    }
    case FileSystem::Answer::NoAnswer:
        return Presence::Disconnected;
    case FileSystem::Answer::No:
        break;
    }
    if (volume.isEmpty())
        return Presence::Unchecked;

    // the nearest folder above that exists: on the entry's volume, the folder is gone from it
    QString parent = QDir::cleanPath(QDir::fromNativeSeparators(path));
    for (;;)
    {
        const int slash = parent.lastIndexOf(QLatin1Char('/'));
        if (slash < 0)
            return Presence::Disconnected;
        parent = slash == 0 ? QStringLiteral("/") : parent.left(slash);
        // a drive's root ("E:"): its own root folder
        if (parent.size() == 2 && parent.at(1) == QLatin1Char(':'))
            parent += QLatin1Char('/');
        switch (fs.exists(parent))
        {
        case FileSystem::Answer::NoAnswer:
            return Presence::Disconnected;
        case FileSystem::Answer::Yes:
            return fs.volumeOf(parent) == volume ? Presence::Missing : Presence::Disconnected;
        case FileSystem::Answer::No:
            break;
        }
        if (parent == QLatin1String("/") || parent.endsWith(QLatin1String(":/")))
            return Presence::Disconnected;
    }
}

void Plan::merge(const Plan& other)
{
    for (const QString& file : other.deleteFiles)
        if (!deleteFiles.contains(file))
            deleteFiles.append(file);
    for (const QString& path : other.forgetEntries)
        if (!forgetEntries.contains(path))
            forgetEntries.append(path);
    for (const QString& file : other.unlinkDownloads)
        if (!unlinkDownloads.contains(file))
            unlinkDownloads.append(file);
}

QString Model::key(const QString& path)
{
    QString clean = QDir::cleanPath(QDir::fromNativeSeparators(path));
#ifdef _WIN32
    clean = clean.toLower();
#endif
    return clean;
}

bool Model::under(const QString& pathKey, const QString& rootKey)
{
    if (rootKey.isEmpty())
        return false;
    if (pathKey == rootKey)
        return true;
    return pathKey.startsWith(rootKey.endsWith(QLatin1Char('/')) ? rootKey : rootKey + QLatin1Char('/'));
}

Model Model::fromJson(const QJsonObject& data)
{
    Model model;
    const QJsonObject entries = data.value(QStringLiteral("entries")).toObject();
    for (auto it = entries.begin(); it != entries.end(); ++it)
    {
        const QJsonObject object = it.value().toObject();
        Entry entry;
        entry.kind = object.value(QStringLiteral("kind")).toString() == QLatin1String("movie") ? Kind::Movie : Kind::Show;
        entry.path = object.value(QStringLiteral("path")).toString();
        if (entry.path.isEmpty())
            continue;
        entry.volume = object.value(QStringLiteral("volume")).toString();
        entry.lastPlayed = object.value(QStringLiteral("played")).toInteger();
        entry.missingSince = object.value(QStringLiteral("missing")).toInteger();
        for (const QJsonValue& value : object.value(QStringLiteral("files")).toArray())
        {
            const QJsonObject file = value.toObject();
            FileId id;
            id.name = file.value(QStringLiteral("n")).toString();
            id.relativePath = file.value(QStringLiteral("r")).toString();
            id.size = file.value(QStringLiteral("s")).toInteger(-1);
            if (!id.name.isEmpty() && id.size >= 0)
                entry.files.append(id);
        }
        model.m_entries.insert(key(entry.path), entry);
    }
    const QJsonObject volumes = data.value(QStringLiteral("volumes")).toObject();
    for (auto it = volumes.begin(); it != volumes.end(); ++it)
        model.m_volumes.insert(it.key(), it.value().toInteger());
    const QJsonObject artifacts = data.value(QStringLiteral("artifacts")).toObject();
    for (auto it = artifacts.begin(); it != artifacts.end(); ++it)
    {
        const QJsonObject object = it.value().toObject();
        Artifact artifact;
        artifact.kind = artifactKind(object.value(QStringLiteral("kind")).toString());
        artifact.media = object.value(QStringLiteral("media")).toString();
        artifact.used = object.value(QStringLiteral("used")).toInteger();
        artifact.selected = object.value(QStringLiteral("selected")).toBool();
        model.m_artifacts.insert(it.key(), artifact);
    }
    model.m_lastDaily = data.value(QStringLiteral("lastDaily")).toInteger();
    return model;
}

QJsonObject Model::toJson() const
{
    QJsonObject entries;
    for (auto it = m_entries.cbegin(); it != m_entries.cend(); ++it)
    {
        QJsonObject object;
        object.insert(QStringLiteral("kind"), kindName(it->kind));
        object.insert(QStringLiteral("path"), it->path);
        if (!it->volume.isEmpty())
            object.insert(QStringLiteral("volume"), it->volume);
        if (it->lastPlayed > 0)
            object.insert(QStringLiteral("played"), it->lastPlayed);
        if (it->missingSince > 0)
            object.insert(QStringLiteral("missing"), it->missingSince);
        QJsonArray files;
        for (const FileId& file : it->files)
        {
            QJsonObject id;
            id.insert(QStringLiteral("n"), file.name);
            if (!file.relativePath.isEmpty() && file.relativePath != file.name)
                id.insert(QStringLiteral("r"), file.relativePath);
            id.insert(QStringLiteral("s"), file.size);
            files.append(id);
        }
        if (!files.isEmpty())
            object.insert(QStringLiteral("files"), files);
        entries.insert(it.key(), object);
    }
    QJsonObject volumes;
    for (auto it = m_volumes.cbegin(); it != m_volumes.cend(); ++it)
        volumes.insert(it.key(), it.value());
    QJsonObject artifacts;
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
    {
        QJsonObject object;
        object.insert(QStringLiteral("kind"), artifactName(it->kind));
        object.insert(QStringLiteral("media"), it->media);
        if (it->used > 0)
            object.insert(QStringLiteral("used"), it->used);
        if (it->selected)
            object.insert(QStringLiteral("selected"), true);
        artifacts.insert(it.key(), object);
    }
    QJsonObject root;
    root.insert(QStringLiteral("version"), 1);
    root.insert(QStringLiteral("entries"), entries);
    root.insert(QStringLiteral("volumes"), volumes);
    root.insert(QStringLiteral("artifacts"), artifacts);
    if (m_lastDaily > 0)
        root.insert(QStringLiteral("lastDaily"), m_lastDaily);
    return root;
}

const Entry* Model::entry(const QString& path) const
{
    const auto it = m_entries.constFind(key(path));
    return it != m_entries.constEnd() ? &it.value() : nullptr;
}

bool Model::importLegacy(const QString& path, Kind kind, qint64 lastPlayed)
{
    const QString k = key(path);
    if (path.isEmpty() || m_entries.contains(k))
        return false;
    Entry entry;
    entry.kind = kind;
    entry.path = path;
    entry.lastPlayed = lastPlayed;
    m_entries.insert(k, entry);
    return true;
}

void Model::recordPlay(const Entry& seen, qint64 now)
{
    if (seen.path.isEmpty())
        return;
    Entry& entry = m_entries[key(seen.path)];
    entry.kind = seen.kind;
    entry.path = seen.path;
    if (!seen.volume.isEmpty())
        entry.volume = seen.volume;
    if (!seen.files.isEmpty())
        entry.files = seen.files;
    entry.lastPlayed = now;
    entry.missingSince = 0;
}

std::optional<Match> Model::findMatch(const Entry& seen) const
{
    if (seen.files.isEmpty() || seen.path.isEmpty())
        return std::nullopt;
    const QString seenKey = key(seen.path);

    std::optional<Match> best;
    int bestCount = 0;
    bool bestMissing = false;
    for (auto it = m_entries.cbegin(); it != m_entries.cend(); ++it)
    {
        const Entry& entry = it.value();
        if (it.key() == seenKey || entry.kind != seen.kind || entry.files.isEmpty())
            continue;
        if (seen.kind == Kind::Movie && (entry.files.size() != 1 || seen.files.size() != 1))
            continue;

        QHash<QString, QString> old;
        for (const FileId& file : entry.files)
            old.insert(identity(file), file.relativePath.isEmpty() ? file.name : file.relativePath);

        Match match;
        match.fromKey = it.key();
        match.toPath = seen.path;
        for (const FileId& file : seen.files)
        {
            const auto found = old.constFind(identity(file));
            if (found == old.constEnd())
                continue;
            const QString from = seen.kind == Kind::Movie ? entry.path : joined(entry.path, found.value());
            const QString to = seen.kind == Kind::Movie
                    ? seen.path
                    : joined(seen.path, file.relativePath.isEmpty() ? file.name : file.relativePath);
            match.media.insert(key(from), to);
        }
        const int count = match.media.size();
        if (count < (seen.kind == Kind::Movie ? 1 : kMinShowMatches))
            continue;
        // a folder that is missing is the one that moved; then the most episodes in common
        const bool missing = entry.missingSince > 0;
        if (!best || (missing && !bestMissing) || (missing == bestMissing && count > bestCount))
        {
            best = match;
            bestCount = count;
            bestMissing = missing;
        }
    }
    return best;
}

QVector<Moved> Model::relocate(const Match& match, const Entry& seen, qint64 now)
{
    QVector<Moved> moved;
    const auto found = m_entries.find(match.fromKey);
    if (found == m_entries.end())
        return moved;
    Entry entry = found.value();
    m_entries.erase(found);
    const QString oldRoot = match.fromKey;
    const Kind kind = entry.kind;

    entry.path = seen.path;
    entry.files = seen.files;
    if (!seen.volume.isEmpty())
        entry.volume = seen.volume;
    entry.lastPlayed = now;
    entry.missingSince = 0;
    m_entries.insert(key(seen.path), entry);

    const QString newRoot = key(seen.path);
    for (auto it = m_artifacts.begin(); it != m_artifacts.end(); ++it)
    {
        QString newMedia;
        QString newPath;
        const auto mapped = match.media.constFind(it->media);
        if (mapped != match.media.constEnd())
        {
            newMedia = key(mapped.value());
            newPath = mapped.value();
        }
        else if (kind == Kind::Show && under(it->media, oldRoot))
            // a video of the show whose file did not match (not there any more): the same place
            // in the new folder
            newMedia = newRoot + it->media.mid(oldRoot.size());
        if (newMedia.isEmpty() || newMedia == it->media)
            continue;
        it->media = newMedia;
        moved.append({ it.key(), it->kind, newMedia, newPath });
    }
    return moved;
}

void Model::renameArtifact(const QString& from, const QString& to)
{
    const auto found = m_artifacts.find(from);
    if (found == m_artifacts.end() || from == to)
        return;
    const Artifact artifact = found.value();
    m_artifacts.erase(found);
    m_artifacts.insert(to, artifact);
}

QStringList Model::artifactsOf(const QString& media, ArtifactKind kind) const
{
    QStringList files;
    const QString mediaKey = key(media);
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
        if (it->kind == kind && it->media == mediaKey)
            files.append(it.key());
    return files;
}

void Model::markConnected(const QSet<QString>& volumes, qint64 now)
{
    for (const QString& volume : volumes)
        if (!volume.isEmpty())
            m_volumes.insert(volume, now);
}

void Model::addArtifact(const QString& file, ArtifactKind kind, const QString& media, qint64 now)
{
    if (file.isEmpty())
        return;
    Artifact& artifact = m_artifacts[file];
    artifact.kind = kind;
    artifact.media = key(media);
    artifact.used = now;
}

void Model::markSelected(const QString& file, qint64 now)
{
    const auto it = m_artifacts.find(file);
    if (it == m_artifacts.end() || it->kind != ArtifactKind::Download)
        return;
    it->selected = true;
    it->used = now;
}

bool Model::belongs(const Artifact& artifact, const QString& entryKey, const Entry& entry) const
{
    return entry.kind == Kind::Movie ? artifact.media == entryKey : under(artifact.media, entryKey);
}

Plan Model::forget(const QString& entryKey)
{
    Plan plan;
    const auto found = m_entries.find(entryKey);
    if (found == m_entries.end())
        return plan;
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
    {
        if (!belongs(it.value(), entryKey, found.value()))
            continue;
        plan.deleteFiles.append(it.key());
        if (it->kind == ArtifactKind::Download)
            plan.unlinkDownloads.append(it.key());
    }
    plan.forgetEntries.append(found->path);
    m_entries.erase(found);
    return plan;
}

Plan Model::dropRebuildable(const QString& entryKey)
{
    Plan plan;
    const auto found = m_entries.constFind(entryKey);
    if (found == m_entries.constEnd())
        return plan;
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
        if (it->kind != ArtifactKind::Download && belongs(it.value(), entryKey, found.value()))
            plan.deleteFiles.append(it.key());
    return plan;
}

Plan Model::daily(qint64 now, Probe& probe, const QSet<QString>& connected)
{
    Plan plan;
    markConnected(connected, now);

    const QStringList keys = m_entries.keys();
    for (const QString& entryKey : keys)
    {
        const auto found = m_entries.find(entryKey);
        if (found == m_entries.end())
            continue;
        Entry& entry = found.value();

        // its drive is one Cone read this session: the folder itself is looked at
        if (!entry.volume.isEmpty() && connected.contains(entry.volume))
        {
            QString volumeNow;
            const Presence presence = probe.presence(entry.path, entry.volume, &volumeNow);
            if (presence == Presence::Present)
                entry.missingSince = 0;
            else if (presence == Presence::Missing)
            {
                if (entry.missingSince <= 0)
                    entry.missingSince = now;
                else if (now - entry.missingSince >= kMissingDays * kDayMs)
                    plan.merge(forget(entryKey));
            }
            continue;
        }

        // saved before the volumes: seen where it was, its volume is known from now on
        if (entry.volume.isEmpty())
        {
            QString volumeNow;
            if (probe.presence(entry.path, QString(), &volumeNow) == Presence::Present && !volumeNow.isEmpty())
            {
                entry.volume = volumeNow;
                entry.missingSince = 0;
                continue;
            }
        }

        // its drive is not there (or not known): from the last time it was connected or played
        const qint64 since = std::max(entry.volume.isEmpty() ? 0 : m_volumes.value(entry.volume, 0), entry.lastPlayed);
        if (since <= 0)
        {
            entry.lastPlayed = now;
            continue;
        }
        const qint64 idle = now - since;
        if (idle >= kForgetDays * kDayMs)
            plan.merge(forget(entryKey));
        else if (idle >= kDriveGoneDays * kDayMs)
            plan.merge(dropRebuildable(entryKey));
    }

    // downloaded subtitles not used for 30 days, wherever their video is
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
    {
        if (it->kind != ArtifactKind::Download || now - it->used < kSubtitleUnusedDays * kDayMs)
            continue;
        plan.deleteFiles.append(it.key());
        plan.unlinkDownloads.append(it.key());
    }

    m_lastDaily = now;
    return plan;
}

Plan Model::closed(const QString& media)
{
    Plan plan;
    const QString mediaKey = key(media);
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
    {
        if (it->kind != ArtifactKind::Download || it->selected || it->media != mediaKey)
            continue;
        plan.deleteFiles.append(it.key());
        plan.unlinkDownloads.append(it.key());
    }
    return plan;
}

Plan Model::caps(const QVector<QPair<QString, qint64>>& pictures) const
{
    Plan plan;
    QVector<QPair<QString, qint64>> sorted = pictures;
    std::sort(sorted.begin(), sorted.end(), [](const auto& a, const auto& b) { return a.second > b.second; });
    for (qsizetype i = kPictureCap; i < sorted.size(); ++i)
        plan.deleteFiles.append(sorted.at(i).first);

    QVector<QPair<QString, qint64>> downloads;
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
        if (it->kind == ArtifactKind::Download)
            downloads.append({ it.key(), it->used });
    std::sort(downloads.begin(), downloads.end(), [](const auto& a, const auto& b) { return a.second > b.second; });
    for (qsizetype i = kDownloadCap; i < downloads.size(); ++i)
    {
        plan.deleteFiles.append(downloads.at(i).first);
        plan.unlinkDownloads.append(downloads.at(i).first);
    }
    return plan;
}

Plan Model::forgetAll(const QStringList& pictures, const QStringList& downloads)
{
    Plan plan;
    plan.deleteFiles = pictures;
    for (const QString& file : downloads)
    {
        if (!plan.deleteFiles.contains(file))
            plan.deleteFiles.append(file);
        plan.unlinkDownloads.append(file);
    }
    for (auto it = m_artifacts.cbegin(); it != m_artifacts.cend(); ++it)
    {
        if (it->kind == ArtifactKind::Waveform || plan.deleteFiles.contains(it.key()))
            continue;
        plan.deleteFiles.append(it.key());
        if (it->kind == ArtifactKind::Download)
            plan.unlinkDownloads.append(it.key());
    }
    // the shows' own data goes with Up Next's Forget all; their fingerprints with it
    for (auto it = m_entries.begin(); it != m_entries.end();)
    {
        if (it->kind == Kind::Show)
            it = m_entries.erase(it);
        else
            ++it;
    }
    return plan;
}

void Model::applied(const Plan& plan)
{
    for (const QString& file : plan.deleteFiles)
        m_artifacts.remove(file);
}

} // namespace rdstorage
