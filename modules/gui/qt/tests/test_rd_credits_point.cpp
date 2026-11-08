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

// Cone extra (Up Next, UP_NEXT_PLAN.md 5.4): where the credits start. QtCore only.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "player/rd_credits_point.hpp"

#include <cstdio>

using namespace rdcredits;

namespace {

int checks = 0;
int failures = 0;

void check(bool ok, const char* what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s\n", what);
    }
}

void checkEqual(qint64 actual, qint64 expected, const char* what)
{
    ++checks;
    if (actual != expected)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s: got %lld, expected %lld\n", what,
                     static_cast<long long>(actual), static_cast<long long>(expected));
    }
}

constexpr qint64 S = 1000;
constexpr qint64 M = 60 * S;

Line line(qint64 start, qint64 end, const char* text)
{
    return Line{ start, end, QString::fromUtf8(text) };
}

void testWindow()
{
    // 56 min: the last 8 minutes; 40 min: the last 15 % (6 min); 53 min 20 s: both 8 min
    checkEqual(windowLength(56 * M), 8 * M, "window of 56 min");
    checkEqual(windowLength(40 * M), 6 * M, "window of 40 min");
    checkEqual(windowLength(160 * M / 3), 8 * M, "window of 53 min 20 s");
    checkEqual(windowLength(10 * M), 90 * S, "window of 10 min");
    checkEqual(windowStart(56 * M), 48 * M, "window start of 56 min");
    checkEqual(windowLength(0), 0, "no length, no window");
    check(!inWindow(47 * M, 56 * M), "47 min of 56 is not in the window");
    check(inWindow(48 * M, 56 * M), "48 min of 56 is in the window");
    check(!inWindow(56 * M, 56 * M), "the end itself is not");
}

void testChapterNames()
{
    check(isCreditsChapterName(QStringLiteral("Credits")), "Credits");
    check(isCreditsChapterName(QStringLiteral("End Credits")), "End Credits");
    check(isCreditsChapterName(QStringLiteral("end credits")), "end credits");
    check(isCreditsChapterName(QStringLiteral("Outro")), "Outro");
    check(isCreditsChapterName(QStringLiteral("ENDING")), "ENDING");
    check(isCreditsChapterName(QStringLiteral("Chapter 6 - Ending Theme")), "Ending Theme");
    check(!isCreditsChapterName(QStringLiteral("Pending")), "Pending is no ending");
    check(!isCreditsChapterName(QStringLiteral("Chapter 5")), "Chapter 5");
    check(!isCreditsChapterName(QStringLiteral("Intro")), "Intro");
    check(isCreditsChapterName(QStringLiteral("ED")), "ED (anime)");
    check(!isCreditsChapterName(QStringLiteral("Edge")), "Edge is no ED");
    check(!isCreditsChapterName(QStringLiteral("Pre-Credits Scene")), "a pre-credits scene is a story scene");
    check(!isCreditsChapterName(QStringLiteral("Mid-credits")), "mid-credits");
    check(!isCreditsChapterName(QStringLiteral("Post Credits")), "post credits");
}

void testDecideChapter()
{
    const qint64 L = 56 * M;
    // a credits chapter in the window: exact, whatever else is known
    Point p = decide(L, { { QStringLiteral("Chapter 1"), 0 }, { QStringLiteral("End Credits"), 54 * M } },
                     3 * M, 60 * S, 52 * M);
    checkEqual(p.timeMs, 54 * M, "credits chapter point");
    check(p.source == Source::Chapter, "credits chapter source");
    check(!p.tuned, "a chapter is not tuned");

    // "Ending" in the middle of the episode: ignored, the setting decides
    p = decide(L, { { QStringLiteral("Ending"), 20 * M } }, -1, 60 * S, -1);
    checkEqual(p.timeMs, 55 * M, "a mid-episode Ending chapter is ignored");
    check(p.source == Source::Setting, "setting after an ignored chapter");

    // a credits chapter just before the window: ignored as well
    p = decide(L, { { QStringLiteral("Credits"), 47 * M } }, -1, 60 * S, -1);
    checkEqual(p.timeMs, 55 * M, "a credits chapter before the window is ignored");
}

void testDecideLearned()
{
    const qint64 L = 56 * M;
    Point p = decide(L, {}, 2 * M, 60 * S, -1);
    checkEqual(p.timeMs, 54 * M, "learned 2 min before the end");
    check(p.source == Source::Learned, "learned source");

    // learned on a longer episode, outside this one's window (10 min, window 90 s): ignored
    p = decide(10 * M, {}, 2 * M, 60 * S, -1);
    checkEqual(p.timeMs, 9 * M, "a learned lead past the window falls back to the setting");
    check(p.source == Source::Setting, "setting source");
}

void testDecideSetting()
{
    checkEqual(decide(56 * M, {}, -1, 30 * S, -1).timeMs, 56 * M - 30 * S, "last 30 s");
    checkEqual(decide(56 * M, {}, -1, 2 * M, -1).timeMs, 54 * M, "last 2 min");
    // a short episode: the setting is held inside the window (10 min: 90 s)
    checkEqual(decide(10 * M, {}, -1, 2 * M, -1).timeMs, 10 * M - 90 * S, "2 min held in a 90 s window");
    check(decide(0, {}, -1, 60 * S, -1).source == Source::None, "no length, no point");
}

void testDecideTune()
{
    const qint64 L = 56 * M;
    // the dialogue ends 2 min before the end: the 1 min setting moves there
    Point p = decide(L, {}, -1, 60 * S, 54 * M);
    checkEqual(p.timeMs, 54 * M, "tuned to the end of the dialogue");
    check(p.tuned && p.source == Source::Setting, "tuned setting");
    // too far from the point (5 min): not used
    p = decide(L, {}, -1, 60 * S, 50 * M);
    checkEqual(p.timeMs, 55 * M, "a dialogue end far from the point is not used");
    check(!p.tuned, "not tuned");
    // before the window: never
    p = decide(L, {}, -1, 8 * M, 47 * M);
    checkEqual(p.timeMs, 48 * M, "a dialogue end before the window is not used");
    // subtitles alone are never a reason: no learned point, no setting
    check(decide(L, {}, -1, -1, 54 * M).source == Source::None, "subtitles alone give no point");
}

void testSubtitleLines()
{
    check(isMusicLine(QStringLiteral("♪ la la la ♪")), "music note line");
    check(isMusicLine(QStringLiteral("{\\i1}♫{\\i0}")), "ASS music line");
    check(isMusicLine(QStringLiteral("# Here comes the sun #")), "hash music line");
    check(!isMusicLine(QStringLiteral("Number #1 fan")), "a hash inside dialogue");
    check(isAdLine(QStringLiteral("Subtitles by Someone")), "subtitles by");
    check(isAdLine(QStringLiteral("Synced and corrected by xyz")), "synced and corrected by");
    check(isAdLine(QStringLiteral("Downloaded from www.example.org")), "downloaded from");
    check(isAdLine(QStringLiteral("<font color=\"#ff0\">OpenSubtitles.com</font>")), "web address");
    check(!isAdLine(QStringLiteral("I'll call you tomorrow.")), "dialogue is no ad");
    check(plainText(QStringLiteral("{\\an8}Hello\\Nthere <i>you</i>")) == QStringLiteral("Hello there you"), "plain text");
}

void testDialogueEnd()
{
    const qint64 L = 10 * M; // window 90 s: from 8:30
    // dialogue up to 8:40, then music and an ad line in the credits, then nothing
    QVector<Line> lines = {
        line(8 * M + 35 * S, 8 * M + 40 * S, "We should go."),
        line(8 * M + 45 * S, 8 * M + 50 * S, "\xE2\x99\xAA Theme song \xE2\x99\xAA"),
        line(9 * M + 50 * S, 9 * M + 55 * S, "Subtitles by Someone"),
    };
    checkEqual(dialogueEnd(lines, L), 8 * M + 40 * S, "dialogue ends before music and an ad line");

    // a post-credits scene: dialogue, a 70 s gap, dialogue again near the end
    lines = {
        line(8 * M + 31 * S, 8 * M + 34 * S, "Goodbye."),
        line(9 * M + 44 * S, 9 * M + 47 * S, "Wait, what was that?"),
    };
    checkEqual(dialogueEnd(lines, L), 8 * M + 34 * S, "the gap before a post-credits scene");

    // dialogue right to the end, short gaps: no end of dialogue
    lines = {
        line(8 * M + 40 * S, 8 * M + 45 * S, "One."),
        line(9 * M + 0 * S, 9 * M + 5 * S, "Two."),
        line(9 * M + 50 * S, 9 * M + 55 * S, "Three."),
    };
    checkEqual(dialogueEnd(lines, L), -1, "dialogue to the end");

    // the last line 30 s before the end, nothing after: a gap of 30 s only, no music: none
    lines = { line(9 * M + 25 * S, 9 * M + 30 * S, "Last words.") };
    checkEqual(dialogueEnd(lines, L), -1, "a short silence at the end");

    // lines before the window do not count
    lines = { line(5 * M, 5 * M + 3 * S, "Early."), line(7 * M, 7 * M + 3 * S, "Still early.") };
    checkEqual(dialogueEnd(lines, L), -1, "nothing in the window");
}

void testParsers()
{
    const QString srt = QStringLiteral(
        "1\r\n00:08:35,000 --> 00:08:40,500\r\nWe should go.\r\n\r\n"
        "2\r\n00:08:45,000 --> 00:08:50,000\r\n<i>♪ Theme ♪</i>\r\n\r\n");
    const QVector<Line> s = parseSrt(srt);
    checkEqual(s.size(), 2, "srt lines");
    if (s.size() == 2)
    {
        checkEqual(s[0].startMs, 8 * M + 35 * S, "srt start");
        checkEqual(s[0].endMs, 8 * M + 40 * S + 500, "srt end");
        check(isMusicLine(s[1].text), "srt music line");
    }

    const QString ass = QStringLiteral(
        "[Script Info]\nTitle: x\n\n[Events]\n"
        "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
        "Dialogue: 0,0:08:35.00,0:08:40.50,Default,,0,0,0,,We should go, now.\n");
    const QVector<Line> a = parseAss(ass);
    checkEqual(a.size(), 1, "ass lines");
    if (a.size() == 1)
    {
        checkEqual(a[0].endMs, 8 * M + 40 * S + 500, "ass end in hundredths");
        check(a[0].text == QStringLiteral("We should go, now."), "ass text keeps its commas");
    }

    const QString vtt = QStringLiteral("WEBVTT\n\n08:35.000 --> 08:40.000\nHi.\n");
    checkEqual(parseVtt(vtt).size(), 1, "vtt lines");
    checkEqual(parseSubtitleFile(srt, QStringLiteral("SRT")).size(), 2, "by extension");
    checkEqual(parseSubtitleFile(srt, QStringLiteral("sub")).size(), 0, "MicroDVD is not read");

    check(assPacketText(QStringLiteral("3,0,Default,,0,0,0,,Hi, you.")) == QStringLiteral("Hi, you."),
          "embedded ASS packet text");
}

} // namespace

int main()
{
    testWindow();
    testChapterNames();
    testDecideChapter();
    testDecideLearned();
    testDecideSetting();
    testDecideTune();
    testSubtitleLines();
    testDialogueEnd();
    testParsers();
    std::printf("rd_credits_point: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
