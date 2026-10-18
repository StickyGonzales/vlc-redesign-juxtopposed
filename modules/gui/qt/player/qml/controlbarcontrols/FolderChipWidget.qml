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

// redesign (W8.1b, the top bar's folder chip, Figma "Frame 12", video 11:24-11:31): the folder
// icon and the name of the folder that holds the playing file (82 x 28 at least, radius 6, gap
// 4); a click opens the compact library on that folder (Player.qml, RdPanels.libraryRequested).
// For media that are not in a folder it takes no room (the bar owns its visibility).
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

T.AbstractButton {
    id: root

    property bool paintOnly: false

    readonly property string folderName: paintOnly ? qsTr("Folder") : RdNowPlaying.folderName

    // the pointing hand over the clickable controls
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    readonly property bool _shown: folderName !== ""

    enabled: MainCtx.playerView && _shown
    opacity: _shown ? 1 : 0

    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)
    implicitWidth: _shown ? Math.max(VLCStyle.dp(82, VLCStyle.scale), chipRow.implicitWidth + VLCStyle.dp(8, VLCStyle.scale))
                          : 0

    focusPolicy: Qt.StrongFocus

    Accessible.name: qsTr("Open folder %1 in the library").arg(folderName)

    onClicked: RdPanels.libraryRequested(true)

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: (root.hovered && !root.paintOnly) ? VLCStyle.palette.rdHoverOverlay : "transparent"
        border.width: root.visualFocus ? VLCStyle.dp(1) : 0
        border.color: VLCStyle.palette.rdFgA3
    }

    contentItem: Row {
        id: chipRow

        spacing: VLCStyle.dp(4, VLCStyle.scale)
        leftPadding: VLCStyle.dp(4, VLCStyle.scale)

        Widgets.RdIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: "folder"
            color: VLCStyle.palette.rdFgA2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.folderName
            elide: Text.ElideRight
            width: Math.min(implicitWidth, VLCStyle.dp(220, VLCStyle.scale))
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA2
        }
    }
}
