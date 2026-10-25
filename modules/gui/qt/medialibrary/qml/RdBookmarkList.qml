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

// redesign: bookmarks of the current file in the queue sidebar's Bookmarks tab (video
// 15:08-15:16). Part of the media library module: VLC keeps bookmarks in the media library, so
// the sidebar loads this list only when the media library is available. The rows are created on
// demand (RdListView). The header's "+" adds a bookmark at the current time, like Ctrl+B
// (W4.8b); a click on a row jumps to it and selects it for the header's "-".
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.MediaLibrary
import VLC.Widgets as Widgets

Widgets.RdListView {
    id: root

    // the row the header's "-" removes
    property int selectedIndex: -1

    function addBookmark() {
        bookmarkModel.add()
    }

    function removeSelected() {
        if (selectedIndex < 0)
            return
        bookmarkModel.removeBookmark(selectedIndex)
        selectedIndex = -1
    }

    model: MLBookmarkModel {
        id: bookmarkModel

        player: Player
        ml: MediaLib
    }

    // a bookmark was added or removed, or the media changed: the old row numbers no longer hold.
    // The model resets on each of these, also when the new list has as many rows (another
    // media with the same number of bookmarks)
    Connections {
        target: bookmarkModel

        function onModelReset() { root.selectedIndex = -1 }
    }

    function _jumpTo(index) {
        selectedIndex = index
        bookmarkModel.select(bookmarkModel.index(index, 0))
    }

    // Enter on the current row jumps to it
    onActionAtIndex: (index) => root._jumpTo(index)

    delegate: Widgets.RdListRow {
        required property int index
        required property var model

        width: root.contentWidth
        // Figma "bookmarks" (Frame 39): the name starts at the row's left edge
        titleInset: 0

        title: model.name ?? ""
        detail: model.preciseTime ?? ""
        selected: root.selectedIndex === index

        Navigation.upAction: function() { root.focusRow(index - 1) }
        Navigation.downAction: function() { root.focusRow(index + 1) }
        // Enter acts on the focused row, also when it got focus by Tab
        onActiveFocusChanged: if (activeFocus) ListView.view.currentIndex = index

        onClicked: root._jumpTo(index)
    }
}
