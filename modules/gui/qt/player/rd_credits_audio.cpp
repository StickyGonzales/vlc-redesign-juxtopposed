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
#include "rd_credits_audio.hpp"

#include <algorithm>
#include <bitset>
#include <cmath>
#include <complex>

namespace rdcredits {

namespace {

constexpr double kPi = 3.14159265358979323846;
// the audio is brought down to about this rate (plenty for 300 Hz to 2 kHz)
constexpr double kWorkRate = 11025.0;
// 0.74 s at the working rate: neighbouring values overlap by 83 %, so where a moment falls on
// the 125 ms grid changes little
constexpr size_t kFftSize = 8192;
// 33 bands give 32 differences, one bit each
constexpr int kBands = 33;
constexpr double kLowHz = 300.0;
constexpr double kHighHz = 2000.0;
// a moment quieter than this (mean square, -60 dBFS) has no music: its value is 0 and never
// matches (two silent endings must not look like the same music)
constexpr double kQuietPower = 1e-6;
// bands more than 30 dB under the moment's loudest band count as equally empty: the faint noise
// in them must not decide bits
constexpr double kBandFloor = 1e-3;

void fft(std::vector<std::complex<double>>& a)
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
        const double angle = -2 * kPi / double(len);
        const std::complex<double> step(std::cos(angle), std::sin(angle));
        for (size_t i = 0; i < n; i += len)
        {
            std::complex<double> w(1);
            for (size_t k = 0; k < len / 2; ++k)
            {
                const std::complex<double> u = a[i + k];
                const std::complex<double> v = a[i + k + len / 2] * w;
                a[i + k] = u + v;
                a[i + k + len / 2] = u - v;
                w *= step;
            }
        }
    }
}

// a value with this few rising bands says too little to be matched (a held note, near silence)
constexpr int kMinSetBits = 4;
// two values are the same moment when most of the bands rising in either rise in both (the
// floor makes values sparse: plain bit errors would let any two sparse values match)
constexpr int kOverlapTenths = 7;

int setBits(uint32_t x)
{
    return int(std::bitset<32>(x).count());
}

bool same(uint32_t a, uint32_t b)
{
    if (setBits(a) < kMinSetBits || setBits(b) < kMinSetBits)
        return false;
    return setBits(a & b) * 10 >= setBits(a | b) * kOverlapTenths;
}

} // namespace

int bitErrors(uint32_t a, uint32_t b)
{
    return setBits(a ^ b);
}

AudioPrinter::AudioPrinter(unsigned sampleRate)
    : m_decimation(std::max(1u, unsigned(std::lround(double(std::max(1u, sampleRate)) / kWorkRate))))
    , m_rate(double(std::max(1u, sampleRate)) / m_decimation)
    , m_fftSize(kFftSize)
    , m_hop(std::max<size_t>(1, size_t(std::lround(m_rate / kPrintsPerSecond))))
    , m_ring(m_fftSize, 0.f)
    , m_window(m_fftSize)
    , m_bandEdges(kBands + 1)
    , m_prevEnergy(kBands, 0.0)
{
    for (size_t i = 0; i < m_fftSize; ++i)
        m_window[i] = float(0.5 - 0.5 * std::cos(2 * kPi * double(i) / double(m_fftSize - 1)));
    for (int k = 0; k <= kBands; ++k)
    {
        const double hz = kLowHz * std::pow(kHighHz / kLowHz, double(k) / kBands);
        m_bandEdges[size_t(k)] = std::clamp(int(std::lround(hz * double(m_fftSize) / m_rate)), 1,
                                            int(m_fftSize / 2 - 1));
    }
}

void AudioPrinter::push(const float* samples, size_t count)
{
    for (size_t i = 0; i < count; ++i)
    {
        // a simple average per kept sample (the decimation's low pass)
        m_accumulator += samples[i];
        if (++m_accumulated < m_decimation)
            continue;
        const float value = float(m_accumulator / m_accumulated);
        m_accumulator = 0;
        m_accumulated = 0;

        m_ring[m_writePos] = value;
        m_writePos = (m_writePos + 1) % m_fftSize;
        if (m_filled < m_fftSize)
            ++m_filled;
        if (++m_sinceHop >= m_hop && m_filled == m_fftSize)
        {
            m_sinceHop = 0;
            frame();
        }
    }
}

void AudioPrinter::skipTo(double seconds)
{
    const size_t wanted = size_t(std::max(0.0, seconds) * kPrintsPerSecond);
    while (m_prints.size() < wanted)
        m_prints.push_back(0);
    m_hasPrev = false;
}

void AudioPrinter::frame()
{
    std::vector<std::complex<double>> spectrum(m_fftSize);
    double power = 0;
    // the oldest sample is at the write position
    for (size_t i = 0; i < m_fftSize; ++i)
    {
        const float sample = m_ring[(m_writePos + i) % m_fftSize];
        power += double(sample) * sample;
        spectrum[i] = double(sample) * m_window[i];
    }
    power /= double(m_fftSize);
    fft(spectrum);

    std::vector<double> energy(kBands, 0.0);
    for (int k = 0; k < kBands; ++k)
    {
        for (int bin = m_bandEdges[size_t(k)]; bin < std::max(m_bandEdges[size_t(k) + 1], m_bandEdges[size_t(k)] + 1); ++bin)
            energy[size_t(k)] += std::norm(spectrum[size_t(bin)]);
    }

    const double loudest = *std::max_element(energy.begin(), energy.end());
    for (double& e : energy)
        e = std::log10(std::max(e, loudest * kBandFloor) + 1e-30);

    uint32_t print = 0;
    if (m_hasPrev && power >= kQuietPower)
    {
        for (int m = 0; m < kBands - 1; ++m)
        {
            const double now = energy[size_t(m)] - energy[size_t(m) + 1];
            const double before = m_prevEnergy[size_t(m)] - m_prevEnergy[size_t(m) + 1];
            if (now - before > 0)
                print |= 1u << m;
        }
        // all bits 0 is the value of silence: a real moment never takes it
        if (print == 0)
            print = 1;
    }
    m_prevEnergy = energy;
    m_hasPrev = true;
    m_prints.push_back(print);
}

Match longestMatch(const std::vector<uint32_t>& a, const std::vector<uint32_t>& b)
{
    Match best;
    const int na = int(a.size());
    const int nb = int(b.size());
    const int maxGap = int(kMaxGapSeconds * kPrintsPerSecond);
    const int minLength = kMinMatchSeconds * kPrintsPerSecond;
    // b's value j is compared with a's value j + shift
    for (int shift = -(nb - 1); shift < na; ++shift)
    {
        const int first = std::max(0, -shift);
        const int last = std::min(nb, na - shift);
        int runStart = -1;
        int lastHit = -1;
        for (int j = first; j <= last; ++j)
        {
            const bool hit = j < last && same(a[size_t(j + shift)], b[size_t(j)]);
            if (hit && runStart < 0)
                runStart = j;
            if (runStart >= 0 && (!hit && (j == last || j - lastHit > maxGap)))
            {
                const int length = lastHit - runStart + 1;
                if (length > best.length)
                {
                    best.length = length;
                    best.bStart = runStart;
                    best.aStart = runStart + shift;
                }
                runStart = hit ? j : -1;
            }
            if (hit)
                lastHit = j;
        }
    }
    best.found = best.length >= minLength;
    return best;
}

int findMusic(const std::vector<uint32_t>& haystack, const std::vector<uint32_t>& music)
{
    const int needle = std::min<int>(int(music.size()), kQuickMatchSeconds * kPrintsPerSecond);
    if (needle < kQuickMatchSeconds * kPrintsPerSecond / 2)
        return -1;
    int bestStart = -1;
    int bestHits = 0;
    for (int p = 0; p + needle <= int(haystack.size()); ++p)
    {
        int hits = 0;
        for (int i = 0; i < needle; ++i)
            hits += same(haystack[size_t(p + i)], music[size_t(i)]) ? 1 : 0;
        if (hits > bestHits)
        {
            bestHits = hits;
            bestStart = p;
        }
    }
    // a quarter of the music's first seconds the same: re-encoded credits music matches about
    // 40 % of its values at the right place (measured on AAC at 48 kb/s), other audio under 1 %
    return bestHits * 100 >= needle * kQuickHitPercent ? bestStart : -1;
}

} // namespace rdcredits
