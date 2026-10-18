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

// redesign: tracks popup (video 4:30-4:56, Figma "Controls" variants subtitles / audio / video,
// frame "Subtitles" 400x524). One rounded panel (radius 10, BG/B1, opaque over the native
// video) whose top is the tab header: 400x50 BG/B2, tabs Video / Audio / Subtitles of 128.67 px
// (6 px side padding, 1 px apart); the active tab has a two-tone icon and a 2 px accent
// underline (tab width - 16). A 1 px gap of the panel color separates the header from the body.
// Sections: "Embedded Tracks", then "External Tracks" (+) for subtitles or "Output Device"
// (refresh) for audio; full-width "Show Preferences" bar at the bottom.
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Util
import VLC.Dialogs

Item {
    id: root

    readonly property string tab: RdPanels.tracksOpen ? RdPanels.current : "subtitles"
    readonly property SystemPalette rdPalette: VLCStyle.palette

    // room between the top bar and the 20 px margin above the control bar (Player.qml); the
    // popup keeps 20 px below the top bar like the sidebars, so the Figma height (524) shrinks
    // to fit small windows
    property real maximumHeight: VLCStyle.dp(524, VLCStyle.scale) + _topGap
    readonly property real _topGap: VLCStyle.dp(20, VLCStyle.scale)

    readonly property real _headerHeight: VLCStyle.rd_sidePanelTabHeight + VLCStyle.dp(1, VLCStyle.scale)

    implicitWidth: VLCStyle.rd_sidePanelWidth
    // the Figma height (524 with the tabs) whatever the number of tracks or devices: each list
    // scrolls inside its Figma frame (TrackListFrame) and Show Preferences stays pinned at the
    // bottom; in a window too small for 524 the popup shrinks and its sections scroll
    implicitHeight: Math.max(0, Math.min(VLCStyle.dp(524, VLCStyle.scale), maximumHeight - _topGap))

    // scrolls the lists holding `item` so that it shows (keyboard focus on a row)
    function _ensureVisible(item) {
        for (let p = item.parent; p; p = p.parent) {
            if (p.contentItem === undefined || p.contentY === undefined || p.contentHeight === undefined)
                continue
            const y = item.mapToItem(p.contentItem, 0, 0).y
            let target = p.contentY
            if (y < target)
                target = y
            else if (y + item.height > target + p.height)
                target = y + item.height - p.height
            p.contentY = Math.max(0, Math.min(target, p.contentHeight - p.height))
        }
    }

    visible: RdPanels.tracksOpen

    // keyboard (opened from the control bar with the keyboard): the active tab takes the focus;
    // Left / Right switch tabs, Down goes into the tab's content, where Up / Down move like Tab
    function focusContent(reason) {
        for (let i = 0; i < tabRepeater.count; ++i) {
            const tab = tabRepeater.itemAt(i)
            if (tab && tab.active) {
                tab.forceActiveFocus(reason)
                return true
            }
        }
        return panel.focusFirst(reason)
    }

    function _selectTab(index) {
        const tab = tabRepeater.itemAt(index)
        if (!tab)
            return
        RdPanels.open(tab.modelData.key)
        tab.forceActiveFocus(Qt.TabFocusReason)
    }

    Widgets.RdPanel {
        id: panel

        anchors.fill: parent
        arrowNavigation: true

        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(root.rdPalette.rdBgB1Transparent, 1.0)

        // tab header: the top of the panel, rounded like it at the top, square at the bottom
        Rectangle {
            id: header

            width: parent.width
            height: VLCStyle.rd_sidePanelTabHeight
            radius: panel.radius
            color: root.rdPalette.rdBgB2

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Row {
                id: tabs

                readonly property real sidePadding: VLCStyle.dp(6, VLCStyle.scale)

                x: sidePadding
                width: parent.width - 2 * sidePadding
                height: parent.height
                spacing: VLCStyle.dp(1, VLCStyle.scale)

                Repeater {
                    id: tabRepeater

                    model: [
                        { key: "video", label: qsTr("Video"), icon: "video" },
                        { key: "audio", label: qsTr("Audio"), icon: "audio" },
                        { key: "subtitles", label: qsTr("Subtitles"), icon: "subtitles" }
                    ]

                    delegate: T.AbstractButton {
                        id: tabButton

                        // the pointing hand over the clickable controls
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        required property var modelData
                        required property int index
                        readonly property bool active: root.tab === modelData.key

                        width: (tabs.width - (tabRepeater.count - 1) * tabs.spacing) / Math.max(1, tabRepeater.count)
                        height: tabs.height

                        focusPolicy: Qt.StrongFocus
                        Accessible.role: Accessible.PageTab
                        Accessible.name: modelData.label
                        Accessible.checkable: true
                        Accessible.checked: active

                        onClicked: RdPanels.open(modelData.key)

                        Navigation.leftAction: () => root._selectTab(tabButton.index - 1)
                        Navigation.rightAction: () => root._selectTab(tabButton.index + 1)
                        Navigation.upAction: () => { }
                        Navigation.downAction: () => {
                            const last = tabRepeater.itemAt(tabRepeater.count - 1)
                            const next = last ? last.nextItemInFocusChain(true) : null
                            if (next && panel.containsItem(next))
                                next.forceActiveFocus(Qt.TabFocusReason)
                        }

                        Keys.priority: Keys.AfterItem
                        Keys.onPressed: (event) => Navigation.defaultKeyAction(event)

                        contentItem: Item {
                            Row {
                                id: tabRow

                                x: (parent.width - width) / 2
                                y: VLCStyle.dp(14, VLCStyle.scale)
                                spacing: VLCStyle.dp(8, VLCStyle.scale)

                                Widgets.RdIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: tabButton.active ? tabButton.modelData.icon + "_two-tone-yes" : tabButton.modelData.icon
                                    size: VLCStyle.dp(20, VLCStyle.scale)
                                    // Figma: FG/A3 strokes when active, FG/A4 when not (hover: FG/A3)
                                    color: (tabButton.active || tabButton.hovered) ? root.rdPalette.rdFgA3 : root.rdPalette.rdFgA4
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tabButton.modelData.label
                                    // Figma: Inter 400 12, FG/A2 when active, FG/A3 when not
                                    font.family: VLCStyle.rd_fontFamily
                                    font.pixelSize: VLCStyle.rd_fontSize_toggle
                                    color: (tabButton.active || tabButton.hovered) ? root.rdPalette.rdFgA2 : root.rdPalette.rdFgA3
                                }
                            }

                            Rectangle {
                                visible: tabButton.active
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - VLCStyle.dp(16, VLCStyle.scale)
                                height: VLCStyle.dp(2, VLCStyle.scale)
                                color: root.rdPalette.rdAccentMain
                            }

                            Rectangle {
                                visible: tabButton.visualFocus
                                anchors.fill: parent
                                anchors.margins: VLCStyle.dp(2, VLCStyle.scale)
                                color: "transparent"
                                radius: VLCStyle.rd_radius_small
                                border.width: VLCStyle.dp(1, VLCStyle.scale)
                                border.color: root.rdPalette.rdFgA3
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: flick

            anchors.top: parent.top
            anchors.topMargin: root._headerHeight
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: footer.top

            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: content.height

            ColumnLayout {
                id: content

                width: flick.width
                height: Math.max(implicitHeight, flick.height)
                spacing: 0

                SectionLabel {
                    text: qsTr("Embedded Tracks")
                }

                // Figma: the list frame is 138.5 tall whatever the track count (with the 20 px
                // below the rows), so the next section label stays in place
                TrackListFrame {
                    model: root.tab === "audio" ? Player.audioTracks
                         : root.tab === "video" ? Player.videoTracks
                         : Player.subtitleTracks
                    // subtitles: the files added next to the video are listed under External Tracks
                    filter: root.tab === "subtitles" ? "embedded" : "all"
                }

                // subtitles: external tracks; the pencil and + both open the Add Subtitles dialog
                // for the playing video (Figma wires both to it; W6.5, P3-05, F-09; it closes this
                // popup as it opens). Figma has no divider above it on this tab, only on the Audio tab.
                SectionLabel {
                    visible: root.tab === "subtitles"
                    text: qsTr("External Tracks")
                    actions: [
                        { icon: "edit", description: qsTr("Edit subtitle files") },
                        { icon: "add", description: qsTr("Add subtitle file") }
                    ]
                    onActionTriggered: (index) => AddSubtitles.open()
                }

                // Figma "Frame 67": the subtitle files, one row each with the file name (no "None":
                // the one above Embedded Tracks turns every subtitle off)
                TrackListFrame {
                    visible: root.tab === "subtitles"
                    model: Player.subtitleTracks
                    filter: "external"
                    showNone: false
                }

                // audio: output device (refresh re-reads the device list)
                Widgets.RdMenuDivider {
                    visible: root.tab === "audio"
                    Layout.fillWidth: true
                }

                SectionLabel {
                    visible: root.tab === "audio"
                    text: qsTr("Output Device")
                    actions: [ { icon: "refresh", description: qsTr("Refresh output devices") } ]
                    onActionTriggered: (index) => Player.audioDevices.refresh()
                }

                TrackListFrame {
                    visible: root.tab === "audio"
                    tracks: false
                    model: Player.audioDevices
                }

                // the sections stay at the top of the Figma height
                Item {
                    Layout.fillHeight: true
                }
            }
        }

        // Figma "Frame 65": 72 px footer pinned at the bottom, the button 20 px from its edges
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: VLCStyle.dp(72, VLCStyle.scale)

            Widgets.RdButton {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: VLCStyle.dp(20, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter

                // Figma button 500:3075 hides its icon: text only
                style: Widgets.RdButton.Style.Bar
                text: qsTr("Show Preferences")

                // opens the settings sidebar on the matching tab (Figma F-07)
                onClicked: RdPanels.open(root.tab === "video" ? "videoSettings"
                                         : root.tab === "audio" ? "audioSettings" : "subtitleSettings")
            }
        }
    }

    // section label row (Figma "Frame 60": 60 px, padding 0,28, FG/A3 14 px) with optional icon
    // actions on the right (Figma "Frame 61": 24 px icons 20 apart, 28 px from the right edge)
    component SectionLabel: Item {
        id: section

        property alias text: label.text
        // [{ icon, description }]; icon is a Figma icon name (Widgets.RdIcon)
        property var actions: []
        signal actionTriggered(int index)

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(60, VLCStyle.scale)

        Text {
            id: label

            anchors.left: parent.left
            anchors.leftMargin: VLCStyle.dp(28, VLCStyle.scale)
            anchors.verticalCenter: parent.verticalCenter
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        Row {
            // the 30 px buttons center their 24 px icons: 3 px of each button lie outside the icon
            readonly property real _iconInset: (VLCStyle.rd_iconButtonWidth - VLCStyle.rd_iconSize) / 2

            anchors.right: parent.right
            anchors.rightMargin: VLCStyle.dp(28, VLCStyle.scale) - _iconInset
            anchors.verticalCenter: parent.verticalCenter
            spacing: VLCStyle.dp(20, VLCStyle.scale) - 2 * _iconInset

            Repeater {
                model: section.actions

                delegate: Widgets.IconToolButton {
                    required property var modelData
                    required property int index

                    width: VLCStyle.rd_iconButtonWidth
                    height: VLCStyle.rd_iconButtonHeight
                    font.pixelSize: VLCStyle.rd_iconSize
                    text: VLCIcons.add
                    rdIcon: modelData.icon
                    description: modelData.description
                    onClicked: section.actionTriggered(index)
                }
            }
        }
    }

    // one selectable row: accent check on the left, label FG/2 (selected or hovered) or FG/A1, 32 px
    component TrackRow: T.AbstractButton {
        id: row

        // the pointing hand over the clickable controls
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        property bool selected: false
        property string label: ""

        Layout.fillWidth: true
        implicitHeight: VLCStyle.rd_rowHeight

        Accessible.role: Accessible.RadioButton
        Accessible.name: label
        Accessible.checked: selected

        onActiveFocusChanged: {
            if (activeFocus)
                root._ensureVisible(row)
        }

        // hover BG/A2 (Figma); pressed and keyboard focus are not in Figma: pressed keeps the
        // hover fill, keyboard focus adds the FG/A3 ring of the other redesign controls
        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: (row.hovered || row.down) ? VLCStyle.palette.rdBgA2 : "transparent"
            border.width: row.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Item {
            Widgets.RdIcon {
                x: VLCStyle.dp(4, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter
                visible: row.selected
                name: "check_state-active"
            }

            // Figma: 32 px check cell + 10 px gap
            Text {
                x: VLCStyle.dp(42, VLCStyle.scale)
                width: parent.width - x
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: row.label
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                // the selected row keeps FG/A1 (Figma): only the accent check marks it
                color: row.hovered ? VLCStyle.palette.rdFg2 : VLCStyle.palette.rdFgA1
            }
        }
    }

    // Figma "Frame 53" (tracks) / "Frame 64" (devices): a list frame 138.5 px tall whatever the
    // number of rows; more rows (a film with 16 subtitle tracks) scroll inside it, so the next
    // section and Show Preferences keep their Figma place
    component TrackListFrame: Flickable {
        id: frame

        property alias model: frameList.model
        property alias tracks: frameList.tracks
        property alias filter: frameList.filter
        property alias showNone: frameList.showNone

        Layout.fillWidth: true
        Layout.preferredHeight: VLCStyle.dp(138.5, VLCStyle.scale)

        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        // the 20 px below the last row stay part of the list
        contentHeight: frameList.implicitHeight + VLCStyle.dp(20, VLCStyle.scale)

        // Figma draws no scroll bar: it shows while the list scrolls or the pointer is on it
        T.ScrollBar.vertical: Widgets.ScrollBarExt {
            id: frameScrollBar

            opacity: (frameScrollBar.active || frameScrollBar.interacting) ? 1 : 0
        }

        TrackList {
            id: frameList

            x: VLCStyle.dp(20, VLCStyle.scale)
            width: frame.width - 2 * VLCStyle.dp(20, VLCStyle.scale)
        }
    }

    // track or device list, 12 px between rows, 20 px below the last row (video 4:44).
    // Track lists start with "None" (video 4:35-4:48), which is checked when no track is selected
    // and unselects the current one; VLC names tracks "Track 1 - [English]", the design shows
    // "Track 1 - English".
    component TrackList: ColumnLayout {
        id: list

        property var model
        property bool tracks: true
        // which tracks show: "all", "embedded" or "external" (TrackListModel's "external" role);
        // the hidden rows still count for "None", so it turns off a track of either list
        property string filter: "all"
        property bool showNone: true

        // bumped when a row is created, removed or (un)selected: the rows can be created after
        // the count changed (asynchronous creation of a prewarmed panel), so a binding over
        // rows.itemAt() alone could miss them and keep "None" checked next to a track
        property int _selectionRevision: 0

        readonly property bool _anySelected: {
            if (list._selectionRevision < 0)
                return false
            for (let i = 0; i < rows.count; ++i) {
                const item = rows.itemAt(i)
                if (item && item.selected)
                    return true
            }
            return false
        }

        Layout.fillWidth: true
        Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)
        Layout.bottomMargin: VLCStyle.dp(20, VLCStyle.scale)
        spacing: VLCStyle.dp(12, VLCStyle.scale)

        TrackRow {
            visible: list.tracks && list.showNone
            label: qsTr("None")
            selected: !list._anySelected

            onClicked: {
                for (let i = 0; i < rows.count; ++i) {
                    const item = rows.itemAt(i)
                    if (item && item.selected)
                        item.model.checked = false
                }
            }
        }

        Repeater {
            id: rows

            model: list.model

            onItemAdded: list._selectionRevision += 1
            onItemRemoved: list._selectionRevision += 1

            delegate: TrackRow {
                required property var model
                required property int index

                visible: list.filter === "all" || (!!model.external === (list.filter === "external"))
                selected: !!model.checked
                onSelectedChanged: list._selectionRevision += 1
                label: list.tracks ? String(model.display).replace(/ - \[(.*)\]$/, " - $1") : model.display

                onClicked: model.checked = true
            }
        }
    }
}
