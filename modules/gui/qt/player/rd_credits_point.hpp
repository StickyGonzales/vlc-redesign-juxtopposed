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

#ifndef RD_CREDITS_POINT_HPP
#define RD_CREDITS_POINT_HPP

#include <QString>
#include <QVector>

/**
 * Cone extra (Up Next, UP_NEXT_PLAN.md 5.4): where the credits of an episode start, so the Up
 * Next card can show while they roll.
 *
 * Hard rule: the point always lies inside the credits window, the last 8 minutes of the episode
 * or its last 15 % when that is shorter (episodes under about 53 minutes). Anything pointing
 * earlier is ignored, so the card never shows in the middle of an episode.
 *
 * Inside the window, in this order:
 * 1. a chapter named like the credits ("credits", "end credits", "outro", "ending") that starts
 *    inside the window: exact;
 * 2. the point learned for the show (the user went on to the next episode inside the window of
 *    an earlier one), as a time before the end;
 * 3. the setting "Show Up Next" (the last 30 s, 1 min or 2 min).
 * A text subtitle track can only fine-tune 2 and 3: the end of the last real dialogue line
 * inside the window, before a gap of 60 s or more or before only music lines, moves the point
 * when it is within `kSubtitleTuneMs` of it. Subtitles are never the only reason.
 *
 * QtCore only and pure (the scan of the subtitle lines is rd_credits_subtitles).
 */
namespace rdcredits {

// the credits window: at most the last 8 minutes, or the last 15 % of a shorter episode
constexpr qint64 kWindowMaxMs = 8 * 60 * 1000;
constexpr int kWindowPercent = 15;
// a gap in the dialogue this long ends it
constexpr qint64 kDialogueGapMs = 60 * 1000;
// the farthest the subtitles may move the learned or the set point
constexpr qint64 kSubtitleTuneMs = 2 * 60 * 1000;
// a move to the next episode closer to the end than this is the episode ending, not a choice
constexpr qint64 kNaturalEndMs = 3 * 1000;

// how long the credits window of an episode is
qint64 windowLength(qint64 lengthMs);
// where it starts (0 when the length is unknown)
qint64 windowStart(qint64 lengthMs);
bool inWindow(qint64 timeMs, qint64 lengthMs);

// a chapter name that marks the end credits
bool isCreditsChapterName(const QString& name);

struct Chapter
{
    QString name;
    qint64 startMs = -1;
};

// one subtitle line: the time it shows and its text (formatting tags may be left in)
struct Line
{
    qint64 startMs = 0;
    qint64 endMs = 0;
    QString text;
};

// the text without formatting: ASS override blocks {\...}, HTML-like tags, \N line breaks
QString plainText(const QString& text);
// a line of music only: ♪, ♫ or a line that starts with #
bool isMusicLine(const QString& text);
// a line that credits the subtitles or advertises: "subtitles by", "synced by", a web address
bool isAdLine(const QString& text);

// the end of the dialogue inside the window: the end of the first real dialogue line in it
// followed by a gap of `kDialogueGapMs` or more (to the next dialogue line or the end) or by
// music lines only; -1 when there is none
qint64 dialogueEnd(QVector<Line> lines, qint64 lengthMs);

// subtitle files: SubRip, Advanced SubStation / SubStation, WebVTT
QVector<Line> parseSrt(const QString& text);
QVector<Line> parseAss(const QString& text);
QVector<Line> parseVtt(const QString& text);
// by the file's extension (srt, ass, ssa, vtt); empty for anything else
QVector<Line> parseSubtitleFile(const QString& text, const QString& extension);
// one dialogue packet of an embedded ASS track ("ReadOrder,Layer,Style,Name,MarginL,MarginR,
// MarginV,Effect,Text"): its text
QString assPacketText(const QString& packet);

enum class Source { None, Chapter, Learned, Setting };

struct Point
{
    // from the start of the episode, -1 when there is none
    qint64 timeMs = -1;
    Source source = Source::None;
    // the subtitles moved it
    bool tuned = false;
};

// `learnedLeadMs` and `settingLeadMs`: time before the end, -1 when none; `dialogueEndMs`: from
// dialogueEnd(), -1 when none
Point decide(qint64 lengthMs, const QVector<Chapter>& chapters, qint64 learnedLeadMs,
             qint64 settingLeadMs, qint64 dialogueEndMs);

QString sourceName(Source source);

} // namespace rdcredits

#endif
