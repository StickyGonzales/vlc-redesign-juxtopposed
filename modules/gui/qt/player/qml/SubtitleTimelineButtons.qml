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
// redesign: the buttons beside the subtitle timeline seek bar (IA-27, video 6:52-7:04; no Figma
// frame, Decision 21): filled accent buttons with dark glyphs, as tall as the bar and touching
// its ends (ControlBar removes the row's gap on the bar's side), "<" and "-" left of the bar,
// "+" and ">" right of it; the chevrons are narrower than "-" / "+" (video 7:04). "<" / ">"
// move the time window by half its length, "-" / "+" show a longer / shorter window
// (SliderBar.timelinePan / timelineZoom). Shown only while the bar shows the timeline.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets

Row {
    id: root

    // the seek bar (SliderBar) whose window the buttons move
    property Item slider: null
    // true: the buttons left of the bar ("<", "-"), false: right of it ("+", ">")
    property bool leading: true

    spacing: VLCStyle.dp(4, VLCStyle.scale)
    visible: root.slider?.timelineShown ?? false

    component TimelineButton: T.AbstractButton {
        id: button

        property string iconName: ""
        property string tip: ""
        // "<" / ">" are narrower than "-" / "+"
        property bool chevron: false

        implicitWidth: button.chevron ? VLCStyle.rd_timelineChevronWidth : VLCStyle.rd_timelineButtonWidth
        implicitHeight: root.slider?.barHeight ?? VLCStyle.rd_seekBarHeight
        anchors.verticalCenter: parent.verticalCenter
        focusPolicy: Qt.TabFocus

        Accessible.name: button.tip
        T.ToolTip.visible: button.hovered
        T.ToolTip.delay: VLCStyle.delayToolTipAppear
        T.ToolTip.text: button.tip

        HoverHandler {
            cursorShape: button.enabled ? Qt.PointingHandCursor : undefined
        }

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: button.pressed ? VLCStyle.palette.rdAccentDim
                 : (button.hovered || button.visualFocus) ? VLCStyle.palette.rdAccentBright
                                                          : VLCStyle.palette.rdAccentMain
            opacity: button.enabled ? 1 : 0.4
        }

        contentItem: Item {
            Widgets.RdIcon {
                anchors.centerIn: parent
                name: button.iconName
                size: VLCStyle.dp(16, VLCStyle.scale)
                color: VLCStyle.palette.rdFgB1
                opacity: button.enabled ? 1 : 0.6
            }
        }
    }

    TimelineButton {
        iconName: root.leading ? "chevron_direction-left" : "add"
        chevron: root.leading
        tip: root.leading ? qsTr("Show earlier subtitles") : qsTr("Show a shorter time span")
        enabled: root.leading ? (root.slider?.timelineCanPanBack ?? false)
                              : (root.slider?.timelineCanZoomIn ?? false)
        onClicked: {
            if (root.leading)
                root.slider.timelinePan(-1)
            else
                root.slider.timelineZoom(1)
        }
    }

    TimelineButton {
        iconName: root.leading ? "remove" : "chevron_direction-right"
        chevron: !root.leading
        tip: root.leading ? qsTr("Show a longer time span") : qsTr("Show later subtitles")
        enabled: root.leading ? (root.slider?.timelineCanZoomOut ?? false)
                              : (root.slider?.timelineCanPanForward ?? false)
        onClicked: {
            if (root.leading)
                root.slider.timelineZoom(-1)
            else
                root.slider.timelinePan(1)
        }
    }
}
