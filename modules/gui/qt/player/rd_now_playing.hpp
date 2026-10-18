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
#ifndef RD_NOW_PLAYING_HPP
#define RD_NOW_PLAYING_HPP

#include <QObject>
#include <QString>

#include <vlc_common.h>

class MainCtx;
class PlayerController;

/**
 * redesign (W8.1b, Figma "Player - customize"): what the Customize Player items "File Name",
 * "Folder Name", "Playlist Name" and "Favorite" show about the playing media.
 *
 * - fileName / folderName: the last part of the media's location and its parent folder,
 *   decoded ("The_Wand_S01E11.mp4", "S01"); empty for media without a path.
 * - inLibrary / favorite: the media is in VLC's media library, and marked as favorite there
 *   (the library's own flag, the one its "Favorites" use). setFavorite() changes it.
 * - playlistName: the first library playlist (by name) that holds the media.
 *
 * The library is only asked while a control shows these (watch() / unwatch(), counted), on the
 * media library thread; each media change asks again, older answers are dropped.
 */
class RdNowPlaying : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString fileName READ fileName NOTIFY mediaChanged FINAL)
    Q_PROPERTY(QString folderName READ folderName NOTIFY mediaChanged FINAL)
    Q_PROPERTY(bool inLibrary READ inLibrary NOTIFY libraryChanged FINAL)
    Q_PROPERTY(bool favorite READ favorite NOTIFY libraryChanged FINAL)
    Q_PROPERTY(QString playlistName READ playlistName NOTIFY libraryChanged FINAL)

public:
    RdNowPlaying(MainCtx* ctx, PlayerController* player, QObject* parent = nullptr);

    QString fileName() const { return m_fileName; }
    QString folderName() const { return m_folderName; }
    bool inLibrary() const { return m_mediaId > 0; }
    bool favorite() const { return m_favorite; }
    QString playlistName() const { return m_playlistName; }

    // a control shows the library values (counted)
    Q_INVOKABLE void watch();
    Q_INVOKABLE void unwatch();

    Q_INVOKABLE void setFavorite(bool favorite);

signals:
    void mediaChanged();
    void libraryChanged();

private:
    void onInputChanged();
    void query();
    void setLibraryValues(int64_t mediaId, bool favorite, const QString& playlistName);

    MainCtx* m_ctx = nullptr;
    PlayerController* m_player = nullptr;

    QString m_mrl;
    QString m_fileName;
    QString m_folderName;

    int m_watchers = 0;
    // the library values belong to this media (empty: not asked yet)
    QString m_queriedMrl;
    int m_generation = 0;

    int64_t m_mediaId = 0;
    bool m_favorite = false;
    QString m_playlistName;
};

#endif // RD_NOW_PLAYING_HPP
