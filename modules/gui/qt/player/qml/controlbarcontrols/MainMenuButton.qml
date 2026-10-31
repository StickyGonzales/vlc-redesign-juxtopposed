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

// redesign (W8.1b, the top bar's "..." button): the main menu (W4.9, Figma "menu"), below the
// button in the top bar (Figma: 17 px left, 38 px below the icon) and above it in a bar at the
// bottom of the window. The bars stay shown while the menu is open.
import QtQuick
import QtQuick.Window

import VLC.Widgets as Widgets
import VLC.Style
import VLC.Menus as Menus
import VLC.Util

Widgets.IconToolButton {
    id: root

    signal requestLockUnlockAutoHide(bool lock)

    text: VLCIcons.more
    rdIcon: "more"
    description: qsTr("Menu")

    checked: mainMenu.visible

    onPressed: console.warn("DIAGMENU " + Date.now() + " mmb pressed")
    onReleased: console.warn("DIAGMENU " + Date.now() + " mmb released")
    onCanceled: console.warn("DIAGMENU " + Date.now() + " mmb canceled")
    onHoveredChanged: console.warn("DIAGMENU " + Date.now() + " mmb hovered=" + hovered)
    onVisibleChanged: console.warn("DIAGMENU " + Date.now() + " mmb visible=" + visible)
    Component.onDestruction: console.warn("DIAGMENU " + Date.now() + " mmb destroyed")
    Component.onCompleted: console.warn("DIAGMENU " + Date.now() + " mmb created")
    onClicked: {
        console.warn("DIAGMENU " + Date.now() + " mmb clicked y=" + root.mapToItem(null, 0, 0).y)
        const window = root.Window.window
        if (!!window && root.mapToItem(null, 0, 0).y > window.height / 2)
            mainMenu.popupAbove(root, visualFocus)
        else
            mainMenu.popupBelow(root, visualFocus)
    }

    function forceUnlock() {
        console.warn("DIAGMENU " + Date.now() + " mmb forceUnlock")
        // called while the bar is torn down too, when the menu is already gone
        mainMenu?.close()
    }

    Menus.RdMainMenu {
        id: mainMenu

        onAboutToShow: { console.warn("DIAGMENU " + Date.now() + " mmb menu aboutToShow"); root.requestLockUnlockAutoHide(true) }
        onAboutToHide: { console.warn("DIAGMENU " + Date.now() + " mmb menu aboutToHide"); console.trace(); root.requestLockUnlockAutoHide(false) }
        onOpened: console.warn("DIAGMENU " + Date.now() + " mmb menu opened")
        onClosed: console.warn("DIAGMENU " + Date.now() + " mmb menu closed")
    }

    AccessibleCompat.id: "topBarMenuButton"
}
