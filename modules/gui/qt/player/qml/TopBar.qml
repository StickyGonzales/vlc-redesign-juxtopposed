/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
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

// redesign: single 40 px top bar (video 3:35-5:14, 11:24-11:40; Figma "topbar"):
// [cone] [...] [sidebar toggle] | [folder chip]      title      [minimize maximize fullscreen close]
// Background BG/A3. Title Inter 400 14 FG/A2, centered on the window.
// In the player (showLibraryButtons) everything but the cone and the window buttons is the
// profile's top bar layout (W8.1b, RdProfiles.topBarModel, edited in Customize Player): its
// left zone after the cone, its center zone centered on the window, its right zone between
// maximize and close (where Figma has the fullscreen button), or at the right end without the
// window buttons. The library's top bar keeps the fixed [...] title [fullscreen].
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQuick.Window


import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.PlayerControls
import VLC.Playlist
import VLC.Widgets as Widgets
import VLC.Menus as Menus
import VLC.Util

FocusScope{
    id: root

    // Properties (same interface as before the redesign, used by Player.qml)

    required property int textWidth

    // For now, used for d&d functionality
    // Not strictly necessary to set
    property Item plListView

    property int reservedHeight: implicitHeight

    property int topMargin: 0
    property int sideMargin: 0

    property string title

    property bool showCSD: false
    property bool showToolbar: false
    property bool pinControls: false

    property bool playlistVisible: false

    // the player's top bar: the editable layout (W8.1b); the full library's top bar
    // (MainDisplay.qml, Figma Player-3.png) has only the cone, "...", the title and the window
    // buttons
    property bool showLibraryButtons: true
    readonly property bool _editable: showLibraryButtons && !!RdProfiles.topBarModel
    property string accessibleName: qsTr("Player topbar")

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Window
    }

    // Signals

    signal togglePlaylistVisibility()
    signal requestLockUnlockAutoHide(bool lock)
    signal backRequested()

    ///incomming signal to request all menu and popup to close
    signal forceUnlock()

    // Settings

    implicitHeight: topMargin + VLCStyle.rd_topBarHeight

    Accessible.role: Accessible.ToolBar
    Accessible.name: accessibleName
    AccessibleCompat.id: "playerTopBar"

    // Children

    // Figma "topbar": BG/A3 in the dark Player frames, BG/A3 Transparent in "Player - Light"
    Rectangle {
        anchors.fill: parent
        color: VLCStyle.palette.isDark ? VLCStyle.palette.rdBgA3 : VLCStyle.palette.rdBgA3Transparent
    }

    // the wheel over the top bar, its empty parts included, never reaches the video (volume /
    // seek, Decision 54); under the controls, so a volume control in a zone still gets it first
    Widgets.RdWheelSink {
        anchors.fill: parent
    }

    //drag and dbl click the titlebar in CSD mode
    Loader {
        id: tapNDrag

        anchors.fill: parent
        active: root.showCSD
        source: "qrc:///qt/qml/VLC/Widgets/CSDTitlebarTapNDrapHandler.qml"

        Connections {
            target: tapNDrag.item
            enabled: tapNDrag.status === Loader.Ready
            function onCsdMenuVisibleChanged() {
                root.requestLockUnlockAutoHide(tapNDrag.item.csdMenuVisible)
            }
        }
    }

    Item {
        id: bar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: VLCStyle.rd_topBarHeight

        Row {
            id: leftGroup

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(6, VLCStyle.scale) + root.sideMargin
            anchors.verticalCenter: parent.verticalCenter

            // Figma "topbar" (1920x40, padding 6): cone cell 38, gap 7, "..." and sidebar icons 28
            // wide 10 apart ("Frame 50"), the divider in a 24 wide cell ("Frame 6"), folder chip
            spacing: 0

            // cone (Figma "Frame 8", 38x28 cell, Figma "vlc" icon in Accent/Logo, derived from the
            // live accent: video 17:46)
            Item {
                width: VLCStyle.dp(38, VLCStyle.scale)
                height: VLCStyle.dp(28, VLCStyle.scale)

                Widgets.RdIcon {
                    anchors.centerIn: parent
                    name: Brand.logoIcon
                    accentColor: VLCStyle.palette.rdAccentLogo
                }
            }

            Item {
                width: VLCStyle.dp(7, VLCStyle.scale)
                height: 1
            }

            Widgets.IconToolButton {
                id: menuSelector

                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(28, VLCStyle.scale)
                height: VLCStyle.rd_iconButtonHeight
                font.pixelSize: VLCStyle.rd_iconSize

                text: VLCIcons.more
                rdIcon: "more"
                description: qsTr("Menu")

                AccessibleCompat.id: "topBarMenuButton"

                focus: !root._editable
                checked: contextMenu.visible

                visible: !root._editable

                Navigation.parentItem: root

                onClicked: contextMenu.popupBelow(menuSelector, visualFocus)

                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)

                // redesign: the main menu in the Figma style (W4.9)
                Menus.RdMainMenu {
                    id: contextMenu

                    onAboutToShow: root.requestLockUnlockAutoHide(true)
                    onAboutToHide: root.requestLockUnlockAutoHide(false)
                }

                Connections {
                    target: root

                    function onForceUnlock() {
                        contextMenu.close()
                    }
                }
            }
        }

        // the player's editable zones (W8.1b)
        RdTopBarZone {
            id: leftZone

            // the keyboard enters the top bar here when "..." is a control of the layout
            focus: root._editable
            visible: root._editable
            anchors.left: leftGroup.right
            anchors.verticalCenter: parent.verticalCenter
            // shrinks (the folder chip and names elide) before it reaches the window buttons
            width: Math.min(implicitWidth, Math.max(0, Math.min(centerZone.x, rightGroup.x)
                                                       - VLCStyle.dp(10, VLCStyle.scale) - x))
            height: parent.height

            model: root._editable ? RdProfiles.topBarModel.left : null

            Navigation.parentItem: root
            // an empty zone is passed over
            Navigation.rightItem: (centerZone.count > 0 && centerZone.width > 0) ? centerZone : rightZone

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            Component.onCompleted: root.forceUnlock.connect(leftZone.forceUnlock)
        }

        RdTopBarZone {
            id: centerZone

            // centered on the window, kept between the other zones
            readonly property real _min: leftZone.x + leftZone.implicitWidth + VLCStyle.dp(10, VLCStyle.scale)
            readonly property real _max: rightGroup.x - VLCStyle.dp(10, VLCStyle.scale)

            visible: root._editable
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, Math.min(implicitWidth, _max - _min))
            height: parent.height
            x: Math.max(_min, Math.min(Math.round((parent.width - width) / 2), _max - width))

            alignment: Qt.AlignHCenter
            model: root._editable ? RdProfiles.topBarModel.center : null

            Navigation.parentItem: root
            Navigation.leftItem: leftZone.count > 0 ? leftZone : null
            Navigation.rightItem: rightZone.count > 0 ? rightZone : null

            onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
            Component.onCompleted: root.forceUnlock.connect(centerZone.forceUnlock)
        }

        T.Label {
            id: centerTitleText

            readonly property real _maxWidth: Math.max(0, Math.min(root.width - 2 * Math.max(leftGroup.width + leftGroup.x,
                                                                                                root.width - rightGroup.x),
                                                                     root.width))

            anchors.centerIn: parent
            width: Math.min(implicitWidth, _maxWidth)

            visible: !root._editable && width > 0

            text: root.title
            color: VLCStyle.palette.rdFgA2
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: rightGroup

            anchors.right: parent.right
            // Figma: the window buttons end 6 from the edge (topbar padding)
            anchors.rightMargin: root.sideMargin + (root.showCSD ? VLCStyle.dp(6, VLCStyle.scale) : 0)
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // (a themed window button set has no middle slot: the right zone sits before it)
            width: root.showCSD ? csdDecorations.width + ((root._editable && !rightZone._slot) ? rightZone.width : 0)
                                : (root._editable ? rightZone.width : fullscreenButton.width) + VLCStyle.dp(6, VLCStyle.scale)

            Loader {
                id: csdDecorations

                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right

                focus: false
                active: root.showCSD
                enabled: root.showCSD
                visible: root.showCSD
                source:  VLCStyle.palette.hasCSDImage
                    ? "qrc:///qt/qml/VLC/Widgets/CSDThemeButtonSet.qml"
                    : "qrc:///qt/qml/VLC/Widgets/CSDWindowButtonSet.qml"

                // the player's right zone takes the place of the fullscreen button (between
                // maximize and close); a themed button set has no room inside: before it
                onLoaded: {
                    if (item.showFullscreenButton !== undefined)
                        item.showFullscreenButton = Qt.binding(() => !root._editable)
                    if (item.middleItem !== undefined)
                        item.middleItem = Qt.binding(() => root._editable ? rightZone : null)
                }

                Connections {
                    target: csdDecorations.item
                    enabled: csdDecorations.status === Loader.Ready
                    function onButtonHoveredChanged() { root.requestLockUnlockAutoHide(csdDecorations.item.buttonHovered) }
                }
            }

            // the player's right zone: in the window buttons, else at the right end
            RdTopBarZone {
                id: rightZone

                // the window buttons' middle slot (CSDWindowButtonSet makes it as wide as this
                // zone while it is its middleItem). The zone stays a child of the group, drawn
                // over the slot: no reparenting, so focus, hover and the zone's place survive the
                // set being unloaded (fullscreen, native decorations)
                readonly property Item _slot: (root.showCSD && !!csdDecorations.item
                                               && !!csdDecorations.item.middleSlotItem)
                                              ? csdDecorations.item.middleSlotItem : null

                visible: root._editable
                width: implicitWidth
                height: rightGroup.height
                x: _slot ? csdDecorations.x + _slot.x
                         : (root.showCSD ? csdDecorations.x - width
                                         : rightGroup.width - VLCStyle.dp(6, VLCStyle.scale) - width)

                // Figma: 36 wide cells as the window buttons, no gap
                iconWidth: VLCStyle.dp(36, VLCStyle.scale)
                spacing: 0
                alignment: Qt.AlignRight
                model: root._editable ? RdProfiles.topBarModel.right : null

                Navigation.parentItem: root
                Navigation.leftItem: (centerZone.count > 0 && centerZone.width > 0) ? centerZone : leftZone

                onRequestLockUnlockAutoHide: (lock) => root.requestLockUnlockAutoHide(lock)
                Component.onCompleted: root.forceUnlock.connect(rightZone.forceUnlock)
            }

            // fullscreen in the library's top bar when the window has native decorations (or a
            // themed CSD set)
            Widgets.IconToolButton {
                id: fullscreenButton

                visible: !root._editable
                         && (!root.showCSD || !(csdDecorations.item && csdDecorations.item.showFullscreenButton !== undefined))
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: root.showCSD ? csdDecorations.left : parent.right
                anchors.rightMargin: root.showCSD ? 0 : VLCStyle.dp(6, VLCStyle.scale)
                width: VLCStyle.rd_iconButtonWidth
                height: VLCStyle.rd_iconButtonHeight
                font.pixelSize: VLCStyle.rd_iconSize

                text: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? VLCIcons.defullscreen : VLCIcons.fullscreen
                rdIcon: (MainCtx.intfMainWindow.visibility === Window.FullScreen) ? "fullscreen_state-active" : "fullscreen"
                description: qsTr("Fullscreen")

                onClicked: MainCtx.toggleInterfaceFullScreen()
                onHoveredChanged: root.requestLockUnlockAutoHide(hovered)
            }
        }
    }
}
