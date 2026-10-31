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

// redesign: the queue attached above the mini player (video 11:52-11:56, P5-28; Figma
// "Miniplayer" queue: header 58 px "Queue" on BG/A5 with radii 14,14,2,2, then the count and
// duration with sort, repeat, shuffle, remove and add (Decision 10: the video's 5 icons), then
// the rows: drag handle, title, duration; the playing row in accent). Rows are created as they
// scroll in. Library rows and files dropped on it join the queue (W5.9).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Dialogs
import VLC.Widgets as Widgets

Item {
    id: root

    property int selectedIndex: -1

    function _durationText(duration) {
        if (!duration || !duration.valid())
            return ""
        const minutes = Math.floor(duration.toSeconds() / 60)
        return minutes >= 60 ? qsTr("%1h %2m").arg(Math.floor(minutes / 60)).arg(minutes % 60)
                             : qsTr("%1m").arg(minutes)
    }

    PlaylistListModel {
        id: queueModel

        playlist: MainPlaylistController.playlist
        onCountChanged: root.selectedIndex = -1
    }

    Rectangle {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: VLCStyle.dp(58)
        radius: VLCStyle.rd_radius_large
        color: VLCStyle.palette.rdBgA5

        // radii 14,14,2,2
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: parent.radius
            radius: VLCStyle.dp(2)
            color: parent.color
        }

        // Figma: text top 20 px below the card's top
        Text {
            anchors.top: parent.top
            anchors.topMargin: VLCStyle.dp(20)
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Queue")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
            color: VLCStyle.palette.rdFgA2
        }
    }

    Item {
        id: tools

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        // Figma queue gap 1
        anchors.topMargin: VLCStyle.dp(1)
        height: VLCStyle.dp(64)

        Text {
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(36)
            anchors.right: buttons.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            readonly property string countText: qsTr("%1 item", "%1 items", queueModel.count).arg(queueModel.count)

            text: queueModel.duration.valid()
                  ? qsTr("%1 - %2").arg(countText).arg(root._durationText(queueModel.duration))
                  : countText
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Row {
            id: buttons

            // Figma: 24 px icons 20 apart (30 wide buttons 14 apart), the last one ending at 363
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(25)
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(14)

            ToolButton {
                rdIcon: "sort"
                description: qsTr("Sort by title")
                onClicked: {
                    root.selectedIndex = -1
                    MainPlaylistController.sort(PlaylistController.SORT_KEY_TITLE)
                }
            }

            ToolButton {
                rdIcon: "repeat_direction-right"
                description: qsTr("Repeat")
                checked: MainPlaylistController.repeatMode !== PlaylistController.PLAYBACK_REPEAT_NONE
                onClicked: MainPlaylistController.toggleRepeatMode()
            }

            ToolButton {
                rdIcon: "shuffle_direction-right"
                description: qsTr("Shuffle")
                checked: MainPlaylistController.random
                onClicked: MainPlaylistController.toggleRandom()
            }

            ToolButton {
                rdIcon: "remove"
                description: qsTr("Remove the selected item")
                enabled: root.selectedIndex >= 0
                onClicked: {
                    queueModel.removeItems([root.selectedIndex])
                    root.selectedIndex = -1
                }
            }

            ToolButton {
                rdIcon: "add"
                description: qsTr("Add files to the queue")
                onClicked: DialogsProvider.simpleOpenDialog(false)
            }
        }
    }

    ListView {
        id: list

        anchors.left: parent.left
        anchors.right: parent.right
        // Figma "Frame 53": 1 below the tools, 215 tall, 20 above the player's picture
        anchors.top: tools.bottom
        anchors.topMargin: VLCStyle.dp(1)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: VLCStyle.dp(12)
        anchors.leftMargin: VLCStyle.dp(28)
        anchors.rightMargin: VLCStyle.dp(28)
        clip: true
        spacing: VLCStyle.dp(12)
        boundsBehavior: Flickable.StopAtBounds
        model: queueModel

        delegate: Widgets.RdListRow {
            id: queueRow

            required property int index
            required property var model

            width: list.width
            title: model.title ?? ""
            // Cone extra (Decision 71): the autoplay item is labelled (UP_NEXT_PLAN.md rows 64, 86)
            readonly property bool _autoplay: RdUpNext.queuedUrl.toString() !== ""
                                             && String(model.url) === RdUpNext.queuedUrl.toString()
            readonly property string _duration: model.duration && model.duration.valid() ? model.duration.formatHMS() : ""
            detail: _autoplay ? (_duration !== "" ? qsTr("Autoplay · %1").arg(_duration) : qsTr("Autoplay"))
                              : _duration
            current: !!model.isCurrent
            selected: root.selectedIndex === index || drag.active
            // Figma: the 32 px move icon wrapper and a gap of 10 before the title
            leftPadding: VLCStyle.dp(38)

            onClicked: root.selectedIndex = index
            onDoubleClicked: MainPlaylistController.goTo(index, true)

            z: drag.active ? 1 : 0
            transform: Translate {
                y: drag.active ? drag.translation.y : 0
            }

            // the playing row shows a play icon, the others the drag handle (11:52)
            Widgets.RdIcon {
                x: VLCStyle.dp(4)
                anchors.verticalCenter: parent.verticalCenter
                name: queueRow.current ? "play" : "move"
                color: queueRow.current ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdFgA2

                DragHandler {
                    id: drag

                    target: null
                    xAxis.enabled: false
                    cursorShape: Qt.SizeVerCursor
                    grabPermissions: PointerHandler.CanTakeOverFromAnything

                    onActiveChanged: {
                        if (active)
                            return
                        const step = queueRow.height + list.spacing
                        const target = Math.max(0, Math.min(queueModel.count - 1,
                                                            queueRow.index + Math.round(translation.y / step)))
                        if (target < queueRow.index)
                            queueModel.moveItemsPre([queueRow.index], target)
                        else if (target > queueRow.index)
                            queueModel.moveItemsPost([queueRow.index], target)
                        root.selectedIndex = -1
                    }
                }
            }
        }
    }

    RdQueueDropArea {
        anchors.fill: parent
        view: list
    }

    component ToolButton: Widgets.IconToolButton {
        width: VLCStyle.rd_iconButtonWidth
        height: VLCStyle.rd_iconButtonHeight
        font.pixelSize: VLCStyle.rd_iconSize
        text: VLCIcons.more
        color: checked ? colorContext.accent : (hovered ? VLCStyle.palette.rdFgA1 : VLCStyle.palette.rdFgA3)
    }
}
