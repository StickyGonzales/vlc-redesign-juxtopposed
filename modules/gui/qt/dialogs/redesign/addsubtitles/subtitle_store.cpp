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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "subtitle_store.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QSet>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_url.h>

namespace {

const QString filesKey = QStringLiteral("files");
const QString foldersKey = QStringLiteral("folders");

QString localPath(const QString& mrl)
{
    if (!mrl.startsWith(QLatin1String("file:"), Qt::CaseInsensitive))
        return {};
    char* path = vlc_uri2path(mrl.toUtf8().constData());
    if (!path)
        return {};
    QString result = QDir::cleanPath(QDir::fromNativeSeparators(QString::fromUtf8(path)));
    free(path);
#ifdef _WIN32
    // Windows paths do not tell case apart
    result = result.toLower();
#endif
    return result;
}

// a local path as the store keys it (mediaKey of its MRL)
QString pathKey(const QString& path)
{
    QString clean = QDir::cleanPath(QDir::fromNativeSeparators(path));
#ifdef _WIN32
    clean = clean.toLower();
#endif
    return clean;
}

bool isUnder(const QString& key, const QString& root)
{
    return !root.isEmpty() && (key == root || key.startsWith(root + QLatin1Char('/')));
}

} // namespace

QString SubtitleStore::filePath()
{
    char* dir = config_GetUserDir(VLC_USERDATA_DIR);
    if (!dir)
        return {};
    const QString path = QString::fromUtf8(dir) + QStringLiteral("/rd-subtitles.json");
    free(dir);
    return path;
}

QJsonObject SubtitleStore::read()
{
    QFile file(filePath());
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

bool SubtitleStore::write(const QJsonObject& data)
{
    const QString path = filePath();
    if (path.isEmpty())
        return false;
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(QJsonDocument(data).toJson(QJsonDocument::Indented));
    return file.commit();
}

QString SubtitleStore::mediaKey(const QString& mrl)
{
    const QString path = localPath(mrl);
    return path.isEmpty() ? mrl : path;
}

QString SubtitleStore::folderKey(const QString& mrl)
{
    const QString path = localPath(mrl);
    if (path.isEmpty())
        return {};
    return QFileInfo(path).path();
}

QStringList SubtitleStore::subtitlesFor(const QString& mrl) const
{
    const QJsonObject entry = m_data.value(filesKey).toObject().value(mediaKey(mrl)).toObject();
    QStringList subtitles;
    for (const QJsonValue& value : entry.value(QStringLiteral("subtitles")).toArray())
        subtitles.append(value.toString());
    return subtitles;
}

void SubtitleStore::setSubtitles(const QString& mrl, const QStringList& subtitles)
{
    QJsonObject files = m_data.value(filesKey).toObject();
    if (subtitles.isEmpty())
        files.remove(mediaKey(mrl));
    else
        files.insert(mediaKey(mrl), QJsonObject { { QStringLiteral("subtitles"), QJsonArray::fromStringList(subtitles) } });
    m_data.insert(filesKey, files);
}

SubtitleStore::Rule SubtitleStore::ruleFor(const QString& folderKey) const
{
    Rule rule;
    if (folderKey.isEmpty())
        return rule;
    const QJsonValue value = m_data.value(foldersKey).toObject().value(folderKey);
    if (!value.isObject())
        return rule;
    const QJsonObject entry = value.toObject();
    rule.valid = true;
    rule.source = entry.value(QStringLiteral("source")).toString() == QLatin1String("opensubtitles")
                  ? OpenSubtitles : Computer;
    rule.path = entry.value(QStringLiteral("path")).toString();
    rule.query = entry.value(QStringLiteral("query")).toString();
    rule.language = entry.value(QStringLiteral("language")).toString();
    for (const QJsonValue& word : entry.value(QStringLiteral("variant")).toArray())
        rule.variant.append(word.toString());
    return rule;
}

void SubtitleStore::setRule(const QString& folderKey, const Rule& rule)
{
    if (folderKey.isEmpty())
        return;
    QJsonObject folders = m_data.value(foldersKey).toObject();
    folders.insert(folderKey, QJsonObject {
        { QStringLiteral("source"), rule.source == OpenSubtitles ? QStringLiteral("opensubtitles")
                                                                 : QStringLiteral("computer") },
        { QStringLiteral("path"), rule.path },
        { QStringLiteral("query"), rule.query },
        { QStringLiteral("language"), rule.language },
        { QStringLiteral("variant"), QJsonArray::fromStringList(rule.variant) }
    });
    m_data.insert(foldersKey, folders);
}

bool SubtitleStore::relocate(const QString& oldRoot, const QString& newRoot, const QHash<QString, QString>& media)
{
    const QString from = pathKey(oldRoot);
    const QString to = pathKey(newRoot);
    if (from.isEmpty() || to.isEmpty() || from == to)
        return false;
    bool changed = false;

    QJsonObject files = m_data.value(filesKey).toObject();
    QJsonObject movedFiles;
    for (auto it = files.begin(); it != files.end();)
    {
        QString target;
        const auto mapped = media.constFind(it.key());
        if (mapped != media.constEnd())
            target = pathKey(mapped.value());
        else if (isUnder(it.key(), from))
            target = to + it.key().mid(from.size());
        if (target.isEmpty() || target == it.key())
        {
            ++it;
            continue;
        }
        movedFiles.insert(target, it.value());
        it = files.erase(it);
        changed = true;
    }
    for (auto it = movedFiles.begin(); it != movedFiles.end(); ++it)
        files.insert(it.key(), it.value());

    QJsonObject folders = m_data.value(foldersKey).toObject();
    QJsonObject movedFolders;
    for (auto it = folders.begin(); it != folders.end();)
    {
        if (!isUnder(it.key(), from))
        {
            ++it;
            continue;
        }
        QJsonObject rule = it.value().toObject();
        // subtitles kept inside the show's folder moved with it
        const QString path = rule.value(QStringLiteral("path")).toString();
        if (!path.isEmpty() && isUnder(pathKey(path), from))
            rule.insert(QStringLiteral("path"), QString(newRoot + pathKey(path).mid(from.size())));
        movedFolders.insert(to + it.key().mid(from.size()), rule);
        it = folders.erase(it);
        changed = true;
    }
    for (auto it = movedFolders.begin(); it != movedFolders.end(); ++it)
        folders.insert(it.key(), it.value());

    if (changed)
    {
        m_data.insert(filesKey, files);
        m_data.insert(foldersKey, folders);
    }
    return changed;
}

bool SubtitleStore::forgetUnder(const QString& root)
{
    const QString key = pathKey(root);
    bool changed = false;
    QJsonObject files = m_data.value(filesKey).toObject();
    for (auto it = files.begin(); it != files.end();)
    {
        if (isUnder(it.key(), key))
        {
            it = files.erase(it);
            changed = true;
        }
        else
            ++it;
    }
    QJsonObject folders = m_data.value(foldersKey).toObject();
    for (auto it = folders.begin(); it != folders.end();)
    {
        if (isUnder(it.key(), key))
        {
            it = folders.erase(it);
            changed = true;
        }
        else
            ++it;
    }
    if (changed)
    {
        m_data.insert(filesKey, files);
        m_data.insert(foldersKey, folders);
    }
    return changed;
}

bool SubtitleStore::unlink(const QStringList& removed)
{
    QSet<QString> keys;
    for (const QString& file : removed)
        keys.insert(pathKey(file));
    bool changed = false;
    QJsonObject files = m_data.value(filesKey).toObject();
    for (auto it = files.begin(); it != files.end();)
    {
        QJsonObject entry = it.value().toObject();
        QJsonArray kept;
        bool dropped = false;
        for (const QJsonValue& value : entry.value(QStringLiteral("subtitles")).toArray())
        {
            if (keys.contains(pathKey(value.toString())))
                dropped = true;
            else
                kept.append(value);
        }
        if (!dropped)
        {
            ++it;
            continue;
        }
        changed = true;
        if (kept.isEmpty())
        {
            it = files.erase(it);
            continue;
        }
        entry.insert(QStringLiteral("subtitles"), kept);
        it.value() = entry;
        ++it;
    }
    if (changed)
        m_data.insert(filesKey, files);
    return changed;
}

QHash<QString, QString> SubtitleStore::downloadOwners(const QString& downloadsDir) const
{
    QHash<QString, QString> owners;
    const QString dir = pathKey(downloadsDir);
    const QJsonObject files = m_data.value(filesKey).toObject();
    for (auto it = files.begin(); it != files.end(); ++it)
        for (const QJsonValue& value : it.value().toObject().value(QStringLiteral("subtitles")).toArray())
        {
            const QString file = value.toString();
            if (isUnder(pathKey(file), dir))
                owners.insert(file, it.key());
        }
    return owners;
}
