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
// redesign: the equalizer inside Settings > Audio (video 18:06-18:08, P8-44; Figma "EQ"
// component in "Settings - audio" / "Settings - audio-1"): a BG/A4 panel (radius 2) with an
// "Open Equalizer" / "Close Equalizer" toggle on top; open, the preamp and the ten bands as
// vertical sliders (track 16x320 BG/B2, accent background fill from the bottom, horizontal
// accent thumb), each with its name (FG/A3) and its value box (60x32) below. The same
// equalizer as the settings sidebar (RdEffects): moving a band turns the equalizer on.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

Rectangle {
    id: root

    property bool expanded: false

    readonly property int _preset: RdEffects.values.equalizerPreset
    readonly property var _bands: RdEffects.values.equalizerBands
    readonly property real _preamp: Number(RdEffects.values[RdEffects.audioKey("equalizer-preamp")] ?? 0)

    function _ensureEqualizer() {
        if (_preset < 0)
            RdEffects.setAudioFilterEnabled("equalizer", true)
    }

    implicitHeight: column.implicitHeight + VLCStyle.dp(6) + (expanded ? VLCStyle.dp(20) : VLCStyle.dp(6))
    radius: VLCStyle.rd_radius_xsmall
    color: VLCStyle.palette.rdBgA4

    Column {
        id: column

        y: VLCStyle.dp(6)
        width: parent.width
        spacing: VLCStyle.dp(24)

        // Figma "Frame 275": text + chevron, centered
        T.AbstractButton {
            id: header

            // the pointing hand over the clickable controls
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: headerRow.implicitWidth + VLCStyle.dp(12)
            implicitHeight: VLCStyle.dp(24)

            focusPolicy: Qt.StrongFocus
            hoverEnabled: true

            Accessible.role: Accessible.Button
            Accessible.name: headerText.text

            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()

            onClicked: root.expanded = !root.expanded

            background: Rectangle {
                radius: VLCStyle.rd_radius_small
                color: header.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent"
                border.width: header.visualFocus ? VLCStyle.dp(1) : 0
                border.color: VLCStyle.palette.rdFgA3
            }

            contentItem: Item {
                Row {
                    id: headerRow

                    anchors.centerIn: parent
                    spacing: VLCStyle.dp(10)

                    Text {
                        id: headerText

                        anchors.verticalCenter: parent.verticalCenter
                        text: root.expanded ? qsTr("Close Equalizer") : qsTr("Open Equalizer")
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: VLCStyle.palette.rdFgA2
                    }

                    Widgets.RdIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.expanded ? "chevron_direction-up" : "chevron_direction-down"
                        color: VLCStyle.palette.rdFgA2
                    }
                }
            }
        }

        // Figma "Frame 309": 60 px columns, 8 px apart, centered; the eleven columns (740 px)
        // scroll sideways when the page is narrower (a small window)
        Loader {
            anchors.horizontalCenter: parent.horizontalCenter
            active: root.expanded
            visible: active

            sourceComponent: Flickable {
                width: Math.min(column.width, bands.implicitWidth)
                height: bands.implicitHeight + (contentWidth > width ? VLCStyle.dp(12) : 0)
                contentWidth: bands.implicitWidth
                contentHeight: bands.implicitHeight
                clip: true
                interactive: contentWidth > width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                // the popup is outside the window's color context: give the scroll bar the palette
                T.ScrollBar.horizontal: Widgets.ScrollBarExt {
                    colorContext.palette: VLCStyle.palette
                }

                Row {
                    id: bands

                    spacing: VLCStyle.dp(8)

                    Band {
                        text: qsTr("Preamp")
                        value: root._preamp
                        onMoved: (v) => {
                            RdEffects.setAudioValue("equalizer-preamp", v)
                            root._ensureEqualizer()
                        }
                    }

                    Repeater {
                        model: RdEffects.equalizerBandNames()

                        delegate: Band {
                            required property int index
                            required property var modelData

                            text: modelData
                            value: Number(root._bands[index] ?? 0)
                            onMoved: (v) => {
                                RdEffects.setEqualizerBand(index, v)
                                root._ensureEqualizer()
                            }
                        }
                    }
                }
            }
        }
    }

    // one vertical slider with its name and value box (Figma "Frame 308"). Mouse wheel
    // (Decision 54): in a page that scrolls, a click on the band (the slider or the value box)
    // hands the slider the wheel until the pointer leaves the band
    component Band: Item {
        id: band

        property alias text: label.text
        property real value: 0

        signal moved(real value)

        width: VLCStyle.dp(60)
        implicitHeight: bandColumn.implicitHeight

        Column {
            id: bandColumn

            width: parent.width
            spacing: VLCStyle.dp(12)

            T.Slider {
                id: slider

                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: VLCStyle.dp(24)
                implicitHeight: VLCStyle.dp(320)
                orientation: Qt.Vertical
                from: -20
                to: 20
                stepSize: 0.1
                value: band.value
                focusPolicy: Qt.StrongFocus

                Accessible.name: band.text

                onMoved: band.moved(value)

                background: Rectangle {
                    x: (slider.width - width) / 2
                    width: VLCStyle.dp(16)
                    height: slider.height
                    radius: VLCStyle.rd_radius_normal
                    color: VLCStyle.palette.rdBgB2
                    // keyboard focus: FG/A3; holding the wheel in a scrolling page: Accent/DIm
                    border.width: (slider.visualFocus || bandWheel.holding) ? VLCStyle.dp(1) : 0
                    border.color: slider.visualFocus ? VLCStyle.palette.rdFgA3 : VLCStyle.palette.rdAccentDim

                    // accent background fill from the bottom to the thumb
                    Rectangle {
                        x: VLCStyle.dp(2)
                        width: parent.width - 2 * VLCStyle.dp(2)
                        y: slider.handle.y + slider.handle.height / 2
                        height: parent.height - VLCStyle.dp(2) - y
                        radius: VLCStyle.rd_radius_small
                        color: VLCStyle.palette.rdBgAccentBright
                    }
                }

                handle: Rectangle {
                    x: (slider.width - width) / 2
                    y: slider.visualPosition * (slider.height - height)
                    width: VLCStyle.dp(24)
                    height: VLCStyle.dp(8)
                    radius: VLCStyle.rd_radius_small
                    color: (slider.pressed || bandWheel.holding) ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdAccentDim
                }

                // the wheel over the bar: 0.1 dB a notch, up raises the gain (Decision 54)
                Widgets.RdSliderWheel {
                    id: bandWheel

                    anchors.fill: parent
                    zoneHovered: bandHover.hovered
                    onStepped: (steps) => {
                        if (slider.pressed)
                            return
                        // after a click on the value box: it shows the new value, so Enter
                        // never brings the old one back
                        if (valueBox.editing)
                            valueBox.cancelEdit()
                        bandWheel.stepSlider(slider, steps)
                    }
                }
            }

            Item {
                width: parent.width
                height: VLCStyle.dp(21)

                Text {
                    id: label

                    anchors.bottom: parent.bottom
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }
            }

            Widgets.RdValueBox {
                id: valueBox

                implicitWidth: VLCStyle.dp(60)
                implicitHeight: VLCStyle.dp(32)
                leftPadding: VLCStyle.dp(6)
                rightPadding: VLCStyle.dp(6)
                text: band.value.toFixed(1) + " " + qsTr("dB")
                Accessible.name: band.text
                onEdited: (text) => {
                    const v = parseFloat(String(text).replace(",", ".").replace(/[^0-9.+-]/g, ""))
                    if (!isNaN(v))
                        band.moved(Math.max(-20, Math.min(20, v)))
                }
            }
        }

        // the band's wheel zone. The handlers only watch (the slider and the value box still
        // take the click) and sit on an item above the band: Qt hands a press a control took to
        // the handlers of the items above it, not to its parents
        Item {
            anchors.fill: parent

            HoverHandler {
                id: bandHover
            }

            PointHandler {
                onActiveChanged: {
                    if (active)
                        bandWheel.arm()
                }
            }

            // while the slider holds the wheel, the wheel over the name, the value box and the
            // gaps moves it too (else it goes on: to the bar below, or the page). Takes no clicks
            // and no hover; the handlers above stay off this MouseArea, which would then take
            // the presses
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton

                onWheel: (wheel) => {
                    if (bandWheel.holding)
                        bandWheel.take(wheel)
                    else
                        wheel.accepted = false
                }
            }
        }
    }
}
