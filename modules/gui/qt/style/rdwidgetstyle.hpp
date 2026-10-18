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
#ifndef RDWIDGETSTYLE_HPP
#define RDWIDGETSTYLE_HPP

#include "qt.hpp"

class QWidget;

// redesign (W6.4): the Figma dialog look (redesign/reference/figma/styles.txt colors,
// Inter 14, radius 6 fields and buttons, accent Save-style primary button) for the
// dialogs that stay Qt widgets (open sources, Open URL, Convert, Stream Output, About).
// The style sheet is set on the dialog only, never application wide, and follows the
// color scheme and the accent color live. Without a main interface (dialogs provider
// mode) the dialog keeps the native look.
namespace RdWidgetStyle
{
void apply( QWidget* widget, qt_intf_t* p_intf );

// gives a dialog's main action button the Save style (Figma "Frame 141"); the focus
// driven QPushButton "default" state is not used, it moves with every clicked button
void setPrimary( QWidget* button );
}

#endif // RDWIDGETSTYLE_HPP
