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

// redesign (W8.1b): an icon button of the bars that opens a short list of choices in the
// redesign menu style (RdMenuPanel, RdOptionRow with the accent check on the current one),
// above the button in the lower half of the window and below it in the upper half (the top
// bar). The bars stay shown while the list is open. Rows: RdOptionRow items declared inside.
import QtQuick
import QtQuick.Window

import VLC.Widgets as Widgets
import VLC.Style

Widgets.IconToolButton {
    id: root

    default property alias menuItems: menu.items

    signal requestLockUnlockAutoHide(bool lock)

    checked: menu.visible

    onClicked: {
        if (menu.visible) {
            menu.close()
            return
        }
        menu.keyboard = visualFocus
        menu.open()
    }

    function forceUnlock() {
        menu.close()
    }

    // (held by a property, not a child: the children of this file's users go into its rows)
    readonly property Widgets.RdMenuPanel _menu: Widgets.RdMenuPanel {
        id: menu

        parent: root

        x: Math.round((root.width - width) / 2)

        onAboutToShow: {
            const window = root.Window.window
            const above = !!window && root.mapToItem(null, 0, 0).y > window.height / 2
            y = above ? -implicitHeight - VLCStyle.dp(4) : root.height + VLCStyle.dp(4)
            root.requestLockUnlockAutoHide(true)
        }

        onAboutToHide: root.requestLockUnlockAutoHide(false)
    }
}
