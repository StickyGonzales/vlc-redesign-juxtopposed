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
// redesign: a titled group of settings in the Settings dialog (Figma "Frame 125" / "Frame 99":
// header 39 px, padding 10,0, Inter 500 16 FG/2; rows directly below, no divider lines). The
// title may be empty (first group under "Advanced Options", Figma "Settings - global-1").
// While the dialog's search is active the section shows only when its title or one of its
// rows matches.
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style

ColumnLayout {
    id: root

    property string title: ""
    // extra words the search finds the whole section by
    property string keywords: ""
    // false hides the whole section, its title included (a section none of whose rows exist)
    property bool shown: true
    default property alias content: group.data

    readonly property bool isSettingsSection: true
    readonly property bool titleMatches: !!_page && _page.filtering && title !== ""
                                         && _page.textMatches([title, keywords])

    property Item _page: null
    // changed in place, counted by recount() (see SettingsPage)
    readonly property var _rows: []

    property bool _anyRowMatches: true

    function registerRow(row) {
        _rows.push(row)
        recount()
    }

    function unregisterRow(row) {
        const i = _rows.indexOf(row)
        if (i >= 0)
            _rows.splice(i, 1)
        recount()
    }

    function recount() {
        Qt.callLater(_recount)
    }

    function _recount() {
        _anyRowMatches = _rows.some((row) => row.shown && row.matches)
    }

    Connections {
        target: root._page

        function onFilterTextChanged() {
            root.recount()
        }
    }

    visible: shown && (!_page || !_page.filtering || titleMatches || _anyRowMatches)
    Layout.fillWidth: true
    spacing: 0

    Component.onCompleted: {
        for (let item = root.parent; item; item = item.parent) {
            if (item.isSettingsPage === true) {
                root._page = item
                break
            }
        }
    }

    // Text's implicit size is read-only, so the 39 px header is an Item holding the text
    Item {
        visible: root.title !== ""
        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(39)

        Text {
            anchors.fill: parent
            topPadding: VLCStyle.dp(10)
            text: root.title
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
            font.weight: Font.Medium
            color: VLCStyle.palette.rdFg2
            Accessible.role: Accessible.Heading
        }
    }

    ColumnLayout {
        id: group

        Layout.fillWidth: true
        spacing: 0
    }
}
