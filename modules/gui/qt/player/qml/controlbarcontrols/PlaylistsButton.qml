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

// redesign (W8.1b, Figma "Player - customize" item "Playlists"): opens the library on its Playlists page. In
// the player it is the compact library next to the video (RdPanels.libraryOpen), elsewhere
// the library on screen; both show RdLibraryNav's location
import QtQuick

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

Widgets.IconToolButton {
    id: root

    enabled: MainCtx.mediaLibraryAvailable

    text: VLCIcons.playlist
    rdIcon: "playlist"
    description: qsTr("Playlists")

    onClicked: {
        RdLibraryNav.openRoot("playlists")
        if (MainCtx.playerView)
            RdPanels.libraryOpen = true
    }

    AccessibleCompat.id: "playlistsButton"
}
