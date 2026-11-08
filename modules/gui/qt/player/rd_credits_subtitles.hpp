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

#ifndef RD_CREDITS_SUBTITLES_HPP
#define RD_CREDITS_SUBTITLES_HPP

#include <QByteArray>
#include <QString>
#include <QStringList>
#include <QVector>

#include <atomic>

#include <vlc_common.h>

#include "player/rd_credits_point.hpp"

/**
 * Cone extra (Up Next, UP_NEXT_PLAN.md 5.4): the text subtitle lines of an episode's credits
 * window, which may fine-tune where the credits start (rd_credits_point).
 *
 * - An external text file first: the subtitle files VLC loaded for the episode (its slaves)
 *   and the SubRip, ASS/SSA and WebVTT files next to it whose name starts with the episode's
 *   name, as VLC's own subtitle autodetection finds them. The first one with lines wins.
 * - Otherwise an embedded text track (SubRip, ASS, tx3g): the file is opened a second time with
 *   VLC's demuxer, which seeks to the credits window and hands over the packets of the first
 *   text track only (no decoder, no video read where the demuxer can skip it).
 * Picture subtitles (PGS, VobSub, DVB) are never read. Nothing looks at the picture.
 *
 * run() blocks and is meant for a worker thread; cancel() may be called from any thread and
 * run() returns at its next packet. The time budget is checked at the same points.
 */
class RdCreditsSubtitles
{
public:
    static constexpr int kTimeBudgetSeconds = 20;

    // `parent`: the VLC object the scan hangs from; `path`: the episode's local file; `mrl`: its
    // MRL; `slaves`: the subtitle files VLC loaded for it (local paths); `lengthMs`: its length
    RdCreditsSubtitles(vlc_object_t* parent, const QString& path, const QByteArray& mrl,
                       const QStringList& slaves, qint64 lengthMs);

    RdCreditsSubtitles(const RdCreditsSubtitles&) = delete;
    RdCreditsSubtitles& operator=(const RdCreditsSubtitles&) = delete;

    QVector<rdcredits::Line> run();
    void cancel() { m_cancelled.store(true, std::memory_order_relaxed); }
    bool cancelled() const { return m_cancelled.load(std::memory_order_relaxed); }

    // where the lines came from, for the log: "file <name>", "embedded", "none"
    QString origin() const { return m_origin; }

    // the external subtitle files of `path`: `slaves` first, then the files next to it
    static QStringList externalFiles(const QString& path, const QStringList& slaves);

private:
    QVector<rdcredits::Line> fromFiles();
    QVector<rdcredits::Line> fromEmbedded();

    vlc_object_t* m_parent;
    QString m_path;
    QByteArray m_mrl;
    QStringList m_slaves;
    qint64 m_lengthMs;
    QString m_origin;
    std::atomic<bool> m_cancelled { false };
};

#endif
