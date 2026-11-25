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
import QtQuick

import VLC.Style

// This is useful especially for color animations, as we do not want the
// animations to run as soon as the theme is initialized, as the colors
// often adjusted depending on initialization, and to have debouncing.
Behavior {
    id: behavior

    required property bool delayedEnabled // modifying `enabled` is not permitted, this property should be used instead

    // `delayedEnabled`, applied once the event queue is cleared (false until then)
    property bool _delayedEnabled: false

    Binding on _delayedEnabled {
        delayed: true
        value: behavior.delayedEnabled
    }

    // redesign: a theme or accent switch applies the new colors at once instead of animating
    // every control (P8-41); this part is not delayed so it is off before the colors change.
    // darkPalette (items drawn on the picture) recolors with the accent.
    enabled: _delayedEnabled && !VLCStyle.palette.switching && !VLCStyle.darkPalette.switching
}
