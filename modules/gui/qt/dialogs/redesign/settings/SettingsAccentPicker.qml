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
// redesign: the accent colors of Settings > General (video 17:44-17:49, P8-05, P8-42, IB-43;
// Figma "Settings - global" "Accent color": a 320x36 BG/B2 strip, radius 6, padding 2, nine
// 32x32 cells 4 px apart, each a 20x20 square swatch (radius 1); the chosen cell has the
// BG/Accent Bright fill). Decision 15 colors, in her order. A click recolors the whole
// interface at once (MainCtx.accentColor, kept in "qt-accent-color").
// Cone extra (redesign/CUSTOM_ACCENT_NOTES.md): a tenth cell, "Custom", of the same size after
// them (the strip grows by one cell and gap, 356 wide); its swatch is the custom color (the last
// one typed while a preset is chosen, at 70 % like them) or a spectrum until there is one, and it
// opens the hex editor (RdAccentEditor) under it.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Rectangle {
    id: root

    // Decision 15 (figma/styles.txt); the first one is VLC's own accent
    readonly property var colors: ["#D37918", "#E15032", "#C49E23", "#19A234", "#18AAD3",
                                   "#185DD3", "#8E42FF", "#F052B3", "#AFAFAF"]
    readonly property var names: [qsTr("Orange"), qsTr("Red"), qsTr("Mustard"), qsTr("Green"),
                                  qsTr("Teal"), qsTr("Blue"), qsTr("Purple"), qsTr("Pink"),
                                  qsTr("Gray")]

    // no choice yet ("default") is VLC's orange
    readonly property int currentIndex: {
        const current = MainCtx.accentColor
        if (!current.valid)
            return 0
        return colors.indexOf(String(current).toUpperCase())
    }

    // the accent is none of the nine: the Custom cell is the chosen one
    readonly property bool customSelected: currentIndex < 0
    // the custom color the Custom cell shows: the accent while it is custom, else the last one
    // typed (kept in the interface settings); none yet: the spectrum
    property string _lastCustom: String(MainCtx.settingValue(customEditor.lastCustomKey, ""))
    readonly property color customColor: customSelected ? MainCtx.accentColor
                                                        : (_lastCustom !== "" ? Qt.color(_lastCustom) : "transparent")
    readonly property bool hasCustomColor: customSelected || _lastCustom !== ""

    // nine colors and Custom
    readonly property int _cellCount: colors.length + 1
    readonly property int _customIndex: colors.length

    // the cell Tab reaches: the chosen one
    readonly property int _focusIndex: customSelected ? _customIndex : currentIndex

    function select(index) {
        MainCtx.accentColor = Qt.color(colors[index])
    }

    // the Custom cell: the last custom color again, and its editor
    function selectCustom() {
        if (!customSelected && _lastCustom !== "")
            MainCtx.accentColor = Qt.color(_lastCustom)
        if (!customEditor.opened)
            customEditor.open()
    }

    // arrows choose the next color and keep the keyboard focus on it (a radio group); Custom is
    // chosen by the arrows only when it has a color, its editor opens with Enter or Space
    function _step(from, step) {
        const index = Math.max(0, Math.min(_cellCount - 1, from + step))
        if (index === _customIndex) {
            if (!customSelected && _lastCustom !== "")
                MainCtx.accentColor = Qt.color(_lastCustom)
        } else {
            select(index)
        }
        const cell = index === _customIndex ? customCell : cells.itemAt(index)
        if (cell)
            cell.forceActiveFocus(Qt.TabFocusReason)
    }

    // Figma's 320 strip and one more 31.6 cell with its 4 gap
    implicitWidth: VLCStyle.dp(320) + VLCStyle.dp(4) + _cellWidth
    readonly property real _cellWidth: (VLCStyle.dp(316) - VLCStyle.dp(4) * (colors.length - 1)) / colors.length
    implicitHeight: VLCStyle.dp(36)
    radius: VLCStyle.rd_radius_normal
    color: VLCStyle.palette.rdBgB2

    Accessible.role: Accessible.List
    Accessible.name: qsTr("Accent color")

    Row {
        id: cellRow

        anchors.fill: parent
        anchors.margins: VLCStyle.dp(2)
        spacing: VLCStyle.dp(4)

        Repeater {
            id: cells

            model: root.colors.length

            delegate: T.AbstractButton {
                id: cell

                // the pointing hand over the clickable controls
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                required property int index

                readonly property bool selected: root.currentIndex === index

                // Figma's cell: the nine cells and their gaps fill its 316 px strip
                width: root._cellWidth
                height: VLCStyle.dp(32)

                // one stop in the tab order; the arrows move between the colors
                focusPolicy: index === root._focusIndex ? Qt.StrongFocus : Qt.ClickFocus
                hoverEnabled: true

                Accessible.role: Accessible.RadioButton
                Accessible.checked: selected
                Accessible.name: root.names[index]

                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                Keys.onLeftPressed: root._step(index, -1)
                Keys.onRightPressed: root._step(index, 1)

                onClicked: root.select(index)

                background: Rectangle {
                    radius: VLCStyle.rd_radius_small
                    color: cell.selected ? VLCStyle.palette.rdBgAccentBright
                                         : (cell.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent")
                    border.width: cell.visualFocus ? VLCStyle.dp(1) : 0
                    border.color: VLCStyle.palette.rdFgA3
                }

                contentItem: Item {
                    Rectangle {
                        anchors.centerIn: parent
                        // Figma: the cell less its 6 px padding (19.6 x 20)
                        width: cell.width - 2 * VLCStyle.dp(6)
                        height: VLCStyle.dp(20)
                        radius: VLCStyle.dp(1)
                        color: root.colors[cell.index]
                        // Figma: the colors not chosen at 70 %
                        opacity: cell.selected ? 1.0 : 0.7
                    }
                }
            }
        }

        // Cone extra: the custom color
        T.AbstractButton {
            id: customCell

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            width: root._cellWidth
            height: VLCStyle.dp(32)

            focusPolicy: root._focusIndex === root._customIndex ? Qt.StrongFocus : Qt.ClickFocus
            hoverEnabled: true

            Accessible.role: Accessible.RadioButton
            Accessible.checked: root.customSelected
            Accessible.name: root.hasCustomColor ? qsTr("Custom color %1").arg(String(root.customColor).toUpperCase())
                                                 : qsTr("Custom color")

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
            Keys.onLeftPressed: root._step(root._customIndex, -1)
            Keys.onRightPressed: root._step(root._customIndex, 1)

            onClicked: root.selectCustom()

            background: Rectangle {
                radius: VLCStyle.rd_radius_small
                color: root.customSelected ? VLCStyle.palette.rdBgAccentBright
                                           : (customCell.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent")
                border.width: customCell.visualFocus ? VLCStyle.dp(1) : 0
                border.color: VLCStyle.palette.rdFgA3
            }

            contentItem: Item {
                Rectangle {
                    anchors.centerIn: parent
                    width: customCell.width - 2 * VLCStyle.dp(6)
                    height: VLCStyle.dp(20)
                    radius: VLCStyle.dp(1)
                    color: root.hasCustomColor ? root.customColor : "transparent"
                    opacity: root.customSelected ? 1.0 : 0.7
                    // no custom color yet: the spectrum says "any color"
                    gradient: root.hasCustomColor ? null : spectrum

                    Gradient {
                        id: spectrum

                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#E15032" }
                        GradientStop { position: 0.25; color: "#C49E23" }
                        GradientStop { position: 0.5; color: "#19A234" }
                        GradientStop { position: 0.75; color: "#185DD3" }
                        GradientStop { position: 1.0; color: "#F052B3" }
                    }
                }
            }
        }
    }

    Widgets.RdAccentEditor {
        id: customEditor

        parent: customCell
        x: customCell.width - width
        y: customCell.height + VLCStyle.dp(6)

        onLastCustomChanged: (hex) => {
            root._lastCustom = hex
        }

        // the keyboard focus goes back to the Custom cell
        onClosed: {
            if (customCell.visible)
                customCell.forceActiveFocus(Qt.OtherFocusReason)
        }
    }
}
