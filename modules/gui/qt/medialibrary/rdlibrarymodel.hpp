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

#ifndef RDLIBRARYMODEL_HPP
#define RDLIBRARYMODEL_HPP

// redesign: base of the Home section models of the redesigned library (video 13:44-13:55).
// A Home section is a short list built from several media library queries (a filtered
// history, visited folders, ranked artists), which no MLBaseModel provides. The model loads its
// few rows on the media library thread (never on the UI thread) and is capped (see
// RdCollectionModel); every unbounded library list uses VLC's paged MLBaseModel models.

#include <QAbstractListModel>
#include <QElapsedTimer>
#include <QSet>
#include <QTimer>

#include <functional>
#include <memory>
#include <vector>

#include "mlqmltypes.hpp"
#include "util/rd_reload_throttle.hpp"

Q_MOC_INCLUDE("medialibrary/medialib.hpp")

class MediaLib;
struct vlc_medialibrary_t;
struct vlc_ml_event_callback_t;
struct vlc_ml_event_t;

// one row of a library page
struct RdLibraryItem
{
    enum Kind { Media, Folder, Playlist, Artist, Album, Genre, Stream };

    Kind kind = Media;
    MLItemId id;
    QString title;
    QString subtitle;    // artist of a song, track count of a container
    QString mrl;
    QString thumbnail;
    QString artist;
    QString album;
    double progress = -1.;  // 0..1 while a media is being watched, -1 otherwise
    bool watched = false;   // played to the end at least once
    bool isVideo = false;
    bool isFavorite = false;
    qint64 duration = 0;    // ms
    qint64 modified = 0;    // file modification date (s), "Newest First" / "Oldest First"
    int trackNumber = 0;
    int discNumber = 0;
    int count = 0;          // media in a folder, playlist, album, artist, genre
    bool thumbnailMissing = false;
};

using RdLibraryItemList = std::vector<RdLibraryItem>;

// conversions from the media library structures (to be called on the media library thread)
namespace RdLibraryItems
{
RdLibraryItem fromMedia(vlc_medialibrary_t* ml, const struct vlc_ml_media_t& media);
RdLibraryItem fromFolder(const struct vlc_ml_folder_t& folder);
RdLibraryItem fromPlaylist(const struct vlc_ml_playlist_t& playlist);
RdLibraryItem fromArtist(const struct vlc_ml_artist_t& artist);
// folder MRLs compare without their trailing slash
QString normalizedMrl(const QString& mrl);
// key to compare MRLs: the media library, VLC and Qt percent-encode differently, so MRLs are
// compared fully decoded, without a trailing slash
QString mrlKey(const QString& mrl);
bool containsMrl(const QStringList& list, const QString& mrl);
}

class RdLibraryModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(MediaLib* ml READ ml WRITE setMl NOTIFY mlChanged FINAL)
    Q_PROPERTY(QString searchPattern READ searchPattern WRITE setSearchPattern NOTIFY searchPatternChanged FINAL)
    Q_PROPERTY(int count READ count NOTIFY countChanged FINAL)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged FINAL)

public:
    enum Roles {
        KIND = Qt::UserRole + 1,
        ID,
        TITLE,
        SUBTITLE,
        MRL,
        THUMBNAIL,
        PROGRESS,
        WATCHED,
        IS_VIDEO,
        IS_FAVORITE,
        DURATION,
        COUNT_ROLE,
        ARTIST,
        ALBUM,
        IS_CONTAINER
    };

    explicit RdLibraryModel(QObject* parent = nullptr);
    ~RdLibraryModel() override;

    int rowCount(const QModelIndex& parent = {}) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    MediaLib* ml() const { return m_mediaLib; }
    void setMl(MediaLib* ml);

    QString searchPattern() const { return m_searchPattern; }
    void setSearchPattern(const QString& pattern);

    int count() const { return static_cast<int>(m_items.size()); }
    bool loading() const { return m_loading; }

public slots:
    void reload();

signals:
    void mlChanged();
    void searchPatternChanged();
    void countChanged();
    void loadingChanged();
    void loaded();

protected:
    // the loading function runs on the media library thread: it must only use the copies it
    // captured, never `this`
    using Loader = std::function<RdLibraryItemList(vlc_medialibrary_t* ml)>;
    virtual Loader createLoader() const = 0;
    // media library events that change the page; called on the media library thread, so it
    // touches no object state
    static bool isRelevantEvent(int eventType);
    // the model may only load once its parameters are set
    virtual bool canLoad() const { return true; }

    // media library events: reload after a short quiet time (a scan sends many events)
    void scheduleReload();
    // a parameter changed: load at the next event loop turn, once QML has set every parameter
    void requestReload();

private:
    static void onMlEvent(void* data, const vlc_ml_event_t* event);
    void applyItems(RdLibraryItemList&& items);
    void rebuild();
    void requestThumbnails();

    MediaLib* m_mediaLib = nullptr;
    std::unique_ptr<vlc_ml_event_callback_t, std::function<void(vlc_ml_event_callback_t*)>> m_eventCallback;
    QTimer m_reloadTimer;
    // during a library scan the page refreshes at most once a second
    RdReloadThrottle m_reloadThrottle;
    QElapsedTimer m_reloadClock;
    quint64 m_taskId = 0;
    bool m_loading = false;
    bool m_reloadQueued = false;

    QString m_searchPattern;

    RdLibraryItemList m_all;
    RdLibraryItemList m_items;
    QSet<int64_t> m_thumbnailRequested;
};

#endif // RDLIBRARYMODEL_HPP
