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

// redesign: a library list row (Figma "media" and "playlist" components, 337x32, gap 10,
// F-13; video 11:40-11:59, IB-14): a 32x32 picture or icon, the title in Inter 14. Unwatched
// titles FG/A1, watched FG/A3, the playing file in accent; hovering brightens the title to
// FG/2 and shows a "..." button at the end of the row (no row background). Media rows can be
// dragged to the queue (11:44, IB-15): the ghost is the row content only, semi-transparent.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.MediaLibrary
import VLC.Widgets as Widgets

T.AbstractButton {
    id: row

    property string title: ""
    property string iconName: ""
    property url thumbnail: ""
    property bool boxed: true
    property real progress: -1
    property bool watched: false
    property bool playing: false
    // Cone extra (Decision 71): the next episode autoplay will play, an "Up next" tag after the
    // title (UP_NEXT_PLAN.md 4.8)
    property bool upNext: false
    // folders, categories, action rows ("+ Add") and Home rows use the secondary text color
    // (Figma FG/A3)
    property bool secondary: false
    property color iconColor: VLCStyle.palette.rdFgA2
    property bool showMore: true
    // drag to the queue: URLs of the dragged media, empty for rows that cannot be dragged
    property var dragUrls: []

    signal moreClicked(Item button)

    implicitWidth: VLCStyle.dp(337)
    implicitHeight: VLCStyle.rd_rowHeight

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Accessible.role: Accessible.ListItem
    Accessible.name: upNext ? qsTr("%1, up next").arg(title) : title

    Keys.priority: Keys.AfterItem
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            row.clicked()
            event.accepted = true
            return
        }
        Navigation.defaultKeyAction(event)
    }

    // VLC's Navigation takes the arrows and Escape: the arrows walk the keyboard focus chain
    // and Escape goes back in the library, unless the view sets its own (RdLibraryPage's grid)
    Navigation.upAction: () => RdLibraryNav.focusStep(row, false)
    Navigation.downAction: () => RdLibraryNav.focusStep(row, true)
    Navigation.leftAction: () => RdLibraryNav.focusStep(row, false)
    Navigation.rightAction: () => RdLibraryNav.focusStep(row, true)
    Navigation.cancelAction: () => RdLibraryNav.goBack()

    background: Item { }

    contentItem: Item {
        Row {
            id: content

            anchors.fill: parent
            spacing: VLCStyle.dp(10)

            RdLibraryThumb {
                id: thumb

                width: VLCStyle.dp(32)
                height: VLCStyle.dp(32)
                anchors.verticalCenter: parent.verticalCenter
                source: row.thumbnail
                iconName: row.iconName
                boxed: row.boxed
                iconColor: row.iconColor
                progress: row.progress
                watched: row.watched
                playing: row.playing
            }

            Text {
                id: titleText

                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth,
                                content.width - thumb.width - content.spacing
                                - (upNextTag.visible ? upNextTag.width + content.spacing : 0)
                                - (moreButton.visible ? moreButton.width + content.spacing : 0))
                text: row.title
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: row.playing ? VLCStyle.palette.rdAccentMain
                     : (row.hovered || row.visualFocus) ? VLCStyle.palette.rdFg2
                     : row.watched ? VLCStyle.palette.rdFgA3
                     : row.secondary ? VLCStyle.palette.rdFgA3
                     : VLCStyle.palette.rdFgA1
            }

            // BG/Accent Bright pill, Inter 600 12 in the accent, radius 4
            Rectangle {
                id: upNextTag

                anchors.verticalCenter: parent.verticalCenter
                visible: row.upNext
                width: upNextLabel.implicitWidth + VLCStyle.dp(12)
                height: VLCStyle.dp(20)
                radius: VLCStyle.rd_radius_small
                color: VLCStyle.palette.rdBgAccentBright

                Text {
                    id: upNextLabel

                    anchors.centerIn: parent
                    text: qsTr("Up next")
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_toggle
                    font.weight: Font.DemiBold
                    color: VLCStyle.palette.rdAccentMain
                }
            }
        }

        RdLibraryIconButton {
            id: moreButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: row.showMore && (row.hovered || row.visualFocus || hovered)
            iconName: "more"
            description: qsTr("More")
            showHoverBackground: false
            onClicked: row.moreClicked(moreButton)
        }
    }

    // drag to the queue
    Item {
        id: ghost

        // over the whole window only while dragging (set by the drag handler)
        parent: row
        visible: dragHandler.active
        width: row.width
        height: row.height
        opacity: VLCStyle.rd_dragGhostOpacity
        z: 1000

        // started and dropped by the handler below (a binding could turn the drag off before
        // the drop, losing it)
        Drag.dragType: Drag.Internal
        Drag.hotSpot.x: VLCStyle.dp(16)
        Drag.hotSpot.y: height / 2
        Drag.keys: ["text/uri-list"]
        // read by the drop areas of the queue (RdQueueDropArea)
        readonly property var rdDragUrls: row.dragUrls

        // created only while dragging: the rows do not load their picture twice
        Loader {
            anchors.fill: parent
            active: dragHandler.active

            sourceComponent: Row {
                spacing: VLCStyle.dp(10)

                RdLibraryThumb {
                    width: VLCStyle.dp(32)
                    height: VLCStyle.dp(32)
                    anchors.verticalCenter: parent.verticalCenter
                    source: row.thumbnail
                    iconName: row.iconName
                    boxed: row.boxed
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.title
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFg1
                }
            }
        }
    }

    DragHandler {
        id: dragHandler

        enabled: row.dragUrls.length > 0
        // as VLC's own list and grid items: touch flicks the list, the mouse drags; the drag
        // takes the press over from the row's button (an item), lists may take it over again
        acceptedDevices: PointerDevice.AllDevices & ~(PointerDevice.TouchScreen)
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                         | PointerHandler.ApprovesTakeOverByAnything
        target: null

        onCentroidChanged: {
            if (!active || !ghost.parent)
                return
            const p = row.mapToItem(ghost.parent, centroid.position.x, centroid.position.y)
            ghost.x = p.x - ghost.Drag.hotSpot.x
            ghost.y = p.y - ghost.Drag.hotSpot.y
        }

        onActiveChanged: {
            if (active) {
                ghost.parent = row.Window.contentItem
                ghost.Drag.active = true
            } else {
                ghost.Drag.drop()
                ghost.parent = row
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
    }
}
