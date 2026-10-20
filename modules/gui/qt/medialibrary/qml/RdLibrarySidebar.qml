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

// redesign: the compact library next to the video (video 11:37-11:59, 12:00-13:48; P5-23, IB-12,
// IB-13, IB-14, P5-25; Figma "sidebar" 427 wide = rail 50 + panel 377, panel BG/B1 95% with
// padding 20 and gap 17, a Divider/Dim line above the rows; Player.png, Player - Music-1.png).
// The user never has to leave the video (11:41).
//
// Hosted by the player page (Player.qml, PC session): docked on the left between the top bar and
// the control bar, the video area to its right; opened and closed by the top bar's sidebar
// toggle and folder chip with a 208 ms "slow" animation (F-16). See LIBRARY_NOTES.md.
import QtQuick

import VLC.MainInterface
import VLC.Style
import VLC.MediaLibrary

FocusScope {
    id: root

    implicitWidth: VLCStyle.rd_libraryRailWidth + VLCStyle.rd_libraryPanelWidth

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Library")

    // the folder chip of the top bar (11:24-11:31): the folder of the playing file
    function revealMrl(mrl) {
        if (!mrl)
            return
        RdLibraryStore.resolveFolder(mrl, (result) => {
            if (result)
                RdLibraryNav.openFolderPath(result)
        })
    }

    // the player's Escape goes back first while there is a page to go back to
    readonly property bool canGoBack: RdLibraryNav.canGoBack

    // mouse back and forward buttons over the player
    function goBack() {
        RdLibraryNav.goBack()
    }

    function goForward() {
        RdLibraryNav.goForward()
    }

    // Ctrl+F
    function focusSearch() {
        header.focusSearch()
    }

    RdLibraryRail {
        id: rail

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: VLCStyle.rd_libraryRailWidth
    }

    Rectangle {
        id: panel

        anchors.left: rail.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: VLCStyle.rd_libraryPanelWidth
        // opaque: it slides over the native video (Figma's 95 % assumes a background blur)
        color: Qt.alpha(VLCStyle.palette.rdBgB1Transparent, 1.0)

        RdLibraryHeader {
            id: header

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: VLCStyle.dp(20)

            compact: true
            page: content.page

            // the full library opens at the same place (11:47-11:48)
            onOpenFullRequested: MainCtx.playerView = false
        }

        Rectangle {
            id: divider

            anchors.left: header.left
            anchors.right: header.right
            anchors.top: header.bottom
            anchors.topMargin: VLCStyle.dp(17)
            height: VLCStyle.dp(1)
            color: VLCStyle.palette.rdDividerDim
        }

        RdLibraryContent {
            id: content

            anchors.left: header.left
            anchors.right: header.right
            // Figma: the rows start 20 below the divider's line
            anchors.top: divider.top
            anchors.topMargin: VLCStyle.dp(20)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: VLCStyle.dp(20)

            compact: true
            focus: true
        }
    }
}
