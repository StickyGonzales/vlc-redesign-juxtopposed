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
#ifndef RD_CREDITS_AUDIO_HPP
#define RD_CREDITS_AUDIO_HPP

// redesign (Cone extra, Up Next, UP_NEXT_CREDITS_SCAN_NOTES.md section 3): the credits music
// usually repeats in every episode of a show. The audio of the end of an episode becomes a
// fingerprint, 8 values a second, each 32 bits telling how the loudness of 33 bands between
// 300 Hz and 2 kHz changes from band to band and from one moment to the next (the classic
// "Philips" audio fingerprint; Chromaprint, used by Jellyfin's Intro Skipper, works alike).
// Bands more than 30 dB under the moment's loudest are taken as equally empty, so faint noise
// decides no bits; two values are the same moment when 70 % of the bands rising in either rise
// in both. Two episodes match where the same music plays for 15 s or more, as in Intro Skipper.
// Our own code: no Chromaprint, no Intro Skipper code.
//
// The standard library only, pure (the file is read by rd_credits_scanner).

#include <cstddef>
#include <cstdint>
#include <vector>

namespace rdcredits {

// fingerprint values per second (one each 125 ms)
constexpr int kPrintsPerSecond = 8;
constexpr int kPrintMs = 1000 / kPrintsPerSecond;
// a match lasts at least this long, and may skip this long a stretch that does not match (a
// sound effect over the music)
constexpr int kMinMatchSeconds = 15;
constexpr double kMaxGapSeconds = 3.5;
// the credits music kept for a show: its first seconds
constexpr int kKeptMusicSeconds = 60;
// the quick check looks for the start of the kept music: this much of it must match
constexpr int kQuickMatchSeconds = 10;
// and this share of its values must match where it starts
constexpr int kQuickHitPercent = 25;

// mono samples at any rate in, fingerprint values out
class AudioPrinter
{
public:
    explicit AudioPrinter(unsigned sampleRate);

    void push(const float* samples, size_t count);
    // a gap in the audio up to `seconds` from the first sample: values of silence are added
    void skipTo(double seconds);
    const std::vector<uint32_t>& prints() const { return m_prints; }

private:
    void frame();

    unsigned m_decimation;
    double m_rate;
    size_t m_fftSize;
    size_t m_hop;
    std::vector<float> m_ring;
    size_t m_writePos = 0;
    size_t m_filled = 0;
    size_t m_sinceHop = 0;
    double m_accumulator = 0;
    unsigned m_accumulated = 0;
    std::vector<float> m_window;
    std::vector<int> m_bandEdges;
    std::vector<double> m_prevEnergy;
    bool m_hasPrev = false;
    std::vector<uint32_t> m_prints;
};

int bitErrors(uint32_t a, uint32_t b);

struct Match
{
    bool found = false;
    // where the shared music starts in each fingerprint (index), and how long it lasts (values)
    int aStart = -1;
    int bStart = -1;
    int length = 0;
};

// the longest stretch of the same music in two fingerprints (the ends of two episodes), at any
// shift; found when it lasts kMinMatchSeconds or more
Match longestMatch(const std::vector<uint32_t>& a, const std::vector<uint32_t>& b);

// where `music` (a show's kept credits music) starts in `haystack`: kQuickHitPercent of the
// values of its first kQuickMatchSeconds must match; -1 when they do not
int findMusic(const std::vector<uint32_t>& haystack, const std::vector<uint32_t>& music);

} // namespace rdcredits

#endif // RD_CREDITS_AUDIO_HPP
