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

// redesign (W8.1b, video 19:20-19:27, Figma "topbar" / "Player - customize"): one zone (left,
// center or right) of the editable top bar: the controls of a ControlListModel of the top bar
// layout (RdProfiles.topBarModel), with the top bar's sizes and gaps (Figma "topbar": icon
// buttons `iconWidth` x 32, `spacing` between controls, none next to a divider, whose 24 px
// cell is its own room). Any control of the control bar can be put here in Customize Player.
// Text controls shrink and elide when the zone is narrower than they are (`width` below
// `implicitWidth`). A bar holds a handful of controls, so they are all created.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls

FocusScope {
    id: root

    property alias model: filter.sourceModel

    // icon buttons' width (28 in the left zone, 36 between the window buttons) and the gap
    // between two controls (10, Figma "Frame 50")
    property real iconWidth: VLCStyle.dp(28, VLCStyle.scale)
    property real spacing: VLCStyle.dp(10, VLCStyle.scale)
    property int alignment: Qt.AlignLeft

    readonly property int count: repeater.count

    signal requestLockUnlockAutoHide(bool lock)
    ///incoming signal to request all menu and popup to close
    signal forceUnlock()

    implicitWidth: layout.implicitWidth
    implicitHeight: VLCStyle.rd_topBarHeight

    // the bars stay shown while the pointer is over the zone (as over the top bar's buttons)
    HoverHandler {
        id: hoverHandler

        onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
    }

    Component.onDestruction: {
        if (hoverHandler.hovered)
            root.requestLockUnlockAutoHide(false)
    }

    function gapBefore(index) {
        if (index <= 0)
            return 0
        const cur = repeater.itemAt(index)
        const prev = repeater.itemAt(index - 1)
        if (!cur || !prev)
            return root.spacing
        if (cur.controlId === ControlListModel.RD_DIVIDER || prev.controlId === ControlListModel.RD_DIVIDER)
            return 0
        return root.spacing
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        spacing: 0

        // the zone's controls sit at its start, center or end when it is wider than they are
        Item {
            visible: root.alignment !== Qt.AlignLeft
            Layout.fillWidth: true
        }

        Repeater {
            id: repeater

            model: ControlListFilter {
                id: filter

                player: Player
                ctx: MainCtx
            }

            delegate: Loader {
                id: loader

                required property int index
                required property var model

                readonly property int controlId: model.id

                source: PlayerControlbarControls.control(model.id).source

                focus: index === 0

                // re-evaluated when the zone's items change or this one loads
                Layout.leftMargin: (repeater.count, loader.item, root.gapBefore(index))
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: !!item && item.Layout.minimumWidth > 0
                Layout.minimumWidth: Layout.fillWidth ? item.Layout.minimumWidth : (item ? item.implicitWidth : 0)
                Layout.maximumWidth: item ? item.implicitWidth : 0
                Layout.preferredWidth: item ? item.implicitWidth : 0
                Layout.preferredHeight: item ? item.implicitHeight : 0

                onLoaded: {
                    // Figma "topbar": the icons are 24 px in a 28 x 32 button
                    if (item.rdMinimumWidth !== undefined) {
                        item.rdMinimumWidth = Qt.binding(() => root.iconWidth)
                        item.rdMinimumHeight = VLCStyle.rd_iconButtonHeight
                        item.font.pixelSize = VLCStyle.rd_iconSize
                    }

                    item.focus = Qt.binding(() => item.enabled && item.visible)
                    item.Navigation.parentItem = root
                    if (typeof item.activeFocusOnTab === "boolean")
                        item.activeFocusOnTab = true

                    if (item.requestLockUnlockAutoHide)
                        item.requestLockUnlockAutoHide.connect(root.requestLockUnlockAutoHide)
                    if (item.forceUnlock)
                        root.forceUnlock.connect(item.forceUnlock)

                    root._chain()
                }
            }

            onItemRemoved: Qt.callLater(root._chain)
        }

        Item {
            visible: root.alignment === Qt.AlignHCenter
            Layout.fillWidth: true
        }
    }

    // keyboard: left / right go along the zone's controls
    function _chain() {
        let previous = null
        for (let i = 0; i < repeater.count; ++i) {
            const loader = repeater.itemAt(i)
            const item = loader ? loader.item : null
            if (!item)
                continue
            item.Navigation.leftItem = previous
            item.Navigation.rightItem = null
            if (previous)
                previous.Navigation.rightItem = item
            previous = item
        }
    }
}
