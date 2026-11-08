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
#ifndef RD_SYNC_SCANNER_HPP
#define RD_SYNC_SCANNER_HPP

// redesign (Cone build, redesign/SUBTITLE_AUTO_SYNC_NOTES.md section 4): one read of the played
// file, apart from playback, for the automatic subtitle sync: the loudness of one audio track
// per 20 ms frame (decoded, as the waveform scanner does) and the times of the lines of its
// embedded text subtitle tracks (their packets' timestamps, not decoded).

#include <QByteArray>

#include <atomic>
#include <map>
#include <vector>

#include <vlc_common.h>
#include <vlc_interrupt.h>

#include "player/rd_sync_math.hpp"

class RdSyncScanner
{
public:
    // the longest a read may take (an episode reads in a few seconds, a film in under a minute)
    static constexpr int kTimeBudgetSeconds = 240;

    struct Result
    {
        bool ok = false;
        // speech per frame (rdsync::detectSpeech), empty without audio
        std::vector<float> speech;
        // the lines of each embedded text subtitle track, by the demuxer's track id
        std::map<int, std::vector<rdsync::Cue>> cues;
        // why there is no result, for the log ("cancelled", "over the time budget", ...)
        const char* reason = "";
    };

    // `parent`: the VLC object the read hangs from; `url`: the played file; `audioId`: the
    // demuxer's id of the audio track to listen to (-1: the first one); `wantAudio`: decode
    // the audio (false: only the subtitle packets are collected)
    RdSyncScanner(vlc_object_t* parent, const QByteArray& url, int audioId, bool wantAudio);
    ~RdSyncScanner();

    RdSyncScanner(const RdSyncScanner&) = delete;
    RdSyncScanner& operator=(const RdSyncScanner&) = delete;

    Result run();
    void cancel();
    bool cancelled() const { return m_cancelled.load(std::memory_order_relaxed); }
    // 0 to 1, how far the read has come (any thread)
    float progress() const { return m_progress.load(std::memory_order_relaxed); }

    struct Scan;

private:
    friend struct Scan;

    vlc_object_t* m_parent;
    QByteArray m_url;
    int m_audioId;
    bool m_wantAudio;
    vlc_interrupt_t* m_interrupt;
    std::atomic<bool> m_cancelled { false };
    std::atomic<float> m_progress { 0.f };
};

#endif // RD_SYNC_SCANNER_HPP
