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

// redesign: the Keyboard Shortcuts dialog (video 15:57-16:03, Figma "Keyboard Shortcuts"
// 1048x800, node 2437:14832): VLC's hotkeys in their own modal dialog over the window (no dim, Decision 41).
// Header (BG/B2): title, close, search field and the "All Fields" search scope. Body: column
// titles Action / Hotkey / Global Hotkey, then the actions grouped under section titles, each
// with its hotkey and global hotkey field. Footer: Cancel, Save (dimmed until something changed).
// The hotkeys come from HotkeysModel, which reuses the logic of VLC's hotkey preferences.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Dialogs
import VLC.Player

T.Popup {
    id: root

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // field being captured: row of the filtered model and column, -1 when none
    property int captureRow: -1
    property bool captureGlobal: false

    // Figma rows: label, two 270 px fields, the hotkey field starting at x 379 of 1008
    readonly property real _rowWidth: Math.max(0, list.width - VLCStyle.dp(12))
    readonly property real _layoutScale: Math.min(1, _rowWidth / VLCStyle.dp(1008))
    readonly property real _fieldWidth: VLCStyle.dp(270) * _layoutScale
    readonly property real _globalFieldX: _rowWidth - _fieldWidth
    readonly property real _hotkeyFieldX: _globalFieldX - VLCStyle.dp(89) * _layoutScale - _fieldWidth

    readonly property real _availableWidth: T.Overlay.overlay ? T.Overlay.overlay.width : VLCStyle.rd_dialogWidth
    readonly property real _availableHeight: T.Overlay.overlay ? T.Overlay.overlay.height : VLCStyle.rd_dialogHeight

    anchors.centerIn: T.Overlay.overlay

    width: Math.min(VLCStyle.rd_dialogWidth, _availableWidth - 2 * VLCStyle.margin_large)
    height: Math.min(VLCStyle.rd_dialogHeight, _availableHeight - 2 * VLCStyle.margin_large)

    padding: 0
    modal: true
    focus: true
    // a click outside closes the dialog unless it holds unsaved changes or is capturing a key
    // (Escape, X and Cancel still close it)
    closePolicy: (hotkeysModel.dirty || captureRow >= 0)
                 ? T.Popup.CloseOnEscape
                 : (T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside)

    function startCapture(row, global) {
        captureRow = row
        captureGlobal = global
    }

    function cancelCapture() {
        captureRow = -1
    }

    function isCapturing(row, global) {
        return captureRow === row && captureGlobal === global
    }

    // a captured key, or a default restored from the menu: asks first when another action uses it
    function requestKeys(row, global, keys) {
        cancelCapture()
        const other = hotkeysModel.conflictingAction(row, global, keys)
        if (other === "") {
            hotkeysModel.assign(row, global, keys)
            return
        }
        conflictPopup.ask(row, global, keys, other)
    }

    function fieldAt(row, global) {
        if (row < 0 || row >= hotkeysModel.count)
            return null
        list.positionViewAtIndex(row, ListView.Contain)
        const item = list.itemAtIndex(row)
        if (!item)
            return null
        return (global && item.hasGlobal) ? item.globalField : item.hotkeyField
    }

    function focusField(row, global) {
        const field = fieldAt(row, global)
        if (field)
            field.forceActiveFocus(Qt.TabFocusReason)
        return !!field
    }

    function navigateFrom(row, global, key) {
        switch (key) {
        case Qt.Key_Up:
            if (!focusField(row - 1, global))
                searchInput.forceActiveFocus(Qt.BacktabFocusReason)
            break
        case Qt.Key_Down:
            focusField(row + 1, global)
            break
        case Qt.Key_Left:
            if (global)
                focusField(row, false)
            break
        case Qt.Key_Right:
            if (!global)
                focusField(row, true)
            break
        case Qt.Key_Tab: {
            const item = list.itemAtIndex(row)
            if (!global && item && item.hasGlobal)
                focusField(row, true)
            else if (!focusField(row + 1, false))
                cancelButton.forceActiveFocus(Qt.TabFocusReason)
            break
        }
        case Qt.Key_Backtab:
            if (global)
                focusField(row, false)
            else if (!focusField(row - 1, true))
                scopeDropdown.forceActiveFocus(Qt.BacktabFocusReason)
            break
        default:
            break
        }
    }

    function focusFirstField(reason) {
        if (!focusField(0, false))
            cancelButton.forceActiveFocus(reason)
    }

    function focusLastField(reason) {
        if (!focusField(hotkeysModel.count - 1, true))
            scopeDropdown.forceActiveFocus(reason)
    }

    // while open, keys go to the dialog instead of VLC's hotkeys (RdPanels.modalCount)
    property bool _holdsModal: false

    Component.onDestruction: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
    }

    // built in the background after startup (MainInterface.qml): read the actions now, so the
    // first open finds the rows ready
    Component.onCompleted: hotkeysModel.reload()

    onAboutToShow: {
        if (!_holdsModal) {
            RdPanels.acquireModal()
            _holdsModal = true
        }
        cancelCapture()
        searchInput.text = ""
        scopeDropdown.currentIndex = 0
        hotkeysModel.searchField = 0
        hotkeysModel.reload()
        list.positionViewAtBeginning()
        // focus from the first frame, not after the enter fade
        searchInput.forceActiveFocus(Qt.PopupFocusReason)
    }

    onOpened: {
        if (!searchInput.activeFocus)
            searchInput.forceActiveFocus(Qt.PopupFocusReason)
    }

    // keys go back to the player as soon as the dialog starts to close, not after its fade
    onAboutToHide: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
    }

    onClosed: {
        cancelCapture()
        conflictPopup.close()
        fieldMenu.close()
        descriptionTip.close()
    }

    // no dim behind the dialog (Decision 41: the video and Figma show none); the transparent
    // overlay still takes the clicks outside the dialog
    T.Overlay.modal: Item {
        // keeps the arrow cursor over the window behind (the video hides its cursor)
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.ArrowCursor
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_large
        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(root.rdPalette.rdBgA3Transparent, 1.0)

        Widgets.RdShadow { }
    }

    // opens and closes instantly, like every redesign dialog (Decision 32)

    contentItem: Item {
        id: content

        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        HotkeysModel {
            id: hotkeysModel

            ctx: MainCtx

            onSearchTextChanged: root.cancelCapture()
            onSearchFieldChanged: root.cancelCapture()
        }

        // keys nobody in the dialog handled never reach the player behind it; Escape goes on
        // to the popup, which closes
        Keys.onPressed: (event) => {
            // Tab goes back into the dialog after a click on empty space, to the first / last
            // row on screen (the list does not jump)
            if (event.key === Qt.Key_Tab) {
                const first = list.indexAt(list.width / 2, list.contentY + 1)
                if (first < 0 || !root.focusField(first, false))
                    root.focusFirstField(Qt.TabFocusReason)
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Backtab) {
                const last = list.indexAt(list.width / 2, list.contentY + list.height - 2)
                if (last < 0 || !root.focusField(last, true))
                    root.focusLastField(Qt.BacktabFocusReason)
                event.accepted = true
                return
            }
            event.accepted = (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Back)
        }

        // a click outside the fields ends a capture
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onPressed: (mouse) => {
                root.cancelCapture()
                content.forceActiveFocus(Qt.MouseFocusReason)
                mouse.accepted = false
            }
        }

        // ---------------------------------------------------------------------------- header
        Rectangle {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: VLCStyle.rd_dialogHeaderHeight

            radius: VLCStyle.rd_radius_large
            color: root.rdPalette.rdBgB2

            // square bottom corners
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(19)
                anchors.verticalCenter: closeButton.verticalCenter
                anchors.right: closeButton.left
                anchors.rightMargin: VLCStyle.dp(10)

                text: qsTr("Keyboard Shortcuts")
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA2

                Accessible.role: Accessible.TitleBar
                Accessible.name: text
            }

            T.Button {
                id: closeButton

                // the pointing hand over the clickable controls
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(9)
                anchors.top: parent.top
                anchors.topMargin: VLCStyle.dp(9)
                implicitWidth: VLCStyle.dp(32)
                implicitHeight: VLCStyle.dp(32)

                focusPolicy: Qt.StrongFocus
                Accessible.name: qsTr("Close")

                KeyNavigation.tab: searchInput
                KeyNavigation.backtab: saveButton.enabled ? saveButton : cancelButton

                onClicked: root.close()

                background: Rectangle {
                    radius: VLCStyle.rd_radius_small
                    color: closeButton.hovered ? root.rdPalette.rdHoverOverlay : "transparent"
                    border.width: closeButton.visualFocus ? VLCStyle.dp(1) : 0
                    border.color: root.rdPalette.rdFgA3
                }

                contentItem: Item {
                    Widgets.RdIcon {
                        anchors.centerIn: parent
                        name: "close"
                        color: root.rdPalette.rdFgA2
                    }
                }
            }

            Rectangle {
                id: searchBox

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(9)
                anchors.right: scopeDropdown.left
                anchors.rightMargin: VLCStyle.dp(10)
                anchors.bottom: parent.bottom
                anchors.bottomMargin: VLCStyle.dp(9)
                height: VLCStyle.dp(34)

                radius: VLCStyle.rd_radius_normal
                color: root.rdPalette.rdBgField

                Widgets.RdIcon {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.dp(8)
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: root.rdPalette.rdFgA2
                }

                T.TextField {
                    id: searchInput

                    anchors.left: searchIcon.right
                    anchors.leftMargin: VLCStyle.dp(10)
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(8)
                    // the box's whole height: a T.TextField has no implicit height of its own
                    // (the Controls styles give it one), so with Qt 6.10 it was 0 px tall,
                    // took no clicks and drew no text
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    padding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: root.rdPalette.rdFg2
                    selectionColor: root.rdPalette.rdAccentDim
                    selectedTextColor: root.rdPalette.rdSelectionText

                    placeholderText: qsTr("Search Keyboard Shortcuts...")
                    Accessible.name: placeholderText

                    KeyNavigation.tab: scopeDropdown
                    KeyNavigation.backtab: closeButton
                    Keys.onDownPressed: root.focusFirstField(Qt.TabFocusReason)

                    onTextChanged: hotkeysModel.searchText = text

                    background: null
                }

                // T.TextField draws no placeholder (the styles do)
                Text {
                    anchors.left: searchInput.left
                    anchors.right: searchInput.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchInput.length === 0 && searchInput.preeditText === ""
                    text: searchInput.placeholderText
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: root.rdPalette.rdFgA4
                }
            }

            Widgets.RdDropdown {
                id: scopeDropdown

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(9)
                anchors.verticalCenter: searchBox.verticalCenter
                width: Math.min(VLCStyle.dp(200), header.width / 4)
                height: VLCStyle.dp(34)
                maxVisibleRows: 4

                model: [qsTr("All Fields"), qsTr("Actions"), qsTr("Hotkeys"), qsTr("Global Hotkeys")]
                Accessible.name: qsTr("Search in")

                KeyNavigation.backtab: searchInput
                Keys.onTabPressed: root.focusFirstField(Qt.TabFocusReason)

                onActivated: (index) => hotkeysModel.searchField = index

                background: Rectangle {
                    radius: VLCStyle.rd_radius_normal
                    color: scopeDropdown.hovered ? root.rdPalette.rdBgA4 : root.rdPalette.rdBgField
                    border.width: scopeDropdown.visualFocus ? VLCStyle.dp(1) : 0
                    border.color: root.rdPalette.rdFgA3
                }

                contentItem: Text {
                    leftPadding: VLCStyle.dp(12)
                    rightPadding: VLCStyle.dp(36)
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: scopeDropdown.displayText
                    font: scopeDropdown.font
                    color: root.rdPalette.rdFgA1
                }

                indicator: Widgets.RdIcon {
                    x: scopeDropdown.width - width - VLCStyle.dp(8)
                    y: (scopeDropdown.height - height) / 2
                    name: "chevron_direction-down"
                    color: root.rdPalette.rdFgA2
                }
            }
        }

        // ---------------------------------------------------------------------------- body
        Item {
            id: columnTitles

            anchors.left: parent.left
            anchors.top: header.bottom
            anchors.leftMargin: VLCStyle.dp(20)
            anchors.topMargin: VLCStyle.dp(20)
            width: root._rowWidth
            height: VLCStyle.dp(25)

            component ColumnTitle : Text {
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }

            ColumnTitle {
                x: 0
                width: root._hotkeyFieldX
                text: qsTr("Action")
            }

            ColumnTitle {
                x: root._hotkeyFieldX
                width: root._fieldWidth
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Hotkey")
            }

            ColumnTitle {
                x: root._globalFieldX
                width: root._fieldWidth
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Global Hotkey")
            }
        }

        ListView {
            id: list

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: columnTitles.bottom
            anchors.bottom: footer.top
            anchors.leftMargin: VLCStyle.dp(20)
            anchors.rightMargin: VLCStyle.dp(8)

            clip: true
            boundsBehavior: Flickable.StopAtBounds

            model: hotkeysModel

            T.ScrollBar.vertical: Widgets.ScrollBarExt { }

            section.property: "group"
            section.criteria: ViewSection.FullString
            section.delegate: Item {
                id: sectionItem

                required property string section

                readonly property bool first: section === hotkeysModel.firstGroup
                // Figma: 20 px under the column titles; 5 + 20 px under the previous rows,
                // whose delegates already end with their 14 px spacing
                readonly property real topGap: first ? VLCStyle.dp(20) : VLCStyle.dp(11)

                width: root._rowWidth
                height: topGap + VLCStyle.dp(20) + VLCStyle.dp(28) + VLCStyle.dp(20)

                Widgets.RdMenuDivider {
                    y: sectionItem.topGap
                    width: parent.width
                }

                Text {
                    y: sectionItem.topGap + VLCStyle.dp(20)
                    width: parent.width
                    height: VLCStyle.dp(28)
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: sectionItem.section
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_header
                    color: VLCStyle.palette.rdFgA1

                    Accessible.role: Accessible.Heading
                    Accessible.name: text
                }
            }

            footer: Item {
                width: root._rowWidth
                height: VLCStyle.dp(13)
            }

            delegate: Item {
                id: row

                required property int index
                required property string action
                required property string description
                required property string hotkey
                required property string globalHotkey
                required property bool hasGlobal
                required property bool hotkeyIsDefault
                required property bool globalHotkeyIsDefault

                readonly property alias hotkeyField: hotkeyField
                readonly property alias globalField: globalField

                width: root._rowWidth
                height: VLCStyle.dp(33) + VLCStyle.dp(14)

                function fieldClicked(field, global) {
                    field.forceActiveFocus(Qt.MouseFocusReason)
                    if (field.capturing)
                        root.cancelCapture()
                    else
                        root.startCapture(row.index, global)
                }

                function fieldFocused() {
                    list.positionViewAtIndex(row.index, ListView.Contain)
                }

                function fieldMenuRequested(field, global, position) {
                    root.cancelCapture()
                    field.forceActiveFocus(Qt.MouseFocusReason)
                    fieldMenu.openFor(field, position, row.index, global, field.keys !== "",
                                      global ? row.globalHotkeyIsDefault : row.hotkeyIsDefault)
                }

                // a click between the fields ends a capture (the list keeps the press for flicking)
                MouseArea {
                    anchors.fill: parent
                    onPressed: (mouse) => {
                        root.cancelCapture()
                        mouse.accepted = false
                    }
                }

                Text {
                    id: actionLabel

                    y: (VLCStyle.dp(33) - height) / 2
                    width: root._hotkeyFieldX - VLCStyle.dp(16)
                    height: VLCStyle.dp(25)
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: row.action
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFg2

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: row.description !== "" || actionLabel.truncated

                        onContainsMouseChanged: {
                            if (containsMouse)
                                descriptionTip.showFor(actionLabel, row.description !== "" ? row.description : row.action)
                            else
                                descriptionTip.hideFor(actionLabel)
                        }
                    }
                }

                HotkeyField {
                    id: hotkeyField

                    x: root._hotkeyFieldX
                    width: root._fieldWidth
                    height: VLCStyle.dp(33)

                    keys: row.hotkey
                    hotkeys: hotkeysModel
                    capturing: root.isCapturing(row.index, false)

                    Accessible.description: qsTr("Hotkey of %1").arg(row.action)

                    onClicked: row.fieldClicked(hotkeyField, false)
                    onFocusEntered: row.fieldFocused()
                    onKeyCaptured: (key) => root.requestKeys(row.index, false, key)
                    onCaptureCancelled: root.cancelCapture()
                    onClearRequested: hotkeysModel.clear(row.index, false)
                    onNavigationRequested: (key) => root.navigateFrom(row.index, false, key)
                    onContextMenuRequested: (position) => row.fieldMenuRequested(hotkeyField, false, position)
                }

                HotkeyField {
                    id: globalField

                    x: root._globalFieldX
                    width: root._fieldWidth
                    height: VLCStyle.dp(33)

                    enabled: row.hasGlobal
                    opacity: enabled ? 1 : 0.5

                    keys: row.globalHotkey
                    hotkeys: hotkeysModel
                    capturing: root.isCapturing(row.index, true)

                    Accessible.description: qsTr("Global hotkey of %1").arg(row.action)

                    onClicked: row.fieldClicked(globalField, true)
                    onFocusEntered: row.fieldFocused()
                    onKeyCaptured: (key) => root.requestKeys(row.index, true, key)
                    onCaptureCancelled: root.cancelCapture()
                    onClearRequested: hotkeysModel.clear(row.index, true)
                    onNavigationRequested: (key) => root.navigateFrom(row.index, true, key)
                    onContextMenuRequested: (position) => row.fieldMenuRequested(globalField, true, position)
                }
            }
        }

        Text {
            anchors.left: list.left
            anchors.right: list.right
            anchors.verticalCenter: list.verticalCenter
            visible: hotkeysModel.count === 0
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("No keyboard shortcut matches your search.")
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }

        // ---------------------------------------------------------------------------- footer
        Item {
            id: footer

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: VLCStyle.rd_dialogFooterHeight

            Widgets.RdButton {
                id: cancelButton

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                text: qsTr("Cancel")

                KeyNavigation.tab: saveButton.enabled ? saveButton : closeButton
                Keys.onBacktabPressed: root.focusLastField(Qt.BacktabFocusReason)

                onClicked: root.close()
            }

            Text {
                anchors.left: cancelButton.right
                anchors.right: saveButton.left
                anchors.margins: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                visible: hotkeysModel.dirty
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                // VLC reads its hotkeys when it starts (src/misc/actions.c)
                text: qsTr("New shortcuts take effect after a restart.")
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA3
            }

            Widgets.RdButton {
                id: saveButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                style: Widgets.RdButton.Style.Save
                text: qsTr("Save")
                enabled: hotkeysModel.dirty

                KeyNavigation.tab: closeButton
                KeyNavigation.backtab: cancelButton

                onClicked: {
                    hotkeysModel.save()
                    root.close()
                }
            }
        }

        // ------------------------------------------------------------------------- popups
        Widgets.RdTooltip {
            id: descriptionTip

            property Item target: null

            maximumTextWidth: VLCStyle.dp(420)
            // follows the hover only: Escape keeps closing the dialog
            closePolicy: T.Popup.NoAutoClose

            function showFor(item, text) {
                target = item
                descriptionTip.text = text
                tipTimer.restart()
            }

            function hideFor(item) {
                if (target !== item)
                    return
                tipTimer.stop()
                target = null
                close()
            }

            Timer {
                id: tipTimer

                interval: VLCStyle.delayToolTipAppear
                onTriggered: {
                    const target = descriptionTip.target
                    if (!target)
                        return
                    const p = target.mapToItem(content, 0, target.height + VLCStyle.dp(4))
                    descriptionTip.x = Math.max(0, Math.min(p.x, content.width - descriptionTip.width))
                    descriptionTip.y = p.y
                    descriptionTip.open()
                }
            }
        }

        Widgets.RdMenuPanel {
            id: fieldMenu

            property Item field: null
            property int row: -1
            property bool global: false
            property bool hasKeys: false
            property bool isDefault: true

            // the menu's parent fills the dialog: close on any press outside the menu
            closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

            function openFor(item, position, row, global, hasKeys, isDefault) {
                field = item
                fieldMenu.row = row
                fieldMenu.global = global
                fieldMenu.hasKeys = hasKeys
                fieldMenu.isDefault = isDefault
                const p = item.mapToItem(content, position.x, position.y)
                x = Math.max(0, Math.min(p.x, content.width - width))
                y = Math.max(0, Math.min(p.y, content.height - height))
                open()
            }

            onClosed: {
                if (field && root.opened)
                    field.forceActiveFocus(Qt.PopupFocusReason)
            }

            Widgets.RdOptionRow {
                text: qsTr("Change")
                onClicked: root.startCapture(fieldMenu.row, fieldMenu.global)
            }

            Widgets.RdOptionRow {
                text: qsTr("Clear")
                enabled: fieldMenu.hasKeys
                dimmed: !enabled
                onClicked: hotkeysModel.clear(fieldMenu.row, fieldMenu.global)
            }

            Widgets.RdOptionRow {
                text: qsTr("Reset to Default")
                enabled: !fieldMenu.isDefault
                dimmed: !enabled
                onClicked: root.requestKeys(fieldMenu.row, fieldMenu.global,
                                            hotkeysModel.defaultKeys(fieldMenu.row, fieldMenu.global))
            }

            Widgets.RdMenuDivider { }

            Widgets.RdOptionRow {
                text: qsTr("Reset All Shortcuts")
                onClicked: hotkeysModel.resetAll()
            }
        }

        T.Popup {
            id: conflictPopup

            property int row: -1
            property bool global: false
            property string keys: ""
            property string otherAction: ""

            function ask(row, global, keys, otherAction) {
                conflictPopup.row = row
                conflictPopup.global = global
                conflictPopup.keys = keys
                conflictPopup.otherAction = otherAction

                const field = root.fieldAt(row, global)
                const below = field ? field.mapToItem(content, 0, field.height + VLCStyle.dp(6))
                                    : Qt.point((content.width - width) / 2, (content.height - height) / 2)
                x = Math.max(VLCStyle.dp(20), Math.min(below.x, content.width - width - VLCStyle.dp(20)))
                y = (below.y + height <= footer.y) ? below.y
                                                   : Math.max(0, below.y - height - (field ? field.height : 0) - VLCStyle.dp(12))
                open()
            }

            width: Math.min(VLCStyle.dp(380), content.width - VLCStyle.dp(40))
            implicitHeight: implicitContentHeight + topPadding + bottomPadding
            padding: VLCStyle.dp(16)
            modal: true
            dim: false
            focus: true
            closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

            onOpened: assignButton.forceActiveFocus(Qt.PopupFocusReason)
            onClosed: {
                const field = root.opened ? root.fieldAt(row, global) : null
                if (field)
                    field.forceActiveFocus(Qt.PopupFocusReason)
            }

            background: Rectangle {
                radius: VLCStyle.rd_radius_panel
                color: root.rdPalette.rdBgA1
                border.width: VLCStyle.dp(1)
                border.color: root.rdPalette.rdDividerBright

                Widgets.RdShadow { }
            }

            contentItem: Column {
                spacing: VLCStyle.dp(16)

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: qsTr("%1 is already used by \"%2\". Use it here instead?")
                              .arg(hotkeysModel.displayKeys(conflictPopup.keys))
                              .arg(conflictPopup.otherAction)
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFg2
                }

                Item {
                    width: parent.width
                    height: assignButton.height

                    Widgets.RdButton {
                        id: keepButton

                        anchors.left: parent.left
                        text: qsTr("Cancel")

                        KeyNavigation.tab: assignButton
                        KeyNavigation.right: assignButton

                        onClicked: conflictPopup.close()
                    }

                    Widgets.RdButton {
                        id: assignButton

                        anchors.right: parent.right
                        style: Widgets.RdButton.Style.Save
                        text: qsTr("Assign")

                        KeyNavigation.tab: keepButton
                        KeyNavigation.left: keepButton

                        onClicked: {
                            hotkeysModel.assign(conflictPopup.row, conflictPopup.global, conflictPopup.keys)
                            conflictPopup.close()
                        }
                    }
                }
            }
        }
    }
}
