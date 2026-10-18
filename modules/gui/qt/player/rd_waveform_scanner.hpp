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
#ifndef RD_WAVEFORM_SCANNER_HPP
#define RD_WAVEFORM_SCANNER_HPP

#include <QByteArray>

#include <atomic>

#include <vlc_common.h>
#include <vlc_interrupt.h>

/**
 * redesign: the loudness profile of a file's audio, for the waveform seek bar (P6-06, IB-24).
 *
 * Opens the file a second time with VLC's own access, demuxer, packetizer and audio decoder
 * (the same modules playback uses, no audio output, no clock) and measures the loudness of
 * the first audio track over `kBins` equal slices of the file's duration.
 *
 * - A full scan decodes the file from start to end, as fast as the decoder goes, but it reads
 *   every byte of the file, video included. So it is only for files where that is quick: any
 *   file up to `kFullScanMaxBytes`, and a file without video (music: every byte read is audio
 *   the waveform needs) up to `kAudioFullScanMaxBytes`. Their waveform is exact.
 * - Other files (videos over `kFullScanMaxBytes`, long audio recordings) are sampled: one short
 *   stretch of audio is decoded in each slice, so a 50 GB file costs at most about `kBins`
 *   seeks, not a full read. A stretch is never longer than its slice. The stretches are read in
 *   order: the scan seeks to a stretch only when reading on to it would cost more than the
 *   seek (stretches that touch, in a file up to `kBins` x 0.25 s, are read once from the start),
 *   and the audio packets before a stretch (from the keyframe an MP4 seek lands on, or between
 *   two stretches) are dropped before the packetizer, undecoded, except a short decoder
 *   warm-up. A video track that only shows up while a full scan reads (MPEG-PS) moves a file
 *   over `kFullScanMaxBytes` to the sampled scan. A file to sample that the demuxer cannot seek
 *   in gets no waveform rather than a full read.
 *
 * run() blocks and is meant for a low priority worker thread. cancel() may be called from any
 * thread: run() then returns an empty array at its next packet or seek (the VLC interrupt
 * context of the run also ends waits that take one, such as a demuxer's dialog; file reads
 * are not interruptible on Windows, so a demuxer call in progress, its opening or a seek in
 * a file without an index, finishes first). The time budget `kTimeBudgetSeconds` is checked
 * at the same points: past it, the file gets no waveform.
 *
 * Result: `kBins` bytes, the RMS loudness of each slice scaled so the loudest slice is 255;
 * empty when the file has no decodable audio, no known duration, or the run was cancelled.
 */
class RdWaveformScanner
{
public:
    static constexpr int kBins = 1000;
    // the full scan's size limits: any file, and a file without video (WAVEFORM_NOTES section 2)
    static constexpr quint64 kFullScanMaxBytes = 32ull * 1024 * 1024;
    static constexpr quint64 kAudioFullScanMaxBytes = 256ull * 1024 * 1024;
    // the longest a run may take (a 256 MB audio file decodes in a few seconds)
    static constexpr int kTimeBudgetSeconds = 60;

    // `parent`: the VLC object the scan's objects hang from (the libvlc instance); `url`: a
    // file:// URL; `lengthHint`: the duration the player knows, used when the demuxer gives none
    RdWaveformScanner(vlc_object_t* parent, const QByteArray& url, vlc_tick_t lengthHint);
    ~RdWaveformScanner();

    RdWaveformScanner(const RdWaveformScanner&) = delete;
    RdWaveformScanner& operator=(const RdWaveformScanner&) = delete;

    QByteArray run();
    void cancel();
    bool cancelled() const { return m_cancelled.load(std::memory_order_relaxed); }

    struct Scan;

private:
    vlc_object_t* m_parent;
    QByteArray m_url;
    vlc_tick_t m_lengthHint;
    vlc_interrupt_t* m_interrupt;
    std::atomic<bool> m_cancelled { false };
};

#endif // RD_WAVEFORM_SCANNER_HPP
