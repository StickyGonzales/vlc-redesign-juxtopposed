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
 * Inside the window, the order of decide() below (UP_NEXT_CREDITS_SCAN_NOTES.md): the show's
 * Fixed point, a credits chapter, the credits music matched across episodes, then the end of the
 * dialogue, black frames and the learned point together, then the setting "Show Up Next".
 *
 * QtCore only and pure (the scan of the subtitle lines is rd_credits_subtitles).
 */
namespace rdcredits {

// the credits window: at most the last 8 minutes, or the last 15 % of a shorter episode
constexpr qint64 kWindowMaxMs = 8 * 60 * 1000;
constexpr int kWindowPercent = 15;
// a gap in the dialogue this long ends it
constexpr qint64 kDialogueGapMs = 60 * 1000;
// a move to the next episode closer to the end than this (past the countdown) is the episode
// ending, not a choice
constexpr qint64 kNaturalEndMs = 3 * 1000;
// the subtitle scan starts this long before the credits window
constexpr qint64 kScanLeadMs = 2 * 60 * 1000;

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

// redesign (Cone extra, UP_NEXT_CREDITS_SCAN_NOTES.md): where the credits start, from what is
// known, in this order (the first that has a point inside the window wins):
//   1. the show's Fixed point (Playback tab, "Up Next for <show>")
//   2. a credits chapter
//   3. the credits music matched across episodes (audio fingerprint, full scan or quick check)
//   4. the end of the dialogue (subtitles), black frames and the learned point: where at least
//      two of them agree within kAgreeMs (the most precise of them: subtitles, then black
//      frames, then the learned point); else the learned point; else the subtitles alone;
//      black frames are never used alone (a dark scene would fool them)
//   5. the global setting ("Show the card": the last 30 / 60 / 120 s)
enum class Source { None, Fixed, Chapter, Audio, Agreement, Learned, Subtitles, Setting };

struct Point
{
    // from the start of the episode, -1 when there is none
    qint64 timeMs = -1;
    Source source = Source::None;
};

// two points this close agree
constexpr qint64 kAgreeMs = 90 * 1000;

struct Inputs
{
    QVector<Chapter> chapters;
    // times before the end, -1 when none
    qint64 fixedLeadMs = -1;
    qint64 learnedLeadMs = -1;
    qint64 settingLeadMs = -1;
    // times from the start of the episode, -1 when none
    qint64 audioMs = -1;
    qint64 dialogueEndMs = -1;
    qint64 blackMs = -1;
};

Point decide(qint64 lengthMs, const Inputs& inputs);

// --- learning from the user (the drift fix, UP_NEXT_CREDITS_SCAN_NOTES.md section 1) ---

// the user (or the queue) moved on to the next episode of the show at `timeMs` of `lengthMs`
struct Move
{
    qint64 timeMs = -1;
    qint64 lengthMs = -1;
    // the card's own "Next episode" button (or its picture) did it
    bool fromCard = false;
    // the card was showing in this episode before the move
    bool cardShown = false;
    // Cancel was pressed on the card in this episode
    bool cancelled = false;
    // the countdown's length (seconds): a move inside it is the episode ending, not a choice
    int countdownSec = 0;
    // the point saved for the show, as time before the end, -1 when none
    qint64 savedLeadMs = -1;
};

// the new learned point (time before the end) for a move, -1 to keep the saved one:
// - only inside the credits window and before the countdown (natural endings are never learned)
// - a click on the card is never learned (it can only come once the card shows: learning it
//   made the point drift later every episode)
// - a move before the card showed moves the point earlier, never later
// - Cancel on the card, then a move later in the episode, moves the point later, to that move
qint64 learnedLead(const Move& move);

// --- the scans (UP_NEXT_CREDITS_SCAN_NOTES.md sections 3 to 6) ---

// a show folder needs this many video files to be scanned
constexpr int kMinShowVideos = 3;
// the full scan reads the end of the episode: the credits window (the last 8 minutes)
// the quick check reads 1 minute either side of where the show's credits music is expected
constexpr qint64 kQuickHalfMs = 60 * 1000;
// an episode whose length is this far from the show's usual one is a finale or a special: the
// quick check is skipped
constexpr qint64 kUsualLengthSlackMs = 5 * 60 * 1000;

// a local video file Cone scans: by its extension (never audio files, streams or images)
bool isScannableVideo(const QString& fileName);

enum class ScanKind { Quick, Full };
// the scan an episode of `lengthMs` gets: the quick check when the show has its credits music
// and the episode's length is within kUsualLengthSlackMs of the show's usual length
ScanKind planScan(bool showHasMusic, qint64 usualLengthMs, qint64 lengthMs);

// one sampled video frame: how much of it is dark (0 to 1)
struct FrameSample
{
    qint64 timeMs = 0;
    float darkShare = 0;
};
// a frame this dark is black (white credits text on black stays above it)
constexpr float kBlackFrameShare = 0.85f;
// black frames: the start of the first stretch of kBlackRunMs or more (or to the last sample,
// at least kBlackMinMs) where kBlackRunShare of the samples are black; -1 when none
constexpr qint64 kBlackRunMs = 30 * 1000;
constexpr qint64 kBlackMinMs = 15 * 1000;
constexpr double kBlackRunShare = 0.9;
qint64 blackStart(const QVector<FrameSample>& samples);

QString sourceName(Source source);

} // namespace rdcredits

#endif
