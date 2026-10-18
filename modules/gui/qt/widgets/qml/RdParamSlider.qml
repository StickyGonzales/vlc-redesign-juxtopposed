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

// Redesign setting with a slider (Figma "Frame 96", video 8:46-8:52): the name on the left and
// the value on the right of a 37 px row, the slider under it at full width. The value is plain
// text (filter parameters, sizes) or an editable value box (equalizer bands, valueBox: true).
// limitFrom / limitTo past from..to make the slider endless (RdEndlessSlider, Decision 47).
// Mouse wheel (Decision 54): in a page that scrolls, a click on the slider or on its name row
// (the value box included) hands the slider the wheel until the pointer leaves the row and the
// slider (RdSliderWheel).
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style

ColumnLayout {
    id: root

    property alias text: label.text
    property string valueText: ""
    property bool valueBox: false
    property alias valueFramed: box.framed
    property alias valueFontSize: box.fontSize
    property alias valueTextColor: box.textColor
    // name row: 37 px, 56 with a value box (Figma "Frame 60" 767:2197: padding 10 around the 36 px
    // box); the space between that row and the slider is the layout's spacing
    property real rowHeight: valueBox ? VLCStyle.dp(56) : VLCStyle.dp(37)
    property alias labelSpacing: slider.labelSpacing
    // label (and plain value) inset from the row edges: 4 in section rows (Figma "Frame 60" padding
    // left 4), 0 in the rows of an expander card (536:1865, 6114:13620)
    property real textInset: VLCStyle.dp(4)

    property alias from: slider.rangeFrom
    property alias to: slider.rangeTo
    property alias stepSize: slider.step
    // the value VLC has (the slider shows it, also past from..to)
    property alias value: slider.current
    property alias limitFrom: slider.limitFrom
    property alias limitTo: slider.limitTo
    property alias scrollSpeed: slider.scrollSpeed
    // one mouse wheel notch over the slider (Decision 54); stepSize by default
    property alias wheelStep: slider.wheelStep
    property alias bipolar: slider.bipolar
    property alias zeroValue: slider.zeroValue
    property alias showTicks: slider.showTicks
    property alias tickIntervals: slider.tickIntervals
    property alias dimmed: slider.dimmed
    property alias labels: slider.labels
    property alias labelStep: slider.labelStep
    property alias labelAnchor: slider.labelAnchor
    property alias labelText: slider.labelText
    readonly property alias pressed: slider.pressed

    // the user moved the slider / typed a value in the box
    signal moved(real value)
    signal edited(string text)

    readonly property SystemPalette rdPalette: VLCStyle.palette

    Layout.fillWidth: true
    spacing: VLCStyle.dp(5)

    // the slider's wheel zone: the name row, the slider and the space between them
    HoverHandler {
        id: zoneHover
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.rowHeight

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: root.textInset
            anchors.right: valueArea.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: root.rdPalette.rdFgA3
        }

        Item {
            id: valueArea

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: root.valueBox ? box.implicitWidth : plainValue.implicitWidth + root.textInset
            height: root.valueBox ? box.implicitHeight : plainValue.implicitHeight

            Text {
                id: plainValue

                visible: !root.valueBox
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.valueText
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA3
            }

            RdValueBox {
                id: box

                visible: root.valueBox
                text: root.valueText
                Accessible.name: label.text
                onEdited: (value) => root.edited(value)
            }
        }

        // while the slider holds the wheel, the wheel over the row moves the slider too. Takes no
        // clicks and no hover
        MouseArea {
            anchors.fill: parent
            // the gap down to the slider too (part of the zone)
            anchors.bottomMargin: -root.spacing
            acceptedButtons: Qt.NoButton

            onWheel: (wheel) => slider.rowWheel(wheel)

            // a press on the row hands the slider the wheel. The handler only watches (the value
            // box still takes the click) and sits on an item above the row: Qt hands a press a
            // control took to the handlers of the items above it, not to its parents; and not on
            // the MouseArea itself, which would then take the press
            Item {
                anchors.fill: parent

                PointHandler {
                    onActiveChanged: {
                        if (active)
                            slider.armWheel()
                    }
                }
            }
        }
    }

    RdEndlessSlider {
        id: slider

        Layout.fillWidth: true
        Accessible.name: label.text
        wheelZoneHovered: zoneHover.hovered
        // a wheel step after a click on the value box: the box shows the new value, so Enter
        // never brings the old one back
        onWheelStepped: {
            if (box.editing)
                box.cancelEdit()
        }
        onValueMoved: (v) => root.moved(v)
    }
}
