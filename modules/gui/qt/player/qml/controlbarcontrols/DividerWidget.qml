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

// redesign (W8.1b, Figma "Player - customize" item "Divider", the top bar's "Vector 26"): a
// thin vertical line between controls, in a 24 x 28 cell (Figma "Frame 6"): 18 px, 1.5 px
// stroke with round caps, Divider/Bright
import QtQuick

import VLC.Style

Item {
    id: root

    property bool paintOnly: false

    enabled: false

    implicitWidth: VLCStyle.dp(24, VLCStyle.scale)
    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

    // (not rounded through dp(): 1.5 would become 2)
    Rectangle {
        anchors.centerIn: parent
        width: 1.5 * VLCStyle.scale
        height: 19.5 * VLCStyle.scale
        radius: width / 2
        color: VLCStyle.palette.rdDividerBright
    }
}
