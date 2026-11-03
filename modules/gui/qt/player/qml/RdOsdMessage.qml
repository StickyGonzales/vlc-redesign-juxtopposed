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
// redesign (redesign/OSD_INVENTORY.md "Final style"): Cone's on-screen message, the latest one of
// the core (RdOsd) or of the interface (UINotifier), one at a time. A 44 px box like the bar's
// parts: radius 10, BG/A3 Transparent with the bar's 1 px Divider/Dim edge and Figma's shadow; a
// plain icon, the name, the value, and the key that caused it in a small key cap. Volume and
// Muted show the control bar's own volume cone (VolumeCone shader, read only). Display only: it
// takes no input. Fades in over 120 ms, stays for "Show feedback for", fades out over 200 ms; a
// new message changes the content in place.
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

Item {
    id: root

    property bool shown: false

    readonly property bool _volume: RdOsd.level >= 0
    readonly property real _maxVolume: MainCtx.maxVolume / 100

    implicitWidth: box.width
    implicitHeight: box.height

    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? 120 : 200
            easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("On-screen message")
    Accessible.description: RdOsd.value !== "" ? RdOsd.label + " " + RdOsd.value : RdOsd.label

    Timer {
        id: hideTimer

        interval: Math.max(500, RdOsd.duration)
        onTriggered: root.shown = false
    }

    Connections {
        target: RdOsd

        function onMessageChanged() {
            root.shown = true
            hideTimer.restart()
        }
    }

    Rectangle {
        id: box

        width: row.implicitWidth + VLCStyle.dp(20, VLCStyle.scale)
        height: VLCStyle.dp(44, VLCStyle.scale)
        radius: VLCStyle.rd_radius_panel
        color: VLCStyle.palette.rdBgA3Transparent
        border.width: VLCStyle.dp(1, VLCStyle.scale)
        border.color: VLCStyle.palette.rdDividerDim

        Widgets.RdShadow {}

        Row {
            id: row

            anchors.centerIn: parent
            spacing: VLCStyle.dp(10, VLCStyle.scale)

            Widgets.RdIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: RdOsd.icon
                size: VLCStyle.dp(24, VLCStyle.scale)
                color: VLCStyle.palette.rdFgA2
            }

            // the volume control's cone (VolumeWidget.qml): 0-100 % fill the first 63 px of 88
            ShaderEffect {
                anchors.verticalCenter: parent.verticalCenter
                visible: root._volume
                width: root._volume ? VLCStyle.rd_volumeWidth : 0
                height: VLCStyle.rd_seekBarHeight

                readonly property size size: Qt.size(width, height)
                readonly property color emptyColor: VLCStyle.palette.rdVolumeEmpty
                readonly property color tint: VLCStyle.palette.rdVolumeTint
                readonly property real level: {
                    const v = Math.max(0, RdOsd.level)
                    const knee = 63 / 88
                    if (v <= 1)
                        return v * knee
                    return Math.min(1, knee + (v - 1) * (1 - knee) / Math.max(0.01, root._maxVolume - 1))
                }

                blending: true
                fragmentShader: "qrc:///shaders/VolumeCone.frag.qsb"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                // the volume's number in the time labels' style; every other name in FG/2
                text: root._volume && !RdOsd.muted ? "" : RdOsd.label
                color: VLCStyle.palette.rdFg2
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_time
                font.weight: Font.Medium
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== ""
                text: RdOsd.value
                // at most half the window: a long file name is elided
                width: Math.min(implicitWidth, (root.parent ? root.parent.width : 800) / 2)
                elide: Text.ElideMiddle
                color: root._volume ? VLCStyle.palette.rdFgA2 : VLCStyle.palette.rdFg1
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_time
                font.weight: root._volume ? Font.Normal : Font.Medium
            }

            // the key that caused it (VLC's "Pressed X"), only when a key did it
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: RdOsd.key !== ""
                width: keyText.implicitWidth + VLCStyle.dp(14, VLCStyle.scale)
                height: VLCStyle.dp(22, VLCStyle.scale)
                radius: VLCStyle.rd_radius_small
                color: VLCStyle.palette.rdBgA1
                border.width: VLCStyle.dp(1, VLCStyle.scale)
                border.color: VLCStyle.palette.rdDividerBright

                Text {
                    id: keyText

                    anchors.centerIn: parent
                    text: RdOsd.key
                    color: VLCStyle.palette.rdFgA2
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.dp(12, VLCStyle.scale)
                    font.weight: Font.Medium
                }
            }
        }
    }
}
