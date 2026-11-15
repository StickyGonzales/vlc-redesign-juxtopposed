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

#include "subtitle_matcher.hpp"

#include <QHash>
#include <QRegularExpression>
#include <QSet>

#include <algorithm>

namespace {

// release and encoding tags: not part of a title or a variant
const QSet<QString>& releaseTags()
{
    static const QSet<QString> tags {
        "480p", "576p", "720p", "1080p", "1080i", "2160p", "4k", "uhd", "hd", "sd", "fhd",
        "x264", "x265", "h264", "h265", "hevc", "avc", "xvid", "divx", "av1", "vp9",
        "web", "webrip", "webdl", "dl", "bluray", "blu", "ray", "brrip", "bdrip", "bdremux",
        "dvdrip", "dvd", "hdtv", "hdrip", "tvrip", "remux", "aac", "aac2", "ac3", "eac3",
        "dts", "ddp", "ddp5", "dd5", "atmos", "truehd", "flac", "opus", "mp3", "10bit", "8bit",
        "hdr", "hdr10", "dv", "sdr", "proper", "repack", "rerip", "extended", "unrated",
        "internal", "limited", "amzn", "nf", "dsnp", "hmax", "atvp", "hulu", "pcok", "max",
        "yify", "yts", "rarbg", "eztv", "ettv", "subs", "sub", "subtitle", "subtitles", "srt",
        "complete", "season", "episode", "ep"
    };
    return tags;
}

// words that tell subtitle variants apart besides the language
const QSet<QString>& variantWords()
{
    static const QSet<QString> words {
        "forced", "sdh", "hi", "cc", "full", "signs", "songs", "commentary", "sign", "default"
    };
    return words;
}

struct Language
{
    const char* code;
    // English and native names, ISO 639-2 codes (three letters)
    std::initializer_list<const char*> words;
};

// the languages OpenSubtitles lists most, by two letter code; three letter codes that are also
// common English words ("may", "per", "cat", "ice") are left out
const QHash<QString, QString>& languageWords()
{
    static const QHash<QString, QString> table = [] {
        static const Language languages[] = {
            { "en", { "english", "eng" } },
            { "es", { "spanish", "spa", "espanol", "castellano", "latino", "esp" } },
            { "fr", { "french", "fre", "fra", "francais", "vf", "vff" } },
            { "de", { "german", "ger", "deu", "deutsch" } },
            { "it", { "italian", "ita", "italiano" } },
            { "pt", { "portuguese", "por", "portugues" } },
            { "pt-br", { "brazilian", "ptbr", "pob" } },
            { "nl", { "dutch", "dut", "nld", "nederlands" } },
            { "pl", { "polish", "pol", "polski" } },
            { "ru", { "russian", "rus" } },
            { "tr", { "turkish", "tur", "turkce" } },
            { "ar", { "arabic", "ara" } },
            { "he", { "hebrew", "heb" } },
            { "ja", { "japanese", "jpn", "jap" } },
            { "ko", { "korean", "kor" } },
            { "zh-cn", { "chinese", "chi", "zho", "chs", "simplified" } },
            { "zh-tw", { "cht", "traditional" } },
            { "sv", { "swedish", "swe", "svenska" } },
            { "no", { "norwegian", "nor", "norsk" } },
            { "da", { "danish", "dan", "dansk" } },
            { "fi", { "finnish", "fin", "suomi" } },
            { "cs", { "czech", "cze", "ces" } },
            { "hu", { "hungarian", "hun", "magyar" } },
            { "ro", { "romanian", "rum", "ron" } },
            { "el", { "greek", "gre", "ell" } },
            { "bg", { "bulgarian", "bul" } },
            { "uk", { "ukrainian", "ukr" } },
            { "hr", { "croatian", "hrv" } },
            { "sr", { "serbian", "srp" } },
            { "sl", { "slovenian", "slv" } },
            { "sk", { "slovak", "slk" } },
            { "vi", { "vietnamese", "vie" } },
            { "th", { "thai", "tha" } },
            { "id", { "indonesian", "ind" } },
            { "ms", { "malay", "msa" } },
            { "hi", { "hindi", "hin" } },
            { "fa", { "persian", "farsi", "fas" } },
            { "et", { "estonian" } },
            { "lv", { "latvian", "lav" } },
            { "lt", { "lithuanian", "lit" } },
            { "ca", { "catalan" } },
            { "eu", { "basque", "eus" } },
            { "gl", { "galician", "glg" } },
            { "is", { "icelandic", "isl" } },
            { "ta", { "tamil", "tam" } },
            { "te", { "telugu", "tel" } },
            { "bn", { "bengali", "ben" } },
            { "ur", { "urdu", "urd" } },
        };
        QHash<QString, QString> words;
        for (const Language& language : languages)
            for (const char* word : language.words)
                words.insert(QString::fromLatin1(word), QString::fromLatin1(language.code));
        return words;
    }();
    return table;
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

// the words of a name: letters and digits only
QStringList words(const QString& base)
{
    QString text;
    text.reserve(base.size());
    for (const QChar c : base)
        text += c.isLetterOrNumber() ? c : QChar(' ');
    return text.split(QChar(' '), Qt::SkipEmptyParts);
}

QStringList tokenize(const QString& base)
{
    return words(base.toLower());
}

double overlap(const QStringList& a, const QStringList& b)
{
    if (a.isEmpty() || b.isEmpty())
        return 0.;
    const QSet<QString> sa(a.cbegin(), a.cend());
    const QSet<QString> sb(b.cbegin(), b.cend());
    const QSet<QString> common = QSet<QString>(sa).intersect(sb);
    QSet<QString> all = sa;
    all.unite(sb);
    return all.isEmpty() ? 0. : double(common.size()) / double(all.size());
}

// the title words written together ("thewand" for "The Wand"): file names often drop spaces
QString joined(const QStringList& tokens)
{
    return tokens.join(QString());
}

bool sameEpisode(const SubtitleMatcher::Name& a, const SubtitleMatcher::Name& b)
{
    if (a.season >= 0 && b.season >= 0)
        return a.season == b.season && a.episode == b.episode;
    if (a.episode == b.episode)
        return true;
    // "Show 104" against "Show S01E04"
    if (a.season >= 0)
        return b.episode == a.season * 100 + a.episode;
    if (b.season >= 0)
        return a.episode == b.season * 100 + b.episode;
    return false;
}

} // namespace

QString SubtitleMatcher::languageCode(const QString& word, bool allowTwoLetters)
{
    const QString w = word.toLower();
    const auto it = languageWords().constFind(w);
    if (it != languageWords().cend())
        return it.value();
    if (allowTwoLetters && w.size() == 2 && w.at(0).isLetter() && w.at(1).isLetter())
    {
        for (const QString& code : languageWords())
            if (code == w)
                return code;
    }
    return {};
}

SubtitleMatcher::Name SubtitleMatcher::parse(const QString& fileName)
{
    Name name;

    // the extension only ("show.en.srt" keeps "en")
    QString base = fileName;
    const qsizetype slash = std::max(base.lastIndexOf(QChar('/')), base.lastIndexOf(QChar('\\')));
    if (slash >= 0)
        base = base.mid(slash + 1);
    const qsizetype dot = base.lastIndexOf(QChar('.'));
    if (dot > 0 && base.size() - dot <= 5)
        base.truncate(dot);

    const QStringList original = words(base);
    const QStringList tokens = tokenize(base);
    name.normalized = tokens.join(QChar(' '));

    static const QRegularExpression seasonEpisode(QStringLiteral("^s(\\d{1,2})e(\\d{1,3})(?:e\\d{1,3})?$"));
    static const QRegularExpression crossed(QStringLiteral("^(\\d{1,2})x(\\d{1,3})$"));
    static const QRegularExpression seasonOnly(QStringLiteral("^s(\\d{1,2})$"));
    static const QRegularExpression episodeOnly(QStringLiteral("^(?:e|ep)(\\d{1,3})$"));

    // [first, last] tokens of the episode marker
    qsizetype first = -1;
    qsizetype last = -1;
    int season = -1;

    for (qsizetype i = 0; i < tokens.size() && first < 0; ++i)
    {
        const QString& t = tokens.at(i);
        QRegularExpressionMatch m;
        if ((m = seasonEpisode.match(t)).hasMatch() || (m = crossed.match(t)).hasMatch())
        {
            name.season = m.captured(1).toInt();
            name.episode = m.captured(2).toInt();
            first = last = i;
        }
        else if ((m = seasonOnly.match(t)).hasMatch())
        {
            season = m.captured(1).toInt();
            // "S01 E04"
            if (i + 1 < tokens.size())
            {
                const QRegularExpressionMatch e = episodeOnly.match(tokens.at(i + 1));
                if (e.hasMatch())
                {
                    name.season = season;
                    name.episode = e.captured(1).toInt();
                    first = i;
                    last = i + 1;
                }
            }
        }
        else if (t == QLatin1String("season") && i + 1 < tokens.size() && isNumber(tokens.at(i + 1)))
        {
            season = tokens.at(i + 1).toInt();
            ++i;
        }
        else if ((t == QLatin1String("episode") || t == QLatin1String("ep"))
                 && i + 1 < tokens.size() && isNumber(tokens.at(i + 1)))
        {
            name.season = season;
            name.episode = tokens.at(i + 1).toInt();
            first = i;
            last = i + 1;
        }
        else if ((m = episodeOnly.match(t)).hasMatch())
        {
            name.season = season;
            name.episode = m.captured(1).toInt();
            first = last = i;
        }
    }

    // a lone number after the title ("Show - 03"), not a year
    if (first < 0)
    {
        for (qsizetype i = 1; i < tokens.size(); ++i)
        {
            const QString& t = tokens.at(i);
            if (isNumber(t) && t.size() <= 3)
            {
                name.season = season;
                name.episode = t.toInt();
                first = last = i;
                break;
            }
        }
    }

    // "The Wand S01": the season of a name without an episode (a whole season)
    if (first < 0 && name.season < 0)
        name.season = season;

    const QSet<QString>& tags = releaseTags();
    const qsizetype titleEnd = first >= 0 ? first : tokens.size();
    for (qsizetype i = 0; i < titleEnd; ++i)
    {
        const QString& t = tokens.at(i);
        // years and season words stay out of the title
        if (tags.contains(t) || seasonOnly.match(t).hasMatch() || (isNumber(t) && t.size() == 4))
            continue;
        if (t == QLatin1String("season") || (i > 0 && tokens.at(i - 1) == QLatin1String("season")))
            continue;
        name.titleTokens.append(t);
        // lower case changes no word count: the same index in the original words
        if (original.size() == tokens.size())
            name.title += (name.title.isEmpty() ? QString() : QStringLiteral(" ")) + original.at(i);
    }

    // without an episode, the language is at the end ("Movie.English.srt", "movie_en.srt")
    const qsizetype variantStart = last >= 0 ? last + 1 : tokens.size() - 1;
    for (qsizetype i = std::max<qsizetype>(variantStart, 0); i < tokens.size(); ++i)
    {
        const QString& t = tokens.at(i);
        if (tags.contains(t) || (isNumber(t) && first >= 0))
            continue;
        const bool lastToken = i == tokens.size() - 1;
        const QString code = languageCode(t, lastToken);
        if (!code.isEmpty() && name.language.isEmpty())
            name.language = code;
        if (first >= 0 || !code.isEmpty())
            name.variantTokens.append(t);
    }
    // a name without an episode keeps its language word out of the title
    if (first < 0 && !name.language.isEmpty() && !name.titleTokens.isEmpty()
            && languageCode(name.titleTokens.constLast(), true) == name.language)
        name.titleTokens.removeLast();

    return name;
}

int SubtitleMatcher::variantScore(const Name& subtitle, const Preference& preference)
{
    int result = 0;
    for (const QString& word : preference.variantTokens)
        if (subtitle.variantTokens.contains(word))
            result += 50;
    // variants the user did not ask for come after the plain file
    for (const QString& word : subtitle.variantTokens)
        if (variantWords().contains(word) && !preference.variantTokens.contains(word))
            result -= 5;
    return result;
}

int SubtitleMatcher::score(const Name& video, const Name& subtitle, const Preference& preference)
{
    int result = 0;

    if (video.hasEpisode() || subtitle.hasEpisode())
    {
        if (!video.hasEpisode() || !subtitle.hasEpisode() || !sameEpisode(video, subtitle))
            return -1;
        result = 1000;
        // a title in both names that differs completely: another show's episode
        if (!video.titleTokens.isEmpty() && !subtitle.titleTokens.isEmpty())
        {
            const QString v = joined(video.titleTokens);
            const QString s = joined(subtitle.titleTokens);
            const double common = overlap(video.titleTokens, subtitle.titleTokens);
            if (v == s)
                result += 100;
            else if (v.contains(s) || s.contains(v))
                result += 80;
            else if (common > 0.)
                result += int(common * 100.);
            else
                return -1;
        }
    }
    else
    {
        // movies and other names without an episode: the titles must agree
        const QString v = joined(video.titleTokens);
        const QString s = joined(subtitle.titleTokens);
        if (v.isEmpty() || s.isEmpty())
            return -1;
        if (v == s)
            result = 900;
        else if (s.startsWith(v) || v.startsWith(s))
            result = 700;
        else
        {
            const double common = overlap(video.titleTokens, subtitle.titleTokens);
            if (common < 0.6)
                return -1;
            result = 400 + int(common * 100.);
        }
    }

    result += variantScore(subtitle, preference);
    if (!preference.language.isEmpty() && !subtitle.language.isEmpty())
        result += subtitle.language == preference.language ? 40 : -10;

    return std::max(result, 0);
}

int SubtitleMatcher::bestMatch(const Name& video, const QVector<Name>& subtitles, const Preference& preference)
{
    int best = -1;
    int bestScore = -1;
    for (int i = 0; i < subtitles.size(); ++i)
    {
        const int s = score(video, subtitles.at(i), preference);
        if (s < 0)
            continue;
        // equal scores: the shorter name, the plain file before its variants
        if (s > bestScore || (s == bestScore
                              && subtitles.at(i).normalized.size() < subtitles.at(best).normalized.size()))
        {
            best = i;
            bestScore = s;
        }
    }
    return best;
}

namespace {

// "en" and "en", "pt" and "pt-br": the same language; "pt-br" and "pt-pt" or "zh-cn" and "zh-tw":
// not (another spelling or script)
bool sameLanguage(const QString& a, const QString& b)
{
    const QString x = a.toLower();
    const QString y = b.toLower();
    if (x.isEmpty() || y.isEmpty())
        return false;
    if (x == y)
        return true;
    const QString xBase = x.section(QChar('-'), 0, 0);
    const QString yBase = y.section(QChar('-'), 0, 0);
    return xBase == yBase && (xBase == x || yBase == y);
}

} // namespace

QVector<int> SubtitleMatcher::rankResults(const Name& video, const QVector<Name>& results, const QString& language,
                                          const Preference& preference)
{
    QVector<int> inLanguage;
    QVector<int> otherLanguages;
    QVector<int> others;
    for (int i = 0; i < results.size(); ++i)
    {
        if (score(video, results.at(i), preference) < 0)
            others.append(i);
        else if (language.isEmpty() || sameLanguage(results.at(i).language, language))
            inLanguage.append(i);
        else
            otherLanguages.append(i);
    }
    // within a language, the variant kept for the show (a plain file, "forced", "SDH": chosen by
    // hand for an earlier episode) still wins; OpenSubtitles' order decides the rest
    const auto byVariant = [&results, &preference](int a, int b) {
        return variantScore(results.at(a), preference) > variantScore(results.at(b), preference);
    };
    // in the chosen language, a result whose name names another language goes after the others:
    // OpenSubtitles files some uploads under the wrong language (the 1.5.0 retest: "sintel.he",
    // Hebrew text, listed as English)
    const auto namedElsewhere = [&results, &language](int i) {
        const QString& named = results.at(i).nameLanguage;
        return !language.isEmpty() && !named.isEmpty() && !sameLanguage(named, language);
    };
    std::stable_sort(inLanguage.begin(), inLanguage.end(), [&](int a, int b) {
        const bool elsewhereA = namedElsewhere(a);
        const bool elsewhereB = namedElsewhere(b);
        if (elsewhereA != elsewhereB)
            return elsewhereB;
        return byVariant(a, b);
    });
    std::stable_sort(otherLanguages.begin(), otherLanguages.end(), byVariant);
    return inLanguage + otherLanguages + others;
}

namespace {

// the language word among the words after the title: a language name or three letter code
// anywhere ("Movie.2010.heb.720p"), a two letter code only as the last word ("sintel.he", where
// "he" alone would too often be a word)
QString languageAfterTitle(const SubtitleMatcher::Name& name)
{
    const QStringList words = name.normalized.split(QChar(' '), Qt::SkipEmptyParts);
    qsizetype start = 0;
    for (const QString& title : name.titleTokens)
    {
        if (start < words.size() && words.at(start) == title)
            ++start;
        else
            break;
    }
    for (qsizetype i = start; i < words.size(); ++i)
    {
        const QString code = SubtitleMatcher::languageCode(words.at(i), i == words.size() - 1);
        if (!code.isEmpty())
            return code;
    }
    return {};
}

} // namespace

QString SubtitleMatcher::namedLanguage(const QString& fileName, const QString& release)
{
    const QString fromFile = languageAfterTitle(parse(fileName));
    if (!fromFile.isEmpty() || release.trimmed().isEmpty())
        return fromFile;
    // a release name has no extension: parse() would take its last word for one
    return languageAfterTitle(parse(release.trimmed() + QStringLiteral(".srt")));
}

int SubtitleMatcher::bestResult(const Name& video, const QVector<Name>& results, const QString& language,
                                const Preference& preference)
{
    const QVector<int> order = rankResults(video, results, language, preference);
    if (order.isEmpty() || score(video, results.at(order.first()), preference) < 0)
        return -1;
    return order.first();
}

QStringList SubtitleMatcher::variantOf(const Name& video, const Name& subtitle)
{
    const QStringList videoWords = tokenize(video.normalized);
    QStringList words;
    for (const QString& word : subtitle.variantTokens)
    {
        if (videoWords.contains(word))
            continue;
        if (!languageCode(word, true).isEmpty() || variantWords().contains(word))
            words.append(word);
    }
    return words;
}

int SubtitleMatcher::naturalCompare(const QString& a, const QString& b)
{
    // QCollator's numeric mode depends on the platform's collation backend: compare the runs of
    // digits by value here, and the rest without case
    qsizetype i = 0;
    qsizetype j = 0;
    while (i < a.size() && j < b.size())
    {
        if (a.at(i).isDigit() && b.at(j).isDigit())
        {
            qsizetype ei = i;
            qsizetype ej = j;
            while (ei < a.size() && a.at(ei).isDigit())
                ++ei;
            while (ej < b.size() && b.at(ej).isDigit())
                ++ej;
            // without leading zeros, a longer run is a larger number
            QStringView da = QStringView(a).mid(i, ei - i);
            QStringView db = QStringView(b).mid(j, ej - j);
            while (da.size() > 1 && da.front() == QChar('0'))
                da = da.mid(1);
            while (db.size() > 1 && db.front() == QChar('0'))
                db = db.mid(1);
            if (da.size() != db.size())
                return da.size() < db.size() ? -1 : 1;
            const int c = da.compare(db);
            if (c != 0)
                return c;
            i = ei;
            j = ej;
            continue;
        }
        const QChar ca = a.at(i).toLower();
        const QChar cb = b.at(j).toLower();
        if (ca != cb)
            return ca < cb ? -1 : 1;
        ++i;
        ++j;
    }
    if (i < a.size())
        return 1;
    if (j < b.size())
        return -1;
    return QString::compare(a, b, Qt::CaseSensitive);
}

void SubtitleMatcher::naturalSort(QStringList& names)
{
    std::sort(names.begin(), names.end(), [](const QString& a, const QString& b) {
        return naturalCompare(a, b) < 0;
    });
}
