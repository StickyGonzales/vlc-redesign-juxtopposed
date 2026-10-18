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

// Redesign dropdown over one of VLC's variable choice models (zoom, aspect ratio, crop, stereo
// mode, audio visualizer...): shows the checked entry and selects the picked one.
import QtQuick
import QtQml

import VLC.MainInterface
import VLC.Style

RdDropdown {
    id: control

    // a VLCVarChoiceModel (roles: display, checked)
    property var choices: null
    // shown while the model has no entries (VLC offers nothing to choose)
    property string placeholderText: ""

    model: choices
    textRole: "display"
    displayText: count > 0 ? currentText : placeholderText
    currentIndex: _checkedIndex
    enabled: !!choices && count > 0

    property int _checkedIndex: -1

    function _updateCheckedIndex() {
        for (let i = 0; i < checkedTracker.count; ++i) {
            const entry = checkedTracker.objectAt(i)
            if (entry && entry.isChecked) {
                _checkedIndex = i
                return
            }
        }
        _checkedIndex = -1
    }

    onActivated: (index) => {
        if (choices)
            choices.toggleIndex(index)
    }

    Instantiator {
        id: checkedTracker

        model: control.choices

        delegate: QtObject {
            required property var model
            readonly property bool isChecked: !!model.checked

            onIsCheckedChanged: control._updateCheckedIndex()
        }

        onObjectAdded: control._updateCheckedIndex()
        onObjectRemoved: control._updateCheckedIndex()
    }
}
