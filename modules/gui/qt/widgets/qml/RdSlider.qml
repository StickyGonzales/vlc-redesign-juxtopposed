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

// Redesign slider (video 7:20-9:10, settings pages): near-black pill track, dark accent fill,
// accent vertical-pill thumb slightly taller than the track.
// - plain: fill from the left
// - bipolar: fill from the zero point to the thumb (subtitle / audio delay)
// - stepped: tick marks at each step (speed, font size, outline thickness)
// Optional labels are drawn under the track, spread evenly from left to right, or (labelStep)
// one every labelStep from labelAnchor, under their own value.
// RdEndlessSlider moves from..to past the normal range (Decision 47): with scaleScrolls the ticks
// and labels stay on their values and scroll with the scale, and an accent edge label points to
// the zero value while it is out of view.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style

T.Slider {
    id: control

    property bool bipolar: false
    property real zeroValue: 0
    // tick marks every tickStep (the step by default; a percentage slider moving by 1 marks
    // every 10, Figma "Text opacity"); tickIntervals sets the count directly (Background
    // Opacity: tenths, Adjust Pitch: one mark at 0)
    property real tickStep: stepSize
    property bool showTicks: tickStep > 0 && (to - from) / tickStep <= 40
    property int tickIntervals: tickStep > 0 ? Math.round((to - from) / tickStep) : 0
    // the setting's filter is off: Figma draws the slider in luminosity blend (614:1472), a gray
    // thumb and fill; moving it still works (and turns the filter on)
    property bool dimmed: false
    // labels under the track, spread from the left end to the right end (Figma "Frame 205")
    property var labels: []
    // Figma "wrapper" auto layout: the track 4 px down (8 in the Settings rows whose slider is
    // wrapped twice), then the gap to the labels (10; 8 in some Settings rows; 14 under the
    // sidebar's Speed slider, whose wrapper is wrapped again: labels 34 under the thumb top)
    property real trackTop: VLCStyle.dp(4)
    property real labelSpacing: VLCStyle.dp(10)
    // labels under their own values, one every labelStep from labelAnchor (replaces `labels`),
    // written by labelText(value)
    property real labelStep: 0
    property real labelAnchor: zeroValue
    property var labelText: (v) => String(v)
    // the ticks and labels belong to values (zeroValue / labelAnchor + n steps), not to fixed
    // places on the track: they scroll when from..to moves (RdEndlessSlider)
    property bool scaleScrolls: false
    // the scale has scrolled away from its normal view: the zero edge label may show (never in
    // the normal view, which stays as in Figma even when the zero value lies outside it)
    property bool scrolled: false
    // no label for a value the slider cannot reach (an endless slider's window may start before
    // VLC's lowest value)
    property real labelMin: -Infinity
    property real labelMax: Infinity
    // the mouse wheel over the bar and the label row (Decision 54): one notch moves by stepSize,
    // as an arrow key; with customWheel the notches go to wheelStepped instead (RdEndlessSlider)
    property bool customWheel: false
    // in a view that can scroll the slider takes the wheel only after a click (RdSliderWheel):
    // the pointer over this zone keeps it; RdParamSlider binds its name row and the slider here
    property bool wheelZoneHovered: wheelArea.pointerOver
    // the slider holds the wheel in a scrolling view: the track shows a thin accent frame and
    // the thumb the accent, as while hovered
    readonly property bool wheelHolding: wheelArea.holding

    signal wheelStepped(int steps)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // Figma "wrapper": the 16 px track (the 24 px thumb overflows it by 4), the gap, the 15 px
    // label row, 4 px below (360x49 in the sidebar)
    implicitWidth: VLCStyle.dp(360)
    implicitHeight: labelRow.visible ? labelRow.y + labelRow.height + VLCStyle.dp(4)
                                     : trackTop + VLCStyle.dp(16) + VLCStyle.dp(4)

    focusPolicy: Qt.StrongFocus
    // disabled: Figma's 30 % rows ("Settings - library")
    opacity: enabled ? 1 : VLCStyle.rd_disabledRowOpacity

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

    readonly property real _inset: VLCStyle.dp(2)

    // Figma draws the marks in BG/Accent Dark with the "screen" blend mode: the color it gives
    // over each background (QML has no blend modes)
    function _screen(c, bg) {
        return Qt.rgba(c.r + bg.r - c.r * bg.r, c.g + bg.g - c.g * bg.g, c.b + bg.b - c.b * bg.b, 1)
    }
    readonly property color _tickOnTrack: _screen(rdPalette.rdBgAccentDark, rdPalette.rdBgB2)
    readonly property color _tickOnFill: _screen(rdPalette.rdBgAccentDark, rdPalette.rdBgAccentBright)

    // a click on the slider's value row hands it the wheel (RdSliderWheel)
    function armWheel() {
        wheelArea.arm()
    }

    // a wheel event over the slider's value row: it moves the slider while the slider holds the
    // wheel, else it goes on (the page scrolls)
    function rowWheel(wheel) {
        if (wheelHolding)
            wheelArea.take(wheel)
        else
            wheel.accepted = false
    }

    function _pos(v) {
        return (to === from) ? 0 : (v - from) / (to - from)
    }

    // the first multiple of `spacing` from `anchor` at or after `v`
    function _firstStep(v, anchor, spacing) {
        return anchor + Math.ceil((v - anchor) / spacing - 1e-6) * spacing
    }

    readonly property real _tickSpacing: tickIntervals > 0 ? (to - from) / tickIntervals : 0
    readonly property real _firstTick: _tickSpacing > 0 ? _firstStep(from, zeroValue, _tickSpacing) : 0
    readonly property real _valueEpsilon: (to - from) * 1e-6

    // where the zero value lies while the scale has scrolled it out of view: -1 left, 1 right
    readonly property int _zeroSide: !(scaleScrolls && scrolled) ? 0
                                     : zeroValue < from - _valueEpsilon ? -1
                                     : zeroValue > to + _valueEpsilon ? 1 : 0

    background: Item {
        // Figma "range": 16 px, radius 6, BG/B2, 2 px padding around a 12 px fill (radius 4)
        Rectangle {
            id: track

            y: control.trackTop
            width: control.availableWidth
            height: VLCStyle.dp(16)
            radius: VLCStyle.rd_radius_normal
            color: control.rdPalette.rdBgB2
            // holding the wheel: a 1 px Accent/DIm frame inside the 2 px padding around the fill
            border.width: control.wheelHolding ? VLCStyle.dp(1) : 0
            border.color: control.dimmed ? control.rdPalette.rdFgA3 : control.rdPalette.rdAccentDim

            Rectangle {
                id: fill

                readonly property real span: track.width - 2 * control._inset
                // the zero value out of view: the fill starts at that end
                readonly property real zeroX: control.bipolar
                                              ? Math.max(0, Math.min(span, control._pos(control.zeroValue) * span)) : 0
                readonly property real thumbX: control.visualPosition * span

                x: control._inset + Math.min(zeroX, thumbX)
                y: control._inset
                width: Math.max(control.bipolar ? 0 : VLCStyle.dp(8), Math.abs(thumbX - zeroX))
                height: track.height - 2 * control._inset
                radius: VLCStyle.rd_radius_small
                color: control.dimmed ? control.rdPalette.rdBgA1 : control.rdPalette.rdBgAccentBright
            }

            // Figma "degrees" (5187:24548, 848:1693): the marks between the ends (the first and
            // last are hidden), centred on the steps of the fill span
            Repeater {
                model: (control.showTicks && !control.scaleScrolls) ? Math.max(0, control.tickIntervals - 1) : 0

                delegate: Rectangle {
                    required property int index

                    x: control._inset + (index + 1) * fill.span / control.tickIntervals - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    // Figma "degrees": 6 px lines stroked 2 px with round caps (2 x 8 drawn),
                    // BG/Accent Dark screened over the track or the fill (dark: #221E19 / #4B3217)
                    width: VLCStyle.dp(2)
                    height: VLCStyle.dp(8)
                    radius: width / 2
                    color: (x >= fill.x && x < fill.x + fill.width) ? control._tickOnFill : control._tickOnTrack
                }
            }

            // scrolling scale: the same marks on the multiples of the tick spacing from zeroValue;
            // a fixed count (one more than fits), each hidden while its value is at an end or out
            // of view, so scrolling never creates or destroys marks
            Repeater {
                model: (control.showTicks && control.scaleScrolls && control._tickSpacing > 0)
                       ? control.tickIntervals + 1 : 0

                delegate: Rectangle {
                    required property int index

                    readonly property real tickValue: control._firstTick + index * control._tickSpacing

                    visible: tickValue > control.from + control._valueEpsilon
                             && tickValue < control.to - control._valueEpsilon
                    x: control._inset + control._pos(tickValue) * fill.span - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: VLCStyle.dp(2)
                    height: VLCStyle.dp(8)
                    radius: width / 2
                    color: (x >= fill.x && x < fill.x + fill.width) ? control._tickOnFill : control._tickOnTrack
                }
            }
        }

        Item {
            id: labelRow

            visible: control.labels.length > 0 || control.labelStep > 0
            y: control.trackTop + VLCStyle.dp(16) + control.labelSpacing
            width: control.availableWidth
            height: VLCStyle.dp(15)

            Repeater {
                model: control.labelStep > 0 ? [] : control.labels

                delegate: Text {
                    required property int index
                    required property var modelData

                    readonly property real center: control.labels.length > 1
                                                   ? index * labelRow.width / (control.labels.length - 1)
                                                   : labelRow.width / 2

                    x: Math.max(0, Math.min(labelRow.width - width, center - width / 2))
                    text: modelData
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_toggle
                    color: control.rdPalette.rdFgA3
                }
            }

            // labels under their values, kept inside the row like the list's end labels; one whose
            // value leaves the view fades out over `fade` px, and one under the zero edge label
            // gives way to it. A fixed count: each label shows the n-th value from the first one
            // in view, so its text only changes when it wraps around
            Repeater {
                id: stepLabels

                readonly property real fade: VLCStyle.dp(16)
                readonly property real fadeValue: control.availableWidth > 0
                                                  ? fade * (control.to - control.from) / control.availableWidth : 0
                readonly property real first: control.labelStep > 0
                                              ? control._firstStep(control.from - fadeValue, control.labelAnchor, control.labelStep)
                                              : 0

                model: control.labelStep > 0
                       ? Math.floor((control.to - control.from + 2 * fadeValue) / control.labelStep) + 2 : 0

                delegate: Text {
                    required property int index

                    readonly property real labelValue: stepLabels.first + index * control.labelStep
                    readonly property real center: control._pos(labelValue) * labelRow.width
                    readonly property real outside: Math.max(0, -center, center - labelRow.width)
                    readonly property bool underZeroLabel: control._zeroSide < 0
                                                           ? x < zeroLabel.x + zeroLabel.width + VLCStyle.dp(8)
                                                           : control._zeroSide > 0 && x + width > zeroLabel.x - VLCStyle.dp(8)

                    x: Math.max(0, Math.min(labelRow.width - width, center - width / 2))
                    visible: opacity > 0
                    opacity: (underZeroLabel || labelValue < control.labelMin - control._valueEpsilon
                              || labelValue > control.labelMax + control._valueEpsilon)
                             ? 0 : Math.max(0, 1 - outside / stepLabels.fade)
                    text: control.labelText(labelValue)
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_toggle
                    color: control.rdPalette.rdFgA3
                }
            }

            // the zero value scrolled out of view: an accent label at that end with an arrow toward
            // it and its distance from that end
            Text {
                id: zeroLabel

                visible: control._zeroSide !== 0 && control.labelStep > 0
                x: control._zeroSide < 0 ? 0 : labelRow.width - width
                text: control._zeroSide < 0
                      ? qsTr("\u2039 %1  %2").arg(control.labelText(control.zeroValue))
                                             .arg(control.labelText(control.zeroValue - control.from))
                      : qsTr("%1  %2 \u203A").arg(control.labelText(control.zeroValue - control.to))
                                             .arg(control.labelText(control.zeroValue))
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_toggle
                color: control.rdPalette.rdAccentMain
            }
        }
    }

    // Figma "thumb": 8x24, radius 4, Accent/DIm (accent while hovered or pressed)
    handle: Rectangle {
        x: control.leftPadding + control._inset + control.visualPosition * (control.availableWidth - 2 * control._inset - width)
        y: control.trackTop - VLCStyle.dp(4)
        width: VLCStyle.dp(8)
        height: VLCStyle.dp(24)
        radius: VLCStyle.rd_radius_small
        color: (control.pressed || control.hovered || control.visualFocus || control.wheelHolding)
               ? (control.dimmed ? control.rdPalette.rdFgA2 : control.rdPalette.rdAccentMain)
               : (control.dimmed ? control.rdPalette.rdFgA3 : control.rdPalette.rdAccentDim)
    }

    // a click on the slider hands it the wheel
    onPressedChanged: {
        if (pressed)
            wheelArea.arm()
    }

    RdSliderWheel {
        id: wheelArea

        anchors.fill: parent
        mirrored: control.mirrored && control.horizontal
        zoneHovered: control.wheelZoneHovered

        onStepped: (steps) => {
            // held: the pointer sets the value
            if (control.pressed)
                return
            if (control.customWheel)
                control.wheelStepped(steps)
            else
                wheelArea.stepSlider(control, steps)
        }
    }
}
