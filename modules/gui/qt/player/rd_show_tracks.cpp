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

#include "rd_show_tracks.hpp"

#include <QRegularExpression>
#include <QStringList>

namespace rdtracks {

namespace {

struct Language
{
    const char* code3;      // ISO 639-2/T
    const char* code2;      // ISO 639-1
    const char* code3b;     // ISO 639-2/B when it differs
    const char* names;      // English and native names, '|' separated, lower case
};

// the languages of films and shows; a tag outside the table still matches itself
const Language kLanguages[] = {
    { "eng", "en", "",    "english" },
    { "hin", "hi", "",    "hindi|हिन्दी|हिंदी" },
    { "spa", "es", "",    "spanish|español|espanol|castellano|castilian|latino" },
    { "fra", "fr", "fre", "french|français|francais" },
    { "deu", "de", "ger", "german|deutsch" },
    { "ita", "it", "",    "italian|italiano" },
    { "por", "pt", "",    "portuguese|português|portugues|brazilian" },
    { "rus", "ru", "",    "russian|русский" },
    { "jpn", "ja", "",    "japanese|日本語" },
    { "kor", "ko", "",    "korean|한국어" },
    { "zho", "zh", "chi", "chinese|mandarin|中文" },
    { "yue", "",   "",    "cantonese" },
    { "ara", "ar", "",    "arabic|العربية" },
    { "tur", "tr", "",    "turkish|türkçe|turkce" },
    { "nld", "nl", "dut", "dutch|nederlands|flemish" },
    { "swe", "sv", "",    "swedish|svenska" },
    { "nor", "no", "",    "norwegian|norsk" },
    { "nob", "nb", "",    "bokmål|bokmal" },
    { "dan", "da", "",    "danish|dansk" },
    { "fin", "fi", "",    "finnish|suomi" },
    { "pol", "pl", "",    "polish|polski" },
    { "ces", "cs", "cze", "czech|čeština|cestina" },
    { "slk", "sk", "slo", "slovak|slovenčina" },
    { "slv", "sl", "",    "slovenian|slovene|slovenščina" },
    { "hun", "hu", "",    "hungarian|magyar" },
    { "ell", "el", "gre", "greek|ελληνικά" },
    { "heb", "he", "",    "hebrew|עברית" },
    { "tha", "th", "",    "thai|ไทย" },
    { "vie", "vi", "",    "vietnamese|tiếng việt" },
    { "ind", "id", "",    "indonesian|bahasa indonesia" },
    { "msa", "ms", "may", "malay|melayu" },
    { "fil", "",   "",    "filipino|tagalog" },
    { "tam", "ta", "",    "tamil|தமிழ்" },
    { "tel", "te", "",    "telugu|తెలుగు" },
    { "mal", "ml", "",    "malayalam|മലയാളം" },
    { "kan", "kn", "",    "kannada|ಕನ್ನಡ" },
    { "ben", "bn", "",    "bengali|bangla|বাংলা" },
    { "mar", "mr", "",    "marathi|मराठी" },
    { "guj", "gu", "",    "gujarati|ગુજરાતી" },
    { "pan", "pa", "",    "punjabi|ਪੰਜਾਬੀ" },
    { "urd", "ur", "",    "urdu|اردو" },
    { "fas", "fa", "per", "persian|farsi|فارسی" },
    { "ukr", "uk", "",    "ukrainian|українська" },
    { "ron", "ro", "rum", "romanian|română|romana" },
    { "bul", "bg", "",    "bulgarian|български" },
    { "hrv", "hr", "",    "croatian|hrvatski" },
    { "srp", "sr", "",    "serbian|srpski|српски" },
    { "cat", "ca", "",    "catalan|català" },
    { "eus", "eu", "baq", "basque|euskara" },
    { "glg", "gl", "",    "galician|galego" },
    { "isl", "is", "ice", "icelandic|íslenska" },
    { "est", "et", "",    "estonian|eesti" },
    { "lav", "lv", "",    "latvian|latviešu" },
    { "lit", "lt", "",    "lithuanian|lietuvių" },
};

const Language* byCode(const QString& code)
{
    for (const Language& language : kLanguages)
    {
        if (code == QLatin1String(language.code3) || code == QLatin1String(language.code2)
                || (language.code3b[0] && code == QLatin1String(language.code3b)))
            return &language;
    }
    return nullptr;
}

const Language* byName(const QString& name)
{
    for (const Language& language : kLanguages)
    {
        const QStringList names = QString::fromUtf8(language.names).split(QLatin1Char('|'));
        if (names.contains(name))
            return &language;
    }
    return nullptr;
}

// "und", "mul", "zxx", "mis": no single language
bool noLanguage(const QString& code)
{
    return code.isEmpty() || code == QLatin1String("und") || code == QLatin1String("mul")
           || code == QLatin1String("zxx") || code == QLatin1String("mis")
           || code == QLatin1String("unk") || code == QLatin1String("qaa");
}

} // namespace

QString languageKey(const QString& tag)
{
    QString value = tag.trimmed().toLower();
    // "en-US", "pt_BR": the language part
    const qsizetype cut = value.indexOf(QRegularExpression(QStringLiteral("[-_]")));
    if (cut > 0 && cut <= 3)
        value.truncate(cut);
    if (noLanguage(value))
        return {};
    if (const Language* language = byCode(value))
        return QString::fromLatin1(language->code3);
    if (const Language* language = byName(value))
        return QString::fromLatin1(language->code3);
    return value;
}

QString languageInTitle(const QString& title)
{
    // whole words of letters (any script); names have four letters or more, so a short code in
    // a title ("tw" of a web address) is never taken for a language
    static const QRegularExpression word(QStringLiteral("[\\p{L}\\p{M}]+"));
    auto it = word.globalMatch(title.toLower());
    while (it.hasNext())
    {
        const QString candidate = it.next().captured();
        if (candidate.size() < 4)
            continue;
        if (const Language* language = byName(candidate))
            return QString::fromLatin1(language->code3);
    }
    return {};
}

QString trackLanguage(const QString& tag, const QString& title)
{
    const QString fromTag = languageKey(tag);
    return fromTag.isEmpty() ? languageInTitle(title) : fromTag;
}

int matchTrack(const QVector<Track>& tracks, const QString& key)
{
    if (key.isEmpty())
        return -1;
    for (qsizetype i = 0; i < tracks.size(); ++i)
    {
        if (trackLanguage(tracks.at(i).tag, tracks.at(i).title) == key)
            return int(i);
    }
    return -1;
}

} // namespace rdtracks
