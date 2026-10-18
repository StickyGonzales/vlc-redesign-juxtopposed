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

// redesign (Add Subtitles, W6.5): a dropdown of the dialog's header (Figma components "target"
// 1959:5325 and "origin" 1963:5465, video 6:04-6:14): 200x34, BG/A5, radius 6, padding 5,8,5,12,
// value FG/A1, chevron FG/A2. The list (Figma "View Options" inside them) opens IN PLACE: 209 wide
// (4 px out on the left), padding 2, BG/A4, radius 6, drop shadow 35 % y 4 blur 13.8, rows 48 px
// (padding 2,14, radius 6), the current row BG/A3 over the field with the accent check; rows the
// dialog cannot use are dimmed and skipped.
// `model`: [{ text, enabled }].
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

T.AbstractButton {
    id: root

    property var model: []
    property int currentIndex: 0
    property int maxVisibleRows: 7

    signal activated(int index)

    readonly property SystemPalette rdPalette: VLCStyle.palette
    readonly property real _rowHeight: VLCStyle.dp(48)
    readonly property real _listPadding: VLCStyle.dp(2)

    function _enabledAt(index) {
        const entry = root.model[index]
        return !!entry && entry.enabled !== false
    }

    // the next usable row from `index` in direction `step`, -1 when none
    function _nextEnabled(index, step) {
        for (let i = index + step; i >= 0 && i < root.model.length; i += step) {
            if (_enabledAt(i))
                return i
        }
        return -1
    }

    function _activate(index) {
        if (!_enabledAt(index))
            return
        list.close()
        if (index !== currentIndex)
            root.activated(index)
    }

    implicitWidth: VLCStyle.dp(200)
    implicitHeight: VLCStyle.dp(34)

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.ComboBox
    Accessible.name: text
    Accessible.description: currentIndex >= 0 && model[currentIndex] ? model[currentIndex].text : ""

    onClicked: list.opened ? list.close() : list.open()

    function openList() {
        list.open()
    }

    // like a closed combo box: the arrows pick the previous / next value
    Keys.onUpPressed: (event) => {
        const i = _nextEnabled(currentIndex, -1)
        if (i >= 0)
            root.activated(i)
    }
    Keys.onDownPressed: (event) => {
        const i = _nextEnabled(currentIndex, 1)
        if (i >= 0)
            root.activated(i)
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        color: (root.hovered || list.opened) ? root.rdPalette.rdBgA4 : root.rdPalette.rdBgField
        border.width: root.visualFocus ? VLCStyle.dp(1) : 0
        border.color: root.rdPalette.rdFgA3
    }

    contentItem: Item {
        Text {
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(12)
            anchors.right: chevron.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter

            text: root.currentIndex >= 0 && root.model[root.currentIndex] ? root.model[root.currentIndex].text : ""
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA1
        }

        Widgets.RdIcon {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_direction-down"
            color: root.rdPalette.rdFgA2
        }
    }

    T.Popup {
        id: list

        readonly property int visibleRows: Math.max(1, Math.min(root.model.length, root.maxVisibleRows))
        // the row of the current value sits over the field (Figma "dropdown 1" / "dropdown 2")
        readonly property int currentRow: Math.min(Math.max(root.currentIndex, 0), visibleRows - 1)

        x: -VLCStyle.dp(4)
        y: -root._listPadding - currentRow * root._rowHeight - (root._rowHeight - root.height) / 2
        width: root.width + VLCStyle.dp(9)
        height: visibleRows * root._rowHeight + 2 * root._listPadding
        padding: root._listPadding

        // a click outside only closes the list (it does not reach the dialog under it)
        modal: true
        dim: false
        closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

        onAboutToShow: {
            listView.currentIndex = root.currentIndex
            listView.contentY = Math.max(0, root.currentIndex - currentRow) * root._rowHeight
            listView.forceActiveFocus(Qt.PopupFocusReason)
        }

        onClosed: {
            if (root.visible)
                root.forceActiveFocus(Qt.PopupFocusReason)
        }

        T.Overlay.modal: Item { }

        background: Rectangle {
            radius: VLCStyle.rd_radius_normal
            color: root.rdPalette.rdBgA4

            Widgets.RdShadow {
                color: root.rdPalette.rdListShadow
                yOffset: VLCStyle.dp(4)
                blurRadius: VLCStyle.dp(13.8)
            }
        }

        contentItem: ListView {
            id: listView

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.model
            keyNavigationEnabled: false

            Keys.onUpPressed: {
                const i = root._nextEnabled(currentIndex, -1)
                if (i >= 0) {
                    currentIndex = i
                    positionViewAtIndex(i, ListView.Contain)
                }
            }
            Keys.onDownPressed: {
                const i = root._nextEnabled(currentIndex, 1)
                if (i >= 0) {
                    currentIndex = i
                    positionViewAtIndex(i, ListView.Contain)
                }
            }
            Keys.onReturnPressed: root._activate(currentIndex)
            Keys.onEnterPressed: root._activate(currentIndex)
            Keys.onSpacePressed: root._activate(currentIndex)

            delegate: T.ItemDelegate {
                id: option

                required property int index
                required property var modelData

                width: ListView.view.width
                height: root._rowHeight
                enabled: modelData.enabled !== false
                hoverEnabled: true
                focusPolicy: Qt.NoFocus

                leftPadding: VLCStyle.dp(14)
                rightPadding: VLCStyle.dp(14)
                topPadding: VLCStyle.dp(2)
                bottomPadding: VLCStyle.dp(2)

                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.text
                Accessible.selected: index === root.currentIndex

                onClicked: root._activate(index)

                background: Rectangle {
                    radius: VLCStyle.rd_radius_normal
                    color: (option.index === root.currentIndex || option.hovered
                            || (option.index === listView.currentIndex && listView.activeFocus
                                && option.index !== root.currentIndex))
                           ? root.rdPalette.rdBgA3 : "transparent"
                }

                contentItem: Item {
                    Text {
                        anchors.left: parent.left
                        anchors.right: check.left
                        anchors.rightMargin: VLCStyle.dp(10)
                        anchors.verticalCenter: parent.verticalCenter

                        text: option.modelData.text
                        elide: Text.ElideRight
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: option.enabled ? root.rdPalette.rdFgA2 : root.rdPalette.rdFgA4
                    }

                    Widgets.RdIcon {
                        id: check

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: option.index === root.currentIndex
                        name: "check_state-active"
                    }
                }
            }
        }
    }
}
