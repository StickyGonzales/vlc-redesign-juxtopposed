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

#include <functional>
#include <utility>

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

// writes a downloaded subtitle at downloadFile()'s place and returns its path, empty on failure.
// Choosing the name and writing are one step for every download worker (two subtitles of the
// same name downloaded at once get two files); a file that already holds the bytes is not
// written again (VLC may have it open)
QString saveDownload(const QString& folder, const QString& name, const QByteArray& data);

// a file name without its extension (".srt", ".ass": at most four characters after the dot)
QString withoutExtension(const QString& fileName);

// `base` without the word that starts at `wordStart` and the separators (space . _ -) before it:
// "Sintel (2010).eng" without "eng" is "Sintel (2010)"; brackets stay. `fallback` when nothing
// would remain
QString withoutLastWord(const QString& base, qsizetype wordStart, const QString& fallback);

// the name of an OpenSubtitles download Cone saved before 1.5.0 ("67399-Sintel (2010).eng.srt",
// the OpenSubtitles file id first, at least four digits) without that id; other names as they are
QString withoutDownloadId(const QString& fileName);

// the English name and two letter code of a language code or name ({ given text, "" } when unknown)
using LanguageLookup = std::function<std::pair<QString, QString>(const QString&)>;

// an external file's track as the video shows it (6:22-6:24, Decision 11): "The_Wand_S01E04
// [English]", the file name without its extension and the language in brackets: the track's own,
// else the one at the end of the file name ("_EN", ".eng"), which then leaves the name with the
// separators before it ("Sintel (2010).eng.srt": "Sintel (2010) [English]")
QString externalTrackName(const QString& fileName, const QString& trackLanguage,
                          const LanguageLookup& languageOf);

} // namespace rdsubtitles

#endif // RD_SUBTITLE_PICKS_HPP
