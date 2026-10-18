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

// redesign (W8.1a / W8.2): asks for a profile name (the main menu's "+ New" and Rename), or
// confirms an action that cannot be undone (Delete Profile: confirm()). No Figma frame
// (Decision 21): the redesign dialog style (BG/B1 box, radius 14, BG/B2 header with the title
// FG/A2, RdTextField or the message in FG/A2, Cancel / Save footer like Figma's dialogs).
// Enter saves, Escape or a click outside cancels; the keys stay in the prompt while it is open
// (RdPanels.acquireModal) and the focus goes back where it was.
import QtQuick
import QtQuick.Templates as T
import QtQuick.Window

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    property string title: ""
    // confirm(): the question instead of the name field, and the accept button's text
    property string message: ""
    property string acceptText: qsTr("Save")

    signal accepted(string name)

    function ask(title, name) {
        root.title = title
        root.message = ""
        root.acceptText = qsTr("Save")
        nameField.text = name
        open()
    }

    function confirm(title, message, acceptText) {
        root.title = title
        root.message = message
        root.acceptText = acceptText
        nameField.text = ""
        open()
    }

    property Item _restoreFocusItem: null
    property bool _holdsModal: false

    onAboutToShow: {
        const window = root.parent ? root.parent.Window.window : null
        root._restoreFocusItem = window ? window.activeFocusItem : null
        if (!root._holdsModal) {
            RdPanels.acquireModal()
            root._holdsModal = true
        }
    }

    onAboutToHide: {
        if (root._holdsModal) {
            RdPanels.releaseModal()
            root._holdsModal = false
        }
    }

    onClosed: {
        const item = root._restoreFocusItem
        root._restoreFocusItem = null
        if (item && item.visible)
            item.forceActiveFocus(Qt.PopupFocusReason)
    }

    Component.onDestruction: {
        if (root._holdsModal)
            RdPanels.releaseModal()
    }

    anchors.centerIn: parent

    width: Math.min(VLCStyle.dp(400), parent ? parent.width - 2 * VLCStyle.margin_large : VLCStyle.dp(400))
    height: content.implicitHeight

    padding: 0
    modal: true
    dim: false
    focus: true
    closePolicy: T.Popup.CloseOnEscape | T.Popup.CloseOnPressOutside

    onOpened: {
        if (root.message !== "") {
            saveButton.forceActiveFocus(Qt.PopupFocusReason)
            return
        }
        nameField.selectAll()
        nameField.forceActiveFocus(Qt.PopupFocusReason)
    }

    function _accept() {
        const name = nameField.text.trim()
        if (root.message === "" && name === "")
            return
        close()
        accepted(name)
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_large
        color: Qt.alpha(VLCStyle.palette.rdBgB1Transparent, 1.0)

        Widgets.RdShadow { }
    }

    contentItem: Column {
        id: content

        // keys the prompt does not handle stay in it; Escape goes on to the popup, which closes
        Keys.onPressed: (event) => {
            event.accepted = (event.key !== Qt.Key_Escape && event.key !== Qt.Key_Back)
        }

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
                anchors.right: parent.right
                anchors.leftMargin: VLCStyle.dp(19)
                anchors.rightMargin: VLCStyle.dp(19)
                anchors.verticalCenter: parent.verticalCenter

                text: root.title
                elide: Text.ElideRight
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA2

                Accessible.role: Accessible.TitleBar
                Accessible.name: text
            }
        }

        Item {
            width: parent.width
            height: (root.message !== "" ? messageText.implicitHeight : nameField.height) + 2 * VLCStyle.dp(20)

            Text {
                id: messageText

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                visible: root.message !== ""
                text: root.message
                wrapMode: Text.Wrap
                font.family: VLCStyle.rd_fontFamily
                font.pixelSize: VLCStyle.rd_fontSize_label
                color: VLCStyle.palette.rdFgA2
            }

            Widgets.RdTextField {
                id: nameField

                visible: root.message === ""

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                placeholderText: qsTr("Profile name")
                Accessible.name: root.title

                KeyNavigation.tab: cancelButton
                KeyNavigation.backtab: saveButton.enabled ? saveButton : cancelButton

                Keys.onReturnPressed: root._accept()
                Keys.onEnterPressed: root._accept()
            }
        }

        Item {
            width: parent.width
            height: VLCStyle.rd_dialogFooterHeight

            Widgets.RdButton {
                id: cancelButton

                anchors.left: parent.left
                anchors.leftMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                text: qsTr("Cancel")

                KeyNavigation.tab: saveButton.enabled ? saveButton : nameField
                KeyNavigation.backtab: root.message !== "" ? saveButton : nameField

                onClicked: root.close()
            }

            Widgets.RdButton {
                id: saveButton

                anchors.right: parent.right
                anchors.rightMargin: VLCStyle.dp(20)
                anchors.verticalCenter: parent.verticalCenter

                style: Widgets.RdButton.Style.Save
                text: root.acceptText
                enabled: root.message !== "" || nameField.text.trim() !== ""

                KeyNavigation.tab: root.message !== "" ? cancelButton : nameField
                KeyNavigation.backtab: cancelButton

                Keys.onReturnPressed: root._accept()
                Keys.onEnterPressed: root._accept()

                onClicked: root._accept()
            }
        }
    }
}
