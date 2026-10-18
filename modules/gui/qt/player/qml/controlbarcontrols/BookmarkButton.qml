/*****************************************************************************
 * Copyright (C) 2021 VLC authors and VideoLAN
 *
 * Authors: Benjamin Arnaud <bunjee@omega.gg>
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

import QtQuick


import VLC.MainInterface
import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

Widgets.IconToolButton {
    id: root

    signal requestLockUnlockAutoHide(bool lock)

    text: VLCIcons.bookmark
    // redesign (W8.1b, Figma "Player - customize" item "Bookmarks")
    rdIcon: "bookmarks"
    description: qsTr("Bookmarks")

    AccessibleCompat.id: "bookmarkButton"

    // redesign: in the player the button opens the queue sidebar on its Bookmarks tab (Decision
    // 3, where Ctrl + B bookmarks are listed); elsewhere it keeps VLC's bookmarks menu
    checked: !paintOnly && MainCtx.playerView && RdPanels.current === "bookmarks"

    // NOTE: We want to pop the menu above the button.
    onClicked: {
        if (MainCtx.playerView) {
            if (RdPanels.current === "bookmarks")
                RdPanels.close()
            else
                RdPanels.open("bookmarks")
            return
        }
        menu.popup(this.mapToGlobal(0, 0), true)
    }

    enabled: !paintOnly && (Player.hasChapters || Player.hasTitles || MainCtx.mediaLibraryAvailable)

    QmlBookmarkMenu {
        id: menu

        ctx: MainCtx

        player: Player

        onAboutToShow: root.requestLockUnlockAutoHide(true)
        onAboutToHide: root.requestLockUnlockAutoHide(false)
    }

    function forceUnlock() {
        if(menu)
            menu.close()
    }
}
