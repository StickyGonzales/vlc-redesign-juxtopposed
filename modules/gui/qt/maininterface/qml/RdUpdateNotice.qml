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

// redesign: Cone's update notice (util/rd_update_check.cpp, redesign/UPDATE_NOTICE_NOTES.md).
// No Figma frame (Decision 21): the style of the profile notice (RdProfileNotice.qml, after the
// Figma "continue" toast: 52 high pill, radius 16, BG/A3, Inter 16 FG/2, a primary button). It
// takes its place in the notices' stack (RdNoticeStack, POPUP_STACK_NOTES.md): the top one,
// centered over the video area, 24 px above the control bar or above the notices under it, and
// never over the Up Next card's Next episode button. "Download" opens the release page in the browser, "Later" (and Escape
// on its buttons) hides it until the next day, "Skip this version" never offers that version
// again. It never takes the keyboard focus from the player, nor its Escape (fullscreen).
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Widgets as Widgets

T.Popup {
    id: root

    parent: T.Overlay.overlay

    readonly property real _overlayWidth: parent ? parent.width : 0
    // the interface's width (the window less its frame margin), the stack's coordinates
    readonly property real _windowWidth: RdNoticeStack.innerWidth(_overlayWidth)

    // its place over the notices under it: the only part that slides, when one of them comes or
    // goes; a resize, fullscreen or an open panel moves it at once with the rest of the stack
    property real _lift: RdNoticeStack.updateLift()
    Behavior on _lift {
        enabled: root.opened
        NumberAnimation { duration: RdNoticeStack.slideDuration; easing.type: Easing.OutCubic }
    }

    x: RdNoticeStack.overlayX(_overlayWidth, width)
    y: RdNoticeStack.overlayY(parent ? parent.height : 0, height, RdNoticeStack.base(_windowWidth) + _lift)
    width: Math.min(content.implicitWidth, RdNoticeStack.room(_windowWidth))
    height: VLCStyle.dp(52, VLCStyle.scale)

    readonly property bool _shown: visible && opacity > 0
    Binding {
        target: RdNoticeStack
        property: "updateHeight"
        value: root._shown ? root.height : 0
    }
    Binding {
        target: RdNoticeStack
        property: "updateWidth"
        value: root._shown ? root.width : 0
    }
    // gone with its view: its place in the stack goes too
    Component.onDestruction: {
        RdNoticeStack.updateHeight = 0
        RdNoticeStack.updateWidth = 0
    }

    padding: 0
    modal: false
    dim: false
    focus: false
    // a window-wide Escape would leave the player's fullscreen no more: only the buttons take it
    closePolicy: T.Popup.NoAutoClose

    Component.onCompleted: {
        if (RdUpdateCheck.noticeVisible)
            open()
    }

    Connections {
        target: RdUpdateCheck

        function onNoticeVisibleChanged() {
            if (RdUpdateCheck.noticeVisible)
                root.open()
            else
                root.close()
        }
    }

    background: Rectangle {
        radius: VLCStyle.rd_radius_toast
        // opaque: the bg blur cannot run over the native video
        color: Qt.alpha(VLCStyle.palette.rdBgA3Transparent, 1.0)
    }

    contentItem: RowLayout {
        id: content

        spacing: VLCStyle.dp(10, VLCStyle.scale)

        // on the content: a Popup is not an Item, it cannot carry the Accessible properties
        Accessible.role: Accessible.AlertMessage
        Accessible.name: label.text

        T.Label {
            id: label

            Layout.fillWidth: true
            Layout.leftMargin: VLCStyle.dp(20, VLCStyle.scale)
            Layout.alignment: Qt.AlignVCenter
            // rounded up: the layout rounds a fractional text width down, which elided the last
            // letters ("Cone Player 1.0.2 is availa...")
            Layout.preferredWidth: Math.ceil(implicitWidth)

            text: qsTr("%1 %2 is available").arg(Brand.name).arg(RdUpdateCheck.latestVersion)
            elide: Text.ElideRight
            color: VLCStyle.palette.rdFg2
            font.family: VLCStyle.rd_fontFamily
            font.pixelSize: VLCStyle.rd_fontSize_header
        }

        Widgets.RdButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: VLCStyle.dp(30, VLCStyle.scale)

            style: Widgets.RdButton.Style.Primary
            text: qsTr("Download")
            focusPolicy: Qt.TabFocus

            onClicked: RdUpdateCheck.download()
            Keys.onEscapePressed: RdUpdateCheck.later()
        }

        Widgets.RdButton {
            Layout.alignment: Qt.AlignVCenter

            style: Widgets.RdButton.Style.Plain
            text: qsTr("Later")
            focusPolicy: Qt.TabFocus

            onClicked: RdUpdateCheck.later()
            Keys.onEscapePressed: RdUpdateCheck.later()
        }

        // never offers this exact version again; a newer one still shows (Settings > General
        // can undo it)
        Widgets.RdButton {
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: VLCStyle.dp(10, VLCStyle.scale)

            style: Widgets.RdButton.Style.Plain
            text: qsTr("Skip this version")
            focusPolicy: Qt.TabFocus

            onClicked: RdUpdateCheck.skipVersion()
            Keys.onEscapePressed: RdUpdateCheck.later()
        }
    }
}
