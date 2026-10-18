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

// redesign (W8.1a, video 19:20-19:27, Figma "Player - customize-6"): one zone (left, center or
// right) of the edited bar: its controls in dashed outlines and, where the zone has room left,
// an empty dashed slot (Figma's empty drop slots) that takes drops at the zone's open end.
// Drop logic from VLC's EditorDNDView: from the palette inserts a new control, from the same
// zone moves it, from another zone moves it over. Controls shift in 50 ms (Figma smart animate).
// A bar holds a handful of controls, so they are all created (Row + Repeater).
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.PlayerControls

Item {
    id: root

    property alias model: repeater.model

    // the dialog content: drag state and drag layer
    property Item editor: null

    // Qt.AlignLeft: free room after the controls; Qt.AlignRight: before them;
    // Qt.AlignHCenter: no free room (the zone is as wide as its controls)
    property int alignment: Qt.AlignLeft

    // the expanding spacer cannot go into the center zone (VLC's toolbar editor rule)
    property bool acceptsExpandingSpacer: true

    // W8.1b: a zone of the top bar (Figma "topbar"): icon buttons `iconWidth` wide with their
    // 28 x 28 icon outlined, `topBarSpacing` between controls and none next to a divider
    property bool topBar: false
    property real iconWidth: VLCStyle.rd_iconButtonWidth
    property real topBarSpacing: VLCStyle.dp(10)
    // above and below a top bar icon's outline (Figma: the 28x28 Icon in the left zone, 36x24
    // cells between the window buttons)
    property real topBarIconPadding: VLCStyle.dp(2)

    readonly property int count: repeater.count
    readonly property real controlsWidth: row.width

    readonly property real _minimumSlotWidth: VLCStyle.rd_playButtonWidth

    implicitWidth: (count > 0) ? row.width : _minimumSlotWidth
    implicitHeight: topBar ? VLCStyle.rd_topBarHeight : VLCStyle.rd_controlBarHeight

    // ------------------------------------------------------------------------------ gaps

    // same gaps as the live control bar (ControlRepeater.gapBefore, Figma "Controls"): 8 between
    // controls, between two icon buttons 8 in the left / center zones and 12 in the right zone
    // (the track buttons group), 20 after the volume and before the queue button
    readonly property real _iconSpacing: (alignment === Qt.AlignRight) ? VLCStyle.rd_iconButtonSpacing
                                                                       : VLCStyle.dp(8)

    function gapBefore(index) {
        if (index <= 0)
            return 0
        const cur = repeater.itemAt(index)
        const prev = repeater.itemAt(index - 1)
        if (topBar) {
            // as the live top bar (RdTopBarZone)
            if (cur && prev && (cur.controlId === ControlListModel.RD_DIVIDER
                                || prev.controlId === ControlListModel.RD_DIVIDER))
                return 0
            return topBarSpacing
        }
        if (!cur || !prev)
            return VLCStyle.dp(8)
        if (cur.controlId === ControlListModel.PLAYLIST_BUTTON || prev.controlId === ControlListModel.VOLUME)
            return VLCStyle.rd_controlBarSpacing
        if (cur.isIconButton && prev.isIconButton)
            return _iconSpacing
        return VLCStyle.dp(8)
    }

    function gapAfter(index) {
        if (index + 1 >= count)
            return topBar ? topBarSpacing : VLCStyle.dp(8)
        return gapBefore(index + 1)
    }

    // ------------------------------------------------------------------------------ drops

    function acceptsDrag(drag) {
        if (!drag.source)
            return false
        if (!acceptsExpandingSpacer && editor.draggedControlId === ControlListModel.WIDGET_SPACER_EXTEND)
            return false
        return true
    }

    function dropAt(drop, destIndex) {
        const source = drop.source
        if (source.zone === root) {
            // moving inside the zone
            const from = source.index
            if (from < destIndex)
                --destIndex
            if (from !== destIndex)
                model.move(from, destIndex)
            source.visible = true
            drop.accept(Qt.MoveAction)
        } else if (source.paletteControlId !== undefined) {
            // from the palette
            model.insert(destIndex, { "id": source.paletteControlId })
            drop.accept(Qt.CopyAction)
        } else {
            // from another zone
            const sourceModel = source.zone.model
            const sourceIndex = source.index
            model.insert(destIndex, { "id": source.controlId })
            sourceModel.remove(sourceIndex)
            drop.accept(Qt.MoveAction)
        }
    }

    // ------------------------------------------------------------------------------ views

    // the free room of the zone: an empty dashed slot that appends (left, center) or
    // prepends (right) the dropped control
    Item {
        id: emptySlot

        x: (root.alignment === Qt.AlignRight || root.count === 0) ? 0 : row.width
        width: (root.count === 0) ? root.width : Math.max(0, root.width - row.width)
        height: root.height

        Widgets.RdDashedFrame {
            anchors.fill: parent
            anchors.leftMargin: (root.alignment === Qt.AlignRight || root.count === 0) ? 0 : VLCStyle.dp(8)
            anchors.rightMargin: (root.alignment === Qt.AlignRight && root.count > 0) ? VLCStyle.dp(8) : 0
            anchors.topMargin: Math.round((parent.height - (root.topBar ? VLCStyle.dp(28) : VLCStyle.dp(36))) / 2)
            anchors.bottomMargin: anchors.topMargin

            visible: width > VLCStyle.dp(8)
            color: slotDrop.containsDrag ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdFgA3
        }

        DropArea {
            id: slotDrop

            anchors.fill: parent

            onEntered: (drag) => {
                if (!root.acceptsDrag(drag))
                    drag.accepted = false
            }

            onDropped: (drop) => {
                root.dropAt(drop, (root.alignment === Qt.AlignRight) ? 0 : root.count)
            }
        }
    }

    Row {
        id: row

        x: (root.alignment === Qt.AlignRight) ? root.width - width : 0
        height: root.height

        move: Transition {
            NumberAnimation {
                property: "x"
                duration: VLCStyle.rd_customizeDragDuration
            }
        }

        Repeater {
            id: repeater

            delegate: CustomizeZoneItem {
                zone: root
                editor: root.editor
                height: row.height
            }
        }
    }
}
