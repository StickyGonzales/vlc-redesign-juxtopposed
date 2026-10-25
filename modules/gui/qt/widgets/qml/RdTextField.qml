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

// Redesign text input (Figma "Frame 86"): BG/B2 fill, 2 px BG/A4 border, radius 6,
// padding 8,18,8,12, placeholder FG/A4, text FG/2. Border turns accent with keyboard focus.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.TextField {
    id: control

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // the value the field stands for, when it has one (a setting): a text that differs from it
    // and was written while the field is not being typed in comes from an accessibility tool (UI
    // Automation's Value pattern sets `text` directly, without focus, so the edit never
    // finishes); it ends the edit (editingFinished()) as leaving the field does. Checked once the
    // bindings have settled, so the value's own updates of `text` never count
    property var committedText: undefined

    readonly property bool _keyboardFocus: activeFocus && (focusReason === Qt.TabFocusReason
                                                           || focusReason === Qt.BacktabFocusReason)

    function _takeOutsideText() {
        if (!activeFocus && !readOnly && committedText !== undefined && text !== String(committedText))
            editingFinished()
    }

    onTextChanged: {
        if (!activeFocus && committedText !== undefined)
            Qt.callLater(_takeOutsideText)
    }

    implicitWidth: VLCStyle.dp(240)
    implicitHeight: VLCStyle.dp(37)

    topPadding: VLCStyle.dp(8)
    bottomPadding: VLCStyle.dp(8)
    leftPadding: VLCStyle.dp(14)    // Figma 12 inside the 2 px stroke (text at x 14)
    rightPadding: VLCStyle.dp(20)   // Figma 18 inside the 2 px stroke

    font.family: VLCStyle.rd_fontFamily
    font.pixelSize: VLCStyle.rd_fontSize_label
    color: rdPalette.rdFg2
    placeholderTextColor: rdPalette.rdFgA4
    selectionColor: rdPalette.rdAccentDim
    selectedTextColor: rdPalette.rdSelectionText
    verticalAlignment: TextInput.AlignVCenter

    // QtQuick.Templates draw no placeholder (the Basic style adds one), so draw it here
    Text {
        x: control.leftPadding
        y: control.topPadding
        width: control.width - control.leftPadding - control.rightPadding
        height: control.height - control.topPadding - control.bottomPadding

        visible: control.length === 0 && control.preeditText === ""
        text: control.placeholderText
        font: control.font
        color: control.placeholderTextColor
        verticalAlignment: control.verticalAlignment
        horizontalAlignment: control.horizontalAlignment
        elide: Text.ElideRight

        Accessible.ignored: true
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.rdPalette.rdBgB2
        border.width: VLCStyle.dp(2)
        // accent only for keyboard focus: the video (13:19) shows no accent border while typing
        border.color: control._keyboardFocus ? control.rdPalette.rdAccentMain
                                             : (control.hovered ? control.rdPalette.rdDividerBright
                                                                : control.rdPalette.rdBgA4)
    }
}
