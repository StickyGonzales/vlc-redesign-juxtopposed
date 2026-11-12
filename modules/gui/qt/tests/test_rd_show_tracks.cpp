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

// Cone extra (Up Next, SHOW_TRACKS_NOTES.md): a show's tracks by language. QtCore only.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "player/rd_show_tracks.hpp"

#include <cstdio>

using namespace rdtracks;

namespace {

int checks = 0;
int failures = 0;

void checkEqual(const QString& actual, const char* expected, const char* what)
{
    ++checks;
    if (actual != QString::fromUtf8(expected))
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s: got \"%s\", expected \"%s\"\n", what, qPrintable(actual), expected);
    }
}

void checkEqual(int actual, int expected, const char* what)
{
    ++checks;
    if (actual != expected)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s: got %d, expected %d\n", what, actual, expected);
    }
}

QString s(const char* text)
{
    return QString::fromUtf8(text);
}

void testTags()
{
    checkEqual(languageKey(s("en")), "eng", "ISO 639-1");
    checkEqual(languageKey(s("eng")), "eng", "ISO 639-2");
    checkEqual(languageKey(s("ENG")), "eng", "upper case");
    checkEqual(languageKey(s("en-US")), "eng", "with a region");
    checkEqual(languageKey(s("pt_BR")), "por", "with a region, underscore");
    checkEqual(languageKey(s("English")), "eng", "a name as the tag");
    checkEqual(languageKey(s("fre")), "fra", "ISO 639-2/B");
    checkEqual(languageKey(s("ger")), "deu", "ISO 639-2/B, German");
    checkEqual(languageKey(s("hin")), "hin", "Hindi");
    checkEqual(languageKey(s("")), "", "no tag");
    checkEqual(languageKey(s("und")), "", "undetermined");
    checkEqual(languageKey(s("mul")), "", "several");
    checkEqual(languageKey(s("xyz")), "xyz", "a tag outside the table matches itself");
}

void testTitles()
{
    checkEqual(languageInTitle(s("1SiteName.tw - English")), "eng", "the name after a web address");
    checkEqual(languageInTitle(s("1SiteName.tw - Hindi")), "hin", "Hindi");
    checkEqual(languageInTitle(s("1SiteName.tw")), "", "a web address alone: \"tw\" is not Twi");
    checkEqual(languageInTitle(s("Track 1 - [English]")), "eng", "VLC's own track name");
    checkEqual(languageInTitle(s("English SDH")), "eng", "with SDH");
    checkEqual(languageInTitle(s("Español (Latinoamérica)")), "spa", "a native name");
    checkEqual(languageInTitle(s("Français")), "fra", "with an accent");
    checkEqual(languageInTitle(s("Stereo 2.0")), "", "no language");
    checkEqual(languageInTitle(s("Commentary")), "", "a commentary");
    checkEqual(languageInTitle(s("ENG")), "", "a code in a title does not count");
}

void testTrackLanguage()
{
    checkEqual(trackLanguage(s("eng"), s("1SiteName.tw - Hindi")), "eng", "the tag wins over the title");
    checkEqual(trackLanguage(s(""), s("1SiteName.tw - Hindi")), "hin", "no tag: the title");
    checkEqual(trackLanguage(s("und"), s("English")), "eng", "an undetermined tag: the title");
    checkEqual(trackLanguage(s(""), s("Track 2")), "", "neither");
}

void testMatch()
{
    // the same two languages in another order
    const QVector<Track> e1 = { { s("hin"), s("Hindi") }, { s("eng"), s("English") } };
    const QVector<Track> e2 = { { s("eng"), s("English") }, { s("hin"), s("Hindi") } };
    checkEqual(matchTrack(e1, s("eng")), 1, "English is second");
    checkEqual(matchTrack(e2, s("eng")), 0, "English is first");
    // no tags, the language in the names (the reported files)
    const QVector<Track> e3 = { { s(""), s("1SiteName.tw - Hindi") }, { s(""), s("1SiteName.tw - English") } };
    checkEqual(matchTrack(e3, s("eng")), 1, "by the name");
    // the language is missing
    const QVector<Track> e4 = { { s(""), s("Track 1") }, { s("hin"), s("Hindi") } };
    checkEqual(matchTrack(e4, s("eng")), -1, "no English track: none");
    checkEqual(matchTrack(e1, s("")), -1, "no language saved: none");
    // a tag in another form
    const QVector<Track> e5 = { { s("en-GB"), s("") } };
    checkEqual(matchTrack(e5, s("eng")), 0, "en-GB is English");
}

} // namespace

int main()
{
    testTags();
    testTitles();
    testTrackLanguage();
    testMatch();
    std::printf("rd_show_tracks: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
