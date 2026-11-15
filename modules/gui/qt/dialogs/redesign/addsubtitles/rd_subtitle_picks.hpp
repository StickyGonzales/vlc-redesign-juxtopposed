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

#ifndef RD_SUBTITLE_PICKS_HPP
#define RD_SUBTITLE_PICKS_HPP

#include <QByteArray>
#include <QSet>
#include <QString>

/**
 * redesign (1.5.0 fixes, redesign/FIX_1_5_0_NOTES.md): the small rules of the Add Subtitles
 * dialog and of the external track names, QtCore only and pure apart from the file checks of
 * downloadFile(), so they are unit tested (tests/test_rd_subtitle_picks.cpp).
 */
namespace rdsubtitles {

// the checked rows after a click on `candidate`. `single`: OpenSubtitles results for one file
// (Figma "Folder-3": one result checked), so a click checks that row alone and a click on the
// checked row keeps it; otherwise (files from the computer, Figma "Folder-2") a click flips it
QSet<int> picked(const QSet<int>& selected, int candidate, bool single);

// where a downloaded subtitle is written in `folder`: its own name ("Sintel (2010).eng.srt"),
// the file already there when it holds the same bytes (the same subtitle downloaded again), else
// the first free "Sintel (2010).eng (2).srt"; empty when no name is free
QString downloadFile(const QString& folder, const QString& name, const QByteArray& data);

// a file name without its extension (".srt", ".ass": at most four characters after the dot)
QString withoutExtension(const QString& fileName);

// `base` without the word that starts at `wordStart` and the separators (space . _ -) before it:
// "Sintel (2010).eng" without "eng" is "Sintel (2010)"; brackets stay. `fallback` when nothing
// would remain
QString withoutLastWord(const QString& base, qsizetype wordStart, const QString& fallback);

// the name of an OpenSubtitles download Cone saved before 1.5.0 ("67399-Sintel (2010).eng.srt",
// the OpenSubtitles file id first) without that id; other names as they are
QString withoutDownloadId(const QString& fileName);

} // namespace rdsubtitles

#endif // RD_SUBTITLE_PICKS_HPP
