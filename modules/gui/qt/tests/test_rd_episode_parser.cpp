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

// redesign (Up Next, UP_NEXT_PLAN.md 3.7 and 8.6 rows 101-117): show detection tests. QtCore
// only: every case builds a folder tree of empty files in a temporary folder.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "player/rd_episode_parser.hpp"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryDir>

#include <cstdio>
#include <functional>

using namespace rdepisode;

namespace {

int checks = 0;
int failures = 0;

void check(bool ok, const QString& what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s\n", qUtf8Printable(what));
    }
}

void checkEqual(const QString& actual, const QString& expected, const QString& what)
{
    check(actual == expected, QStringLiteral("%1: got \"%2\", expected \"%3\"").arg(what, actual, expected));
}

void checkEqual(int actual, int expected, const QString& what)
{
    check(actual == expected, QStringLiteral("%1: got %2, expected %3").arg(what).arg(actual).arg(expected));
}

// a folder tree of empty files, removed at the end of the case
class Tree
{
public:
    explicit Tree(const QStringList& files)
    {
        for (const QString& name : files)
            add(name);
    }

    void add(const QString& name)
    {
        const QString file = path(name);
        QDir().mkpath(QFileInfo(file).absolutePath());
        QFile f(file);
        check(f.open(QIODevice::WriteOnly), QStringLiteral("create ") + name);
    }

    QString path(const QString& name) const { return m_dir.filePath(name); }

private:
    QTemporaryDir m_dir;
};

// "prefix" + number + "suffix" for every number in [from, to], numbers written by `format`
QStringList numbered(const QString& prefix, int from, int to, const QString& suffix,
                     const std::function<QString(int)>& format)
{
    QStringList names;
    for (int n = from; n <= to; ++n)
        names.append(prefix + format(n) + suffix);
    return names;
}

QString two(int n)
{
    return QStringLiteral("%1").arg(n, 2, 10, QChar('0'));
}

QString plain(int n)
{
    return QString::number(n);
}

QString nextCode(const Show& show)
{
    const int n = show.next();
    return n < 0 ? QString() : code(show.episodes.at(n));
}

QString nextName(const Show& show)
{
    const int n = show.next();
    return n < 0 ? QString() : show.episodes.at(n).fileName;
}

void notShow(const Tree& tree, const QString& file, const QString& what, const Options& options = {})
{
    const Show show = detect(tree.path(file), options);
    check(!show.isShow, what + QStringLiteral(": detected as a show"));
}

// parse(): every pattern and guard

void testParse()
{
    Episode e = parse(QStringLiteral("The.Wand.S01E02.1080p.WEB.x264-GRP.mkv"));
    checkEqual(e.season, 1, "SxxEyy season");
    checkEqual(e.episode, 2, "SxxEyy episode");
    checkEqual(e.lastEpisode, 2, "SxxEyy last");
    checkEqual(e.stem, "the wand", "SxxEyy stem");
    checkEqual(e.title, "", "SxxEyy title");
    check(e.strength == Strength::Strong, "SxxEyy strong");
    checkEqual(e.fileName, "The.Wand.S01E02.1080p.WEB.x264-GRP.mkv", "file name");

    e = parse(QStringLiteral("/media/shows/The Wand/Season 1/The.Wand.S01E02.The.Second.Spark.1080p.WEB-DL.DDP5.1.H.264-GRP.mkv"));
    checkEqual(e.title, "The Second Spark", "title before release tags");
    checkEqual(e.fileName, "The.Wand.S01E02.The.Second.Spark.1080p.WEB-DL.DDP5.1.H.264-GRP.mkv", "file name without folders");
    checkEqual(e.stem, "the wand", "stem with folders");

    e = parse(QStringLiteral("C:\\Shows\\The Wand\\The Wand - S01E03.mkv"));
    checkEqual(e.fileName, "The Wand - S01E03.mkv", "Windows path file name");
    checkEqual(e.stem, "the wand", "stem with a dash");
    checkEqual(e.episode, 3, "Windows path episode");

    e = parse(QStringLiteral("The.Wand.S01E01-E02.mkv"));
    checkEqual(e.episode, 1, "range first");
    checkEqual(e.lastEpisode, 2, "range last");
    checkEqual(code(e), "S01E01-E02", "range code");
    e = parse(QStringLiteral("The.Wand.S01E03E04.mkv"));
    checkEqual(e.lastEpisode, 4, "range without dash");
    e = parse(QStringLiteral("The Wand S01E05-720p.mkv"));
    checkEqual(e.lastEpisode, 5, "no range from a resolution");

    e = parse(QStringLiteral("The Wand S01 E02.mkv"));
    check(e.strength == Strength::Strong && e.season == 1 && e.episode == 2, "S01 E02");
    e = parse(QStringLiteral("The Wand S1 Ep 2.mkv"));
    check(e.strength == Strength::Strong && e.season == 1 && e.episode == 2, "S1 Ep 2");
    e = parse(QStringLiteral("The Wand Season 1 Episode 2.mkv"));
    check(e.strength == Strength::Strong && e.season == 1 && e.episode == 2, "Season 1 Episode 2");
    checkEqual(e.stem, "the wand", "Season 1 Episode 2 stem");

    e = parse(QStringLiteral("Show - 1x08 - Title.mp4"));
    check(e.strength == Strength::Strong && e.season == 1 && e.episode == 8, "1x08");
    checkEqual(e.title, "Title", "1x08 title");
    checkEqual(e.stem, "show", "1x08 stem");
    e = parse(QStringLiteral("1920x1080 sample.mkv"));
    check(e.strength != Strength::Strong && e.season < 0, "1920x1080 is not 1x...");
    e = parse(QStringLiteral("Clip 720x480.mkv"));
    check(e.strength != Strength::Strong, "720x480 is not NxNN");
    e = parse(QStringLiteral("Movie x264.mkv"));
    check(e.strength == Strength::None, "x264 is not NxNN");

    e = parse(QStringLiteral("Doc - Episode 2.mkv"));
    check(e.strength == Strength::Medium && e.episode == 2 && e.season < 0, "Episode 2");
    checkEqual(e.stem, "doc", "Episode 2 stem");
    checkEqual(code(e), "Episode 2", "code without a season");
    e = parse(QStringLiteral("Doc Ep.02.mkv"));
    check(e.strength == Strength::Medium && e.episode == 2, "Ep.02");
    e = parse(QStringLiteral("Doc E02.mkv"));
    check(e.strength == Strength::Medium && e.episode == 2, "standalone E02");
    e = parse(QStringLiteral("Doc Season 2 - E05.mkv"));
    check(e.strength == Strength::Medium && e.season == 2 && e.episode == 5, "season words before E05");
    e = parse(QStringLiteral("Epic 2.mkv"));
    check(e.strength != Strength::Medium, "Epic is not Ep");

    e = parse(QStringLiteral("Documentary Part 3.mkv"));
    check(e.strength == Strength::Medium && e.part && e.episode == 3, "Part 3");
    checkEqual(code(e), "Part 3", "part code");
    e = parse(QStringLiteral("Documentary Pt.2.mkv"));
    check(e.part && e.episode == 2, "Pt.2");
    e = parse(QStringLiteral("Dune Part One (2021).mkv"));
    check(e.strength == Strength::None, "Part One (2021) has no number");
    e = parse(QStringLiteral("Party 3.mkv"));
    check(!e.part, "Party is not Part");

    e = parse(QStringLiteral("The Wand 02.mkv"));
    check(e.strength == Strength::Weak && e.episode == 2, "weak number");
    checkEqual(e.stem, "the wand", "weak stem");
    e = parse(QStringLiteral("02 - Title.mkv"));
    check(e.strength == Strength::Weak && e.episode == 2, "leading weak number");
    checkEqual(e.title, "Title", "leading weak number title");
    checkEqual(e.stem, "", "leading weak number stem");
    e = parse(QStringLiteral("[Group] Show - 03 [1080p].mkv"));
    check(e.strength == Strength::Weak && e.episode == 3, "bracketed groups");
    checkEqual(e.stem, "show", "bracketed groups stem");

    e = parse(QStringLiteral("Movie 2012 (2009).mkv"));
    check(e.strength == Strength::None, "Movie 2012 (2009): no weak 2012");
    e = parse(QStringLiteral("1917 (2019).mkv"));
    check(e.strength == Strength::None, "1917 (2019): no number");
    for (const char* name : { "Show 720.mkv", "Show 480.mkv", "Show 264.mkv", "Show 265.mkv",
                              "Show 10bit.mkv", "Show 10 bit.mkv", "Show 5.1.mkv", "Show DDP5.1.mkv",
                              "Show 7.1.mkv", "Show 1080p.mkv", "Show 2160p.mkv", "Show H.264.mkv",
                              "Kill Bill Vol 1.mkv", "Movie CD 2.avi", "Show Season 2.mkv" })
    {
        e = parse(QString::fromLatin1(name));
        check(e.strength == Strength::None, QStringLiteral("guarded number: ") + QString::fromLatin1(name));
    }

    e = parse(QStringLiteral("Doctor Who (2005) S02E03.mkv"));
    checkEqual(e.stem, "doctor who", "year out of the stem");
    e = parse(QStringLiteral("Grey's Anatomy S01E01.mkv"));
    checkEqual(e.stem, "greys anatomy", "apostrophe out of the stem");
    e = parse(QStringLiteral("Inception (2010).mkv"));
    check(e.strength == Strength::None && e.episode < 0, "movie has no episode");
    checkEqual(code(e), "", "no code without an episode");

    // 115: a long title stays whole (the card wraps and elides it)
    const QString longTitle = QStringLiteral("A").repeated(60) + QStringLiteral(" ") + QStringLiteral("B").repeated(59);
    e = parse(QStringLiteral("The Wand S01E07 ") + longTitle + QStringLiteral(".mkv"));
    checkEqual(e.title, longTitle, "120 character title");

    Episode s;
    s.season = 1;
    s.episode = 2;
    s.lastEpisode = 2;
    checkEqual(code(s), "S01E02", "code");
    s.seasonDefaulted = true;
    checkEqual(code(s), "Episode 2", "code with a defaulted season");
}

void testExcluded()
{
    for (const char* path : {
             "/v/The Wand/Extras/Making of.mkv", "/v/The Wand/Featurettes/x.mkv",
             "/v/The Wand/Behind The Scenes/x.mkv", "/v/The Wand/Deleted Scenes/x.mkv",
             "/v/The Wand/Season 1/Extras/x.mkv", "/v/The Wand/Trailers/x.mkv",
             "/v/The Wand/Season 1/The.Wand.S01E03.sample.mkv", "/v/Show-trailer.mkv",
             "/v/Show S01E01 NCOP.mkv", "/v/Show NCED2.mkv", "/v/Show Creditless OP.mkv",
             "/v/Show Teaser.mkv", "/v/Show promo.mkv", "/v/Show-behindthescenes.mkv",
             "/v/Show-featurette.mkv", "/v/Show-other.mkv",
             "/v/The.Wand.S01E02.mkv.part", "/v/The.Wand.S01E02.mkv.!qB", "/v/x.mkv.crdownload",
             "/v/VID_20240101_101010.mp4", "/v/IMG_1234.MOV", "/v/PXL_20240101_123456789.mp4",
             "/v/GOPR0001.MP4", "/v/GX010023.MP4", "/v/DJI_0001.MP4", "/v/DSC_0001.MOV",
             "/v/DSCF0002.AVI", "/v/MVI_1234.MOV", "/v/Screen Recording 2024-01-01 at 10.00.00.mov",
             "/v/Screencast from 2024-01-01.webm", "/v/2024-05-01 18-22-10.mkv",
             "/v/20240501.mp4", "/v/2024-05-01.mp4", "/v/20240101_101010.mp4",
             "/home/u/DCIM/Camera/x.mp4", "C:\\Users\\u\\Videos\\Captures\\Game 01.mp4" })
        check(excluded(QString::fromLatin1(path)), QStringLiteral("excluded: ") + QString::fromLatin1(path));

    for (const char* path : {
             "/v/The Wand/Season 1/The.Wand.S01E03.mkv", "/v/The Other Two S01E01.mkv",
             "/v/Discovery S01E01.mkv", "/v/Ghosts S01E01.mkv", "/v/Other/The Wand/The Wand S01E01.mkv",
             "/v/Anime/01.mkv", "/v/Inception (2010).mkv" })
        check(!excluded(QString::fromLatin1(path)), QStringLiteral("not excluded: ") + QString::fromLatin1(path));
}

void testSeasonFolders()
{
    const struct { const char* name; int number; } cases[] = {
        { "Season 1", 1 }, { "Season 01", 1 }, { "season 12", 12 }, { "S01", 1 }, { "S1", 1 },
        { "s02", 2 }, { "Series 2", 2 }, { "Staffel 1", 1 }, { "Saison 3", 3 }, { "Temporada 1", 1 },
        { "Season.2", 2 }, { "Season 1 (2019)", 1 }, { "Season 0", 0 }, { "S00", 0 },
        { "Specials", 0 }, { "The Wand", -1 }, { "Seasons", -1 }, { "Extras", -1 }, { "S01E01", -1 },
        { "Sample", -1 }
    };
    for (const auto& c : cases)
        checkEqual(seasonFolderNumber(QString::fromLatin1(c.name)), c.number,
                   QStringLiteral("season folder ") + QString::fromLatin1(c.name));
    check(isSpecialsFolder(QStringLiteral("Specials")), "Specials folder");
    check(isSpecialsFolder(QStringLiteral("Season 0")), "Season 0 folder");
    check(isSpecialsFolder(QStringLiteral("s00")), "S00 folder");
    check(!isSpecialsFolder(QStringLiteral("Season 1")), "Season 1 is not specials");
}

// table 3.7 and rows 101-117

void testShows()
{
    {
        // 3.7: The Wand/Season 1/The.Wand.S01E01..E09.mkv, next of E04 = E05
        Tree tree(numbered("The Wand/Season 1/The.Wand.S01E", 1, 9, ".1080p.mkv", two));
        const Show show = detect(tree.path("The Wand/Season 1/The.Wand.S01E04.1080p.mkv"));
        check(show.isShow, "The Wand season 1: " + show.reason);
        checkEqual(show.name, "The Wand", "show name from the root, not the season folder");
        checkEqual(int(show.episodes.size()), 9, "The Wand episode count");
        checkEqual(nextCode(show), "S01E05", "next of E04");
        check(!show.nextIsNewSeason(), "E05 is the same season");
        checkEqual(show.minDurationSec, 120, "strong minimum length");
        checkEqual(QFileInfo(show.root).fileName(), "The Wand", "root folder");
    }
    {
        // 3.7, 108, 111: season jump, Extras never next
        QStringList files = numbered("The Wand/S01/The.Wand.S01E", 1, 15, ".mkv", two);
        files += numbered("The Wand/S02/The.Wand.S02E", 1, 3, ".mkv", two);
        files += QStringList { "The Wand/Extras/Making of.mkv", "The Wand/Extras/The.Wand.S01E16.mkv",
                               "The Wand/The.Wand.S01E16.mkv" };
        Tree tree(files);
        const Show show = detect(tree.path("The Wand/S01/The.Wand.S01E15.mkv"));
        check(show.isShow, "two season folders: " + show.reason);
        checkEqual(nextCode(show), "S02E01", "after S01E15");
        check(show.nextIsNewSeason(), "S02E01 is a new season");
        bool extras = false;
        for (const Episode& e : show.episodes)
            extras = extras || e.path.contains(QLatin1String("Extras")) || !e.path.contains(QLatin1String("/S0"));
        check(!extras, "nothing outside the season folders");
        checkEqual(int(show.episodes.size()), 18, "both seasons listed");

        const Show last = detect(tree.path("The Wand/S02/The.Wand.S02E03.mkv"));
        checkEqual(last.next(), -1, "112: the last episode has no next");
        check(!last.nextIsNewSeason(), "no new season after the last");

        notShow(tree, "The Wand/Extras/Making of.mkv", "108: Extras/Making of.mkv");
        notShow(tree, "The Wand/Extras/The.Wand.S01E16.mkv", "108: an episode name inside Extras");
    }
    {
        // 3.7: Show/Show 1x01 ... 1x08
        Tree tree(numbered("Show/Show 1x", 1, 8, ".mp4", two));
        const Show show = detect(tree.path("Show/Show 1x03.mp4"));
        check(show.isShow, "1x01..1x08: " + show.reason);
        checkEqual(nextCode(show), "S01E04", "next of 1x03");
    }
    {
        // 3.7: Doc/Doc - Episode 1..6 (medium)
        Tree tree(numbered("Doc/Doc - Episode ", 1, 6, ".mkv", plain));
        const Show show = detect(tree.path("Doc/Doc - Episode 2.mkv"));
        check(show.isShow, "Doc episodes: " + show.reason);
        checkEqual(nextCode(show), "Episode 3", "medium next without a season");
        checkEqual(show.minDurationSec, 120, "medium minimum length");
        check(show.current >= 0 && show.episodes.at(show.current).seasonDefaulted, "season 1 assumed");
        check(show.current >= 0 && show.episodes.at(show.current).season == 1, "season 1 for ordering");
    }
    {
        // medium inside a season folder takes the folder's season
        Tree tree(numbered("Doc/Season 2/Doc - Episode ", 1, 4, ".mkv", plain));
        const Show show = detect(tree.path("Doc/Season 2/Doc - Episode 1.mkv"));
        check(show.isShow, "medium in a season folder: " + show.reason);
        checkEqual(nextCode(show), "S02E02", "season from the folder");
    }
    {
        // 102: Dune Part One / Two; parts need 3
        Tree tree({ "Movies/Dune Part One (2021).mkv", "Movies/Dune Part Two (2024).mkv",
                    "Movies/Kill Bill Vol 1.mkv", "Movies/Kill Bill Vol 2.mkv",
                    "Movies/Inception (2010).mkv", "Movies/1917 (2019).mkv", "Movies/2012 (2009).mkv",
                    "Movies/Movie Part 1.mkv", "Movies/Movie Part 2.mkv" });
        notShow(tree, "Movies/Dune Part One (2021).mkv", "102: Dune Part One");
        notShow(tree, "Movies/Dune Part Two (2024).mkv", "102: Dune Part Two");
        notShow(tree, "Movies/Kill Bill Vol 1.mkv", "Kill Bill Vol 1");
        notShow(tree, "Movies/Kill Bill Vol 2.mkv", "Kill Bill Vol 2");
        notShow(tree, "Movies/Inception (2010).mkv", "101: Inception");
        notShow(tree, "Movies/1917 (2019).mkv", "1917 (2019)");
        notShow(tree, "Movies/2012 (2009).mkv", "2012 (2009)");
        notShow(tree, "Movies/Movie Part 1.mkv", "two parts");
    }
    {
        // three parts are a show
        Tree tree(numbered("Docs/Documentary Part ", 1, 3, ".mkv", plain));
        const Show show = detect(tree.path("Docs/Documentary Part 1.mkv"));
        check(show.isShow, "three parts: " + show.reason);
        checkEqual(nextCode(show), "Part 2", "next part");
    }
    {
        // 101: a single movie alone
        Tree tree({ "Movies/Inception (2010).mkv" });
        notShow(tree, "Movies/Inception (2010).mkv", "101: Inception alone");
    }
    {
        // 103: phone videos
        QStringList files;
        for (int i = 0; i < 5; ++i)
            files.append(QStringLiteral("DCIM/VID_2024010%1_10101%1.mp4").arg(i + 1));
        files += numbered("Phone/VID_20240101_1010", 10, 14, ".mp4", plain);
        Tree tree(files);
        notShow(tree, "DCIM/VID_20240101_101011.mp4", "103: DCIM phone videos");
        notShow(tree, "Phone/VID_20240101_101012.mp4", "103: phone videos in any folder");
    }
    {
        // 104: OBS recordings
        Tree tree({ "Videos/2024-05-01 18-22-10.mkv", "Videos/2024-05-01 19-01-44.mkv",
                    "Videos/2024-05-02 20-15-03.mkv" });
        notShow(tree, "Videos/2024-05-01 18-22-10.mkv", "104: OBS recordings");
    }
    {
        // 105, 3.7: numbered clips: a weak show only if each lasts 10 minutes (checked by the caller)
        Tree tree(numbered("Clips/clip ", 1, 40, ".mp4", plain));
        const Show show = detect(tree.path("Clips/clip 3.mp4"));
        check(!show.isShow || show.minDurationSec >= 600, "105: 30 s clips are dropped by the length rule");
        checkEqual(show.minDurationSec, 600, "weak minimum length");
        Tree five(numbered("Clips/clip ", 1, 5, ".mp4", plain));
        const Show few = detect(five.path("Clips/clip 1.mp4"));
        check(!few.isShow || few.minDurationSec > 30, "105: five numbered 30 s clips");
    }
    {
        // 106, 3.7: music
        Tree tree(numbered("Music/Album/", 1, 12, " - Song.flac", two));
        notShow(tree, "Music/Album/01 - Song.flac", "106: album folder");
        Options options;
        options.musicRoots = { tree.path("Music") };
        Tree videos(numbered("Music/Videos/Band S01E", 1, 3, ".mkv", two));
        Options videoOptions;
        videoOptions.musicRoots = { videos.path("Music") + QStringLiteral("/") };
        notShow(videos, "Music/Videos/Band S01E01.mkv", "videos inside a music root", videoOptions);
        check(detect(videos.path("Music/Videos/Band S01E01.mkv")).isShow, "the same videos outside a music root");
    }
    {
        // a folder of mostly audio with two videos
        QStringList files = numbered("Album/", 1, 10, " - Song.mp3", two);
        files += numbered("Album/Live S01E", 1, 2, ".mkv", two);
        Tree tree(files);
        notShow(tree, "Album/Live S01E01.mkv", "mostly audio folder");
    }
    {
        // 107, 3.7: podcast mp3 named S01E01
        Tree tree(numbered("Podcast/S01E", 1, 3, ".mp3", two));
        const Show show = detect(tree.path("Podcast/S01E01.mp3"));
        check(!show.isShow, "107: podcast mp3");
        checkEqual(show.reason, "audio file", "podcast reason");
    }
    {
        // 109, 3.7: a sample next to E03 is never next
        Tree tree({ "The Wand/S01/The.Wand.S01E01.mkv", "The Wand/S01/The.Wand.S01E02.mkv",
                    "The Wand/S01/The.Wand.S01E03.sample.mkv", "The Wand/S01/The.Wand.S01E03.mkv",
                    "The Wand/S01/The.Wand.S01E04.mkv" });
        const Show show = detect(tree.path("The Wand/S01/The.Wand.S01E02.mkv"));
        check(show.isShow, "show with a sample: " + show.reason);
        checkEqual(nextName(show), "The.Wand.S01E03.mkv", "109: next is E03, not its sample");
        for (const Episode& e : show.episodes)
            check(!e.fileName.contains(QLatin1String("sample")), "109: sample listed");
        notShow(tree, "The Wand/S01/The.Wand.S01E03.sample.mkv", "109: the sample itself");
    }
    {
        // 110: missing E05
        QStringList files = numbered("The Wand/Season 1/The.Wand.S01E", 1, 4, ".mkv", two);
        files += numbered("The Wand/Season 1/The.Wand.S01E", 6, 9, ".mkv", two);
        Tree tree(files);
        const Show show = detect(tree.path("The Wand/Season 1/The.Wand.S01E04.mkv"));
        check(show.isShow, "missing E05: " + show.reason);
        checkEqual(nextCode(show), "S01E06", "110: E06 after E04");
    }
    {
        // gaps larger than 3 are not a sequence (1, 47, 300)
        Tree tree({ "Talks/Talk Ep 1.mkv", "Talks/Talk Ep 47.mkv", "Talks/Talk Ep 300.mkv" });
        const Show show = detect(tree.path("Talks/Talk Ep 1.mkv"));
        check(!show.isShow, "1, 47, 300");
        checkEqual(show.reason, "gaps too large", "gap reason");
    }
    {
        // 113: multi-episode file
        Tree tree({ "The Wand/The.Wand.S01E01-E02.mkv", "The Wand/The.Wand.S01E03.mkv",
                    "The Wand/The.Wand.S01E04.mkv" });
        const Show show = detect(tree.path("The Wand/The.Wand.S01E01-E02.mkv"));
        check(show.isShow, "multi-episode: " + show.reason);
        checkEqual(nextCode(show), "S01E03", "113: next = last + 1");
        check(show.current >= 0 && code(show.episodes.at(show.current)) == QLatin1String("S01E01-E02"),
              "113: current code is the range");
    }
    {
        // 114: unfinished download skipped
        Tree tree({ "The Wand/The.Wand.S01E01.mkv", "The Wand/The.Wand.S01E02.mkv.part",
                    "The Wand/The.Wand.S01E03.mkv", "The Wand/The.Wand.S01E04.mkv.crdownload",
                    "The Wand/The.Wand.S01E05.mkv.!qB", "The Wand/The.Wand.S01E06.mkv" });
        const Show show = detect(tree.path("The Wand/The.Wand.S01E01.mkv"));
        check(show.isShow, "with downloads: " + show.reason);
        checkEqual(nextCode(show), "S01E03", "114: .part skipped");
        checkEqual(int(show.episodes.size()), 3, "114: unfinished downloads not listed");
        notShow(tree, "The Wand/The.Wand.S01E02.mkv.part", "114: the .part itself");
    }
    {
        // 116, 3.7: plain numbers, title from the folder
        Tree tree(numbered("Anime/", 1, 12, ".mkv", two));
        const Show show = detect(tree.path("Anime/01.mkv"));
        check(show.isShow, "116: Anime/01..12: " + show.reason);
        checkEqual(show.name, "Anime", "116: name");
        checkEqual(nextName(show), "02.mkv", "116: next");
        checkEqual(nextCode(show), "Episode 2", "116: code");
        checkEqual(show.minDurationSec, 600, "116: weak minimum length");

        Tree three(numbered("Anime/", 1, 3, ".mkv", two));
        notShow(three, "Anime/01.mkv", "three plain numbers");
        Tree generic(numbered("Downloads/", 1, 12, ".mkv", two));
        notShow(generic, "Downloads/01.mkv", "plain numbers in Downloads");
        Tree season(numbered("Anime/Season 2/", 1, 6, ".mkv", two));
        const Show inSeason = detect(season.path("Anime/Season 2/03.mkv"));
        check(inSeason.isShow, "plain numbers in a season folder: " + inSeason.reason);
        checkEqual(inSeason.name, "Anime", "plain numbers in a season folder: name");
        checkEqual(nextCode(inSeason), "S02E04", "plain numbers in a season folder: code");
    }
    {
        // 117: two shows in one folder
        QStringList files = numbered("Mixed/A S01E", 1, 3, ".mkv", two);
        files += numbered("Mixed/B S01E", 1, 3, ".mkv", two);
        Tree tree(files);
        const Show a = detect(tree.path("Mixed/A S01E02.mkv"));
        check(a.isShow, "117: show A: " + a.reason);
        checkEqual(int(a.episodes.size()), 3, "117: A has its own three");
        checkEqual(nextName(a), "A S01E03.mkv", "117: A next");
        const Show b = detect(tree.path("Mixed/B S01E03.mkv"));
        checkEqual(b.next(), -1, "117: B ends at its own last");
        for (const Episode& e : b.episodes)
            checkEqual(e.stem, "b", "117: B stem");
    }
    {
        // specials: never next from a season; inside Specials only the specials, in order
        Tree tree({ "The Wand/Season 1/The.Wand.S01E01.mkv", "The Wand/Season 1/The.Wand.S01E02.mkv",
                    "The Wand/Specials/The.Wand.S00E01.mkv", "The Wand/Specials/The.Wand.S00E02.mkv",
                    "The Wand/Season 0/The.Wand.S00E03.mkv" });
        const Show show = detect(tree.path("The Wand/Season 1/The.Wand.S01E02.mkv"));
        checkEqual(show.next(), -1, "specials never next after the last episode");
        for (const Episode& e : show.episodes)
            check(e.season != 0, "specials listed with the seasons");
        const Show specials = detect(tree.path("The Wand/Specials/The.Wand.S00E01.mkv"));
        check(specials.isShow, "specials: " + specials.reason);
        checkEqual(nextCode(specials), "S00E02", "specials in order");
        checkEqual(int(specials.episodes.size()), 2, "only the current specials folder");
        const Show end = detect(tree.path("The Wand/Specials/The.Wand.S00E02.mkv"));
        checkEqual(end.next(), -1, "specials stop at their end");
    }
    {
        // two releases of one episode: one show, the copy is skipped as next
        Tree tree({ "Show/Show S01E01.720p.mkv", "Show/Show S01E01.1080p.mkv", "Show/Show S01E02.mkv" });
        const Show show = detect(tree.path("Show/Show S01E01.1080p.mkv"));
        check(show.isShow, "strong copies: " + show.reason);
        checkEqual(nextCode(show), "S01E02", "copy skipped");
        Tree weak(numbered("Lessons/Lesson ", 1, 4, ".mkv", plain) + QStringList { "Lessons/Lesson 2 extra.mkv" });
        notShow(weak, "Lessons/Lesson 1.mkv", "weak numbers used twice");
    }
    {
        // other extensions and options
        Tree tree(numbered("Show/Show S01E", 1, 3, ".xyz", two));
        notShow(tree, "Show/Show S01E01.xyz", "unknown extension");
        Options options;
        options.videoExtensions = { ".XYZ" };
        check(detect(tree.path("Show/Show S01E01.xyz"), options).isShow, "own video extension list");
    }
    {
        // a strong pair is enough, a medium pair is not
        Tree strong({ "Pair/Pair S01E01.mkv", "Pair/Pair S01E02.mkv" });
        check(detect(strong.path("Pair/Pair S01E01.mkv")).isShow, "two strong episodes");
        Tree medium({ "Pair/Pair Episode 1.mkv", "Pair/Pair Episode 2.mkv" });
        notShow(medium, "Pair/Pair Episode 1.mkv", "two medium episodes");
        Tree single({ "One/One S01E01.mkv" });
        notShow(single, "One/One S01E01.mkv", "a single strong episode");
    }
}

} // namespace

int main()
{
    testParse();
    testExcluded();
    testSeasonFolders();
    testShows();
    std::printf("rd_episode_parser: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
