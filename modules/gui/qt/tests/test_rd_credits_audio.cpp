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

// Cone extra (Up Next, UP_NEXT_CREDITS_SCAN_NOTES.md section 3): the credits music matched
// across episodes, on generated audio. Each episode ending has its own sound (random notes and
// noise) and then the show's credits melody; the match must find where the melody starts in
// each, the quick check must find the kept melody in a 2-minute window, and unrelated music or
// silence must never match. The standard library only.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "player/rd_credits_audio.hpp"

#include <cmath>
#include <cstdio>
#include <string>
#include <vector>

using namespace rdcredits;

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

void checkNear(long actual, long expected, long tolerance, const std::string& what)
{
    check(std::labs(actual - expected) <= tolerance,
          what + ": got " + std::to_string(actual) + ", expected " + std::to_string(expected));
}

struct Random
{
    uint32_t state;
    explicit Random(uint32_t seed) : state(seed * 2654435761u + 7) {}
    uint32_t next()
    {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return state;
    }
    double unit() { return next() / 4294967296.0; }
};

constexpr double kPi = 3.14159265358979323846;

// notes of 0.2 to 0.6 s between 250 Hz and 1.8 kHz, with their second harmonic
void addNotes(std::vector<float>& out, unsigned rate, double from, double to, uint32_t seed, double level)
{
    Random random(seed);
    double t = from;
    while (t < to)
    {
        const double length = 0.2 + 0.4 * random.unit();
        const double hz = 250.0 * std::pow(7.2, random.unit());
        const size_t a = size_t(t * rate);
        const size_t b = std::min(out.size(), size_t(std::min(to, t + length) * rate));
        for (size_t i = a; i < b; ++i)
        {
            const double x = double(i - a) / rate;
            const double envelope = std::min(1.0, x * 40.0) * std::min(1.0, (double(b - i) / rate) * 40.0);
            out[i] += float(level * envelope * (std::sin(2 * kPi * hz * x) + 0.4 * std::sin(4 * kPi * hz * x)));
        }
        t += length;
    }
}

void addNoise(std::vector<float>& out, uint32_t seed, double level)
{
    Random random(seed);
    for (float& v : out)
        v += float(level * (random.unit() * 2 - 1));
}

constexpr uint32_t kShowMelody = 1234;

// an episode's last `seconds`: its own sound to `creditsAt`, then the show's melody for
// `creditsLength`, then (optionally) a post-credits scene of its own sound
std::vector<float> ending(unsigned rate, double seconds, double creditsAt, double creditsLength,
                          uint32_t episodeSeed, uint32_t melody = kShowMelody)
{
    std::vector<float> out(size_t(seconds * rate), 0.f);
    addNotes(out, rate, 0, creditsAt, episodeSeed, 0.25);
    // the episode's own noise up to the credits, and coding noise everywhere (the credits audio
    // is the same track in every episode, re-encoded)
    {
        std::vector<float> noise(size_t(std::min(seconds, creditsAt) * rate), 0.f);
        addNoise(noise, episodeSeed + 99, 0.05);
        for (size_t i = 0; i < noise.size(); ++i)
            out[i] += noise[i];
    }
    addNoise(out, episodeSeed + 98, 0.003);
    addNotes(out, rate, creditsAt, std::min(seconds, creditsAt + creditsLength), melody, 0.3);
    if (creditsAt + creditsLength < seconds)
        addNotes(out, rate, creditsAt + creditsLength, seconds, episodeSeed + 7, 0.25);
    return out;
}

std::vector<uint32_t> printsOf(const std::vector<float>& audio, unsigned rate)
{
    AudioPrinter printer(rate);
    for (size_t i = 0; i < audio.size(); i += 4096)
        printer.push(audio.data() + i, std::min<size_t>(4096, audio.size() - i));
    return printer.prints();
}

long index(double seconds)
{
    return long(std::lround(seconds * kPrintsPerSecond));
}

} // namespace

int main()
{
    const unsigned rate = 22050;
    const double window = 8 * 60;

    // two episodes, credits 90 s long starting 6:10 and 5:30 into the last 8 minutes
    const std::vector<uint32_t> a = printsOf(ending(rate, window, 370, 90, 11), rate);
    const std::vector<uint32_t> b = printsOf(ending(rate, window, 330.06, 90, 22), rate);
    check(a.size() >= size_t(index(window)) - 8, "8 values a second");
    const Match match = longestMatch(a, b);
    check(match.found, "the credits music matches across two episodes");
    checkNear(match.aStart, index(370), 4, "credits start in the first episode");
    checkNear(match.bStart, index(330), 4, "credits start in the second episode");
    checkNear(match.length, index(90), 12, "credits length");

    // the kept music (its first 60 s), found by the quick check in a 2-minute window centred on
    // the expected point: a third episode whose credits start 25 s after the expected point
    std::vector<uint32_t> music(a.begin() + match.aStart, a.begin() + std::min<long>(long(a.size()), match.aStart + index(kKeptMusicSeconds)));
    const std::vector<uint32_t> quick = printsOf(ending(rate, 120 + 15, 60 + 25.04, 90, 33), rate);
    checkNear(findMusic(quick, music), index(85), 4, "quick check finds the music 25 s after the expected point");
    // a lossy copy: half of the values changed (re-encoded music matches about 40 % of its values)
    {
        std::vector<uint32_t> lossy = quick;
        Random random(5);
        for (uint32_t& v : lossy)
            if (random.unit() < 0.5)
                v = random.next();
        checkNear(findMusic(lossy, music), index(85), 4, "quick check finds the music in a lossy copy");
    }
        // another show's music: not found
    const std::vector<uint32_t> other = printsOf(ending(rate, 120 + 15, 60, 90, 44, 9876), rate);
    check(findMusic(other, music) < 0, "another show's music is not found by the quick check");
    // the episode's own sound only (no credits music in the window: longer credits): not found
    const std::vector<uint32_t> early = printsOf(ending(rate, 135, 200, 90, 55), rate);
    check(findMusic(early, music) < 0, "no music in the window: the quick check fails");

    // unrelated endings, and silent ones, never match
    check(!longestMatch(a, printsOf(ending(rate, window, 330, 90, 66, 4321), rate)).found,
          "different credits music does not match");
    const std::vector<uint32_t> silence = printsOf(std::vector<float>(size_t(window * rate), 0.f), rate);
    check(!longestMatch(silence, silence).found, "two silent endings do not match");

    // credits longer than 5 minutes (6:30, from 1:30 into the window), at 44.1 kHz
    const unsigned cd = 44100;
    const std::vector<uint32_t> longA = printsOf(ending(cd, window, 90, 390, 77), cd);
    const std::vector<uint32_t> longB = printsOf(ending(cd, window, 100.09, 380, 88), cd);
    const Match longMatch = longestMatch(longA, longB);
    check(longMatch.found, "long credits match");
    checkNear(longMatch.aStart, index(90), 4, "long credits start, first episode");
    checkNear(longMatch.bStart, index(100), 4, "long credits start, second episode");

    // a post-credits scene: the match ends with the credits
    const std::vector<uint32_t> postA = printsOf(ending(rate, window, 300, 120, 12), rate);
    const std::vector<uint32_t> postB = printsOf(ending(rate, window, 320.03, 120, 13), rate);
    const Match post = longestMatch(postA, postB);
    checkNear(post.aStart, index(300), 8, "post-credits scene: start (within 1 s)");
    checkNear(post.length, index(120), 12, "post-credits scene: the match ends with the credits");

    check(bitErrors(0xF0F0F0F0u, 0x0F0F0F0Fu) == 32 && bitErrors(5, 4) == 1, "bit errors");

    std::printf("test_rd_credits_audio: %d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
