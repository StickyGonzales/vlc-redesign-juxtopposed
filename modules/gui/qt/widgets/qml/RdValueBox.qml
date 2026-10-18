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

// Redesign value box (Figma "text_input": 140x36, padding 10,18,10,12, radius 6, BG/B2 with a
// 2 px BG/A4 inside stroke (accent while typing), Inter 14
// FG/A2). Shows a value; when editable, clicking it lets the user type a new one (Enter applies,
// Escape cancels). An optional color swatch (22x22, radius 2) sits at the right (Text Color).
// framed: false is a box without the stroke, 32 px tall (Settings colour fields "Frame 87", the
// Playback tab's Speed box "Frame 86" 5187:24542); the accent stroke still shows while typing.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.Control {
    id: control

    property string text: ""
    property bool editable: true
    property color swatch: "transparent"
    property bool showSwatch: false
    property int fontSize: VLCStyle.rd_fontSize_label
    // a name inside the box, left of the value (Figma Crop "Frame 87" 774:1024: "Top" FG/A3 at
    // 12, the value FG/A2 ending 40 px from the right edge)
    property string prefix: ""
    // a unit after the value, in FG/A4 (Figma "0 px": the "px" is overridden to FG/A4)
    property string suffix: ""
    // input validation while typing
    property var validator: null
    // the 2 px BG/A4 frame (Figma "text_input"); the color fields of Settings ("Frame 87") and
    // the start volume box have none
    property bool framed: true
    property real backgroundRadius: VLCStyle.rd_radius_normal
    // the text color: FG/A2 (FG/A3 in the sidebar's Speed box and Colors card; Figma shows a
    // value not in use at 40 %)
    property color textColor: rdPalette.rdFgA2

    signal edited(string text)

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property bool editing: input.activeFocus
    // a typed value not applied yet (Enter applies it, leaving the box drops it)
    readonly property bool dirty: editing && input.text !== control.text

    // drops a value being typed: the box shows the current value again (a wheel step moved it)
    function cancelEdit() {
        input.focus = false
    }

    implicitWidth: VLCStyle.dp(140)
    implicitHeight: framed ? VLCStyle.dp(36) : VLCStyle.dp(32)

    // the text sits 12 px inside the frame's 2 px stroke (Figma text at 14)
    leftPadding: framed ? VLCStyle.dp(14) : VLCStyle.dp(12)
    // the swatch sits 5 px inside the frame's 2 px stroke (Figma 4046:12377), 5 px from the edge
    // of a frameless box (800:1149)
    rightPadding: showSwatch ? (framed ? VLCStyle.dp(7) : VLCStyle.dp(5))
                             : (prefix !== "" ? VLCStyle.dp(40) : VLCStyle.dp(18))

    hoverEnabled: true
    // disabled: Figma's 30 % rows ("Settings - library")
    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

    background: Rectangle {
        radius: control.backgroundRadius
        color: control.rdPalette.rdBgB2
        // typing shows the accent frame even on an unframed box
        border.width: (control.framed || control.editing) ? VLCStyle.dp(2) : 0
        border.color: control.editing ? control.rdPalette.rdAccentMain : control.rdPalette.rdBgA4
    }

    contentItem: Item {
        Text {
            id: prefixText

            visible: control.prefix !== ""
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: control.prefix
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: control.fontSize
            color: control.rdPalette.rdFgA3
        }

        TextInput {
            id: input

            anchors.left: prefixText.visible ? prefixText.right : parent.left
            anchors.leftMargin: prefixText.visible ? VLCStyle.dp(8) : 0
            anchors.right: swatchRect.visible ? swatchRect.left : (suffixText.visible ? suffixText.left : parent.right)
            horizontalAlignment: prefixText.visible ? TextInput.AlignRight : TextInput.AlignLeft
            anchors.rightMargin: swatchRect.visible ? VLCStyle.dp(8) : 0
            anchors.verticalCenter: parent.verticalCenter

            readOnly: !control.editable
            activeFocusOnPress: control.editable
            activeFocusOnTab: control.editable
            clip: true
            selectByMouse: true
            validator: control.validator
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: control.fontSize
            color: control.textColor
            selectionColor: control.rdPalette.rdAccentMain
            selectedTextColor: control.rdPalette.rdFgB1
            cursorDelegate: Rectangle {
                width: VLCStyle.dp(1)
                color: control.rdPalette.rdAccentMain
                visible: input.activeFocus
            }

            Accessible.role: Accessible.EditableText
            Accessible.name: control.Accessible.name

            Binding on text {
                when: !input.activeFocus
                value: control.text
                // keep the shown value when editing starts
                restoreMode: Binding.RestoreNone
            }

            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll()
            }

            onAccepted: {
                control.edited(text)
                focus = false
            }

            // Escape cancels the edit before the player's Escape shortcut closes the panel
            Keys.onShortcutOverride: (event) => {
                if (event.key === Qt.Key_Escape)
                    event.accepted = true
            }

            Keys.onEscapePressed: (event) => {
                focus = false
                event.accepted = true
            }
        }

        Text {
            id: suffixText

            visible: control.suffix !== ""
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: " " + control.suffix
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: control.fontSize
            color: control.rdPalette.rdFgA4
        }

        Rectangle {
            id: swatchRect

            visible: control.showSwatch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: VLCStyle.dp(22)
            height: VLCStyle.dp(22)
            radius: VLCStyle.rd_radius_xsmall
            color: control.swatch
            // Figma: #FFFFFF 21 %, 1.5 px (dp() would round it to 2)
            border.width: 1.5 * VLCStyle.scale
            border.color: control.rdPalette.rdSwatchStroke
        }
    }
}
