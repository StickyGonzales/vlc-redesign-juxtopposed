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

// redesign (W8.1a, video 19:12-19:28, Figma "Player - customize" 2107:5604): Customize Player,
// VLC's toolbar editor in the redesign. One large frame in the middle of VLC with outlined buttons and
// icons: a 1048 wide box over the window (BG/B1, radius 14, shadow; header BG/B2 94
// high with the title and the description; the palette of controls; Cancel / Save footer) and,
// at the bottom of the window where the control bar is, the edited bar with dashed outlines;
// at the top, where the top bar is, the edited top bar (W8.1b, CustomizeTopBar). Controls are
// dragged from the box into either bar, around in them, from one bar to the other, and back into
// the box to remove them. VLC's three player layouts (video, audio, mini player) stay
// customizable: the Figma segmented control centered in the footer between Cancel and Save
// (Decision 62), since the design has no place for them; the profiles are in the main menu
// (W8.2, Figma "Profiles"), the title row is Figma's (title and X).
// Opens and closes instantly (Decision 32). Save keeps the changes, Cancel / X / Escape restore
// the saved layouts (VLC's toolbar editor semantics); the live bars follow every change.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player
import VLC.PlayerControls

T.Popup {
    id: root

    // player layout being edited (PlayerControlbarModel.PlayerIdentifier)
    property int identifier: PlayerControlbarModel.Videoplayer

    readonly property var playerModel: {
        const profile = MainCtx.controlbarProfileModel.currentModel
        return profile ? profile.getModel(identifier) : null
    }

    // something to save: a layout of the selected profile changed (the top bar's too)
    readonly property bool dirty: !!MainCtx.controlbarProfileModel.currentModel
                                  && MainCtx.controlbarProfileModel.currentModel.dirty

    property bool _accepted: false

    // the window without the client side decoration's shadow margin
    readonly property real _margin: MainCtx.windowExtendedMargin
    readonly property real _availableWidth: parent ? parent.width - 2 * _margin : VLCStyle.rd_dialogWidth
    readonly property real _availableHeight: parent ? parent.height - 2 * _margin : VLCStyle.rd_dialogHeight

    property Item _restoreFocusItem: null

    function openDialog() {
        if (opened)
            return

        // an item inside another popup (the main menu that opened this dialog) closes with it,
        // so the focus goes back to the window content instead
        const window = MainCtx.intfMainWindow
        let focusItem = (window && window.activeFocusItem) ? window.activeFocusItem : null
        for (let item = focusItem; item; item = item.parent) {
            if (item === root.parent) {
                focusItem = null
                break
            }
        }
        _restoreFocusItem = focusItem

        open()
    }

    function accept() {
        _accepted = true
        close()
    }

    parent: T.Overlay.overlay
    x: _margin
    y: _margin
    width: _availableWidth
    height: _availableHeight

    padding: 0
    modal: true
    // the player stays visible behind the box (Figma: no dimming)
    dim: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape

    // while open, keys go to the dialog instead of VLC's hotkeys (RdPanels.modalCount)
    property bool _holdsModal: false

    Component.onDestruction: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
    }

    onAboutToShow: {
        if (!_holdsModal) {
            RdPanels.acquireModal()
            _holdsModal = true
        }
        _accepted = false

        // what Cancel goes back to (VLC's toolbar editor saves first too)
        MainCtx.controlbarProfileModel.save(false)

        // the layout of what is on screen: the player's video or audio bar, else the mini player
        if (MainCtx.effectiveMainInterfaceMode === MainCtx.MAININTERFACE_MODE_PLAYER)
            identifier = Player.hasVideoOutput ? PlayerControlbarModel.Videoplayer
                                               : PlayerControlbarModel.Audioplayer
        else
            identifier = PlayerControlbarModel.Miniplayer

        paletteGrid.refresh()
        body.fitContent()
        paletteGrid.positionViewAtBeginning()
        content.forceActiveFocus(Qt.PopupFocusReason)
    }

    // keys go back to the player as soon as the dialog starts to close
    onAboutToHide: {
        if (_holdsModal) {
            RdPanels.releaseModal()
            _holdsModal = false
        }
        if (_restoreFocusItem)
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
    }

    onClosed: {
        if (_accepted)
            MainCtx.controlbarProfileModel.save()
        else
            MainCtx.controlbarProfileModel.reload()

        const window = MainCtx.intfMainWindow
        if (_restoreFocusItem && _restoreFocusItem.visible
                && (!window || window.activeFocusItem !== _restoreFocusItem))
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
        _restoreFocusItem = null
    }

    background: null

    // opens and closes instantly, like every redesign dialog (Decision 32)

    contentItem: Item {
        id: content

        readonly property ColorContext colorContext: ColorContext {
            palette: VLCStyle.palette
            colorSet: ColorContext.Window
        }

        // ------------------------------------------------------------------ drag state
        // (used by CustomizePalette, CustomizeBar, CustomizeZone, CustomizeZoneItem)

        property bool paletteDragActive: false
        property bool barDragActive: false
        readonly property bool dragActive: paletteDragActive || barDragActive
        property int draggedControlId: -1

        readonly property Item dragGhost: ghost

        function paletteDragStarted(controlId) {
            draggedControlId = controlId
            paletteDragActive = true
        }

        function paletteDragStopped(controlId) {
            paletteDragActive = false
            draggedControlId = -1
        }

        function barDragStarted(controlId) {
            draggedControlId = controlId
            barDragActive = true
        }

        function barDragStopped(controlId) {
            barDragActive = false
            draggedControlId = -1
        }

        // keys nobody in the dialog handled never reach the player behind it; Escape goes on to
        // the popup, which closes
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                closeButton.forceActiveFocus(event.key === Qt.Key_Tab ? Qt.TabFocusReason
                                                                       : Qt.BacktabFocusReason)
                event.accepted = true
                return
            }
            event.accepted = (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Back)
        }

        // the window behind is not usable while customizing; keeps the arrow cursor (the video
        // hides its cursor) and gives the keys back to the dialog after a click on empty space
        MouseArea {
            anchors.fill: parent
            cursorShape: content.dragActive ? Qt.DragMoveCursor : Qt.ArrowCursor
            onPressed: (mouse) => {
                content.forceActiveFocus(Qt.MouseFocusReason)
                mouse.accepted = false
            }
        }

        // ---------------------------------------------------------------------- box

        Rectangle {
            id: box

            readonly property real _maxHeight: content.height - topBar.height - bar.height - 2 * VLCStyle.margin_large

            width: Math.min(VLCStyle.rd_dialogWidth, content.width - 2 * VLCStyle.margin_large)
            height: Math.min(_maxHeight, header.height + body.implicitHeight + footer.height)

            x: Math.round((content.width - width) / 2)
            // centered in the space above a one-row bar (Figma: 189.5 above, 181.5 below), under
            // the top bar; a two-row bar does not move it (Figma "Player - customize-6": same
            // place) unless it would reach the bar
            y: Math.max(topBar.height,
                        Math.min(Math.round((content.height - VLCStyle.rd_controlBarHeight - height) / 2),
                                 content.height - bar.height - VLCStyle.margin_large - height))

            radius: VLCStyle.rd_radius_large
            // opaque over the native video (Figma's BG/B1 95 % assumes a background blur)
            color: Qt.alpha(VLCStyle.palette.rdBgB1Transparent, 1.0)

            Widgets.RdShadow { }

            // clicks inside the box never reach the window
            MouseArea {
                anchors.fill: parent
                cursorShape: content.dragActive ? Qt.DragMoveCursor : Qt.ArrowCursor
            }

            // -------------------------------------------------------------- header
            Rectangle {
                id: header

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: VLCStyle.rd_customizeHeaderHeight

                radius: VLCStyle.rd_radius_large
                color: VLCStyle.palette.rdBgB2

                // square bottom corners
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.radius
                    color: parent.color
                }

                // title row (Figma "Frame 207": 9 from the edges, 32 high, text at 10)
                Item {
                    id: titleRow

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: VLCStyle.dp(9)
                    height: VLCStyle.dp(32)

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: VLCStyle.dp(10)
                        anchors.right: closeButton.left
                        anchors.rightMargin: VLCStyle.dp(10)
                        anchors.verticalCenter: parent.verticalCenter

                        text: qsTr("Customize Player")
                        elide: Text.ElideRight
                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: VLCStyle.palette.rdFgA2

                        Accessible.role: Accessible.TitleBar
                        Accessible.name: text
                    }

                    HeaderButton {
                        id: closeButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        iconName: "close"
                        Accessible.name: qsTr("Close")

                        KeyNavigation.tab: playerTabs
                        KeyNavigation.backtab: saveButton.enabled ? saveButton : cancelButton

                        onClicked: root.close()
                    }
                }

                // description row (Figma "Frame 208", FG/A3)
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: VLCStyle.dp(19)
                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(19)
                    anchors.top: titleRow.bottom
                    anchors.topMargin: VLCStyle.dp(12)
                    height: VLCStyle.dp(32)

                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: qsTr("Drag items around and out of the box below to re-order them. Drag items into the box to remove them from the player.")
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: VLCStyle.palette.rdFgA3
                }
            }

            // ---------------------------------------------------------------- body
            Item {
                id: body

                readonly property int _columns: Math.max(1, Math.floor((width - 2 * VLCStyle.rd_customizeBodyPadding + VLCStyle.rd_customizeColumnGap)
                                                                       / paletteGrid.cellWidth))
                // sized for the items the box has when it opens (Figma's auto layout: full rows
                // 120 apart, the last row as high as its items), then kept while items move (the
                // box does not resize under the cursor); more items scroll
                property int _rows: 1
                property real _lastRowHeight: paletteGrid._itemHeight

                function fitContent() {
                    _rows = Math.max(1, Math.ceil(paletteGrid.count / _columns))
                    _lastRowHeight = paletteGrid.itemsHeightFrom((_rows - 1) * _columns)
                }

                implicitHeight: 2 * VLCStyle.rd_customizeBodyPadding
                                + (_rows - 1) * paletteGrid.cellHeight + _lastRowHeight

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: footer.top

                // a control dragged from the bar over the box: it is removed on drop
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: VLCStyle.dp(14)
                    visible: paletteGrid.removeHintVisible
                    radius: VLCStyle.rd_radius_normal
                    color: VLCStyle.palette.rdHoverOverlay

                    Widgets.RdDashedFrame {
                        anchors.fill: parent
                        color: VLCStyle.palette.rdAccentMain
                    }
                }

                CustomizePalette {
                    id: paletteGrid

                    x: VLCStyle.rd_customizeBodyPadding
                    y: VLCStyle.rd_customizeBodyPadding
                    width: body._columns * cellWidth
                    // the cells include the row gap: the last one reaches into the bottom padding
                    height: Math.max(0, parent.height - 2 * VLCStyle.rd_customizeBodyPadding + VLCStyle.rd_customizeRowGap)

                    editor: content
                    playerModel: root.playerModel
                    topBarModel: RdProfiles.topBarModel
                }
            }

            // -------------------------------------------------------------- footer
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
                    KeyNavigation.backtab: playerTabs

                    onClicked: root.close()
                }

                // VLC's player layouts (not in the design, Decision 62): the Figma segmented
                // control (component "Values" 999:4556: padding 2, gap 2, radius 6 / 4, Inter
                // 14) at the size of the settings sidebar's Flip switcher (6114:13499: 360 x 44,
                // three 117.33 x 40 segments), centered between Cancel and Save. One Tab stop,
                // Left / Right switch the layout.
                Widgets.RdSegmented {
                    id: playerTabs

                    readonly property var layouts: PlayerListModel.model
                    readonly property real _room: saveButton.x - (cancelButton.x + cancelButton.width)

                    function select(index) {
                        if (index < 0 || index >= layouts.length)
                            return
                        const identifier = layouts[index].identifier
                        if (identifier === root.identifier)
                            return
                        root.identifier = identifier
                        // a click refits the box; during a drag it keeps its size
                        if (!content.dragActive)
                            body.fitContent()
                    }

                    implicitWidth: VLCStyle.dp(360)
                    implicitHeight: VLCStyle.dp(44)
                    width: Math.max(0, Math.min(implicitWidth, _room - 2 * VLCStyle.dp(20)))
                    x: Math.round(cancelButton.x + cancelButton.width + (_room - width) / 2)
                    anchors.verticalCenter: parent.verticalCenter

                    model: layouts.map((layout) => layout.name)
                    currentIndex: layouts.findIndex((layout) => layout.identifier === root.identifier)
                    Accessible.name: qsTr("Player layout: %1").arg(model[currentIndex] ?? "")

                    KeyNavigation.tab: cancelButton
                    KeyNavigation.backtab: closeButton

                    onActivated: (index) => select(index)

                    // a palette item dragged over a segment selects it (not a control of the bar:
                    // its zone would go away under the drag)
                    DropArea {
                        anchors.fill: parent

                        // RdSegmented: 2 px around and between the segments
                        function _indexAt(x) {
                            const count = playerTabs.layouts.length
                            const inset = VLCStyle.dp(2)
                            const pitch = (width - 2 * inset + inset) / Math.max(1, count)
                            return Math.max(0, Math.min(count - 1, Math.floor((x - inset) / pitch)))
                        }

                        onEntered: (drag) => {
                            if (!content.paletteDragActive) {
                                drag.accepted = false
                                return
                            }
                            playerTabs.select(_indexAt(drag.x))
                        }
                        onPositionChanged: (drag) => playerTabs.select(_indexAt(drag.x))
                    }
                }

                Widgets.RdButton {
                    id: saveButton

                    anchors.right: parent.right
                    anchors.rightMargin: VLCStyle.dp(20)
                    anchors.verticalCenter: parent.verticalCenter

                    style: Widgets.RdButton.Style.Save
                    text: qsTr("Save")
                    enabled: root.dirty

                    KeyNavigation.tab: closeButton
                    KeyNavigation.backtab: cancelButton

                    onClicked: root.accept()
                }
            }
        }

        // ------------------------------------------------------------------ top bar

        CustomizeTopBar {
            id: topBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            editor: content
            topBarModel: RdProfiles.topBarModel
        }

        // ---------------------------------------------------------------------- bar

        CustomizeBar {
            id: bar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            editor: content
            playerModel: root.playerModel
            hasSeekRow: root.identifier !== PlayerControlbarModel.Miniplayer
        }

        // ------------------------------------------------------------- drag ghost

        // a palette item under the cursor while it is dragged (video 19:22)
        CustomizePaletteTile {
            id: ghost

            box: paletteGrid
            // (the palette puts the drag hot spot where the item was grabbed)
            visible: Drag.active
            z: 100
        }
    }

    // ------------------------------------------------------------------------------ parts

    // 32x32 icon button of the dialog header (Figma "Icon Wrapper" with the close icon)
    component HeaderButton: T.Button {
        id: headerButton

        // the pointing hand over the clickable controls
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        property string iconName: ""

        implicitWidth: VLCStyle.dp(32)
        implicitHeight: VLCStyle.dp(32)

        focusPolicy: Qt.StrongFocus

        background: Rectangle {
            radius: VLCStyle.rd_radius_small
            color: headerButton.hovered ? VLCStyle.palette.rdHoverOverlay : "transparent"
            border.width: headerButton.visualFocus ? VLCStyle.dp(1) : 0
            border.color: VLCStyle.palette.rdFgA3
        }

        contentItem: Item {
            Widgets.RdIcon {
                anchors.centerIn: parent
                name: headerButton.iconName
                color: VLCStyle.palette.rdFgA2
            }
        }
    }
}
