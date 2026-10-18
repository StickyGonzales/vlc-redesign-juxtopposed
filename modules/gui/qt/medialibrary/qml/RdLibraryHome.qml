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

// redesign: the library Home (video 13:44-13:55, 20:52-20:59; P6-20, P6-21, IB-33, IB-34, P8-38,
// F-15; Figma sidebar "home"): Continue Watching, Listen Again, Frequently Visited Folders,
// Frequently Visited Playlists, Frequently Listened Artists and Latest Streams (Decision 8).
// Next to the video each section lists 3 rows under its title, with a ">" at the panel's edge;
// in the full library each section is a row of cards with the ">" right after the title.
// The ">" opens the whole section. With nothing played yet, Home shows "Watch Next" and an
// empty card (20:52).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.MediaLibrary

FocusScope {
    id: home

    required property var location
    property bool compact: true

    property string searchText: ""

    readonly property string viewMode: compact ? RdLibraryStore.compactViewMode : RdLibraryStore.viewMode
    readonly property bool listMode: viewMode === "list"

    function setViewMode(mode) {
        if (compact)
            RdLibraryStore.compactViewMode = mode
        else
            RdLibraryStore.viewMode = mode
    }

    readonly property var sortOptions: []
    readonly property string sortKey: ""
    readonly property string defaultSortKey: ""
    function setSortKey(key) { }

    readonly property bool searchable: true

    property int itemCount: 0
    // a section is still loading: the "Watch Next" empty state waits for it
    property bool anyLoading: true

    signal loaded()

    readonly property var sections: [
        { section: "continueWatching", title: qsTr("Continue Watching"), wide: true },
        { section: "listenAgain", title: qsTr("Listen Again"), wide: false },
        { section: "frequentFolders", title: qsTr("Frequently Visited Folders"), wide: false },
        { section: "frequentPlaylists", title: qsTr("Frequently Visited Playlists"), wide: false },
        { section: "frequentArtists", title: qsTr("Frequently Listened Artists"), wide: false },
        { section: "latestStreams", title: qsTr("Latest Streams"), wide: false }
    ]

    // full library (Figma Player-5): one row of cards per section, as many as fit, 20 apart;
    // Continue Watching cards 316 wide (16:9), the others 200 (square)
    readonly property real _cardGap: VLCStyle.dp(20)

    function _cardWidth(wide) {
        return wide ? VLCStyle.dp(316) : VLCStyle.dp(200)
    }

    function _limit(wide) {
        if (compact || listMode)
            return 3
        return Math.max(1, Math.floor((flick.width + _cardGap) / (_cardWidth(wide) + _cardGap)))
    }

    function _updateCount() {
        let count = 0
        let loading = false
        for (let i = 0; i < sectionRepeater.count; ++i) {
            const s = sectionRepeater.itemAt(i)
            if (s) {
                count += s.model.count
                loading = loading || s.model.loading
            }
        }
        itemCount = count
        anyLoading = loading
    }

    // compared as RdLibraryNav.mrlKey (decoded safely, drive letters as on disk)
    readonly property string playingMrl: Player.url.toString() !== "" ? RdLibraryNav.mrlKey(Player.url.toString()) : ""

    Flickable {
        id: flick

        anchors.fill: parent
        clip: true
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        T.ScrollBar.vertical: T.ScrollBar {
            id: scrollBar

            policy: flick.contentHeight > flick.height ? T.ScrollBar.AsNeeded : T.ScrollBar.AlwaysOff
            width: VLCStyle.dp(6)
            contentItem: Rectangle {
                implicitWidth: VLCStyle.dp(4)
                radius: width / 2
                color: VLCStyle.palette.rdDividerBright
                opacity: scrollBar.active ? 1 : 0
            }
        }

        // Figma: next to the video sections 30 apart; in the full library the first title 37 below
        // the divider (17 here) and 77 from a row of cards to the next title
        Column {
            id: column

            width: flick.width
            topPadding: home.compact ? 0 : VLCStyle.dp(17)
            spacing: home.compact ? VLCStyle.dp(30) : VLCStyle.dp(77)

            Repeater {
                id: sectionRepeater

                model: home.sections

                delegate: Column {
                    id: sectionItem

                    required property var modelData

                    readonly property alias model: sectionModel

                    width: column.width
                    spacing: home.compact ? VLCStyle.dp(15) : VLCStyle.dp(20)
                    visible: sectionModel.count > 0

                    RdCollectionModel {
                        id: sectionModel

                        ml: MediaLib
                        section: sectionItem.modelData.section
                        limit: home._limit(sectionItem.modelData.wide)
                        searchPattern: home.searchText
                        ids: {
                            if (sectionItem.modelData.section === "frequentFolders")
                                return RdLibraryStore.frequentFolderIds
                            if (sectionItem.modelData.section === "frequentPlaylists")
                                return RdLibraryStore.frequentPlaylistIds
                            return []
                        }
                        onCountChanged: home._updateCount()
                        onLoadingChanged: home._updateCount()
                        onLoaded: home.loaded()
                    }

                    SectionHeader {
                        width: parent.width
                        text: sectionItem.modelData.title
                        chevronAtEdge: home.compact
                        onClicked: RdLibraryNav.openChild({ page: "section", section: sectionItem.modelData.section,
                                                            title: sectionItem.modelData.title })
                    }

                    // next to the video: rows (Figma rows, gap 10)
                    Column {
                        visible: home.compact || home.listMode
                        width: parent.width
                        spacing: VLCStyle.dp(10)

                        Repeater {
                            model: home.compact || home.listMode ? sectionModel : null

                            delegate: RdLibraryRow {
                                required property var model
                                required property int index

                                readonly property var item: home.toItem(model, index)

                                width: parent.width
                                title: home.titleOf(item)
                                iconName: home.iconOf(item)
                                thumbnail: home.thumbnailOf(item)
                                // Figma: songs and videos boxed, streams a bare icon
                                boxed: item.kind === "media"
                                       || (item.kind === "playlist" && thumbnail.toString() !== "")
                                progress: item.progress
                                // Home rows are secondary (Figma: FG/A3)
                                secondary: true
                                watched: item.watched
                                playing: home.isPlaying(item.mrl)
                                dragUrls: home.dragUrlsOf(item)
                                onClicked: home.activate(item)
                                onMoreClicked: (button) => itemMenu.openForItem(item, button, home.categoryOf(item))
                            }
                        }
                    }

                    // full library: a row of cards
                    Row {
                        visible: !home.compact && !home.listMode
                        spacing: home._cardGap

                        Repeater {
                            model: !home.compact && !home.listMode ? sectionModel : null

                            delegate: RdLibraryCard {
                                required property var model
                                required property int index

                                readonly property var item: home.toItem(model, index)

                                width: home._cardWidth(sectionItem.modelData.wide)
                                title: item.title
                                subtitle: item.kind === "media" && !item.isVideo ? (item.subtitle ?? "") : ""
                                iconName: home.iconOf(item) || "videos"
                                thumbnail: home.thumbnailOf(item)
                                wide: sectionItem.modelData.wide
                                progress: item.progress
                                watched: item.watched
                                playing: home.isPlaying(item.mrl)
                                dragUrls: home.dragUrlsOf(item)
                                onClicked: home.activate(item)
                                onMoreClicked: (button) => itemMenu.openForItem(item, button, home.categoryOf(item))
                            }
                        }
                    }
                }
            }

            // nothing played yet (20:52-20:59)
            Column {
                visible: home.itemCount === 0 && !home.anyLoading && home.searchText === ""
                width: parent.width
                spacing: home.compact ? VLCStyle.dp(15) : VLCStyle.dp(20)

                // no Figma node (Decision 21): the video's white title (20:52) over an empty
                // card in the Figma card style (316 x 177.75, radius 12, #171717)
                SectionHeader {
                    width: parent.width
                    text: qsTr("Watch Next")
                    chevronAtEdge: home.compact
                    textColor: VLCStyle.palette.rdFg1
                    onClicked: RdLibraryNav.openRoot("videos")
                }

                Rectangle {
                    width: Math.min(parent.width, VLCStyle.dp(316))
                    height: width * 9 / 16
                    radius: VLCStyle.rd_radius_card
                    color: VLCStyle.palette.rdCardBase
                }
            }
        }
    }

    function toItem(model, index) {
        return {
            kind: model.kind,
            index: index,
            // held by value (the section reloads on media library events, see RdLibraryNav)
            id: RdLibraryNav.detachedId(model.id),
            title: model.title,
            subtitle: model.subtitle,
            mrl: model.mrl,
            thumbnail: model.thumbnail,
            progress: model.progress,
            watched: model.watched,
            isVideo: model.isVideo,
            isFavorite: model.isFavorite
        }
    }

    function iconOf(item) {
        switch (item.kind) {
        case "folder": return "folder"
        case "playlist": return "playlist"
        case "artist": return "artist"
        case "stream": return "streaming"
        default: return item.isVideo ? "" : "music"
        }
    }

    function titleOf(item) {
        if (item.kind === "media" && !item.isVideo && item.subtitle)
            return qsTr("%1 - %2").arg(item.title).arg(item.subtitle)
        return item.title
    }

    function thumbnailOf(item) {
        if (item.kind === "playlist") {
            const covers = RdLibraryStore.playlistCovers
            return covers ? RdLibraryStore.playlistCover(item.id).toString() : ""
        }
        return item.thumbnail ?? ""
    }

    function isPlaying(mrl) {
        return playingMrl !== "" && !!mrl && RdLibraryNav.mrlKey(mrl) === playingMrl
    }

    function dragUrlsOf(item) {
        return (item.kind === "media" || item.kind === "stream") && item.mrl ? [item.mrl] : []
    }

    // the category of a Home row (RdLibraryNav.itemCategory)
    function categoryOf(item) {
        return RdLibraryNav.itemCategory(item)
    }

    // a frequent folder opens with its whole address line
    function activate(item) {
        if (item.kind === "folder") {
            RdLibraryStore.noteVisit("folder", item.id)
            RdLibraryStore.resolveFolder(item.mrl, (result) => RdLibraryNav.openFolderPath(result))
            return
        }
        RdLibraryActions.activate(item, home.categoryOf(item))
    }

    RdLibraryItemMenu {
        id: itemMenu

        location: home.location
    }

    // section title with its ">" link (Figma: next to the video Inter 400 16 FG/A1 in a 32 px
    // row, the chevron at the edge; in the full library Inter 400 20 in a 24 px row, the 24 px
    // chevron 5 after the title)
    component SectionHeader: T.AbstractButton {
        id: header

        property bool chevronAtEdge: true
        property color textColor: VLCStyle.palette.rdFgA1

        implicitHeight: chevronAtEdge ? VLCStyle.dp(32) : VLCStyle.dp(24)
        hoverEnabled: true
        focusPolicy: Qt.TabFocus

        Keys.onReturnPressed: header.clicked()
        Keys.onEnterPressed: header.clicked()

        Accessible.role: Accessible.Link
        Accessible.name: text

        contentItem: Item {
            Text {
                id: label

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - chevron.width - VLCStyle.dp(10))
                text: header.text
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: header.chevronAtEdge ? VLCStyle.rd_fontSize_header : VLCStyle.rd_fontSize_section
                color: header.hovered || header.visualFocus ? VLCStyle.palette.rdFg2 : header.textColor
            }

            Widgets.RdIcon {
                id: chevron

                anchors.verticalCenter: parent.verticalCenter
                x: header.chevronAtEdge ? parent.width - width : label.width + VLCStyle.dp(5)
                name: "chevron_direction-right"
                size: VLCStyle.rd_iconSize
                color: header.hovered || header.visualFocus ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA2
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }
}
