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

#ifndef RD_SHOW_TRACKS_HPP
#define RD_SHOW_TRACKS_HPP

#include <QString>
#include <QVector>

/**
 * Cone extra (Up Next, redesign/SHOW_TRACKS_NOTES.md): the audio and subtitle track a show is
 * watched with, kept by language so the next episodes, whose tracks may come in another order,
 * get the same one.
 *
 * A track's language is its language tag ("en", "eng", "English", "en-US": all "eng"), or, when
 * it has none, a language name that is a whole word of its title ("1Vegamovies.tw - English").
 * Only names count in a title: a short code there is too often something else (".tw" of a web
 * address is not Twi).
 *
 * QtCore only and pure (RdUpNext records and applies the choice).
 */
namespace rdtracks {

// the key of a language tag or name: its ISO 639-2/T code ("eng"), or the tag itself in lower case
// when the language is not in the table; empty for no language ("", "und", "mul", "zxx")
QString languageKey(const QString& tag);

// the language whose name is a whole word of `title`, as languageKey() gives it; empty when none
QString languageInTitle(const QString& title);

// the track's language: its tag, else a language name in its title; empty when neither
QString trackLanguage(const QString& tag, const QString& title);

struct Track
{
    QString tag;
    QString title;
};

// the first track of the language `key` (a languageKey()), -1 when none
int matchTrack(const QVector<Track>& tracks, const QString& key);

} // namespace rdtracks

#endif
