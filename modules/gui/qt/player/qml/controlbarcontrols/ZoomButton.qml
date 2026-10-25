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

// redesign (W8.1b, Figma "Player - customize" item "Zoom"): VLC's video zoom (the video tab's
// Zoom, Player.zoom), as a list of its values
import QtQuick

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

ChoiceMenuButton {
    id: root

    enabled: !paintOnly && Player.hasVideoOutput

    text: VLCIcons.aspect_ratio
    rdIcon: "zoom"
    description: qsTr("Zoom")

    AccessibleCompat.id: "zoomButton"

    Repeater {
        model: root.paintOnly ? null : Player.zoom

        delegate: Widgets.RdOptionRow {
            required property int index
            required property var model

            text: model.display
            selected: !!model.checked
            onClicked: Player.zoom.toggleIndex(index)
        }
    }
}
