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

// redesign (W8.1b, Figma "Player - customize" item "Thumbnail"): the playing media's cover
// (its artwork), 28 x 28 with rounded corners; the Figma placeholder (BG/A4) while it has none
import QtQuick

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style

Item {
    id: root

    property bool paintOnly: false

    enabled: false

    implicitWidth: VLCStyle.dp(28, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

    Accessible.role: Accessible.Graphic
    Accessible.name: qsTr("Cover")

    Rectangle {
        anchors.fill: parent
        radius: VLCStyle.rd_radius_small
        color: VLCStyle.palette.rdBgA4
        visible: cover.status !== Image.Ready
    }

    Widgets.ImageExt {
        id: cover

        anchors.fill: parent

        source: root.paintOnly ? "" : Player.artwork
        sourceSize: Qt.size(width, height)
        fillMode: Image.PreserveAspectCrop
        radius: VLCStyle.rd_radius_small
        visible: status === Image.Ready
    }
}
