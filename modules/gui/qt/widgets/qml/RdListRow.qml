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

// Redesign list row of the sidebars (Figma "Frame 39": 360x32, padding 0,4): optional accent
// number (chapters), the title in FG/A1 (accent when current), a detail on the right in FG/A3
// (time, duration). Hover and selection use BG/A2 and BG/A1.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.AbstractButton {
    id: row

    // the pointing hand over the clickable controls
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    property int number: 0
    property string title: ""
    property string detail: ""
    property bool current: false
    property bool selected: false
    // space before the title of a row without a number (queue: 4 after the handle; Figma
    // "bookmarks" rows have none)
    property real titleInset: VLCStyle.dp(4)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    Layout.fillWidth: true
    implicitHeight: VLCStyle.rd_rowHeight

    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.ListItem
    Accessible.name: title

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    background: Rectangle {
        radius: VLCStyle.rd_radius_small
        color: row.selected ? row.rdPalette.rdBgA1
             : (row.hovered || row.visualFocus) ? row.rdPalette.rdBgA2 : "transparent"
    }

    contentItem: Item {
        Text {
            id: numberText

            visible: row.number > 0
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? VLCStyle.dp(34) : 0
            text: row.number
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            font.weight: Font.Medium
            color: row.rdPalette.rdAccentMain
        }

        Text {
            // Figma "Frame 39" of "chapters": the title at x 48 (number box 4 + 34, gap 10), fixed
            // from the row's edge: anchored to the number box it landed 3 px further right
            anchors.left: parent.left
            anchors.leftMargin: numberText.visible ? VLCStyle.dp(48) : row.titleInset
            anchors.right: detailText.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.title
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: row.current ? row.rdPalette.rdAccentMain
                               : (row.hovered ? row.rdPalette.rdFg2 : row.rdPalette.rdFgA1)
        }

        Text {
            id: detailText

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(4)
            anchors.verticalCenter: parent.verticalCenter
            text: row.detail
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: row.rdPalette.rdFgA3
        }
    }
}
