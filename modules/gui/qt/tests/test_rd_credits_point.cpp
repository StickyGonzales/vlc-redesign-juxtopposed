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

Inputs inputs(qint64 learned, qint64 setting, qint64 dialogue)
{
    Inputs in;
    in.learnedLeadMs = learned;
    in.settingLeadMs = setting;
    in.dialogueEndMs = dialogue;
    return in;
}

void testDecideChapter()
{
    const qint64 L = 56 * M;
    // a credits chapter in the window wins over the audio match, subtitles, learned and setting
    Inputs in = inputs(3 * M, 60 * S, 52 * M);
    in.chapters = { { QStringLiteral("Chapter 1"), 0 }, { QStringLiteral("End Credits"), 54 * M } };
    in.audioMs = 53 * M;
    Point p = decide(L, in);
    checkEqual(p.timeMs, 54 * M, "credits chapter point");
    check(p.source == Source::Chapter, "credits chapter source");

    // "Ending" in the middle of the episode: ignored, the setting decides
    in = inputs(-1, 60 * S, -1);
    in.chapters = { { QStringLiteral("Ending"), 20 * M } };
    p = decide(L, in);
    checkEqual(p.timeMs, 55 * M, "a mid-episode Ending chapter is ignored");
    check(p.source == Source::Setting, "setting after an ignored chapter");

    // a credits chapter just before the window: ignored as well
    in.chapters = { { QStringLiteral("Credits"), 47 * M } };
    checkEqual(decide(L, in).timeMs, 55 * M, "a credits chapter before the window is ignored");
}

void testDecideFixed()
{
    const qint64 L = 56 * M;
    // Fixed wins over everything, the chapter included
    Inputs in = inputs(3 * M, 60 * S, 52 * M);
    in.chapters = { { QStringLiteral("End Credits"), 54 * M } };
    in.audioMs = 53 * M;
    in.blackMs = 52 * M;
    in.fixedLeadMs = 90 * S;
    Point p = decide(L, in);
    checkEqual(p.timeMs, L - 90 * S, "fixed point");
    check(p.source == Source::Fixed, "fixed source");
    // held inside the window: never mid-episode (a 10 min episode has a 90 s window)
    in.fixedLeadMs = 5 * M;
    checkEqual(decide(10 * M, in).timeMs, 10 * M - 90 * S, "fixed held in the window");
}

void testDecideAudio()
{
    const qint64 L = 56 * M;
    Inputs in = inputs(3 * M, 60 * S, 52 * M);
    in.blackMs = 52 * M;
    in.audioMs = 53 * M + 10 * S;
    Point p = decide(L, in);
    checkEqual(p.timeMs, 53 * M + 10 * S, "audio match point");
    check(p.source == Source::Audio, "audio match wins over subtitles, black frames, learned");
    // an audio match before the window is no point
    in.audioMs = 40 * M;
    check(decide(L, in).source != Source::Audio, "audio match before the window ignored");
}

void testDecideCombined()
{
    const qint64 L = 56 * M;
    // subtitles and black frames agree within 90 s: the subtitles' point
    Inputs in = inputs(-1, 60 * S, 53 * M);
    in.blackMs = 53 * M + 40 * S;
    Point p = decide(L, in);
    checkEqual(p.timeMs, 53 * M, "subtitles and black frames agree");
    check(p.source == Source::Agreement, "agreement source");

    // black frames and the learned point agree: the black frames' point
    in = inputs(2 * M + 30 * S, 60 * S, -1);
    in.blackMs = 54 * M;
    p = decide(L, in);
    checkEqual(p.timeMs, 54 * M, "black frames and learned agree");

    // a dark scene 4 min before the credits: black frames disagree with the learned point,
    // which is used
    in = inputs(2 * M, 60 * S, -1);
    in.blackMs = 50 * M;
    p = decide(L, in);
    checkEqual(p.timeMs, 54 * M, "a dark scene does not fool black frames: the learned point");
    check(p.source == Source::Learned, "learned when they disagree");

    // black frames alone are never used (a dark scene would fool them)
    in = inputs(-1, 60 * S, -1);
    in.blackMs = 50 * M;
    p = decide(L, in);
    check(p.source == Source::Setting, "black frames alone are not used");

    // the subtitles alone are used
    in = inputs(-1, 60 * S, 52 * M + 30 * S);
    p = decide(L, in);
    checkEqual(p.timeMs, 52 * M + 30 * S, "subtitles alone");
    check(p.source == Source::Subtitles, "subtitles source");

    // subtitles and the learned point disagree: the learned point
    in = inputs(2 * M, 60 * S, 49 * M);
    checkEqual(decide(L, in).timeMs, 54 * M, "learned when subtitles disagree");
}

void testDecideLearned()
{
    const qint64 L = 56 * M;
    Point p = decide(L, inputs(2 * M, 60 * S, -1));
    checkEqual(p.timeMs, 54 * M, "learned 2 min before the end");
    check(p.source == Source::Learned, "learned source");

    // learned on a longer episode, outside this one's window (10 min, window 90 s): ignored
    p = decide(10 * M, inputs(2 * M, 60 * S, -1));
    checkEqual(p.timeMs, 9 * M, "a learned lead past the window falls back to the setting");
    check(p.source == Source::Setting, "setting source");
}

void testDecideSetting()
{
    checkEqual(decide(56 * M, inputs(-1, 30 * S, -1)).timeMs, 56 * M - 30 * S, "last 30 s");
    checkEqual(decide(56 * M, inputs(-1, 2 * M, -1)).timeMs, 54 * M, "last 2 min");
    // a short episode: the setting is held inside the window (10 min: 90 s)
    checkEqual(decide(10 * M, inputs(-1, 2 * M, -1)).timeMs, 10 * M - 90 * S, "2 min held in a 90 s window");
    check(decide(0, inputs(-1, 60 * S, -1)).source == Source::None, "no length, no point");
    check(decide(56 * M, inputs(-1, -1, -1)).source == Source::None, "nothing known, no point");
}

void testLearning()
{
    const qint64 L = 44 * M;
    // the drift: five episodes where the user clicks the card's Next episode button 20 s after
    // it showed; the point stays where it was
    qint64 saved = 90 * S;
    for (int episode = 0; episode < 5; ++episode)
    {
        Move move;
        move.lengthMs = L;
        move.timeMs = L - saved + 20 * S;
        move.fromCard = true;
        move.cardShown = true;
        move.countdownSec = 10;
        move.savedLeadMs = saved;
        const qint64 learned = learnedLead(move);
        if (learned > 0)
            saved = learned;
    }
    checkEqual(saved, 90 * S, "five card clicks keep the point");

    // Next pressed before the card showed, earlier than the saved point: moves it earlier
    Move early;
    early.lengthMs = L;
    early.timeMs = L - 150 * S;
    early.countdownSec = 10;
    early.savedLeadMs = 90 * S;
    checkEqual(learnedLead(early), 150 * S, "an early Next moves the point earlier");
    // ... but never later
    early.timeMs = L - 60 * S;
    checkEqual(learnedLead(early), -1, "a Next before the card, later than the point: kept");
    // with nothing saved, the first Next inside the window is learned
    early.savedLeadMs = -1;
    checkEqual(learnedLead(early), 60 * S, "first point learned");

    // Cancel on the card, then Next later: the point moves later, to that press
    Move cancel;
    cancel.lengthMs = L;
    cancel.timeMs = L - 40 * S;
    cancel.cardShown = true;
    cancel.cancelled = true;
    cancel.countdownSec = 10;
    cancel.savedLeadMs = 90 * S;
    checkEqual(learnedLead(cancel), 40 * S, "Cancel then a later Next moves the point later");

    // the card showed, no Cancel, the user pressed the Next key: kept
    Move key = cancel;
    key.cancelled = false;
    checkEqual(learnedLead(key), -1, "Next key while the card shows: kept");

    // the countdown and the natural end are never learned
    Move end = early;
    end.savedLeadMs = 90 * S;
    end.timeMs = L - 8 * S;
    checkEqual(learnedLead(end), -1, "the countdown is not learned");
    end.timeMs = L - 1 * S;
    checkEqual(learnedLead(end), -1, "the natural end is not learned");
    // outside the window (mid-episode): never
    end.timeMs = 20 * M;
    checkEqual(learnedLead(end), -1, "mid-episode Next is not learned");
}

void testScanPlan()
{
    // no music kept yet: full scan
    check(planScan(false, 44 * M, 44 * M) == ScanKind::Full, "first episodes: full scan");
    // music kept, length within 5 min of the usual one (a few minutes shorter or longer)
    check(planScan(true, 44 * M, 44 * M) == ScanKind::Quick, "same length: quick check");
    check(planScan(true, 44 * M, 41 * M) == ScanKind::Quick, "3 min shorter: quick check");
    check(planScan(true, 44 * M, 48 * M + 30 * S) == ScanKind::Quick, "4.5 min longer: quick check");
    // more than 5 min off: a finale or a special, full scan at once
    check(planScan(true, 44 * M, 52 * M) == ScanKind::Full, "8 min longer: full scan");
    check(planScan(true, 44 * M, 38 * M) == ScanKind::Full, "6 min shorter: full scan");
}

void testScannable()
{
    check(isScannableVideo(QStringLiteral("Show.S01E01.mkv")), "mkv");
    check(isScannableVideo(QStringLiteral("episode.MP4")), "MP4");
    check(isScannableVideo(QStringLiteral("a.ts")) && isScannableVideo(QStringLiteral("a.webm")), "ts, webm");
    check(!isScannableVideo(QStringLiteral("song.mp3")), "mp3 is never scanned");
    check(!isScannableVideo(QStringLiteral("song.flac")) && !isScannableVideo(QStringLiteral("a.m4a")), "audio files");
    check(!isScannableVideo(QStringLiteral("cover.jpg")) && !isScannableVideo(QStringLiteral("noext")), "others");
}

QVector<FrameSample> frames(qint64 from, qint64 to, float dark)
{
    QVector<FrameSample> samples;
    for (qint64 t = from; t < to; t += 250)
        samples.append({ t, dark });
    return samples;
}

void testBlackFrames()
{
    // picture to 52:00, then black credits with white text (80 % dark... above the share) to the end
    QVector<FrameSample> samples = frames(48 * M, 52 * M, 0.2f) + frames(52 * M, 56 * M, 0.92f);
    checkEqual(blackStart(samples), 52 * M, "black credits start");
    // a 20 s dark scene at 49:00 is too short: the credits are found
    samples = frames(48 * M, 49 * M, 0.2f) + frames(49 * M, 49 * M + 20 * S, 0.95f)
              + frames(49 * M + 20 * S, 52 * M, 0.2f) + frames(52 * M, 56 * M, 0.92f);
    checkEqual(blackStart(samples), 52 * M, "a short dark scene is skipped");
    // a long dark scene is found by black frames (decide() never uses them alone for that)
    samples = frames(48 * M, 49 * M, 0.2f) + frames(49 * M, 50 * M, 0.95f) + frames(50 * M, 56 * M, 0.2f);
    checkEqual(blackStart(samples), 49 * M, "a long dark scene looks like black frames");
    // no black: none
    checkEqual(blackStart(frames(48 * M, 56 * M, 0.3f)), -1, "no black frames");
    // a few bright frames inside the black (a logo) do not break it
    samples = frames(52 * M, 52 * M + 20 * S, 0.95f) + frames(52 * M + 20 * S, 52 * M + 21 * S, 0.1f)
              + frames(52 * M + 21 * S, 56 * M, 0.95f);
    samples = frames(48 * M, 52 * M, 0.2f) + samples;
    checkEqual(blackStart(samples), 52 * M, "a logo in the black");
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
    testDecideFixed();
    testDecideAudio();
    testDecideCombined();
    testLearning();
    testScanPlan();
    testScannable();
    testBlackFrames();
    testSubtitleLines();
    testDialogueEnd();
    testParsers();
    std::printf("rd_credits_point: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
