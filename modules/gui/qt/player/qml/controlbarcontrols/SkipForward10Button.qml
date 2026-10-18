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

// redesign (W8.1b, Figma "Player - customize" item "Forwardward 10s"): a 10 s jump, relative to
// where the player is so quick clicks add up (the "Forwardward 15s" item is VLC's skip button)
import QtQuick

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Player
import VLC.Util

Widgets.IconToolButton {
    id: root

    readonly property int jumpSeconds: 10

    enabled: Player.seekable

    text: VLCIcons.skip_for
    rdIcon: "forward-10-sec"
    description: qsTr("Forward %1 second", "Forward %1 seconds", jumpSeconds).arg(jumpSeconds)

    onClicked: Player.jumpSeconds(jumpSeconds)

    AccessibleCompat.id: "skipForward10Button"
}
