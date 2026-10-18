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

// redesign: frame of the library dialogs (Figma "new playlist" 713x589 and "Open network
// stream" 1048x631): BG/A3 95%, radius 14; a 50 px BG/B2 header with the title (Inter 400 14
// FG/A2) and a close icon; the body with padding 22,20 and gap 20; a 72 px footer with Cancel
// on the left and Save on the right (Save BG/Accent Bright + Accent/Main, half transparent until
// the dialog can save).
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Dialogs
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: dialog

    // while open, keys go to the dialog instead of VLC's hotkeys over the player
    // (RdPanels.modalCount, see menus/qml/RdCascadeMenu.qml)
    property bool _holdsModal: false

    // the item that had the focus before the popup opened gets it back when it closes
    property Item _opener: null

    onAboutToShow: {
        // the menus, popups and player panels close first (the menu that opened this dialog
        // gives the focus back to its button, which gets it again when the dialog closes)
        DialogsProvider.dialogOpening()
        if (!dialog._holdsModal) {
            RdPanels.acquireModal()
            dialog._holdsModal = true
        }
        const window = dialog.parent ? dialog.parent.Window.window : null
        dialog._opener = window ? window.activeFocusItem : null
    }

    onAboutToHide: {
        if (dialog._holdsModal) {
            RdPanels.releaseModal()
            dialog._holdsModal = false
        }
    }

    onClosed: {
        const opener = dialog._opener
        dialog._opener = null
        if (opener && opener.visible && opener.enabled)
            opener.forceActiveFocus(Qt.PopupFocusReason)
    }

    Component.onDestruction: {
        if (dialog._holdsModal)
            RdPanels.releaseModal()
    }

    property string title: ""
    property bool canSave: true
    // the right button (Figma "Save"; the action's name in a confirmation)
    property string saveText: qsTr("Save")
    property real preferredWidth: VLCStyle.dp(713)
    default property alias body: bodyColumn.data
    // width of the body's children
    readonly property real bodyWidth: width - VLCStyle.dp(40)

    signal saved()

    // keyboard focus on the right button (a confirmation is answered with Space, Escape cancels)
    function focusSaveButton() {
        saveButton.forceActiveFocus(Qt.TabFocusReason)
    }

    parent: T.Overlay.overlay
    anchors.centerIn: parent
    // a Templates popup has no implicit size of its own: without these the dialog was 0 high,
    // its top sat at the window's centre, the body had no background and the footer ran out
    // of the window under the control bar (P6-16, IB-30)
    implicitWidth: Math.max(implicitBackgroundWidth + leftInset + rightInset,
                            implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding)
    // inside the window with 20 around it, over the bars (the body scrolls when it is too low)
    width: Math.min(preferredWidth, parent ? parent.width - VLCStyle.dp(40) : preferredWidth)
    height: Math.min(implicitHeight, parent ? parent.height - VLCStyle.dp(40) : implicitHeight)

    modal: true
    focus: true
    padding: 0
    closePolicy: T.Popup.CloseOnEscape

    // no dim behind the dialog (Decision 41: the video and Figma show none); the transparent
    // overlay still takes the clicks outside the dialog
    T.Overlay.modal: Item { }

    background: Rectangle {
        radius: VLCStyle.rd_radius_large
        // opaque over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)

        Widgets.RdShadow { }
    }

    contentItem: Column {
        // header
        Rectangle {
            width: parent.width
            height: VLCStyle.dp(50)
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

            Text {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(19)
                anchors.verticalCenter: parent.verticalCenter
                text: dialog.title
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA2
            }

            RdLibraryIconButton {
                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(9)
                anchors.verticalCenter: parent.verticalCenter
                width: VLCStyle.dp(32)
                height: VLCStyle.dp(32)
                iconName: "close"
                description: qsTr("Close")
                onClicked: dialog.close()
                // Escape closes the dialog, not the library page behind it
                Navigation.cancelAction: () => dialog.close()
            }
        }

        // body: scrolls when the window is too low for it, so the footer stays inside
        Flickable {
            width: parent.width
            height: Math.min(bodyColumn.implicitHeight,
                             dialog.parent ? Math.max(0, dialog.parent.height - VLCStyle.dp(40)
                                                         - VLCStyle.dp(50) - VLCStyle.dp(72))
                                           : bodyColumn.implicitHeight)
            contentWidth: width
            contentHeight: bodyColumn.implicitHeight
            clip: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: bodyColumn

                width: parent.width
                topPadding: VLCStyle.dp(22)
                bottomPadding: VLCStyle.dp(22)
                leftPadding: VLCStyle.dp(20)
                rightPadding: VLCStyle.dp(20)
                spacing: VLCStyle.dp(20)
            }
        }

        // footer
        Item {
            width: parent.width
            height: VLCStyle.dp(72)

            Widgets.RdButton {
                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Cancel")
                onClicked: dialog.close()
            }

            Widgets.RdButton {
                id: saveButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter
                style: Widgets.RdButton.Style.Save
                text: dialog.saveText
                enabled: dialog.canSave
                onClicked: {
                    dialog.saved()
                    dialog.close()
                }
            }
        }
    }

    // a titled part of the body (Figma: title Inter 400 16 / 28 FG/2, hint 400 14 / 24.5 FG/A3)
    component Section: Column {
        property string title: ""
        property string note: ""
        property string hint: ""

        spacing: VLCStyle.dp(5)

        Text {
            width: parent.width
            textFormat: Text.StyledText
            text: parent.note === "" ? parent.title
                                     : "%1 <font color=\"%2\">%3</font>".arg(parent.title)
                                                                         .arg(VLCStyle.palette.rdFgA3)
                                                                         .arg(parent.note)
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
            lineHeight: VLCStyle.dp(28)
            lineHeightMode: Text.FixedHeight
            color: VLCStyle.palette.rdFg2
        }

        Text {
            visible: parent.hint !== ""
            width: parent.width
            wrapMode: Text.WordWrap
            text: parent.hint
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_label
            // Figma: line height 24.5
            lineHeight: VLCStyle.dp(24.5)
            lineHeightMode: Text.FixedHeight
            color: VLCStyle.palette.rdFgA3
        }
    }
}
