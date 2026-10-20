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

// redesign (Add Subtitles, W6.5): the field of the dialog's header (Figma "Frame 122": 34 px,
// BG/A5, radius 6, padding 5,8,5,8, gap 10, 24 px icon FG/A2, text Inter 14 FG/A1):
// - From Computer: the folder of the subtitles, "Videos / Shows / The Wand / S01"; a click picks
//   another folder (`editable: false`);
// - From OpenSubtitles: the search text, with the magnifier (video 6:12);
// - From Link: the link to a subtitle file.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.Control {
    id: root

    property string iconName: ""
    property string text: ""
    property string placeholderText: ""
    property bool editable: true
    property string accessibleName: placeholderText

    // a click on the field when it is not editable
    signal clicked()
    // Enter in the editable field
    signal accepted(string text)
    signal textEdited(string text)

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property alias input: input

    implicitHeight: VLCStyle.dp(34)

    // the text set from outside (a new target changes the search text) replaces what is typed
    onTextChanged: {
        if (input.text !== root.text)
            input.text = root.text
    }
    Component.onCompleted: input.text = root.text
    focusPolicy: editable ? Qt.NoFocus : Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: editable ? Accessible.EditableText : Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: root.clicked()

    Keys.onPressed: (event) => {
        if (!root.editable && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                               || event.key === Qt.Key_Space)) {
            event.accepted = true
            root.clicked()
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: (!root.editable && root.hovered) ? root.rdPalette.rdBgA4 : root.rdPalette.rdBgField
        border.width: (root.visualFocus || (input.activeFocus && (input.focusReason === Qt.TabFocusReason
                                                                  || input.focusReason === Qt.BacktabFocusReason)))
                      ? VLCStyle.dp(1) : 0
        border.color: root.rdPalette.rdFgA3
    }

    contentItem: Item {
        Widgets.RdIcon {
            id: icon

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            color: root.rdPalette.rdFgA2
        }

        T.TextField {
            id: input

            anchors.left: icon.right
            anchors.leftMargin: VLCStyle.dp(10)
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(8)
            // the whole height of the field takes clicks (the template has no implicit height)
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            visible: root.editable
            enabled: root.editable
            padding: 0
            verticalAlignment: TextInput.AlignVCenter
            selectByMouse: true
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA1
            selectionColor: root.rdPalette.rdAccentDim
            selectedTextColor: root.rdPalette.rdSelectionText
            placeholderText: root.placeholderText

            Accessible.name: root.accessibleName

            onTextEdited: root.textEdited(text)
            onAccepted: root.accepted(text)

            background: null
        }

        // T.TextField draws no placeholder (the styles do)
        Text {
            anchors.left: input.left
            anchors.right: input.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.editable && input.length === 0 && input.preeditText === ""
            text: root.placeholderText
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA4

            Accessible.ignored: true
        }

        // the folder: the end of a long path stays visible
        Text {
            anchors.left: input.left
            anchors.right: input.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.editable
            text: root.text !== "" ? root.text : root.placeholderText
            elide: Text.ElideLeft
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.text !== "" ? root.rdPalette.rdFgA1 : root.rdPalette.rdFgA4

            Accessible.ignored: true
        }

        MouseArea {
            anchors.fill: parent
            visible: !root.editable
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.forceActiveFocus(Qt.MouseFocusReason)
                root.clicked()
            }
        }
    }
}
