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

// redesign: the full-window library (video 10:12-10:59, 11:48-11:56, 13:48-13:55, 20:52-20:59;
// P5-06, P5-26, P5-27, P6-21): the window's top bar (cone, "...", the centered window title,
// the window buttons; 11:48 no sidebar toggle or folder chip), the library (RdLibraryView,
// shared with the compact library next to the video) and the mini player at the bottom right.
// Without the media library, VLC's own home page is shown.
import QtQuick
import QtQuick.Window

import VLC.Style
import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player

import VLC.Util
import VLC.Dialogs

FocusScope {
    id: g_mainDisplay

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Main display")
    AccessibleCompat.id: "mainDisplay"

    property bool _showCSD: MainCtx.clientSideDecoration
        && !(MainCtx.intfMainWindow.visibility === Window.FullScreen)

    Component.onCompleted: {
        // without a picture-in-picture video, the video cannot keep playing in the library
        if (!MainCtx.canShowVideoPIP && MainCtx.hasEmbededVideo)
            MainPlaylistController.stop()
    }

    // the library's own history (Escape, mouse back, the swipe-back gesture in MainInterface.qml);
    // VLC's home page without the media library keeps VLC's History
    readonly property bool canGoBack: library.item?.canGoBack ?? !History.previousEmpty

    function goBack() {
        if (library.item && library.item.goBack)
            library.item.goBack()
        else
            History.previous()
    }

    // Escape goes back in the library
    Navigation.cancelAction: function() {
        g_mainDisplay.goBack()
    }

    // Ctrl+F searches the library (its Search field) instead of VLC's global Ctrl+F "Open
    // Folder" (Ctrl+O and the main menu still open files and folders); the shortcut override
    // comes before the global shortcut
    Keys.onShortcutOverride: (event) => {
        if (KeyHelper.matchSearch(event) && library.item && library.item.focusSearch) {
            event.accepted = true
            library.item.focusSearch()
        } else if (event.key === Qt.Key_L && event.modifiers === Qt.ControlModifier && miniPlayer.visible) {
            // Ctrl+L (VLC's play queue toggle) shows and hides the mini player's queue, the
            // library's play queue (Decision 3), instead of VLC's docked play queue, which
            // would then show up in the player
            event.accepted = true
            miniPlayer.queueOpen = !miniPlayer.queueOpen
        }
    }

    Keys.onPressed: (event) => {
        if (KeyHelper.matchSearch(event) && library.item && library.item.focusSearch) {
            library.item.focusSearch()
            event.accepted = true
        }
        //unhandled keys are forwarded as hotkeys
        if (!event.accepted)
            MainCtx.sendHotkey(event.key, event.modifiers)
    }

    // pinch to change the interface scale (VLC's)
    PinchHandler {
        id: interfaceScalePinchHandler

        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad

        minimumPointCount: 2
        maximumPointCount: 2

        target: null

        // Default in QPlatformTheme::defaultThemeHint is 10
        dragThreshold: ((Application.styleHints?.startDragDistance ?? 10) * 4)

        property double accumulatedDelta: 0.0

        function adjustScaleFactor() {
            // We don't want too fine change, since changing it requires reloading
            // all images from disk:
            if (accumulatedDelta >= 0.5) {
                MainCtx.setIntfUserScaleFactor(+((MainCtx.getIntfUserScaleFactor() * accumulatedDelta).toFixed(2)))
                accumulatedDelta = 0.0
            }
        }

        scaleAxis.onActiveValueChanged: (delta) => {
            if (delta < 0.25)
                return

            accumulatedDelta += delta

            // Naive compression:
            Qt.callLater(interfaceScalePinchHandler.adjustScaleFactor)
        }

        onActiveChanged: {
            if (!active) {
                accumulatedDelta = 0.0
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: VLCStyle.palette.rdBgB1
    }

    MenuTopbar {
        id: menuTopbar
        z: 6

        visible: MainCtx.hasToolbarMenu
        enabled: visible

        anchors {
            top: parent.top
            right: parent.right
            left: parent.left
        }
    }

    // window top bar: the player's top bar without its sidebar toggle and folder chip (Figma
    // Player-3.png, video 11:48), so both bars line up exactly; the title is the playing media's,
    // VLC's name when nothing plays
    TopBar {
        id: topBar

        z: 5
        anchors.top: menuTopbar.visible ? menuTopbar.bottom : parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        topMargin: VLCStyle.applicationVerticalMargin
        sideMargin: VLCStyle.applicationHorizontalMargin
        textWidth: width

        showLibraryButtons: false
        accessibleName: qsTr("Library top bar")
        title: Player.isStarted ? (Player.title !== "" ? Player.title : Player.name)
                                : Brand.title
        showCSD: g_mainDisplay._showCSD
    }

    // the library (VLC's own home page without the media library)
    Loader {
        id: library

        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: loaderUpdatePane.top
        anchors.leftMargin: VLCStyle.applicationHorizontalMargin
        anchors.rightMargin: VLCStyle.applicationHorizontalMargin

        focus: true
        source: MainCtx.mediaLibraryAvailable ? "qrc:///qt/qml/VLC/MediaLibrary/RdLibraryView.qml"
                                              : "qrc:///qt/qml/VLC/MainInterface/NoMedialibHome.qml"
    }

    // the mini player and its queue (W5.8), over the library at the bottom right
    RdMiniPlayer {
        id: miniPlayer

        parent: library
        z: 4
        visible: Player.isStarted
        topInset: library.item && library.item.headerHeight !== undefined ? library.item.headerHeight : 0

        onFolderClicked: {
            if (library.item && library.item.revealMrl)
                library.item.revealMrl(Player.url.toString())
        }
    }

    // the last rows scroll out from under the mini player in a bottom corner
    Binding {
        target: library.item
        property: "bottomInset"
        when: !!library.item && library.item.bottomInset !== undefined
        value: miniPlayer.visible && !miniPlayer.atTop ? miniPlayer.height + miniPlayer.margin : 0
    }

    Loader {
        id: loaderUpdatePane

        z: 2

        // WARNING: Object name is used from C++ side to acknowledge the modern update pane is loaded,
        //          if C++ side does not get this acknowledgement, the old update dialog is shown as
        //          fallback.
        objectName: "updatePaneLoader"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        readonly property bool updateModelIsAvailable: (typeof UpdateModel !== 'undefined')

        active: updateModelIsAvailable && (shouldShow || height > 0.0)

        focus: !!item

        readonly property bool shouldShow: {
            if (!updateModelIsAvailable)
                return false

            if (DialogsProvider.updateDialogVisible)
                return false

            if (UpdateModel.explicitCheck) {
                return (UpdateModel.updateStatus !== UpdateModel.Unchecked)
            } else {
                if (UpdateModel.updateStatus === UpdateModel.updateStatusOnAcknowledgment)
                    return false // already dismissed with the same status

                switch (UpdateModel.updateStatus) {
                    case UpdateModel.Unchecked:
                    case UpdateModel.Checking:
                    case UpdateModel.UpToDate:
                        return false
                    default:
                        return true
                }
            }
        }

        function dismiss() {
            // This could be also be an assertion:
            if (updateModelIsAvailable) {
                UpdateModel.updateStatusOnAcknowledgment = UpdateModel.updateStatus
                UpdateModel.explicitCheck = undefined // Resets the property
            }

            height = 0.0
        }

        onShouldShowChanged: {
            if (shouldShow)
                height = Qt.binding(() => { return implicitHeight })
        }

        height: 0
        clip: (height < implicitHeight)

        Behavior on height {
            NumberAnimation {
                easing.type: Easing.InOutSine
                duration: VLCStyle.duration_long
            }
        }

        source: "qrc:///qt/qml/VLC/MainInterface/UpdatePane.qml"

        onLoaded: {
            item.leftPadding = Qt.binding(function() { return VLCStyle.margin_large + VLCStyle.applicationHorizontalMargin })
            item.rightPadding = Qt.binding(function() { return VLCStyle.margin_large + VLCStyle.applicationHorizontalMargin })
            item.bottomPadding = Qt.binding(function() { return VLCStyle.margin_small + VLCStyle.applicationVerticalMargin })

            item.dismissRequested.connect(loaderUpdatePane, loaderUpdatePane.dismiss)
        }
    }

    Dialogs {
        z: 10
        bgContent: g_mainDisplay

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }
    }

    Widgets.FloatingNotification {
        id: notif
        z: 11

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    // a video that starts opens the player (VLC's behavior)
    Connections {
        target: Player
        function onHasVideoOutputChanged() {
            if (Player.hasVideoOutput && MainCtx.hasEmbededVideo)
                MainCtx.playerView = true
        }
    }

    MouseArea {
        /// handles mouse navigation buttons
        z: 9
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        cursorShape: undefined
        onClicked: (mouse) => {
            if (!library.item)
                return
            if (mouse.button === Qt.BackButton && library.item.goBack)
                library.item.goBack()
            else if (mouse.button === Qt.ForwardButton && library.item.goForward)
                library.item.goForward()
        }
    }
}
