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

#include "rd_storage.hpp"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QPointer>
#include <QSaveFile>

#include <cstring>
#include <memory>

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_player.h>
#include <vlc_url.h>

#ifdef _WIN32
# include <windows.h>
#endif

#include "qt.hpp"
#include "player/input_models.hpp"
#include "player/player_controller.hpp"
#include "util/rd_background_queue.hpp"
#include "util/rd_volume.hpp"

using namespace rdstorage;

namespace {

RdStorage* g_storage = nullptr;

// how long a drive may take to answer before it counts as not there
constexpr int kDriveTimeoutMs = 2000;
// the daily check is due at most once a day; looked at every hour while Cone is open
constexpr int kDailyLookMs = 3600 * 1000;
// a change is written this long after the last one
constexpr int kSaveDelayMs = 2000;

QString userDir(vlc_userdir_t type, const QString& name)
{
    char* dir = config_GetUserDir(type);
    if (!dir)
        return {};
    const QString path = QString::fromUtf8(dir) + QLatin1Char('/') + name;
    free(dir);
    return path;
}

QString storePath()
{
    return userDir(VLC_USERDATA_DIR, QStringLiteral("rd-storage.json"));
}

qint64 now()
{
    return QDateTime::currentMSecsSinceEpoch();
}

// the daily check's answers, asked on the queue's thread beforehand
class CachedProbe : public Probe
{
public:
    explicit CachedProbe(const QHash<QString, QPair<Presence, QString>>& answers) : m_answers(answers) {}
    Presence presence(const QString& path, const QString&, QString* volumeNow) override
    {
        const auto found = m_answers.constFind(Model::key(path));
        if (found == m_answers.constEnd())
            return Presence::Unchecked;
        if (volumeNow)
            *volumeNow = found->second;
        return found->first;
    }

private:
    QHash<QString, QPair<Presence, QString>> m_answers;
};

// a path on a drive Cone read this session: its mount point (from the mount table, the drive
// is not touched) is one of theirs. "/" holds only what no other mount point holds
bool onSessionDrive(const QString& path, const QStringList& roots)
{
    const QString root = Model::key(rdvolume::mountRootOf(path));
    if (root.isEmpty())
        return false;
    for (const QString& sessionRoot : roots)
        if (Model::key(sessionRoot) == root)
            return true;
    return false;
}

QVector<QPair<QString, qint64>> listFiles(const QString& dir, const QStringList& filters)
{
    QVector<QPair<QString, qint64>> files;
    if (dir.isEmpty())
        return files;
    for (const QFileInfo& info : QDir(dir).entryInfoList(filters, QDir::Files))
        files.append({ info.absoluteFilePath(), info.lastModified().toMSecsSinceEpoch() });
    return files;
}

QStringList pathsOf(const QVector<QPair<QString, qint64>>& files)
{
    QStringList paths;
    for (const auto& file : files)
        paths.append(file.first);
    return paths;
}

QString localPathOf(const char* uri)
{
    if (!uri || std::strncmp(uri, "file:", 5) != 0)
        return {};
    char* path = vlc_uri2path(uri);
    if (!path)
        return {};
    const QString result = QString::fromUtf8(path);
    free(path);
    return result;
}

} // namespace

RdStorage::RdStorage(qt_intf_t* intf, PlayerController* player, QObject* parent)
    : QObject(parent)
    , m_intf(intf)
    , m_player(player)
{
    g_storage = this;
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(kSaveDelayMs);
    connect(&m_saveTimer, &QTimer::timeout, this, &RdStorage::save);

    // the daily check: looked at every hour, first once the queue's first minute is over
    m_dailyTimer.setInterval(kDailyLookMs);
    connect(&m_dailyTimer, &QTimer::timeout, this, &RdStorage::dailyTick);
    m_dailyTimer.start();
    QTimer::singleShot(RdBackgroundQueue::kStartupDelayMs + 5000, this, &RdStorage::dailyTick);

    connect(m_player, &PlayerController::inputChanged, this, &RdStorage::onInputChanged);
    TrackListModel* subtitles = m_player->getSubtitleTracks();
    connect(subtitles, &QAbstractItemModel::dataChanged, this, &RdStorage::checkSelectedDownload);
    connect(subtitles, &QAbstractItemModel::rowsInserted, this, &RdStorage::checkSelectedDownload);
    connect(subtitles, &QAbstractItemModel::modelReset, this, &RdStorage::checkSelectedDownload);

    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (!queue)
        return;
    auto data = std::make_shared<QJsonObject>();
    auto system = std::make_shared<QVector<rdvolume::Info>>();
    QPointer<RdStorage> self(this);
    queue->post(QStringLiteral("storage load"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent,
        [data, system](const std::shared_ptr<RdBackgroundQueue::Control>&) {
            QFile file(storePath());
            if (file.open(QIODevice::ReadOnly))
                *data = QJsonDocument::fromJson(file.readAll()).object();
            // the system drive always counts as read: where Cone's data and the home folder are
            system->append(rdvolume::volumeOf(QDir::homePath(), kDriveTimeoutMs));
            system->append(rdvolume::volumeOf(QFileInfo(storePath()).absolutePath(), kDriveTimeoutMs));
        },
        [self, data, system]() {
            if (!self)
                return;
            self->m_model = Model::fromJson(*data);
            for (const rdvolume::Info& info : *system)
            {
                if (info.id.isEmpty())
                    continue;
                self->m_sessionVolumes.insert(info.id);
                if (!info.root.isEmpty() && !self->m_sessionRoots.contains(info.root))
                    self->m_sessionRoots.append(info.root);
            }
            self->m_loaded = true;
            const QVector<std::function<void()>> waiting = std::move(self->m_beforeLoad);
            self->m_beforeLoad.clear();
            for (const auto& action : waiting)
                action();
        });
}

RdStorage* RdStorage::instance()
{
    return g_storage;
}

RdStorage::~RdStorage()
{
    if (g_storage == this)
        g_storage = nullptr;
    // a change not written yet (the timer waits, or its save job was dropped by the queue's
    // stop): written now, a small file
    if (m_loaded && m_changes != m_savedChanges)
    {
        const QString path = storePath();
        QDir().mkpath(QFileInfo(path).absolutePath());
        QSaveFile file(path);
        if (file.open(QIODevice::WriteOnly))
        {
            file.write(QJsonDocument(m_model.toJson()).toJson(QJsonDocument::Compact));
            file.commit();
        }
    }
}

QString RdStorage::picturesDir()
{
    return userDir(VLC_CACHE_DIR, QStringLiteral("up-next"));
}

QString RdStorage::waveformsDir()
{
    return userDir(VLC_USERDATA_DIR, QStringLiteral("waveforms"));
}

QString RdStorage::downloadsDir()
{
    return userDir(VLC_USERDATA_DIR, QStringLiteral("subtitles/opensubtitles"));
}

QString RdStorage::pictureFile(const QString& videoPath)
{
    const QString dir = picturesDir();
    if (dir.isEmpty())
        return {};
    const QFileInfo file(videoPath);
    const QByteArray key = QCryptographicHash::hash(
        (file.absoluteFilePath() + QString::number(file.lastModified().toMSecsSinceEpoch())).toUtf8(),
        QCryptographicHash::Sha1).toHex();
    return dir + QLatin1Char('/') + QString::fromLatin1(key) + QStringLiteral(".png");
}

QString RdStorage::waveformFile(const QString& dir, const QFileInfo& video)
{
    QByteArray key = video.absoluteFilePath().toUtf8();
    key += '\n' + QByteArray::number(video.size());
    key += '\n' + QByteArray::number(video.lastModified().toMSecsSinceEpoch());
    return dir + QLatin1Char('/')
           + QString::fromLatin1(QCryptographicHash::hash(key, QCryptographicHash::Sha1).toHex())
           + QStringLiteral(".wf");
}

bool RdStorage::batterySaver()
{
#ifdef _WIN32
    SYSTEM_POWER_STATUS status;
    return GetSystemPowerStatus(&status) && (status.SystemStatusFlag & SYSTEM_STATUS_FLAG_POWER_SAVING_ON);
#else
    return false;
#endif
}

RdStorage::Seen RdStorage::describeShow(const QString& root, const QStringList& episodes)
{
    Seen seen;
    seen.entry.kind = Kind::Show;
    seen.entry.path = root;
    const QDir dir(root);
    for (const QString& episode : episodes)
    {
        const QFileInfo info(episode);
        if (!info.isFile())
            continue;
        FileId id;
        id.name = info.fileName();
        id.relativePath = QDir::fromNativeSeparators(dir.relativeFilePath(info.absoluteFilePath()));
        id.size = info.size();
        seen.entry.files.append(id);
    }
    const rdvolume::Info volume = rdvolume::volumeOf(root, kDriveTimeoutMs);
    seen.entry.volume = volume.id;
    seen.volumeRoot = volume.root;
    return seen;
}

RdStorage::Seen RdStorage::describeMovie(const QString& path)
{
    Seen seen;
    seen.entry.kind = Kind::Movie;
    seen.entry.path = path;
    const QFileInfo info(path);
    if (info.isFile())
    {
        FileId id;
        id.name = info.fileName();
        id.relativePath = id.name;
        id.size = info.size();
        seen.entry.files.append(id);
    }
    const rdvolume::Info volume = rdvolume::volumeOf(path, kDriveTimeoutMs);
    seen.entry.volume = volume.id;
    seen.volumeRoot = volume.root;
    return seen;
}

void RdStorage::whenLoaded(std::function<void()> action)
{
    if (m_loaded)
        action();
    else
        m_beforeLoad.append(std::move(action));
}

void RdStorage::log(const QString& text) const
{
    msg_Dbg(m_intf, "storage: %s", qtu(text));
}

void RdStorage::seen(const Seen& seen)
{
    if (seen.entry.path.isEmpty())
        return;
    whenLoaded([this, seen]() {
        const Entry& entry = seen.entry;
        if (!entry.volume.isEmpty())
        {
            m_sessionVolumes.insert(entry.volume);
            if (!seen.volumeRoot.isEmpty() && !m_sessionRoots.contains(seen.volumeRoot))
                m_sessionRoots.append(seen.volumeRoot);
        }
        const qint64 time = now();
        // a show or movie Cone has no data for: an earlier one with the same files?
        if (!m_model.has(entry.path))
        {
            if (const std::optional<Match> match = m_model.findMatch(entry))
            {
                const QString oldPath = m_model.entries().value(match->fromKey).path;
                const QVector<Moved> moved = m_model.relocate(*match, entry, time);
                log(QStringLiteral("%1 found again at %2 (%3 files in common): its data moves with it")
                        .arg(oldPath, entry.path).arg(match->media.size()));
                emit relocated(oldPath, entry.path, match->media);
                renameArtifacts(moved);
            }
        }
        m_model.recordPlay(entry, time);
        scheduleSave();
    });
}

void RdStorage::importLegacy(const QStringList& paths, Kind kind, qint64 lastPlayed)
{
    whenLoaded([this, paths, kind, lastPlayed]() {
        bool changed = false;
        for (const QString& path : paths)
            changed |= m_model.importLegacy(path, kind, lastPlayed > 0 ? lastPlayed : now());
        if (changed)
            scheduleSave();
    });
}

void RdStorage::pictureWritten(const QString& file, const QString& videoPath)
{
    whenLoaded([this, file, videoPath]() {
        m_model.addArtifact(file, ArtifactKind::Picture, videoPath, now());
        scheduleSave();
        checkPictureCap();
    });
}

void RdStorage::waveformUsed(const QString& file, const QString& videoPath)
{
    whenLoaded([this, file, videoPath]() {
        if (m_model.artifacts().contains(file))
            return;
        m_model.addArtifact(file, ArtifactKind::Waveform, videoPath, now());
        scheduleSave();
    });
}

void RdStorage::downloadWritten(const QString& file, const QString& videoPath)
{
    whenLoaded([this, file, videoPath]() {
        m_model.addArtifact(file, ArtifactKind::Download, videoPath, now());
        // the backup cap: the oldest downloads over 1,000 go
        apply(m_model.caps({}), QStringLiteral("download cap"));
        scheduleSave();
        checkSelectedDownload();
    });
}

void RdStorage::setDownloadOwners(const QHash<QString, QString>& owners)
{
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (!queue)
        return;
    // the downloads from before the registry: counted as used now, so the 30 days start with
    // this version (a season downloaded long ago is not all deleted on the first check)
    auto found = std::make_shared<QVector<QPair<QString, qint64>>>();
    QPointer<RdStorage> self(this);
    queue->post(QStringLiteral("storage downloads"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
        [found](const std::shared_ptr<RdBackgroundQueue::Control>&) {
            *found = listFiles(downloadsDir(), {});
        },
        [self, found, owners]() {
            if (!self)
                return;
            self->whenLoaded([self, found, owners]() {
                if (!self)
                    return;
                bool changed = false;
                for (const auto& file : *found)
                {
                    if (self->m_model.artifacts().contains(file.first))
                        continue;
                    self->m_model.addArtifact(file.first, ArtifactKind::Download, owners.value(file.first), now());
                    changed = true;
                }
                if (changed)
                    self->scheduleSave();
            });
        });
}

void RdStorage::forgetAll()
{
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (!queue)
        return;
    auto pictures = std::make_shared<QStringList>();
    auto downloads = std::make_shared<QStringList>();
    QPointer<RdStorage> self(this);
    queue->post(QStringLiteral("storage forget all"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent,
        [pictures, downloads](const std::shared_ptr<RdBackgroundQueue::Control>&) {
            *pictures = pathsOf(listFiles(picturesDir(), { QStringLiteral("*.png") }));
            *downloads = pathsOf(listFiles(downloadsDir(), {}));
        },
        [self, pictures, downloads]() {
            if (!self)
                return;
            self->whenLoaded([self, pictures, downloads]() {
                if (self)
                    self->apply(self->m_model.forgetAll(*pictures, *downloads), QStringLiteral("forget all"));
            });
        });
}

void RdStorage::scheduleSave()
{
    if (!m_loaded)
        return;
    ++m_changes;
    m_saveTimer.start();
}

void RdStorage::save()
{
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (!m_loaded || !queue)
        return;
    const QByteArray json = QJsonDocument(m_model.toJson()).toJson(QJsonDocument::Compact);
    const quint64 changes = m_changes;
    QPointer<RdStorage> self(this);
    queue->post(QStringLiteral("storage save"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::High,
        [json](const std::shared_ptr<RdBackgroundQueue::Control>& control) {
            if (control->cancelled())
                return;
            const QString path = storePath();
            if (path.isEmpty())
                return;
            QDir().mkpath(QFileInfo(path).absolutePath());
            QSaveFile file(path);
            if (file.open(QIODevice::WriteOnly))
            {
                file.write(json);
                file.commit();
            }
        },
        [self, changes]() {
            // written, unless it was dropped (quit) or more changed meanwhile
            if (self && self->m_changes == changes)
                self->m_savedChanges = changes;
        });
}

void RdStorage::dailyTick()
{
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (!queue || !m_loaded || m_dailyRunning || !m_model.dailyDue(now()))
        return;
    if (batterySaver())
    {
        log(QStringLiteral("the daily check waits (battery saver)"));
        return;
    }
    m_dailyRunning = true;

    // what the check looks at: only folders on the drives Cone read this session
    struct Item
    {
        QString path;
        QString volume;
    };
    QVector<Item> items;
    for (const Entry& entry : m_model.entries())
        if (entry.volume.isEmpty() || m_sessionVolumes.contains(entry.volume))
            items.append({ entry.path, entry.volume });
    const QStringList roots = m_sessionRoots;
    const QSet<QString> connected = m_sessionVolumes;

    auto answers = std::make_shared<QHash<QString, QPair<Presence, QString>>>();
    auto pictures = std::make_shared<QVector<QPair<QString, qint64>>>();
    QPointer<RdStorage> self(this);
    queue->post(QStringLiteral("storage cleanup"), RdBackgroundQueue::Weight::Heavy, RdBackgroundQueue::Low,
        [items, roots, answers, pictures](const std::shared_ptr<RdBackgroundQueue::Control>& control) {
            rdvolume::SystemFileSystem fs(kDriveTimeoutMs);
            for (const Item& item : items)
            {
                if (!control->waitWhilePaused())
                    return;
                Presence presence = item.volume.isEmpty() ? Presence::Unchecked : Presence::Disconnected;
                QString volumeNow;
                // a drive Cone has not read this session is never woken
                if (onSessionDrive(item.path, roots))
                    presence = presenceOf(fs, item.path, item.volume, &volumeNow);
                answers->insert(Model::key(item.path), { presence, volumeNow });
            }
            if (control->waitWhilePaused())
                *pictures = listFiles(picturesDir(), { QStringLiteral("*.png") });
        },
        [self, answers, pictures, connected]() {
            if (!self)
                return;
            self->m_dailyRunning = false;
            CachedProbe probe(*answers);
            Plan plan = self->m_model.daily(now(), probe, connected);
            plan.merge(self->m_model.caps(*pictures));
            self->apply(plan, QStringLiteral("daily check"));
            self->scheduleSave();
        }, true);
}

void RdStorage::apply(const Plan& plan, const QString& why)
{
    if (plan.isEmpty())
        return;
    log(QStringLiteral("%1: %2 files deleted, %3 shows or movies forgotten, %4 subtitle links removed")
            .arg(why).arg(plan.deleteFiles.size()).arg(plan.forgetEntries.size()).arg(plan.unlinkDownloads.size()));
    for (const QString& path : plan.forgetEntries)
        log(QStringLiteral("forgotten: %1").arg(path));
    if (!plan.forgetEntries.isEmpty())
        emit forgetEntries(plan.forgetEntries);
    if (!plan.unlinkDownloads.isEmpty())
        emit unlinkDownloads(plan.unlinkDownloads);
    m_model.applied(plan);
    deleteFiles(plan.deleteFiles);
    scheduleSave();
}

void RdStorage::deleteFiles(const QStringList& files)
{
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (files.isEmpty() || !queue)
        return;
    // only Cone's own files: never anything outside its folders
    const QStringList allowed = { picturesDir(), waveformsDir(), downloadsDir() };
    queue->post(QStringLiteral("storage delete"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
        [files, allowed](const std::shared_ptr<RdBackgroundQueue::Control>&) {
            for (const QString& file : files)
            {
                const QString key = Model::key(file);
                bool ours = false;
                for (const QString& dir : allowed)
                    ours |= !dir.isEmpty() && key.startsWith(Model::key(dir) + QLatin1Char('/'));
                if (ours)
                    QFile::remove(file);
            }
        });
}

void RdStorage::renameArtifacts(const QVector<Moved>& moved)
{
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    QVector<Moved> files;
    for (const Moved& item : moved)
        if (item.kind != ArtifactKind::Download && !item.newPath.isEmpty())
            files.append(item);
    if (files.isEmpty() || !queue)
        return;
    // pictures and waveforms are named after their video's path: renamed for the new one
    auto renamed = std::make_shared<QVector<QPair<QString, QString>>>();
    QPointer<RdStorage> self(this);
    queue->post(QStringLiteral("storage rename"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Normal,
        [files, renamed](const std::shared_ptr<RdBackgroundQueue::Control>&) {
            const QString waveforms = waveformsDir();
            for (const Moved& item : files)
            {
                const QString target = item.kind == ArtifactKind::Picture
                        ? pictureFile(item.newPath)
                        : waveformFile(waveforms, QFileInfo(item.newPath));
                if (target.isEmpty() || target == item.file || !QFile::exists(item.file))
                    continue;
                // the new name made already (the show played there before): the old one goes
                if (QFile::exists(target))
                {
                    QFile::remove(item.file);
                    renamed->append({ item.file, target });
                }
                else if (QFile::rename(item.file, target))
                    renamed->append({ item.file, target });
            }
        },
        [self, renamed]() {
            if (!self)
                return;
            for (const auto& pair : *renamed)
                self->m_model.renameArtifact(pair.first, pair.second);
            if (!renamed->isEmpty())
                self->scheduleSave();
        });
}

void RdStorage::checkPictureCap()
{
    RdBackgroundQueue* queue = RdBackgroundQueue::instance();
    if (m_pictureCapQueued || !queue)
        return;
    m_pictureCapQueued = true;
    auto pictures = std::make_shared<QVector<QPair<QString, qint64>>>();
    QPointer<RdStorage> self(this);
    queue->post(QStringLiteral("picture cap"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
        [pictures](const std::shared_ptr<RdBackgroundQueue::Control>&) {
            *pictures = listFiles(picturesDir(), { QStringLiteral("*.png") });
        },
        [self, pictures]() {
            if (!self)
                return;
            self->m_pictureCapQueued = false;
            if (pictures->size() > kPictureCap)
                self->apply(self->m_model.caps(*pictures), QStringLiteral("picture cap"));
        });
}

void RdStorage::onInputChanged()
{
    QString path;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker lock{ player };
        if (input_item_t* item = vlc_player_GetCurrentMedia(player))
        {
            vlc_mutex_lock(&item->lock);
            path = localPathOf(item->psz_uri);
            vlc_mutex_unlock(&item->lock);
        }
    }
    if (Model::key(path) == Model::key(m_currentMedia))
        return;
    const QString closed = m_currentMedia;
    m_currentMedia = path;
    if (closed.isEmpty())
        return;
    // the video closed: its downloaded subtitles never selected go, the one in use stays
    whenLoaded([this, closed]() { apply(m_model.closed(closed), QStringLiteral("video closed")); });
}

void RdStorage::checkSelectedDownload()
{
    if (!m_loaded || m_currentMedia.isEmpty())
        return;
    const QStringList downloads = m_model.artifactsOf(m_currentMedia, ArtifactKind::Download);
    if (downloads.isEmpty())
        return;
    // an added file's track ID starts with the MD5 of its address (AddSubtitles::attach)
    QHash<QByteArray, QString> byHash;
    for (const QString& file : downloads)
    {
        char* uri = vlc_path2uri(qtu(QDir::toNativeSeparators(file)), nullptr);
        if (!uri)
            continue;
        byHash.insert(QCryptographicHash::hash(QByteArray(uri), QCryptographicHash::Md5).toHex(), file);
        free(uri);
    }
    QStringList selected;
    {
        vlc_player_t* player = m_player->getPlayer();
        vlc_player_locker lock{ player };
        const size_t count = vlc_player_GetTrackCount(player, SPU_ES);
        for (size_t i = 0; i < count; ++i)
        {
            const vlc_player_track* track = vlc_player_GetTrackAt(player, SPU_ES, i);
            if (!track || !track->selected)
                continue;
            const char* strId = vlc_es_id_GetStrId(track->es_id);
            const char* slash = strId ? std::strchr(strId, '/') : nullptr;
            if (!slash)
                continue;
            const auto found = byHash.constFind(QByteArray(strId, int(slash - strId)));
            if (found != byHash.constEnd())
                selected.append(found.value());
        }
    }
    for (const QString& file : selected)
        m_model.markSelected(file, now());
    if (!selected.isEmpty())
        scheduleSave();
}
