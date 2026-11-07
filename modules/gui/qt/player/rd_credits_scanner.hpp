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
#ifndef RD_CREDITS_SCANNER_HPP
#define RD_CREDITS_SCANNER_HPP

// redesign (Cone extra, Up Next, UP_NEXT_CREDITS_SCAN_NOTES.md section 6): one read of a stretch
// of an episode file in its own demuxer and decoders, never through the player: the audio
// becomes a fingerprint (rd_credits_audio), a few small samples of the picture a second tell how
// dark it is (black frames), and the packets of an embedded text subtitle track give its lines.
// Cancelled at once (VLC interrupt), paused while asked (the seek bar is in use), and VLC opens
// files without locking them (Windows: FILE_SHARE_DELETE), so an episode can be moved, renamed
// or deleted while it is read.

#include <QByteArray>
#include <QVector>

#include <atomic>
#include <functional>
#include <memory>
#include <vector>

#include <vlc_common.h>
#include <vlc_interrupt.h>

#include "player/rd_credits_point.hpp"

class RdCreditsScanner
{
public:
    // what to read, decided once the file's length is known
    struct Plan
    {
        // false: nothing to read (the file is too short, a quick check without music...)
        bool read = false;
        // from the start of the file; toMs at or past the length: to the end
        qint64 fromMs = 0;
        qint64 toMs = 0;
        bool frames = false;
        bool subtitles = false;
        // the longest the read may take
        int budgetSeconds = 120;
    };
    using Planner = std::function<Plan(qint64 lengthMs)>;

    struct Result
    {
        bool ok = false;
        const char* reason = "";
        // the reason may not hold next time (cancelled, over the time budget, a decoder failed)
        bool transient = false;
        qint64 lengthMs = 0;
        Plan plan;
        // fingerprint values from plan.fromMs, one each rdcredits::kPrintMs
        std::vector<uint32_t> prints;
        QVector<rdcredits::FrameSample> frames;
        // the lines of the first embedded text subtitle track inside the stretch
        QVector<rdcredits::Line> lines;
    };

    // `paused`: shared by all scans, set while the seek bar is in use
    RdCreditsScanner(vlc_object_t* parent, const QByteArray& mrl, std::shared_ptr<std::atomic<bool>> paused);
    ~RdCreditsScanner();

    RdCreditsScanner(const RdCreditsScanner&) = delete;
    RdCreditsScanner& operator=(const RdCreditsScanner&) = delete;

    // one read, planned once the length is known; may run again (a quick check, then the full
    // scan): a cancel() stops every run, the current one and the next
    Result run(const Planner& planner);
    void cancel();
    bool cancelled() const { return m_cancelled.load(std::memory_order_relaxed); }

    struct Scan;

private:
    friend struct Scan;

    vlc_object_t* m_parent;
    QByteArray m_mrl;
    std::shared_ptr<std::atomic<bool>> m_paused;
    vlc_interrupt_t* m_interrupt;
    std::atomic<bool> m_cancelled { false };
};

#endif // RD_CREDITS_SCANNER_HPP
