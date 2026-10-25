/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
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

// redesign: play / pause pill (video 1:16-2:15, 4:07; Figma "play" 54x28, radius 6).
// Paused: Accent/Main pill with a FG/B1 play glyph. Playing: FG/A3 pill with a pause glyph.
// The state switch is instant. Press and hold still stops playback, as in VLC.
import QtQuick
import QtQuick.Templates as T


import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Util

T.Control {
    id: root

    // Properties

    property bool paintOnly: false

    readonly property bool _playing: !paintOnly
                                     && Player.playingState !== Player.PLAYING_STATE_PAUSED
                                     && Player.playingState !== Player.PLAYING_STATE_STOPPED

    readonly property ColorContext colorContext: ColorContext {
        id: theme

        colorSet: ColorContext.ToolButton

        enabled: root.enabled || root.paintOnly
        focused: root.activeFocus
        hovered: root.cursorInside
        pressed: mouseArea.containsPress
    }

    property bool _keyOkPressed: false

    // Aliases

    property alias cursorInside: mouseArea.containsMouse

    // Settings

    implicitWidth: implicitBackgroundWidth + leftInset + rightInset
    implicitHeight: implicitBackgroundHeight + topInset + bottomInset

    scale: (_keyOkPressed || (mouseArea.pressed && cursorInside)) ? 0.95
                                                                  : 1.00

    Accessible.role: Accessible.Button
    Accessible.name: qsTr("Play/Pause")
    AccessibleCompat.id: "playButton"
    Accessible.checkable: true
    Accessible.checked: _playing
    Accessible.onPressAction: MainPlaylistController.togglePlayPause()
    Accessible.onToggleAction: MainPlaylistController.togglePlayPause()

    // Tooltip

    T.ToolTip.visible: (hovered || visualFocus) && !_toolTipDismissed

    // redesign: a click or Enter hides the tooltip until the pointer and the keyboard focus
    // leave the button (it stayed over the video and the panels)
    property bool _toolTipDismissed: false
    onHoveredChanged: if (!hovered && !visualFocus) _toolTipDismissed = false
    onVisualFocusChanged: if (!hovered && !visualFocus) _toolTipDismissed = false
    T.ToolTip.delay: VLCStyle.delayToolTipAppear
    T.ToolTip.text: root.Accessible.name

    // Keys

    Keys.onPressed: (event) => {
        if (KeyHelper.matchOk(event) ) {
            if (!event.isAutoRepeat) {
                _keyOkPressed = true
                _toolTipDismissed = true
                keyHoldTimer.restart()
            }
            event.accepted = true
        }
        Navigation.defaultKeyAction(event)
    }

    Keys.onReleased: (event) => {
        if (KeyHelper.matchOk(event)) {
            if (!event.isAutoRepeat) {
                const held = !keyHoldTimer.running
                _keyOkPressed = false
                keyHoldTimer.stop()
                if (!held && Player.playingState !== Player.PLAYING_STATE_STOPPED)
                    MainPlaylistController.togglePlayPause()
            }
            event.accepted = true
        }
    }

    // Functions

    function _pressAndHoldAction() {
        _keyOkPressed = false
        MainPlaylistController.stop()
    }

    // Children

    Timer {
        id: keyHoldTimer

        interval: mouseArea.pressAndHoldInterval
        repeat: false

        onTriggered: root._pressAndHoldAction()
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent

        hoverEnabled: true
        // redesign: the pointing hand over the clickable controls
        cursorShape: root.paintOnly ? undefined : Qt.PointingHandCursor

        onPressed: (mouse) => {
            if (root.paintOnly) {
                mouse.accepted = false
                return
            }

            root.forceActiveFocus(Qt.MouseFocusReason)
            root._toolTipDismissed = true
        }

        onClicked: (mouse) => {
            MainPlaylistController.togglePlayPause()
            mouse.accepted = true
        }

        onPressAndHold: (mouse) => {
            root._pressAndHoldAction()
            mouse.accepted = true
        }
    }

    contentItem: Item {
        Widgets.RdIcon {
            anchors.centerIn: parent
            // Figma padding 2,15,2,17 (play) and 2,15,2,15 (pause): the play glyph sits 1 px right
            anchors.horizontalCenterOffset: root._playing ? 0 : VLCStyle.dp(1, VLCStyle.scale)

            name: root._playing ? "pause" : "play"
            color: VLCStyle.palette.rdFgB1
        }
    }

    background: Rectangle {
        implicitWidth: VLCStyle.rd_playButtonWidth
        implicitHeight: VLCStyle.rd_playButtonHeight

        radius: VLCStyle.rd_radius_normal

        color: {
            if (root._playing)
                return root.cursorInside ? Qt.tint(VLCStyle.palette.rdFgA3, VLCStyle.palette.rdHoverOverlay)
                                         : VLCStyle.palette.rdFgA3
            return root.cursorInside ? VLCStyle.palette.rdAccentBright : VLCStyle.palette.rdAccentMain
        }

        border.width: root.visualFocus ? VLCStyle.focus_border : 0
        border.color: theme.visualFocus
    }
}
