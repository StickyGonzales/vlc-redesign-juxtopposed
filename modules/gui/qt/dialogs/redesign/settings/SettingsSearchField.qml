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
// redesign: search field of the Settings dialog header (Figma "Frame 121": 200x34, radius 6,
// BG/A5, padding 5,8, 24 px search icon FG/A3, 10 px gap, "Search" placeholder Inter 14 FG/A4).
// The field has the focus when the dialog opens; its text cursor shows it (no border in Figma).
// Escape clears the text first; with an empty field it reaches the dialog (closes it).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.TextField {
    id: control

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.dp(200)
    implicitHeight: VLCStyle.dp(34)

    leftPadding: VLCStyle.dp(8) + VLCStyle.rd_iconSize + VLCStyle.dp(10)
    rightPadding: clearButton.visible ? clearButton.width + VLCStyle.dp(8) : VLCStyle.dp(8)

    placeholderText: qsTr("Search")
    placeholderTextColor: rdPalette.rdFgA4
    color: rdPalette.rdFg2
    selectionColor: rdPalette.rdAccentDim
    selectedTextColor: rdPalette.rdSelectionText
    verticalAlignment: TextInput.AlignVCenter
    font.family: VLCStyle.rd_fontFamily
    font.pixelSize: VLCStyle.rd_fontSize_label

    Accessible.name: qsTr("Search settings")

    Keys.onShortcutOverride: (event) => {
        if (event.key === Qt.Key_Escape && control.text !== "")
            event.accepted = true
    }
    Keys.onEscapePressed: (event) => {
        if (control.text !== "") {
            control.clear()
            event.accepted = true
        } else {
            event.accepted = false
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.rdPalette.rdBgField

        Widgets.RdIcon {
            x: VLCStyle.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            color: control.rdPalette.rdFgA3
        }
    }

    // T.TextField does not draw its placeholder (the Controls styles do)
    Text {
        x: control.leftPadding
        width: control.availableWidth
        anchors.verticalCenter: parent.verticalCenter
        visible: control.length === 0 && control.preeditText === ""
        text: control.placeholderText
        elide: Text.ElideRight
        font: control.font
        color: control.placeholderTextColor
    }

    // not in the design: a way to clear the search with the mouse
    T.AbstractButton {
        id: clearButton

        // the pointing hand over the clickable controls
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        visible: control.text !== ""
        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(4)
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: VLCStyle.rd_iconSize
        implicitHeight: VLCStyle.rd_iconSize

        focusPolicy: Qt.NoFocus
        hoverEnabled: true

        Accessible.role: Accessible.Button
        Accessible.name: qsTr("Clear search")

        onClicked: control.clear()

        contentItem: Item {
            Widgets.RdIcon {
                anchors.centerIn: parent
                name: "close"
                size: VLCStyle.dp(16)
                color: clearButton.hovered ? control.rdPalette.rdFgA2 : control.rdPalette.rdFgA3
            }
        }
    }
}
