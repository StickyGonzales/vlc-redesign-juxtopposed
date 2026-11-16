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

#if HAVE_CONFIG_H
# include "config.h"
#endif

#include "rdlibrarymodel.hpp"

#include <QUrl>

#include <algorithm>

#include <vlc_media_library.h>

#include "medialib.hpp"
#include "mlhelper.hpp"
#include "util/vlctick.hpp"

namespace {

// thumbnails are generated at the size VLC's own video views ask for
constexpr uint32_t THUMBNAIL_WIDTH = 512;
constexpr uint32_t THUMBNAIL_HEIGHT = 320;
constexpr double THUMBNAIL_POSITION = .15;


QString thumbnailOf(const vlc_ml_thumbnail_t (&thumbnails)[VLC_ML_THUMBNAIL_SIZE_COUNT])
{
    const vlc_ml_thumbnail_t& smallThumbnail = thumbnails[VLC_ML_THUMBNAIL_SMALL];
    if (smallThumbnail.i_status == VLC_ML_THUMBNAIL_STATUS_AVAILABLE && smallThumbnail.psz_mrl)
        return qfu(smallThumbnail.psz_mrl);
    return {};
}

const char* kindName(RdLibraryItem::Kind kind)
{
    switch (kind)
    {
    case RdLibraryItem::Media:    return "media";
    case RdLibraryItem::Folder:   return "folder";
    case RdLibraryItem::Playlist: return "playlist";
    case RdLibraryItem::Artist:   return "artist";
    case RdLibraryItem::Album:    return "album";
    case RdLibraryItem::Genre:    return "genre";
    case RdLibraryItem::Stream:   return "stream";
    }
    return "media";
}

} // namespace

// RdLibraryItems

RdLibraryItem RdLibraryItems::fromMedia(vlc_medialibrary_t* ml, const vlc_ml_media_t& media)
{
    RdLibraryItem item;
    item.id = MLItemId(media.i_id, VLC_ML_PARENT_UNKNOWN);
    item.isVideo = media.i_type != VLC_ML_MEDIA_TYPE_AUDIO;
    item.isFavorite = media.b_is_favorite;
    item.duration = media.i_duration;
    item.watched = media.i_playcount > 0;
    item.progress = (media.f_progress > 0. && media.f_progress < 1.) ? media.f_progress : -1.;

    if (media.p_files && media.p_files->i_nb_items > 0)
    {
        const vlc_ml_file_t& file = media.p_files->p_items[0];
        item.mrl = qfu(file.psz_mrl);
        item.modified = file.i_last_modification_date;
    }
    // network streams (stream history, saved streams) are not files
    if (!item.mrl.isEmpty() && !QUrl(item.mrl).isLocalFile())
        item.kind = RdLibraryItem::Stream;

    // videos show their file name, as in the design ("The_Wand_S01E05.mp4"); songs their title
    if (item.isVideo && media.psz_filename && *media.psz_filename && item.kind == RdLibraryItem::Media)
        item.title = qfu(media.psz_filename);
    else
        item.title = qfu(media.psz_title);

    item.thumbnail = thumbnailOf(media.thumbnails);

    if (media.i_type == VLC_ML_MEDIA_TYPE_AUDIO)
    {
        item.trackNumber = media.album_track.i_track_nb;
        item.discNumber = media.album_track.i_disc_nb;

        if (media.album_track.i_artist_id > 0)
        {
            ml_unique_ptr<vlc_ml_artist_t> artist(vlc_ml_get_artist(ml, media.album_track.i_artist_id));
            if (artist && artist->psz_name)
                item.artist = qfu(artist->psz_name);
        }
        if (media.album_track.i_album_id > 0)
        {
            ml_unique_ptr<vlc_ml_album_t> album(vlc_ml_get_album(ml, media.album_track.i_album_id));
            if (album)
            {
                item.album = qfu(album->psz_title);
                if (item.thumbnail.isEmpty())
                    item.thumbnail = thumbnailOf(album->thumbnails);
            }
        }
        item.subtitle = item.artist;
    }
    else
    {
        const vlc_ml_thumbnail_status_t status = media.thumbnails[VLC_ML_THUMBNAIL_SMALL].i_status;
        item.thumbnailMissing = item.kind == RdLibraryItem::Media
                                && (status == VLC_ML_THUMBNAIL_STATUS_MISSING
                                    || status == VLC_ML_THUMBNAIL_STATUS_FAILURE);
    }
    return item;
}

RdLibraryItem RdLibraryItems::fromFolder(const vlc_ml_folder_t& folder)
{
    RdLibraryItem item;
    item.kind = RdLibraryItem::Folder;
    item.id = MLItemId(folder.i_id, VLC_ML_PARENT_FOLDER);
    item.title = qfu(folder.psz_name);
    item.mrl = qfu(folder.psz_mrl);
    item.duration = folder.i_duration;
    item.count = static_cast<int>(folder.i_nb_media);
    item.isFavorite = folder.b_is_favorite;
    return item;
}

RdLibraryItem RdLibraryItems::fromPlaylist(const vlc_ml_playlist_t& playlist)
{
    RdLibraryItem item;
    item.kind = RdLibraryItem::Playlist;
    item.id = MLItemId(playlist.i_id, VLC_ML_PARENT_PLAYLIST);
    item.title = qfu(playlist.psz_name);
    item.mrl = qfu(playlist.psz_mrl);
    item.count = static_cast<int>(playlist.i_nb_media);
    item.isFavorite = playlist.b_is_favorite;
    return item;
}

RdLibraryItem RdLibraryItems::fromArtist(const vlc_ml_artist_t& artist)
{
    RdLibraryItem item;
    item.kind = RdLibraryItem::Artist;
    item.id = MLItemId(artist.i_id, VLC_ML_PARENT_ARTIST);
    item.title = qfu(artist.psz_name);
    item.thumbnail = thumbnailOf(artist.thumbnails);
    item.count = static_cast<int>(artist.i_nb_tracks);
    item.isFavorite = artist.b_is_favorite;
    return item;
}

QString RdLibraryItems::normalizedMrl(const QString& mrl)
{
    QString result = mrl;
    while (result.endsWith(QLatin1Char('/')) && !result.endsWith(QLatin1String(":///")))
        result.chop(1);
    return result;
}

QString RdLibraryItems::mrlKey(const QString& mrl)
{
    QString key = normalizedMrl(QUrl::fromPercentEncoding(mrl.toUtf8()));
#ifdef _WIN32
    // Windows drive letters are not case sensitive ("file:///C:/" and "file:///c:/")
    if (key.size() > 9 && key.startsWith(QLatin1String("file:///"), Qt::CaseInsensitive)
        && key.at(9) == QLatin1Char(':'))
        key[8] = key.at(8).toLower();
#endif
    return key;
}

bool RdLibraryItems::containsMrl(const QStringList& list, const QString& mrl)
{
    const QString key = mrlKey(mrl);
    return std::any_of(list.cbegin(), list.cend(), [&key](const QString& entry) {
        return mrlKey(entry) == key;
    });
}

// RdLibraryModel

RdLibraryModel::RdLibraryModel(QObject* parent)
    : QAbstractListModel(parent)
    , m_eventCallback(nullptr, [this](vlc_ml_event_callback_t* cb) {
        assert(m_mediaLib != nullptr);
        m_mediaLib->unregisterEventListener(cb);
    })
{
    m_reloadTimer.setSingleShot(true);
    connect(&m_reloadTimer, &QTimer::timeout, this, &RdLibraryModel::reload);
    m_reloadClock.start();
}

RdLibraryModel::~RdLibraryModel()
{
    // stop the media library events before the members they reach go away
    m_eventCallback.reset();
}

int RdLibraryModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid())
        return 0;
    return count();
}

QHash<int, QByteArray> RdLibraryModel::roleNames() const
{
    return {
        { KIND, "kind" },
        { ID, "id" },
        { TITLE, "title" },
        { SUBTITLE, "subtitle" },
        { MRL, "mrl" },
        { THUMBNAIL, "thumbnail" },
        { PROGRESS, "progress" },
        { WATCHED, "watched" },
        { IS_VIDEO, "isVideo" },
        { IS_FAVORITE, "isFavorite" },
        { DURATION, "duration" },
        { COUNT_ROLE, "itemCount" },
        { ARTIST, "artist" },
        { ALBUM, "album" },
        { IS_CONTAINER, "isContainer" },
    };
}

QVariant RdLibraryModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= count())
        return {};

    const RdLibraryItem& item = m_items[static_cast<size_t>(index.row())];
    switch (role)
    {
    case Qt::DisplayRole:
    case TITLE:
        return item.title;
    case KIND:
        return QString::fromLatin1(kindName(item.kind));
    case ID:
        return QVariant::fromValue(item.id);
    case SUBTITLE:
        return item.subtitle;
    case MRL:
        return item.mrl;
    case THUMBNAIL:
        return item.thumbnail;
    case PROGRESS:
        return item.progress;
    case WATCHED:
        return item.watched;
    case IS_VIDEO:
        return item.isVideo;
    case IS_FAVORITE:
        return item.isFavorite;
    case DURATION:
        return QVariant::fromValue(VLCDuration(VLC_TICK_FROM_MS(item.duration)));
    case COUNT_ROLE:
        return item.count;
    case ARTIST:
        return item.artist;
    case ALBUM:
        return item.album;
    case IS_CONTAINER:
        return item.kind != RdLibraryItem::Media && item.kind != RdLibraryItem::Stream;
    default:
        return {};
    }
}

void RdLibraryModel::setMl(MediaLib* ml)
{
    if (m_mediaLib == ml)
        return;

    m_eventCallback.reset();
    m_mediaLib = ml;
    if (m_mediaLib)
        m_eventCallback.reset(m_mediaLib->registerEventListener(&RdLibraryModel::onMlEvent, this));
    emit mlChanged();
    requestReload();
}

void RdLibraryModel::setSearchPattern(const QString& pattern)
{
    if (m_searchPattern == pattern)
        return;
    m_searchPattern = pattern;
    emit searchPatternChanged();
    rebuild();
}

bool RdLibraryModel::isRelevantEvent(int eventType)
{
    switch (eventType)
    {
    case VLC_ML_EVENT_DISCOVERY_STARTED:
    case VLC_ML_EVENT_DISCOVERY_PROGRESS:
    case VLC_ML_EVENT_BACKGROUND_IDLE_CHANGED:
    case VLC_ML_EVENT_PARSING_PROGRESS_UPDATED:
    case VLC_ML_EVENT_BOOKMARKS_ADDED:
    case VLC_ML_EVENT_BOOKMARKS_UPDATED:
    case VLC_ML_EVENT_BOOKMARKS_DELETED:
        return false;
    default:
        return true;
    }
}

void RdLibraryModel::onMlEvent(void* data, const vlc_ml_event_t* event)
{
    // media library thread
    auto* self = static_cast<RdLibraryModel*>(data);
    if (!isRelevantEvent(event->i_type))
        return;
    QMetaObject::invokeMethod(self, &RdLibraryModel::scheduleReload, Qt::QueuedConnection);
}

void RdLibraryModel::scheduleReload()
{
    // the first event of a burst starts the delay, the next ones join it; a scan sending events
    // all the time refreshes the page at most once a second (the home page's rows each reload
    // with a library query: every 300 ms they kept the media library busy for the whole scan)
    if (!m_reloadTimer.isActive())
        m_reloadTimer.start(m_reloadThrottle.delayFor(m_reloadClock.elapsed()));
}

void RdLibraryModel::requestReload()
{
    // the views hide their empty state while loading: no "nothing here" flash before the
    // first rows arrive
    if (!m_loading)
    {
        m_loading = true;
        emit loadingChanged();
    }
    if (m_reloadQueued)
        return;
    m_reloadQueued = true;
    QMetaObject::invokeMethod(this, [this]() {
        m_reloadQueued = false;
        reload();
    }, Qt::QueuedConnection);
}

void RdLibraryModel::reload()
{
    m_reloadTimer.stop();
    m_reloadThrottle.reloaded(m_reloadClock.elapsed());
    if (!m_mediaLib || !canLoad())
    {
        if (m_loading && m_taskId == 0)
        {
            m_loading = false;
            emit loadingChanged();
        }
        return;
    }

    if (m_taskId != 0)
        m_mediaLib->cancelMLTask(this, m_taskId);

    if (!m_loading)
    {
        m_loading = true;
        emit loadingChanged();
    }

    struct Ctx {
        RdLibraryItemList items;
    };

    Loader loader = createLoader();
    m_taskId = m_mediaLib->runOnMLThread<Ctx>(this,
    [loader](vlc_medialibrary_t* ml, Ctx& ctx) {
        ctx.items = loader(ml);
    },
    [this](quint64 taskId, Ctx& ctx) {
        if (taskId != m_taskId)
            return;
        m_taskId = 0;
        applyItems(std::move(ctx.items));
        m_loading = false;
        emit loadingChanged();
        emit loaded();
    });
}

void RdLibraryModel::applyItems(RdLibraryItemList&& items)
{
    m_all = std::move(items);
    rebuild();
    requestThumbnails();
}

void RdLibraryModel::rebuild()
{
    RdLibraryItemList items;
    items.reserve(m_all.size());
    for (const RdLibraryItem& item : m_all)
    {
        if (m_searchPattern.isEmpty()
            || item.title.contains(m_searchPattern, Qt::CaseInsensitive)
            || item.subtitle.contains(m_searchPattern, Qt::CaseInsensitive))
            items.push_back(item);
    }
    // same rows in the same order: refresh them in place, so views keep their scroll position
    const bool sameRows = items.size() == m_items.size()
                          && std::equal(items.cbegin(), items.cend(), m_items.cbegin(),
                                        [](const RdLibraryItem& a, const RdLibraryItem& b) {
                                            return a.kind == b.kind && a.id == b.id && a.mrl == b.mrl;
                                        });
    if (sameRows)
    {
        m_items = std::move(items);
        if (!m_items.empty())
            emit dataChanged(index(0), index(count() - 1));
        return;
    }

    beginResetModel();
    m_items = std::move(items);
    endResetModel();
    emit countChanged();
}

void RdLibraryModel::requestThumbnails()
{
    std::vector<int64_t> ids;
    for (const RdLibraryItem& item : m_all)
    {
        if (item.thumbnailMissing && !m_thumbnailRequested.contains(item.id.id))
        {
            m_thumbnailRequested.insert(item.id.id);
            ids.push_back(item.id.id);
        }
    }
    if (ids.empty() || !m_mediaLib)
        return;

    m_mediaLib->runOnMLThread(this, [ids](vlc_medialibrary_t* ml) {
        for (int64_t id : ids)
            vlc_ml_media_generate_thumbnail(ml, id, VLC_ML_THUMBNAIL_SMALL,
                                            THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT, THUMBNAIL_POSITION);
    });
}
