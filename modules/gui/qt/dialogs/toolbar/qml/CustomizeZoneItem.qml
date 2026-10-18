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

// redesign (W8.1a, video 19:20-19:27, Figma "Player - customize"): one control of the edited
// bar. It shows the real control (paint only) inside a dashed outline, keeps the gap the live
// control bar puts before it (ControlRepeater: 8, 12 between two icon buttons, 20 after the
// volume and before the queue button), and can be dragged to another place of the bar or into
// the palette (removed). Drag logic from VLC's EditorDNDDelegate; a drop on the left half of
// the item inserts before it, on the right half after it.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

Item {
    id: control

    required property int index
    required property var model

    // CustomizeZone and the dialog content (drag state, drag layer)
    property Item zone: null
    property Item editor: null

    readonly property int controlId: model.id
    readonly property bool dragActive: frameItem.Drag.active

    // an icon button of the control bar (IconToolButton: 30 wide in the bar)
    readonly property bool isIconButton: !!loader.item && loader.item.rdMinimumWidth !== undefined

    // re-evaluated when the zone's items change or this one loads (ControlRepeater does the same)
    readonly property real gapBefore: zone ? (zone.count, isIconButton, zone.gapBefore(index)) : 0

    // drop position: true when a drop goes after this item
    property bool _dropAfter: false

    width: gapBefore + frameItem.width

    Item {
        id: frameItem

        // during a drag the outlined control follows the cursor in the editor's drag layer
        // (MouseArea keeps its scene position when it changes parent)
        parent: Drag.active ? control.editor : control

        // (anchored to `parent`, which is always valid while the parent changes)
        anchors.left: (parent === control) ? parent.left : undefined
        anchors.leftMargin: control.gapBefore
        anchors.verticalCenter: (parent === control) ? parent.verticalCenter : undefined

        // the control's place in the bar, as in the live bar (the outline may reach into the gaps)
        width: Math.max(loader.width, control.isIconButton ? control.zone.iconWidth
                                                           : (control.zone.topBar ? 0 : VLCStyle.rd_iconButtonWidth))
        height: Math.max(loader.height, VLCStyle.rd_iconSize)

        z: Drag.active ? 100 : 0

        // (the hot spot is set where the control is grabbed: drops happen under the cursor)
        Drag.source: control

        // Figma's outlines around the bar controls ("Player - customize"): icon buttons 30x32
        // (Icon Wrapper), previous / next 30x28, the play button 3 px around it, the volume
        // 5 px left and right, 4 px above and below; the top bar's icons 28x28, and the items
        // that are as high as their place (divider, names, title, folder chip, thumbnail)
        // outlined on themselves
        readonly property real _padH: (control.controlId === ControlListModel.VOLUME) ? VLCStyle.dp(5) : 0
        readonly property real _padV: {
            switch (control.controlId) {
            case ControlListModel.RD_DIVIDER:
            case ControlListModel.RD_FILE_NAME:
            case ControlListModel.RD_ARTIST_NAME:
            case ControlListModel.RD_FOLDER_NAME:
            case ControlListModel.RD_PLAYLIST_NAME:
            case ControlListModel.RD_MEDIA_TITLE:
            case ControlListModel.RD_FOLDER_CHIP:
            case ControlListModel.RD_THUMBNAIL:
                return 0
            }
            if (control.zone.topBar)
                return control.zone.topBarIconPadding
            switch (control.controlId) {
            case ControlListModel.PREVIOUS_BUTTON:
            case ControlListModel.NEXT_BUTTON:
                return VLCStyle.dp(2)
            case ControlListModel.PLAY_BUTTON:
                return VLCStyle.dp(3)
            default:
                return VLCStyle.dp(4)
            }
        }

        Widgets.RdDashedFrame {
            anchors.fill: parent
            anchors.leftMargin: -frameItem._padH
            anchors.rightMargin: -frameItem._padH
            anchors.topMargin: -frameItem._padV
            anchors.bottomMargin: -frameItem._padV
            color: (mouseArea.containsMouse || frameItem.Drag.active) ? VLCStyle.palette.rdFgA2
                                                                       : VLCStyle.palette.rdFgA3
        }

        Loader {
            id: loader

            anchors.centerIn: parent

            source: PlayerControlbarControls.control(control.controlId).source

            onLoaded: {
                item.paintOnly = true
                item.enabled = false
                if (item.rdMinimumWidth !== undefined)
                    item.rdMinimumWidth = control.zone.iconWidth
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        anchors.leftMargin: control.gapBefore

        hoverEnabled: true
        cursorShape: (pressed || frameItem.Drag.active) ? Qt.DragMoveCursor : Qt.OpenHandCursor

        drag.target: frameItem
        drag.smoothed: false

        onPressed: (mouse) => {
            const p = mouseArea.mapToItem(frameItem, mouse.x, mouse.y)
            frameItem.Drag.hotSpot.x = p.x
            frameItem.Drag.hotSpot.y = p.y
        }

        drag.onActiveChanged: {
            if (drag.active) {
                control.editor.barDragStarted(control.controlId)
                frameItem.Drag.start()
            } else {
                control.visible = false
                const action = frameItem.Drag.drop()
                if (action === Qt.IgnoreAction)
                    control.visible = true
                control.editor.barDragStopped(control.controlId)
            }
        }
    }

    DropArea {
        id: dropArea

        anchors.fill: parent

        onEntered: (drag) => {
            if (!control.zone.acceptsDrag(drag) || mouseArea.pressed) {
                drag.accepted = false
                return
            }
            control._dropAfter = drag.x > control.gapBefore + frameItem.width / 2
        }

        onPositionChanged: (drag) => {
            control._dropAfter = drag.x > control.gapBefore + frameItem.width / 2
        }

        onDropped: (drop) => {
            control.zone.dropAt(drop, control.index + (control._dropAfter ? 1 : 0))
        }
    }

    // drop position: 2 px accent line, centered in the gap before or after the item
    Rectangle {
        visible: dropArea.containsDrag

        x: control._dropAfter ? control.width + Math.round((control.zone.gapAfter(control.index) - width) / 2)
                              : Math.round((control.gapBefore - width) / 2)
        anchors.verticalCenter: parent.verticalCenter

        width: VLCStyle.dp(2)
        height: frameItem.height
        color: VLCStyle.palette.rdAccentMain
    }
}
