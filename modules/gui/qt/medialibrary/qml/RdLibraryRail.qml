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

// redesign: the library rail (video 10:16-10:22, 11:40-11:59, 13:33-13:55, 20:08-20:19,
// 20:52-20:59; IA-44, P5-07, IB-07, IB-13, P6-18, IB-32, P6-19, IB-47, P8-53; Figma sidebar
// "Frame 3": 50 wide, BG/A4, padding 8, gap 14, 30x32 icon wrappers).
// Order: Home, Videos, Music, Network, Playlists, Recent, the pins, "+".
// Icons: the category open at its own page = filled accent icon; inside it = filled gray icon;
// the others = gray outlines (Network and Playlists have accent outlines instead of filled
// ones). The full library adds the labels (gray, the current one bright) and turns icon and
// label accent on hover (20:13).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.MediaLibrary

Rectangle {
    id: rail

    // full library: labels next to the icons
    property bool showLabels: false

    // Figma: next to the video a 50 wide BG/A4 column; in the full library 217 wide on BG/B1
    // with a BG/A4 card inside (margins 8, radius 6, padding 12 / 16)
    implicitWidth: showLabels ? VLCStyle.rd_libraryRailFullWidth : VLCStyle.rd_libraryRailWidth
    color: showLabels ? VLCStyle.palette.rdBgB1 : VLCStyle.palette.rdBgA4

    Rectangle {
        visible: rail.showLabels
        anchors.fill: parent
        anchors.margins: VLCStyle.dp(8)
        radius: VLCStyle.rd_radius_normal
        color: VLCStyle.palette.rdBgA4
    }

    readonly property var _categories: [
        { page: "home", category: "home", label: qsTr("Home"), icon: "home",
          active: "home_state-active", selected: "home_state-selected" },
        { page: "videos", category: "video", label: qsTr("Videos"), icon: "videos",
          active: "videos_state-active", selected: "videos_state-selected" },
        { page: "music", category: "music", label: qsTr("Music"), icon: "songs",
          active: "songs_state-active", selected: "songs_state-selected" },
        { page: "network", category: "network", label: qsTr("Network"), icon: "streaming",
          active: "streaming_state-active", selected: "streaming_state-selected" },
        { page: "playlists", category: "playlists", label: qsTr("Playlists"), icon: "playlist",
          active: "playlist_state-active", selected: "playlist_state-active" },
        { page: "recent", category: "recent", label: qsTr("Recent"), icon: "recent",
          active: "recent", selected: "recent" }
    ]

    Flickable {
        anchors.fill: parent
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column

            // width of the buttons
            readonly property real itemWidth: width - leftPadding - rightPadding

            width: parent.width
            topPadding: rail.showLabels ? VLCStyle.dp(20) : VLCStyle.dp(8)
            bottomPadding: rail.showLabels ? VLCStyle.dp(20) : VLCStyle.dp(8)
            leftPadding: rail.showLabels ? VLCStyle.dp(24) : 0
            rightPadding: rail.showLabels ? VLCStyle.dp(24) : 0
            spacing: VLCStyle.dp(14)

            Repeater {
                model: rail._categories

                delegate: RailButton {
                    required property var modelData

                    readonly property bool isCurrent: RdLibraryNav.category === modelData.category

                    label: modelData.label
                    iconName: !isCurrent ? modelData.icon
                                         : (RdLibraryNav.atCategoryRoot ? modelData.active : modelData.selected)
                    // Recent has no filled icon: the current one is accent
                    accentIcon: isCurrent && modelData.page === "recent"
                    current: isCurrent
                    showLabel: rail.showLabels
                    width: column.itemWidth
                    onClicked: RdLibraryNav.openRoot(modelData.page)
                }
            }

            // pins: a pinned playlist shows its thumbnail, a folder its outline icon (IB-32)
            Repeater {
                model: RdLibraryStore.pins

                delegate: RailButton {
                    id: pinButton

                    required property var modelData
                    required property int index

                    label: modelData.title
                    iconName: modelData.kind === "playlist" ? "playlist"
                            : modelData.kind === "folder" ? "folder"
                            : modelData.kind === "stream" ? "streaming"
                            : modelData.kind === "artist" ? "artist"
                            : modelData.kind === "album" ? "album"
                            : modelData.kind === "genre" ? "genre" : "music"
                    image: modelData.image ?? ""
                    // a folder's key is its MRL, which Qt, VLC and the media library encode
                    // differently: compared decoded, as everywhere in the library (IB-32)
                    current: RdLibraryNav.location.page === modelData.location.page
                             && RdLibraryNav.mrlKey(RdLibraryNav.key(RdLibraryNav.location))
                                === RdLibraryNav.mrlKey(modelData.location.key)
                    showLabel: rail.showLabels
                    width: column.itemWidth
                    onClicked: RdLibraryNav.openPin(modelData.location)
                    onContextRequested: (x, y) => {
                        pinMenu.entries = [
                            { text: qsTr("Unpin"), icon: "close", action: () => RdLibraryStore.removePin(index) },
                            { text: qsTr("Move Up"), icon: "arrow_direction-up", enabled: index > 0,
                              action: () => RdLibraryStore.movePin(index, index - 1) },
                            { text: qsTr("Move Down"), icon: "arrow_direction-down",
                              enabled: index < RdLibraryStore.pins.length - 1,
                              action: () => RdLibraryStore.movePin(index, index + 1) }
                        ]
                        pinMenu.openAt(pinButton, x, y)
                    }
                }
            }

            RailButton {
                id: addButton

                label: qsTr("Add item")
                iconName: "add"
                showLabel: rail.showLabels
                width: column.itemWidth
                onClicked: {
                    const location = RdLibraryNav.location
                    addMenu.entries = [
                        { text: qsTr("Pin This Page"), icon: "add", enabled: RdLibraryNav.isPinnable(location)
                                                                         && RdLibraryStore.pinIndex(RdLibraryNav.pinLocation(location)) < 0,
                          action: () => rail._pin(location) },
                        { text: qsTr("Pin a Folder..."), icon: "new-folder_two-tone-yes", action: () => rail._pinFolder() }
                    ]
                    addMenu.openBeside(addButton)
                }
            }
        }
    }

    function _pin(location) {
        let kind = "folder"
        let image = ""
        switch (location.page) {
        case "playlist":
            kind = "playlist"
            image = RdLibraryStore.playlistCover(location.id).toString()
            break
        case "collection":
            kind = location.kind
            break
        case "streams":
        case "service":
            kind = "stream"
            break
        case "section":
            kind = "section"
            break
        }
        RdLibraryStore.addPin(kind, location.title, image, RdLibraryNav.pinLocation(location))
    }

    // a folder picked on disk joins Videos and is pinned once the media library has it
    property string _folderToPin: ""

    function _pinFolder() {
        RdLibraryStore.pickFolder(qsTr("Pin a Folder"), "", "video", (url) => {
            if (url.toString() === "")
                return
            RdLibraryStore.addFolder("video", url)
            rail._folderToPin = url.toString()
        })
    }

    Connections {
        target: RdLibraryStore
        enabled: rail._folderToPin !== ""

        function onFoldersScanned() {
            rail._tryPinFolder(false)
        }

        function onFolderAdded(category, mrl) {
            rail._tryPinFolder(false)
        }

        // the scan ended: one last look, then stop waiting for the folder
        function onScanFinished() {
            rail._tryPinFolder(true)
        }
    }

    function _tryPinFolder(lastTry) {
        const mrl = _folderToPin
        RdLibraryStore.resolveFolder(mrl, (result) => {
            if (rail._folderToPin !== mrl)
                return
            const crumbs = result ? result.crumbs : []
            const last = crumbs.length > 0 ? crumbs[crumbs.length - 1] : null
            if (!last || RdLibraryNav.mrlKey(last.mrl) !== RdLibraryNav.mrlKey(mrl)) {
                // (another scan may still run: keep waiting for it)
                if (lastTry && !MediaLib.discoveryPending)
                    rail._folderToPin = ""
                return
            }
            rail._folderToPin = ""
            const categoryRoot = result.category === "music"
                               ? [{ page: "music", title: qsTr("Music") }, { page: "songs", title: qsTr("Songs") }]
                               : [{ page: "videos", title: qsTr("Videos") }]
            const path = categoryRoot.concat(crumbs.map((c) => ({
                page: "folder", category: result.category, id: c.id, mrl: c.mrl, title: c.title
            })))
            const loc = path[path.length - 1]
            loc.crumbs = path
            RdLibraryStore.addPin("folder", loc.title, "", RdLibraryNav.pinLocation(loc))
        }, "video")
    }

    RdLibraryMenu {
        id: pinMenu
    }

    RdLibraryMenu {
        id: addMenu

        function openBeside(item) {
            parent = item
            x = item.width + VLCStyle.dp(4)
            y = 0
            open()
        }
    }

    // one rail entry: icon wrapper (30x32, #FFFFFF 6% hover) and, in the full library, the label
    component RailButton: T.AbstractButton {
        id: button

        property string label: ""
        property string iconName: ""
        property url image: ""
        property bool current: false
        property bool accentIcon: false
        property bool showLabel: false

        signal contextRequested(real x, real y)

        implicitHeight: VLCStyle.rd_iconButtonHeight
        hoverEnabled: true
        focusPolicy: Qt.TabFocus

        Keys.onReturnPressed: button.clicked()
        Keys.onEnterPressed: button.clicked()

        Accessible.role: Accessible.Button
        Accessible.name: label

        T.ToolTip.visible: !showLabel && (hovered || visualFocus)
        T.ToolTip.delay: VLCStyle.delayToolTipAppear
        T.ToolTip.text: label

        readonly property bool _hot: hovered || visualFocus

        contentItem: Item {
            Rectangle {
                id: wrapper

                x: button.showLabel ? 0 : (parent.width - width) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.rd_iconButtonWidth
                height: VLCStyle.rd_iconButtonHeight
                radius: VLCStyle.rd_radius_small
                // Figma "Icon Wrapper" hover: #FFFFFF 6 %, the icon and label keep their colors
                color: button._hot ? VLCStyle.palette.rdHoverOverlay : "transparent"

                Widgets.ImageExt {
                    anchors.centerIn: parent
                    width: VLCStyle.rd_iconSize
                    height: VLCStyle.rd_iconSize
                    radius: VLCStyle.rd_radius_small
                    visible: button.image.toString() !== "" && status === Image.Ready
                    source: button.image
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width * 2, height * 2)
                }

                Widgets.RdIcon {
                    anchors.centerIn: parent
                    visible: button.image.toString() === ""
                    name: button.iconName
                    color: button.accentIcon ? VLCStyle.palette.rdAccentMain : VLCStyle.palette.rdFgA2
                }
            }

            Text {
                visible: button.showLabel
                anchors.left: wrapper.right
                anchors.leftMargin: VLCStyle.dp(8)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: button.label
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                // Figma Player-5: the current category's label is FG/2 at its root, FG/A2 inside
                color: button.current && RdLibraryNav.atCategoryRoot ? VLCStyle.palette.rdFg2
                                                                     : VLCStyle.palette.rdFgA2
            }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: (eventPoint) => button.contextRequested(eventPoint.position.x, eventPoint.position.y)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }
}
