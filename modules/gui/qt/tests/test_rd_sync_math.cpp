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

// redesign (Cone build, SUBTITLE_AUTO_SYNC_NOTES.md section 6): the automatic subtitle sync's
// arithmetic on generated audio: syllable-like noise bursts where the lines are, steady music
// and noise everywhere. A track shifted by a constant offset and a track timed for 25 fps on a
// 23.976 fps video must be found; unrelated lines and silence must not match.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "player/rd_sync_math.hpp"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

using namespace rdsync;

namespace {

int checks = 0;
int failures = 0;

void check(bool ok, const std::string& what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s\n", what.c_str());
    }
}

void checkNear(int64_t actual, int64_t expected, int64_t tolerance, const std::string& what)
{
    check(std::llabs(actual - expected) <= tolerance,
          what + ": got " + std::to_string(actual) + ", expected " + std::to_string(expected));
}

void checkNear(double actual, double expected, double tolerance, const std::string& what)
{
    check(std::abs(actual - expected) <= tolerance,
          what + ": got " + std::to_string(actual) + ", expected " + std::to_string(expected));
}

// a small deterministic generator (the same numbers on every platform)
struct Random
{
    uint32_t state;
    explicit Random(uint32_t seed) : state(seed * 2654435761u + 1) {}
    uint32_t next()
    {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return state;
    }
    double unit() { return next() / 4294967296.0; }
    int64_t range(int64_t lo, int64_t hi) { return lo + static_cast<int64_t>(unit() * static_cast<double>(hi - lo)); }
};

constexpr unsigned kRate = 16000;
constexpr int64_t kLengthMs = 10 * 60 * 1000;

// lines of 1 to 5 s with gaps of 0.5 to 12 s
std::vector<Cue> makeCues(uint32_t seed)
{
    Random random(seed);
    std::vector<Cue> cues;
    int64_t t = random.range(5000, 15000);
    while (t < kLengthMs - 10000)
    {
        const int64_t length = random.range(1000, 5000);
        cues.push_back({ t, t + length });
        t += length + random.range(500, 12000);
    }
    return cues;
}

// the film's sound: steady chords and noise throughout, and in the lines, bursts of voice-band
// noise of a syllable's length (speech's rhythm)
std::vector<float> makeAudio(const std::vector<Cue>& speech)
{
    Random random(7);
    const size_t samples = static_cast<size_t>(kLengthMs) * kRate / 1000;
    std::vector<float> audio(samples);
    const double pi = 3.14159265358979323846;
    for (size_t i = 0; i < samples; ++i)
    {
        const double t = static_cast<double>(i) / kRate;
        const double music = 0.12 * std::sin(2 * pi * 110 * t) + 0.08 * std::sin(2 * pi * 164.8 * t)
                             + 0.06 * std::sin(2 * pi * 659 * t);
        audio[i] = static_cast<float>(music + 0.02 * (random.unit() * 2 - 1));
    }
    // a simple voice-band colour for the bursts: noise through two one-pole filters
    for (const Cue& cue : speech)
    {
        int64_t at = cue.startMs;
        while (at < cue.endMs)
        {
            const int64_t syllable = random.range(90, 260);
            const int64_t end = std::min(cue.endMs, at + syllable);
            double low = 0, high = 0;
            for (int64_t ms = at; ms < end; ++ms)
                for (unsigned k = 0; k < kRate / 1000; ++k)
                {
                    const size_t i = static_cast<size_t>(ms) * (kRate / 1000) + k;
                    if (i >= samples)
                        break;
                    const double x = random.unit() * 2 - 1;
                    low += 0.35 * (x - low);
                    high = low - 0.9 * high;
                    audio[i] += static_cast<float>(0.5 * (low - 0.5 * high));
                }
            at = end + random.range(40, 160);
        }
    }
    return audio;
}

std::vector<Cue> transform(const std::vector<Cue>& cues, double scale, int64_t shiftMs)
{
    std::vector<Cue> out;
    for (const Cue& cue : cues)
        out.push_back({ static_cast<int64_t>(std::llround(static_cast<double>(cue.startMs) * scale)) + shiftMs,
                        static_cast<int64_t>(std::llround(static_cast<double>(cue.endMs) * scale)) + shiftMs });
    return out;
}

std::vector<float> speechOf(const std::vector<float>& audio)
{
    FeatureExtractor features(kRate);
    // in pieces, as decoded audio comes
    for (size_t i = 0; i < audio.size(); i += 1024)
        features.push(audio.data() + i, std::min<size_t>(1024, audio.size() - i));
    features.finish();
    return detectSpeech(features.bandDb(), features.totalDb());
}

} // namespace

int main()
{
    const double ntsc = 24000.0 / 1001.0;
    const std::vector<Cue> truth = makeCues(1);
    const std::vector<float> speech = speechOf(makeAudio(truth));
    checkNear(static_cast<int64_t>(speech.size()), kLengthMs / kFrameMs, 1, "frames");

    // a constant offset, either way; the delay that puts the lines back is the opposite
    for (int64_t shift : { int64_t(2400), int64_t(-7300), int64_t(45000) })
    {
        const Match m = align(speech, transform(truth, 1.0, shift), true);
        const std::string what = "offset " + std::to_string(shift);
        check(m.found, what + ": found");
        checkNear(m.offsetMs, -shift, 40, what + ": delay");
        check(isUnitScale(m.scale), what + ": no frame-rate change");
    }

    // lines timed for 25 fps on a 23.976 fps video: their times are 23.976/25 of the speech's
    {
        const Match m = align(speech, transform(truth, ntsc / 25.0, 0), true);
        check(m.found, "25 vs 23.976: found");
        checkNear(m.scale, 25.0 / ntsc, 1e-6, "25 vs 23.976: factor");
        checkNear(m.offsetMs, 0, 60, "25 vs 23.976: delay");
    }
    // the other way, with an offset on top
    {
        const Match m = align(speech, transform(truth, 25.0 / ntsc, 1500), true);
        check(m.found, "23.976 vs 25 + 1.5 s: found");
        checkNear(m.scale, ntsc / 25.0, 1e-6, "23.976 vs 25 + 1.5 s: factor");
        // (t * 25/23.976 + 1500) * 23.976/25 + delay = t
        checkNear(m.offsetMs, static_cast<int64_t>(-1500 * ntsc / 25.0), 60, "23.976 vs 25 + 1.5 s: delay");
    }
    // without the frame-rate search, a mismatch is never "found" as a scale
    {
        const Match m = align(speech, transform(truth, 1.0, 900), false);
        check(m.found && isUnitScale(m.scale), "no scale search: offset only");
        checkNear(m.offsetMs, -900, 40, "no scale search: delay");
    }

    // another track as the reference (an in-sync track of the same film)
    {
        const std::vector<float> reference = cueSignal(truth, static_cast<size_t>(kLengthMs / kFrameMs));
        const Match shifted = align(reference, transform(truth, 1.0, 3700), true);
        check(shifted.found, "reference track: found");
        checkNear(shifted.offsetMs, -3700, 20, "reference track: delay");
        const Match scaled = align(reference, transform(truth, ntsc / 25.0, -1200), true);
        check(scaled.found, "reference track, 25 vs 23.976: found");
        checkNear(scaled.scale, 25.0 / ntsc, 1e-6, "reference track, 25 vs 23.976: factor");
        checkNear(scaled.offsetMs, static_cast<int64_t>(1200 * 25.0 / ntsc), 60, "reference track, 25 vs 23.976: delay");
    }

    // lines of another film, and no speech at all: no match
    for (uint32_t seed : { 11u, 12u, 13u })
        check(!align(speech, makeCues(seed), true).found, "unrelated lines " + std::to_string(seed) + ": not found");
    check(!align(std::vector<float>(30000, 0.f), truth, true).found, "silence: not found");
    check(!align(speech, {}, true).found, "no lines: not found");

    // the lines' signal
    {
        const std::vector<float> s = cueSignal({ { 100, 200 } }, 20, 1.0);
        check(s[4] == 0.f && s[5] == 1.f && s[9] == 1.f && s[10] == 0.f, "cueSignal frames 5 to 9");
        const std::vector<float> scaled = cueSignal({ { 100, 200 } }, 20, 2.0);
        check(scaled[9] == 0.f && scaled[10] == 1.f && scaled[19] == 1.f, "cueSignal scaled");
        check(frameRateScales().size() == 7 && isUnitScale(frameRateScales().front()), "scales: 1 first");
    }

    std::printf("test_rd_sync_math: %d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
