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

// redesign: cascading menu in the Figma menu style (menu.png, right-click menu.png, Profiles.png):
// panels of 48 px option rows with 1 px Divider/Dim lines, BG/A3 95%, radius 10, padding 4. A
// submenu opens 11 px to the right of its row, its first row level with that row (Profiles.png),
// on hover after a short delay, on click, or with the Right key.
// The rows come from a RdMenuModel (VLC's own menus as data). One popup covers the window, so
// the levels never close each other; a click outside the panels closes the menu.
// Motion (video 5:08, 60 fps): the menu fades in over about 7 frames; submenus appear at once
// (19:30) and menus close at once, like the Figma prototype's instant overlays.
import QtQuick
import QtQuick.Window
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    // RdMenuModel of the first level
    property QtObject model: null
    property real rootWidth: VLCStyle.rd_menuWidth
    property bool withShadow: true

    // a right press outside the panels closed the menu (a context menu opens again there)
    signal rightPressedOutside()

    readonly property int _maxDepth: 5
    readonly property real _margin: VLCStyle.margin_xsmall
    readonly property real _padding: VLCStyle.rd_menuPadding

    // the open levels: _models[i] is the model of level i, _anchors[i] where its panel opens,
    // _openRows[i] the row of level i whose submenu is level i + 1
    property var _models: []
    property var _anchors: []
    property var _openRows: []
    property bool _keyboard: false
    // the item that had the focus before the menu opened gets it back when it closes
    property Item _opener: null

    // the last hovered row, applied when the hover delay ends
    property int _pendingLevel: -1
    property int _pendingRow: -1

    parent: T.Overlay.overlay
    x: 0
    y: 0
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    padding: 0
    modal: false
    dim: false
    focus: true
    closePolicy: T.Popup.NoAutoClose

    // opens the menu with its top left corner at (px, py) in `item` coordinates, kept inside the
    // window; `keyboard` puts the focus on the first row
    function popupAt(item, px, py, keyboard) {
        if (!root.model || !root.parent || !item)
            return

        const p = item.mapToItem(root.parent, px, py)

        if (!root.visible)
            root._opener = item.Window.window ? item.Window.window.activeFocusItem : null

        hoverTimer.stop()
        root._pendingLevel = -1
        root.model.build()

        root._models = [root.model]
        root._anchors = [{ x: p.x, y: p.y }]
        root._openRows = []
        root._keyboard = !!keyboard
        root.open()
    }

    function _reset() {
        if (root.visible)
            return
        hoverTimer.stop()
        root._models = []
        root._anchors = []
        root._openRows = []
    }

    function _rowItem(level, row) {
        const panel = levels.itemAt(level)
        return panel ? panel.rowAt(row) : null
    }

    function _focusRow(level, row, direction) {
        const panel = levels.itemAt(level)
        if (panel)
            panel.focusRow(row, direction)
    }

    function _closeLevels(count) {
        if (root._models.length <= count)
            return
        root._models = root._models.slice(0, count)
        root._anchors = root._anchors.slice(0, count)
        root._openRows = root._openRows.slice(0, Math.max(0, count - 1))
    }

    function _openSubmenu(level, row, keyboard) {
        if (level + 1 >= root._maxDepth || level >= root._models.length)
            return

        const model = root._models[level]
        const rowItem = root._rowItem(level, row)
        const panel = levels.itemAt(level)
        if (!model || !rowItem || !panel)
            return

        const submenu = model.submenu(row)
        if (!submenu)
            return

        if (root._models.length > level + 1 && root._openRows[level] === row) {
            root._closeLevels(level + 2)
        } else {
            submenu.aboutToShow()

            const p = rowItem.mapToItem(root.contentItem, 0, 0)
            const models = root._models.slice(0, level + 1)
            const anchors = root._anchors.slice(0, level + 1)
            const openRows = root._openRows.slice(0, level)
            models.push(submenu)
            anchors.push({ right: panel.x + panel.width + VLCStyle.rd_submenuGap,
                           left: panel.x - VLCStyle.rd_submenuGap,
                           y: p.y - root._padding })
            openRows.push(row)
            root._models = models
            root._anchors = anchors
            root._openRows = openRows
        }

        if (keyboard)
            Qt.callLater(root._focusRow, level + 1, 0, 1)
    }

    // Left / Escape: back to the parent level, or close the first level
    function _back(level) {
        if (level <= 0) {
            root.close()
            return
        }
        const row = root._openRows[level - 1]
        root._closeLevels(level)
        root._focusRow(level - 1, row, 1)
    }

    function _activate(level, row, keyboard) {
        const rowItem = root._rowItem(level, row)
        if (!rowItem || rowItem.separator || !rowItem.actionEnabled)
            return

        if (rowItem.hasSubmenu) {
            root._openSubmenu(level, row, keyboard)
            return
        }

        const model = root._models[level]
        root.close()
        // after the menu is gone: the entry may open a modal dialog
        Qt.callLater(() => model.trigger(row))
    }

    function _hover(level, row) {
        root._pendingLevel = level
        root._pendingRow = row
        hoverTimer.restart()
    }

    function _applyHover() {
        const level = root._pendingLevel
        const row = root._pendingRow
        if (level < 0 || level >= root._models.length)
            return

        const rowItem = root._rowItem(level, row)
        if (rowItem && rowItem.hasSubmenu && rowItem.actionEnabled)
            root._openSubmenu(level, row, false)
        else
            root._closeLevels(level + 1)
    }

    // while open, keys go to the menu instead of VLC's hotkeys (RdPanels.modalCount)
    property bool _holdsModal: false

    onAboutToShow: {
        if (!root._holdsModal) {
            RdPanels.acquireModal()
            root._holdsModal = true
        }
        // keys reach the menu from the first frame of its fade in
        menuScope.forceActiveFocus()
    }

    onAboutToHide: {
        if (root._holdsModal) {
            RdPanels.releaseModal()
            root._holdsModal = false
        }
    }

    Component.onDestruction: {
        if (root._holdsModal)
            RdPanels.releaseModal()
    }

    // a keyboard-opened menu highlights its first row, unless a key already moved the focus
    // during the fade in
    onOpened: {
        if (root._keyboard) {
            if (menuScope.activeFocus)
                root._focusRow(0, 0, 1)
        } else if (!root.activeFocus && !menuScope.activeFocus) {
            menuScope.forceActiveFocus()
        }
    }

    // the panels go away once the click that closed the menu is handled
    onClosed: {
        if (root._opener && root._opener.visible)
            root._opener.forceActiveFocus(root._keyboard ? Qt.TabFocusReason : Qt.PopupFocusReason)
        root._opener = null
        Qt.callLater(root._reset)
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: VLCStyle.rd_menuFadeDuration
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: hoverTimer

        interval: VLCStyle.duration_long
        onTriggered: root._applyHover()
    }

    Connections {
        target: Qt.application

        // like a native menu, the menu closes when the application loses the focus
        function onStateChanged() {
            console.warn("DIAGMENU appState=" + Qt.application.state)
            if (Qt.application.state !== Qt.ApplicationActive)
                root.close()
        }
    }

    // a dialog opening (Ctrl+P, Ctrl+N, ...) closes the menu first: it never stays behind it
    Connections {
        target: DialogsProvider

        function onDialogOpening() {
            console.warn("DIAGMENU dialogOpening")
            root.close()
        }
    }

    contentItem: FocusScope {
        id: menuScope

        focus: true

        Keys.onPressed: (event) => {
            const deepest = root._models.length - 1
            if (deepest < 0)
                return

            if (event.key === Qt.Key_Down) {
                root._focusRow(deepest, 0, 1)
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                root._focusRow(deepest, -1, -1)
                event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
                root._back(deepest)
                event.accepted = true
            }
        }

        // outside the panels: a click closes the menu; the wheel does not reach the player
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            // the player may have hidden the cursor over the video
            cursorShape: Qt.ArrowCursor
            onPressed: (mouse) => {
                console.warn("DIAGMENU outside press at " + mouse.x + "," + mouse.y)
                root.close()
                if (mouse.button === Qt.RightButton)
                    root.rightPressedOutside()
            }
            onWheel: (wheel) => { wheel.accepted = true }
        }

        Repeater {
            id: levels

            model: root._maxDepth

            delegate: Rectangle {
                id: panel

                required property int index

                readonly property QtObject menuModel: index < root._models.length ? root._models[index] : null
                readonly property var anchor: index < root._anchors.length ? root._anchors[index] : null
                readonly property int openRow: index < root._openRows.length ? root._openRows[index] : -1

                // rows are created on demand (chapter and track lists can be long), so the size
                // comes from the model: row and separator counts, widest label and shortcut
                readonly property int rowCount: menuModel ? menuModel.count : 0
                readonly property int separatorCount: menuModel ? menuModel.separatorCount : 0
                readonly property real contentHeight: (rowCount - separatorCount) * VLCStyle.rd_menuRowHeight
                                                      + separatorCount * VLCStyle.dp(1)
                readonly property real naturalWidth: VLCStyle.dp(14) + VLCStyle.rd_iconSize + VLCStyle.dp(10)
                                                     + labelMetrics.advanceWidth + VLCStyle.dp(10)
                                                     + Math.max(VLCStyle.rd_iconSize, shortcutMetrics.advanceWidth)
                                                     + VLCStyle.dp(14)

                function rowAt(row) {
                    return list.itemAtIndex(row)
                }

                // focuses the first enabled row from `row` on in `direction`, wrapping around
                function focusRow(row, direction) {
                    const count = list.count
                    for (let k = 0; k < count; ++k) {
                        const i = (((row + k * direction) % count) + count) % count
                        list.positionViewAtIndex(i, ListView.Contain)
                        const item = list.itemAtIndex(i)
                        if (item && !item.separator && item.actionEnabled) {
                            item.focusOption()
                            return
                        }
                    }
                }

                visible: menuModel !== null && anchor !== null && rowCount > 0

                width: index === 0 ? root.rootWidth
                                   : Math.max(VLCStyle.rd_menuWidth,
                                              Math.min(VLCStyle.rd_menuMaxWidth, naturalWidth + 2 * root._padding))
                height: Math.min(contentHeight + 2 * root._padding, root.height - 2 * root._margin)

                x: {
                    if (!anchor)
                        return 0
                    if (index === 0)
                        return Math.max(root._margin, Math.min(anchor.x, root.width - width - root._margin))
                    if (anchor.right + width <= root.width - root._margin)
                        return anchor.right
                    return Math.max(root._margin, anchor.left - width)
                }
                y: anchor ? Math.max(root._margin, Math.min(anchor.y, root.height - height - root._margin)) : 0

                radius: VLCStyle.rd_radius_panel
                // opaque over the native video (Figma's 95 % assumes a background blur)
                color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

                Widgets.RdShadow {
                    visible: root.withShadow
                }

                TextMetrics {
                    id: labelMetrics

                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    text: panel.menuModel ? panel.menuModel.longestLabel : ""
                }

                TextMetrics {
                    id: shortcutMetrics

                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    text: panel.menuModel ? panel.menuModel.longestShortcut : ""
                }

                // clicks on the panel's padding stay in the menu
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    cursorShape: Qt.ArrowCursor
                    onWheel: (wheel) => { wheel.accepted = true }
                }

                ListView {
                    id: list

                    anchors.fill: parent
                    anchors.margins: root._padding

                    model: panel.menuModel
                    interactive: panel.contentHeight > height
                    clip: interactive
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: false

                    delegate: Item {
                        id: entry

                        required property int index
                        required property string label
                        required property string iconName
                        required property bool iconAccent
                        required property string shortcut
                        required property bool checkable
                        required property bool checked
                        required property bool actionEnabled
                        required property bool separator
                        required property bool hasSubmenu

                        function focusOption() {
                            option.forceActiveFocus(Qt.TabFocusReason)
                        }

                        width: ListView.view.width
                        height: separator ? divider.height : option.height

                        Widgets.RdMenuDivider {
                            id: divider

                            visible: entry.separator
                            width: parent.width
                        }

                        Widgets.RdOptionRow {
                            id: option

                            visible: !entry.separator
                            width: parent.width

                            text: entry.label
                            // checked entries show the accent check in the icon column (Profiles.png)
                            rdIcon: (entry.checkable && entry.checked) ? "check_state-active" : entry.iconName
                            reserveIconSpace: true
                            iconColor: entry.iconAccent ? VLCStyle.palette.rdAccentDim : VLCStyle.palette.rdFgA2
                            shortcut: entry.shortcut
                            hasSubmenu: entry.hasSubmenu
                            enabled: entry.actionEnabled
                            active: panel.openRow === entry.index

                            Accessible.role: Accessible.MenuItem
                            Accessible.checkable: entry.checkable
                            Accessible.checked: entry.checked

                            onHoveredChanged: {
                                if (!hovered) {
                                    // moving onto a disabled row (no hover events) must not
                                    // open this row's submenu 200 ms later
                                    if (root._pendingLevel === panel.index
                                            && root._pendingRow === entry.index)
                                        hoverTimer.stop()
                                    return
                                }
                                // the mouse takes over from the keyboard highlight
                                forceActiveFocus(Qt.MouseFocusReason)
                                root._hover(panel.index, entry.index)
                            }

                            onClicked: root._activate(panel.index, entry.index, visualFocus)

                            Keys.onReturnPressed: root._activate(panel.index, entry.index, true)
                            Keys.onEnterPressed: root._activate(panel.index, entry.index, true)

                            Navigation.upAction: () => panel.focusRow(entry.index - 1, -1)
                            Navigation.downAction: () => panel.focusRow(entry.index + 1, 1)
                            Navigation.rightAction: () => {
                                if (entry.hasSubmenu && entry.actionEnabled)
                                    root._openSubmenu(panel.index, entry.index, true)
                            }
                            // Left closes a submenu; on the first level it does nothing
                            Navigation.leftAction: () => {
                                if (panel.index > 0)
                                    root._back(panel.index)
                            }
                            // Escape closes the deepest open level first, like native menus
                            Navigation.cancelAction: () => root._back(Math.max(panel.index,
                                                                               root._models.length - 1))
                        }
                    }
                }
            }
        }
    }
}
