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

#include "rd_credits_point.hpp"

#include <QRegularExpression>
#include <QStringList>

#include <algorithm>
#include <cstdlib>

namespace rdcredits {

qint64 windowLength(qint64 lengthMs)
{
    if (lengthMs <= 0)
        return 0;
    return std::min(kWindowMaxMs, lengthMs * kWindowPercent / 100);
}

qint64 windowStart(qint64 lengthMs)
{
    return lengthMs <= 0 ? 0 : lengthMs - windowLength(lengthMs);
}

bool inWindow(qint64 timeMs, qint64 lengthMs)
{
    return lengthMs > 0 && timeMs >= windowStart(lengthMs) && timeMs < lengthMs;
}

bool isCreditsChapterName(const QString& name)
{
    // "Credits", "End Credits", "Closing credits", "Outro", "Ending", "ending theme"
    static const QRegularExpression credits(QStringLiteral("\\b(?:credits|outro|ending)\\b"),
                                            QRegularExpression::CaseInsensitiveOption);
    return credits.match(name).hasMatch();
}

QString plainText(const QString& text)
{
    static const QRegularExpression assBlock(QStringLiteral("\\{[^}]*\\}"));
    static const QRegularExpression tag(QStringLiteral("<[^>]*>"));
    QString plain = text;
    plain.remove(assBlock);
    plain.remove(tag);
    plain.replace(QLatin1String("\\N"), QLatin1String(" "));
    plain.replace(QLatin1String("\\n"), QLatin1String(" "));
    plain.replace(QLatin1String("\\h"), QLatin1String(" "));
    return plain.simplified();
}

bool isMusicLine(const QString& text)
{
    const QString plain = plainText(text);
    return plain.contains(QChar(0x266A)) || plain.contains(QChar(0x266B)) || plain.startsWith(QLatin1Char('#'));
}

bool isAdLine(const QString& text)
{
    static const QRegularExpression ad(
        QStringLiteral("subtitles?\\s+(?:by|from)|subbed\\s+by|synced?\\s+(?:and\\s+corrected\\s+)?by|"
                       "sync\\s+by|corrected\\s+by|translated\\s+by|translation\\s+by|"
                       "captions?\\s+by|captioning\\s+by|downloaded\\s+from|ripped\\s+by|encoded\\s+by|"
                       "opensubtitles|addic7ed|subscene|podnapisi|yify|"
                       "https?://|www\\.|\\b[a-z0-9-]+\\.(?:com|org|net|tv|io|info)\\b"),
        QRegularExpression::CaseInsensitiveOption);
    return ad.match(plainText(text)).hasMatch();
}

qint64 dialogueEnd(QVector<Line> lines, qint64 lengthMs)
{
    if (lengthMs <= 0)
        return -1;
    std::stable_sort(lines.begin(), lines.end(), [](const Line& a, const Line& b) {
        return a.startMs < b.startMs;
    });

    struct Kind
    {
        Line line;
        bool music;
    };
    QVector<Kind> kept;
    for (const Line& line : lines)
    {
        if (plainText(line.text).isEmpty() || isAdLine(line.text))
            continue;
        kept.append({ line, isMusicLine(line.text) });
    }

    const qint64 start = windowStart(lengthMs);
    for (int i = 0; i < kept.size(); ++i)
    {
        if (kept[i].music)
            continue;
        const qint64 end = std::max(kept[i].line.startMs, kept[i].line.endMs);
        if (end < start || end >= lengthMs)
            continue;
        // what follows it: the next dialogue line (or the end of the episode), music between
        qint64 next = lengthMs;
        bool musicAfter = false;
        for (int j = i + 1; j < kept.size(); ++j)
        {
            if (kept[j].music)
            {
                musicAfter = true;
                continue;
            }
            next = kept[j].line.startMs;
            break;
        }
        const bool lastDialogue = next == lengthMs;
        if (next - end >= kDialogueGapMs || (lastDialogue && musicAfter))
            return end;
    }
    return -1;
}

namespace {

qint64 toMs(const QString& h, const QString& m, const QString& s, const QString& frac)
{
    QString f = frac.left(3);
    while (f.size() < 3)
        f.append(QLatin1Char('0'));
    return ((h.isEmpty() ? 0 : h.toLongLong()) * 3600 + m.toLongLong() * 60 + s.toLongLong()) * 1000
           + f.toLongLong();
}

QStringList textLines(const QString& text)
{
    QString t = text;
    t.replace(QLatin1String("\r\n"), QLatin1String("\n"));
    t.replace(QLatin1Char('\r'), QLatin1Char('\n'));
    return t.split(QLatin1Char('\n'));
}

// the cue blocks of SubRip and WebVTT: a timing line, then the text up to a blank line
QVector<Line> parseCues(const QString& text, const QRegularExpression& timing)
{
    QVector<Line> lines;
    const QStringList rows = textLines(text);
    for (int i = 0; i < rows.size(); ++i)
    {
        const QRegularExpressionMatch m = timing.match(rows[i]);
        if (!m.hasMatch())
            continue;
        Line line;
        line.startMs = toMs(m.captured(1), m.captured(2), m.captured(3), m.captured(4));
        line.endMs = toMs(m.captured(5), m.captured(6), m.captured(7), m.captured(8));
        QStringList body;
        for (++i; i < rows.size() && !rows[i].trimmed().isEmpty(); ++i)
            body.append(rows[i].trimmed());
        line.text = body.join(QLatin1Char(' '));
        lines.append(line);
    }
    return lines;
}

} // namespace

QVector<Line> parseSrt(const QString& text)
{
    static const QRegularExpression timing(QStringLiteral(
        "^\\s*(\\d+):(\\d{1,2}):(\\d{1,2})[,.](\\d{1,3})\\s*-->\\s*(\\d+):(\\d{1,2}):(\\d{1,2})[,.](\\d{1,3})"));
    return parseCues(text, timing);
}

QVector<Line> parseVtt(const QString& text)
{
    static const QRegularExpression timing(QStringLiteral(
        "^\\s*(?:(\\d+):)?(\\d{2}):(\\d{2})\\.(\\d{3})\\s*-->\\s*(?:(\\d+):)?(\\d{2}):(\\d{2})\\.(\\d{3})"));
    return parseCues(text, timing);
}

QVector<Line> parseAss(const QString& text)
{
    QVector<Line> lines;
    // the [Events] Format line names the fields; the usual order when it is missing
    QStringList format = { QStringLiteral("layer"), QStringLiteral("start"), QStringLiteral("end"),
                           QStringLiteral("style"), QStringLiteral("name"), QStringLiteral("marginl"),
                           QStringLiteral("marginr"), QStringLiteral("marginv"), QStringLiteral("effect"),
                           QStringLiteral("text") };
    bool inEvents = false;
    static const QRegularExpression time(QStringLiteral("^\\s*(\\d+):(\\d{1,2}):(\\d{1,2})[.,](\\d{1,3})\\s*$"));
    for (const QString& row : textLines(text))
    {
        const QString trimmed = row.trimmed();
        if (trimmed.startsWith(QLatin1Char('[')))
        {
            inEvents = trimmed.compare(QLatin1String("[Events]"), Qt::CaseInsensitive) == 0;
            continue;
        }
        if (!inEvents)
            continue;
        if (trimmed.startsWith(QLatin1String("Format:"), Qt::CaseInsensitive))
        {
            format.clear();
            for (const QString& field : trimmed.mid(7).split(QLatin1Char(',')))
                format.append(field.trimmed().toLower());
            continue;
        }
        if (!trimmed.startsWith(QLatin1String("Dialogue:"), Qt::CaseInsensitive))
            continue;
        // the text is the last field and may hold commas
        const QStringList fields = trimmed.mid(9).split(QLatin1Char(','));
        if (fields.size() < format.size())
            continue;
        const int startIndex = format.indexOf(QStringLiteral("start"));
        const int endIndex = format.indexOf(QStringLiteral("end"));
        if (startIndex < 0 || endIndex < 0)
            continue;
        const QRegularExpressionMatch s = time.match(fields[startIndex]);
        const QRegularExpressionMatch e = time.match(fields[endIndex]);
        if (!s.hasMatch() || !e.hasMatch())
            continue;
        Line line;
        // ASS times are in hundredths: "0:01:02.50" is 62.5 s
        line.startMs = toMs(s.captured(1), s.captured(2), s.captured(3), s.captured(4).leftJustified(2, QLatin1Char('0')));
        line.endMs = toMs(e.captured(1), e.captured(2), e.captured(3), e.captured(4).leftJustified(2, QLatin1Char('0')));
        line.text = fields.mid(format.size() - 1).join(QLatin1Char(','));
        lines.append(line);
    }
    return lines;
}

QVector<Line> parseSubtitleFile(const QString& text, const QString& extension)
{
    const QString ext = extension.toLower();
    if (ext == QLatin1String("srt"))
        return parseSrt(text);
    if (ext == QLatin1String("ass") || ext == QLatin1String("ssa"))
        return parseAss(text);
    if (ext == QLatin1String("vtt"))
        return parseVtt(text);
    return {};
}

QString assPacketText(const QString& packet)
{
    // ReadOrder, Layer, Style, Name, MarginL, MarginR, MarginV, Effect, Text
    int commas = 0;
    for (int i = 0; i < packet.size(); ++i)
    {
        if (packet[i] == QLatin1Char(',') && ++commas == 8)
            return packet.mid(i + 1);
    }
    return packet;
}

Point decide(qint64 lengthMs, const QVector<Chapter>& chapters, qint64 learnedLeadMs,
             qint64 settingLeadMs, qint64 dialogueEndMs)
{
    Point point;
    if (lengthMs <= 0)
        return point;
    const qint64 start = windowStart(lengthMs);
    const qint64 window = windowLength(lengthMs);

    // 1. a credits chapter that starts inside the window: exact
    qint64 chapterStart = -1;
    for (const Chapter& chapter : chapters)
    {
        if (chapter.startMs >= start && chapter.startMs < lengthMs && isCreditsChapterName(chapter.name)
                && (chapterStart < 0 || chapter.startMs < chapterStart))
            chapterStart = chapter.startMs;
    }
    if (chapterStart >= 0)
    {
        point.timeMs = chapterStart;
        point.source = Source::Chapter;
        return point;
    }

    // 2. the point learned for the show, when it falls inside this episode's window; 3. the
    // setting, held inside the window
    if (learnedLeadMs > 0 && learnedLeadMs <= window)
    {
        point.timeMs = lengthMs - learnedLeadMs;
        point.source = Source::Learned;
    }
    else if (settingLeadMs > 0)
    {
        point.timeMs = lengthMs - std::min(settingLeadMs, window);
        point.source = Source::Setting;
    }
    else
    {
        return point;
    }

    // the subtitles fine-tune it, never more than kSubtitleTuneMs and never out of the window
    if (dialogueEndMs >= start && dialogueEndMs < lengthMs
            && std::llabs(dialogueEndMs - point.timeMs) <= kSubtitleTuneMs)
    {
        point.tuned = dialogueEndMs != point.timeMs;
        point.timeMs = dialogueEndMs;
    }
    return point;
}

QString sourceName(Source source)
{
    switch (source)
    {
    case Source::Chapter:
        return QStringLiteral("chapter");
    case Source::Learned:
        return QStringLiteral("learned");
    case Source::Setting:
        return QStringLiteral("setting");
    case Source::None:
        break;
    }
    return QStringLiteral("none");
}

} // namespace rdcredits
