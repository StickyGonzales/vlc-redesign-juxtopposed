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

// redesign (W8.1b, Figma "Player - customize" item "Right Sidebar"): opens and closes the
// player's right sidebar, the settings sidebar on its Playback tab (Decision 5, as the gear)
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

Widgets.IconToolButton {
    id: root

    // the sidebar belongs to the player page
    enabled: MainCtx.playerView

    text: VLCIcons.panel_left
    rdIcon: "sidebar_direction-right"
    description: qsTr("Right Sidebar")

    checked: MainCtx.playerView && RdPanels.settingsOpen

    onClicked: {
        if (RdPanels.settingsOpen)
            RdPanels.close()
        else
            RdPanels.open("playback")
    }

    AccessibleCompat.id: "rightSidebarButton"
}
