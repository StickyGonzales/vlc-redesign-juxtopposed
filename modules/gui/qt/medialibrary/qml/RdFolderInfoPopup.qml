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

// redesign: "Info" of the folder menu (video 10:52-10:57, P5-15): the folder's name and where it
// is on disk, in the style of the info popovers (Decision 26, RdTooltip look).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets
import VLC.MediaLibrary

T.Popup {
    id: popup

    // while open, keys go to the popup instead of VLC's hotkeys over the player
    // (RdPanels.modalCount, see menus/qml/RdCascadeMenu.qml)
    property bool _holdsModal: false

    // the item that had the focus before the popup opened gets it back when it closes
    property Item _opener: null

    onAboutToShow: {
        if (!popup._holdsModal) {
            RdPanels.acquireModal()
            popup._holdsModal = true
        }
        const window = popup.parent ? popup.parent.Window.window : null
        popup._opener = window ? window.activeFocusItem : null
    }

    onAboutToHide: {
        if (popup._holdsModal) {
            RdPanels.releaseModal()
            popup._holdsModal = false
        }
    }

    onClosed: {
        const opener = popup._opener
        popup._opener = null
        if (opener && opener.visible && opener.enabled)
            opener.forceActiveFocus(Qt.PopupFocusReason)
    }

    Component.onDestruction: {
        if (popup._holdsModal)
            RdPanels.releaseModal()
    }

    // a dialog opening (Ctrl+P, Ctrl+N, ...) closes the popover first
    readonly property Connections _dialogConnections: Connections {
        target: DialogsProvider

        function onDialogOpening() {
            popup.close()
        }
    }

    property string folderTitle: ""
    property string location: ""

    function show(item) {
        folderTitle = item.title ?? ""
        const url = item.mrl ?? ""
        location = url.startsWith("file://") ? RdLibraryNav.decoded(url.replace(/^file:\/\/\/?/, "")) : url
        open()
    }

    parent: T.Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(VLCStyle.dp(420), parent ? parent.width - VLCStyle.dp(40) : VLCStyle.dp(420))
    // a Templates popup has no implicit height of its own (it was only its padding high, the
    // text ran out of its background)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    // Figma info popover ("audio value"): padding 10, radius 6
    padding: VLCStyle.dp(10)
    modal: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    background: Rectangle {
        radius: VLCStyle.rd_radius_normal
        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(VLCStyle.palette.rdBgB1Transparent, 1.0)

        Widgets.RdShadow { }
    }

    contentItem: Column {
        spacing: VLCStyle.dp(8)

        Row {
            spacing: VLCStyle.dp(10)

            Widgets.RdIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: "folder"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: popup.availableWidth - VLCStyle.rd_iconSize - VLCStyle.dp(10)
                elide: Text.ElideRight
                text: popup.folderTitle
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_header
                color: VLCStyle.palette.rdFg2
            }
        }

        Text {
            width: popup.availableWidth
            wrapMode: Text.WrapAnywhere
            text: popup.location
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            color: VLCStyle.palette.rdFgA3
        }
    }
}
