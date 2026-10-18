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

#ifndef RDLIBRARYSTORE_HPP
#define RDLIBRARYSTORE_HPP

// redesign: what the redesigned library keeps besides the media library itself (video
// 9:35-13:55): which library folders belong to Videos and to Music (P5-16, P5-29), the pins of
// the library rail (P6-18), the named network stream lists (P6-14), the playlist thumbnails
// (IB-30), how often folders and playlists are opened (Home "Frequently Visited", P6-20), the
// sort order of each page and the view mode (P5-12, P5-13). Kept in VLC's Qt settings.
// It also runs the library actions that have no media library model behind them.

#include <QJSValue>
#include <QObject>
#include <QTimer>
#include <QUrl>
#include <QVariant>

#include <functional>
#include <memory>

#include "qt.hpp"
#include "mlqmltypes.hpp"

class MediaLib;

class RdLibraryStore : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QStringList videoFolders READ videoFolders NOTIFY foldersChanged FINAL)
    Q_PROPERTY(QStringList musicFolders READ musicFolders NOTIFY foldersChanged FINAL)
    // library folders removed from both categories that stay in the media library because
    // folders of a category are inside them (their media keep their data); shown nowhere
    Q_PROPERTY(QStringList hiddenRoots READ hiddenRoots NOTIFY foldersChanged FINAL)
    // [{ kind, title, image, location }], see addPin()
    Q_PROPERTY(QVariantList pins READ pins NOTIFY pinsChanged FINAL)
    // [{ name, url }]
    Q_PROPERTY(QVariantList streamLists READ streamLists NOTIFY streamListsChanged FINAL)
    // playlist id (as a string) -> thumbnail url; read it with playlistCover()
    Q_PROPERTY(QVariantMap playlistCovers READ playlistCovers NOTIFY playlistCoversChanged FINAL)
    Q_PROPERTY(QVariantList frequentFolderIds READ frequentFolderIds NOTIFY visitsChanged FINAL)
    Q_PROPERTY(QVariantList frequentPlaylistIds READ frequentPlaylistIds NOTIFY visitsChanged FINAL)
    // "grid" or "list", for the full library and for the compact library next to the video
    Q_PROPERTY(QString viewMode READ viewMode WRITE setViewMode NOTIFY viewModeChanged FINAL)
    Q_PROPERTY(QString compactViewMode READ compactViewMode WRITE setCompactViewMode NOTIFY viewModeChanged FINAL)

public:
    RdLibraryStore(qt_intf_t* intf, MediaLib* mediaLib, QObject* parent = nullptr);
    ~RdLibraryStore() override;

    QStringList videoFolders() const { return m_videoFolders; }
    QStringList musicFolders() const { return m_musicFolders; }
    QStringList hiddenRoots() const { return m_hiddenRoots; }
    QVariantList pins() const { return m_pins; }
    QVariantList streamLists() const { return m_streamLists; }
    QVariantMap playlistCovers() const { return m_playlistCovers; }
    QVariantList frequentFolderIds() const { return frequentIds(QStringLiteral("folder")); }
    QVariantList frequentPlaylistIds() const { return frequentIds(QStringLiteral("playlist")); }
    QString viewMode() const { return m_viewMode; }
    void setViewMode(const QString& mode);
    QString compactViewMode() const { return m_compactViewMode; }
    void setCompactViewMode(const QString& mode);

    // file pickers (native dialogs): callback(url) / callback([url]), empty when cancelled.
    // The picker opens once the event that asked for it is handled, never inside a QML handler:
    // its own event loop could otherwise destroy the item running that handler (a model reload
    // of a scan rebuilds the library rows) and crash when the dialog returns (P5-16). One picker
    // at a time; a request while one is open is dropped. The folder picker opens in `start` (a
    // local folder URL), else in the user's Videos or Music folder for `category`, else in the
    // user's home folder
    Q_INVOKABLE void pickFolder(const QString& title, const QUrl& start, const QString& category,
                                QJSValue callback);
    Q_INVOKABLE void pickFiles(const QString& title, bool images, QJSValue callback);

    // `value` held by value. In Qt 6 a value type read from a model row in a delegate (an
    // MLItemId, a network tree) is a reference to that row: kept after the row changes or the
    // delegate is destroyed, it reads another row's value or nothing (RdLibraryNav.detached)
    Q_INVOKABLE QVariant detached(const QVariant& value) const { return value; }

    // library folders of a category ("video" or "music")
    Q_INVOKABLE void addFolder(const QString& category, const QUrl& url);
    Q_INVOKABLE void removeFolder(const QString& category, const QString& mrl);
    Q_INVOKABLE void reloadFolder(const QString& mrl);
    // the library location of a folder or a file: callback({ category, crumbs: [{ id, title }] }),
    // or callback(null) when it is not inside a library folder. `category` ("video" or "music")
    // is preferred when the folder is shown in both (a folder just added to it)
    Q_INVOKABLE void resolveFolder(const QString& mrl, QJSValue callback, const QString& category = {});

    // pins of the library rail; `location` is the library page to open
    Q_INVOKABLE void addPin(const QString& kind, const QString& title, const QString& image,
                            const QVariantMap& location);
    Q_INVOKABLE void removePin(int index);
    Q_INVOKABLE void movePin(int from, int to);
    Q_INVOKABLE int pinIndex(const QVariantMap& location) const;

    // named network stream lists (a pasted m3u link saved with a name). The link is made an MRL
    // as Open URL does (a link without a scheme is a local path); returns the list's entry
    // { name, url } (the existing one for a link already saved), empty for an invalid link
    Q_INVOKABLE QVariantMap addStreamList(const QString& name, const QString& url);
    Q_INVOKABLE void removeStreamList(int index);
    Q_INVOKABLE void renameStreamList(int index, const QString& name);
    // a browse tree for NetworkMediaModel over a stream list, a folder or a playlist URL
    Q_INVOKABLE QVariant treeForUrl(const QString& url, const QString& name) const;

    // Home "Frequently Visited": kind is "folder" or "playlist"
    Q_INVOKABLE void noteVisit(const QString& kind, const MLItemId& id);

    // playlists (the media library playlists, with a thumbnail of their own)
    // items: MLItemIds or file URLs
    Q_INVOKABLE void createPlaylist(const QString& name, const QVariantList& items, const QUrl& cover);
    Q_INVOKABLE void appendToPlaylist(const MLItemId& playlistId, const QVariantList& items);
    Q_INVOKABLE void renamePlaylist(const MLItemId& playlistId, const QString& name);
    Q_INVOKABLE void deletePlaylist(const MLItemId& playlistId);
    Q_INVOKABLE void setPlaylistCover(const MLItemId& playlistId, const QUrl& image);
    // the playlist's own thumbnail, an empty URL when it has none
    Q_INVOKABLE QUrl playlistCover(const MLItemId& playlistId) const;
    Q_INVOKABLE void exportPlaylist(const MLItemId& playlistId, const QString& name);
    // the media addresses of a playlist, in its order: callback([mrl]) (the Add Subtitles
    // dialog's "To This Playlist", W6.5)
    Q_INVOKABLE void playlistMedia(const MLItemId& playlistId, QJSValue callback);

    // media and containers
    Q_INVOKABLE void setWatched(const QVariantList& mediaIds, bool watched);
    Q_INVOKABLE void setFavorite(const MLItemId& id, const QString& mrl, bool favorite);
    Q_INVOKABLE void showInFileExplorer(const QString& mrl) const;
    // Recent: forget what was played
    Q_INVOKABLE void clearHistory();

    // sort order of a library page kind ("folder", "music", "playlist" ...)
    Q_INVOKABLE QString sortKey(const QString& page, const QString& fallback) const;
    Q_INVOKABLE void setSortKey(const QString& page, const QString& key);

signals:
    void foldersChanged();
    void pinsChanged();
    void streamListsChanged();
    void playlistCoversChanged();
    void visitsChanged();
    void viewModeChanged();
    void sortKeysChanged();
    // a folder was added to a category; the library opens it once the media library has it
    void folderAdded(const QString& category, const QString& mrl);
    void playlistCreated(const MLItemId& playlistId);
    // the media library found or scanned folders (a folder being added may now be listed); at
    // most a few times a second during a scan, and once more when it ends
    void foldersScanned();
    // a scan ended: a folder still not listed will not show up by itself
    void scanFinished();

private:
    static void onMlEvent(void* data, const struct vlc_ml_event_t* event);
    void onFolderEvent();
    void onScanCompleted();
    // the user's Videos and Music folders, when they are library folders in no category
    // (added by the onboarding, VLC's first-run wizard or VLC's preferences), join their own
    // category instead of showing in both
    void sortStandardFolders();
    QVariantList frequentIds(const QString& kind) const;
    void save(const char* key, const QVariant& value);
    QString coverDirectory() const;
    static void appendItems(struct vlc_medialibrary_t* ml, int64_t playlistId, const QVariantList& items);
    // runs `dialog` (a native dialog) from the event loop, after the current event; dropped
    // while a dialog is open or waiting
    void openDialogLater(std::function<void()> dialog);
    // logs an error a picker callback threw
    void warnOnError(const QJSValue& result) const;
    // the M3U8 file of exportPlaylist()
    void writePlaylist(const MLItemId& playlistId, const QString& file);

    qt_intf_t* p_intf;
    MediaLib* m_mediaLib;
    std::unique_ptr<struct vlc_ml_event_callback_t, std::function<void(struct vlc_ml_event_callback_t*)>> m_eventCallback;
    // coalesces foldersScanned during a scan (one folder event per folder found)
    QTimer m_folderEventTimer;

    QStringList m_videoFolders;
    QStringList m_musicFolders;
    QVariantList m_pins;
    QVariantList m_streamLists;
    QVariantMap m_playlistCovers;
    QVariantMap m_visits;
    QVariantMap m_sortKeys;
    QString m_viewMode;
    QString m_compactViewMode;
    QStringList m_hiddenRoots;
    // a native dialog of the store is open or about to open
    bool m_dialogPending = false;
};

#endif // RDLIBRARYSTORE_HPP
