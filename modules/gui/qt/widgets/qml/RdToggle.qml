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

// Redesign toggle (Figma component "Toggle", 68x32): square knob plus ON / OFF label. Figma flips
// it instantly on click (prototype "Change to", no transition) and has no hover variant: hovered,
// the knob and the label go one step brighter, as the other redesign controls do (tabs FG/A4 to
// FG/A3, labels FG/A3 to FG/A2, Primary button Accent/Main to Accent/Bright).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.AbstractButton {
    id: control

    checkable: true

    implicitWidth: VLCStyle.dp(68)
    implicitHeight: VLCStyle.dp(32)

    focusPolicy: Qt.StrongFocus
    // disabled: Figma's 30 % rows ("Settings - library")
    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

    Accessible.role: Accessible.CheckBox
    Accessible.checked: control.checked
    // accessibility tools (UI Automation's Toggle and Invoke patterns, screen readers) toggle it
    // like a click: T.AbstractButton's own toggle action only flips `checked` (no toggled(), so
    // the users of the toggle never save the change) and its press action only emits clicked()
    Accessible.onToggleAction: control._toggleByUser()
    Accessible.onPressAction: control._toggleByUser()

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // what a mouse click or Space does: flip, then toggled() and clicked()
    function _toggleByUser() {
        if (!control.enabled)
            return
        control.toggle()
        control.toggled()
        control.clicked()
    }

    // the pointing hand over the clickable controls
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.rdPalette.rdBgB2
        border.width: control.visualFocus ? VLCStyle.dp(1) : 0
        border.color: control.rdPalette.rdFgA3
    }

    contentItem: Item {
        // highlight behind the ON / OFF text, opposite the knob (Figma "Rectangle 11", 33x26:
        // x 3 when on, x 32 when off)
        Rectangle {
            id: track

            width: VLCStyle.dp(33)
            height: VLCStyle.dp(26)
            radius: VLCStyle.dp(3)
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? VLCStyle.dp(3) : parent.width - width - VLCStyle.dp(3)
            color: control.checked ? control.rdPalette.rdBgAccentBright : control.rdPalette.rdBgA4
        }

        // knob (Figma "Rectangle 12", 26x26)
        Rectangle {
            width: VLCStyle.dp(26)
            height: VLCStyle.dp(26)
            radius: VLCStyle.dp(3)
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? parent.width - width - VLCStyle.dp(3) : VLCStyle.dp(3)
            color: control.checked ? (control.hovered ? control.rdPalette.rdAccentMain : control.rdPalette.rdAccentDim)
                                   : (control.hovered ? control.rdPalette.rdFgA3 : control.rdPalette.rdFgA4)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: control.checked ? VLCStyle.dp(10) : parent.width - width - VLCStyle.dp(8)
            text: control.checked ? qsTr("ON") : qsTr("OFF")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_toggle
            color: control.checked ? (control.hovered ? control.rdPalette.rdAccentBright : control.rdPalette.rdAccentMain)
                                   : (control.hovered ? control.rdPalette.rdFgA2 : control.rdPalette.rdFgA3)
        }
    }
}
