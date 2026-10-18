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

// redesign (W8.1b): a line of text about the playing media for the bars (the Customize Player
// items File Name, Artist Name, Folder Name, Playlist Name and the top bar's title): Inter 14
// FG/A2 as the top bar title (Figma "topbar"), elided when the bar is short of room. Empty, it
// takes no room; in Customize Player it then shows its name in FG/A3 so it can still be moved.
import QtQuick
import QtQuick.Layouts

import VLC.Style

Item {
    id: root

    property bool paintOnly: false

    property string text: ""
    // shown in Customize Player while there is nothing to show
    property string placeholder: ""
    property real maximumWidth: VLCStyle.dp(220, VLCStyle.scale)
    property int horizontalAlignment: Text.AlignLeft

    readonly property bool _placeholderShown: text === "" && paintOnly

    enabled: false

    implicitWidth: Math.min(label.implicitWidth, maximumWidth)
    implicitHeight: VLCStyle.dp(28, VLCStyle.scale)

    // the bar lets it shrink (and elide) down to this
    Layout.minimumWidth: Math.min(implicitWidth, VLCStyle.dp(40, VLCStyle.scale))

    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Text {
        id: label

        anchors.fill: parent

        text: root._placeholderShown ? root.placeholder : root.text
        elide: Text.ElideRight
        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
        color: root._placeholderShown ? VLCStyle.palette.rdFgA3 : VLCStyle.palette.rdFgA2
    }
}
