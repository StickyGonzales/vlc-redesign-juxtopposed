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

#include <QFile>
#include <QFileInfo>

namespace rdsubtitles {

namespace {

// how many "(n)" names downloadFile() tries before it gives up
constexpr int kMaxNumberedNames = 99;

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

QSet<int> picked(const QSet<int>& selected, int candidate, bool single)
{
    if (single)
        return { candidate };
    QSet<int> result = selected;
    if (result.contains(candidate))
        result.remove(candidate);
    else
        result.insert(candidate);
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

QString withoutExtension(const QString& fileName)
{
    const qsizetype dot = fileName.lastIndexOf(QChar('.'));
    if (dot > 0 && fileName.size() - dot <= 5)
        return fileName.left(dot);
    return fileName;
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
    if (digits == 0 || digits >= fileName.size() - 1 || fileName.at(digits) != QChar('-'))
        return fileName;
    return fileName.mid(digits + 1);
}

} // namespace rdsubtitles
