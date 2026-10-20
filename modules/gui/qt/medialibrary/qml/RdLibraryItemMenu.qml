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

// redesign: the "..." menus of the library (Figma "file context menu" F-12, "folder context
// menu" IB-04 / P5-15, "playlist context menu" F-11; video 10:52-10:57, 13:30-13:33).
//   openForItem(): the menu of a row (file, folder, playlist, album, artist, genre, stream)
//   openForPage(): the menu of the "..." button of the page header
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Dialogs
import VLC.MediaLibrary

Item {
    id: root

    // the page the menu belongs to (RdLibraryNav location)
    property var location: RdLibraryNav.location

    // the favorite state of the playlist shown by the page (its header "...", Figma "playlist
    // context menu" F-11): the location does not carry it, so it is read when the page opens,
    // off the UI thread, and the menu still opens at once
    property var _pageFavorite: undefined

    function _readPageFavorite() {
        _pageFavorite = undefined
        const loc = root.location
        if (!loc || loc.page !== "playlist" || !loc.id)
            return
        RdLibraryStore.playlistFavorite(loc.id, (favorite) => {
            if (root.location === loc)
                root._pageFavorite = favorite
        })
    }

    onLocationChanged: _readPageFavorite()
    Component.onCompleted: _readPageFavorite()

    function _fileEntries(item) {
        const isLocal = (item.mrl ?? "").startsWith("file://")
        const isMl = item.kind === "media" && item.id && item.id.isValid()
        const entries = [
            { text: qsTr("Play"), icon: "playback_two-tone-yes", action: () => RdLibraryActions.play(item) }
        ]
        if (isMl) {
            entries.push(item.watched
                ? { text: qsTr("Mark as Unwatched"), icon: "check_state-selected_two-tone-yes",
                    action: () => RdLibraryActions.setWatched(item, false) }
                : { text: qsTr("Mark as Watched"), icon: "check_state-selected_two-tone-yes",
                    action: () => RdLibraryActions.setWatched(item, true) })
            // only where the model knows the favorite state, so it can be cleared again
            if (item.isFavorite !== undefined)
                entries.push({ text: qsTr("Favorite"), icon: "favorite_two-tone-yes", selected: !!item.isFavorite,
                               action: () => RdLibraryActions.toggleFavorite(item) })
        }
        entries.push({ text: qsTr("Stream"), icon: "streaming_two-tone-yes", action: () => RdLibraryActions.stream(item) })
        entries.push({ text: qsTr("Convert"), icon: "swap_two-tone-yes", action: () => RdLibraryActions.convert(item) })
        entries.push({ text: qsTr("Add to Queue"), icon: "queue_two-tone-yes", action: () => RdLibraryActions.addToQueue(item) })
        if (isMl)
            entries.push({ text: qsTr("Add to Playlist"), icon: "playlist_two-tone-yes", submenu: true, chevron: false,
                           action: (row) => { playlistMenu.mediaItems = [item.id]; playlistMenu.openBeside(row) } })
        if (isLocal) {
            // Windows' file manager by its name, the others' (Linux) in general
            entries.push({ text: Qt.platform.os === "windows" ? qsTr("Show in File Explorer") : qsTr("Show in File Manager"),
                           icon: "folder_two-tone-yes",
                           action: () => RdLibraryActions.showInFileExplorer(item) })
            if (root.location.page !== "folder")
                entries.push({ text: qsTr("Go to Source"), icon: "arrow_two-tone-yes_direction-right",
                               action: () => RdLibraryActions.goToSource(item) })
        }
        // the Add Subtitles dialog for this file (W6.5)
        entries.push({ text: qsTr("Add Subtitle Tracks"), icon: "subtitles_two-tone-yes",
                       action: () => AddSubtitles.open({ mrl: item.mrl ?? "" }) })
        entries.push({ text: qsTr("Add Audio Tracks"), icon: "waveform_two-tone-yes",
                       action: () => RdLibraryActions.addTracks(item, false) })
        if (isMl)
            entries.push({ text: qsTr("Properties & Metadata"), icon: "info_two-tone-yes",
                           action: () => RdLibraryActions.properties(item) })
        return entries
    }

    function _playlistEntries(item) {
        return [
            { text: qsTr("Play"), icon: "playback_two-tone-yes", action: () => RdLibraryActions.play(item) },
            // only where the model knows the favorite state, so it can be cleared again
            item.isFavorite !== undefined ? { text: qsTr("Favorite"), icon: "favorite_two-tone-yes", selected: !!item.isFavorite,
                                              action: () => {
                                                  RdLibraryActions.toggleFavorite(item)
                                                  // the page's own state: the next menu shows the new one
                                                  if (item.isPage)
                                                      root._pageFavorite = !item.isFavorite
                                              } } : null,
            { text: qsTr("Shuffle"), icon: "shuffle_two-tone-yes_direction-right", action: () => RdLibraryActions.shuffle(item) },
            { text: qsTr("Export Playlist"), icon: "save_two-tone-yes",
              action: () => RdLibraryStore.exportPlaylist(item.id, item.title) },
            { text: qsTr("Add to Queue"), icon: "queue_two-tone-yes", action: () => RdLibraryActions.addToQueue(item) },
            // the Add Subtitles dialog (W6.5) on "To This Playlist", with the playlist's media
            { text: qsTr("Add Subtitle Tracks"), icon: "subtitles_two-tone-yes",
              action: () => RdLibraryStore.playlistMedia(item.id, (mrls) => AddSubtitles.open({
                  target: "playlist", items: mrls, title: item.title ?? "" })) },
            // audio tracks are added to the file that is playing
            { text: qsTr("Add Audio Tracks"), icon: "waveform_two-tone-yes", enabled: Player.isStarted,
              action: () => DialogsProvider.loadAudioFile() },
            { text: qsTr("Properties & Metadata"), icon: "info_two-tone-yes",
              action: () => RdLibraryNav.playlistDialogRequested({ playlist: item }) },
            { text: qsTr("Delete Playlist"), icon: "close",
              action: () => RdLibraryNav.confirmRequested({
                  title: qsTr("Delete Playlist"),
                  message: qsTr("Delete the playlist \"%1\"? Its media stay in the library.").arg(item.title ?? ""),
                  button: qsTr("Delete"),
                  action: () => RdLibraryStore.deletePlaylist(item.id)
              }) }
        ].filter((entry) => !!entry)
    }

    function _containerEntries(item) {
        return [
            { text: qsTr("Play"), icon: "playback_two-tone-yes", action: () => RdLibraryActions.play(item) },
            // only where the model knows the favorite state, so it can be cleared again
            item.isFavorite !== undefined ? { text: qsTr("Favorite"), icon: "favorite_two-tone-yes", selected: !!item.isFavorite,
                                              action: () => RdLibraryActions.toggleFavorite(item) } : null,
            { text: qsTr("Shuffle"), icon: "shuffle_two-tone-yes_direction-right", action: () => RdLibraryActions.shuffle(item) },
            { text: qsTr("Add to Queue"), icon: "queue_two-tone-yes", action: () => RdLibraryActions.addToQueue(item) },
            { text: qsTr("Add to Playlist"), icon: "playlist_two-tone-yes", submenu: true, chevron: false,
              action: (row) => { playlistMenu.mediaItems = [item.id]; playlistMenu.openBeside(row) } }
        ].filter((entry) => !!entry)
    }

    // the folder menu: the header "..." of folder pages and the "..." of folder rows
    function _folderEntries(folder, category) {
        const entries = [
            { text: qsTr("Add File"), icon: "add", action: () => RdLibraryActions.addFiles(null) },
            // the picker opens in the folder the menu belongs to
            { text: qsTr("Add Folder"), icon: "new-folder_two-tone-yes",
              action: () => RdLibraryActions.addFolder(category, folder ? folder.mrl : "") },
            // the Add Subtitles dialog (W6.5) on "To This Folder"; without a folder (a page header
            // with none), for the file that is playing
            { text: qsTr("Edit Subtitle Tracks"), icon: "subtitles_two-tone-yes", enabled: !!folder || Player.isStarted,
              action: () => AddSubtitles.open(folder ? { target: "folder", folder: folder.mrl ?? "" } : {}) },
            // audio tracks are added to the file that is playing
            { text: qsTr("Edit Audio Tracks"), icon: "waveform_two-tone-yes", enabled: Player.isStarted,
              action: () => DialogsProvider.loadAudioFile() },
            { text: qsTr("Resync"), icon: "refresh_two-tone-yes",
              action: () => RdLibraryStore.reloadFolder(folder ? folder.mrl : "") },
            { text: qsTr("Info"), icon: "info_two-tone-yes", enabled: !!folder, action: () => RdLibraryNav.infoRequested(folder) }
        ]
        // a library folder of the category's root can leave the category
        if (folder && folder.isRoot)
            entries.push({ text: qsTr("Remove from Library"), icon: "close",
                           action: () => RdLibraryNav.confirmRequested({
                               title: qsTr("Remove from Library"),
                               message: qsTr("Remove \"%1\" from the library? The files stay on disk, and the folders inside it that you added to the library stay in it.").arg(folder.title ?? ""),
                               button: qsTr("Remove"),
                               action: () => RdLibraryStore.removeFolder(category, folder.mrl)
                           }) })
        return entries
    }

    function openForItem(item, button, category) {
        let entries
        switch (item.kind) {
        case "folder": entries = _folderEntries(item, category); break
        case "playlist": entries = _playlistEntries(item); break
        case "album":
        case "artist":
        case "genre": entries = _containerEntries(item); break
        case "streamList":
            entries = [
                { text: qsTr("Play"), icon: "playback_two-tone-yes", action: () => RdLibraryActions.play(item) },
                { text: qsTr("Add to Queue"), icon: "queue_two-tone-yes", action: () => RdLibraryActions.addToQueue(item) },
                { text: qsTr("Remove"), icon: "close", action: () => RdLibraryStore.removeStreamList(item.index) }
            ]
            break
        default: entries = _fileEntries(item)
        }
        menu.entries = entries
        // Figma row "..." menus: overlay offset -16, 34 from the icon
        menu.openOffset(button, -VLCStyle.dp(16), VLCStyle.dp(34))
    }

    // compact: the "..." next to the video; Figma overlay offset -11, 30 there, -235, 30 in the
    // full library
    function openForPage(button, compact) {
        const loc = root.location
        let entries
        switch (loc.page) {
        case "folder":
            entries = _folderEntries({ kind: "folder", id: loc.id, mrl: loc.mrl, title: loc.title,
                                       isRoot: loc.crumbs.length === (loc.category === "music" ? 3 : 2) },
                                     loc.category)
            break
        case "videos":
            entries = _folderEntries(null, "video")
            break
        case "music":
        case "songs":
        case "albums":
        case "artists":
        case "genres":
        case "collection":
            entries = _folderEntries(null, "music")
            break
        case "playlist":
            entries = _playlistEntries({ kind: "playlist", id: loc.id, title: loc.title,
                                         isFavorite: root._pageFavorite, isPage: true })
            break
        case "playlists":
            entries = [{ text: qsTr("Create playlist"), icon: "add", action: () => RdLibraryNav.playlistDialogRequested({ items: [] }) }]
            break
        case "network":
        case "streams":
        case "service":
        case "browse":
            entries = [{ text: qsTr("Add Network Stream"), icon: "add", action: () => RdLibraryActions.openNetworkStream() }]
            break
        case "recent":
            entries = [{ text: qsTr("Clear Recent"), icon: "close", action: () => RdLibraryStore.clearHistory() }]
            break
        default:
            entries = [
                { text: qsTr("Add File"), icon: "add", action: () => RdLibraryActions.addFiles(null) },
                { text: qsTr("Add Folder"), icon: "new-folder_two-tone-yes", action: () => RdLibraryActions.addFolder("video") }
            ]
        }
        menu.entries = entries
        menu.openOffset(button, compact ? -VLCStyle.dp(11) : -VLCStyle.dp(235), VLCStyle.dp(30))
    }

    function close() {
        menu.close()
        playlistMenu.close()
    }

    RdLibraryMenu {
        id: menu
    }

    RdAddToPlaylistMenu {
        id: playlistMenu
    }
}
