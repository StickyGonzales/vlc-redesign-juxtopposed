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

// Redesign dropdown (Figma component "Dropdown", 364x48): BG/B2 frame with a BG/A4 inner row
// (radius 6 / 4), value FG/A2, chevron at the right. The list opens IN PLACE over the field
// (current row where the field was) with a soft shadow; the current item has an accent check.
// Set openUpward for footers (preset selector).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Style

T.ComboBox {
    id: control

    // the pointing hand over the clickable controls
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    property bool openUpward: false
    property int maxVisibleRows: 7
    // a list without a frame or inner row: BG/B1, FG/A3 text (Figma "Gradient" 673:1670)
    property bool frameless: false

    // the design's wording for entries whose text comes from VLC, e.g. { "Disable": "Disabled" }
    // (Figma labels); entries not listed keep VLC's text
    property var displayNames: ({})

    function displayName(text) {
        const name = control.displayNames[text]
        return name !== undefined ? name : text
    }

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.dp(364)
    implicitHeight: VLCStyle.dp(48)

    font.family: VLCStyle.rd_fontFamily
    font.pixelSize: VLCStyle.rd_fontSize_label

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // accessibility tools (UI Automation's Invoke pattern) open the list as a click does; T.ComboBox
    // has no action of its own. Its rows (RdOptionRow) are invoked like a click, which picks one
    // (activated())
    Accessible.onPressAction: {
        if (!control.enabled)
            return
        if (control.popup.visible)
            control.popup.close()
        else
            control.popup.open()
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: control.frameless ? (control.hovered ? control.rdPalette.rdBgA4 : control.rdPalette.rdBgB1)
                            : control.rdPalette.rdBgB2
        border.width: control.frameless && control.visualFocus ? VLCStyle.dp(1) : 0
        border.color: control.rdPalette.rdFgA3

        Rectangle {
            visible: !control.frameless
            anchors.fill: parent
            anchors.margins: VLCStyle.dp(2)
            radius: VLCStyle.rd_radius_small
            color: control.hovered ? control.rdPalette.rdBgA2 : control.rdPalette.rdBgA4
            border.width: control.visualFocus ? VLCStyle.dp(1) : 0
            border.color: control.rdPalette.rdFgA3
        }
    }

    contentItem: Text {
        leftPadding: control.frameless ? VLCStyle.dp(18) : VLCStyle.dp(16)
        rightPadding: VLCStyle.dp(40)
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: control.displayName(control.displayText)
        font: control.font
        color: control.frameless ? control.rdPalette.rdFgA3 : control.rdPalette.rdFgA2
    }

    // disabled (no choices, dependent setting): Figma's 30 % rows ("Settings - library")
    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

    // the chevron sits 16 px from the edge (Figma "option" 2372:8360: padding 14 inside the 2 px
    // frame); 14 in the frameless list (673:1670)
    indicator: RdIcon {
        x: control.width - width - (control.frameless ? VLCStyle.dp(14) : VLCStyle.dp(16))
        y: (control.height - height) / 2
        name: control.openUpward ? "chevron_direction-up" : "chevron_direction-down"
        color: control.rdPalette.rdFgA2
    }

    delegate: RdOptionRow {
        required property int index
        required property var model

        width: ListView.view ? ListView.view.width : implicitWidth
        height: VLCStyle.dp(44)
        radius: VLCStyle.rd_radius_small
        text: control.displayName(model[control.textRole] !== undefined ? model[control.textRole]
                                  : (model.modelData !== undefined ? model.modelData : model.display))
        selected: control.currentIndex === index
        highlighted: control.highlightedIndex === index
    }

    // a dialog opening (Ctrl+P, Ctrl+N, ...) closes the list first
    Connections {
        target: DialogsProvider

        function onDialogOpening() {
            control.popup.close()
        }
    }

    popup: T.Popup {
        readonly property real rowHeight: VLCStyle.dp(44) + VLCStyle.dp(2)
        readonly property real listHeight: Math.min(control.count, control.maxVisibleRows) * rowHeight + VLCStyle.dp(4)

        width: control.width
        height: listHeight

        // like a native drop-down list, a click outside only closes the list: it does not
        // also reach what is under it (the video, which would pause, or a panel that would
        // close with the list)
        modal: true
        dim: false
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside
        y: control.openUpward ? control.height - height
                              : -Math.min(control.currentIndex, control.maxVisibleRows - 1) * rowHeight
        padding: VLCStyle.dp(2)

        contentItem: ListView {
            clip: true
            spacing: VLCStyle.dp(2)
            implicitHeight: contentHeight
            model: control.delegateModel
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
        }

        background: Rectangle {
            radius: VLCStyle.rd_radius_normal
            color: control.rdPalette.rdBgA4

            // Figma "Options" 2372:8307: drop shadow #000000 35 %, y 4, blur 13.8
            RdShadow {
                color: control.rdPalette.rdListShadow
                yOffset: VLCStyle.dp(4)
                blurRadius: VLCStyle.dp(13.8)
            }
        }
    }
}
