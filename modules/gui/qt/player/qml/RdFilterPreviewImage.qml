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
// redesign: the small preview of a video filter preset (VIDEO_INDEX row 139): the frame on
// screen with the preset's filter values applied (RdFilterPreview). Neither Figma nor the video
// shows these previews, so the look is an extrapolation in the Figma style: a 16:9 picture as
// tall as the EQ preset icons (24), corners of the library thumbnails (rd_radius_xsmall), the
// video background (BG/B2) while the preview is made or when none can be made (a stream, no
// video). It goes in the `leading` slot of an RdOptionRow like the EQ curve icons.
// Display only: it takes no input, and it never waits for the preview (no loading state).
import QtQuick

import VLC.Style
import VLC.Widgets as Widgets
import VLC.Player

Rectangle {
    id: root

    // the preset's filter values, RdEffects / RdPresets names ("adjust": true, "hue": 90, ...)
    property var values: ({})

    implicitWidth: Math.round(implicitHeight * 16 / 9)
    implicitHeight: VLCStyle.icon_normal

    radius: VLCStyle.rd_radius_xsmall
    color: VLCStyle.palette.rdBgB2

    enabled: false

    // the preview of the current frame, asked again whenever one becomes ready
    readonly property url _source: {
        void RdFilterPreview.revision
        return RdFilterPreview.supported ? RdFilterPreview.preview(root.values) : ""
    }

    function _requestFrame() {
        if (!visible || !RdFilterPreview.supported || width <= 0 || height <= 0)
            return
        const dpr = Screen.devicePixelRatio
        RdFilterPreview.frameSize = Qt.size(Math.ceil(width * dpr), Math.ceil(height * dpr))
        // one capture per opening of the list: the engine skips it while the frame on hand is
        // still the one on screen
        RdFilterPreview.capture()
    }

    onVisibleChanged: _requestFrame()
    onWidthChanged: _requestFrame()
    Component.onCompleted: _requestFrame()

    Connections {
        target: RdFilterPreview
        function onSupportedChanged() { root._requestFrame() }
    }

    Widgets.ImageExt {
        anchors.fill: parent

        visible: root._source.toString() !== ""
        source: root._source
        // the preview is already in memory: no loading state, no flicker between frames
        asynchronous: false
        // RdFilterPreview keeps its own cache
        cache: false
        // the frame covers the box, like the library thumbnails
        fillMode: Image.PreserveAspectCrop
        radius: root.radius
    }
}
