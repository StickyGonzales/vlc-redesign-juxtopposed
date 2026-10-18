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

// redesign (W8.1b, the top bar's sidebar toggle, video 11:37): opens and closes the compact
// library next to the video (Player.qml, through RdPanels.libraryRequested)
import QtQuick

import VLC.MainInterface
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

Widgets.IconToolButton {
    id: root

    enabled: MainCtx.playerView

    text: VLCIcons.panel_left
    rdIcon: "sidebar_direction-left"
    // Figma "sidebar" icon state=active: the filled panel, in the icon's own color
    rdIconChecked: "sidebar_state-active"
    color: colorContext.fg.primary
    description: qsTr("Library")

    checked: !paintOnly && MainCtx.mediaLibraryAvailable && RdPanels.libraryOpen

    onClicked: RdPanels.libraryRequested(false)

    AccessibleCompat.id: "libraryToggleButton"
}
