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
#ifndef RD_SYNC_MATH_HPP
#define RD_SYNC_MATH_HPP

// redesign (Cone build, redesign/SUBTITLE_AUTO_SYNC_NOTES.md): the arithmetic of the automatic
// subtitle sync, without VLC: the speech found in the audio and the subtitle lines both become
// a timeline of 20 ms frames, and the shift (and frame-rate scale) that lines them up best is
// the peak of their cross-correlation. The same approach as ffsubsync and alass, written for
// Cone (no code of either is used).

#include <cstdint>
#include <vector>

namespace rdsync {

// one frame of the timelines, in milliseconds
constexpr int kFrameMs = 20;
// the largest shift searched, either way
constexpr int64_t kMaxOffsetMs = 5 * 60 * 1000;

// one subtitle line: when it shows and hides, in milliseconds of the track's own times
struct Cue
{
    int64_t startMs = 0;
    int64_t endMs = 0;
};

// the loudness of the audio per frame, overall and in the voice band (250 Hz - 3.5 kHz), in
// dB; fed with mono samples at the audio's own rate
class FeatureExtractor
{
public:
    explicit FeatureExtractor(unsigned sampleRate);

    // the next samples, in order (the scan moves to a frame with skipTo when the audio jumps)
    void push(const float* samples, size_t count);
    // the next samples belong to `frame` (a gap in the audio): the frames between stay silent
    void skipTo(size_t frame);
    // the frame being filled is complete as far as it goes
    void finish();

    unsigned sampleRate() const { return m_rate; }
    size_t frames() const { return m_band.size(); }
    const std::vector<float>& bandDb() const { return m_band; }
    const std::vector<float>& totalDb() const { return m_total; }

private:
    struct Biquad
    {
        double b0 = 1, b1 = 0, b2 = 0, a1 = 0, a2 = 0;
        double z1 = 0, z2 = 0;
        double run(double x);
    };
    void closeFrame();

    unsigned m_rate;
    size_t m_frameSamples;
    Biquad m_highPass;
    Biquad m_lowPass;
    double m_bandSum = 0;
    double m_totalSum = 0;
    size_t m_count = 0;
    std::vector<float> m_band;
    std::vector<float> m_total;
};

// how likely each frame holds speech, 0 to 1, from the loudness per frame (voice activity:
// louder than the file's quiet parts, and most of its energy in the voice band)
std::vector<float> detectSpeech(const std::vector<float>& bandDb, const std::vector<float>& totalDb);

// 1 in the frames a line is shown, 0 elsewhere; the lines' times are multiplied by `scale`
std::vector<float> cueSignal(const std::vector<Cue>& cues, size_t frames, double scale = 1.0);

// the frame-rate mismatches tried: the factor the lines' times are multiplied by
// (1, 25/23.976, 23.976/25, 24/23.976, 23.976/24, 25/24, 24/25)
std::vector<double> frameRateScales();

struct Match
{
    bool found = false;
    // the delay to give the lines (positive: later), and the factor their times need
    int64_t offsetMs = 0;
    double scale = 1.0;
    // the correlation at the peak, -1 to 1, and how far the peak stands above the other shifts
    // (standard deviations)
    double score = 0;
    double confidence = 0;
};

// the shift (and, with `tryScales`, the frame-rate factor) that lines `cues` up with
// `reference` (speech per frame, or another track's cueSignal). `found` is false when no shift
// stands out (no speech, music only, a subtitle file of another film)
Match align(const std::vector<float>& reference, const std::vector<Cue>& cues, bool tryScales,
            int64_t maxOffsetMs = kMaxOffsetMs);

// a factor this close to 1 is no frame-rate change
bool isUnitScale(double scale);

} // namespace rdsync

#endif // RD_SYNC_MATH_HPP
