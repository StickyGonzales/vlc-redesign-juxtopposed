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
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Style
import VLC.Player

T.Pane {
    id: root

    property bool paintOnly: false

    readonly property color sliderColor: {
        const theme = volControl.colorContext
        return (volControl.position > _fullvolpos) ? theme.fg.negative : theme.fg.primary
    }

    readonly property var _player: paintOnly ? ({ muted: false, volume: .5 }) : Player
    readonly property int _maxvol: MainCtx.maxVolume
    readonly property real _fullvolpos: 100 / _maxvol
    readonly property real _maxvolpos: _maxvol / 100

    // redesign: sized from contentWidth / contentHeight (the row below), not from Pane's
    // implicitContentWidth / implicitContentHeight: the Pane derives those from its only content
    // child and reads 0 as soon as it has two (the wheel area below), which made the control 0 px
    // wide in the control bar, its row drawn over the buttons on its right
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             contentHeight + topPadding + bottomPadding)

    contentWidth: volumeWidget.implicitWidth
    contentHeight: volumeWidget.implicitHeight

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    // redesign: the wheel over the whole volume control, the speaker included, sets the volume as
    // over the cone (Decision 54: over the bars only the volume control reacts to the wheel)
    MouseArea {
        anchors.fill: parent

        acceptedButtons: Qt.NoButton
        enabled: !root.paintOnly

        onWheel: (wheel) => sliderMouseArea.wheelVolume(wheel)
    }

    RowLayout {
        id: volumeWidget

        anchors.fill: parent
        spacing: 0

        Widgets.IconToolButton{
            id: volumeBtn

            focus: true
            paintOnly: root.paintOnly
            text: {
                if (_player.muted)
                    return VLCIcons.volume_muted
                else if (_player.volume === 0)
                    return VLCIcons.volume_zero
                else if (_player.volume < .33)
                    return VLCIcons.volume_low
                else if (_player.volume <= .66)
                    return VLCIcons.volume_medium
                else
                    return VLCIcons.volume_high
            }
            // redesign: Figma speaker icon; the design has no muted variant, so muted keeps VLC's glyph
            rdIcon: _player.muted ? "" : "volume_value-high"
            description: qsTr("Mute")
            // the "N %" volume tooltip replaces the button's own tooltip (Figma "audio value")
            T.ToolTip.visible: false

            AccessibleCompat.id: "muteButton"

            onClicked: Player.muted = !Player.muted

            Accessible.onIncreaseAction: {
                Player.muted = false
                Player.setVolumeUp()
            }

            Accessible.onDecreaseAction: {
                Player.muted = false
                Player.setVolumeDown()
            }

            Navigation.parentItem: root
            Navigation.rightItem: volControl

            // redesign: "100 %" tooltip 63 px above the speaker while hovered (Figma "audio value", F-03)
            Widgets.RdTooltip {
                visible: (volumeBtn.hovered || volumeBtn.visualFocus) && !root.paintOnly
                text: Math.round(Player.volume * 100) + " %"
                minimumWidth: VLCStyle.dp(121, VLCStyle.scale)
                x: (volumeBtn.width - width) / 2
                y: -VLCStyle.dp(63, VLCStyle.scale)
            }
        }

        Widgets.SliderExt {
            id: volControl

            // redesign: cone slider 88x28 (Figma "volume")
            implicitWidth: VLCStyle.rd_volumeWidth
            implicitHeight: VLCStyle.rd_seekBarHeight

            // WARNING: Directly setting the insets break handle and background positioning.
            Binding on topInset {
                when: MainCtx.usingTouch
                value: VLCStyle.touchHandlerMargin
            }
            Binding on bottomInset {
                when: MainCtx.usingTouch
                value: VLCStyle.touchHandlerMargin
            }

            Layout.fillHeight: false
            Layout.preferredHeight: VLCStyle.rd_seekBarHeight
            Layout.leftMargin: VLCStyle.dp(8, VLCStyle.scale)

            // redesign: the Figma cone has no thumb (video 3:04-3:10)
            handle: Item { }

            // redesign: cone-shaped track. 0-100% fills the first 63 px of 88, 100-200% the rest
            // (Figma volume variants 50%=33, 100%=63, 200%=88). Gradient #95D318 > #B2A918 > #D37918 >
            // #FF3737 across the whole cone in every theme and accent (video 17:44-17:49), under the
            // theme's tint; unfilled part and tint from the theme's Figma Player frame (rdVolume*).
            background: ShaderEffect {
                id: cone

                implicitWidth: VLCStyle.rd_volumeWidth
                implicitHeight: VLCStyle.rd_seekBarHeight
                // the Figma cone vector ("Rectangle 6", 89x28) overhangs the 88 px slider by 1 px
                width: volControl.availableWidth * 89 / 88
                height: volControl.availableHeight

                readonly property size size: Qt.size(width, height)
                readonly property color emptyColor: VLCStyle.palette.rdVolumeEmpty
                readonly property color tint: VLCStyle.palette.rdVolumeTint
                // fraction of the cone's width; the fill mask is measured on the 88 px slider
                readonly property real level: {
                    const v = volControl.value
                    const knee = 63 / 88
                    let l
                    if (v <= 1)
                        l = Math.max(0, v) * knee
                    else
                        l = Math.min(1, knee + (v - 1) * (1 - knee) / Math.max(0.01, root._maxvolpos - 1))
                    return l * 88 / 89
                }

                blending: true
                fragmentShader: "qrc:///shaders/VolumeCone.frag.qsb"
            }

            property bool _inhibitPlayerVolumeUpdate: false

            // FIXME: Currently we are not updating the ShiftModifier status while dragging. This
            //        could be fixed with a custom Slider based on a MouseArea.
            property bool _shiftPressed: false

            property real _clamp: 0.01

            property bool _keyPressed: false

            property bool filterEvents: false

            color: root.sliderColor

            from: 0
            to: root._maxvolpos
            opacity: _player.muted ? 0.5 : 1

            enabled: !root.paintOnly // disables event handling depending on this

            toolTipTextProvider: function (value) {
                // the real value i.e 'Player.volume' bounds can be different
                // from bounds of this widget and we want to show the current
                // volume here, so directly use Player.volume instead of "value"

                return Math.round(Player.volume * 100) + "%"
            }

            Accessible.name: qsTr("Volume")
            AccessibleCompat.id: "volumeSlider"

            Keys.onPressed: (event) => {
                if (KeyHelper.matchOk(event)) {
                    event.accepted = true

                    _keyPressed = true
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            Keys.onReleased: (event) => {
                if (_keyPressed === false)
                    return

                _keyPressed = false

                if (KeyHelper.matchOk(event)) {
                    Player.muted = !Player.muted
                }
            }

            function _syncVolumeWithPlayer() {
                volControl._inhibitPlayerVolumeUpdate = true
                volControl.value = _player.volume
                volControl._inhibitPlayerVolumeUpdate = false
            }

            function _adjustPlayerVolume() {
                Player.muted = false

                let value = volControl.value

                // NOTE: We are clamping the value to make it easier to restore the default volume.
                if (_shiftPressed === false) {
                    if (Math.abs(value - 1.0) < _clamp)
                        value = 1.0
                    else
                        _clamp = 0.01
                }

                Player.volume = value

                volControl.value = value
            }

            Component.onCompleted: {
                root.paintOnlyChanged.connect(_syncVolumeWithPlayer)
                volControl._syncVolumeWithPlayer()
            }

            Connections {
                target: Player
                enabled: !paintOnly

                function onVolumeChanged() { volControl._syncVolumeWithPlayer() }
            }

            Binding on Widgets.PointingToolTipAttached.visible {
                when: sliderMouseArea.pressed
                value: true
            }

            Navigation.leftItem: volumeBtn
            Navigation.parentItem: root

            Keys.onUpPressed: (event) => {
                Player.muted = false
                Player.setVolumeUp()
            }

            Keys.onDownPressed: (event) => {
                Player.muted = false
                Player.setVolumeDown()
            }

            Keys.priority: Keys.BeforeItem

            onValueChanged: {
                if (paintOnly)
                    return

                if (!volControl._inhibitPlayerVolumeUpdate) {
                    if (filterEvents) {
                        Qt.callLater(volControl._adjustPlayerVolume)
                    } else {
                        volControl._adjustPlayerVolume()
                        filterEvents = true
                    }
                }
            }

            Rectangle{
                id: tickmark

                parent: volControl.background

                x : parent.width * root._fullvolpos
                width: VLCStyle.dp(1, VLCStyle.scale)
                height: parent.height
                radius: VLCStyle.dp(2, VLCStyle.scale)

                // NOTE: This shouldn't be visible when the volume stops before a 100.
                // redesign: no 100% tick on the cone
                visible: false

                // FIXME: tick mark is not visible when it's over slider
                color: root.sliderColor

                // NOTE: This is a helper to select the default volume when clicking on the
                //       tickmark. We apply a higher clamp value to achieve that behavior on
                //       the Slider.
                MouseArea {
                    anchors.fill: parent

                    anchors.margins: -(VLCStyle.dp(4, VLCStyle.scale))

                    onPressed: (mouse) => {
                        mouse.accepted = false

                        if (mouse.modifiers === Qt.ShiftModifier)
                            return

                        volControl._clamp = 0.1
                    }
                }
            }

            MouseArea {
                id: sliderMouseArea

                anchors.fill: parent

                acceptedButtons: (Qt.LeftButton | Qt.RightButton)

                onPressed: (mouse) => {
                    if (root.paintOnly) {
                        mouse.accepted = true
                        return
                    }

                    volControl._shiftPressed = (mouse.modifiers === Qt.ShiftModifier)

                    if (mouse.button === Qt.LeftButton) {
                        mouse.accepted = false

                        return
                    }

                    volControl.filterEvents = false
                    adjustVolume(mouse)
                }

                onPositionChanged: (mouse) => {
                    if (mouse.buttons & Qt.RightButton)
                        adjustVolume(mouse)
                }

                onWheel: (wheel) => wheelVolume(wheel)

                function wheelVolume(wheel) {
                    if ((Math.abs(wheel.pixelDelta.x) % 120 > 0) || (Math.abs(wheel.pixelDelta.y) % 120 > 0)) {
                        let delta = 0
                        if (Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y))
                            delta = wheel.pixelDelta.x
                        else
                            delta = wheel.pixelDelta.y

                        if (wheel.inverted)
                            delta = -delta
                        volControl.value += 0.001 * delta
                    }
                    else
                        wheelToVLC.qmlWheelEvent(wheel)

                    wheel.accepted = true
                }

                function adjustVolume(mouse) {
                    mouse.accepted = true

                    const pos = mouse.x * root._maxvolpos / width

                    if (pos < 0.25)
                        volControl.value = 0
                    else if (pos < 0.75)
                        volControl.value = 0.5
                    else if (pos < 1.125)
                        volControl.value = 1
                    else
                        volControl.value = 1.25
                }

                WheelToVLCConverter {
                    id: wheelToVLC

                    function handle(steps: int) {
                        if (steps > 0)
                            Player.setVolumeUp(steps)
                        else
                            Player.setVolumeDown(-steps)
                    }

                    Component.onCompleted: {
                        wheelUpDown.connect(wheelToVLC.handle)
                        wheelLeftRight.connect(wheelToVLC.handle)
                    }
                }
            }
        }
    }
}
