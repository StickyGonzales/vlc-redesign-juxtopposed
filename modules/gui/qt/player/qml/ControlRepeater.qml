/*****************************************************************************
 * Copyright (C) 2023 VLC authors and VideoLAN
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
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.PlayerControls
import VLC.PlayerControls as PC

Repeater {
    id: repeater

    // redesign: Figma control bar ("Controls": Frame 25 / 15 / 23 and the last Icon Wrapper):
    // icon buttons are 30 wide; baseSpacing (the layout spacing, 8) between controls,
    // iconSpacing between two icon buttons (8 in the transport group, 12 in the track buttons
    // group), 20 after the volume group and before the queue button
    property bool figmaGaps: false
    property real baseSpacing: 0
    property real iconSpacing: baseSpacing

    function _isIconButton(loader) {
        return !!loader && !!loader.item && loader.item.rdMinimumWidth !== undefined
    }

    function gapBefore(index) {
        if (index <= 0)
            return 0
        const cur = itemAt(index)
        const prev = itemAt(index - 1)
        if (!cur || !prev)
            return baseSpacing
        if (cur.controlId === ControlListModel.PLAYLIST_BUTTON || prev.controlId === ControlListModel.VOLUME)
            return VLCStyle.rd_controlBarSpacing
        if (_isIconButton(cur) && _isIconButton(prev))
            return iconSpacing
        return baseSpacing
    }

    property int alignment: Qt.AlignVCenter

    property real availableWidth: Number.MAX_VALUE
    property real availableHeight: Number.MAX_VALUE

    signal requestLockUnlockAutoHide(bool lock)
    signal menuOpened(var menu)
    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // NOTE: We apply the 'navigation chain' after adding the item.
    onItemAdded: (index, item) => {
        item.applyNavigation()
    }

    onItemRemoved: (index, item) => {
        // NOTE: We update the 'navigation chain' after removing the item.
        item.removeNavigation()

        item.recoverFocus(index)
    }

    delegate: Loader {
        id: loader

        // Settings

        source: targetSource

        readonly property url targetSource: PlayerControlbarControls.control(model.id).source

        onTargetSourceChanged: {
            source = targetSource
        }

        focus: (index === 0)

        Layout.fillWidth: (item && item.Layout.minimumWidth > 0)
        Layout.minimumWidth: Layout.fillWidth ? item.Layout.minimumWidth : (item ? item.implicitWidth : -1)
        Layout.maximumWidth: Layout.fillWidth ? (item ? item.implicitWidth : -1) : -1

        Layout.minimumHeight: 0
        Layout.maximumHeight: Math.min((item && item.implicitHeight <= 0) ? Number.MAX_VALUE : item.implicitHeight, repeater.availableHeight)
        Layout.fillHeight: true

        Layout.alignment: repeater.alignment

        readonly property int controlId: model.id
        // extra space on top of the layout spacing (Figma gaps), re-evaluated once the items load
        Layout.leftMargin: repeater.figmaGaps ? (repeater.count, loader.item,
                                                 Math.max(0, repeater.gapBefore(index) - repeater.baseSpacing))
                                              : 0
        onStatusChanged: {
            if (status === Loader.Error) {
                const fallback = "qrc:///qt/qml/VLC/PlayerControls/Fallback.qml"
                console.assert(loader.source !== fallback)
                loader.setSource(fallback, { type: PC.Fallback.Broken })
            }
        }

        Binding on visible {
            delayed: true // this is important
            when: condition
            value: {
                if (condition)
                    return (loader.x + loader.Layout.minimumWidth <= repeater.availableWidth)
                else
                    return true;
            }

            property bool condition: false

            Binding on condition {
                delayed: true
                value: (loader.status === Loader.Ready) &&
                       (loader.Layout.minimumWidth > 0) &&
                       (repeater.availableWidth < Number.MAX_VALUE)
            }
        }

        // Events

        onActiveFocusChanged: {
            if (activeFocus && !item?.focus) {
                recoverFocus()
            }
        }

        onLoaded: {
            // control should not request focus if they are not enabled:
            item.focus = Qt.binding(function() { return item.enabled && item.visible })
            // redesign: icon buttons get the Figma "Icon Wrapper" size (30x32) in the player's bar;
            // previous / next sit in the 28 px transport row next to the play pill (Figma
            // "Frame 8" / "Frame 10": 30x28)
            if (item.rdMinimumWidth !== undefined)
                item.rdMinimumWidth = Qt.binding(function() { return repeater.figmaGaps ? VLCStyle.rd_iconButtonWidth : 0 })
            if (item.rdMinimumHeight !== undefined) {
                const transport = (loader.controlId === ControlListModel.PREVIOUS_BUTTON
                                   || loader.controlId === ControlListModel.NEXT_BUTTON)
                item.rdMinimumHeight = Qt.binding(function() {
                    if (!repeater.figmaGaps)
                        return 0
                    return transport ? VLCStyle.rd_playButtonHeight : VLCStyle.rd_iconButtonHeight
                })
            }

            // navigation parent of control is always controlLayout
            // so it can be set here unlike leftItem and rightItem:
            item.Navigation.parentItem = repeater

            if (typeof item.activeFocusOnTab === "boolean")
                item.activeFocusOnTab = true

            item.visible = Qt.binding(function() { return loader.visible })

            if (item.requestLockUnlockAutoHide)
                item.requestLockUnlockAutoHide.connect(repeater.requestLockUnlockAutoHide)

            if (item.menuOpened)
                item.menuOpened.connect(repeater.menuOpened)

            if (item.forceUnlock)
                repeater.forceUnlock.connect(item.forceUnlock)

            //can't connect to enabledChanged in a Connections
            item.onEnabledChanged.connect(() => {
                if (loader.activeFocus && !item.enabled) // Loader has focus but item is not enabled
                    recoverFocus()
            })
        }

        // Connections

        Connections {
            target: item

            enabled: loader.status === Loader.Ready

            function onVisibleChanged() {
                if (loader.activeFocus && !item.visible)
                    recoverFocus()
            }
        }

        // Functions

        function applyNavigation() {
            if (item === null) return

            const itemLeft  = repeater.itemAt(index - 1)
            const itemRight = repeater.itemAt(index + 1)

            if (itemLeft) {
                const componentLeft = itemLeft.item

                if (componentLeft)
                {
                    item.Navigation.leftItem = componentLeft

                    componentLeft.Navigation.rightItem = item
                }
            }

            if (itemRight) {
                const componentRight = itemRight.item

                if (componentRight)
                {
                    item.Navigation.rightItem = componentRight

                    componentRight.Navigation.leftItem = item
                }
            }
        }

        function removeNavigation() {
            if (item === null) return

            const itemLeft = repeater.itemAt(index - 1)

            // NOTE: The current item was removed from the repeater so we test against the
            //       same index.
            const itemRight = repeater.itemAt(index)

            if (itemLeft) {
                if (itemRight) {
                    itemLeft.item.Navigation.rightItem = itemRight.item
                    itemRight.item.Navigation.leftItem = itemLeft.item
                }
                else
                    itemLeft.item.Navigation.rightItem = null
            }
            else if (itemRight) {
                itemRight.item.Navigation.leftItem = null
            }
        }

        function recoverFocus(_index) {
            if (item === null) return

            const controlLayout = repeater.Navigation.parentItem

            if (!controlLayout || !controlLayout.visible)
                return

            if (_index === undefined)
                _index = index

            for (let i = 1; i <= Math.max(_index, repeater.count - (_index + 1)); ++i) {
                 if (i <= _index) {
                     const leftItem = repeater.itemAt(_index - i)

                     if (_focusIfFocusable(leftItem))
                         return
                 }

                 if (_index + i <= repeater.count - 1) {
                     const rightItem = repeater.itemAt(_index + i)

                     if (_focusIfFocusable(rightItem))
                         return
                 }
            }

            // focus to other alignment if focusable control
            // in the same alignment is not found:
            if (!!controlLayout.Navigation.rightItem) {
                controlLayout.Navigation.defaultNavigationRight()
            } else if (!!controlLayout.Navigation.leftItem) {
                controlLayout.Navigation.defaultNavigationLeft()
            } else if (controlLayout.altFocusAction) {
                controlLayout.altFocusAction()
            }
        }

        // Private

        function _focusIfFocusable(_loader) {
            if (_loader?.item?.focus) {
                if (item.focusReason !== undefined)
                    _loader.item.forceActiveFocus(item.focusReason)
                else {
                    console.warn("focusReason is not available in %1!".arg(item))
                    _loader.item.forceActiveFocus()
                }
                return true
            } else {
                return false
            }
        }
    }
}
