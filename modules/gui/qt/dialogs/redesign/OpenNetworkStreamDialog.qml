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

// redesign (W6.4, video 13:07-13:20, Figma "Open network stream" 6216:13614):
// modal dialog over the window (no dim, Decision 41). "Network URL" takes one link per line;
// "Playlist Name (optional)" fills in from a playlist link's file name; links to playlists
// (m3u, pls ...) are always saved as stream lists under the library's Network and shown there
// (RdStreamListSaver, P6-14); with a typed name the other links are saved as a media library
// playlist instead of playing them (shown only when the media library is available).
// Opened by DialogsProvider.openNetDialog() through showOpenNetworkStreamDialog().
import QtQuick
import QtQuick.Templates as T
import QtQuick.Layouts

import VLC.MainInterface
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Dialogs
import VLC.Player

T.Popup {
    id: root

    readonly property SystemPalette rdPalette: VLCStyle.palette

    // Figma frame 1048 x 631 (header 50, body 509, footer 72), 160 px less without the
    // playlist name section; the URL box gives back height first when the window is
    // smaller than the design
    readonly property real _designHeight: VLCStyle.dp(_showPlaylistName ? 631 : 471, VLCStyle.scale)
    readonly property real _windowMargin: VLCStyle.dp(20, VLCStyle.scale)

    readonly property bool _canSave: urlArea.text.trim() !== ""
    readonly property bool _showPlaylistName: MainCtx.mediaLibraryAvailable

    // item to give the keyboard focus back to when the dialog closes
    property Item _restoreFocusItem: null

    // the Playlist Name holds a name the user typed (not the one filled in from the link)
    property bool _nameTyped: false

    function openDialog() {
        const window = MainCtx.intfMainWindow
        if (window) {
            window.raise()
            window.requestActivate()
        }

        // already open or opening (opened only turns true after the enter transition)
        if (visible && !(root.exit && root.exit.running)) {
            urlArea.forceActiveFocus(Qt.PopupFocusReason)
            return
        }

        _nameTyped = false
        urlArea.clear()
        nameField.clear()

        // an item inside another popup (the main menu that opened this dialog) closes
        // with it, so focus goes back to the window content instead
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

    function _links() {
        return urlArea.text.split("\n").map((u) => u.trim()).filter((u) => u !== "")
    }

    // the Playlist Name fills in from the first playlist link (13:17: ".../index.m3u" gives
    // "Index") until the user types a name of their own; clearing it lets it follow the links again
    function _updateAutoName() {
        const saver = _streamListSaver.item
        if (_nameTyped || !saver)
            return
        const list = _links().find((u) => saver.isPlaylistUrl(u))
        nameField.text = list ? saver.autoName(list) : ""
    }

    function save() {
        if (!_canSave)
            return

        // links to playlists always become stream lists under Network, shown in the library
        // (video 13:17-13:20, P6-14): under the typed Playlist Name, otherwise each under the
        // name from its link. The other links are saved as a media library playlist under a
        // typed name and play otherwise (a single stream link plays, as Open URL does).
        const typedName = (_showPlaylistName && _nameTyped) ? nameField.text.trim() : ""
        const saver = _streamListSaver.item
        if (saver) {
            const links = _links()
            const lists = links.filter((u) => saver.isPlaylistUrl(u))
            const others = links.filter((u) => !saver.isPlaylistUrl(u))
            if (others.length > 0)
                DialogsProvider.openNetworkStreams(others.join("\n"), typedName)
            if (typedName !== "")
                saver.save(typedName, lists)
            else
                saver.saveWithDefaultNames(lists)
        } else {
            DialogsProvider.openNetworkStreams(urlArea.text, typedName)
        }
        close()
    }

    // the library's stream lists (VLC.MediaLibrary is only there with the media library); not
    // a child of the dialog's content column
    readonly property Loader _streamListSaver: Loader {
        // loaded while the dialog shows
        active: root._showPlaylistName && root.visible
        source: "qrc:///qt/qml/VLC/MediaLibrary/RdStreamListSaver.qml"

        onLoaded: root._updateAutoName()
    }

    parent: T.Overlay.overlay
    anchors.centerIn: parent

    width: Math.min(VLCStyle.dp(1048, VLCStyle.scale),
                    parent ? parent.width - 2 * (_windowMargin + MainCtx.windowExtendedMargin) : 0)
    height: Math.min(_designHeight,
                     parent ? parent.height - 2 * (_windowMargin + MainCtx.windowExtendedMargin) : 0)

    padding: 0
    modal: true
    focus: true
    // a click outside closes the dialog while nothing is typed; typed links are never lost to
    // a stray click (Escape, X and Cancel still close it)
    closePolicy: (urlArea.text.trim() === "" && nameField.text.trim() === "")
                 ? (T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside)
                 : T.Popup.CloseOnEscape

    // while open, keys go to the dialog instead of VLC's hotkeys (RdPanels.modalCount). The count
    // and the focus change hands when the dialog starts to show / hide, not when its fade ends,
    // so no key is lost during the 200 ms transitions.
    property bool _holdsModal: false

    onAboutToShow: {
        if (!root._holdsModal) {
            RdPanels.acquireModal()
            root._holdsModal = true
        }
        urlArea.forceActiveFocus(Qt.PopupFocusReason)
    }

    onAboutToHide: {
        if (root._holdsModal) {
            RdPanels.releaseModal()
            root._holdsModal = false
        }
        if (_restoreFocusItem)
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
    }

    Component.onDestruction: {
        if (root._holdsModal)
            RdPanels.releaseModal()
    }

    onOpened: {
        if (!urlArea.activeFocus)
            urlArea.forceActiveFocus(Qt.PopupFocusReason)
    }

    // the end of the exit transition may move the focus again
    onClosed: {
        const window = MainCtx.intfMainWindow
        if (_restoreFocusItem && _restoreFocusItem.visible
                && (!window || window.activeFocusItem !== _restoreFocusItem))
            _restoreFocusItem.forceActiveFocus(Qt.PopupFocusReason)
        _restoreFocusItem = null
    }

    // Motion (Decision 32): dialogs open and close instantly, like the Figma prototype and the
    // Settings dialog (the video's fade at 13:09.2 is an editing dissolve)

    // no dim behind the dialog (Decision 41: the video and Figma show none); the transparent
    // overlay still takes the clicks outside the dialog
    T.Overlay.modal: Item { }

    // Figma: Dark/BG/A3 Transparent, radius 14, effect "bg blur + shadow"
    background: Rectangle {
        radius: VLCStyle.rd_radius_large
        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(root.rdPalette.rdBgA3Transparent, 1.0)

        Widgets.RdShadow { }
    }

    contentItem: ColumnLayout {
        spacing: 0

        Accessible.role: Accessible.Dialog
        Accessible.name: qsTr("Open Network Stream")

        // header (Figma "Frame 120"): 50 px, BG/B2, top corners rounded, padding 9
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(50, VLCStyle.scale)

            radius: VLCStyle.rd_radius_large
            color: root.rdPalette.rdBgB2

            // square the bottom corners
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.radius
                color: parent.color
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(19, VLCStyle.scale)
                anchors.right: closeButton.left
                anchors.rightMargin: VLCStyle.dp(10, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter

                text: qsTr("Open Network Stream")
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: root.rdPalette.rdFgA2

                Accessible.ignored: true
            }

            // Figma "Icon Wrapper" 32x32, radius 4, hover #FFFFFF 6%
            T.Button {
                id: closeButton

                // the pointing hand over the clickable controls
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(9, VLCStyle.scale)
                anchors.verticalCenter: parent.verticalCenter

                implicitWidth: VLCStyle.dp(32, VLCStyle.scale)
                implicitHeight: VLCStyle.dp(32, VLCStyle.scale)

                focusPolicy: Qt.StrongFocus

                Accessible.name: qsTr("Close")
                Accessible.onPressAction: closeButton.clicked()

                KeyNavigation.tab: urlArea
                KeyNavigation.backtab: saveButton.enabled ? saveButton : cancelButton

                onClicked: root.close()

                background: Rectangle {
                    radius: VLCStyle.rd_radius_small
                    color: closeButton.hovered ? root.rdPalette.rdHoverOverlay : "transparent"
                    border.width: closeButton.visualFocus ? VLCStyle.dp(1, VLCStyle.scale) : 0
                    border.color: root.rdPalette.rdFg2
                }

                contentItem: Item {
                    Widgets.RdIcon {
                        anchors.centerIn: parent
                        name: "close"
                        color: closeButton.hovered ? root.rdPalette.rdFg2 : root.rdPalette.rdFgA2
                    }
                }
            }
        }

        // body (Figma "Frame 124"): padding 22,20,22,20, gap 20
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: VLCStyle.dp(22, VLCStyle.scale)
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

            spacing: VLCStyle.dp(20, VLCStyle.scale)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: VLCStyle.dp(5, VLCStyle.scale)

                // dialog section title: Inter 400 16 / 28, FG/2
                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("Network URL")
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_header
                    color: root.rdPalette.rdFg2
                }

                // hint: Inter 400 14 / 24.5, FG/A3
                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: VLCStyle.dp(25, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("You can enter multiple links to load.")
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: root.rdPalette.rdFgA3
                }
            }

            // URL box (Figma "Frame 86" 1008x194): BG/B2, 2 px BG/A4 border, radius 6,
            // padding 8,18,8,12; one link per line
            Rectangle {
                id: urlBox

                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(VLCStyle.dp(64, VLCStyle.scale),
                                                 VLCStyle.dp(194, VLCStyle.scale) - (root._designHeight - root.height))

                radius: VLCStyle.rd_radius_normal
                color: root.rdPalette.rdBgB2
                border.width: VLCStyle.dp(2, VLCStyle.scale)
                // accent only for keyboard focus, like RdTextField
                border.color: (urlArea.activeFocus && (urlArea.focusReason === Qt.TabFocusReason
                                                       || urlArea.focusReason === Qt.BacktabFocusReason))
                              ? root.rdPalette.rdAccentMain
                              : (urlHover.hovered ? root.rdPalette.rdDividerBright
                                                  : root.rdPalette.rdBgA4)

                HoverHandler {
                    id: urlHover
                    cursorShape: Qt.IBeamCursor
                }

                Flickable {
                    id: urlFlickable

                    anchors.fill: parent
                    anchors.margins: urlBox.border.width

                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // the attached TextArea sizes the content and follows the cursor;
                    // Figma padding 8,18,8,12 inside the 2 px stroke
                    T.TextArea.flickable: T.TextArea {
                        id: urlArea

                        topPadding: VLCStyle.dp(8, VLCStyle.scale)
                        bottomPadding: VLCStyle.dp(8, VLCStyle.scale)
                        leftPadding: VLCStyle.dp(12, VLCStyle.scale)
                        rightPadding: VLCStyle.dp(18, VLCStyle.scale)

                        wrapMode: TextEdit.Wrap
                        selectByMouse: true

                        font.family: VLCStyle.rd_fontFamily
                        font.pixelSize: VLCStyle.rd_fontSize_label
                        color: root.rdPalette.rdFg2
                        placeholderText: qsTr("e.g., https://www.example.com/stream.avi")
                        placeholderTextColor: root.rdPalette.rdFgA4
                        selectionColor: root.rdPalette.rdAccentDim
                        selectedTextColor: root.rdPalette.rdSelectionText

                        Accessible.name: qsTr("Network URL")

                        onTextChanged: root._updateAutoName()

                        // QtQuick.Templates draw no placeholder
                        Text {
                            x: urlArea.leftPadding
                            y: urlArea.topPadding
                            width: urlArea.width - urlArea.leftPadding - urlArea.rightPadding

                            visible: urlArea.length === 0 && urlArea.preeditText === ""
                            text: urlArea.placeholderText
                            font: urlArea.font
                            color: urlArea.placeholderTextColor
                            elide: Text.ElideRight

                            Accessible.ignored: true
                        }

                        KeyNavigation.priority: KeyNavigation.BeforeItem
                        KeyNavigation.tab: root._showPlaylistName ? nameField : cancelButton
                        KeyNavigation.backtab: closeButton

                        Keys.onPressed: (event) => {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                    && (event.modifiers & Qt.ControlModifier)) {
                                event.accepted = true
                                root.save()
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: VLCStyle.dp(1, VLCStyle.scale)
                visible: root._showPlaylistName
                color: root.rdPalette.rdDividerDim
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root._showPlaylistName
                spacing: VLCStyle.dp(5, VLCStyle.scale)

                // "Playlist Name" FG/2 followed by "(optional)" FG/A3 (Figma text override)
                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: VLCStyle.dp(28, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    textFormat: Text.StyledText
                    text: qsTr("Playlist Name") + " <font color=\"%1\">%2</font>"
                              .arg(root.rdPalette.rdFgA3).arg(qsTr("(optional)"))
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_header
                    color: root.rdPalette.rdFg2
                }

                Text {
                    Layout.fillWidth: true
                    Layout.preferredHeight: VLCStyle.dp(25, VLCStyle.scale)
                    verticalAlignment: Text.AlignVCenter
                    text: qsTr("The playlist will be saved and displayed with this title.")
                    elide: Text.ElideRight
                    font.family: VLCStyle.rd_fontFamily
                    font.pixelSize: VLCStyle.rd_fontSize_label
                    color: root.rdPalette.rdFgA3
                }
            }

            Widgets.RdTextField {
                id: nameField

                // Figma: 37 px field centered in a 41 px row
                Layout.fillWidth: true
                Layout.topMargin: VLCStyle.dp(2, VLCStyle.scale)
                Layout.bottomMargin: VLCStyle.dp(2, VLCStyle.scale)
                visible: root._showPlaylistName

                placeholderText: qsTr("e.g., Favorite TV Channels")

                Accessible.name: qsTr("Playlist Name (optional)")

                KeyNavigation.tab: cancelButton
                KeyNavigation.backtab: urlArea

                // only the user's own edits (the auto name is set from code)
                onTextEdited: root._nameTyped = (text.trim() !== "")
                onAccepted: root.save()
            }

            // Figma body keeps 34 px free under the fields
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // footer (Figma "Frame 225"): 72 px, padding 20, Cancel left, Save right
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: VLCStyle.dp(72, VLCStyle.scale)
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.rightMargin: VLCStyle.dp(20, VLCStyle.scale)

            spacing: VLCStyle.dp(20, VLCStyle.scale)

            Widgets.RdButton {
                id: cancelButton

                text: qsTr("Cancel")

                KeyNavigation.tab: saveButton.enabled ? saveButton : closeButton
                KeyNavigation.backtab: root._showPlaylistName ? nameField : urlArea

                onClicked: root.close()
            }

            Item {
                Layout.fillWidth: true
            }

            Widgets.RdButton {
                id: saveButton

                style: Widgets.RdButton.Style.Save
                text: qsTr("Save")
                enabled: root._canSave

                KeyNavigation.tab: closeButton
                KeyNavigation.backtab: cancelButton

                onClicked: root.save()
            }
        }
    }
}
