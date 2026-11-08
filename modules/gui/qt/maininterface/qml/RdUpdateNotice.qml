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
// Figma "continue" toast: 52 high pill, radius 16, BG/A3, Inter 16 FG/2, a primary button),
// centered over the bottom of the window, 18 px above the control bar (above the window's
// bottom in the library). "Download" opens the release page in the browser, "Later" (and Escape
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

    x: Math.round(((parent ? parent.width : 0) - width) / 2)
    // the library has no control bar: the notice sits 18 px above the window's bottom there
    readonly property real _barHeight: (MainCtx.effectiveMainInterfaceMode !== MainCtx.MAININTERFACE_MODE_PLAYER) ? 0
                                       : (RdPanels.controlBarHeight > 0) ? RdPanels.controlBarHeight
                                                                         : VLCStyle.rd_controlBarHeight

    y: (parent ? parent.height : 0) - height - _barHeight - VLCStyle.dp(18, VLCStyle.scale)
    width: Math.min(content.implicitWidth, (parent ? parent.width : 0) - 2 * VLCStyle.margin_large)
    height: VLCStyle.dp(52, VLCStyle.scale)

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
