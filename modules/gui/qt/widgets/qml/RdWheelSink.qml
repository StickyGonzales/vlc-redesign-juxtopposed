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

// redesign: takes the mouse wheel that nothing inside an overlay (card, panel, sidebar) used, so it
// never reaches what lies behind it: the player turns the wheel into volume or seek, a library list
// would scroll (Decision 54). It fills the overlay under its content, so the overlay's lists and
// sliders still get the wheel first. Takes no clicks and no hover.
import QtQuick

MouseArea {
    acceptedButtons: Qt.NoButton
    onWheel: (wheel) => { wheel.accepted = true }
}
