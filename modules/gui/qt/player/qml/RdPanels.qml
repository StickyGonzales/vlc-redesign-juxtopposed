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

// redesign: which player panel is open (Figma "Controls" variants, F-06). The control bar buttons
// toggle a panel: clicking the same button again closes it, clicking another one switches.
//   tracks popup:      "video", "audio", "subtitles"
//   settings sidebar:  "playback", "videoSettings", "audioSettings", "subtitleSettings"
//   queue sidebar:     "queue", "bookmarks", "chapters"
// It also holds the player's Hide UI state (video 5:25-5:30, Ctrl + \ and the right-click menu):
// no bars and no panel, only the video.
pragma Singleton

import QtQml

import VLC.Dialogs

QtObject {
    id: root

    property string current: ""
    property bool uiHidden: false

    readonly property bool tracksOpen: current === "video" || current === "audio" || current === "subtitles"
    readonly property bool settingsOpen: current === "playback" || current === "videoSettings"
                                         || current === "audioSettings" || current === "subtitleSettings"
    readonly property bool queueOpen: current === "queue" || current === "bookmarks" || current === "chapters"

    function toggle(name) {
        current = (current === name) ? "" : name
    }

    function open(name) {
        current = name
    }

    function close() {
        current = ""
    }

    // a dialog opening (a shortcut such as Ctrl+P, a menu entry, a panel button) closes the panel
    // first, so it never stays open behind the dialog; menus and popups listen to the same signal
    property Connections _dialogs: Connections {
        target: DialogsProvider

        function onDialogOpening() {
            root.current = ""
        }
    }

    // Modal redesign popups (menus, dialogs) that are open. While the player is shown VLC sends
    // every key to its hotkeys unless the focused item shows keyboard focus
    // (MainCtx.preferHotkeys); a modal popup needs the keys itself (Escape, arrows, Space,
    // typing), so Player.qml prefers hotkeys only while this is 0. A popup calls acquireModal()
    // when it opens and releaseModal() when it closes (and on destruction while open); a count
    // keeps nested popups (a menu opening a dialog) correct.
    property int modalCount: 0

    function acquireModal() {
        modalCount += 1
    }

    function releaseModal() {
        modalCount = Math.max(0, modalCount - 1)
    }

    // the compact library docked on the left of the player (video 11:37-11:59, P5-23): opened and
    // closed by the top bar's sidebar toggle and folder chip. Kept here, not in Player.qml, so
    // the player finds it open again after a visit to the full library (11:58).
    property bool libraryOpen: false

    // the height of the player's control bar (one 54 px row, two when the seek row has its own
    // row, ControlBar), set by Player.qml; 0 while no player exists. Overlays outside the player
    // (RdProfileNotice) keep clear of it.
    property real controlBarHeight: 0

    // the sidebar toggle (reveal false) and the folder chip (reveal true) controls, in either bar
    // (W8.1b): Player.qml opens or closes the compact library (toggleLibrary)
    signal libraryRequested(bool reveal)

    // the info overlays over the video, switched by the settings sidebar's Playback tab
    // toggles "Show Metadata" and "Show Statistics" (W4.3b; Decisions 13 and 24). They are not
    // panels: they stay open next to any panel until switched off (toggle or their X), are kept
    // while VLC runs, and hide with the rest of the UI (Hide UI).
    property bool metadataShown: false
    property bool statisticsShown: false

    // hiding the UI closes every panel; showing it again brings the bars back, not the panels
    function toggleUi() {
        if (!uiHidden) {
            current = ""
            libraryOpen = false
        }
        uiHidden = !uiHidden
    }
}
