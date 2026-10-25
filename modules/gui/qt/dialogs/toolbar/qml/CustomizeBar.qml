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

// redesign (W8.1a, video 19:20-19:27, Figma "Player - customize" / "-6"): the edited bar, drawn
// where the control bar is (bottom of the window, Figma "Controls": 54 high, BG/A3, padding 20)
// with every control in a dashed outline. It edits VLC's three zones of the selected player
// layout like the live bar lays them out (ControlBar, PlayerControlLayout): with an empty center
// zone the video and audio players show the seek row between the left and right controls (a
// drop on it goes to the center zone); with center controls the seek row moves to its own row
// above the controls (Figma "Player - customize-1" / "-6": two 54 px rows), the center controls
// sit in the middle and the left / right zones show their free room as empty slots.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

Rectangle {
    id: root

    // the dialog content: drag state and drag layer
    property Item editor: null

    // PlayerControlbarModel of the selected profile and player
    property var playerModel: null

    // the video and audio players have the seek row between their zones (ControlBar Inline)
    property bool hasSeekRow: true

    readonly property bool _hasCenter: !!playerModel && playerModel.center.count > 0
    // the seek row between the left and right zones, or on its own row above them
    readonly property bool _seekRowInline: hasSeekRow && !!playerModel && !_hasCenter
    readonly property bool _seekRowOnOwnRow: hasSeekRow && _hasCenter

    readonly property real _rowHeight: VLCStyle.rd_controlBarHeight
    // the row of the zones
    readonly property real _zonesY: _seekRowOnOwnRow ? _rowHeight : 0

    readonly property real _padding: VLCStyle.rd_controlBarSpacing
    readonly property real _zoneSpacing: VLCStyle.rd_controlBarSpacing

    implicitHeight: _seekRowOnOwnRow ? 2 * _rowHeight : _rowHeight

    // Figma "Controls" BG/A3 Transparent, opaque over the native video
    color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

    // Figma "Controls" in this frame: 1 px Divider/Dim stroke on top (as the live bar draws it)
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: VLCStyle.dp(1)
        color: VLCStyle.palette.rdDividerDim
    }

    // keeps the arrow cursor and the clicks inside the bar
    MouseArea {
        anchors.fill: parent
        cursorShape: root.editor && root.editor.dragActive ? Qt.DragMoveCursor : Qt.ArrowCursor
    }

    CustomizeZone {
        id: leftZone

        x: root._padding
        width: root._seekRowInline ? implicitWidth
                                  : Math.max(implicitWidth, centerZone.x - root._zoneSpacing - x)
        y: root._zonesY
        height: root._rowHeight

        alignment: Qt.AlignLeft
        editor: root.editor
        model: root.playerModel ? root.playerModel.left : null
    }

    CustomizeZone {
        id: centerZone

        x: Math.round((root.width - width) / 2)
        width: implicitWidth
        y: root._zonesY
        height: root._rowHeight

        visible: !root._seekRowInline

        alignment: Qt.AlignHCenter
        acceptsExpandingSpacer: false
        editor: root.editor
        model: root.playerModel ? root.playerModel.center : null
    }

    CustomizeZone {
        id: rightZone

        readonly property real _left: root._seekRowInline ? root.width - root._padding - implicitWidth
                                                         : centerZone.x + centerZone.width + root._zoneSpacing

        x: Math.min(_left, root.width - root._padding - implicitWidth)
        width: root.width - root._padding - x
        y: root._zonesY
        height: root._rowHeight

        alignment: Qt.AlignRight
        editor: root.editor
        model: root.playerModel ? root.playerModel.right : null
    }

    // the seek row of the live bar (Figma "seekbar": time 76, thick bar, duration 76, gap 8, in a
    // 36 high dashed outline, centered in its 54 px row); it is not movable itself: between the
    // zones a drop on it fills the center zone, which sends it to its own row
    Item {
        id: seekRow

        x: root._seekRowOnOwnRow ? root._padding : leftZone.x + leftZone.width + root._zoneSpacing
        width: root._seekRowOnOwnRow ? Math.max(0, root.width - 2 * root._padding)
                                     : Math.max(0, rightZone.x + (rightZone.width - rightZone.controlsWidth) - root._zoneSpacing - x)
        height: VLCStyle.dp(36)
        y: Math.round((root._rowHeight - height) / 2)

        visible: root._seekRowInline || root._seekRowOnOwnRow

        Widgets.RdDashedFrame {
            anchors.fill: parent
            color: seekDrop.containsDrag ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdFgA3
        }

        Row {
            anchors.fill: parent
            anchors.topMargin: VLCStyle.dp(4)
            anchors.bottomMargin: VLCStyle.dp(4)
            spacing: VLCStyle.dp(8)

            Text {
                width: VLCStyle.rd_timeLabelWidth
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: seekRow.visible ? Player.time.formatHHMMSS() : ""
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_time
                color: VLCStyle.palette.rdFgA2
            }

            Rectangle {
                id: seekBar

                width: Math.max(0, parent.width - 2 * (VLCStyle.rd_timeLabelWidth + parent.spacing))
                height: parent.height
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgB2

                readonly property real _inner: width - 2 * VLCStyle.dp(2)
                readonly property real _handleX: VLCStyle.dp(2)
                                                 + (seekRow.visible ? Math.max(0, Math.min(1, Player.position)) : 0) * Math.max(0, _inner - VLCStyle.rd_seekHandleWidth)

                Rectangle {
                    x: VLCStyle.dp(2)
                    width: seekBar._handleX + VLCStyle.rd_seekHandleWidth - x
                    height: VLCStyle.rd_seekFillHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: VLCStyle.rd_radius_small
                    color: VLCStyle.palette.rdBgAccentBright
                }

                Rectangle {
                    x: seekBar._handleX
                    width: VLCStyle.rd_seekHandleWidth
                    height: VLCStyle.rd_seekFillHeight
                    anchors.verticalCenter: parent.verticalCenter
                    radius: VLCStyle.rd_radius_small
                    color: VLCStyle.palette.rdAccentMain
                }
            }

            Text {
                width: VLCStyle.rd_timeLabelWidth
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: seekRow.visible ? Player.length.formatHHMMSS() : ""
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_time
                color: VLCStyle.palette.rdFgA2
            }
        }

        DropArea {
            id: seekDrop

            anchors.fill: parent
            enabled: root._seekRowInline

            onEntered: (drag) => {
                if (!centerZone.acceptsDrag(drag))
                    drag.accepted = false
            }

            onDropped: (drop) => centerZone.dropAt(drop, 0)
        }
    }
}
