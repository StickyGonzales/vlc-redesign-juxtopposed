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

// redesign (1.5.0 fixes, FIX_1_5_0_NOTES.md): the Add Subtitles choice, the downloaded file's name
// and the external track name. QtCore only.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "dialogs/redesign/addsubtitles/rd_subtitle_picks.hpp"
#include "dialogs/redesign/addsubtitles/subtitle_matcher.hpp"

#include <QDir>
#include <QFile>
#include <QTemporaryDir>

#include <cstdio>
#include <utility>

using namespace rdsubtitles;

namespace {

int checks = 0;
int failures = 0;

void check(bool ok, const char* what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s\n", what);
    }
}

void checkEqual(const QString& actual, const QString& expected, const char* what)
{
    ++checks;
    if (actual != expected)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s: got \"%s\", expected \"%s\"\n", what, qPrintable(actual),
                     qPrintable(expected));
    }
}

QString s(const char* text)
{
    return QString::fromUtf8(text);
}

void write(const QString& path, const QByteArray& data)
{
    QFile file(path);
    check(file.open(QIODevice::WriteOnly) && file.write(data) == data.size(), "test file written");
}

void testPicked()
{
    // OpenSubtitles: one choice. The pre-checked best match, then a click on another result:
    // only that one stays checked (1.5.0 Windows pass: English and Hebrew were both downloaded)
    check(picked({ 0 }, 2, true) == QSet<int>{ 2 }, "single: another result moves the check");
    // a click on the checked result keeps it (it unchecked it, and Save downloaded nothing)
    check(picked({ 0 }, 0, true) == QSet<int>{ 0 }, "single: the checked result stays checked");
    check(picked({}, 1, true) == QSet<int>{ 1 }, "single: nothing checked, a click checks");
    check(picked({ 0, 3 }, 1, true) == QSet<int>{ 1 }, "single: never more than one");

    // files from the computer: several (Figma Folder-2), a click flips the row
    check(picked({ 0 }, 2, false) == (QSet<int>{ 0, 2 }), "multi: a click adds");
    check(picked({ 0, 2 }, 0, false) == QSet<int>{ 2 }, "multi: a click removes");
}

void testDownloadFile()
{
    QTemporaryDir dir;
    check(dir.isValid(), "temporary folder");
    const QString folder = dir.path();
    const QString name = s("Sintel (2010).eng.srt");

    // the subtitle's own name, no OpenSubtitles id in front (1.5.0: "67399-Sintel (2010).eng.srt")
    checkEqual(downloadFile(folder, name, "one"), folder + s("/Sintel (2010).eng.srt"), "own name");
    write(folder + s("/Sintel (2010).eng.srt"), "one");
    // the same subtitle again: the same file, no copy
    checkEqual(downloadFile(folder, name, "one"), folder + s("/Sintel (2010).eng.srt"), "same bytes reused");
    // another subtitle with the same name: numbered, the first is kept
    checkEqual(downloadFile(folder, name, "two"), folder + s("/Sintel (2010).eng (2).srt"), "numbered");
    write(folder + s("/Sintel (2010).eng (2).srt"), "two");
    checkEqual(downloadFile(folder, name, "two"), folder + s("/Sintel (2010).eng (2).srt"), "numbered reused");
    checkEqual(downloadFile(folder, name, "three"), folder + s("/Sintel (2010).eng (3).srt"), "next number");
    checkEqual(downloadFile(QString(), name, "x"), QString(), "no folder");
}

void testTrackName()
{
    checkEqual(withoutExtension(s("Sintel (2010).eng.srt")), s("Sintel (2010).eng"), "extension");
    checkEqual(withoutExtension(s("Sintel (2010)")), s("Sintel (2010)"), "no extension");

    // the 1.5.0 track "Sintel (2010 [English]": the language word went with the ")" before it
    const QString base = s("Sintel (2010).eng");
    checkEqual(withoutLastWord(base, base.size() - 3, base), s("Sintel (2010)"), "bracket kept");
    const QString wand = s("The_Wand_S01E04_EN");
    checkEqual(withoutLastWord(wand, wand.size() - 2, wand), s("The_Wand_S01E04"), "separators go");
    const QString dashes = s("Movie [HD] - en");
    checkEqual(withoutLastWord(dashes, dashes.size() - 2, dashes), s("Movie [HD]"), "square bracket kept");
    checkEqual(withoutLastWord(s("en"), 0, s("en.srt")), s("en.srt"), "fallback");

    checkEqual(withoutDownloadId(s("67399-Sintel (2010).eng.srt")), s("Sintel (2010).eng.srt"), "old id");
    checkEqual(withoutDownloadId(s("Sintel (2010).eng.srt")), s("Sintel (2010).eng.srt"), "no id");
    checkEqual(withoutDownloadId(s("2001 A Space Odyssey.srt")), s("2001 A Space Odyssey.srt"), "digits, no dash");
    checkEqual(withoutDownloadId(s("12345-")), s("12345-"), "nothing after the id");
    checkEqual(withoutDownloadId(s("24-S01E01.eng.srt")), s("24-S01E01.eng.srt"), "short number kept");
}

// VLC's ISO 639 table, for the codes these checks use
std::pair<QString, QString> language(const QString& code)
{
    const QString lower = code.toLower();
    if (lower == QLatin1String("eng") || lower == QLatin1String("en") || lower == QLatin1String("english"))
        return { s("English"), s("en") };
    if (lower == QLatin1String("heb") || lower == QLatin1String("he"))
        return { s("Hebrew"), s("he") };
    return { code, QString() };
}

void testExternalTrackName()
{
    // the 1.5.0 Windows pass: "67399-Sintel (2010 [English]" for "67399-Sintel (2010).eng.srt"
    checkEqual(externalTrackName(s("Sintel (2010).eng.srt"), QString(), language),
               s("Sintel (2010) [English]"), "track: bracket kept");
    checkEqual(externalTrackName(withoutDownloadId(s("67399-Sintel (2010).eng.srt")), QString(), language),
               s("Sintel (2010) [English]"), "track: old download");
    // the video's example (6:22-6:24)
    checkEqual(externalTrackName(s("The_Wand_S01E04_EN.srt"), QString(), language),
               s("The_Wand_S01E04 [English]"), "track: video example");
    // the track's own language wins; the file name keeps a word that is another language
    checkEqual(externalTrackName(s("Sintel (2010).eng.srt"), s("heb"), language),
               s("Sintel (2010).eng [Hebrew]"), "track: track language");
    checkEqual(externalTrackName(s("Sintel (2010).srt"), QString(), language),
               s("Sintel (2010)"), "track: no language");
}

void testSaveDownload()
{
    QTemporaryDir dir;
    check(dir.isValid(), "temporary folder");
    const QString folder = dir.path();
    const QString name = s("Sintel (2010).eng.srt");
    const QString first = saveDownload(folder, name, "one");
    checkEqual(first, folder + s("/Sintel (2010).eng.srt"), "saved under its own name");
    QFile file(first);
    check(file.open(QIODevice::ReadOnly) && file.readAll() == "one", "saved bytes");
    checkEqual(saveDownload(folder, name, "one"), first, "saved again: the same file");
    checkEqual(saveDownload(folder, name, "two"), folder + s("/Sintel (2010).eng (2).srt"), "another: numbered");
    checkEqual(saveDownload(QString(), name, "one"), QString(), "no folder: nothing saved");
}

// an OpenSubtitles result as the dialog parses it: its file name, and the language OpenSubtitles gives
SubtitleMatcher::Name result(const char* fileName, const char* language)
{
    SubtitleMatcher::Name name = SubtitleMatcher::parse(s(fileName));
    name.language = s(language);
    return name;
}

QString orderText(const QVector<int>& order)
{
    QStringList parts;
    for (const int i : order)
        parts.append(QString::number(i));
    return parts.join(QLatin1Char(','));
}

void testLanguageFirst()
{
    const SubtitleMatcher::Name sintel = SubtitleMatcher::parse(s("Sintel (2010).mkv"));
    SubtitleMatcher::Preference english;
    english.language = s("en");

    // the 1.5.0 Windows retest: English chosen, OpenSubtitles' list mixed. The Hebrew file is named
    // exactly like the film, the English ones carry more words, so the name score put Hebrew first
    const QVector<SubtitleMatcher::Name> mixed {
        result("Sintel (2010).srt", "he"),
        result("Sintel.Open.Movie.2010.720p.srt", "en"),
        result("Sintel.Open.Movie.2010.1080p.srt", "en"),
        result("Big Buck Bunny (2008).srt", "en"),
        result("Sintel.2010.fr.srt", "fr"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, mixed, s("en"), english)), s("1"),
               "language first: the first English result, not the Hebrew one");
    // English in OpenSubtitles' order, then the other languages in their order, then another film
    checkEqual(orderText(SubtitleMatcher::rankResults(sintel, mixed, s("en"), english)), s("1,2,0,4,3"),
               "language first: order");

    // no result in the chosen language: OpenSubtitles' top result, every result still listed
    const QVector<SubtitleMatcher::Name> none {
        result("Sintel.Open.Movie.2010.srt", "fr"),
        result("Sintel (2010).srt", "he"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, none, s("en"), english)), s("0"),
               "no result in the language: their top result");
    checkEqual(orderText(SubtitleMatcher::rankResults(sintel, none, s("en"), english)), s("0,1"),
               "no result in the language: none hidden");

    // only other films: nothing is picked
    const QVector<SubtitleMatcher::Name> otherFilm { result("Big Buck Bunny (2008).srt", "en") };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, otherFilm, s("en"), english)), s("-1"),
               "another film is never the best match");

    // regions: "pt" chosen takes "pt-br"; "pt-br" chosen does not take "pt-pt"
    const QVector<SubtitleMatcher::Name> portuguese {
        result("Sintel (2010).srt", "pt-pt"),
        result("Sintel.Open.Movie.2010.srt", "pt-br"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, portuguese, s("pt-br"), english)), s("1"),
               "pt-br chosen: the pt-br result");
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, portuguese, s("pt"), english)), s("0"),
               "pt chosen: either region, OpenSubtitles' order");

    // the variant kept for the show (an episode's "forced", "SDH") still counts within a language:
    // none kept, the plain file before the SDH one OpenSubtitles lists first; "sdh" kept (picked by
    // hand for an earlier episode), the SDH one
    const SubtitleMatcher::Name wand = SubtitleMatcher::parse(s("The Wand S01E04.mkv"));
    const QVector<SubtitleMatcher::Name> variants {
        result("The Wand S01E04.srt", "he"),
        result("The Wand S01E04 SDH.srt", "en"),
        result("The Wand S01E04.srt", "en"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(wand, variants, s("en"), english)), s("2"),
               "variant: the plain English file without a kept variant");
    SubtitleMatcher::Preference sdh = english;
    sdh.variantTokens = QStringList { s("sdh") };
    checkEqual(QString::number(SubtitleMatcher::bestResult(wand, variants, s("en"), sdh)), s("1"),
               "variant: the kept SDH variant");

    // an episode: the results of another episode never come first
    const SubtitleMatcher::Name episode = SubtitleMatcher::parse(s("The Wand S01E04.mkv"));
    const QVector<SubtitleMatcher::Name> episodes {
        result("The Wand S01E05.srt", "en"),
        result("The Wand S01E04.srt", "he"),
        result("The.Wand.S01E04.WEB.srt", "en"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(episode, episodes, s("en"), english)), s("2"),
               "episode: the English result of this episode");
}

// an OpenSubtitles result as the dialog parses it (parseResult): OpenSubtitles' language tag, and
// the language the file or release name names
SubtitleMatcher::Name tagged(const char* fileName, const char* language, const char* release = "")
{
    SubtitleMatcher::Name name = SubtitleMatcher::parse(s(fileName));
    name.nameLanguage = SubtitleMatcher::namedLanguage(s(fileName), s(release));
    name.language = s(language);
    return name;
}

void testNamedLanguage()
{
    // a language word in the name: two letter codes, three letter codes, names
    checkEqual(SubtitleMatcher::namedLanguage(s("sintel.he.srt"), QString()), s("he"), "named: .he");
    checkEqual(SubtitleMatcher::namedLanguage(s("Sintel.2010.heb.srt"), QString()), s("he"), "named: .heb");
    checkEqual(SubtitleMatcher::namedLanguage(s("Sintel (2010) Hebrew.srt"), QString()), s("he"), "named: Hebrew");
    checkEqual(SubtitleMatcher::namedLanguage(s("sintel.fi.srt"), QString()), s("fi"), "named: .fi");
    checkEqual(SubtitleMatcher::namedLanguage(s("Sintel.2010.fin.srt"), QString()), s("fi"), "named: .fin");
    checkEqual(SubtitleMatcher::namedLanguage(s("The.Wand.S01E04.heb.srt"), QString()), s("he"), "named: episode .heb");
    // only whole words where a language goes: not inside a word, not a title word
    checkEqual(SubtitleMatcher::namedLanguage(s("Sintel.2010.srt"), QString()), QString(), "named: none");
    checkEqual(SubtitleMatcher::namedLanguage(s("Chef.2014.720p.srt"), QString()), QString(), "named: not in chef");
    checkEqual(SubtitleMatcher::namedLanguage(s("The.Chef.Show.S01E01.srt"), QString()), QString(), "named: not in the");
    checkEqual(SubtitleMatcher::namedLanguage(s("The.Hebrew.Hammer.2003.srt"), QString()), QString(),
               "named: not a title word (The Hebrew Hammer)");
    checkEqual(SubtitleMatcher::namedLanguage(s("He.Got.Game.1998.srt"), QString()), QString(),
               "named: not a title word (He Got Game)");
    checkEqual(SubtitleMatcher::namedLanguage(s("Sintel.2010.heb.720p.BluRay.srt"), QString()), s("he"),
               "named: before the release tags");
    checkEqual(SubtitleMatcher::namedLanguage(s("The.Wand.S01E04.The.End.srt"), QString()), QString(),
               "named: not an episode title of plain words");
    // no language in the file name: the release name
    checkEqual(SubtitleMatcher::namedLanguage(s("subtitle.srt"), s("Sintel.2010.Hebrew")), s("he"), "named: release");
    checkEqual(SubtitleMatcher::namedLanguage(s("sintel.en.srt"), s("Sintel.2010.Hebrew")), s("en"),
               "named: the file name first");
}

void testMislabeled()
{
    const SubtitleMatcher::Name sintel = SubtitleMatcher::parse(s("Sintel (2010).mkv"));
    SubtitleMatcher::Preference english;
    english.language = s("en");

    // the 1.5.0 retest of #144: English chosen, OpenSubtitles files "sintel.he" (Hebrew text) and a
    // Finnish upload under English and lists the Hebrew one first: they go after the English ones,
    // in OpenSubtitles' order, and stay listed
    const QVector<SubtitleMatcher::Name> sintelResults {
        tagged("sintel.he.srt", "en"),
        tagged("Sintel.2010.720p.BluRay.x264.srt", "en"),
        tagged("Sintel.2010.fin.srt", "en"),
        tagged("Sintel.2010.srt", "en"),
        tagged("Sintel.2010.fr.srt", "fr"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, sintelResults, s("en"), english)), s("1"),
               "mislabeled: the English file, not sintel.he");
    checkEqual(orderText(SubtitleMatcher::rankResults(sintel, sintelResults, s("en"), english)), s("1,3,0,2,4"),
               "mislabeled: order, nothing hidden");

    // the release name names the language
    const QVector<SubtitleMatcher::Name> byRelease {
        tagged("Sintel.2010.srt", "en", "Sintel.2010.Hebrew.WEB"),
        tagged("Sintel.2010.srt", "en", "Sintel.2010.1080p.WEB"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, byRelease, s("en"), english)), s("1"),
               "mislabeled: by the release name");

    // another chosen language: an English file filed under Finnish
    SubtitleMatcher::Preference finnish;
    finnish.language = s("fi");
    const QVector<SubtitleMatcher::Name> finnishResults {
        tagged("Sintel.2010.eng.srt", "fi"),
        tagged("Sintel.2010.srt", "fi"),
    };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, finnishResults, s("fi"), finnish)), s("1"),
               "mislabeled: an English file filed under Finnish");

    // a name in the chosen language, or a title word that is a language, is not pushed down
    const SubtitleMatcher::Name hammer = SubtitleMatcher::parse(s("The Hebrew Hammer (2003).mkv"));
    const QVector<SubtitleMatcher::Name> hammerResults {
        tagged("The.Hebrew.Hammer.2003.srt", "en"),
        tagged("The.Hebrew.Hammer.2003.eng.srt", "en"),
    };
    checkEqual(orderText(SubtitleMatcher::rankResults(hammer, hammerResults, s("en"), english)), s("0,1"),
               "mislabeled: a title word is no other language");

    // only mislabeled results: OpenSubtitles' top one is still the best match
    const QVector<SubtitleMatcher::Name> onlyHebrew { tagged("sintel.he.srt", "en"), tagged("sintel.heb.srt", "en") };
    checkEqual(QString::number(SubtitleMatcher::bestResult(sintel, onlyHebrew, s("en"), english)), s("0"),
               "mislabeled: all of them, the top one");
}

} // namespace

int main()
{
    testPicked();
    testDownloadFile();
    testTrackName();
    testExternalTrackName();
    testSaveDownload();
    testLanguageFirst();
    testNamedLanguage();
    testMislabeled();
    std::fprintf(stderr, "test_rd_subtitle_picks: %d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
