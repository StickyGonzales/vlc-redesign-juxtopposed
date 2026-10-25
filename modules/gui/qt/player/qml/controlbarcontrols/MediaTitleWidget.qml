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

// redesign (W8.1b, the top bar's title, Figma "topbar" / "Frame 229", video 19:24 moves it into
// the bottom bar): the playing media's title, or VLC's display name (the file name) when it has
// no title tag, centered in its place and elided when the bar is short of room
import QtQuick

import VLC.Player
import VLC.Style

TextInfoWidget {
    text: paintOnly && Player.title === "" && Player.name === ""
          ? "" : (Player.title !== "" ? Player.title : Player.name)
    placeholder: qsTr("Title")
    maximumWidth: VLCStyle.dp(640, VLCStyle.scale)
    horizontalAlignment: Text.AlignHCenter
}
