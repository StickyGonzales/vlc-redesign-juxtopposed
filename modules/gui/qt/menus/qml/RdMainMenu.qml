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

// redesign: the main "..." menu of the top bar (Decision 2: her last version, Figma "menu" 375 wide;
// video 5:05-5:16, 12:56-13:09, 15:28-15:33, 16:01-16:03, 19:29-19:36). The entries are built in
// C++ (RdMenuModel "main") with VLC's own actions; Keyboard Shortcuts, Customize Player and the
// Profile submenu's entries (W8.2, RdProfiles) are handled here.
import QtQuick
import QtQuick.Templates as T

import VLC.MainInterface
import VLC.Player
import VLC.Style
import VLC.Dialogs
import VLC.Menus

RdCascadeMenu {
    id: root

    rootWidth: VLCStyle.rd_mainMenuWidth

    // opens under `button` (the top bar "..."): the Figma overlay sits 17 px left of the 24 px icon
    // and 38 px below its top, so the menu icons line up under the "..." icon
    function popupBelow(button, keyboard) {
        const iconX = (button.width - VLCStyle.rd_iconSize) / 2
        const iconY = (button.height - VLCStyle.rd_iconSize) / 2
        root.popupAt(button,
                     iconX - VLCStyle.dp(17, VLCStyle.scale),
                     iconY + VLCStyle.dp(38, VLCStyle.scale),
                     keyboard)
    }

    // W8.1b: the "..." button in a bar at the bottom of the window opens the menu above it, its
    // bottom edge 8 px above the button (the rows are counted before the menu opens)
    function popupAbove(button, keyboard) {
        root.model.build()
        const rows = root.model.count - root.model.separatorCount
        const height = rows * VLCStyle.rd_menuRowHeight + root.model.separatorCount * VLCStyle.dp(1)
                       + 2 * VLCStyle.rd_menuPadding
        const iconX = (button.width - VLCStyle.rd_iconSize) / 2
        root.popupAt(button,
                     iconX - VLCStyle.dp(17, VLCStyle.scale),
                     -height - VLCStyle.dp(8, VLCStyle.scale),
                     keyboard)
    }

    model: RdMenuModel {
        kind: "main"
        ctx: MainCtx

        onRequested: (id) => {
            if (id === "keyboardShortcuts") {
                DialogsProvider.keyboardShortcutsDialog()
            } else if (id === "customizePlayer") {
                // VLC's toolbar editor (Customize Player screen: W8.1)
                DialogsProvider.showToolbarEditorDialog()
            } else if (id.startsWith("profile:")) {
                // W8.2: the bars switch at once, the settings follow (RdProfiles)
                if (RdProfiles.busy)
                    return
                // the values the sidebar is still applying reach VLC first
                RdEffects.refresh()
                RdProfiles.select(parseInt(id.substring(8)))
            } else if (id === "newProfile") {
                profilePrompt.askFor("new", qsTr("New Profile"), RdProfiles.uniqueName(qsTr("Profile")))
            } else if (id === "renameProfile") {
                profilePrompt.askFor("rename", qsTr("Rename Profile"), RdProfiles.currentName)
            } else if (id === "deleteProfile") {
                profilePrompt.confirmFor("delete", qsTr("Delete Profile"),
                                         qsTr("Delete the profile “%1”, its layouts and its settings?").arg(RdProfiles.currentName),
                                         qsTr("Delete"))
            }
        }
    }

    // the name of a new profile (Decision 25: then a copy of the current settings), a new name,
    // or the confirmation of a deletion
    CustomizeNamePrompt {
        id: profilePrompt

        // "new", "rename" or "delete"
        property string _mode: ""

        parent: T.Overlay.overlay

        function askFor(mode, title, name) {
            _mode = mode
            ask(title, name)
        }

        function confirmFor(mode, title, message, acceptText) {
            _mode = mode
            confirm(title, message, acceptText)
        }

        onAccepted: (name) => {
            if (RdProfiles.busy)
                return
            switch (_mode) {
            case "new":
                RdEffects.refresh()
                RdProfiles.create(name)
                break
            case "rename":
                RdProfiles.rename(MainCtx.controlbarProfileModel.selectedProfile, name)
                break
            case "delete":
                RdEffects.refresh()
                RdProfiles.removeCurrent()
                break
            }
        }
    }
}
