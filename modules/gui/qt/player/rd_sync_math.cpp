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
#include "rd_sync_math.hpp"

#include <algorithm>
#include <cmath>
#include <complex>

namespace rdsync {

namespace {

constexpr double kPi = 3.14159265358979323846;

// the voice band (speech's fundamentals and formants)
constexpr double kVoiceLowHz = 250.0;
constexpr double kVoiceHighHz = 3500.0;
// a frame quieter than this is silence (digital zero, a gap)
constexpr float kSilenceDb = -90.f;
// detectSpeech: the averages the voice band's loudness swings around (a syllable, half a
// second), and the swings mapped to 0 and 1
constexpr int kSyllableFrames = 3;
constexpr int kPhraseFrames = 25;
constexpr double kTypicalPercentile = 0.50;
constexpr double kStrongPercentile = 0.95;
// align: a peak that stands this many standard deviations above the other shifts is a match
constexpr double kMinConfidence = 5.0;
// align: a frame-rate factor other than 1 is taken when it scores this much better
constexpr double kScaleAdvantage = 1.08;

using Complex = std::complex<double>;

void fft(std::vector<Complex>& a, bool inverse)
{
    const size_t n = a.size();
    for (size_t i = 1, j = 0; i < n; ++i)
    {
        size_t bit = n >> 1;
        for (; j & bit; bit >>= 1)
            j ^= bit;
        j ^= bit;
        if (i < j)
            std::swap(a[i], a[j]);
    }
    for (size_t len = 2; len <= n; len <<= 1)
    {
        const double angle = 2 * kPi / static_cast<double>(len) * (inverse ? 1 : -1);
        const Complex step(std::cos(angle), std::sin(angle));
        for (size_t i = 0; i < n; i += len)
        {
            Complex w(1);
            for (size_t k = 0; k < len / 2; ++k)
            {
                const Complex u = a[i + k];
                const Complex v = a[i + k + len / 2] * w;
                a[i + k] = u + v;
                a[i + k + len / 2] = u - v;
                w *= step;
            }
        }
    }
    if (inverse)
        for (Complex& x : a)
            x /= static_cast<double>(n);
}

double percentile(std::vector<float> values, double p)
{
    if (values.empty())
        return 0;
    const size_t k = std::min(values.size() - 1, static_cast<size_t>(p * static_cast<double>(values.size())));
    std::nth_element(values.begin(), values.begin() + static_cast<std::ptrdiff_t>(k), values.end());
    return values[k];
}

// the average over `width` frames centred on each frame (fewer at the ends)
std::vector<float> movingAverage(const std::vector<float>& in, int width)
{
    const size_t n = in.size();
    std::vector<double> prefix(n + 1, 0.0);
    for (size_t i = 0; i < n; ++i)
        prefix[i + 1] = prefix[i] + in[i];
    std::vector<float> out(n);
    const int64_t half = width / 2;
    for (size_t i = 0; i < n; ++i)
    {
        const int64_t lo = std::max<int64_t>(0, static_cast<int64_t>(i) - half);
        const int64_t hi = std::min<int64_t>(static_cast<int64_t>(n), static_cast<int64_t>(i) + width - half);
        out[i] = static_cast<float>((prefix[static_cast<size_t>(hi)] - prefix[static_cast<size_t>(lo)]) / static_cast<double>(hi - lo));
    }
    return out;
}

// the signal less its mean, and its length (norm)
double centre(const std::vector<float>& in, std::vector<double>& out)
{
    double mean = 0;
    for (float v : in)
        mean += v;
    mean /= std::max<size_t>(1, in.size());
    out.resize(in.size());
    double norm = 0;
    for (size_t i = 0; i < in.size(); ++i)
    {
        out[i] = in[i] - mean;
        norm += out[i] * out[i];
    }
    return std::sqrt(norm);
}

struct Peak
{
    int64_t lag = 0;
    double score = 0;
    double confidence = 0;
};

// the shift of `cues` (frames, positive: later) that correlates best with the reference whose
// spectrum is `refSpectrum`
Peak bestShift(const std::vector<Complex>& refSpectrum, double refNorm, size_t refFrames,
               const std::vector<Cue>& cues, double scale, int64_t maxLag)
{
    const size_t n = refSpectrum.size();
    std::vector<double> cue;
    const double cueNorm = centre(cueSignal(cues, refFrames, scale), cue);
    if (cueNorm <= 0 || refNorm <= 0)
        return {};

    std::vector<Complex> spectrum(n);
    for (size_t i = 0; i < cue.size(); ++i)
        spectrum[i] = cue[i];
    fft(spectrum, false);
    for (size_t i = 0; i < n; ++i)
        spectrum[i] = refSpectrum[i] * std::conj(spectrum[i]);
    fft(spectrum, true);

    // c[lag] = sum over t of ref[t + lag] * cue[t]: lag >= 0 at lag, lag < 0 at n + lag
    const int64_t limit = std::min<int64_t>(maxLag, static_cast<int64_t>(n / 2) - 1);
    Peak peak;
    peak.score = -2;
    double sum = 0, sumSquares = 0;
    int64_t count = 0;
    for (int64_t lag = -limit; lag <= limit; ++lag)
    {
        const size_t index = lag >= 0 ? static_cast<size_t>(lag) : n - static_cast<size_t>(-lag);
        const double c = spectrum[index].real() / (refNorm * cueNorm);
        sum += c;
        sumSquares += c * c;
        ++count;
        if (c > peak.score)
        {
            peak.score = c;
            peak.lag = lag;
        }
    }
    const double mean = sum / static_cast<double>(count);
    const double deviation = std::sqrt(std::max(0.0, sumSquares / static_cast<double>(count) - mean * mean));
    peak.confidence = deviation > 0 ? (peak.score - mean) / deviation : 0;
    return peak;
}

} // namespace

double FeatureExtractor::Biquad::run(double x)
{
    // transposed direct form II
    const double y = b0 * x + z1;
    z1 = b1 * x - a1 * y + z2;
    z2 = b2 * x - a2 * y;
    return y;
}

FeatureExtractor::FeatureExtractor(unsigned sampleRate)
    : m_rate(std::max(8000u, sampleRate))
    , m_frameSamples(std::max<size_t>(1, m_rate * kFrameMs / 1000))
{
    // second-order Butterworth high pass and low pass (the audio EQ cookbook's formulas)
    const auto design = [this](Biquad& f, double hz, bool high) {
        const double w = 2 * kPi * std::min(hz, m_rate * 0.45) / m_rate;
        const double alpha = std::sin(w) / (2 * std::sqrt(0.5));
        const double cosw = std::cos(w);
        const double a0 = 1 + alpha;
        if (high)
        {
            f.b0 = (1 + cosw) / 2 / a0;
            f.b1 = -(1 + cosw) / a0;
            f.b2 = (1 + cosw) / 2 / a0;
        }
        else
        {
            f.b0 = (1 - cosw) / 2 / a0;
            f.b1 = (1 - cosw) / a0;
            f.b2 = (1 - cosw) / 2 / a0;
        }
        f.a1 = -2 * cosw / a0;
        f.a2 = (1 - alpha) / a0;
    };
    design(m_highPass, kVoiceLowHz, true);
    design(m_lowPass, kVoiceHighHz, false);
}

void FeatureExtractor::push(const float* samples, size_t count)
{
    for (size_t i = 0; i < count; ++i)
    {
        const double x = samples[i];
        const double y = m_lowPass.run(m_highPass.run(x));
        m_totalSum += x * x;
        m_bandSum += y * y;
        if (++m_count == m_frameSamples)
            closeFrame();
    }
}

void FeatureExtractor::skipTo(size_t frame)
{
    if (m_count > 0)
        closeFrame();
    while (m_band.size() < frame)
    {
        m_band.push_back(kSilenceDb - 10);
        m_total.push_back(kSilenceDb - 10);
    }
}

void FeatureExtractor::finish()
{
    if (m_count > m_frameSamples / 2)
        closeFrame();
    m_count = 0;
    m_bandSum = m_totalSum = 0;
}

void FeatureExtractor::closeFrame()
{
    const double n = static_cast<double>(std::max<size_t>(1, m_count));
    m_band.push_back(static_cast<float>(10 * std::log10(m_bandSum / n + 1e-12)));
    m_total.push_back(static_cast<float>(10 * std::log10(m_totalSum / n + 1e-12)));
    m_count = 0;
    m_bandSum = m_totalSum = 0;
}

std::vector<float> detectSpeech(const std::vector<float>& bandDb, const std::vector<float>& totalDb)
{
    // speech rises and falls with its syllables (about 4 a second) while music, ambience and
    // effects hold their level: the voice band's loudness less its average over half a second,
    // averaged over half a second, is far likelier in speech than the loudness itself
    // (redesign/SUBTITLE_AUTO_SYNC_NOTES.md, section 3)
    const size_t n = std::min(bandDb.size(), totalDb.size());
    std::vector<float> speech(n, 0.f);
    if (n < 50)
        return speech;

    std::vector<float> level(bandDb.begin(), bandDb.begin() + static_cast<std::ptrdiff_t>(n));
    // silence (digital zero) counts as the quietest sound, so it does not swing
    float quietest = 0.f;
    bool any = false;
    for (size_t i = 0; i < n; ++i)
        if (totalDb[i] > kSilenceDb)
        {
            quietest = any ? std::min(quietest, level[i]) : level[i];
            any = true;
        }
    if (!any)
        return speech;
    for (size_t i = 0; i < n; ++i)
        if (totalDb[i] <= kSilenceDb)
            level[i] = quietest;

    const std::vector<float> fast = movingAverage(level, kSyllableFrames);
    const std::vector<float> slow = movingAverage(level, kPhraseFrames);
    std::vector<float> swing(n);
    for (size_t i = 0; i < n; ++i)
        swing[i] = std::abs(fast[i] - slow[i]);
    swing = movingAverage(swing, kPhraseFrames);

    // 0 at the file's typical swing, 1 at its strongest
    const double typical = percentile(swing, kTypicalPercentile);
    const double strong = percentile(swing, kStrongPercentile);
    if (strong - typical < 0.5)
        return speech;
    for (size_t i = 0; i < n; ++i)
        speech[i] = static_cast<float>(std::clamp((swing[i] - typical) / (strong - typical), 0.0, 1.0));
    return speech;
}

std::vector<float> cueSignal(const std::vector<Cue>& cues, size_t frames, double scale)
{
    std::vector<float> signal(frames, 0.f);
    for (const Cue& cue : cues)
    {
        if (cue.endMs <= cue.startMs)
            continue;
        const double start = static_cast<double>(cue.startMs) * scale / kFrameMs;
        const double end = static_cast<double>(cue.endMs) * scale / kFrameMs;
        const int64_t first = std::max<int64_t>(0, static_cast<int64_t>(std::floor(start)));
        const int64_t last = std::min<int64_t>(static_cast<int64_t>(frames), static_cast<int64_t>(std::ceil(end)));
        for (int64_t f = first; f < last; ++f)
            signal[static_cast<size_t>(f)] = 1.f;
    }
    return signal;
}

std::vector<double> frameRateScales()
{
    const double ntsc = 24000.0 / 1001.0;
    return { 1.0, 25.0 / ntsc, ntsc / 25.0, 24.0 / ntsc, ntsc / 24.0, 25.0 / 24.0, 24.0 / 25.0 };
}

bool isUnitScale(double scale)
{
    return std::abs(scale - 1.0) < 1e-4;
}

Match align(const std::vector<float>& reference, const std::vector<Cue>& cues, bool tryScales,
            int64_t maxOffsetMs)
{
    Match match;
    if (reference.empty() || cues.empty())
        return match;

    const int64_t maxLag = maxOffsetMs / kFrameMs;
    // the cues may reach past the reference by the largest shift, and the correlation must not
    // wrap around: room for both
    size_t n = 1;
    while (n < reference.size() + static_cast<size_t>(maxLag) * 2 + 2)
        n <<= 1;

    std::vector<double> ref;
    const double refNorm = centre(reference, ref);
    std::vector<Complex> refSpectrum(n);
    for (size_t i = 0; i < ref.size(); ++i)
        refSpectrum[i] = ref[i];
    fft(refSpectrum, false);

    // the cues are laid out over the reference's length plus the largest shift, so lines that
    // start after the audio's end (a track shifted late) still count
    const size_t cueFrames = std::min(n - static_cast<size_t>(maxLag), reference.size() + static_cast<size_t>(maxLag));

    Peak unit;
    Peak best;
    double bestScale = 1.0;
    const std::vector<double> scales = tryScales ? frameRateScales() : std::vector<double>{ 1.0 };
    for (double scale : scales)
    {
        const Peak peak = bestShift(refSpectrum, refNorm, cueFrames, cues, scale, maxLag);
        if (isUnitScale(scale))
        {
            unit = peak;
            if (peak.score > best.score || best.score == 0)
            {
                best = peak;
                bestScale = scale;
            }
        }
        else if (peak.confidence >= kMinConfidence && peak.score > unit.score * kScaleAdvantage
                 && peak.score > best.score)
        {
            best = peak;
            bestScale = scale;
        }
    }

    match.found = best.confidence >= kMinConfidence && best.score > 0;
    match.offsetMs = best.lag * kFrameMs;
    match.scale = bestScale;
    match.score = best.score;
    match.confidence = best.confidence;
    return match;
}

} // namespace rdsync
