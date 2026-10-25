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

// redesign (W8.1b, Figma "Player - customize" item "Bookmark"): adds a bookmark at the current
// time, as Ctrl + B (MLGlobalShortcuts, Decision 22): VLC keeps bookmarks in the media library
// and the queue sidebar's Bookmarks tab lists them
import QtQuick

import VLC.MainInterface
import VLC.MediaLibrary
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

Widgets.IconToolButton {
    id: root

    enabled: MainCtx.mediaLibraryAvailable && Player.isStarted

    text: VLCIcons.bookmark
    rdIcon: "bookmark"
    description: qsTr("Add Bookmark")

    // made on the first click (it reads the media's bookmarks from the library)
    property var _model: null

    onClicked: {
        if (!_model)
            _model = bookmarkModelComponent.createObject(root)
        if (_model)
            _model.add()
    }

    Component {
        id: bookmarkModelComponent

        MLBookmarkModel {
            player: Player
            ml: MediaLib
        }
    }

    AccessibleCompat.id: "addBookmarkButton"
}
