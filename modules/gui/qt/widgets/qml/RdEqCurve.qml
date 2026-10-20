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

// Redesign equalizer preset icon drawn from the preset's band gains (IA-40 / P4-25 / P4-26): the
// 24x24 icon box with the FG/A2 baseline and the Accent/Main lobes of the curve, drawn by
// RdEqCurveItem. Only for a preset without its own icon in Figma's set "name=EQ" (those show the
// exported SVG, RdEffects.equalizerPresetIcon). Its colours follow the palette, so the accent
// colour and the light theme apply live.
import QtQuick

import VLC.Style
import VLC.Widgets

// `bands`: the gains in dB (-20 to +20) of the preset's bands
RdEqCurveItem {
    implicitWidth: VLCStyle.icon_normal
    implicitHeight: VLCStyle.icon_normal

    lineColor: VLCStyle.palette.rdFgA2
    fillColor: VLCStyle.palette.rdAccentMain
}
