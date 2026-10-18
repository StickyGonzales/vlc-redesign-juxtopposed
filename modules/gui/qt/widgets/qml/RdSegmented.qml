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

// Redesign segmented control (Figma component "Values": Relative / Pixels, Dark / Light / System,
// None / Horizontal / Vertical). Selected segment: BG/Accent Bright fill, Accent/Main text; in the
// light theme a solid Accent/Main fill with BG/A1 text, like Theme "Light" at video 17:43.
import QtQuick

import VLC.MainInterface
import VLC.Style

Rectangle {
    id: root

    property var model: []              // list of segment labels
    property int currentIndex: 0
    signal activated(int index)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    implicitWidth: VLCStyle.dp(213)
    implicitHeight: VLCStyle.dp(44)

    radius: VLCStyle.rd_radius_normal
    color: rdPalette.rdBgB2
    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

    // keyboard: Tab reaches the control, Left / Right pick the previous / next segment; the
    // focus ring is the FG/A3 border of the other redesign controls (not in Figma)
    activeFocusOnTab: true
    border.width: activeFocus ? VLCStyle.dp(1) : 0
    border.color: rdPalette.rdFgA3

    Accessible.role: Accessible.PageTabList
    Accessible.name: (currentIndex >= 0 && currentIndex < model.length) ? model[currentIndex] : ""

    function _step(delta) {
        const count = root.model.length
        if (count === 0)
            return
        const index = Math.max(0, Math.min(count - 1, root.currentIndex + delta))
        if (index !== root.currentIndex)
            root.activated(index)
    }

    Keys.onLeftPressed: (event) => {
        root._step(-1)
        event.accepted = true
    }
    Keys.onRightPressed: (event) => {
        root._step(1)
        event.accepted = true
    }

    Row {
        id: row

        anchors.fill: parent
        anchors.margins: VLCStyle.dp(2)
        spacing: VLCStyle.dp(2)

        Repeater {
            model: root.model

            delegate: Rectangle {
                id: segment

                required property int index
                required property var modelData

                readonly property bool selected: index === root.currentIndex

                width: (row.width - row.spacing * (root.model.length - 1)) / Math.max(1, root.model.length)
                height: row.height
                radius: VLCStyle.rd_radius_small
                color: selected ? (root.rdPalette.isDark ? root.rdPalette.rdBgAccentBright : root.rdPalette.rdAccentMain)
                                : (mouse.containsMouse ? root.rdPalette.rdBgA2 : root.rdPalette.rdBgA4)

                Text {
                    anchors.centerIn: parent
                    // a label longer than a narrow segment is elided instead of running into the
                    // next one
                    width: Math.min(implicitWidth, Math.max(0, segment.width - 2 * VLCStyle.dp(4)))
                    elide: Text.ElideRight
                    text: segment.modelData
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    // Figma "Values" (804:1208): FG/A3 on the segments not chosen, FG/A2 while
                    // hovered (dark only in Figma; the light FG/A3 would be 2.5:1 on BG/A4, so
                    // FG/A2 there)
                    color: segment.selected ? (root.rdPalette.isDark ? root.rdPalette.rdAccentMain : root.rdPalette.rdBgA1)
                                            : ((mouse.containsMouse || !root.rdPalette.isDark) ? root.rdPalette.rdFgA2
                                                                                               : root.rdPalette.rdFgA3)
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.activated(segment.index)
                    }
                }
            }
        }
    }
}
