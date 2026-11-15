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

#ifndef SUBTITLE_MATCHER_HPP
#define SUBTITLE_MATCHER_HPP

#include <QString>
#include <QStringList>
#include <QVector>

/**
 * redesign (Add Subtitles, W6.5, P3-02 / P3-08 / P3-09): matches subtitle files to the videos
 * they belong to by what the names mean, not by how they are written: the designer's folder has
 * "The_Wand_S01E04.mp4" next to "thewand_s01e04.srt", which VLC's own file name matching misses.
 *
 * A name is read as a title, an episode (S01E04, 1x04, "Episode 4", E04, a lone number) and
 * what follows the episode (language, "forced", "SDH" ...: the variant). A subtitle matches a
 * video when the episodes agree (or, for names without an episode, when the titles agree); among
 * the matches of an episode the preferred variant and language win, so a choice made by hand
 * once ("_English" instead of "_Spanish") is kept for the next episodes.
 *
 * Pure functions on names only (no file access), safe on any thread.
 */
class SubtitleMatcher
{
public:
    struct Name
    {
        // lower case, words separated by single spaces, without the extension
        QString normalized;
        // the words before the episode (without release tags), or every word without one
        QStringList titleTokens;
        // the same words as written ("The Wand")
        QString title;
        // the words after the episode (language, forced, SDH, an episode title...)
        QStringList variantTokens;
        // two letter language code found in the variant ("en"), empty when none
        QString language;
        int season = -1;
        int episode = -1;

        bool hasEpisode() const { return episode >= 0; }
    };

    // what the user prefers among the matches of an episode
    struct Preference
    {
        QStringList variantTokens;
        QString language;
    };

    static Name parse(const QString& fileName);

    // the part of score() that comes from the variant: the kept one (preference.variantTokens)
    // +50 a word, a variant word nobody asked for ("forced", "SDH") -5
    static int variantScore(const Name& subtitle, const Preference& preference);

    // how well `subtitle` fits `video`: -1 when it does not belong to it, higher is better
    static int score(const Name& video, const Name& subtitle, const Preference& preference = {});

    // the index in `subtitles` of the best match for `video`, -1 when none
    static int bestMatch(const Name& video, const QVector<Name>& subtitles, const Preference& preference = {});

    // OpenSubtitles results for `video`, best first, as indexes into `results` (in OpenSubtitles'
    // order, their ranking): the ones that belong to the video (score() >= 0) in `language` first,
    // then the ones that belong in other languages, each group in OpenSubtitles' order after the
    // variant kept for the show (variantScore(), equal scores keep their order); then the
    // ones that do not belong. A language tag counts as `language` when it is the same, or when
    // only one of them names a region ("pt" and "pt-br"); empty `language`: every result counts
    static QVector<int> rankResults(const Name& video, const QVector<Name>& results, const QString& language,
                                    const Preference& preference = {});

    // the first of rankResults() when it belongs to the video, -1 when none does: a result in
    // `language`, else OpenSubtitles' top result
    static int bestResult(const Name& video, const QVector<Name>& results, const QString& language,
                          const Preference& preference = {});

    // the words of a chosen subtitle that are not in its video's name and say which variant it
    // is (language, forced ...): kept as the preference for the next episodes
    static QStringList variantOf(const Name& video, const Name& subtitle);

    // two letter code of a language name or code ("english", "eng", "en"), empty when unknown
    static QString languageCode(const QString& word, bool allowTwoLetters);

    // file name order with numbers compared by value ("E2" before "E10"): < 0, 0, > 0
    static int naturalCompare(const QString& a, const QString& b);
    static void naturalSort(QStringList& names);
};

#endif // SUBTITLE_MATCHER_HPP
