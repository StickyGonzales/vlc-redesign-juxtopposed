/*****************************************************************************
 * Copyright (C) 2024 VLC authors and VideoLAN
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
import QtQml.Models
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Playlist
import VLC.Player
import VLC.PlayerControls
import VLC.Dialogs
import VLC.Util

FocusScope {
    id: rootPlayer

    // Properties

    //behave like a Page
    property var pagePrefix: []

    readonly property int positionSliderY: controlBar.y + controlBar.sliderY

    // redesign: no stock placeholder card; without artwork the music view draws the Figma-style
    // placeholder itself (P6-04)
    readonly property string coverSource: (Player.artwork && Player.artwork.toString()) ? Player.artwork : ""

    // Only applicable in video mode:
    // redesign: no shadow gradients behind the bars; the bars have their own background
    property bool displayFadeRectangles: false
    property real implicitFadeRectangleHeight: VLCStyle.dp(206, VLCStyle.scale)

    // Private

    property bool _controlsUnderVideo: (MainCtx.pinVideoControls
                                        &&
                                        (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
                                        && !RdPanels.uiHidden)

    readonly property bool _windowed: MainCtx.intfMainWindow.visibility !== Window.FullScreen

    property bool _keyPressed: false

    // redesign: the compact library docked on the left between the bars (video 11:37-11:59,
    // P5-23 / P5-25 / F-16; Figma Player.png): the top bar's sidebar toggle and folder chip open
    // and close it with the Figma smart animate "slow" (208 ms), the video area sits to its
    // right. Without the media library the toggle opens VLC's own library view instead.
    readonly property bool _libraryShown: MainCtx.mediaLibraryAvailable && RdPanels.libraryOpen
                                          && !RdPanels.uiHidden
    // 0 closed, 1 open
    property real _libraryProgress: _libraryShown ? 1 : 0
    Behavior on _libraryProgress {
        NumberAnimation {
            duration: VLCStyle.rd_librarySlideDuration
            easing.type: Easing.OutCubic
        }
    }
    readonly property real _libraryFullWidth: VLCStyle.rd_libraryRailWidth + VLCStyle.rd_libraryPanelWidth
    readonly property real _libraryWidth: _libraryFullWidth * _libraryProgress
    // left edge of the video area. The library slides over the video, which takes its new size
    // once, when the opening ends or the closing starts: the native video surface is resized
    // once instead of on every frame of the slide (performance first)
    readonly property real _videoInset: (_libraryShown && _libraryProgress >= 1) ? _libraryFullWidth : 0
    // the music view stays on the whole window under the library (Figma "Player - Music-1": the
    // cover keeps its place centred on the window), so its blurred background is never resized
    readonly property real _contentInset: MainCtx.hasEmbededVideo ? _videoInset : 0
    // the video between the bars instead of under them: with the controls pinned, and next to
    // the compact library, which keeps both bars shown (VLC lays the subtitles out in the video's
    // area: under a bar that stays they were cut off)
    readonly property bool _videoBetweenBars: MainCtx.hasEmbededVideo
                                              && (_controlsUnderVideo || _contentInset > 0)
    // the library is built on its first opening and then kept, so it reopens within a frame
    property bool _libraryActivated: false
    // built in the background when the player starts with it open (the player shows first)
    property bool _libraryAsync: false

    // open already when the player comes back from the full library
    Component.onCompleted: {
        if (_libraryShown) {
            _libraryAsync = true
            _libraryActivated = true
        }
    }

    on_LibraryShownChanged: {
        if (_libraryShown) {
            // opened by the user: built at once (the folder chip reveals in it right away)
            _libraryAsync = false
            _libraryActivated = true
        } else if (librarySidebar.activeFocus) {
            // keys must not go on to the hidden library
            topBar.forceActiveFocus()
        }
        _updatePanelLock()
    }

    // sidebar toggle (reveal = false) and folder chip (reveal = true): open or close the compact
    // library; the folder chip opens it on the folder of the playing file (11:24-11:31)
    function toggleLibrary(reveal) {
        if (!MainCtx.mediaLibraryAvailable) {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP)
                MainPlaylistController.stop()
            MainCtx.playerView = false
            return
        }

        if (RdPanels.libraryOpen) {
            RdPanels.libraryOpen = false
            return
        }

        RdPanels.libraryOpen = true
        if (reveal && librarySidebar.item)
            librarySidebar.item.revealMrl(Player.url.toString())
    }

    // redesign (Decision 30): in a window both bars show while the mouse moves over the player and
    // fade out a few seconds after it stops; in fullscreen each bar shows while the mouse is near
    // it (video 3:46-3:55). Menus, keyboard use and audio mode show both bars (in fullscreen
    // except the far one while the mouse is in the other bar's zone); an open panel shows both.
    // how near the edge: Settings > Interface "Fullscreen controls sensitivity" (40 by default)
    readonly property real _barHoverZone: VLCStyle.dp(MainCtx.fsSensitivity, VLCStyle.scale)
    readonly property bool _mouseNearTop: !_windowed && _cursorY >= 0 && _cursorY <= topBar.height + _barHoverZone
    readonly property bool _mouseNearBottom: !_windowed && _cursorY >= 0
                                             && _cursorY >= height - controlBar.height - _barHoverZone
    readonly property bool _showBothBars: playerToolbarVisibilityFSM.isVisible
                                          && (_windowed || !MainCtx.hasEmbededVideo
                                              || playerToolbarVisibilityFSM.keyboardShown)
    // Hide UI (W4.10, Ctrl + \) hides both bars whatever the mouse does
    // (the compact library sits between both bars and keeps them, also in fullscreen; so does an
    // open panel: the settings sidebar's tabs lie in the top bar's zone, and pointing at them must
    // not hide the control bar the panel was opened from)
    readonly property bool _topBarVisible: !RdPanels.uiHidden
                                           && (_controlsUnderVideo || _showBothBars || _mouseNearTop
                                               || _libraryShown || _panelLocked
                                               || (playerToolbarVisibilityFSM.isLocked && !_mouseNearBottom))
    readonly property bool _controlBarVisible: !RdPanels.uiHidden
                                               && (_controlsUnderVideo || _showBothBars || _mouseNearBottom
                                                   || _libraryShown || _panelLocked
                                                   || (playerToolbarVisibilityFSM.isLocked && !_mouseNearTop))

    // cursor height inside the player, -1 outside, from mouse events (no polling): the hover
    // handler below sees the moves over the bars and panels; the video surface accepts its hover
    // events, so the handler is not hovered over the video, where the surface reports the moves
    // as in upstream VLC and its own hover handler tells when the cursor is over it
    // (_videoHovered). Hover events reach Qt Quick while another app is active, so a window also
    // shows its bars then.
    property real _cursorY: -1
    property bool _videoHovered: false

    // the cursor left the player only when neither the player nor the video is hovered (moving
    // from a bar onto the video unhovers the player handler)
    function _cursorMaybeLeft() {
        if (!playerHover.hovered && !_videoHovered && !_pointerStillOverPlayer())
            _cursorY = -1
    }

    // the pointer is still over the player while its window is the active one, for example over
    // one of Cone's own popup windows (a tooltip is a native window on Windows, Popup.Window):
    // the window and its hover handlers report a leave, but the pointer did not leave. Without this, a top bar button's tooltip, pushed
    // onto the button at the top of the screen, hid the fullscreen top bar under the pointer
    function _pointerStillOverPlayer() {
        return MainCtx.intfMainWindow.active && cursorTracker.inside(MainCtx.cursorPosition(rootPlayer))
    }

    HoverHandler {
        id: playerHover

        // only the video player hides its bars and cursor
        enabled: MainCtx.hasEmbededVideo

        onPointChanged: {
            if (hovered)
                cursorTracker.track(point.scenePosition.x, point.scenePosition.y)
        }
        onHoveredChanged: {
            if (!hovered)
                rootPlayer._cursorMaybeLeft()
        }
        // without video nothing is tracked
        onEnabledChanged: {
            if (!enabled)
                rootPlayer._cursorY = -1
        }
    }

    // the window's own mouse moves (InterfaceWindowHandler) feed the same tracking: in a large
    // window (2400 x 1350 px at 125 %) the moves over the video did not reach the video surface,
    // so the bars woke up only near the window edges. Several reports of one move count once
    // (same position in the window). A modal redesign dialog over the player keeps its moves.
    // Leaving the window ends the fullscreen bar zones also when no hover handler saw the cursor.
    Connections {
        target: MainCtx
        enabled: MainCtx.hasEmbededVideo && RdPanels.modalCount === 0

        function onIntfMouseMoved(scenePos) {
            cursorTracker.track(scenePos.x, scenePos.y)
        }
        function onIntfMouseLeft() {
            if (!rootPlayer._pointerStillOverPlayer())
                rootPlayer._cursorY = -1
        }
    }

    QtObject {
        id: cursorTracker

        // last cursor position in scene and in screen coordinates
        property bool valid: false
        property real sceneX: 0
        property real sceneY: 0
        property real globalX: 0
        property real globalY: 0

        // Window moves, resizes and fullscreen switches move the player under a still cursor and
        // cause hover events without a mouse move: they do not count as moves (they would end the
        // keyboard mode and show the bars).
        function track(x, y) {
            const tolerance = 0.01
            let p
            if (valid && Math.abs(x - sceneX) < tolerance && Math.abs(y - sceneY) < tolerance) {
                // same position in the window (Qt's hover check after the scene changed): the
                // cursor is still where it was on the screen
                p = rootPlayer.mapFromGlobal(globalX, globalY)
            } else {
                p = rootPlayer.mapFromItem(null, x, y)
                const g = rootPlayer.mapToGlobal(p.x, p.y)
                // the window moved under a still cursor if only the position in the window changed
                const moved = !valid || Math.abs(g.x - globalX) >= tolerance
                                     || Math.abs(g.y - globalY) >= tolerance
                valid = true
                sceneX = x
                sceneY = y
                globalX = g.x
                globalY = g.y
                // (ends the keyboard "show both bars" mode and shows the auto-hidden cursor again)
                if (moved && inside(p)) {
                    if (Player.isInteractive)
                        interactiveAutoHideTimer.restart()
                    else
                        playerToolbarVisibilityFSM.mouseMove()
                }
            }
            rootPlayer._cursorY = inside(p) ? p.y : -1
        }

        function inside(p) {
            return p.x >= 0 && p.y >= 0 && p.x <= rootPlayer.width && p.y <= rootPlayer.height
        }
    }

    // Settings

    Accessible.role: Accessible.Client
    Accessible.name: qsTr("Player")
    AccessibleCompat.id: "playerView"

    // Events

    // keys go to VLC's hotkeys, except while a modal redesign popup is open (RdPanels.modalCount).
    // In the compact library a row with keyboard focus or the search field still gets its keys
    // (InterfaceWindowHandler::applyKeyEvent), a row clicked with the mouse does not: Space
    // pauses as everywhere else in the player.
    // _leaving keeps the binding off while the view is destroyed: a menu released during the
    // destruction would otherwise turn the hotkeys back on for the library
    property bool _leaving: false
    Binding {
        target: MainCtx
        property: "preferHotkeys"
        value: !rootPlayer._leaving && RdPanels.modalCount === 0
    }
    Component.onDestruction: {
        rootPlayer._leaving = true
        MainCtx.preferHotkeys = false
        RdPanels.close()
        RdPanels.uiHidden = false
    }

    Keys.priority: Keys.AfterItem

    // Ctrl+F searches the compact library while it is shown: the shortcut override comes
    // before VLC's global Ctrl+F "Open Folder" shortcut and before the hotkeys (the key press
    // itself may go to the hotkeys); with the library closed Ctrl+F stays Open Folder
    Keys.onShortcutOverride: (event) => {
        if (rootPlayer._libraryShown && librarySidebar.item && KeyHelper.matchSearch(event)) {
            event.accepted = true
            librarySidebar.item.focusSearch()
        }
    }

    Keys.onPressed: (event) => {
        if (event.accepted)
            return

        // Ctrl+F reaching the player (focus in the library search): stays there
        if (rootPlayer._libraryShown && librarySidebar.item && KeyHelper.matchSearch(event)) {
            librarySidebar.item.focusSearch()
            event.accepted = true
            return
        }

        _keyPressed = true

        rootPlayer.Navigation.defaultKeyAction(event)

        //unhandled keys are forwarded as hotkeys
        if (!event.accepted || controlBar.state !== "visible")
            MainCtx.sendHotkey(event.key, event.modifiers);
    }

    Keys.onReleased: (event) => {
        if (event.accepted || _keyPressed === false)
            return

        _keyPressed = false

        rootPlayer.Navigation.defaultKeyReleaseAction(event)
    }

    on_ControlsUnderVideoChanged: {
        if (_controlsUnderVideo && !playerToolbarVisibilityFSM.isVisible)
            playerToolbarVisibilityFSM.askShow()
        // the hide timeout was blocked while pinned: start it again, keeping the keyboard mode
        // (pressing F while pinned keeps both bars up as long as after any key)
        else if (!_controlsUnderVideo && playerToolbarVisibilityFSM.isVisible && !Player.isInteractive) {
            if (playerToolbarVisibilityFSM.keyboardShown)
                playerToolbarVisibilityFSM.keyboardMove()
            else
                playerToolbarVisibilityFSM.mouseMove()
        }
    }

    // Functions

    function lockUnlockAutoHide(lock) {
        if (lock) {
            // a hidden FSM ignores lock() (fullscreen bars shown by their edge zone, a panel or the
            // time field opened from such a bar): show it first, so every lock is counted and the
            // matching unlock() cannot release another component's lock
            if (!playerToolbarVisibilityFSM.isVisible)
                playerToolbarVisibilityFSM.askShow()
            playerToolbarVisibilityFSM.lock()
        } else {
            playerToolbarVisibilityFSM.unlock()
        }
    }

    // Private

    function _onNavigationCancel() {
        if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
            MainPlaylistController.stop()
        }

        History.previous()
    }

    //we draw both the view and the window here
    ColorContext {
        id: windowTheme

        // redesign: the player follows the theme over the video too (Figma "Player - Light",
        // video 17:43), instead of VLC's night theme forced while a video plays
        palette: VLCStyle.palette

        colorSet: ColorContext.Window
    }

    PlayerToolbarVisibilityFSM {
        id: playerToolbarVisibilityFSM

        pinned: rootPlayer._controlsUnderVideo
        // a window uses the redesign's 3 s; fullscreen keeps VLC's "hide cursor and fullscreen
        // controller" preference (mouse-hide-timeout)
        hideDelay: rootPlayer._windowed ? VLCStyle.rd_barsHideDelay : MainCtx.mouseHideTimeout

        onForceUnlock:{
            controlBar.forceUnlock()

            topBar.forceUnlock()
        }
    }

    PlayerPlaylistVisibilityFSM {
        id: playlistVisibility

        onIsPlaylistVisibleChanged: lockUnlockAutoHide(isPlaylistVisible)
    }

    Connections {
        target: MainCtx

        //playlist
        function onHasEmbededVideoChanged() {
            playlistVisibility.updateVideoEmbed()
            playerToolbarVisibilityFSM.updateVideoEmbed()
        }
        function onAskShow() {
            playerToolbarVisibilityFSM.askShow()
        }
    }


    Connections {
        target: MainCtx.playqueuePanel

        //playlist
        function onDockedChanged() {
            playlistVisibility.updatePlaylistDocked()
        }
        function onVisibleChanged() {
            playlistVisibility.updatePlaylistVisible()
        }
    }


    Loader {
        id: playerSpecializationLoader

        objectName: "playerSpecializationLoader"

        anchors {
            left: parent.left
            // the video area starts right of the compact library
            leftMargin: rootPlayer._contentInset
            right: parent.right
            top: rootPlayer._videoBetweenBars ? topBar.bottom : parent.top
            bottom: rootPlayer._videoBetweenBars ? controlBar.top : parent.bottom
        }

        sourceComponent: MainCtx.hasEmbededVideo ? videoComponent : audioComponent

        property int cursorShape

        // Have padding here, so that the content (unlike background) does not go behind the top bar or the control bar:
        property real topPadding: (anchors.top === parent.top) ? topBar.height : 0
        property real bottomPadding: (anchors.bottom === parent.bottom) ? controlBar.height : 0

        component TouchDragHandler : DragHandler {
            id: touchDragHandler

            acceptedDevices: PointerDevice.TouchScreen

            minimumPointCount: 1
            maximumPointCount: 1

            target: null

            dragThreshold: VLCStyle.margin_normal

            property vector2d lastActiveTranslation

            // TODO: Use `createComponent()` and load directly from module instead, since
            //       it is pointless to keep the `QQmlComponent` around for this object.
            readonly property Component wheelToVLCConverterComponent: Component { WheelToVLCConverter { } }

            property WheelToVLCConverter wheelToVLCConverter

            // We synthesize wheel event with pixel delta. It is a to-do to handle
            // touch properly with precision adjustment, like on Android:
            onActiveTranslationChanged: {
                if (active) {
                    console.assert(wheelToVLCConverter)

                    const delta = Qt.point(activeTranslation.x - lastActiveTranslation.x,
                                           activeTranslation.y - lastActiveTranslation.y)

                    // WheelToVLCConverter can not handle sole pixel delta now, so we also
                    // use angle delta. This is similar to wheel events on some platforms:
                    wheelToVLCConverter.customWheelEvent(delta,
                                                         delta,
                                                         Qt.NoButton,
                                                         Qt.NoModifier,
                                                         true)

                    lastActiveTranslation = activeTranslation
                }
            }

            onActiveChanged: {
                if (active) {
                    if (!wheelToVLCConverter) {
                        wheelToVLCConverter = wheelToVLCConverterComponent.createObject(touchDragHandler)
                        wheelToVLCConverter.vlcWheelKey.connect(MainCtx, MainCtx.sendVLCHotkey)
                    }
                } else {
                    lastActiveTranslation = Qt.vector2d(0, 0)
                }
            }
        }

        Component {
            id: videoComponent

            FocusScope {
                // Video

                focus: true

                VideoSurface {
                    id: videoSurface

                    anchors.fill: parent

                    // With regard to `ViewBlockingRectangle`, we
                    // do not need to prevent painting anything
                    // behind because there is already nothing
                    // behind (unlike pip player):
                    renderingEnabled: false

                    videoSurfaceProvider: MainCtx.videoSurfaceProvider

                    visible: MainCtx.hasEmbededVideo

                    focus: true

                    cursorShape: playerSpecializationLoader.cursorShape

                    function onMouseEvent() {
                        //short interval for mouse events
                        if (Player.isInteractive)
                            interactiveAutoHideTimer.restart()
                        else
                            playerToolbarVisibilityFSM.mouseMove();
                    }

                    // redesign: moves go through the player's cursor tracking, which tells mouse
                    // moves from window moves and also gives the cursor height for the
                    // fullscreen bar zones; the surface reports device pixels
                    function onMouseMove(x, y) {
                        const dpr = MainCtx.effectiveDevicePixelRatio(Window.window) || 1.0
                        const p = videoSurface.mapToItem(null, x / dpr, y / dpr)
                        cursorTracker.track(p.x, p.y)
                    }

                    Component.onCompleted: {
                        mouseMoved.connect(videoSurface.onMouseMove)
                        mousePressed.connect(videoSurface.onMouseEvent)
                        mouseReleased.connect(videoSurface.onMouseEvent)
                        mouseDblClicked.connect(videoSurface.onMouseEvent)
                    }

                    Component.onDestruction: rootPlayer._videoHovered = false

                    // redesign: tells the player when the cursor is over the video (see _cursorY)
                    HoverHandler {
                        onHoveredChanged: {
                            rootPlayer._videoHovered = hovered
                            if (!hovered)
                                rootPlayer._cursorMaybeLeft()
                        }
                    }

                    Binding on cursorShape {
                        when: playerToolbarVisibilityFSM.started
                            && !playerToolbarVisibilityFSM.isVisible
                            && !interactiveAutoHideTimer.running
                            && !rootPlayer._mouseNearTop && !rootPlayer._mouseNearBottom
                        value: Qt.BlankCursor
                    }

                    TouchDragHandler {

                    }
                }

                component FadeRectangle : Rectangle {
                    implicitHeight: rootPlayer.implicitFadeRectangleHeight

                    SGManipulator {
                        // The rectangle is the bottom-most item in the interface,
                        // it does not need blending even though it is not opaque.
                        // Since `Rectangle` does not provide explicit control over
                        // blending, we are using `SGManipulator`:
                        blending: false
                    }
                }

                FadeRectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: topBar.opacity
                    visible: rootPlayer.displayFadeRectangles

                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }

                FadeRectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    opacity: controlBar.opacity

                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: .64; color: Qt.rgba(0, 0, 0, .8) }
                        GradientStop { position: 1; color: "black" }
                    }

                    visible: rootPlayer.displayFadeRectangles && !(controlBar.background && controlBar.background.visible)
                }
            }
        }

        Component {
            id: audioComponent

            FocusScope {
                id: audioFocusScope
                // Audio

                focus: true

                property real topPadding: playerSpecializationLoader.topPadding
                property real bottomPadding: playerSpecializationLoader.bottomPadding

                // Whether the full lyrics view is active
                readonly property bool lyricsMode: MainCtx.lyricsMode
                readonly property bool lyricsLayoutActive: lyricsMode
                                                        && Player.hasLyrics
                                                        && (centerContent.width - rootPlayer._videoInset) > VLCStyle.colWidth(6)

                // redesign: something under the cover takes the keyboard (the control bar and the
                // top bar skip the view otherwise)
                readonly property bool hasNavigable: lyricsButton.visible || syncToPlaybackCheckBox.visible

                // Reset sync when entering lyrics mode
                onLyricsModeChanged: {
                    if (lyricsMode && lyricsLoader.item)
                        lyricsLoader.item.lyricsSyncToPlayback = true
                }

                // redesign: the music view is the picture area of the player: like the video it
                // stays dark in the Light theme (Figma "Player - Light", video 17:43), so it is
                // drawn with the dark palette in both themes; the frame and the bars around it
                // follow the theme. Without artwork (or until it loads) it is BG/B2 behind the
                // placeholder cover.
                Rectangle {
                    anchors.fill: parent
                    color: VLCStyle.darkPalette.rdBgB2
                }

                // background image
                // redesign: Figma "Player - Music": the artwork as a square 32 px wider than the
                // window (16 px past each side), centred on the window, layer blur 20 (a gaussian
                // of about 10 px: four passes of radius 3), no tint. The blur is drawn once per
                // cover and kept as a still texture (`live` only while the cover or the size
                // changes, see `liveTimer`); the compact library slides over it without resizing
                // it (_contentInset).
                Widgets.DualKawaseBlur {
                    id: blurredBackground

                    visible: coverItem.coverShown

                    mode: Widgets.DualKawaseBlur.Mode.FourPass
                    radius: 3

                    // We disable live when everything settles through `liveTimer`,
                    // which is important to release intermediate layers with static
                    // source:
                    live: true

                    //destination aspect ratio
                    readonly property real dar: parent.width / parent.height
                    readonly property real bleed: VLCStyle.dp(16, VLCStyle.scale)

                    anchors.centerIn: parent
                    width: (cover.sar < dar) ? parent.width + 2 * bleed : (parent.height + 2 * bleed) * cover.sar
                    height: (cover.sar < dar) ? (parent.width + 2 * bleed) / cover.sar : parent.height + 2 * bleed

                    source: textureProviderIndirection

                    postprocess: true
                    // under a translucent artwork
                    backgroundColor: VLCStyle.darkPalette.rdBgB2

                    // The window naturally clips the content, but having this saves some
                    // video memory, depending on the excess content in the last layer:
                    viewportRect: Qt.rect((width - parent.width) / 2, (height - parent.height) / 2, parent.width, parent.height)

                    sourceTextureProviderObserver.onTextureChanged: {
                        liveTimer.transientTurnOnLive()
                    }

                    TextureProviderIndirection {
                        id: textureProviderIndirection

                        // This should not be necessary anymore since `DualKawaseBlur`
                        // does not create layer for the source implicitly as `MultiEffect`
                        // or `FastBlur` does as they deem necessary (in this case, it
                        // is not necessary). But due to a Qt bug when `mipmap: true` is
                        // used where texture sampling becomes broken, we need this as
                        // `QSGTextureView` has a workaround for that bug. This is totally
                        // acceptable as there is virtually no overhead.
                        source: cover
                    }

                    Component.onCompleted: {
                        // Blur layers are effect-size dependent, so once the user starts resizing the window (hence the effect),
                        // we should either momentarily turn on live, or repeatedly call `scheduleUpdate()`. Due to the optimization,
                        // calling `scheduleUpdate()` would continuously create and release intermediate layers, which would be a
                        // really bad idea. So instead, we turn on live and after some time passes turn it off again.
                        widthChanged.connect(liveTimer, liveTimer.transientTurnOnLive)
                        heightChanged.connect(liveTimer, liveTimer.transientTurnOnLive)

                        // In case texture provider observer never signals texture change:
                        liveTimer.transientTurnOnLive()
                    }

                    Timer {
                        id: liveTimer

                        repeat: false
                        interval: VLCStyle.duration_humanMoment

                        function transientTurnOnLive() {
                            if (!blurredBackground.sourceTextureIsValid)
                                return
                            blurredBackground.live = true
                            liveTimer.restart()
                        }

                        onTriggered: {
                            blurredBackground.live = false
                        }
                    }
                }

                MouseArea {
                    id: centerContent

                    readonly property ColorContext colorContext: ColorContext {
                        id: centerTheme
                        colorSet: ColorContext.View
                        // the picture area stays dark in both themes (see the background above)
                        palette: VLCStyle.darkPalette
                    }

                    anchors.fill: parent
                    anchors.topMargin: VLCStyle.margin_xsmall + audioFocusScope.topPadding
                    anchors.bottomMargin: VLCStyle.margin_xsmall + audioFocusScope.bottomPadding

                    onWheel: (wheel) => {
                        wheel.accepted = true
                        wheelToVlc.qmlWheelEvent(wheel)
                    }

                    TouchDragHandler {
                        wheelToVLCConverter: wheelToVlc
                    }

                    WheelToVLCConverter {
                        id: wheelToVlc

                        onVlcWheelKey: (key) => MainCtx.sendVLCHotkey(key)
                    }

                    // ── Two-panel lyrics layout ────────────────────────
                    Item {
                        id: leftSideParent

                        visible: (opacity > 0.0) || (width > 0.0)

                        opacity: (lyricsLoader.item ? 1.0 : 0.0)

                        Behavior on opacity {
                            id: opacityBehavior

                            enabled: false

                            NumberAnimation {
                                duration: VLCStyle.duration_long

                                easing.type: Easing.InOutSine
                            }

                            Component.onCompleted: {
                                // The animation should not be used at initialization:
                                Qt.callLater(() => { opacityBehavior.enabled = true })
                            }
                        }

                        anchors.top: parent.top
                        anchors.topMargin: VLCStyle.margin_large
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        // redesign: the lyrics start right of the compact library, which floats over
                        // the music view
                        anchors.leftMargin: rootPlayer._videoInset

                        width: lyricsLoader.item ? ((parent.width - rootPlayer._videoInset) * 0.6) : 0.0

                        Behavior on width {
                            id: widthBehavior

                            enabled: false

                            NumberAnimation {
                                duration: VLCStyle.duration_long

                                easing.type: Easing.InOutSine
                            }

                            Component.onCompleted: {
                                // The animation should not be used at initialization:
                                Qt.callLater(() => { widthBehavior.enabled = true })
                            }
                        }

                        Loader {
                            id: lyricsLoader

                            active: audioFocusScope.lyricsLayoutActive
                            sourceComponent: T.Pane {
                                // Swallow wheel events so scrolling the lyrics
                                // does not bubble up to the player and change
                                // the volume.
                                wheelEnabled: true

                                // Expose the inner Flickable's sync flag so the
                                // Loader's `item.lyricsSyncToPlayback` reaches
                                // through to LyricsFlickable in both directions.
                                property alias lyricsSyncToPlayback: lyricsFlickable.lyricsSyncToPlayback

                                implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                                                        implicitContentWidth + leftPadding + rightPadding)
                                implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                                                         implicitContentHeight + topPadding + bottomPadding)

                                contentItem: LyricsFlickable {
                                    id: lyricsFlickable

                                    onPlayerPositionChangeRequested: (time) => {
                                        Player.setTime(time)
                                        lyricsFlickable.lyricsSyncToPlayback = true
                                    }
                                }
                            }
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter

                            height: Math.min(implicitHeight, parent.height)
                        }
                    }

                    Item {
                        id: rightSideParent

                        visible: leftSideParent.visible

                        anchors.top: parent.top
                        anchors.topMargin: VLCStyle.margin_large
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.left: leftSideParent.right
                    }

                    ColumnLayout {
                        parent: leftSideParent.visible ? rightSideParent : centerContent

                        anchors.centerIn: parent
                        spacing: 0

                        Item {
                            id: coverItem
                            // no wider than the pane it sits in (a narrow window, lyrics)
                            Layout.preferredHeight: Math.min(rootPlayer.height / sizeConstant,
                                                             parent.parent.width - 2 * VLCStyle.margin_large)
                            // the placeholder is square, also when a short window limits its height
                            Layout.preferredWidth: coverShown ? cover.paintedWidth
                                                              : Math.min(Layout.preferredHeight, Layout.maximumHeight)
                            Layout.maximumHeight: centerContent.height
                            Layout.alignment: Qt.AlignHCenter

                            // redesign: Figma "Player - Music": the cover is 737 high in a 1080 high window
                            readonly property real sizeConstant: 1080 / 737

                            // an artwork is painted (also the previous one while the next one loads);
                            // else the placeholder
                            readonly property bool coverShown: cover.status === Image.Ready
                                                               || (cover.status === Image.Loading && cover.paintedWidth > 0)

                            // the texture of the cover and of the blurred background, and the cover
                            // size; shown through roundedCover below (falls back to itself where
                            // rounding is not available)
                            Image {
                                id: cover

                                visible: coverItem.coverShown && roundedCover.effectiveRadius <= 0

                                //source aspect ratio
                                readonly property real sar: paintedHeight > 0 ? paintedWidth / paintedHeight : 1
                                readonly property int maximumWidth: Helpers.alignUp((Screen.desktopAvailableWidth * eDPR / coverItem.sizeConstant), 32)
                                readonly property int maximumHeight: Helpers.alignUp((Screen.desktopAvailableHeight * eDPR / coverItem.sizeConstant), 32)

                                readonly property int maximumSize: Math.min(maximumWidth, maximumHeight)

                                readonly property real eDPR: MainCtx.effectiveDevicePixelRatio(Window.window)

                                readonly property url targetSource: rootPlayer.coverSource !== "" ? VLCAccessImage.uri(rootPlayer.coverSource) : ""

                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: targetSource
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                cache: false
                                asynchronous: true
                                // the previous cover stays until the next one is ready (no placeholder flash
                                // between two songs)
                                retainWhileLoading: true

                                onTargetSourceChanged: {
                                    cover.source = targetSource
                                }

                                // redesign: re-blur from the new source even before its texture is valid:
                                // the blur hidden during a placeholder still holds the texture of the
                                // cover before it (the texture change re-blurs again once it is ready)
                                onSourceChanged: {
                                    blurredBackground.live = true
                                    liveTimer.restart()
                                }

                                onStatusChanged: {
                                    // an unreadable artwork shows the placeholder
                                    if (status === Image.Error) {
                                        cover.source = ""
                                    }
                                }

                                sourceSize: Qt.size(maximumSize, maximumSize)

                                Accessible.role: Accessible.Graphic
                                Accessible.name: qsTr("Cover")

                                Component.onCompleted: {
                                    // After the update on source change, there can be another update when the mipmaps are generated.
                                    // We intentionally do not wait for this, initially using non-mipmapped source should be okay. As
                                    // the user should not be greeted with a black background until the mipmaps are ready, let alone
                                    // the possibility of knowing if the mipmaps are actually going to be ready as expected.
                                    // If the texture is not valid yet (which is signalled the latest), blur effect is going to queue
                                    // an update itself similar to the case when the source itself changes, so we do not check validity
                                    // of the texture here.
                                    blurredBackground.sourceTextureProviderObserver.hasMipmapsChanged.connect(blurredBackground,
                                                                                                              (hasMipmaps /*: bool */) => {
                                                                                                                  if (hasMipmaps) {
                                                                                                                      blurredBackground.scheduleUpdate()
                                                                                                                  }
                                                                                                              })
                                }
                            }

                            // redesign: the cover with rounded corners (Figma "Player - Music":
                            // radius 20, P6-04), drawn from the cover's own texture
                            Widgets.ImageExt {
                                id: roundedCover

                                visible: coverItem.coverShown
                                anchors.fill: cover
                                textureProviderItem: cover
                                fillMode: Image.PreserveAspectFit
                                radius: VLCStyle.rd_radius_cover

                                // Figma: one faint glow, #FFFFFF 3 %, no offset, blur 90.5
                                Widgets.RoundedRectangleShadow {
                                    color: VLCStyle.darkPalette.rdCoverGlow
                                    blurRadius: VLCStyle.dp(90.5, VLCStyle.scale)
                                }
                            }

                            // redesign: a song without artwork: the library's placeholder at the cover's
                            // size (Figma media base #303030 with the "music" icon, like a song row or
                            // card of the library) with the cover's radius and glow
                            Rectangle {
                                anchors.fill: parent
                                visible: !coverItem.coverShown
                                radius: VLCStyle.rd_radius_cover
                                color: VLCStyle.darkPalette.rdMediaBase

                                Widgets.RoundedRectangleShadow {
                                    color: VLCStyle.darkPalette.rdCoverGlow
                                    blurRadius: VLCStyle.dp(90.5, VLCStyle.scale)
                                }

                                Widgets.RdIcon {
                                    anchors.centerIn: parent
                                    // the audio view also shows a video played in its own window
                                    name: Player.hasVideoOutput ? "video" : "music"
                                    // a quarter of the cover (184 px in the 1080 high Figma frame), in steps
                                    // of 8 px so a window resize does not render the SVG again on every pixel
                                    size: Math.max(VLCStyle.dp(8), Math.round(parent.height / 32) * 8)
                                    color: VLCStyle.darkPalette.rdFgA2
                                }

                                Accessible.role: Accessible.Graphic
                                Accessible.name: qsTr("Cover")
                            }
                        }

                        // redesign: "title - artist" under the cover (Figma "Player - Music":
                        // Inter 500 24, FG/A1; P6-04, IB-23)
                        Text {
                            id: captionLabel

                            Layout.alignment: Qt.AlignHCenter
                            // Figma: the space between the bars is split in three equal gaps:
                            // above the cover, between cover and caption, below the caption
                            Layout.topMargin: Math.max(VLCStyle.margin_small,
                                                       (centerContent.height + 2 * VLCStyle.margin_xsmall
                                                        - coverItem.Layout.preferredHeight - implicitHeight) / 3)
                            // the column's pane: the whole view, or the right pane with lyrics
                            Layout.maximumWidth: parent.parent.width - 2 * VLCStyle.margin_large

                            Binding on visible {
                                delayed: true
                                when: captionLabel.componentCompleted
                                value: captionLabel.text !== "" && centerContent.height > (captionLabel.y + captionLabel.height)
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            readonly property string _title: Player.title !== "" ? Player.title : Player.name

                            text: Player.artist !== "" ? qsTr("%1 - %2").arg(_title).arg(Player.artist) : _title
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                            font.family: VLCStyle.rd_fontFamily
                            font.pixelSize: VLCStyle.rd_fontSize_title
                            font.weight: Font.Medium
                            color: VLCStyle.darkPalette.rdFgA1

                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }

                        Widgets.SubtitleLabel {
                            id: lyricsLabel

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_large
                            // Pin width and height so the surrounding centered
                            // column does not shift when the current lyric
                            // changes between empty / 1 line / 2 lines. Text
                            // exceeding two lines wraps then elides on line 2.
                            Layout.preferredWidth: parent.parent.width - VLCStyle.margin_xlarge * 2
                            Layout.preferredHeight: (lyricsLabelTextMetrics.height * 2) + VLCStyle.margin_xxxsmall

                            visible: false

                            Binding on visible {
                                delayed: true
                                when: lyricsLabel.componentCompleted

                                // Stay visible (reserving the 2-line slot) for the
                                // entire track when it has any lyrics, so the
                                // layout does not collapse between lyric lines.
                                value: Player.hasLyrics && !audioFocusScope.lyricsLayoutActive &&
                                       (centerContent.height > (lyricsLabel.y + lyricsLabel.height))
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            elide: Text.ElideRight

                            text: Player.currentLyric.text
                            font.pixelSize: VLCStyle.fontSize_xlarge
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            color: centerTheme.fg.primary

                            // TODO: Do not use `Binding` when minimum Qt is 6.12:
                            Binding {
                                target: lyricsLabel
                                property: "mutabilityGroup"
                                when: (lyricsLabel.mutabilityGroup !== undefined)
                                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.ModerateMutabilityGroup
                                                                                              : Item.StaticMutabilityGroup
                            }

                            TextMetrics {
                                id: lyricsLabelTextMetrics
                                font: lyricsLabel.font
                                text: "TEXT"
                            }

                            Accessible.role: Accessible.StaticText
                            Accessible.name: qsTr("Lyrics")
                            Accessible.description: text
                        }

                        // redesign: Figma "Player - Music" shows only the caption under the cover. VLC's
                        // step back / visualization / step forward buttons live in the control bar
                        // (skip 15 s) and the settings sidebar (Audio Visualizer); the lyrics toggle is
                        // in neither (RESIDUAL_AUDIT: NOT IN VIDEO, kept until Sticky decides), so it
                        // stays here, shown only for a song that has lyrics.
                        Widgets.IconToolButton {
                            id: lyricsButton

                            focus: true

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_large

                            visible: false

                            Binding on visible {
                                delayed: true
                                when: lyricsButton.componentCompleted
                                value: Player.hasLyrics && centerContent.height > (lyricsButton.y + lyricsButton.height)
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            colorContext.palette: VLCStyle.darkPalette

                            text: VLCIcons.topbar_music
                            font.pixelSize: VLCStyle.icon_audioPlayerButton
                            checked: MainCtx.lyricsMode
                            onClicked: MainCtx.lyricsMode = !MainCtx.lyricsMode
                            description: qsTr("Lyrics")

                            Navigation.parentItem: rootPlayer
                            Navigation.upItem: topBar
                            Navigation.downItem: syncToPlaybackCheckBox.visible ? syncToPlaybackCheckBox
                                                                                : (Player.isInteractive ? toggleControlBarButton : controlBar)

                            Accessible.role: Accessible.Button
                            Accessible.name: qsTr("Toggle lyrics view")
                            AccessibleCompat.id: "audioLyricsButton"
                        }

                        // "Sync to Playback" checkbox pinned to bottom of right panel
                        Widgets.CheckBoxExt {
                            id: syncToPlaybackCheckBox

                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: VLCStyle.margin_small

                            visible: false

                            Binding on visible {
                                delayed: true
                                when: syncToPlaybackCheckBox.componentCompleted
                                value: audioFocusScope.lyricsLayoutActive &&
                                       centerContent.height > (syncToPlaybackCheckBox.y + syncToPlaybackCheckBox.height)
                            }

                            property bool componentCompleted: false

                            Component.onCompleted: {
                                componentCompleted = true
                            }

                            text: qsTr("Sync lyrics to playback")
                            // Use a Binding element rather than an inline binding
                            // so manual clicks (which write `checked` directly)
                            // don't permanently break the source-of-truth link.
                            Binding on checked {
                                when: lyricsLoader.item
                                value: lyricsLoader.item ? lyricsLoader.item.lyricsSyncToPlayback : true
                                restoreMode: Binding.RestoreBindingOrValue
                            }
                            onClicked: {
                                if (lyricsLoader.item)
                                    lyricsLoader.item.lyricsSyncToPlayback = checked
                            }

                            Accessible.role: Accessible.CheckBox
                            Accessible.name: qsTr("Sync lyrics to playback position")
                            AccessibleCompat.id: "syncToPlaybackCheckBox"

                            Navigation.parentItem: rootPlayer
                            Navigation.upItem: lyricsButton.visible ? lyricsButton : topBar
                            Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
                        }
                    }

                    Widgets.SubtitleLabel {
                        id: labelVolume

                        anchors.right: parent.right
                        anchors.top: parent.top

                        anchors.rightMargin: VLCStyle.margin_normal
                        anchors.topMargin: VLCStyle.margin_xxsmall

                        visible: false

                        text: qsTr("Volume %1%").arg(Math.round(Player.volume * 100))

                        color: centerTheme.fg.primary

                        font.weight: Font.Normal

                        Connections {
                            target: Player

                            function onVolumeChanged() {
                                animationVolume.restart()
                            }
                        }

                        SequentialAnimation {
                            id: animationVolume

                            PropertyAction { target: labelVolume; property: "visible"; value: true }

                            PauseAnimation { duration: VLCStyle.duration_humanMoment }

                            PropertyAction { target: labelVolume; property: "visible"; value: false }
                        }
                    }

                }
            }
        }
    }

    // redesign: the video sits in an inset area with rounded corners, framed by the window color
    // (video 9:29 / 11:41 zoomed: ~6 px frame on the sides and bottom, ~8 px inner radius; with the
    // bars hidden a thin frame stays all around, video 3:50 and 5:28). Drawn above the video, below
    // the bars (W3.7).
    // Qt is built without Canvas and Shapes, so the frame is the thick border of a rounded
    // rectangle: its inner edge is the rounded video opening, its outer edge lies outside the
    // player. The opening follows the bars' fade, so the frame is split into a top and a bottom
    // half, each a fixed-size rectangle that only moves with its edge (no geometry is rebuilt
    // during a fade) and is clipped to its half.
    Item {
        id: videoFrame

        anchors.fill: parent
        // next to the compact library the opening starts at the library's edge (Figma
        // Player.png: no frame between the library and the video)
        anchors.leftMargin: rootPlayer._contentInset > 0 ? rootPlayer._contentInset - inset : 0
        // the music view has the same frame (Figma "Player - Music": "Frame 312")
        visible: MainCtx.intfMainWindow.visibility !== Window.FullScreen
        enabled: false

        // Figma "Frame 312": 10 px of BG/A3 frame, visible corner about 9 px (visual audit A7, A8)
        readonly property real inset: VLCStyle.dp(10, VLCStyle.scale)
        readonly property real innerRadius: VLCStyle.dp(9, VLCStyle.scale)
        // the opening follows the bars' fade, so it grows and shrinks with them instead of
        // jumping once a bar has faded out (bars auto-hide over the video, Decision 30)
        readonly property real topEdge: inset + (topBar.height - inset) * (topBar.visible ? topBar.opacity : 0)
        readonly property real bottomEdge: height - inset
                                           - (controlBar.height - inset) * (controlBar.visible ? controlBar.opacity : 0)
        // fixed while the bars fade (whole pixels: a rectangle's border width is pixel aligned)
        readonly property real frameWidth: Math.ceil(2 * Math.max(topBar.height, controlBar.height)
                                                     + 2 * innerRadius + VLCStyle.dp(10, VLCStyle.scale))
        readonly property real openingWidth: Math.max(0, width - 2 * inset)
        // smaller corners when the opening is too small for them
        readonly property real cornerRadius: Math.min(innerRadius, openingWidth / 2,
                                                      Math.max(0, bottomEdge - topEdge) / 2)
        // the halves meet in the middle; in a tiny window, inside the opening (or where it closed)
        readonly property real split: Math.min(Math.max(height / 2, topEdge), bottomEdge)

        Repeater {
            model: 2 // top half, bottom half

            delegate: Item {
                id: frameHalf

                required property int index
                readonly property bool atTop: index === 0

                y: atTop ? 0 : videoFrame.split
                width: videoFrame.width
                height: atTop ? videoFrame.split : videoFrame.height - videoFrame.split
                clip: true

                // its opening is as tall as the player, so only the edge of this half shows
                Rectangle {
                    x: videoFrame.inset - videoFrame.frameWidth
                    y: (frameHalf.atTop ? videoFrame.topEdge
                                        : videoFrame.bottomEdge - videoFrame.height - frameHalf.y)
                       - videoFrame.frameWidth
                    width: videoFrame.openingWidth + 2 * videoFrame.frameWidth
                    height: videoFrame.height + 2 * videoFrame.frameWidth

                    color: "transparent"
                    border.width: videoFrame.frameWidth
                    border.color: VLCStyle.palette.rdBgA3
                    radius: videoFrame.frameWidth + videoFrame.cornerRadius
                    antialiasing: true
                }
            }
        }
    }

    // redesign: the compact library (RdLibrarySidebar, 427 px: rail 50 + panel 377) between the
    // top bar and the control bar; it slides in from the left edge over the video (opaque: the
    // video is a native surface under the scene)
    Item {
        id: libraryHost

        anchors.left: parent.left
        anchors.top: topBar.bottom
        anchors.bottom: controlBar.top
        width: rootPlayer._libraryWidth
        visible: width > 0
        clip: rootPlayer._libraryProgress < 1
        z: 1

        // the presses and wheel turns the library leaves (rail, header, margins, a list at its
        // end) stop here: they never reach the music view (volume) or the video under it
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => { wheel.accepted = true }
        }

        Loader {
            id: librarySidebar

            x: libraryHost.width - width
            width: rootPlayer._libraryFullWidth
            height: libraryHost.height

            enabled: rootPlayer._libraryShown
            active: rootPlayer._libraryActivated
            asynchronous: rootPlayer._libraryAsync
            source: "qrc:///qt/qml/VLC/MediaLibrary/RdLibrarySidebar.qml"
        }
    }

    // redesign: a click outside the open player panel closes it (INTERACTIONS.md section 2).
    // Over the video (or the audio view) the click only closes the panel: it does not reach the
    // video, which would pause on the click (mouse-pause-policy) and switch to fullscreen on a
    // double click; the second click of a quick double click is held back too. A right click
    // closes the panel and opens the right-click menu. Clicks on the bars are handled below.
    MouseArea {
        id: panelDismissArea

        anchors.fill: parent

        enabled: RdPanels.current !== "" || dismissClickGuard.running || pressed
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: {
            if (RdPanels.current === "")
                return
            RdPanels.close()
            dismissClickGuard.restart()
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                playerMenu.popupAtCursor()
        }

        Timer {
            id: dismissClickGuard

            interval: Qt.styleHints.mouseDoubleClickInterval
        }
    }

    // a press on the bars (or anywhere else in the player outside the panel) closes the panel
    // once the click is done, unless the click itself changed the panel: the button of the open
    // panel toggles it, another panel button switches to its panel without the panel flashing
    // closed in between. The handler only observes: the click still reaches the control (play,
    // seek, volume ... work in the same click). It sits on an empty item above everything in the
    // player, because Qt delivers a press that a control accepted to the handlers of the items
    // above that control, not to its parents.
    Item {
        anchors.fill: parent
        z: 100

        PointHandler {
            id: panelOutsidePress

            enabled: RdPanels.current !== ""
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            property string _panel: ""
            // a drag from outside that ends over the open panel (a library row dropped into the
            // queue) is not a click outside: the panel stays. Other drags (seek bar, volume)
            // still close it once released
            property Item _panelItem: null
            property bool _dragged: false
            property point _lastPosition
            // the compact library and the queue sit side by side (video 11:44 drags a library
            // row into the open queue): a press in the library, or a click on its sidebar
            // toggle or folder chip (the libraryRequested handler below sets this), leaves the
            // queue open
            property bool _libraryToggled: false

            onPointChanged: {
                if (!active)
                    return
                _lastPosition = point.scenePosition
                if (!_dragged) {
                    const dx = point.scenePosition.x - point.scenePressPosition.x
                    const dy = point.scenePosition.y - point.scenePressPosition.y
                    _dragged = Math.max(Math.abs(dx), Math.abs(dy)) >= Qt.styleHints.startDragDistance
                }
            }

            function _inside(item, scenePoint) {
                if (!item || !item.visible)
                    return false
                const p = item.mapFromItem(null, scenePoint.x, scenePoint.y)
                return p.x >= 0 && p.y >= 0 && p.x < item.width && p.y < item.height
            }

            onActiveChanged: {
                if (active) {
                    const p = point.scenePressPosition
                    const panel = RdPanels.tracksOpen ? tracksPopupLoader
                                : RdPanels.settingsOpen ? settingsPanelLoader
                                : RdPanels.queueOpen ? queuePanelLoader : null
                    const inLibrary = RdPanels.queueOpen && rootPlayer._libraryShown && _inside(libraryHost, p)
                    _panel = (_inside(panel, p) || inLibrary) ? "" : RdPanels.current
                    _panelItem = panel
                    _dragged = false
                    _lastPosition = p
                    _libraryToggled = false
                } else if (_panel !== "") {
                    const panel = _panel
                    _panel = ""
                    const droppedInto = _dragged && _inside(_panelItem, _lastPosition)
                    _panelItem = null
                    if (droppedInto)
                        return
                    Qt.callLater(() => {
                        if (RdPanels.current !== panel)
                            return
                        if (RdPanels.queueOpen && panelOutsidePress._libraryToggled)
                            return
                        RdPanels.close()
                    })
                }
            }
        }
    }

    TopBar {
        id: topBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right

        z: 1

        topMargin: VLCStyle.applicationVerticalMargin
        sideMargin: VLCStyle.applicationHorizontalMargin

        textWidth: playlistVisibility.isPlaylistVisible
                 ? rootPlayer.width - playlistpopup.width
                 : rootPlayer.width

        focus: true
        // the title, library toggle and folder chip are controls of the top bar layout (W8.1b);
        // the fixed title stays for a profile model without a top bar layout
        title: Player.title !== "" ? Player.title : Player.name

        pinControls: MainCtx.pinVideoControls

        showCSD: MainCtx.clientSideDecoration && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        showToolbar: MainCtx.hasToolbarMenu && (MainCtx.intfMainWindow.visibility !== Window.FullScreen)
        playlistVisible: playlistVisibility.isPlaylistVisible

        plListView: {
            if (playlistpopup.active)
                return playlistpopup.item
            else if (playlistWindowLoader?.status === Loader.Ready)
                return playlistWindowLoader.item.playlistView
            else
                return null
        }

        Navigation.parentItem: rootPlayer
        Navigation.downItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (MainCtx.hasEmbededVideo || playerSpecializationLoader.item?.hasNavigable)
                return playerSpecializationLoader
            if (Player.isInteractive)
                return toggleControlBarButton
            return controlBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: rootPlayer._topBarVisible ? "visible" : "hidden"
        }

        onTogglePlaylistVisibility: playlistVisibility.togglePlaylistVisibility()

        onRequestLockUnlockAutoHide: (lock) => {
            rootPlayer.lockUnlockAutoHide(lock)
        }

        onBackRequested: {
            if (MainCtx.hasEmbededVideo && !MainCtx.canShowVideoPIP) {
               MainPlaylistController.stop()
            }
            MainCtx.playerView = false
        }

        // the library toggle and the folder chip, in either bar (W8.1b)
        Connections {
            target: RdPanels

            function onLibraryRequested(reveal) {
                panelOutsidePress._libraryToggled = true
                rootPlayer.toggleLibrary(reveal)
            }
        }

        // redesign: no acrylic background behind the top bar, it paints its own background
        // (BG/A3 in Dark, BG/A3 Transparent in Light, see TopBar.qml)

        FadeControllerStateGroup {
            target: topBar
        }
    }

    Loader {
        id: playlistpopup

        anchors {
            // NOTE: When the controls are pinned we display the playqueue under the topBar.
            top: (rootPlayer._controlsUnderVideo) ? topBar.bottom
                                                  : parent.top

            right: parent.right
            bottom: parent.bottom

            bottomMargin: parent.height - rootPlayer.positionSliderY
        }

        focus: false

        // redesign: the list button opens the queue sidebar instead of this pane, so the pane (and
        // its own play queue model) is only created the first time it is shown (VLC's play queue
        // hotkey, a docked queue left open in the library), then kept for its retract animation
        property bool _requested: false

        active: MainCtx.playqueuePanel.docked && _requested

        Binding on _requested {
            when: playlistVisibility.isPlaylistVisible
            value: true
            restoreMode: Binding.RestoreNone
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playlistVisibility.started
            value: (status === Loader.Ready && playlistVisibility.isPlaylistVisible) ? "expanded" : "retracted"
        }

        Component.onCompleted: {
            Qt.callLater(() => { playlistTransition.enabled = true; })
        }

        states: [
            State {
                name: "expanded"
                PropertyChanges {
                    target: playlistpopup
                    width: playlistpopup.implicitWidth
                    visible: true
                }
           }, State {
                name: "retracted"
                PropertyChanges {
                    target: playlistpopup
                    width: 0
                    visible: false
                }
           }
        ]

        transitions: Transition {
            id: playlistTransition
            enabled: false

            from: "retracted"; to: "expanded";
            reversible: true

            SequentialAnimation {
                PropertyAction { property: "visible" }

                NumberAnimation {
                    property: "width"
                    duration: VLCStyle.duration_short
                    easing.type: Easing.InOutSine
                }
            }
        }

        sourceComponent: PlaylistPane {
            id: playlistView

            property real maximumWidth: (rootPlayer.width + playlistView.rightPadding) / 2

            implicitWidth: Helpers.clamp(MainCtx.playqueuePanel.width
                                 , playlistView.minimumWidth
                                 , playlistView.maximumWidth)
            height: playlistpopup.height

            useAcrylic: false
            focus: true

            wheelEnabled: true

            rightPadding: VLCStyle.applicationHorizontalMargin
            topPadding:  {
                if (rootPlayer._controlsUnderVideo)
                    return VLCStyle.margin_normal
                else
                    // NOTE: We increase the padding accordingly to avoid overlapping the TopBar.
                    return topBar.reservedHeight
            }
            bottomPadding: 0

            background: Rectangle {
                color: windowTheme.bg.primary.alpha(0.8)
            }

            view.fadingEdge.pixelAlignedForDPR: !controlBar.visible

            Navigation.parentItem: rootPlayer
            Navigation.upItem: topBar
            Navigation.downItem: Player.isInteractive ? toggleControlBarButton : controlBar
            Navigation.leftAction: closePlaylist
            Navigation.cancelAction: closePlaylist

            function closePlaylist() {
                playlistVisibility.togglePlaylistVisibility()
                controlBar.forceActiveFocus()
            }


            Widgets.HorizontalResizeHandle {
                id: resizeHandle

                property bool _inhibitMainCtxUpdate: false

                parent: playlistView

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                }

                atRight: false
                currentWidth: playlistpopup.width

                maximumWidth: playlistView.maximumWidth
                minimumWidth: playlistView.minimumWidth

                onRequestedWidthChanged: {
                    if (!_inhibitMainCtxUpdate)
                        MainCtx.playqueuePanel.width = requestedWidth
                }

                Component.onCompleted:  _updateFromMainCtx()

                function _updateFromMainCtx() {
                    if (requestedWidth === MainCtx.playqueuePanel.width)
                        return

                    _inhibitMainCtxUpdate = true
                    requestedWidth = MainCtx.playqueuePanel.width
                    _inhibitMainCtxUpdate = false
                }

                Connections {
                    target: MainCtx.playqueuePanel

                    function onWidthChanged() {
                        resizeHandle._updateFromMainCtx()
                    }
                }
            }
        }
    }

    Dialogs {
        z: 10
        bgContent: rootPlayer

        anchors {
            bottom: controlBar.visible ? controlBar.top : rootPlayer.bottom
            left: parent.left
            right: parent.right

            bottomMargin: (rootPlayer._controlsUnderVideo || !controlBar.visible)
                          ? 0 : - VLCStyle.margin_large
        }
    }

    Timer {
        // NavigationBox's visibility depends on this timer
        id: interactiveAutoHideTimer
        running: false
        repeat: false
        interval: 3000
    }

    NavigationBox {
        id: navBox
        visible: Player.isInteractive && navBox.show
                    && (interactiveAutoHideTimer.running
                    || navBox.hovered || !MainCtx.hasEmbededVideo)

        // drawn on the picture itself (translucent black box): keeps the night colors in every theme
        colorContext.palette: VLCStyle.darkPalette

        x: rootPlayer.x + VLCStyle.margin_normal + VLCStyle.applicationHorizontalMargin
        y: controlBar.y - navBox.height - VLCStyle.margin_normal

        dragXMin: 0
        dragXMax: rootPlayer.width - navBox.width
        dragYMin: 0
        dragYMax: rootPlayer.height - navBox.height

        Drag.onDragStarted: (controlId) => {
            navBox.x = drag.x
            navBox.y = drag.y
        }
    }

    Connections {
        target: MainCtx
        function onNavBoxToggled() { interactiveAutoHideTimer.restart() }
    }

    Connections {
        target: rootPlayer
        function onWidthChanged() {
            if (navBox.x > navBox.dragXMax)
                navBox.x = navBox.dragXMax
        }
        function onHeightChanged() {
            if (navBox.y > navBox.dragYMax)
                navBox.y = navBox.dragYMax
        }
    }

    Widgets.ButtonExt {
        id: toggleControlBarButton
        visible: Player.isInteractive
                 && MainCtx.hasEmbededVideo
                 && !(MainCtx.pinVideoControls && !Player.fullscreen)
                 && (interactiveAutoHideTimer.running === true
                     || controlBar.state !== "hidden" || toggleControlBarButton.hovered)
        focus: true
        anchors {
            bottom: controlBar.state === "hidden" ? parent.bottom : controlBar.top
            horizontalCenter: parent.horizontalCenter
        }
        iconSize: VLCStyle.icon_large
        iconTxt: controlBar.state === "hidden" ? VLCIcons.expand_inverted : VLCIcons.expand

        // drawn on the picture itself (no bar behind it): keeps the night colors in every theme
        colorContext.palette: VLCStyle.darkPalette

        Navigation.parentItem: rootPlayer
        Navigation.upItem: playlistVisibility.isPlaylistVisible ? playlistpopup : (MainCtx.hasEmbededVideo ? playerSpecializationLoader : topBar)
        Navigation.downItem: controlBar

        onClicked:{
            playerToolbarVisibilityFSM.askShow();
        }
    }

    Widgets.FloatingNotification {
        id: notif

        anchors {
            bottom: controlBar.top
            left: parent.left
            right: parent.right
            margins: VLCStyle.margin_large
        }
    }

    // redesign: the subtitles stay above the control bar while it covers the bottom of the
    // video area (redesign/BETA_SUBS_NOTES.md). The covered height goes to VLC as a subtitle margin
    // in display pixels (RdSubtitleLift); it follows the bar's fade, so the subtitles rise and
    // settle with the bar. Nothing is covered in the music view, with the controls under the
    // video (pinned), or while the player is not shown (minimal view, library).
    readonly property real _subtitleLift: {
        if (!rootPlayer.visible || !MainCtx.hasEmbededVideo || !controlBar.visible || controlBar.opacity <= 0)
            return 0
        const area = playerSpecializationLoader
        if (area.width <= 0 || area.height <= 0)
            return 0
        // measured from the bottom of the whole video area, not of the picture: VLC places text
        // subtitles in the whole window ("spu-fill"), so in a letterboxed film they sit on the
        // black bar under the picture, where the control bar covers them
        const covered = area.y + area.height - controlBar.y
        if (covered <= 0)
            return 0
        const dpr = MainCtx.effectiveDevicePixelRatio(Window.window) || 1.0
        return covered * controlBar.opacity * dpr
    }

    Binding {
        target: RdSubtitleLift
        property: "lift"
        value: Math.round(rootPlayer._subtitleLift)

        // the subtitles go back down when the player goes (minimal view, library)
        Component.onDestruction: RdSubtitleLift.lift = 0
    }

    ControlBar {
        id: controlBar

        anchors {
            bottom: parent.bottom
            left: parent.left
            right: parent.right
        }

        hoverEnabled: true

        focus: true

        // redesign: one 54 px row (Figma "Controls": padding 11 top/bottom, 20 left/right inside the
        // layout); two rows when the seek row has its own row (ControlBar._seekRowOnOwnRow)
        rightPadding: VLCStyle.applicationHorizontalMargin
        leftPadding: VLCStyle.applicationHorizontalMargin
        topPadding: VLCStyle.rd_controlBarPaddingV
        bottomPadding: VLCStyle.applicationVerticalMargin + VLCStyle.rd_controlBarPaddingV

        textPosition: ControlBar.TimeTextPosition.Inline

        // hide right text so that it won't overlap with play queue
        showRemainingTime: (textPosition !== ControlBar.TimeTextPosition.AboveSlider)
                           || !playlistVisibility.isPlaylistVisible

        onStateChanged: {
            if (state === "visible")
                showChapterMarks()
        }

        Navigation.parentItem: rootPlayer
        Navigation.upItem: {
            if (playlistVisibility.isPlaylistVisible)
                return playlistpopup
            if (Player.isInteractive)
                return toggleControlBarButton
            // redesign: the music view only when something in it takes the keyboard
            if (!MainCtx.hasEmbededVideo && playerSpecializationLoader.item?.hasNavigable)
                return playerSpecializationLoader
            return topBar
        }

        //initial state value is "", using a binding avoid animation on startup
        Binding on state {
            when: playerToolbarVisibilityFSM.started
            value: rootPlayer._controlBarVisible ? "visible" : "hidden"
        }

        onRequestLockUnlockAutoHide: (lock) => rootPlayer.lockUnlockAutoHide(lock)

        // a right click on the seek bar opens the right-click menu like the rest of the bar
        // (the TapHandler below never sees it: the seek bar accepts every mouse button)
        onContextMenuRequested: playerMenu.popupAtCursor()

        identifier: (Player.hasVideoOutput) ? PlayerControlbarModel.Videoplayer
                                            : PlayerControlbarModel.Audioplayer

        onHoveredChanged: rootPlayer.lockUnlockAutoHide(hovered)

        // the profile notice over every view sits above the control bar, one or two rows high
        onHeightChanged: RdPanels.controlBarHeight = height
        Component.onCompleted: RdPanels.controlBarHeight = height
        Component.onDestruction: RdPanels.controlBarHeight = 0

        background: Rectangle {
            id: controlBarBackground

            visible: true

            opacity: {
                if (controlBar.textPosition === ControlBar.TimeTextPosition.Inline) {
                    return 1.0
                } else if (MainCtx.hasEmbededVideo && !MainCtx.pinVideoControls && !rootPlayer.displayFadeRectangles) {
                    return 0.6
                } else if ((Window.visibility === Window.FullScreen) && MainCtx.hasEmbededVideo) {
                    return MainCtx.pinOpacity
                } else if (AcrylicController.enabled || !MainCtx.hasEmbededVideo) {
                    return 0.7
                } else {
                    return 1.0
                }
            }

            // redesign: opaque, like the panels and menus, so the fullscreen bar over the native
            // video looks like the windowed one: BG/A3 in Dark (the dark Player frames override
            // the bar fill to BG/A3, visual audit A2, like the top bar), BG/A3 Transparent made
            // opaque in Light (its 95 % assumes a background blur); no top line in either theme:
            // Figma "Player - Light" strokes the bar with Divider/Dim (#ACACAC), but over the
            // video its 75 % bar renders the same #ABABAB, so the frame shows no line, while on the
            // opaque bar it showed as a grey 1-2 px line (PC session, 2026-10-19)
            color: (controlBar.textPosition !== ControlBar.TimeTextPosition.Inline) ? windowTheme.bg.primary
                   : VLCStyle.palette.isDark ? VLCStyle.palette.rdBgA3
                                             : Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)
        }

        FadeControllerStateGroup {
            target: controlBar
        }
    }

    // redesign: player panels. An open panel keeps the bars visible (F-06). Each panel is created
    // the first time it opens and then kept, so it reopens instantly; a moment after the player
    // shows, the panels are also created in the background, so the first click opens them within
    // a frame without slowing down the switch to the player (INTERACTIONS.md section 0).
    property bool _panelsPrewarm: false

    Timer {
        running: true
        interval: VLCStyle.duration_veryLong
        onTriggered: rootPlayer._panelsPrewarm = true
    }

    component PanelLoader: Loader {
        id: panelLoader

        // the panel is open
        property bool open: false
        property bool prewarm: false

        active: false
        // a panel that is needed now is created at once (this also completes a background
        // creation in progress)
        asynchronous: !panelLoader.open

        Binding on active {
            when: panelLoader.open || panelLoader.prewarm
            value: true
            restoreMode: Binding.RestoreNone
        }
    }

    // tracks popup (subtitle and audio buttons), sized by its content
    PanelLoader {
        id: tracksPopupLoader

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottom: controlBar.top
        anchors.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        z: 2

        open: RdPanels.tracksOpen
        prewarm: rootPlayer._panelsPrewarm

        sourceComponent: TracksPopup {
            width: VLCStyle.rd_sidePanelWidth
            height: implicitHeight
            maximumHeight: controlBar.y - tracksPopupLoader.anchors.bottomMargin
                           - (topBar.visible ? topBar.y + topBar.height : 0)
        }
    }

    // settings sidebar (gear) and queue sidebar (list button): inside the video area at the right,
    // 20 px from both bars and the right edge (video 7:12, 9:29; Figma "queue" 491:1781 400 wide)
    PanelLoader {
        id: settingsPanelLoader

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.top: topBar.bottom
        anchors.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottom: controlBar.top
        anchors.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        width: VLCStyle.rd_sidePanelWidth
        z: 2

        open: RdPanels.settingsOpen
        prewarm: rootPlayer._panelsPrewarm

        sourceComponent: SettingsSidebar {
            visible: RdPanels.settingsOpen
        }
    }

    PanelLoader {
        id: queuePanelLoader

        anchors.right: parent.right
        anchors.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.top: topBar.bottom
        anchors.topMargin: VLCStyle.dp(20, VLCStyle.scale)
        anchors.bottom: controlBar.top
        anchors.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        width: VLCStyle.rd_sidePanelWidth
        z: 2

        open: RdPanels.queueOpen
        prewarm: rootPlayer._panelsPrewarm

        sourceComponent: QueueSidebar {
            visible: RdPanels.queueOpen
        }
    }

    // redesign: "Show Metadata" and "Show Statistics" (settings sidebar, Playback tab; W4.3b):
    // info panels at the top left of the video area, right of the compact library, under the
    // sidebars where a small window makes them meet. They stay until switched off (their X or
    // the toggle) and hide with the UI. Each panel and its data source exist only while it is
    // shown.
    Column {
        id: infoPanels

        readonly property real margin: VLCStyle.dp(20, VLCStyle.scale)
        readonly property int count: (RdPanels.metadataShown ? 1 : 0) + (RdPanels.statisticsShown ? 1 : 0)
        readonly property real panelWidth: Math.max(0, Math.min(VLCStyle.dp(320, VLCStyle.scale),
                                                                rootPlayer.width - rootPlayer._videoInset - 2 * margin))
        // the room between the bars, shared by the panels shown
        readonly property real panelMaximumHeight: count > 0
            ? Math.max(0, (controlBar.y - y - margin - (count - 1) * spacing) / count)
            : 0

        anchors.left: parent.left
        anchors.leftMargin: rootPlayer._videoInset + margin
        anchors.top: topBar.bottom
        anchors.topMargin: margin
        z: 1

        spacing: margin
        visible: count > 0 && !RdPanels.uiHidden

        Loader {
            active: RdPanels.metadataShown
            visible: active

            sourceComponent: RdInfoPanel {
                width: infoPanels.panelWidth
                maximumHeight: infoPanels.panelMaximumHeight

                title: qsTr("Metadata")
                iconName: "info_two-tone-yes"
                sections: mediaMeta.sections

                onCloseRequested: RdPanels.metadataShown = false

                RdMediaMeta {
                    id: mediaMeta

                    player: Player
                }
            }
        }

        Loader {
            active: RdPanels.statisticsShown
            visible: active

            sourceComponent: RdInfoPanel {
                width: infoPanels.panelWidth
                maximumHeight: infoPanels.panelMaximumHeight

                title: qsTr("Statistics")
                iconName: "speed"
                values: inputStats.values
                placeholder: !inputStats.collecting
                             ? qsTr("%1 does not collect playback statistics. Turn on \"Collect playback statistics\" in Settings > General > Advanced Options, then play the media again.").arg(Brand.shortName)
                             : (!Player.isStarted ? qsTr("No media") : "")

                // VLC's Media Information > Statistics (dialogs/mediainfo/info_panels.cpp)
                sections: [
                    { title: qsTr("Input/Read"), rows: [
                        { label: qsTr("Media data size"), key: "readBytes" },
                        { label: qsTr("Input bitrate"), key: "inputBitrate" },
                        { label: qsTr("Demuxed data size"), key: "demuxBytes" },
                        { label: qsTr("Content bitrate"), key: "demuxBitrate" },
                        { label: qsTr("Discarded (corrupted)"), key: "corrupted" },
                        { label: qsTr("Dropped (discontinued)"), key: "discontinuity" }
                    ] },
                    { title: qsTr("Video"), rows: [
                        { label: qsTr("Decoded"), key: "decodedVideo" },
                        { label: qsTr("Displayed"), key: "displayedPictures" },
                        { label: qsTr("Late"), key: "latePictures" },
                        { label: qsTr("Lost"), key: "lostPictures" }
                    ] },
                    { title: qsTr("Audio"), rows: [
                        { label: qsTr("Decoded"), key: "decodedAudio" },
                        { label: qsTr("Played"), key: "playedBuffers" },
                        { label: qsTr("Lost"), key: "lostBuffers" }
                    ] }
                ]

                onCloseRequested: RdPanels.statisticsShown = false

                RdInputStats {
                    id: inputStats

                    player: Player
                }
            }
        }
    }

    // an open panel or the compact library keeps both bars visible (F-06, Decision 30)
    property bool _panelLocked: false

    function _updatePanelLock() {
        const open = RdPanels.current !== "" || rootPlayer._libraryShown
        if (open === rootPlayer._panelLocked)
            return
        rootPlayer._panelLocked = open
        // a hidden toolbar FSM ignores lock(): show it first so lock and unlock stay balanced
        if (open && !playerToolbarVisibilityFSM.isVisible)
            playerToolbarVisibilityFSM.askShow()
        rootPlayer.lockUnlockAutoHide(open)
    }

    // keyboard: a panel opened from a control bar button with the keyboard (Tab, then Space or
    // Enter) takes the focus, so the arrows act in it at once; closing it (Escape, a click
    // outside, a dialog opening) gives the focus back to that button
    property Item _panelOpener: null

    function _isInside(item, ancestor) {
        for (let p = item; p; p = p.parent) {
            if (p === ancestor)
                return true
        }
        return false
    }

    function _openPanelItem() {
        const loader = RdPanels.tracksOpen ? tracksPopupLoader
                     : RdPanels.settingsOpen ? settingsPanelLoader
                     : RdPanels.queueOpen ? queuePanelLoader : null
        return loader ? loader.item : null
    }

    function _focusOpenPanel() {
        const panel = rootPlayer._openPanelItem()
        if (panel && typeof panel.focusContent === "function")
            panel.focusContent(Qt.TabFocusReason)
    }

    Connections {
        target: RdPanels

        function onCurrentChanged() {
            rootPlayer._updatePanelLock()

            const window = rootPlayer.Window.window
            const focused = window ? window.activeFocusItem : null

            if (RdPanels.current === "") {
                // closed another way than Escape (a click outside, its button, a dialog opening):
                // the keyboard focus still in the panel, or fallen back to the player when the
                // panel hid, goes back to the button that opened it
                const opener = rootPlayer._panelOpener
                rootPlayer._panelOpener = null
                const lost = !focused || focused === rootPlayer || !focused.visible
                             || rootPlayer._isInside(focused, tracksPopupLoader)
                             || rootPlayer._isInside(focused, settingsPanelLoader)
                             || rootPlayer._isInside(focused, queuePanelLoader)
                if (opener && opener.visible && opener.enabled && lost)
                    opener.forceActiveFocus(Qt.TabFocusReason)
                return
            }
            if (focused && focused.visualFocus === true && rootPlayer._isInside(focused, controlBar)) {
                rootPlayer._panelOpener = focused
                Qt.callLater(rootPlayer._focusOpenPanel)
            }
        }
    }

    // the compact library stays open after a visit to the full library: lock the bars once the
    // toolbar FSM runs
    Connections {
        target: playerToolbarVisibilityFSM

        function onStartedChanged() {
            if (playerToolbarVisibilityFSM.started) {
                // a lock() before the start went nowhere: lock again
                rootPlayer._panelLocked = false
                rootPlayer._updatePanelLock()
            }
        }
    }

    // Escape closes the open player panel first, then the compact library, then shows the UI
    // again after Hide UI (a second Escape then leaves fullscreen as usual). In the library's
    // search field Escape closes the search, and while the keyboard moves through the library
    // it goes back a page first (VLC's Navigation). A shortcut runs before the focused control's
    // own cancel action (the control bar would otherwise leave the player).
    readonly property Item _focusItem: Window.activeFocusItem
    readonly property bool _escapeClosesLibrary: _libraryShown
            && !(librarySidebar.activeFocus
                 && (((_focusItem instanceof TextInput) && _focusItem.visible)
                     || ((librarySidebar.item?.canGoBack ?? false) && (_focusItem?.visualFocus ?? false))))

    Shortcut {
        sequences: [StandardKey.Cancel]
        // a focused Up Next card takes Escape itself (it cancels)
        enabled: (RdPanels.current !== "" || rootPlayer._escapeClosesLibrary || RdPanels.uiHidden)
                 && !upNextCard.activeFocus
        onActivated: {
            if (RdPanels.current !== "") {
                // the keyboard focus goes back to the panel's button (onCurrentChanged above)
                RdPanels.close()
            } else if (rootPlayer._escapeClosesLibrary) {
                RdPanels.libraryOpen = false
            } else {
                RdPanels.uiHidden = false
            }
        }
    }

    // the tracks popup belongs to the current file: close it when the media changes
    Connections {
        target: Player

        function onInputChanged() {
            if (RdPanels.tracksOpen)
                RdPanels.close()
        }
    }

    // the tracks popup and the sidebars sit at the right on the same band above the control bar
    // as the resume toast: while one is open the toast centers in the room left of it (its
    // 20 px right margin and a 20 px gap), so they never overlap
    readonly property real _toastRightInset: RdPanels.current !== ""
                                             ? VLCStyle.rd_sidePanelWidth + 2 * VLCStyle.dp(20, VLCStyle.scale)
                                             : 0
    readonly property real _toastRoom: width - _videoInset - _toastRightInset - 2 * VLCStyle.margin_normal

    // redesign: resume toast centered just above the control bar (video 14:00-14:10, W3.8)
    ResumeDialog {
        id: resumeToast

        anchors.horizontalCenter: parent.horizontalCenter
        // centered over the video area, right of the compact library and left of an open panel
        anchors.horizontalCenterOffset: (rootPlayer._videoInset - rootPlayer._toastRightInset) / 2
        anchors.bottom: controlBar.top
        // Figma "continue": 24 px above the control bar (visual audit A21)
        anchors.bottomMargin: VLCStyle.dp(24, VLCStyle.scale)
        z: 2

        // it hugs its sentence (Figma) and wraps it when the room is narrower
        maxWidth: rootPlayer._toastRoom

        // a room narrower than the buttons (a panel open in a narrow window, or a very long
        // button translation in the minimum window): the toast waits hidden until the room grows
        opacity: rootPlayer._toastRoom >= minimumWidth ? 1 : 0
        enabled: visible && opacity > 0

        Navigation.parentItem: rootPlayer

        onVisibleChanged: rootPlayer.lockUnlockAutoHide(visible)
    }

    // Cone extra (Decision 71, UP_NEXT_PLAN.md 7.1): the Up Next card never covers the subtitles. With a subtitle track on they sit 16 px above the subtitle
    // band (the lift over the control bar + sub-margin + two lines at the current size, whether a
    // line shows or not, so they do not jump); without, 24 px above the control bar, or above
    // the bottom edge while the bars are hidden. They show in Hide UI too (Q4).
    readonly property real _upNextBottom: {
        const dpr = MainCtx.effectiveDevicePixelRatio(Window.window) || 1.0
        const barRoom = Math.max(0, height - controlBar.y) * (controlBar.visible ? controlBar.opacity : 0)
        const minimum = barRoom + VLCStyle.dp(24, VLCStyle.scale)
        if (!RdUpNext.subtitlesOn)
            return minimum
        const margin = Number(RdEffects.values[RdEffects.videoKey("sub-margin")]) || 0
        const scaleValue = Number(RdEffects.values.subtitleTextScale) || 100
        // VLC's text size: 6.25 % of the video height at 100 % (STYLE_DEFAULT_REL_FONT_SIZE),
        // a line about 1.25 of it
        const line = playerSpecializationLoader.height * 0.0625 * (scaleValue / 100) * 1.25
        const band = (RdSubtitleLift.lift + margin) / dpr + 2 * line
        return Math.max(minimum, band + VLCStyle.dp(16, VLCStyle.scale))
    }
    // the video area beside the compact library and an open panel
    readonly property real _upNextRoom: width - _videoInset - _toastRightInset - 2 * VLCStyle.dp(24, VLCStyle.scale)

    RdUpNextCard {
        id: upNextCard

        anchors.right: parent.right
        // 24 px from the video area's right edge, left of an open panel like the resume toast
        anchors.rightMargin: rootPlayer._toastRightInset > 0 ? rootPlayer._toastRightInset
                                                             : VLCStyle.dp(24, VLCStyle.scale)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: rootPlayer._upNextBottom
        width: Math.min(implicitWidth, rootPlayer._upNextRoom)
        height: implicitHeight
        z: 3

        // Variant C's pill under 900 px of video width (Q8)
        compact: (rootPlayer.width - rootPlayer._videoInset - rootPlayer._toastRightInset) < VLCStyle.dp(900, VLCStyle.scale)
        // too small for the pill: hidden, the countdown runs on (the queue shows what is next)
        shown: RdUpNext.cardVisible && rootPlayer._upNextRoom >= minimumWidth

        Navigation.parentItem: rootPlayer

        // the bars wait while a button of the card has the focus (like the resume toast)
        onActiveFocusChanged: rootPlayer.lockUnlockAutoHide(activeFocus)
    }

    // redesign: right-click menu and Hide UI (W4.10); the video's right click arrives through
    // DialogsProvider, the audio view's here
    RdPlayerMenu {
        id: playerMenu

        onShownChanged: rootPlayer.lockUnlockAutoHide(shown)
    }

    // redesign: a right click on the control bar (its buttons included) opens the right-click
    // menu too, like a right click on the video; the top bar keeps the window menu of its
    // client-side decorations. The seek bar sends its own right click (onContextMenuRequested)
    TapHandler {
        parent: controlBar
        acceptedButtons: Qt.RightButton
        // a right button held longer than a tap still opens the menu on release, as on the video
        longPressThreshold: 0

        onTapped: playerMenu.popupAtCursor()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        enabled: !MainCtx.hasEmbededVideo

        onTapped: (eventPoint, button) => {
            if (button & Qt.RightButton) {
                playerMenu.popupAtCursor()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        propagateComposedEvents: true
        cursorShape: undefined
        // with the compact library open the mouse buttons go back and forward in the library
        onClicked: (mouse) => {
            if (rootPlayer._libraryShown && librarySidebar.item) {
                if (mouse.button === Qt.BackButton)
                    librarySidebar.item.goBack()
                else
                    librarySidebar.item.goForward()
            } else if (mouse.button === Qt.BackButton) {
                MainCtx.playerView = false
            }
        }
    }

    //filter key events to keep toolbar
    //visible when user navigates within the control bar
    KeyEventFilter {
    id: filter
    target: MainCtx.intfMainWindow

        Keys.onPressed: (event) => {
            if (Player.isInteractive)
                interactiveAutoHideTimer.restart()
            else
                playerToolbarVisibilityFSM.keyboardMove()
        }
    }
}
