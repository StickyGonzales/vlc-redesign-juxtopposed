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
#ifndef RD_FILTER_MATH_HPP
#define RD_FILTER_MATH_HPP

#include <QImage>
#include <QString>
#include <QStringList>
#include <QVariantMap>

/**
 * redesign: VLC's video filters applied to a small still frame, for the filter preset
 * previews (VIDEO_INDEX row 139; redesign/SIDEBAR_MUSTHAVES_NOTES.md). The same math as the filters VLC
 * runs on the video, done in software on an RGBA image (8 bit, BT.601):
 *
 * - "adjust" (modules/video_filter/adjust.c): contrast, brightness and gamma through the
 *   luma table, hue and saturation through the U/V rotation and scale;
 * - "sepia" (sepia.c): luma lifted by the intensity, chroma set to the sepia tone;
 * - "invert" (invert.c): every plane inverted;
 * - "posterize" (posterize.c): RGB levels;
 * - "transform" (transform.c) and "rotate" (rotate.c): flips, quarter turns, any angle.
 *
 * `values` uses the names of RdEffects / RdPresets: a filter's module name as a bool (on or
 * off) and its variables by name ("hue", "sepia-intensity", "transform-type", ...). Values
 * not given take VLC's defaults. Filters not in the list above (sharpen, gradfun, grain,
 * extract, colorthres, gradient) do not change the preview: `previewedFilters()` lists the
 * ones that do. Pure function, safe on any thread.
 */
namespace RdFilterMath
{
QImage apply(const QImage& frame, const QVariantMap& values);

// the modules whose effect apply() draws
QStringList previewedFilters();
}

#endif // RD_FILTER_MATH_HPP
