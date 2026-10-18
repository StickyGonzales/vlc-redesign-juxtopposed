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

// redesign: the header of a library page.
// Compact library (Figma sidebar "Frame 27", 337x68, IB-12, P5-23): back and forward, the
// address line, "..." and "open in full"; under it the item count, sort, view and search icons.
// Full library (video 10:44-10:59, P5-11, IB-02, P5-14): one row with back, forward and the
// address line on the left, the count, sort, view, an always visible search field and "..."
// on the right (11:48 the top bar there has no folder chip).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.MediaLibrary

Item {
    id: root

    property bool compact: true
    // the page shown under the header (RdLibraryPage or RdLibraryHome)
    property Item page: null

    signal openFullRequested()

    property bool searchOpen: false

    // Figma: two 24 px rows 20 apart next to the video, one 34 px row in the full library
    implicitHeight: compact ? VLCStyle.dp(68) : VLCStyle.dp(34)

    // Ctrl+F
    function focusSearch() {
        if (compact) {
            searchOpen = true
            searchField.focusInput()
        } else {
            fullSearch.focusInput()
        }
    }

    // while the media library scans or indexes (VLC's old side bar showed a progress bar), the
    // count says so: the new rows are still coming
    function _countText() {
        if (!page)
            return ""
        const count = qsTr("%1 item", "%1 items", page.itemCount).arg(page.itemCount)
        if (MediaLib.idle)
            return count
        const status = MediaLib.discoveryPending ? qsTr("Scanning...")
                                                 : qsTr("Indexing %1%").arg(MediaLib.parsingProgress)
        return qsTr("%1 - %2").arg(count).arg(status)
    }

    // closing the search clears it
    onSearchOpenChanged: {
        if (searchOpen)
            return
        searchField.text = ""
        if (page)
            page.searchText = ""
    }

    Connections {
        target: RdLibraryNav

        function onLocationChanged() {
            root.searchOpen = false
            searchField.text = ""
            fullSearch.text = ""
        }
    }

    Item {
        id: firstRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.compact ? VLCStyle.dp(24) : VLCStyle.dp(34)

        Row {
            id: navButtons

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(12)

            RdLibraryIconButton {
                iconName: "arrow_direction-left"
                description: qsTr("Back")
                enabled: RdLibraryNav.canGoBack
                onClicked: RdLibraryNav.goBack()
            }

            RdLibraryIconButton {
                iconName: "arrow_direction-right"
                description: qsTr("Forward")
                enabled: RdLibraryNav.canGoForward
                onClicked: RdLibraryNav.goForward()
            }
        }

        RdBreadcrumb {
            id: breadcrumb

            anchors.left: navButtons.right
            anchors.leftMargin: VLCStyle.dp(10)
            anchors.right: root.compact ? pageActions.left : fullTools.left
            anchors.rightMargin: root.compact ? VLCStyle.dp(10) : VLCStyle.dp(20)
            anchors.verticalCenter: parent.verticalCenter

            crumbs: RdLibraryNav.location.crumbs
            // Figma Player-5: a category's root alone is not bold
            boldLast: !root.compact && RdLibraryNav.location.crumbs.length > 1
            onCrumbClicked: (index) => RdLibraryNav.openCrumb(index)
        }

        Row {
            id: pageActions

            visible: root.compact
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(12)

            RdLibraryIconButton {
                id: compactMore

                normalColor: VLCStyle.palette.rdFgA3
                iconName: "more"
                description: qsTr("More")
                onClicked: pageMenu.openForPage(compactMore, true)
            }

            RdLibraryIconButton {
                normalColor: VLCStyle.palette.rdFgA3
                iconName: "open"
                description: qsTr("Open the library in full")
                onClicked: root.openFullRequested()
            }
        }

        // full library: everything on one row (Figma Player-5 "Frame 26": count, sort, view,
        // search 325 x 34, "...", 20 apart). It never runs into back / forward: when the row is
        // short the count elides, then hides, then the search field shrinks to its minimum, then
        // the address line gives way (it folds and elides its parts); in a very small window the
        // search field hides (its search is cleared), then sort and view; "..." always shows
        Row {
            id: fullTools

            readonly property real searchMaxWidth: VLCStyle.dp(325)
            readonly property real searchMinWidth: VLCStyle.dp(120)
            readonly property real countMinWidth: VLCStyle.dp(40)
            // what the address line keeps while the count and the search field give way
            readonly property real crumbsMinWidth: VLCStyle.dp(100)

            // room for this row once back / forward, the address line's minimum and the gaps
            // are taken
            readonly property real _room: firstRow.width - navButtons.width - breadcrumb.anchors.leftMargin
                                          - breadcrumb.anchors.rightMargin - crumbsMinWidth
            // sort and view fit next to "..." (the address line may give up all its room)
            readonly property bool toolsFit: _room + crumbsMinWidth >= fullPageTools.implicitWidth + spacing
                                                                       + fullMore.width
            // the parts that always show, with the gaps around the search field
            readonly property real _fixedWidth: fullPageTools.implicitWidth + fullMore.width + 2 * spacing
            readonly property real searchWidth: {
                const room = _room - _fixedWidth
                if (room >= searchMinWidth)
                    return Math.min(searchMaxWidth, room)
                return toolsFit && room + crumbsMinWidth >= searchMinWidth ? searchMinWidth : 0
            }
            readonly property real countWidth: {
                const room = _room - _fixedWidth - searchWidth - spacing
                return room >= countMinWidth ? Math.min(fullCount.implicitWidth, room) : 0
            }

            // a search nobody can see or clear does not stay applied
            onSearchWidthChanged: {
                if (searchWidth === 0)
                    fullSearch.text = ""
            }

            visible: !root.compact
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(20)

            CountText {
                id: fullCount

                anchors.verticalCenter: parent.verticalCenter
                visible: fullTools.countWidth > 0
                width: fullTools.countWidth
                text: root._countText()
            }

            PageTools {
                id: fullPageTools

                anchors.verticalCenter: parent.verticalCenter
                visible: fullTools.toolsFit
                header: root
                menu: toolMenu
                showSearchButton: false
                spacing: VLCStyle.dp(20)
            }

            // Figma "Frame 122": 325 x 34
            SearchField {
                id: fullSearch

                anchors.verticalCenter: parent.verticalCenter
                visible: fullTools.searchWidth > 0
                width: fullTools.searchWidth
                height: VLCStyle.dp(34)
                page: root.page
            }

            RdLibraryIconButton {
                id: fullMore

                anchors.verticalCenter: parent.verticalCenter
                normalColor: VLCStyle.palette.rdFgA3
                iconName: "more"
                description: qsTr("More")
                onClicked: pageMenu.openForPage(fullMore, false)
            }
        }
    }

    // compact library: count and tools
    Item {
        visible: root.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: firstRow.bottom
        anchors.topMargin: VLCStyle.dp(20)
        height: VLCStyle.dp(24)

        CountText {
            visible: !root.searchOpen
            anchors.left: parent.left
            // elided before the tools ("3007 items - Indexing 45%")
            anchors.right: compactTools.left
            anchors.rightMargin: VLCStyle.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            text: root._countText()
        }

        SearchField {
            id: searchField

            visible: root.searchOpen
            anchors.left: parent.left
            anchors.right: compactTools.left
            anchors.rightMargin: VLCStyle.dp(12)
            anchors.verticalCenter: parent.verticalCenter
            // no Figma state: the field fits the 24 px count row
            height: VLCStyle.dp(28)
            page: root.page
            onEscaped: root.searchOpen = false
        }

        PageTools {
            id: compactTools

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            header: root
            menu: toolMenu
            showSearchButton: true
            onSearchClicked: {
                root.searchOpen = !root.searchOpen
                if (root.searchOpen)
                    searchField.focusInput()
            }
        }
    }

    RdLibraryItemMenu {
        id: pageMenu
    }

    RdLibraryMenu {
        id: toolMenu
    }

    component CountText: Text {
        elide: Text.ElideRight
        font.family: VLCStyle.rd_fontFamily
        font.pixelSize: VLCStyle.rd_fontSize_label
        color: VLCStyle.palette.rdFgA3
    }

    // sort, view and (compact) search; outer ids are passed in (inline components do not see
    // them)
    component PageTools: Row {
        id: tools

        property Item header
        property RdLibraryMenu menu
        property bool showSearchButton: true
        readonly property Item page: header ? header.page : null

        signal searchClicked()

        spacing: VLCStyle.dp(12)

        // the button whose menu is open: a second click on it closes the menu
        property Item _menuOwner: null

        function _toggleMenu(button) {
            if (menu.opened && _menuOwner === button) {
                menu.close()
                return false
            }
            _menuOwner = button
            return true
        }

        function openSortMenu(button) {
            const page = tools.page
            menu.entries = page.sortOptions.map((option) => ({
                text: option.text,
                selected: option.key === page.sortKey,
                // the check moves at once and the menu stays open (IB-03)
                action: () => { page.setSortKey(option.key); tools.openSortMenu(button) }
            }))
            menu.closeOnClick = false
            if (!menu.opened)
                menu.openBelow(button, false)
        }

        RdLibraryIconButton {
            id: sortButton

            readonly property bool sorted: !!tools.page && tools.page.sortKey !== tools.page.defaultSortKey

            visible: !!tools.page && tools.page.sortOptions.length > 0
            normalColor: VLCStyle.palette.rdFgA3
            iconName: "sort"
            description: qsTr("Sort")

            // Figma "sort" state=active: a 4 px accent dot at (22, -1), outside the icon's box
            Rectangle {
                visible: sortButton.sorted
                x: VLCStyle.dp(22)
                y: VLCStyle.dp(-1)
                width: VLCStyle.dp(4)
                height: VLCStyle.dp(4)
                radius: width / 2
                color: VLCStyle.palette.rdAccentMain
            }
            onClicked: {
                if (tools._toggleMenu(sortButton))
                    tools.openSortMenu(sortButton)
            }
        }

        RdLibraryIconButton {
            id: viewButton

            visible: !!tools.page
            normalColor: VLCStyle.palette.rdFgA3
            iconName: tools.page && tools.page.viewMode === "grid" ? "grid" : "list"
            description: qsTr("View")
            onClicked: {
                if (!tools._toggleMenu(viewButton))
                    return
                const page = tools.page
                tools.menu.entries = [
                    { text: qsTr("Grid View"), icon: "grid", selected: page.viewMode === "grid",
                      action: () => page.setViewMode("grid") },
                    { text: qsTr("List View"), icon: "list", selected: page.viewMode === "list",
                      action: () => page.setViewMode("list") }
                ]
                tools.menu.closeOnClick = true
                tools.menu.openBelow(viewButton, false)
            }
        }

        RdLibraryIconButton {
            visible: tools.showSearchButton && !!tools.page && tools.page.searchable
            normalColor: VLCStyle.palette.rdFgA3
            iconName: "search"
            description: qsTr("Search")
            onClicked: tools.searchClicked()
        }
    }

    // search field (IB-02: darker rounded field, magnifier, dim "Search")
    component SearchField: Rectangle {
        id: field

        property alias text: input.text
        property Item page

        signal escaped()

        function focusInput() {
            input.forceActiveFocus()
        }

        implicitHeight: VLCStyle.dp(34)
        radius: VLCStyle.rd_radius_normal
        // a little lighter than the page (video 10:44-10:59)
        color: VLCStyle.palette.rdBgA5
        enabled: !!page && page.searchable
        opacity: enabled ? 1 : 0.5

        Widgets.RdIcon {
            id: searchIcon

            // Figma: padding 5,8; 24 px icon, 10 before the text
            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            name: "search"
            size: VLCStyle.rd_iconSize
            color: VLCStyle.palette.rdFgA3
        }

        TextInput {
            id: input

            anchors.left: searchIcon.right
            anchors.leftMargin: VLCStyle.dp(10)
            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(8)
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFg2
            selectionColor: VLCStyle.palette.rdAccentDim
            selectByMouse: true
            // reachable with Tab like the buttons around it
            activeFocusOnTab: true

            Accessible.role: Accessible.EditableText
            Accessible.name: qsTr("Search")

            onTextChanged: {
                if (field.page)
                    field.page.searchText = text
            }

            Keys.onEscapePressed: (event) => {
                text = ""
                field.escaped()
                event.accepted = true
            }

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === "" && !input.activeFocus
                text: qsTr("Search")
                font: input.font
                color: VLCStyle.palette.rdFgA4
            }
        }
    }
}
