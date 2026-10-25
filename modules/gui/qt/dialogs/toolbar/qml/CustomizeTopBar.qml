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

// redesign (W8.1b, video 19:20-19:27, Figma "Player - customize" / "-6"): the edited top bar,
// drawn where the top bar is (40 high, BG/A3) while Customize Player is open, with every
// movable item in a dashed outline (Figma: "..." and the library toggle 28x28, the divider
// 24x28, the folder chip and the title on themselves). It edits the top bar layout of the
// selected profile (RdProfiles.topBarModel): its left zone after the cone, its center zone
// centered on the window, and its right zone between the window's maximize and close buttons,
// where Figma's top bar has its fullscreen button (without the window buttons of a client side
// decoration: at the right end). Items move between this bar, the control bar and the box.
// The cone and the window buttons stay where they are: the window buttons keep Figma's dashed
// outline (36x24) but cannot be moved.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

Rectangle {
    id: root

    // the dialog content: drag state and drag layer
    property Item editor: null

    // PlayerControlbarModel: the top bar layout of the selected profile
    property var topBarModel: null

    readonly property bool _windowButtons: MainCtx.clientSideDecoration

    implicitHeight: VLCStyle.rd_topBarHeight

    // Figma "topbar": BG/A3 (Dark), BG/A3 Transparent (Light), opaque over the native video
    color: Qt.alpha(VLCStyle.palette.isDark ? VLCStyle.palette.rdBgA3 : VLCStyle.palette.rdBgA3Transparent, 1.0)

    // keeps the arrow cursor and the clicks inside the bar
    MouseArea {
        anchors.fill: parent
        cursorShape: root.editor && root.editor.dragActive ? Qt.DragMoveCursor : Qt.ArrowCursor
    }

    // the brand logo, as the live top bar (Figma "Frame 8": 38x28 cell 6 from the edge, then
    // 7; util/brand.hpp: VLC's cone or the public build's logo)
    Item {
        id: cone

        x: VLCStyle.dp(6)
        width: VLCStyle.dp(38)
        height: parent.height

        Widgets.RdIcon {
            anchors.centerIn: parent
            name: Brand.logoIcon
            accentColor: VLCStyle.palette.rdAccentLogo
        }
    }

    CustomizeZone {
        id: leftZone

        x: cone.x + cone.width + VLCStyle.dp(7)
        width: Math.max(implicitWidth, centerZone.x - VLCStyle.dp(10) - x)
        height: parent.height

        topBar: true
        iconWidth: VLCStyle.dp(28)
        alignment: Qt.AlignLeft
        editor: root.editor
        model: root.topBarModel ? root.topBarModel.left : null
    }

    CustomizeZone {
        id: centerZone

        x: Math.round((root.width - width) / 2)
        width: implicitWidth
        height: parent.height

        topBar: true
        iconWidth: VLCStyle.dp(28)
        alignment: Qt.AlignHCenter
        acceptsExpandingSpacer: false
        editor: root.editor
        model: root.topBarModel ? root.topBarModel.center : null
    }

    // window buttons and the right zone (Figma: 36 wide cells, the last one ends 6 from the edge)
    Row {
        id: rightGroup

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(6)
        height: parent.height

        LockedWindowButton {
            visible: root._windowButtons
            iconName: "minimize"
        }

        LockedWindowButton {
            visible: root._windowButtons
            iconName: "maximize"
        }

        CustomizeZone {
            id: rightZone

            width: implicitWidth
            height: parent.height

            topBar: true
            iconWidth: VLCStyle.dp(36)
            topBarSpacing: 0
            topBarIconPadding: 0
            alignment: Qt.AlignRight
            editor: root.editor
            model: root.topBarModel ? root.topBarModel.right : null
        }

        LockedWindowButton {
            visible: root._windowButtons
            iconName: "close"
        }
    }

    // a window button: its icon in Figma's 36x24 dashed outline; it stays in place
    component LockedWindowButton: Item {
        property string iconName: ""

        width: VLCStyle.dp(36)
        height: rightGroup.height

        Widgets.RdDashedFrame {
            anchors.centerIn: parent
            width: parent.width
            height: VLCStyle.dp(24)
            color: VLCStyle.palette.rdFgA3
        }

        Widgets.RdIcon {
            anchors.centerIn: parent
            name: parent.iconName
            color: VLCStyle.palette.rdFgA2
        }
    }
}
