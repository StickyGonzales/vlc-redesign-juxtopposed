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

// redesign: one page of the right sidebar (RdSidePanel), created on first use (INTERACTIONS.md
// section 0): when its tab is selected the first time (synchronously, so it shows in the same
// frame), or in the background once the sidebar has been shown, so that switching tabs is
// instant. Once created the page is kept. The page cross-fades when its tab is selected (video
// 8:40, IA-37).
//   RdSidePanelPageLoader { key: "audioSettings"; sourceComponent: AudioSettingsPage { } }
import QtQuick

import VLC.MainInterface
import VLC.Style

Loader {
    id: root

    // the tab key of the page
    required property string key

    // the pages host of RdSidePanel provides currentKey and prewarm
    readonly property bool current: !!parent && parent.currentKey === key

    anchors.fill: parent

    active: false
    // a page that is needed now is created at once
    asynchronous: !current

    opacity: current ? 1 : 0
    visible: opacity > 0
    enabled: current

    // the tab icons and underlines fade with the same timing (RdSidePanel); instant when the
    // system's animations are off
    Behavior on opacity {
        enabled: MainCtx.systemAnimations

        NumberAnimation {
            duration: VLCStyle.rd_tabSwitchDuration
            easing.type: Easing.OutQuad
        }
    }

    Binding on active {
        when: root.current || (!!root.parent && root.parent.prewarm)
        value: true
        restoreMode: Binding.RestoreNone
    }
}
