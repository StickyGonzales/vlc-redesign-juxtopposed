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

// redesign (W8.1b, Figma "Player - customize" item "Favorite", video 19:26): marks the playing
// media as a favorite of the media library (the library's own flag), filled heart when it is
// one; greyed out for media that are not in the library
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

Widgets.IconToolButton {
    id: root

    enabled: !paintOnly && RdNowPlaying.inLibrary

    text: VLCIcons.bookmark
    rdIcon: "favorite"
    rdIconChecked: "favorite_state-active"
    description: checked ? qsTr("Remove from Favorites") : qsTr("Add to Favorites")

    checked: !paintOnly && RdNowPlaying.favorite

    onClicked: RdNowPlaying.setFavorite(!RdNowPlaying.favorite)

    // the library is asked about the media only while it is shown for real (not as the paint
    // only copy in Customize Player, which becomes paint only after it is made)
    property bool _watching: false

    function _updateWatching() {
        const wanted = !paintOnly
        if (wanted === _watching)
            return
        _watching = wanted
        if (wanted)
            RdNowPlaying.watch()
        else
            RdNowPlaying.unwatch()
    }

    onPaintOnlyChanged: _updateWatching()
    Component.onCompleted: _updateWatching()
    Component.onDestruction: {
        if (_watching)
            RdNowPlaying?.unwatch()
    }

    AccessibleCompat.id: "favoriteButton"
}
