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

#ifndef RD_EPISODE_PARSER_HPP
#define RD_EPISODE_PARSER_HPP

#include <QString>
#include <QStringList>
#include <QVector>

/**
 * redesign (Up Next, UP_NEXT_PLAN.md section 3): strict show detection. A file name is read as
 * a show title (the stem), an episode token and what is left (the episode title); a folder is a
 * show only when enough of its video files share the stem and the kind of token and their
 * numbers form a sequence. A single movie, a two-part movie, camera and screen recordings,
 * clips, music and podcasts never count: a missed show only costs what Cone does today.
 *
 * QtCore only; parse(), code(), excluded() and the folder name functions are pure, detect()
 * reads the file system (call it on a worker thread).
 */
namespace rdepisode {

// how sure the episode token is: SxxEyy / NxNN / "Season 1 Episode 2" are strong, "Episode 2",
// "E02" and "Part 3" medium, a plain number weak
enum class Strength { None = 0, Weak = 1, Medium = 2, Strong = 3 };

struct Episode
{
    // absolute file path (as given)
    QString path;
    // file name with extension
    QString fileName;
    // normalised show title part ("the wand"), may be empty
    QString stem;
    // -1 unknown
    int season = -1;
    // first episode number
    int episode = -1;
    // multi-episode files (S01E01-E02): last number, else == episode
    int lastEpisode = -1;
    Strength strength = Strength::None;
    // came from "Part N" / "Pt N"
    bool part = false;
    // detect() only: neither the name nor a season folder gave the season, 1 is assumed
    bool seasonDefaulted = false;
    // what is left after stem, token and release noise ("The Second Spark"), may be empty
    QString title;
};

// parses a file name (with or without folders); pure function
Episode parse(const QString& path);

// "S01E02", "S01E01-E02", "Episode 2" when there is no season, "Part 2" for parts
QString code(const Episode& e);

// true for names and folders that must never count: extras, samples, trailers, camera and
// screen recordings, unfinished downloads (plan 3.3 item 5 and 3.4). The file name and its own
// folder are checked; other extensions (audio ...) are left to detect()
bool excluded(const QString& path);

// season folder names: Season 1, Season 01, S01, S1, Series 2, Staffel 1, Saison 1,
// Temporada 1 (case-insensitive); returns the number (0 for Specials) or -1
int seasonFolderNumber(const QString& folderName);

// Season 0 / S00 / Specials
bool isSpecialsFolder(const QString& folderName);

struct Options
{
    // library music folders: anything inside never counts
    QStringList musicRoots;
    // default list used when empty (mkv mp4 avi mov m4v webm wmv flv mpg mpeg ts m2ts ogv 3gp divx vob)
    QStringList videoExtensions;
    // default list used when empty (mp3 flac m4a aac ogg opus wav wma ape alac)
    QStringList audioExtensions;
};

struct Show
{
    bool isShow = false;
    // short reason when not a show (for logs and tests)
    QString reason;
    // show root folder (parent of the season folder, or the episode's folder)
    QString root;
    // display name: the root folder's name ("The Wand")
    QString name;
    // the show's episodes in play order (season, episode, then natural file name); specials
    // folders are left out unless the current file is in one (then only that folder)
    QVector<Episode> episodes;
    // index of the given file in `episodes`
    int current = -1;
    // the current file must last at least this long (120 strong / medium, 600 weak): checked
    // by the caller once the length is known
    int minDurationSec = 0;

    // index of the next episode, -1 after the last one: skips what a multi-episode file covers,
    // takes the next existing number over a gap, and the next season's first episode after the
    // last of a season
    int next() const;
    bool nextIsNewSeason() const;
};

// blocking file-system scan (worker thread): the folder of `filePath` and, when it is a season
// folder, its sibling season folders under the show root; never deeper
Show detect(const QString& filePath, const Options& options = {});

} // namespace rdepisode

#endif // RD_EPISODE_PARSER_HPP
