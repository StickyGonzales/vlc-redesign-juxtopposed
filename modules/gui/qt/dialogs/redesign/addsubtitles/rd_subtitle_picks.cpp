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

#include "rd_subtitle_picks.hpp"
#include "subtitle_matcher.hpp"

#include <QFile>
#include <QFileInfo>
#include <QMutex>
#include <QMutexLocker>
#include <QRegularExpression>

#include <tuple>

namespace rdsubtitles {

namespace {

// how many "(n)" names downloadFile() tries before it gives up
constexpr int kMaxNumberedNames = 99;

// the OpenSubtitles file ids Cone put in front of its downloads before 1.5.0 have this many digits
// or more (a name such as "24-S01E01.eng.srt" keeps its number)
constexpr qsizetype kMinDownloadIdDigits = 4;

// saveDownload() for every download worker at once
QMutex downloadMutex;

bool isSeparator(QChar c)
{
    return c == QChar(' ') || c == QChar('.') || c == QChar('_') || c == QChar('-');
}

bool holds(const QString& path, const QByteArray& data)
{
    QFile file(path);
    if (file.size() != data.size() || !file.open(QIODevice::ReadOnly))
        return false;
    return file.readAll() == data;
}

} // namespace

QSet<int> picked(const QSet<int>& selected, int candidate)
{
    QSet<int> result = selected;
    if (result.contains(candidate))
        result.remove(candidate);
    else
        result.insert(candidate);
    return result;
}

QVector<int> checkedInOrder(const QVector<int>& order, const QSet<int>& selected)
{
    QVector<int> result;
    for (const int candidate : order)
        if (selected.contains(candidate))
            result.append(candidate);
    return result;
}

QString downloadFile(const QString& folder, const QString& name, const QByteArray& data)
{
    if (folder.isEmpty() || name.isEmpty())
        return {};
    const QString first = folder + QChar('/') + name;
    if (!QFileInfo::exists(first) || holds(first, data))
        return first;

    const QString base = withoutExtension(name);
    const QString extension = name.mid(base.size());
    for (int number = 2; number <= kMaxNumberedNames; ++number)
    {
        const QString path = folder + QChar('/') + base + QStringLiteral(" (%1)").arg(number) + extension;
        if (!QFileInfo::exists(path) || holds(path, data))
            return path;
    }
    return {};
}

QString saveDownload(const QString& folder, const QString& name, const QByteArray& data)
{
    QMutexLocker locker(&downloadMutex);
    const QString path = downloadFile(folder, name, data);
    if (path.isEmpty())
        return {};
    if (QFileInfo::exists(path))
        return path; // downloadFile() only returns an existing file that holds the same bytes
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate) || file.write(data) != data.size())
    {
        file.remove();
        return {};
    }
    return path;
}

QString withoutExtension(const QString& fileName)
{
    return SubtitleMatcher::withoutExtension(fileName);
}

QString withoutCopyNumber(const QString& text, QString* number)
{
    // " (2)" .. " (99)" at the end, as downloadFile() numbers a second subtitle of the same name;
    // a year ("Sintel (2010)") has more digits and stays
    static const QRegularExpression copy(QStringLiteral("^(.*\\S)\\s+\\((\\d{1,2})\\)$"));
    const QRegularExpressionMatch match = copy.match(text);
    if (!match.hasMatch())
        return text;
    if (number)
        *number = match.captured(2);
    return match.captured(1);
}

QString withoutLastWord(const QString& base, qsizetype wordStart, const QString& fallback)
{
    QString result = base.left(wordStart);
    while (!result.isEmpty() && isSeparator(result.back()))
        result.chop(1);
    return result.isEmpty() ? fallback : result;
}

QString withoutDownloadId(const QString& fileName)
{
    qsizetype digits = 0;
    while (digits < fileName.size() && fileName.at(digits).isDigit() && fileName.at(digits).unicode() < 128)
        ++digits;
    if (digits < kMinDownloadIdDigits || digits >= fileName.size() - 1 || fileName.at(digits) != QChar('-'))
        return fileName;
    return fileName.mid(digits + 1);
}

QString externalTrackName(const QString& fileName, const QString& trackLanguage,
                          const LanguageLookup& languageOf)
{
    // a numbered copy ("sintel_en (2).srt") shows its number once, after the title and outside the
    // language: "sintel (2) [English]". VLC reads the language from the file name and keeps the
    // number with it ("en (2)"), which is no language: the number goes there too
    QString copy;
    QString base = withoutCopyNumber(withoutExtension(fileName), &copy);
    const QString cleanLanguage = withoutCopyNumber(trackLanguage.trimmed(), nullptr);
    const QString number = copy.isEmpty() ? QString() : QStringLiteral(" (%1)").arg(copy);

    qsizetype wordStart = base.size();
    while (wordStart > 0 && base.at(wordStart - 1).isLetterOrNumber())
        --wordStart;
    const QString nameCode = wordStart > 0
            ? SubtitleMatcher::languageCode(base.mid(wordStart), true) : QString();

    QString language;
    QString code;
    // a language the lookup knows comes back with a code or as a name other than the text given
    // (a language without a two letter code); an unknown one comes back as it was
    const auto lookUp = [&languageOf](const QString& text, QString& name, QString& twoLetters) {
        std::tie(name, twoLetters) = languageOf(text);
        return !name.isEmpty() && (!twoLetters.isEmpty() || name.compare(text, Qt::CaseInsensitive) != 0);
    };
    bool known = !cleanLanguage.isEmpty() && lookUp(cleanLanguage, language, code);
    // VLC's language is not one it knows ("en (2)" before the number went): the file name's word
    if (!known && !nameCode.isEmpty())
        known = lookUp(nameCode, language, code);

    if (!known)
        return base + number;
    // only the separators before the language word go: "Sintel (2010).eng" keeps its ")"
    if (!nameCode.isEmpty() && nameCode == code)
        base = withoutLastWord(base, wordStart, fileName);
    return QStringLiteral("%1%2 [%3]").arg(base, number, language);
}

} // namespace rdsubtitles
