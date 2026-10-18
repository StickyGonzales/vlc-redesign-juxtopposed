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

// redesign (W8.1b, Figma "Player - customize" item "HDR"): the HDR output mode of the video
// tab (VLC's "d3d11-hdr-mode", read through RdEffects like the tab), as a list of its choices;
// greyed out where VLC's video output has no HDR mode (the option does not exist)
import QtQuick

import VLC.Player
import VLC.Widgets as Widgets
import VLC.Style
import VLC.Util

ChoiceMenuButton {
    id: root

    readonly property string option: "d3d11-hdr-mode"
    readonly property var _choices: paintOnly ? [] : RdEffects.optionChoices(option)
    readonly property var _current: RdEffects.values[RdEffects.optionKey(option)]

    enabled: _choices.length > 0

    text: VLCIcons.tv
    rdIcon: "hdr"
    description: qsTr("HDR")

    AccessibleCompat.id: "hdrButton"

    Repeater {
        model: root._choices

        delegate: Widgets.RdOptionRow {
            required property var modelData

            // Figma "HDR Options" (2372:8733) names VLC's "never" mode "Off"
            text: modelData.text === qsTr("Never out HDR") ? qsTr("Off") : modelData.text
            selected: modelData.value === root._current
            onClicked: RdEffects.setOption(root.option, modelData.value)
        }
    }
}
