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

// redesign: where Cone's notices at the bottom of the window go (redesign/POPUP_STACK_NOTES.md).
// The resume toast (Figma "continue"), the profile notice and the update notice share one place:
// centered over the video area, Figma's 24 px above the control bar (24 px above the window's
// bottom in Hide UI and in the library). When more than one shows they stack upwards in a fixed
// order, 10 px apart (Figma's spacing between the toast's parts; Figma shows one notice at a
// time), all on the same center line; when one closes, the ones above slide down into its place.
//   order, bottom to top: resume toast (it belongs to the file that just started, next to the
//   controls), profile notice, update notice
// The Up Next card (bottom right) keeps its place: the whole stack moves up above it whenever the
// widest notice would reach it, so no notice ever covers its Next episode button. The on-screen
// message has its own place at the top (RdOsdMessage) and the tray popup is its own window.
// Each notice reports its size while it shows (0 otherwise) and reads its bottom from here.
pragma Singleton

import QtQml
import QtQuick

import VLC.MainInterface
import VLC.Style

QtObject {
    id: root

    // reported by the notices while they show, 0 when hidden
    property real resumeHeight: 0
    property real resumeWidth: 0
    property real profileHeight: 0
    property real profileWidth: 0
    property real updateHeight: 0
    property real updateWidth: 0

    // set by Player.qml while the player view exists: the center line's offset from the window's
    // center (the compact library on the left, an open panel on the right) and the widest a
    // notice may be there; outside the player the notices center over the whole window
    property bool playerShown: false
    property real axisOffset: 0
    property real playerRoom: 0

    // set by Player.qml while the Up Next card shows: its left edge from the window's left
    property real upNextLeft: 0

    readonly property real gap: VLCStyle.dp(10, VLCStyle.scale)
    readonly property real edgeGap: VLCStyle.dp(24, VLCStyle.scale)
    // the stack slides into place over 200 ms (the performance rule's limit)
    readonly property int slideDuration: 200

    readonly property bool _inPlayer: playerShown
                                      && MainCtx.effectiveMainInterfaceMode === MainCtx.MAININTERFACE_MODE_PLAYER

    readonly property real _barHeight: (!_inPlayer || RdPanels.uiHidden) ? 0
                                       : (RdPanels.controlBarHeight > 0) ? RdPanels.controlBarHeight
                                                                         : VLCStyle.rd_controlBarHeight

    // the widest notice that shows: the stack's footprint, for the Up Next test
    readonly property real _widest: Math.max(resumeWidth, profileWidth, updateWidth)

    function centerX(windowWidth) {
        return windowWidth / 2 + (_inPlayer ? axisOffset : 0)
    }

    // the widest a notice may get in a window this wide
    function room(windowWidth) {
        return (_inPlayer && playerRoom > 0) ? playerRoom
                                             : windowWidth - 2 * VLCStyle.margin_large
    }

    // the stack's bottom, from the window's bottom: above the control bar, and above the Up Next
    // card when the widest notice would reach it
    function base(windowWidth) {
        const b = _barHeight + edgeGap
        if (RdPanels.upNextCardTop <= 0 || _widest <= 0)
            return b
        if (centerX(windowWidth) + _widest / 2 + gap <= upNextLeft)
            return b
        return Math.max(b, RdPanels.upNextCardTop + gap)
    }

    function resumeBottom(windowWidth) {
        return base(windowWidth)
    }

    function profileBottom(windowWidth) {
        return resumeBottom(windowWidth) + (resumeHeight > 0 ? resumeHeight + gap : 0)
    }

    function updateBottom(windowWidth) {
        return profileBottom(windowWidth) + (profileHeight > 0 ? profileHeight + gap : 0)
    }
}
