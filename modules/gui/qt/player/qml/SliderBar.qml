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
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts
import QtQuick.Window

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util
import VLC.MainInterface

T.ProgressBar {
    id: control

    readonly property real _hoveredScalingFactor: 1.8
    property int barHeight: VLCStyle.dp(5, VLCStyle.scale)
    readonly property real _scaledBarHeight: control.barHeight * _hoveredScalingFactor
    readonly property real _scaledY: (-control.barHeight / 2) * (control._hoveredScalingFactor - 1)

    property bool _isSeekPointsShown: true
    readonly property int _seekPointsDistance: VLCStyle.dp(2, VLCStyle.scale)
    readonly property int _seekPointsRadius: VLCStyle.dp(0.5, VLCStyle.scale)
    readonly property real _scaledSeekPointsRadius: _seekPointsRadius * _hoveredScalingFactor

    property bool _currentChapterHovered: false
    property real _tooltipPosition: (Widgets.PointingToolTipAttached.instance?.pos.x ?? 0.0) / width

    property color backgroundColor: theme.bg.primary
    // redesign: thick seek bar (Figma "Frame 21": 28 px track BG/B2 radius 6, 24 px played fill
    // BG/Accent Bright inset 2 px, 8x24 accent playhead always visible)
    property bool thick: false
    readonly property real _inset: thick ? VLCStyle.dp(2, VLCStyle.scale) : 0
    property real touchHandlerMargin: VLCStyle.touchHandlerMargin

    // redesign: a right click on the bar, for the owner's context menu. The bar (a Control)
    // accepts every mouse button, so a right-click handler of an item below or around it never
    // sees the click
    signal rightClicked()

    Keys.onRightPressed: Player.jumpFwd()
    Keys.onLeftPressed: Player.jumpBwd()

    Accessible.onIncreaseAction: Player.jumpFwd()
    Accessible.onDecreaseAction: Player.jumpBwd()

    function showChapterMarks() {
        _isSeekPointsShown = true
        seekpointTimer.restart()
    }

    readonly property ColorContext colorContext: ColorContext {
        id: theme
        colorSet: ColorContext.Slider

        enabled: control.enabled
        focused: control.visualFocus
        hovered: hoverHandler.hovered
    }

    Timer {
        id: seekpointTimer
        running: Player.hasChapters && !hoverHandler.hovered && _isSeekPointsShown
        interval: 3000
        onTriggered: control._isSeekPointsShown = false
    }

    // redesign: preview card (P2-04 / IA-14, video 3:24-3:31, Figma "thumbnail"; Decision 6:
    // anywhere along the bar). Hovering or dragging the thick bar shows a frame of the position
    // under the pointer with its time; it replaces the time tooltip, which stays for keyboard
    // focus and for media without frames (streams, audio, the option off; RdSeekThumbnailer)
    readonly property bool _previewOption: RdEffects.values[RdEffects.optionKey("qt-seek-thumbnails")] !== false
    readonly property bool _previewAvailable: control.thick && control._previewOption && control.enabled
                                              && control.visible && RdSeekThumbnailer.supported
                                              && Player.seekable && Player.videoTracks.count > 0
    // the pointer is scrubbing: over the bar, or dragging it (also past its ends)
    readonly property bool scrubbing: hoverHandler.hovered || dragHandler.active
    readonly property bool dragging: dragHandler.active
    readonly property bool _previewShown: control._previewAvailable && control.scrubbing
    readonly property real _scrubX: Helpers.clamp(dragHandler.active ? dragHandler.centroid.position.x
                                                                     : hoverHandler.point.position.x,
                                                  0, control.width)
    // the position under the pointer (0..1); the current time label shows it while dragging
    readonly property real scrubPosition: control.width > 0 ? control._scrubX / control.width : 0

    // redesign: waveform seek bar (P6-06 / IB-24, Figma Controls "Property 1=waveform"). With the
    // Playback tab's "Show Waveform on Seekbar" on, the thick bar draws the playing file's
    // waveform once its background scan is ready (RdWaveform); until then the plain fill stays,
    // then the bars fade in over it and the playhead narrows to 4 px around the same center.
    // The layer takes no input: hover, drag, the preview card, keys and the right click
    // stay the bar's
    readonly property bool _waveformOption: RdEffects.values[RdEffects.optionKey("qt-seek-waveform")] === true
    readonly property bool waveformShown: waveform.ready

    function _updatePreview() {
        if (control._previewShown)
            RdSeekThumbnailer.request(control.scrubPosition)
        else
            RdSeekThumbnailer.stop()
    }

    on_PreviewShownChanged: control._updatePreview()
    onScrubPositionChanged: {
        if (control._previewShown)
            RdSeekThumbnailer.request(control.scrubPosition)
    }

    // a bar removed while its card is shown (control bar layout change, player page closed)
    // leaves no request running
    Component.onDestruction: {
        if (control._previewShown)
            RdSeekThumbnailer?.stop()
    }

    // frames are made at the card's size in device pixels
    readonly property real _devicePixelRatio: Screen.devicePixelRatio

    Binding {
        target: RdSeekThumbnailer
        property: "frameSize"
        when: control.thick
        // several thick bars may exist: none puts back an older size when it goes
        restoreMode: Binding.RestoreNone
        value: Qt.size(Math.round(VLCStyle.rd_seekPreviewPictureWidth * control._devicePixelRatio),
                       Math.round(VLCStyle.rd_seekPreviewPictureHeight * control._devicePixelRatio))
    }

    // above every bar and panel of the window, centered on the pointer, its bottom edge
    // rd_seekPreviewGap above the bar, kept inside the window. It joins the window overlay
    // only while shown (an overlay with children stays visible over the whole window)
    readonly property Item _windowOverlay: T.Overlay.overlay

    RdSeekPreview {
        id: seekPreview

        readonly property Item _overlay: control._previewShown ? control._windowOverlay : null

        parent: _overlay ?? control
        visible: !!_overlay

        readonly property point _anchor: _overlay ? control.mapToItem(_overlay, control._scrubX, 0)
                                                  : Qt.point(0, 0)

        x: Helpers.clamp(_anchor.x - width / 2, VLCStyle.rd_seekPreviewEdgeMargin,
                         (parent ? parent.width : 0) - width - VLCStyle.rd_seekPreviewEdgeMargin)
        y: Math.max(VLCStyle.rd_seekPreviewEdgeMargin, _anchor.y - VLCStyle.rd_seekPreviewGap - height)

        source: RdSeekThumbnailer.source
        timeText: visible ? Player.length.scale(control.scrubPosition).formatHHMMSS() : ""
    }

    Widgets.PointingToolTipAttached.visible: !control._previewShown
                                             && (hoverHandler.hovered || control.visualFocus || dragHandler.active)

    Widgets.PointingToolTipAttached.text: {
        if (!Widgets.PointingToolTipAttached.instance?.visible)
            return ""

        let _text

        const length = Player.length
        if (hoverHandler.hovered)
            _text = length.scale(Widgets.PointingToolTipAttached.instance.pos.x / control.width)
        else
            _text = Player.time

        _text = _text.formatHMS(length.isSubSecond() ? VLCTick.SubSecondFormattedAsMS : 0)

        if (Player.hasChapters)
            _text += " - " + Player.chapters.getNameAtPosition(control._tooltipPosition)

        return _text
    }

    Widgets.PointingToolTipAttached.pos: Qt.point(hoverHandler.hovered ? Helpers.clamp(hoverHandler.point.position.x, 0, control.availableWidth)
                                                                       : (control.visualPosition * control.width), 0)

    FSM {
        id: fsm
        signal playerUpdatePosition(real position)
        signal pressControl(real position, bool forcePrecise)
        signal releaseControl(real position, bool forcePrecise)
        signal moveControl(real position, bool forcePrecise)
        signal inputChanged()

        //each signal is associated to a key, when a signal is received,
        //transitions of active state for the given key are evaluated
        signalMap: ({
            "playerUpdatePosition": fsm.playerUpdatePosition,
            "pressControl": fsm.pressControl,
            "releaseControl": fsm.releaseControl,
            "moveControl": fsm.moveControl,
            "inputChanged": fsm.inputChanged
        })

        initialState: fsmReleased

        function _setPositionFromValue(position) {
            control.value = position
        }

        function _seekToPosition(position, threshold, forcePrecise) {
            position = Helpers.clamp(position, 0., 1.)
            control.value = position
            if (!forcePrecise) {
                const chapter = Player.chapters.getClosestChapterFromPos(position, threshold)
                if (chapter !== -1) {
                    Player.chapters.selectChapter(chapter)
                    return
                }
            }
            Player.position = position
        }

        FSMState {
            id: fsmReleased

            transitions: ({
                "playerUpdatePosition": {
                    action: (position) => {
                        control.value = position
                    }
                },
                "pressControl": {
                    action: (position, forcePrecise) => {
                        control.forceActiveFocus()
                        fsm._seekToPosition(position, VLCStyle.dp(4, VLCStyle.scale) / control.width, forcePrecise)
                    },
                    target: fsmHeld
                }
            })
        }

        FSMState  {
            id: fsmHeld

            transitions: ({
                "moveControl": {
                    action: (position, forcePrecise) => {
                        fsm._seekToPosition(position, VLCStyle.dp(2, VLCStyle.scale) / control.width, forcePrecise)
                    }
                },
                "releaseControl": {
                    target: fsmReleased
                },
                "inputChanged": {
                    target: fsmHeldWrongInput
                }
            })
        }

        FSMState  {
            id: fsmHeldWrongInput

            function enter() {
                fsm._setPositionFromValue(Player.position)
            }

            transitions: ({
                "playerUpdatePosition": {
                    action: fsm._setPositionFromValue
                },
                "releaseControl": {
                    target: fsmReleased
                }
            })
        }
    }

    Connections {
        target: Player
        function onPositionChanged() {  fsm.playerUpdatePosition(Player.position) }
        function onInputChanged() {  fsm.inputChanged() }
    }

    Component.onCompleted: value = Player.position

    implicitHeight: control.barHeight
    height: implicitHeight

    padding: 0

    //we use our own HoverHandler
    hoverEnabled: false

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: () => {
            if (hovered) {
                if(Player.hasChapters)
                    control._isSeekPointsShown = true
            } else {
                if(Player.hasChapters)
                    seekpointTimer.restart()
            }
        }
    }

    // on the bar itself, not in contentItem: there the Control would accept the press after the
    // handler and the right click would also reach the handlers around the bar
    TapHandler {
        acceptedButtons: Qt.RightButton

        // a right button held longer than a tap still counts, as a context menu on release
        longPressThreshold: 0

        onTapped: control.rightClicked()
    }

    contentItem: Item {
        implicitHeight: control.implicitHeight
        implicitWidth: control.implicitWidth

        //placing the TapHandler directly in the Control doesn't work with 6.2
        TapHandler {
            acceptedButtons: Qt.LeftButton

            gesturePolicy: TapHandler.WithinBounds

            // Make it easier to tap with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0.0

            onPressedChanged: {
                if (pressed) {
                    fsm.pressControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                } else {
                    // NOTE: Point is still valid at this point.
                    fsm.releaseControl(point.position.x / control.width, point.modifiers === Qt.ShiftModifier)
                }
            }
        }

        DragHandler {
            id: dragHandler
            acceptedButtons: Qt.LeftButton

            // Make it easier to drag with touch screen:
            margin: MainCtx.usingTouch ? control.touchHandlerMargin : 0

            target: null
            dragThreshold: 0
            grabPermissions: PointerHandler.CanTakeOverFromAnything

            property bool filterEvents: false

            function moveControl() {
                fsm.moveControl(dragHandler.centroid.position.x / control.width,
                                dragHandler.centroid.modifiers === Qt.ShiftModifier)
            }

            onActiveChanged: {
                if (active) {
                    filterEvents = false
                    fsm.pressControl(centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                } else {
                    fsm.releaseControl( centroid.position.x / control.width, centroid.modifiers === Qt.ShiftModifier)
                }
            }

            onCentroidChanged: {
                // FIXME: Qt 6.5 use xAxis.onActiveValueChanged in the DragHandler
                if (filterEvents) {
                    Qt.callLater(dragHandler.moveControl)
                } else {
                    dragHandler.moveControl()
                    filterEvents = true
                }
            }
        }

        // redesign: the seek bar takes no wheel (Decision 54): over the bars only the volume control
        // reacts to it, the control bar takes the rest
    }

    background: Item {
        width: control.availableWidth
        implicitHeight: control.implicitHeight
        height: implicitHeight

        Rectangle {
            id: sliderRect
            visible: control.thick || !Player.hasChapters
            color: control.thick ? VLCStyle.palette.rdBgB2 : control.backgroundColor
            anchors.fill: parent
            radius: control.thick ? VLCStyle.rd_radius_normal : implicitHeight
        }

        Repeater {
            id: seekpointsRptr

            anchors.left: parent.left
            anchors.right: parent.right
            height: control.barHeight
            visible: Player.hasChapters && !control.thick

            model: Player.chapters
            Item {
                Rectangle {
                    id: seekpointsRect
                    readonly property real startPosition: model.startPosition ??  0.0
                    readonly property real endPosition: model.endPosition ?? 1.0

                    readonly property int _currentChapter: {
                        if (control.visualPosition < seekpointsRect.startPosition)
                            return 1
                        else if (control.visualPosition > seekpointsRect.endPosition)
                            return -1
                        return 0
                    }
                    on_CurrentChapterChanged: {
                        if(_hovered)
                            control._currentChapterHovered = _currentChapter === 0
                    }

                    readonly property bool _hovered: hoverHandler.hovered &&
                                            (hoverHandler.point.position.x > x && hoverHandler.point.position.x < x+width)

                    color: _currentChapter < 0 ? theme.fg.primary : control.backgroundColor
                    width: sliderRect.width * seekpointsRect.endPosition - x - control._seekPointsDistance
                    x: sliderRect.width * seekpointsRect.startPosition

                    Rectangle {
                        id: progressRepRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        radius: parent.radius

                        width: sliderRect.width * control.visualPosition - parent.x - control._seekPointsDistance
                        visible: parent._currentChapter === 0
                        color: theme.fg.primary

                        // We use dynamic mutability group because time interpolation
                        // may induce rapid change:
                        // TODO: Do not use `Binding` when minimum Qt is 6.12:
                        Binding {
                            target: progressRepRect
                            property: "mutabilityGroup"
                            when: (progressRepRect.mutabilityGroup !== undefined)
                            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                                          : Item.StaticMutabilityGroup
                        }
                    }
                }

                transitions: [
                    Transition {
                        to: "*"
                        SequentialAnimation{
                            PropertyAction { targets: control; property: "_currentChapterHovered" }
                            NumberAnimation {
                                targets: [seekpointsRect, progressRepRect]; properties: "height, y, radius"
                                duration: VLCStyle.duration_short; easing.type: Easing.InSine
                            }
                        }
                    }
                ]

                states:[
                    State {
                        name: "visible"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? false : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control.barHeight }
                        PropertyChanges { target: seekpointsRect; y: 0 }
                        PropertyChanges { target: seekpointsRect; radius: control._seekPointsRadius }
                    },
                    State {
                        name: "visibleLarge"
                        PropertyChanges {
                            target: control;
                            _currentChapterHovered: seekpointsRect._currentChapter === 0 ? true : control._currentChapterHovered
                        }
                        PropertyChanges { target: seekpointsRect; height: control._scaledBarHeight }
                        PropertyChanges { target: seekpointsRect; y: control._scaledY }
                        PropertyChanges { target: seekpointsRect; radius: control._scaledSeekPointsRadius }
                    }
                ]

                state: (seekpointsRect._hovered || (seekpointsRect._currentChapter === 0 && fsm._state === fsm.fsmHeld))
                       ? "visibleLarge"
                       : "visible"
            }
        }

        Rectangle {
            id: progressRect
            x: control._inset
            y: control._inset
            width: Math.max(0, control.visualPosition * (parent.width - 2 * control._inset))
            visible: (control.thick || !Player.hasChapters) && opacity > 0
            opacity: control.waveformShown ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }
            color: control.thick ? VLCStyle.palette.rdBgAccentBright : theme.fg.primary
            height: control.barHeight - 2 * control._inset
            radius: control.thick ? VLCStyle.rd_radius_small : control._seekPointsRadius

            // We use dynamic mutability group because time interpolation
            // may induce rapid change:
            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: progressRect
                property: "mutabilityGroup"
                when: (progressRect.mutabilityGroup !== undefined)
                value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                              : Item.StaticMutabilityGroup
            }
        }

        // the bars of the waveform, cut around the playhead (played: Accent/DIm, the others
        // FG/A4; both follow the live accent and theme)
        RdWaveformItem {
            id: waveform

            anchors.fill: parent
            visible: opacity > 0
            opacity: ready ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: VLCStyle.duration_short } }

            source: RdWaveform
            active: control.thick && control._waveformOption

            playheadX: sliderHandle.x + sliderHandle.width / 2
            playheadWidth: sliderHandle.width
            playheadGap: VLCStyle.rd_waveformPlayheadGap
            playedColor: VLCStyle.palette.rdAccentDim
            unplayedColor: VLCStyle.palette.rdFgA4

            barWidth: VLCStyle.rd_waveformBarWidth
            barSpacing: VLCStyle.rd_waveformBarSpacing
            barMinHeight: VLCStyle.rd_waveformBarMinHeight
            barMaxHeight: VLCStyle.rd_waveformBarMaxHeight
            barStep: VLCStyle.rd_waveformBarStep
            horizontalPadding: VLCStyle.rd_waveformPadding
        }

        Rectangle {
            id: bufferRect
            property int bufferAnimWidth: VLCStyle.dp(100, VLCStyle.scale)
            property int bufferAnimPosition: 0
            property int bufferFrames: 1000
            property alias animateLoading: loadingAnim.running
            property bool display: false
            property bool buffering: Player.buffering > 0 && Player.buffering < 1

            height: control.barHeight
            opacity: 0.4
            color: theme.fg.neutral //FIXME buffer color ?
            radius: control.barHeight

            // TODO: Do not use `Binding` when minimum Qt is 6.12:
            Binding {
                target: bufferRect
                property: "mutabilityGroup"
                when: bufferRect.mutabilityGroup !== undefined
                value: bufferRect.buffering ? Item.DynamicMutabilityGroup
                                            : Item.StaticMutabilityGroup
            }

            Timer {
                id: bufferingTimer
                interval: VLCStyle.duration_humanMoment
                repeat: false
                running: false
                onTriggered: {
                    bufferRect.display = true
                }
            }

            onBufferingChanged: {
                if(buffering)
                {
                    bufferingTimer.start()
                }
                else
                {
                    bufferingTimer.stop()
                    bufferRect.display = false
                }
            }

            states: [
                State {
                    name: "hidden"
                    when: !control.visible
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "buffering not started"
                    when: control.visible && Player.buffering === 0
                    PropertyChanges {
                        target: bufferRect
                        width: bufferAnimWidth
                        visible: true
                        x: (bufferAnimPosition / bufferFrames) * (parent.width - bufferAnimWidth)
                        animateLoading: true
                    }
                },
                State {
                    name: "time to start playing known"
                    when: control.visible && bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: true
                        x: 0
                        animateLoading: false
                    }
                },
                State {
                    name: "playing from buffer"
                    when: control.visible && !bufferRect.display
                    PropertyChanges {
                        target: bufferRect
                        width: Player.buffering * parent.width
                        visible: false
                        x: 0
                        animateLoading: false
                    }
                }
            ]

            SequentialAnimation on bufferAnimPosition {
                id: loadingAnim
                running: bufferRect.animateLoading
                loops: Animation.Infinite
                PropertyAnimation {
                    from: 0.0
                    to: bufferRect.bufferFrames
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
                PropertyAnimation {
                    from: bufferRect.bufferFrames
                    to: 0.0
                    duration: VLCStyle.durationSliderBouncing
                    easing.type: "OutBounce"
                }
                PauseAnimation {
                    duration: VLCStyle.duration_veryLong
                }
            }
        }
    }

    Rectangle {
        id: sliderHandle

        property int _size: control.barHeight * 3

        x: control.thick ? Math.max(control._inset, Math.min(control.availableWidth - width - control._inset,
                                                             (control.visualPosition * control.availableWidth) - width / 2))
                         : (control.visualPosition * control.availableWidth) - width / 2
        y: (control.barHeight - height) / 2

        implicitWidth: control.thick ? (control.waveformShown ? VLCStyle.rd_waveformPlayheadWidth
                                                              : VLCStyle.rd_seekHandleWidth)
                                     : sliderHandle._size
        // the thick bar's playhead narrows with the waveform (the thin bar animates by states)
        Behavior on implicitWidth {
            enabled: control.thick
            NumberAnimation { duration: VLCStyle.duration_short }
        }
        implicitHeight: control.thick ? control.barHeight - 2 * control._inset : sliderHandle._size
        radius: control.thick ? VLCStyle.rd_radius_small : VLCStyle.margin_small
        color: theme.fg.primary

        // We use dynamic mutability group because time interpolation
        // may induce rapid change:
        // TODO: Do not use `Binding` when minimum Qt is 6.12:
        Binding {
            target: sliderHandle
            property: "mutabilityGroup"
            when: (sliderHandle.mutabilityGroup !== undefined)
            value: (Player.playingState === Player.PLAYING_STATE_PLAYING) ? Item.DynamicMutabilityGroup
                                                                          : Item.StaticMutabilityGroup
        }

        transitions: [
            Transition {
                to: "hidden"
                SequentialAnimation {
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: 0
                        duration: VLCStyle.duration_short; easing.type: Easing.OutSine
                    }
                    PropertyAction { target: sliderHandle; property: "visible"; value: false; }
                }
            },
            Transition {
                to: "visible"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            },
            Transition {
                to: "visibleLarge"
                SequentialAnimation {
                    PropertyAction { target: sliderHandle; property: "visible"; value: true; }
                    NumberAnimation {
                        target: sliderHandle; properties: "implicitWidth,implicitHeight"
                        to: sliderHandle._size * (0.8 * control._hoveredScalingFactor)
                        duration: VLCStyle.duration_short; easing.type: Easing.InSine
                    }
                }
            }
        ]

        state: control.thick ? "" : (hoverHandler.hovered || control.visualFocus)
               ? ((control._currentChapterHovered || (Player.hasChapters && fsm._state === fsm.fsmHeld)) ? "visibleLarge" : "visible")
               : "hidden"
    }
}
