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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "rd_episode_parser.hpp"

#include "dialogs/redesign/addsubtitles/subtitle_matcher.hpp"

#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>

#include <algorithm>

namespace rdepisode {

namespace {

constexpr auto caseless = QRegularExpression::CaseInsensitiveOption;

#ifdef _WIN32
constexpr Qt::CaseSensitivity pathCase = Qt::CaseInsensitive;
#else
constexpr Qt::CaseSensitivity pathCase = Qt::CaseSensitive;
#endif

const QStringList& defaultVideoExtensions()
{
    static const QStringList list {
        "mkv", "mp4", "avi", "mov", "m4v", "webm", "wmv", "flv", "mpg", "mpeg", "ts", "m2ts",
        "ogv", "3gp", "divx", "vob"
    };
    return list;
}

const QStringList& defaultAudioExtensions()
{
    static const QStringList list {
        "mp3", "flac", "m4a", "aac", "ogg", "opus", "wav", "wma", "ape", "alac"
    };
    return list;
}

// unfinished downloads (qBittorrent, uTorrent, Chrome, Firefox, Safari)
const QSet<QString>& partialExtensions()
{
    static const QSet<QString> list { "part", "partial", "!qb", "!ut", "crdownload", "download" };
    return list;
}

// release and encoding tags: never part of a stem or an episode title
const QSet<QString>& releaseNoise()
{
    static const QSet<QString> tags {
        "480p", "576p", "720p", "1080p", "1080i", "2160p", "4k", "uhd", "fhd", "hd", "sd",
        "x264", "x265", "h264", "h265", "hevc", "avc", "xvid", "divx", "av1", "vp9", "10bit", "8bit",
        "web", "webrip", "webdl", "dl", "bluray", "bdrip", "brrip", "bdremux", "remux", "dvdrip",
        "hdtv", "hdrip", "tvrip", "aac", "ac3", "eac3", "dts", "ddp", "dd", "atmos", "truehd",
        "hdr", "hdr10", "sdr", "proper", "repack", "rerip", "extended", "unrated", "internal",
        "amzn", "nf", "dsnp", "hmax", "atvp", "hulu", "pcok", "yify", "yts", "rarbg", "eztv",
        "ettv", "mkv", "mp4", "avi"
    };
    return tags;
}

// a token of a name in lower case; "web-dl" and "x264-grp" are judged by their first part
bool isNoise(const QString& token)
{
    QString t = token;
    const qsizetype dash = t.indexOf(QChar('-'));
    if (dash > 0)
        t.truncate(dash);
    if (releaseNoise().contains(t))
        return true;
    static const QRegularExpression pattern(QStringLiteral(
        "^(?:\\d{3,4}[pi]|\\d{3,4}x\\d{3,4}|[xh]26[45]|\\d{1,2}bits?|(?:ddp?|aac|e?ac3|dts|truehd)\\d*)$"));
    return pattern.match(t).hasMatch();
}

bool isYear(const QString& token)
{
    static const QRegularExpression year(QStringLiteral("^(?:19|20)\\d{2}$"));
    return year.match(token).hasMatch();
}

bool isNumber(const QString& token)
{
    if (token.isEmpty())
        return false;
    for (const QChar c : token)
        if (!c.isDigit())
            return false;
    return true;
}

QString fileNameOf(const QString& path)
{
    const qsizetype slash = std::max(path.lastIndexOf(QChar('/')), path.lastIndexOf(QChar('\\')));
    return slash >= 0 ? path.mid(slash + 1) : path;
}

QString suffixOf(const QString& fileName)
{
    const qsizetype dot = fileName.lastIndexOf(QChar('.'));
    return dot > 0 ? fileName.mid(dot + 1).toLower() : QString();
}

// without its extension: a known media or download extension, or up to four letters
// ("The.Wand.S01E02" without an extension keeps its episode)
QString stripExtension(const QString& fileName)
{
    const qsizetype dot = fileName.lastIndexOf(QChar('.'));
    if (dot <= 0)
        return fileName;
    const QString ext = fileName.mid(dot + 1).toLower();
    bool letters = !ext.isEmpty() && ext.size() <= 4;
    for (const QChar c : ext)
        letters = letters && c.isLetter();
    if (letters || defaultVideoExtensions().contains(ext) || defaultAudioExtensions().contains(ext)
            || partialExtensions().contains(ext))
        return fileName.left(dot);
    return fileName;
}

// lower case words of letters and digits, single spaces ("Behind.The_Scenes" -> "behind the scenes")
QString plainWords(const QString& text)
{
    QString lower = text.toLower();
    lower.remove(QChar('\''));
    lower.remove(QChar(0x2019));
    QString spaced;
    spaced.reserve(lower.size());
    for (const QChar c : lower)
        spaced += c.isLetterOrNumber() ? c : QChar(' ');
    return spaced.split(QChar(' '), Qt::SkipEmptyParts).join(QChar(' '));
}

// the name with its brackets, audio channels and separators made plain, case kept:
// "The.Wand.S01E02.DDP5.1.H.264-GRP [abc]" -> "The Wand S01E02 DDP H264-GRP"
QString clean(QString text)
{
    static const QRegularExpression groups(QStringLiteral("\\[[^\\]]*\\]|\\{[^}]*\\}"));
    static const QRegularExpression channels(QStringLiteral("(?<!\\d)[257]\\.[01](?!\\d)"));
    static const QRegularExpression codec(QStringLiteral("\\b([hx])\\.(26[45])\\b"), caseless);
    static const QRegularExpression separators(QStringLiteral("[._()\\s]+"));
    text.replace(groups, QStringLiteral(" "));
    text.replace(channels, QStringLiteral(" "));
    text.replace(codec, QStringLiteral("\\1\\2"));
    text.replace(separators, QStringLiteral(" "));
    return text.trimmed();
}

struct Token
{
    qsizetype start = -1;
    qsizetype end = -1;
    int season = -1;
    int episode = -1;
    int last = -1;
    Strength strength = Strength::None;
    bool part = false;
};

Token tokenOf(const QRegularExpressionMatch& m, Strength strength, int seasonGroup, int episodeGroup)
{
    Token token;
    token.start = m.capturedStart(0);
    token.end = m.capturedEnd(0);
    token.season = seasonGroup > 0 ? m.captured(seasonGroup).toInt() : -1;
    token.episode = m.captured(episodeGroup).toInt();
    token.last = token.episode;
    token.strength = strength;
    return token;
}

// the plain number of a weak name: the first one before any release tag that is not a
// resolution, a codec, a bit depth or the number of a season, volume, part or disc
Token weakToken(const QString& text)
{
    static const QRegularExpression word(QStringLiteral("[^\\s-]+"));
    static const QSet<int> guarded { 480, 576, 720, 264, 265 };
    static const QSet<QString> counters {
        "season", "series", "staffel", "saison", "temporada", "vol", "volume", "part", "pt",
        "chapter", "disc", "disk", "cd", "dvd"
    };

    QVector<QRegularExpressionMatch> words;
    QRegularExpressionMatchIterator it = word.globalMatch(text);
    while (it.hasNext())
        words.append(it.next());

    QString previous;
    for (qsizetype i = 0; i < words.size(); ++i)
    {
        const QString t = words.at(i).captured(0).toLower();
        if (isNoise(t))
            break;
        if (isNumber(t) && t.size() <= 3)
        {
            const QString following = i + 1 < words.size() ? words.at(i + 1).captured(0).toLower() : QString();
            const int value = t.toInt();
            if (!guarded.contains(value) && !counters.contains(previous)
                    && following != QLatin1String("bit") && following != QLatin1String("bits"))
                return tokenOf(words.at(i), Strength::Weak, 0, 0);
        }
        previous = t;
    }
    return {};
}

Token findToken(const QString& text)
{
    // S01E02, S01 E02, S1 Ep 2, S01E01-E02, S01E01E02, S01E01-02
    static const QRegularExpression seasonEpisode(QStringLiteral(
        "\\bs(\\d{1,2})[\\s-]{0,3}e(?:p(?:isode)?)?\\s?(\\d{1,3})(?:-?e(\\d{1,3})|-(\\d{1,3}))?(?![\\da-z])"), caseless);
    static const QRegularExpression seasonWords(QStringLiteral(
        "\\bseason\\s?(\\d{1,2})[\\s,-]{0,3}ep(?:isode)?\\s?(\\d{1,3})(?![\\da-z])"), caseless);
    // 1x02, not 1920x1080 (no digit before) nor x264 (a digit needed before the x)
    static const QRegularExpression crossed(QStringLiteral(
        "(?<![\\da-z])(\\d{1,2})x(\\d{2,3})(?![\\da-z])"), caseless);
    static const QRegularExpression episodeWord(QStringLiteral(
        "\\bep(?:isode)?\\s?(\\d{1,3})(?![\\da-z])"), caseless);
    static const QRegularExpression episodeLetter(QStringLiteral("\\be(\\d{2,3})(?![\\da-z])"), caseless);
    static const QRegularExpression partWord(QStringLiteral(
        "\\b(?:part|pt)\\s?(\\d{1,2})(?![\\da-z])"), caseless);

    QRegularExpressionMatch m = seasonEpisode.match(text);
    if (m.hasMatch())
    {
        Token token = tokenOf(m, Strength::Strong, 1, 2);
        const int range = m.hasCaptured(3) ? 3 : (m.hasCaptured(4) ? 4 : 0);
        if (range > 0)
        {
            const int last = m.captured(range).toInt();
            // a range of a few episodes; anything else is not part of the token
            if (last > token.episode && last - token.episode <= 10)
                token.last = last;
            else
                token.end = m.capturedEnd(2);
        }
        return token;
    }
    if ((m = seasonWords.match(text)).hasMatch())
        return tokenOf(m, Strength::Strong, 1, 2);
    if ((m = crossed.match(text)).hasMatch())
        return tokenOf(m, Strength::Strong, 1, 2);
    if ((m = episodeWord.match(text)).hasMatch() || (m = episodeLetter.match(text)).hasMatch())
        return tokenOf(m, Strength::Medium, 0, 1);
    if ((m = partWord.match(text)).hasMatch())
    {
        Token token = tokenOf(m, Strength::Medium, 0, 1);
        token.part = true;
        return token;
    }
    return weakToken(text);
}

// the show title words before the token: lower case, without release tags, years and season
// words ("Doctor Who (2005) S02" -> "doctor who", season 2)
QString stemOf(const QString& text, int* season)
{
    static const QRegularExpression seasonToken(QStringLiteral("^s(\\d{1,2})$"));
    static const QSet<QString> seasonWords { "season", "series", "staffel", "saison", "temporada" };

    const QStringList tokens = plainWords(text).split(QChar(' '), Qt::SkipEmptyParts);
    QStringList kept;
    for (qsizetype i = 0; i < tokens.size(); ++i)
    {
        const QString& t = tokens.at(i);
        if (seasonWords.contains(t) && i + 1 < tokens.size() && isNumber(tokens.at(i + 1)))
        {
            *season = tokens.at(i + 1).toInt();
            ++i;
            continue;
        }
        const QRegularExpressionMatch m = seasonToken.match(t);
        if (m.hasMatch())
        {
            *season = m.captured(1).toInt();
            continue;
        }
        if (isNoise(t) || isYear(t))
            continue;
        kept.append(t);
    }
    return kept.join(QChar(' '));
}

// the episode title after the token, as written, up to the first release tag
// ("- The Second Spark 1080p WEB-DL" -> "The Second Spark")
QString titleOf(const QString& text)
{
    QStringList kept;
    for (const QString& t : text.split(QChar(' '), Qt::SkipEmptyParts))
    {
        bool separator = true;
        for (const QChar c : t)
            separator = separator && (c == QChar('-') || c == QChar(0x2013) || c == QChar(0x2014)
                                      || c == QChar('|') || c == QChar('~'));
        if (separator)
            continue;
        const QString lower = t.toLower();
        if (isNoise(lower))
            break;
        if (isYear(lower))
            continue;
        kept.append(t);
    }
    return kept.join(QChar(' '));
}

const QSet<QString>& extraFolders()
{
    static const QSet<QString> names {
        "extras", "extra", "featurettes", "featurette", "behind the scenes", "deleted scenes",
        "interviews", "trailers", "trailer", "samples", "sample", "bonus", "shorts", "other", "scenes"
    };
    return names;
}

// folder names that never supply a show title for numbered files ("Downloads/01.mkv")
const QSet<QString>& genericFolders()
{
    static const QSet<QString> names {
        "videos", "video", "my videos", "movies", "movie", "films", "film", "downloads", "download",
        "desktop", "documents", "new folder", "clips", "media", "tv", "tv shows", "shows", "series",
        "temp", "tmp"
    };
    return names;
}

bool inside(const QString& path, const QString& root)
{
    QString folder = QDir::cleanPath(QDir::fromNativeSeparators(root));
    if (folder.isEmpty())
        return false;
    if (!folder.endsWith(QChar('/')))
        folder += QChar('/');
    return path.startsWith(folder, pathCase);
}

QStringList extensions(const QStringList& list, const QStringList& fallback)
{
    if (list.isEmpty())
        return fallback;
    QStringList result;
    for (const QString& ext : list)
    {
        QString e = ext.trimmed().toLower();
        if (e.startsWith(QChar('.')))
            e.remove(0, 1);
        result.append(e);
    }
    return result;
}

int classOf(const Episode& e)
{
    return int(e.strength) * 2 + (e.part ? 1 : 0);
}

} // namespace

Episode parse(const QString& path)
{
    Episode e;
    e.path = path;
    e.fileName = fileNameOf(path);

    const QString text = clean(stripExtension(e.fileName));
    const Token token = findToken(text);
    int stemSeason = -1;
    if (token.strength == Strength::None)
    {
        e.stem = stemOf(text, &stemSeason);
        return e;
    }

    e.season = token.season;
    e.episode = token.episode;
    e.lastEpisode = token.last;
    e.strength = token.strength;
    e.part = token.part;
    e.stem = stemOf(text.left(token.start), &stemSeason);
    // "The Wand Season 2 - E05"
    if (e.season < 0)
        e.season = stemSeason;
    e.title = titleOf(text.mid(token.end));
    return e;
}

QString code(const Episode& e)
{
    if (e.episode < 0)
        return {};
    if (e.part)
        return QStringLiteral("Part %1").arg(e.episode);
    if (e.season < 0 || e.seasonDefaulted)
        return QStringLiteral("Episode %1").arg(e.episode);
    QString text = QStringLiteral("S%1E%2").arg(e.season, 2, 10, QChar('0')).arg(e.episode, 2, 10, QChar('0'));
    if (e.lastEpisode > e.episode)
        text += QStringLiteral("-E%1").arg(e.lastEpisode, 2, 10, QChar('0'));
    return text;
}

bool excluded(const QString& path)
{
    static const QRegularExpression slashes(QStringLiteral("[/\\\\]"));
    QStringList parts = path.split(slashes, Qt::SkipEmptyParts);
    if (parts.isEmpty())
        return false;
    const QString fileName = parts.takeLast();

    // Extras / Featurettes ..., camera and recording folders: the file's own folder only, a
    // show kept in a folder named "Other" still counts
    static const QRegularExpression recordingFolder(QStringLiteral(
        "^(?:dcim|camera|camera roll|screen ?recordings?|screencasts?|captures?|recordings?)$"));
    if (!parts.isEmpty())
    {
        const QString folder = plainWords(parts.constLast());
        if (extraFolders().contains(folder) || recordingFolder.match(folder).hasMatch())
            return true;
    }

    if (partialExtensions().contains(suffixOf(fileName)))
        return true;

    const QString base = stripExtension(fileName).toLower();
    // Plex / Jellyfin extras suffixes
    static const QRegularExpression suffix(QStringLiteral(
        "-(?:behindthescenes|deleted|featurette|interview|scene|short|trailer|other|sample)$"));
    // phones and cameras: IMG_, VID_, MVI_, DSC, GoPro, Pixel, DJI
    static const QRegularExpression camera(QStringLiteral(
        "^(?:(?:img|vid|mvi|pxl|dji)[_-]|dsc[a-z]?[_-]?\\d|gopr\\d|g[phx]\\d{6}|vid\\d{8})"));
    // OBS ("2024-05-01 18-22-10") and other names that are only a date and a time
    static const QRegularExpression date(QStringLiteral(
        "^(?:19|20)\\d{2}[-_. ]?\\d{2}[-_. ]?\\d{2}(?:[-_. t]+\\d{2}[-_.: ]?\\d{2}(?:[-_.: ]?\\d{2})?)?(?:[-_ ]?\\d{1,4})?$"));
    if (suffix.match(base).hasMatch() || camera.match(base).hasMatch() || date.match(base).hasMatch())
        return true;

    // "other", "scenes", "shorts", "bonus" and "interviews" only count as folder names: as
    // words they are part of real titles ("The Other Two")
    static const QRegularExpression extraWords(QStringLiteral(
        "\\b(?:samples?|trailers?|teaser|promo|nc(?:op|ed)\\d*|creditless|extras|featurettes?"
        "|behind the scenes|deleted scenes?|screen ?recordings?|screencasts?|screen ?captures?"
        "|recordings?|captures?)\\b"));
    return extraWords.match(plainWords(base)).hasMatch();
}

int seasonFolderNumber(const QString& folderName)
{
    static const QRegularExpression pattern(QStringLiteral(
        "^(?:(?:season|series|staffel|saison|temporada)[\\s._-]*(\\d{1,3})|s(\\d{1,3}))(?:\\s*[\\[(].*)?$"), caseless);
    static const QRegularExpression specials(QStringLiteral("^specials?$"), caseless);

    const QString name = folderName.trimmed();
    const QRegularExpressionMatch m = pattern.match(name);
    if (m.hasMatch())
        return m.captured(m.hasCaptured(1) ? 1 : 2).toInt();
    if (specials.match(name).hasMatch())
        return 0;
    return -1;
}

bool isSpecialsFolder(const QString& folderName)
{
    return seasonFolderNumber(folderName) == 0;
}

int Show::next() const
{
    if (current < 0 || current >= episodes.size())
        return -1;
    const Episode& now = episodes.at(current);
    for (qsizetype i = current + 1; i < episodes.size(); ++i)
    {
        const Episode& e = episodes.at(i);
        // a copy of an episode the current file already covers
        if (e.season == now.season && e.episode <= now.lastEpisode)
            continue;
        return int(i);
    }
    return -1;
}

bool Show::nextIsNewSeason() const
{
    const int n = next();
    return n >= 0 && episodes.at(n).season != episodes.at(current).season;
}

Show detect(const QString& filePath, const Options& options)
{
    Show show;
    const auto fail = [&show](const char* reason) {
        show.isShow = false;
        show.reason = QString::fromLatin1(reason);
        show.episodes.clear();
        show.current = -1;
        show.minDurationSec = 0;
        return show;
    };

    const QStringList video = extensions(options.videoExtensions, defaultVideoExtensions());
    const QStringList audio = extensions(options.audioExtensions, defaultAudioExtensions());

    const QFileInfo file(filePath);
    const QString suffix = file.suffix().toLower();
    if (audio.contains(suffix))
        return fail("audio file");
    if (!video.contains(suffix))
        return fail("not a video file");

    const QString absolute = QDir::cleanPath(file.absoluteFilePath());
    for (const QString& root : options.musicRoots)
        if (inside(absolute, root))
            return fail("inside a music folder");
    if (excluded(absolute))
        return fail("excluded name or folder");

    const QDir folder = file.absoluteDir();
    const QString folderPath = QDir::cleanPath(folder.absolutePath());
    const int folderSeason = seasonFolderNumber(folder.dirName());

    // the folders of the show and their season numbers (-1: no season folder)
    QVector<QPair<QString, int>> folders;
    if (folderSeason >= 0)
    {
        QDir rootDir = folder;
        rootDir.cdUp();
        show.root = QDir::cleanPath(rootDir.absolutePath());
        // inside Specials only the specials play
        if (folderSeason == 0)
            folders.append({ folderPath, 0 });
        else
        {
            const QFileInfoList subfolders = rootDir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
            for (const QFileInfo& sub : subfolders)
            {
                const int number = seasonFolderNumber(sub.fileName());
                if (number > 0)
                    folders.append({ QDir::cleanPath(sub.absoluteFilePath()), number });
            }
        }
    }
    else
    {
        show.root = folderPath;
        folders.append({ folderPath, -1 });
    }
    show.name = QFileInfo(show.root).fileName();

    int audioFiles = 0;
    int videoFiles = 0;
    QVector<Episode> all;
    for (const auto& [path, season] : folders)
    {
        const bool currentFolder = path.compare(folderPath, pathCase) == 0;
        const QFileInfoList entries = QDir(path).entryInfoList(QDir::Files | QDir::NoDotAndDotDot);
        for (const QFileInfo& info : entries)
        {
            // macOS resource forks on other file systems
            if (info.fileName().startsWith(QLatin1String("._")))
                continue;
            const QString ext = info.suffix().toLower();
            if (audio.contains(ext))
            {
                audioFiles += currentFolder ? 1 : 0;
                continue;
            }
            if (!video.contains(ext))
                continue;
            videoFiles += currentFolder ? 1 : 0;

            const QString entryPath = QDir::cleanPath(info.absoluteFilePath());
            if (excluded(entryPath))
                continue;
            Episode e = parse(entryPath);
            if (e.strength == Strength::None)
                continue;
            if (e.season < 0)
            {
                e.season = season >= 0 ? season : 1;
                e.seasonDefaulted = season < 0;
            }
            all.append(e);
        }
    }
    if (audioFiles > videoFiles)
        return fail("mostly audio");

    const auto isCurrent = [&absolute](const Episode& e) {
        return e.path.compare(absolute, pathCase) == 0;
    };
    const auto found = std::find_if(all.cbegin(), all.cend(), isCurrent);
    if (found == all.cend())
        return fail(parse(absolute).strength == Strength::None ? "no episode number" : "file not listed");
    const Episode now = *found;

    // the current file's show: same stem and kind of token; specials stay among themselves
    QVector<Episode> group;
    for (const Episode& e : all)
        if (e.stem == now.stem && classOf(e) == classOf(now) && (e.season == 0) == (now.season == 0))
            group.append(e);

    if (now.strength == Strength::Weak && now.stem.isEmpty())
    {
        // the folder supplies the title ("Anime/01.mkv"), not "Downloads" or "2024"
        const QString title = plainWords(show.name);
        if (title.isEmpty() || isNumber(QString(title).remove(QChar(' '))) || genericFolders().contains(title)
                || seasonFolderNumber(title) >= 0)
            return fail("no show title");
    }

    const int needed = now.strength == Strength::Strong ? 2 : (now.strength == Strength::Weak ? 4 : 3);
    if (group.size() < needed)
        return fail("too few episodes");

    std::sort(group.begin(), group.end(), [](const Episode& a, const Episode& b) {
        if (a.season != b.season)
            return a.season < b.season;
        if (a.episode != b.episode)
            return a.episode < b.episode;
        return SubtitleMatcher::naturalCompare(a.fileName, b.fileName) < 0;
    });

    // distinct numbers with small gaps; copies of an episode only for strong names (two
    // releases of S01E02), a weak or medium number used twice means two different things
    for (qsizetype i = 1; i < group.size(); ++i)
    {
        const Episode& previous = group.at(i - 1);
        const Episode& e = group.at(i);
        if (e.season != previous.season)
            continue;
        if (e.episode <= previous.lastEpisode)
        {
            if (now.strength != Strength::Strong)
                return fail("numbers repeat");
            continue;
        }
        if (e.episode - previous.lastEpisode > 3)
            return fail("gaps too large");
    }

    show.episodes = group;
    show.current = int(std::find_if(group.cbegin(), group.cend(), isCurrent) - group.cbegin());
    show.minDurationSec = now.strength == Strength::Weak ? 600 : 120;
    show.isShow = true;
    return show;
}

} // namespace rdepisode
