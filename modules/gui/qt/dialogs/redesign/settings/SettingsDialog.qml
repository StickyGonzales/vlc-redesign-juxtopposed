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
// redesign: the Settings dialog (video 16:03-18:55, Figma "Settings - *" frames 1048x865).
// A modal panel centered over the window (BG/B1 95%, radius 14, "bg blur + shadow"):
// - header 50 px (BG/B2): search field 200x34, the category's page title (Inter 16 FG/A1)
//   aligned with the page content, close button (Icon Wrapper 32x32);
// - left column 216 px: grouped categories App / Media / System in a BG/A3 95% card
//   (padding 6, 8 px apart), and "All VLC Settings", which opens VLC's complete preferences;
// - right: the category's page, scrolling under the fixed header (padding 20,24,100,24).
// Pages are loaded when first shown (only the open category's page on opening), or all at once
// on the first search, so the search can hide the categories and rows that do not match.
// Motion: opening, closing and switching categories are instant, as the Figma prototype wires
// them ("open overlay" / "swap overlay", instant); the fades seen in the video at 17:40 and
// 18:05 are cuts and dissolves of the edit (redesign/VIDEO_INDEX.md, Decisions (Claude)).
// Closing gives the keyboard focus back to where it was before.
// DialogsProvider.settingsDialog(category) opens it through MainInterface.qml.
import QtQuick
import QtQuick.Templates as T
import QtQuick.Window

import VLC.MainInterface
import VLC.Style
import VLC.Player
import VLC.Widgets as Widgets

Item {
    id: root

    readonly property var groups: [
        { key: "app", label: qsTr("App") },
        { key: "media", label: qsTr("Media") },
        { key: "system", label: qsTr("System") }
    ]

    // labels and titles: video 17:36-18:27 (Decision 11 for "Extensions & Scripts"); icons:
    // Figma "setting category" instances
    readonly property var categories: [
        { key: "general", group: "app", label: qsTr("General"), title: qsTr("Global Settings"),
          icon: "preferences", page: generalPage },
        { key: "interface", group: "app", label: qsTr("Interface"), title: qsTr("Interface Settings"),
          icon: "interface", page: interfacePage },
        { key: "privacy", group: "app", label: qsTr("Privacy"), title: qsTr("Privacy Settings"),
          icon: "privacy", page: privacyPage },
        { key: "controls", group: "app", label: qsTr("Controls"), title: qsTr("Mouse, Keyboard & Remote Controls"),
          icon: "hotkeys", page: controlsPage },
        { key: "playback", group: "media", label: qsTr("Playback"), title: qsTr("Playback Preferences"),
          icon: "playback", page: playbackPage },
        { key: "video", group: "media", label: qsTr("Video"), title: qsTr("Video Defaults"),
          icon: "video", page: videoPage },
        { key: "audio", group: "media", label: qsTr("Audio"), title: qsTr("Audio Defaults"),
          icon: "audio", page: audioPage },
        { key: "subtitles", group: "media", label: qsTr("Subtitles"), title: qsTr("Subtitle Defaults"),
          icon: "subtitles", page: subtitlesPage },
        { key: "library", group: "media", label: qsTr("Library"), title: qsTr("Playlists, Folders & Files"),
          icon: "folder", page: libraryPage },
        { key: "network", group: "system", label: qsTr("Network"), title: qsTr("Network Connections & Security"),
          icon: "streaming", page: networkPage },
        { key: "performance", group: "system", label: qsTr("Performance"), title: qsTr("Performance Settings"),
          icon: "preferences", page: performancePage },
        { key: "recording", group: "system", label: qsTr("Recording"), title: qsTr("Recording, Casting & Streaming Out"),
          icon: "record", page: recordingPage },
        { key: "extensions", group: "system", label: qsTr("Extensions"), title: qsTr("Extensions & Scripts"),
          icon: "plugins", page: extensionsPage }
    ]

    // set by open(); empty before, so no page is built for a category nobody opened
    property string currentKey: ""

    readonly property bool opened: popup.opened
    // the search applies once typing pauses (every page and row is filtered on each change);
    // clearing it applies at once
    property string searchText: ""
    readonly property bool filtering: _words.length > 0
    // once searched, all pages stay loaded: clearing and typing again must not destroy and
    // rebuild them on every keystroke
    property bool _searched: false
    onFilteringChanged: {
        if (filtering)
            _searched = true
    }
    readonly property var _words: searchText.toLowerCase().split(/\s+/).filter((w) => w !== "")

    readonly property int _currentIndex: _indexOf(currentKey)
    readonly property bool _anyMatch: {
        if (!filtering)
            return true
        for (let i = 0; i < pageViews.count; ++i) {
            const view = pageViews.itemAt(i)
            if (view && view.hasMatches)
                return true
        }
        return false
    }

    // the item that had the keyboard focus before opening, given back on closing
    property Item _focusBeforeOpen: null

    // opens the dialog on a category ("general" when empty or unknown)
    function open(category) {
        const index = _indexOf(category)
        currentKey = categories[index >= 0 ? index : 0].key
        searchField.clear()
        // values may have changed elsewhere (VLC's preferences, the sidebar, hotkeys)
        RdEffects.refresh()
        const view = pageViews.itemAt(_currentIndex)
        if (view)
            view.contentY = 0
        popup.open()
    }

    function close() {
        popup.close()
    }

    // Ctrl+P and the menus toggle the dialog like they toggled VLC's preferences
    function toggle(category) {
        // close only when the user is in the dialog's window; from another window (the main
        // window is raised first) it comes to the front instead
        const window = root.Window.window
        if (popup.opened && !category && window && window.active)
            popup.close()
        else if (popup.opened && !category)
            return
        else
            open(category)
    }

    // closes the dialog, then runs `action` (opening another dialog: VLC's preferences, the
    // keyboard shortcuts editor...), so two windows never edit the same settings at once
    function openExternal(action) {
        popup.close()
        action()
    }

    function openLegacyPreferences() {
        openExternal(() => DialogsProvider.legacyPrefsDialog())
    }

    // true when every word of the search appears in one of the texts
    function textMatches(texts) {
        if (_words.length === 0)
            return true
        const haystack = texts.join(" ").toLowerCase()
        return _words.every((w) => haystack.includes(w))
    }

    function _indexOf(key) {
        if (!key)
            return -1
        for (let i = 0; i < categories.length; ++i) {
            if (categories[i].key === key)
                return i
        }
        return -1
    }

    // a search that hides the current category moves to the first one that matches
    function _ensureCurrentMatches() {
        if (!filtering)
            return
        const current = pageViews.itemAt(_currentIndex)
        if (current && current.hasMatches)
            return
        for (let i = 0; i < pageViews.count; ++i) {
            const view = pageViews.itemAt(i)
            if (view && view.hasMatches) {
                currentKey = categories[i].key
                return
            }
        }
    }

    // the category column: each group's header followed by its categories
    readonly property var _navEntries: {
        const entries = []
        for (const group of groups) {
            entries.push({ group: group.key, label: group.label, category: -1 })
            for (let i = 0; i < categories.length; ++i) {
                if (categories[i].group === group.key)
                    entries.push({ group: group.key, label: categories[i].label, category: i })
            }
        }
        return entries
    }

    // false for a category the search hides
    function _categoryShown(index) {
        if (!filtering)
            return true
        const view = pageViews.count > index ? pageViews.itemAt(index) : null
        return !!view && view.hasMatches
    }

    function _groupShown(group) {
        for (let i = 0; i < categories.length; ++i) {
            if (categories[i].group === group && _categoryShown(i))
                return true
        }
        return false
    }

    // Up / Down in the category column select the previous / next shown category
    function _moveCategory(from, step) {
        for (let i = from + step; i >= 0 && i < categories.length; i += step) {
            if (!_categoryShown(i))
                continue
            currentKey = categories[i].key
            for (let e = 0; e < navEntries.count; ++e) {
                const entry = navEntries.itemAt(e)
                if (entry && entry.modelData.category === i)
                    entry.focusButton()
            }
            return
        }
    }

    // keyboard focus moving through a page scrolls the page to the focused control
    function _revealFocusItem() {
        const window = root.Window.window
        if (!popup.opened || !window || !window.activeFocusItem)
            return
        const view = pageViews.itemAt(_currentIndex)
        if (!view)
            return
        const item = window.activeFocusItem
        let p = item
        while (p && p !== view.contentItem)
            p = p.parent
        if (!p)
            return
        const margin = VLCStyle.dp(20)
        const top = item.mapToItem(view.contentItem, 0, 0).y
        const bottom = top + item.height
        if (top - margin < view.contentY)
            view.contentY = Math.max(0, top - margin)
        else if (bottom + margin > view.contentY + view.height)
            view.contentY = Math.max(0, Math.min(view.contentHeight - view.height, bottom + margin - view.height))
    }

    onSearchTextChanged: Qt.callLater(_ensureCurrentMatches)

    Timer {
        id: searchDelay

        interval: VLCStyle.duration_long
        onTriggered: root.searchText = searchField.text
    }

    Connections {
        target: searchField

        function onTextChanged() {
            if (searchField.text.trim() === "") {
                searchDelay.stop()
                root.searchText = searchField.text
            } else {
                searchDelay.restart()
            }
        }
    }

    Connections {
        target: root.Window.window
        enabled: popup.opened

        function onActiveFocusItemChanged() {
            root._revealFocusItem()
        }
    }

    Component { id: generalPage; SettingsGeneralPage { } }
    Component { id: interfacePage; SettingsInterfacePage { } }
    Component { id: privacyPage; SettingsPrivacyPage { } }
    Component { id: controlsPage; SettingsControlsPage { } }
    Component { id: playbackPage; SettingsPlaybackPage { } }
    Component { id: videoPage; SettingsVideoPage { } }
    Component { id: audioPage; SettingsAudioPage { } }
    Component { id: subtitlesPage; SettingsSubtitlesPage { } }
    Component { id: libraryPage; SettingsLibraryPage { } }
    Component { id: networkPage; SettingsNetworkPage { } }
    Component { id: performancePage; SettingsPerformancePage { } }
    Component { id: recordingPage; SettingsRecordingPage { } }
    Component { id: extensionsPage; SettingsExtensionsPage { } }

    T.Popup {
        id: popup

        parent: root
        anchors.centerIn: parent

        width: Math.min(VLCStyle.rd_settingsDialogWidth, root.width - 2 * VLCStyle.margin_normal)
        height: Math.min(VLCStyle.rd_settingsDialogHeight, root.height - 2 * VLCStyle.margin_normal)
        padding: 0

        modal: true
        dim: true
        focus: true
        // a click outside closes the dialog (every setting applies at once), except while a
        // page holds a typed value not applied yet (a field's `dirty`: a number box applies on
        // Enter, so a stray click would lose it); search fields hold no setting (Escape and X
        // still close; same rule as Open Network Stream)
        closePolicy: _typingValue ? T.Popup.CloseOnEscape
                                  : (T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside)

        readonly property bool _typingValue: {
            const window = root.Window.window
            for (let p = window ? window.activeFocusItem : null; p && p !== pagesArea; p = p.parent) {
                if (p.dirty === true)
                    return true
            }
            return false
        }

        // no dim behind the dialog (Decision 41: the video and Figma show none); the transparent
        // overlay still takes the clicks outside the dialog
        T.Overlay.modal: Item { }

        // while open, keys go to the dialog instead of VLC's hotkeys (RdPanels.modalCount)
        property bool _holdsModal: false

        Component.onDestruction: {
            if (_holdsModal)
                RdPanels.releaseModal()
        }

        onAboutToShow: {
            if (!_holdsModal) {
                RdPanels.acquireModal()
                _holdsModal = true
            }
            // remember the focused item, unless it is inside another popup (a menu that opened us)
            const window = root.Window.window
            let item = window ? window.activeFocusItem : null
            for (let p = item; p; p = p.parent) {
                if (p === T.Overlay.overlay) {
                    item = null
                    break
                }
            }
            root._focusBeforeOpen = item
            searchField.forceActiveFocus(Qt.PopupFocusReason)
        }
        onOpened: {
            if (!searchField.activeFocus)
                searchField.forceActiveFocus(Qt.PopupFocusReason)
        }
        // count and focus change hands when hiding starts, so no key is lost in a transition
        onAboutToHide: {
            if (_holdsModal) {
                RdPanels.releaseModal()
                _holdsModal = false
            }
            const item = root._focusBeforeOpen
            if (item && item.visible)
                item.forceActiveFocus(Qt.PopupFocusReason)
        }
        onClosed: {
            const item = root._focusBeforeOpen
            root._focusBeforeOpen = null
            const window = root.Window.window
            if (item && item.visible && (!window || window.activeFocusItem !== item))
                item.forceActiveFocus(Qt.PopupFocusReason)
        }

        background: Rectangle {
            radius: VLCStyle.rd_radius_large
            // opaque: over the native video Figma's 95 % (meant with a background blur) shows a
            // sharp ghost of the video (same rule as the side panels)
            color: Qt.alpha(VLCStyle.palette.rdBgB1Transparent, 1.0)

            Widgets.RdShadow { }
        }

        contentItem: Item {
            // header (Figma "Frame 120")
            Rectangle {
                id: header

                width: parent.width
                height: VLCStyle.rd_settingsHeaderHeight
                topLeftRadius: VLCStyle.rd_radius_large
                topRightRadius: VLCStyle.rd_radius_large
                color: VLCStyle.palette.rdBgB2

                SettingsSearchField {
                    id: searchField

                    x: VLCStyle.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, VLCStyle.rd_settingsNavWidth - 2 * VLCStyle.dp(8))
                }

                Text {
                    x: VLCStyle.rd_settingsNavWidth + VLCStyle.dp(24)
                    anchors.verticalCenter: parent.verticalCenter
                    width: closeButton.x - x - VLCStyle.dp(10)
                    text: root._currentIndex >= 0 ? root.categories[root._currentIndex].title : ""
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_header
                    color: VLCStyle.palette.rdFgA1
                    Accessible.role: Accessible.Heading
                }

                // Figma "Icon Wrapper" 32x32, padding 4, radius 4, hover #FFFFFF 6%
                T.AbstractButton {
                    id: closeButton

                    // the pointing hand over the clickable controls
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(14)
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: VLCStyle.dp(32)
                    implicitHeight: VLCStyle.dp(32)
                    padding: VLCStyle.dp(4)

                    focusPolicy: Qt.StrongFocus
                    hoverEnabled: true

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Close")

                    Keys.onReturnPressed: closeButton.clicked()
                    Keys.onEnterPressed: closeButton.clicked()

                    onClicked: popup.close()

                    background: Rectangle {
                        radius: VLCStyle.rd_radius_small
                        color: closeButton.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent"
                        border.width: closeButton.visualFocus ? VLCStyle.dp(1) : 0
                        border.color: VLCStyle.palette.rdFgA3
                    }

                    contentItem: Widgets.RdIcon {
                        name: "close"
                        color: VLCStyle.palette.rdFgA2
                    }
                }
            }

            // category column (Figma "Frame 3" padding 8 around "Frame 110")
            Rectangle {
                id: nav

                x: VLCStyle.dp(8)
                y: header.height + VLCStyle.dp(8)
                width: VLCStyle.rd_settingsNavWidth - 2 * VLCStyle.dp(8)
                height: parent.height - y - VLCStyle.dp(8)
                radius: VLCStyle.rd_radius_normal
                color: VLCStyle.palette.rdBgA3Transparent

                Flickable {
                    id: navView

                    anchors.fill: parent
                    anchors.bottomMargin: allSettingsButton.height + 2 * VLCStyle.dp(6)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentWidth: width
                    contentHeight: navColumn.height + 2 * VLCStyle.dp(6)

                    Column {
                        id: navColumn

                        x: VLCStyle.dp(6)
                        y: VLCStyle.dp(6)
                        width: navView.width - 2 * VLCStyle.dp(6)
                        spacing: VLCStyle.dp(8)

                        Repeater {
                            id: navEntries

                            model: root._navEntries

                            delegate: Item {
                                id: navEntry

                                required property var modelData

                                readonly property bool isHeader: modelData.category < 0

                                function focusButton() {
                                    categoryButton.forceActiveFocus(Qt.TabFocusReason)
                                }

                                visible: isHeader ? root._groupShown(modelData.group)
                                                  : root._categoryShown(modelData.category)
                                width: navColumn.width
                                height: isHeader ? VLCStyle.dp(33) : VLCStyle.rd_settingsCategoryHeight

                                // group header (Figma "Frame 260": 33 px, padding 8,10, Inter 14 FG/A3)
                                Text {
                                    visible: navEntry.isHeader
                                    anchors.fill: parent
                                    leftPadding: VLCStyle.dp(10)
                                    rightPadding: VLCStyle.dp(10)
                                    verticalAlignment: Text.AlignVCenter
                                    text: navEntry.modelData.label
                                    elide: Text.ElideRight
                                    font.family: VLCStyle.rd_fontFamily
                                    font.pixelSize: VLCStyle.rd_fontSize_label
                                    color: VLCStyle.palette.rdFgA3
                                    Accessible.role: Accessible.Heading
                                }

                                SettingsCategoryButton {
                                    id: categoryButton

                                    readonly property var category: navEntry.isHeader ? null
                                                                    : root.categories[navEntry.modelData.category]

                                    visible: !navEntry.isHeader
                                    anchors.fill: parent
                                    text: navEntry.modelData.label
                                    iconName: category ? category.icon : ""
                                    selected: !!category && root.currentKey === category.key

                                    onClicked: {
                                        if (category)
                                            root.currentKey = category.key
                                    }

                                    Keys.onUpPressed: root._moveCategory(navEntry.modelData.category, -1)
                                    Keys.onDownPressed: root._moveCategory(navEntry.modelData.category, 1)
                                }
                            }
                        }
                    }
                }

                // not in the design: VLC's complete preferences, so no option of VLC becomes
                // unreachable (the redesigned pages hold a curated selection)
                SettingsCategoryButton {
                    id: allSettingsButton

                    x: VLCStyle.dp(6)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: VLCStyle.dp(6)
                    width: parent.width - 2 * VLCStyle.dp(6)
                    text: qsTr("All %1 Settings").arg(Brand.shortName)
                    iconName: "wrench"

                    onClicked: root.openLegacyPreferences()
                }
            }

            // pages (Figma "Frame 123": padding 20,24,100,24)
            Item {
                id: pagesArea

                x: VLCStyle.rd_settingsNavWidth
                y: header.height
                width: parent.width - x
                height: parent.height - y

                Repeater {
                    id: pageViews

                    model: root.categories

                    delegate: Flickable {
                        id: pageView

                        required property var modelData
                        required property int index

                        readonly property bool current: root.currentKey === modelData.key
                        readonly property bool titleMatches: root.filtering
                                                             && root.textMatches([modelData.label, modelData.title])
                        readonly property Item page: pageLoader.item
                        // shown in the category column while searching
                        readonly property bool hasMatches: !root.filtering || titleMatches
                                                           || (!!page && page.matchCount > 0)
                        property bool visited: false

                        anchors.fill: parent

                        visible: current && root._anyMatch

                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        contentWidth: width
                        contentHeight: pageLoader.height + VLCStyle.dp(20) + VLCStyle.dp(100)

                        // the popup is outside the window's color context: give the scroll bar the palette
                        T.ScrollBar.vertical: Widgets.ScrollBarExt {
                            colorContext.palette: VLCStyle.palette
                        }

                        onCurrentChanged: {
                            if (current) {
                                visited = true
                                contentY = 0
                            }
                        }

                        // the pages count their matching rows after the search text reached
                        // them: a current page that turns out to have none moves the dialog to
                        // the first category that has some (else its pane would stay empty)
                        onHasMatchesChanged: {
                            if (current && !hasMatches)
                                Qt.callLater(root._ensureCurrentMatches)
                        }

                        Loader {
                            id: pageLoader

                            x: VLCStyle.dp(24)
                            y: VLCStyle.dp(20)
                            width: pageView.width - 2 * VLCStyle.dp(24)
                            height: item ? item.implicitHeight : 0

                            active: pageView.current || pageView.visited || root._searched
                            sourceComponent: pageView.modelData.page

                            onLoaded: item.settingsDialog = root
                        }

                        // a matching category title shows its whole page
                        Binding {
                            target: pageLoader.item
                            property: "filterText"
                            value: pageView.titleMatches ? "" : root.searchText
                            when: pageLoader.status === Loader.Ready
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 2 * VLCStyle.dp(24)
                    visible: !root._anyMatch
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("No settings match \"%1\"").arg(root.searchText.trim())
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }
            }
        }
    }
}
