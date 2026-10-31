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

// redesign: right sidebar of the player (settings sidebar 7:12-9:19, queue sidebar 9:29 and
// 15:08; Figma "Subtitles" / "Queue" frames: 400 wide, radius 10, BG/B1 95% with a 50 px
// background blur).
// - the body is opaque BG/B1: the video is a native surface under the QML scene and cannot be
//   blurred, and without the blur its 5 % would show through as a sharp ghost image
// - tab header 50 px, BG/B2, then a 1 px gap: icon 20 + label Inter 12; active
//   tab: two-tone icon, FG/A2 label and a 2 px accent underline as wide as the Figma tab content
//   frame (centered); inactive: plain icon, FG/A3 label
// - pages (RdSidePanelPageLoader) are created on first use and cross-fade when the tab changes
//   (video 8:40, P4-16, IA-37); the tabs' icons, labels and underlines cross-fade with them
//   (VLCStyle.rd_tabSwitchDuration; instant when the system's animations are off)
// - optional footer pinned at the bottom (preset selector, "Open Advanced Settings")
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Widgets.RdPanel {
    id: root

    // [{ key, label, icon, width, underline, activeIcon, inactiveIcon, activeColor }]; icon is a
    // Figma icon name: the active tab uses activeIcon (default "<icon>_two-tone-yes"), an inactive
    // one inactiveIcon (default icon); underline is the Figma underline width (default: icon and
    // label). Figma colours: the active icon in activeColor (default FG/A3) with its two-tone part
    // in Accent/DIm, inactive icons all FG/A4.
    property var tabs: []
    property string currentKey: ""
    default property alias pages: pageHost.data
    property alias footer: footerHost.data
    // false hides the footer on a tab that has none in Figma
    property bool footerVisible: true

    signal tabClicked(string key)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // keyboard: the tabs take Left / Right (switch tab) and Down (into the page); the page's
    // controls Up / Down (a list moves its rows, the rest moves like Tab, RdPanel.arrowNavigation)
    function focusTabs(reason) {
        for (let i = 0; i < tabRepeater.count; ++i) {
            const tab = tabRepeater.itemAt(i)
            if (tab && tab.active) {
                tab.forceActiveFocus(reason)
                return
            }
        }
    }

    // focuses the current page: its own focusContent(reason) when it has one (the queue focuses
    // the playing row), else its first control; the current tab when the page has none
    function focusContent(reason) {
        const pages = pageHost.children
        for (let i = 0; i < pages.length; ++i) {
            const page = pages[i]
            if (!page.current || !page.item)
                continue
            if (typeof page.item.focusContent === "function") {
                if (page.item.focusContent(reason))
                    return
            } else {
                const lastTab = tabRepeater.itemAt(tabRepeater.count - 1)
                const next = lastTab ? lastTab.nextItemInFocusChain(true) : null
                if (next && root._inPages(next)) {
                    next.forceActiveFocus(reason)
                    return
                }
            }
            break
        }
        root.focusTabs(reason)
    }

    function _inPages(item) {
        for (let p = item; p; p = p.parent) {
            if (p === pageHost)
                return true
        }
        return false
    }

    // selects the tab at `index` and focuses it (Left / Right on the tabs)
    function _selectTab(index) {
        const tab = tabRepeater.itemAt(index)
        if (!tab)
            return
        root.tabClicked(tab.modelData.key)
        tab.forceActiveFocus(Qt.TabFocusReason)
    }

    arrowNavigation: true
    clip: true
    color: rdPalette.rdBgB1

    Rectangle {
        id: header

        width: parent.width
        height: VLCStyle.dp(50)
        color: root.rdPalette.rdBgB2

        // rounded like the panel at the top, square at the bottom
        radius: root.radius

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: root.radius
            color: parent.color
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            spacing: VLCStyle.dp(1)

            Repeater {
                id: tabRepeater

                model: root.tabs

                delegate: T.AbstractButton {
                    id: tab

                    // the pointing hand over the clickable controls
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    required property var modelData
                    required property int index
                    readonly property bool active: root.currentKey === modelData.key
                    // 0 (not selected) to 1 (selected): the icon, the label and the underline
                    // cross-fade with the page when the tab changes (P4-16, IA-37, video 8:40)
                    property real selection: active ? 1 : 0

                    Behavior on selection {
                        enabled: MainCtx.systemAnimations

                        NumberAnimation {
                            duration: VLCStyle.rd_tabSwitchDuration
                            easing.type: Easing.Linear
                        }
                    }

                    width: VLCStyle.dp(modelData.width ?? 100)
                    height: header.height

                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    Accessible.checkable: true
                    Accessible.checked: active

                    onClicked: root.tabClicked(modelData.key)

                    Navigation.leftAction: () => root._selectTab(tab.index - 1)
                    Navigation.rightAction: () => root._selectTab(tab.index + 1)
                    Navigation.downAction: () => root.focusContent(Qt.TabFocusReason)
                    Navigation.upAction: () => { }

                    Keys.priority: Keys.AfterItem
                    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                    contentItem: Item {
                        Row {
                            id: tabRow

                            x: (parent.width - width) / 2
                            y: VLCStyle.dp(14)
                            spacing: VLCStyle.dp(8)

                            // the plain and the two-tone icon, cross-faded by the selection
                            Item {
                                anchors.verticalCenter: parent.verticalCenter
                                width: VLCStyle.dp(20)
                                height: width

                                Widgets.RdIcon {
                                    readonly property color inactiveColor: tab.hovered ? root.rdPalette.rdFgA3
                                                                                       : root.rdPalette.rdFgA4

                                    anchors.centerIn: parent
                                    visible: opacity > 0
                                    opacity: 1 - tab.selection
                                    name: tab.modelData.inactiveIcon ?? tab.modelData.icon
                                    size: VLCStyle.dp(20)
                                    color: inactiveColor
                                    color2: inactiveColor
                                }

                                Widgets.RdIcon {
                                    anchors.centerIn: parent
                                    visible: opacity > 0
                                    opacity: tab.selection
                                    name: tab.modelData.activeIcon ?? tab.modelData.icon + "_two-tone-yes"
                                    size: VLCStyle.dp(20)
                                    color: tab.modelData.activeColor ?? root.rdPalette.rdFgA3
                                    color2: root.rdPalette.rdAccentDim
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.label
                                font.family: VLCStyle.rd_fontFamily
                                font.pixelSize: VLCStyle.rd_fontSize_toggle
                                color: tab.hovered ? root.rdPalette.rdFgA2
                                                   : Qt.tint(root.rdPalette.rdFgA3,
                                                             Qt.rgba(root.rdPalette.rdFgA2.r,
                                                                     root.rdPalette.rdFgA2.g,
                                                                     root.rdPalette.rdFgA2.b,
                                                                     root.rdPalette.rdFgA2.a * tab.selection))
                            }
                        }

                        // the old tab's underline fades out while the new one fades in: both
                        // show for a moment (P4-16, video 8:40-8:42)
                        Rectangle {
                            visible: opacity > 0
                            opacity: tab.selection
                            x: (parent.width - width) / 2
                            anchors.bottom: parent.bottom
                            width: tab.modelData.underline ? VLCStyle.dp(tab.modelData.underline)
                                                           : tabRow.width
                            height: VLCStyle.dp(2)
                            color: root.rdPalette.rdAccentMain
                        }

                        Rectangle {
                            visible: tab.visualFocus
                            anchors.fill: parent
                            anchors.margins: VLCStyle.dp(2)
                            color: "transparent"
                            radius: VLCStyle.rd_radius_small
                            border.width: VLCStyle.dp(1)
                            border.color: root.rdPalette.rdFgA3
                        }
                    }
                }
            }
        }
    }

    // Figma panel gap 1: the panel fill shows between the header and the page, no line
    Item {
        id: headerGap

        anchors.top: header.bottom
        width: parent.width
        height: VLCStyle.dp(1)
    }

    // pages: each RdSidePanelPageLoader shows its page when its key is the current one
    Item {
        id: pageHost

        readonly property string currentKey: root.currentKey
        // the sidebar has been shown: the pages not created yet are created in the background
        property bool prewarm: false

        Binding on prewarm {
            when: root.visible
            value: true
            restoreMode: Binding.RestoreNone
        }

        anchors.top: headerGap.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footerArea.top
        // keep scrolled content off the rounded corners when there is no footer
        anchors.bottomMargin: footerArea.used ? 0 : root.radius
    }

    // Figma "Frame 68": pinned footer, padding 20, gap 10, BG/B1 95%, 1 px Divider/Dim on top
    Item {
        id: footerArea

        readonly property bool used: root.footerVisible && footerHost.children.length > 0

        visible: used
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: used ? footerHost.implicitHeight : 0

        Rectangle {
            visible: footerArea.used
            width: parent.width
            height: VLCStyle.dp(1)
            color: root.rdPalette.rdDividerDim
        }

        Column {
            id: footerHost

            width: parent.width
            padding: VLCStyle.dp(20)
            spacing: VLCStyle.dp(10)
        }
    }
}
