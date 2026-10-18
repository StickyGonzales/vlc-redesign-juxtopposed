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

// redesign: queue sidebar (video 9:29-9:34 and 15:08-15:16, Decision 3; Figma "queue",
// "bookmarks", "chapters"). Tabs Queue / Bookmarks / Chapters over VLC's play queue, the media
// library bookmarks of the current file and the chapters of the current title. Each page is
// created on first use (RdSidePanelPageLoader) and its rows on demand (RdListView).
import QtQuick
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Playlist
import VLC.Dialogs
import VLC.Util
import VLC.Widgets as Widgets

RdSidePanel {
    id: root

    tabs: [
        { key: "queue", label: qsTr("Queue"), icon: "queue", width: 128.67, underline: 112.67 },
        { key: "bookmarks", label: qsTr("Bookmarks"), icon: "bookmarks", width: 128.67, underline: 112.67 },
        { key: "chapters", label: qsTr("Chapters"), icon: "chapters", width: 128.67, underline: 112.67 }
    ]
    currentKey: RdPanels.queueOpen ? RdPanels.current : "queue"
    onTabClicked: (key) => RdPanels.open(key)

    // Figma "4 items - 2h 3m"; under a minute in seconds ("45s"); empty when no item has a
    // known duration (an empty queue, streams), so the header shows the count only
    function durationText(duration) {
        if (!duration || !duration.valid())
            return ""
        const seconds = duration.toSeconds()
        if (seconds <= 0)
            return ""
        if (seconds < 60)
            return qsTr("%1s").arg(seconds)
        const minutes = Math.floor(seconds / 60)
        return minutes >= 60 ? qsTr("%1h %2m").arg(Math.floor(minutes / 60)).arg(minutes % 60)
                             : qsTr("%1m").arg(minutes)
    }

    /* Queue */

    // header on top, then the rows, created on demand (RdListView): the queue can hold thousands
    // of items. The queue model lives only while this page does.
    RdSidePanelPageLoader {
        id: queueLoader

        key: "queue"

        sourceComponent: Item {
            id: queuePage

            property int selectedIndex: -1

            // the sidebar is open on the queue
            readonly property bool shown: root.visible && queueLoader.current

            function positionAtCurrent() {
                if (MainPlaylistController.currentIndex >= 0)
                    queueView.positionViewAtIndex(MainPlaylistController.currentIndex, ItemView.Center)
            }

            // keyboard (RdSidePanel.focusContent): the selected row, else the playing one
            function focusContent(reason) {
                if (queueModel.count === 0)
                    return false
                queueView.focusRow(queuePage.selectedIndex >= 0 ? queuePage.selectedIndex
                                                                : Math.max(0, MainPlaylistController.currentIndex))
                return true
            }

            // a control outside the queue shows the keyboard focus (in the player only such a
            // control gets the keys, MainCtx.preferHotkeys): its Delete is its own (a library list
            // of the compact library removes from its playlist)
            readonly property bool _keyboardElsewhere: {
                const focused = queuePage.Window.activeFocusItem
                return !!focused && focused.visualFocus === true && !root.containsItem(focused)
            }

            // Delete removes the row with the keyboard focus, else the selected row (a click
            // selects it), as the remove button does; a text field with the focus keeps its Delete
            Shortcut {
                sequences: [StandardKey.Delete]
                context: Qt.WindowShortcut
                enabled: queuePage.shown && (queueView.activeFocus
                                             || (queuePage.selectedIndex >= 0 && !queuePage._keyboardElsewhere))

                onActivated: {
                    const window = queuePage.Window.window
                    const focused = window ? window.activeFocusItem : null
                    const keyboard = queueView.activeFocus && !!focused && focused.visualFocus === true
                    const index = keyboard ? queueView.currentIndex : queuePage.selectedIndex
                    if (index < 0 || index >= queueModel.count)
                        return
                    queueModel.removeItems([index])
                    queuePage.selectedIndex = -1
                    // the keyboard goes on with the row that took its place
                    if (keyboard && queueModel.count > 0)
                        queueView.focusRow(Math.min(index, queueModel.count - 1))
                }
            }

            onShownChanged: {
                if (shown)
                    positionAtCurrent()
            }

            Component.onCompleted: {
                if (shown)
                    Qt.callLater(positionAtCurrent)
            }

            PlaylistListModel {
                id: queueModel

                playlist: MainPlaylistController.playlist
                onCountChanged: queuePage.selectedIndex = -1
            }

            // drag to reorder: VLC's play queue drag (PlaylistPane), started from a row's handle
            Widgets.DragItem {
                id: dragItem

                view: queueView
                // the ghost is the row content only (IB-15)
                rdRowGhost: true

                onRequestData: (indexes, resolve, reject) => {
                    resolve(indexes.map((index) => {
                        const item = queueModel.itemAt(index)
                        return {
                            "title": item.title,
                            "cover": (!!item.artwork && item.artwork.toString() !== "") ? item.artwork : VLCStyle.noArtAlbumCover,
                            "url": item.url
                        }
                    }))
                }

                onRequestInputItems: (indexes, data, resolve, reject) => {
                    resolve(queueModel.getItemsForIndexes(indexes))
                }
            }

            Header {
                id: queueHeader

                width: parent.width
                height: VLCStyle.dp(68)

                readonly property string countText: qsTr("%1 item", "%1 items", queueModel.count).arg(queueModel.count)
                readonly property string durationText: root.durationText(queueModel.duration)

                text: durationText !== "" ? qsTr("%1 - %2").arg(countText).arg(durationText) : countText

                HeaderButton {
                    rdIcon: "sort"
                    description: qsTr("Sort by title")
                    // sorting by the same key again reverses the order
                    onClicked: {
                        queuePage.selectedIndex = -1
                        MainPlaylistController.sort(PlaylistController.SORT_KEY_TITLE)
                    }
                }

                HeaderButton {
                    width: VLCStyle.rd_iconButtonWidth
                    rdIcon: "repeat_direction-right"
                    description: qsTr("Repeat")
                    checked: MainPlaylistController.repeatMode !== PlaylistController.PLAYBACK_REPEAT_NONE
                    onClicked: MainPlaylistController.toggleRepeatMode()
                }

                HeaderButton {
                    width: VLCStyle.rd_iconButtonWidth
                    rdIcon: "shuffle_direction-right"
                    description: qsTr("Shuffle")
                    checked: MainPlaylistController.random
                    onClicked: MainPlaylistController.toggleRandom()
                }

                HeaderButton {
                    rdIcon: "remove"
                    description: qsTr("Remove the selected item")
                    enabled: queuePage.selectedIndex >= 0
                    onClicked: {
                        queueModel.removeItems([queuePage.selectedIndex])
                        queuePage.selectedIndex = -1
                    }
                }

                HeaderButton {
                    rdIcon: "add"
                    description: qsTr("Add files to the queue")
                    onClicked: DialogsProvider.simpleOpenDialog(false)
                }
            }

            Widgets.RdListView {
                id: queueView

                anchors.top: queueHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                model: queueModel

                // a row of the queue moved, library items or files dropped in; rows of the
                // redesigned library carry their URLs in rdDragUrls (video 11:44-11:49, W5.9)
                isDropAcceptableFunc: function(drag, index) {
                    if (drag.source === dragItem)
                        return Helpers.itemsMovable(dragItem.indexes, index)
                    else if (Helpers.isValidInstanceOf(drag.source, Widgets.DragItem))
                        return true
                    else if (drag.source && drag.source.rdDragUrls)
                        return drag.source.rdDragUrls.length > 0
                    return drag.hasUrls
                }

                acceptDropFunc: function(index, drop) {
                    const source = drop.source

                    if (source === dragItem) {
                        queueModel.moveItemsPre(dragItem.indexes, index)
                        queuePage.selectedIndex = -1
                    } else if (Helpers.isValidInstanceOf(source, Widgets.DragItem)) {
                        return source.getSelectedInputItem().then((inputItems) => {
                            if (!Helpers.isArray(inputItems) || inputItems.length === 0) {
                                console.warn("can't convert items to input items")
                                return
                            }
                            MainPlaylistController.insert(index, inputItems, false)
                        })
                    } else if (source && source.rdDragUrls) {
                        MainPlaylistController.insert(index, source.rdDragUrls, false)
                    } else if (drop.hasUrls) {
                        const urls = []
                        for (let i in drop.urls)
                            urls.push(drop.urls[i])
                        MainPlaylistController.insert(index, urls, false)
                        // otherwise the main window adds the files as well
                        drop.accept(Qt.IgnoreAction)
                    }

                    return Promise.resolve()
                }

                // Enter on the current row plays it
                onActionAtIndex: (index) => MainPlaylistController.goTo(index, true)

                // a click selects the row (for "remove"), a double click plays it; the handle
                // drags it to another place in the queue
                delegate: Widgets.RdListRow {
                    id: queueRow

                    required property int index
                    required property var model

                    // drop target of a drag (ListViewExt: drop indicator and auto scroll)
                    readonly property bool topContainsDrag: dropAreas.higherDropArea.containsDrag
                    readonly property bool bottomContainsDrag: dropAreas.lowerDropArea.containsDrag
                    readonly property bool containsDrag: topContainsDrag || bottomContainsDrag
                    readonly property point dragPosition: mapFromItem(dropAreas,
                                                                      dropAreas.dragPosition.x,
                                                                      dropAreas.dragPosition.y)

                    width: queueView.contentWidth

                    title: model.title ?? ""
                    detail: model.duration && model.duration.valid() ? model.duration.formatHMS() : ""
                    current: !!model.isCurrent
                    selected: queuePage.selectedIndex === index || dragHandler.active
                    leftPadding: VLCStyle.dp(32)

                    ListView.delayRemove: dragHandler.active

                    // Up from the first row goes to the tabs
                    Navigation.upAction: function() {
                        if (index > 0)
                            queueView.focusRow(index - 1)
                        else
                            root.focusTabs(Qt.BacktabFocusReason)
                    }
                    Navigation.downAction: function() { queueView.focusRow(index + 1) }
                    // Enter acts on the focused row, also when it got focus by Tab
                    onActiveFocusChanged: if (activeFocus) ListView.view.currentIndex = index

                    onContainsDragChanged: queueView.updateItemContainsDrag(this, containsDrag)

                    onClicked: {
                        queuePage.selectedIndex = index
                        queueView.currentIndex = index
                    }
                    onDoubleClicked: MainPlaylistController.goTo(index, true)

                    Widgets.RdIcon {
                        x: VLCStyle.dp(4)
                        anchors.verticalCenter: parent.verticalCenter
                        name: "move"
                        color: VLCStyle.palette.rdFgA3

                        DragHandler {
                            id: dragHandler

                            target: null
                            cursorShape: Qt.SizeVerCursor
                            // keep the drag from the list's flicking
                            grabPermissions: PointerHandler.CanTakeOverFromAnything

                            onActiveChanged: {
                                if (active) {
                                    queuePage.selectedIndex = queueRow.index
                                    dragItem.indexes = [queueRow.index]
                                    dragItem.indexesFlat = true
                                    dragItem.Drag.active = true
                                } else {
                                    dragItem.Drag.drop()
                                }
                            }
                        }
                    }

                    // the drop areas cover the row and half of the gaps around it
                    Widgets.ListViewExt.VerticalDropAreaLayout {
                        id: dropAreas

                        anchors.fill: parent
                        anchors.topMargin: -queueView.spacing / 2
                        anchors.bottomMargin: -queueView.spacing / 2

                        index: queueRow.index
                        view: queueView
                        isDropAcceptable: queueView.isDropAcceptableFunc
                        acceptDrop: queueView.acceptDropFunc
                    }
                }
            }
        }
    }

    /* Bookmarks */

    RdSidePanelPageLoader {
        key: "bookmarks"

        sourceComponent: ColumnLayout {
            spacing: 0

            Header {
                text: qsTr("%1 Bookmark", "%1 Bookmarks", bookmarkLoader.item ? bookmarkLoader.item.count : 0)
                          .arg(bookmarkLoader.item ? bookmarkLoader.item.count : 0)

                // "-" removes the selected bookmark, "+" adds one at the current time at once,
                // like Ctrl+B (video 15:03-15:16, W4.8b)
                HeaderButton {
                    rdIcon: "remove"
                    description: qsTr("Remove the selected bookmark")
                    enabled: !!bookmarkLoader.item && bookmarkLoader.item.selectedIndex >= 0
                    onClicked: bookmarkLoader.item.removeSelected()
                }

                HeaderButton {
                    rdIcon: "add"
                    description: qsTr("Add a bookmark at the current time (Ctrl + B)")
                    enabled: !!bookmarkLoader.item && Player.isStarted
                    onClicked: bookmarkLoader.item.addBookmark()
                }
            }

            // VLC keeps bookmarks in the media library
            Loader {
                id: bookmarkLoader

                Layout.fillWidth: true
                Layout.fillHeight: true
                active: MainCtx.mediaLibraryAvailable
                source: "qrc:///qt/qml/VLC/MediaLibrary/RdBookmarkList.qml"
            }
        }
    }

    /* Chapters */

    RdSidePanelPageLoader {
        key: "chapters"

        sourceComponent: Item {
            // keyboard (RdSidePanel.focusContent): the current chapter
            function focusContent(reason) {
                if (chapterView.count === 0)
                    return false
                chapterView.focusRow(Math.max(0, chapterView.currentIndex))
                return true
            }

            Widgets.RdListView {
                id: chapterView

                anchors.fill: parent
                // Figma "chapters": 20 px above the first row and below the last one
                topMargin: VLCStyle.dp(20)
                bottomMargin: VLCStyle.dp(20)

                model: Player.chapters

                // Enter on the current row jumps to it
                onActionAtIndex: (index) => Player.chapters.selectChapter(index)

                delegate: Widgets.RdListRow {
                    required property int index
                    required property var model

                    width: chapterView.contentWidth

                    number: index + 1
                    title: model.display ?? ""
                    // hh:mm:ss like the control bar's time (Figma "chapters" 00:02:15)
                    detail: model.time ? model.time.formatHHMMSS() : ""
                    current: !!model.checked

                    // Up from the first row goes to the tabs
                    Navigation.upAction: function() {
                        if (index > 0)
                            chapterView.focusRow(index - 1)
                        else
                            root.focusTabs(Qt.BacktabFocusReason)
                    }
                    Navigation.downAction: function() { chapterView.focusRow(index + 1) }
                    // Enter acts on the focused row, also when it got focus by Tab
                    onActiveFocusChanged: if (activeFocus) ListView.view.currentIndex = index

                    onClicked: Player.chapters.selectChapter(index)
                }
            }

            Text {
                visible: Player.chapters.count === 0
                x: VLCStyle.dp(20)
                y: VLCStyle.dp(20)
                width: parent.width - 2 * VLCStyle.dp(20)
                leftPadding: VLCStyle.dp(4)
                text: qsTr("This media has no chapters")
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }
        }
    }

    /* parts */

    // Figma "Frame 60": 400x68, padding 20,20,20,28, count on the left, icons on the right
    component Header: Item {
        property alias text: label.text
        default property alias buttons: buttonRow.data

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(68)

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(28)
            anchors.right: buttonRow.left
            anchors.rightMargin: VLCStyle.dp(10)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Row {
            id: buttonRow

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(20)
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(12)
        }
    }

    // queue header icon: accent while its mode is on (repeat, shuffle). Figma "Frame 61"
    // (463:842): the icons are 24 wide and 12 apart, the repeat and shuffle frames 30 wide
    component HeaderButton: Widgets.IconToolButton {
        width: VLCStyle.rd_iconSize
        height: VLCStyle.rd_iconButtonHeight
        font.pixelSize: VLCStyle.rd_iconSize
        text: VLCIcons.more
        color: checked ? colorContext.accent : (hovered ? VLCStyle.palette.rdFgA1 : VLCStyle.palette.rdFgA2)
    }
}
