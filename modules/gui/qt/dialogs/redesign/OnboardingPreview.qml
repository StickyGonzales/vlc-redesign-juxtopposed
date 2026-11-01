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

// redesign (W8.3, video 19:49, Figma "Onboarding" 1902:3670 "Player"): the still picture of the
// player behind the theme and color choices. It is drawn at the size of the Figma player
// (1920 x 1080: top bar 40, control bar 54) and scaled down to the item's width, so every part
// keeps the Figma proportions; it uses the theme colors and the accent, so it follows the
// choices live. Nothing in it reacts to the mouse.
import QtQuick

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style

Item {
    id: root

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // Figma player frame at full size
    readonly property real _designWidth: 1920
    readonly property real _designHeight: 1080

    implicitWidth: VLCStyle.dp(1056, VLCStyle.scale)
    implicitHeight: implicitWidth * _designHeight / _designWidth

    clip: true

    Accessible.ignored: true

    Rectangle {
        width: root._designWidth
        height: root._designHeight

        transformOrigin: Item.TopLeft
        scale: root.width / root._designWidth

        color: root.rdPalette.rdBgB2

        // window title bar (Figma "Frame 2"): 40 px, BG/A4, cone left, window buttons right
        Rectangle {
            width: parent.width
            height: 40
            color: root.rdPalette.rdBgA4

            Widgets.RdIcon {
                x: 13
                y: 8
                size: 24
                // drawn scaled down with the whole preview: the small-size logo
                name: Brand.logoIconSmall
                accentColor: root.rdPalette.rdAccentLogo
            }

            Row {
                x: 1776
                y: 8
                spacing: 12

                Repeater {
                    model: ["minimize", "maximize", "fullscreen", "close"]

                    Widgets.RdIcon {
                        required property string modelData

                        size: 24
                        name: modelData
                    }
                }
            }
        }

        // control bar (Figma "Controls", default): 54 px, BG/A3 Transparent; its 1 px Divider/Dim
        // stroke is left out like on the real control bar (not visible in the Figma exports)
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: 54

            color: root.rdPalette.rdBgA3Transparent

            Widgets.RdIcon {
                x: 23
                y: 15
                size: 24
                name: "previous"
            }

            // play button: accent pill 54 x 28, radius 6
            Rectangle {
                x: 58
                y: 13
                width: 54
                height: 28
                radius: 6
                color: root.rdPalette.rdAccentMain

                Widgets.RdIcon {
                    x: 16
                    y: 2
                    size: 24
                    name: "play"
                    color: root.rdPalette.rdFgOnAccent
                }
            }

            Widgets.RdIcon {
                x: 123
                y: 15
                size: 24
                name: "next"
            }

            component TimeLabel: Text {
                y: 13
                width: 76
                height: 28
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: 15
                color: VLCStyle.palette.rdFgA2
            }

            TimeLabel {
                x: 170
                text: "00:02:10"
            }

            // seek bar: BG/B2 track, BG/Accent Bright fill, accent handle
            Rectangle {
                x: 254
                y: 13
                width: 1238
                height: 28
                radius: 6
                color: root.rdPalette.rdBgB2

                Rectangle {
                    x: 2
                    y: 2
                    width: 98
                    height: 24
                    radius: 4
                    color: root.rdPalette.rdBgAccentBright
                }

                Rectangle {
                    x: 92
                    y: 2
                    width: 8
                    height: 24
                    radius: 4
                    color: root.rdPalette.rdAccentMain
                }
            }

            TimeLabel {
                x: 1500
                text: "00:25:40"
            }

            Widgets.RdIcon {
                x: 1596
                y: 15
                size: 24
                name: "volume_value-high"
            }

            // volume at 50 %: the control bar's cone (VolumeWidget), 33 of 88 px filled
            ShaderEffect {
                x: 1628
                y: 13
                width: 88
                height: 28

                readonly property size size: Qt.size(width, height)
                readonly property real tipRadius: height * 0.12
                readonly property color emptyColor: root.rdPalette.rdVolumeEmpty
                readonly property color tint: root.rdPalette.rdVolumeTint
                readonly property real level: 33 / 88

                blending: true
                fragmentShader: "qrc:///shaders/VolumeCone.frag.qsb"
            }

            Row {
                x: 1739
                y: 15
                spacing: 18

                Repeater {
                    model: ["audio", "subtitles", "playback-settings"]

                    Widgets.RdIcon {
                        required property string modelData

                        size: 24
                        name: modelData
                    }
                }
            }

            Widgets.RdIcon {
                x: 1873
                y: 15
                size: 24
                name: "lists"
            }
        }
    }
}
