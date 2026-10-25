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
#ifndef RD_SUBTITLE_TIMELINE_HPP
#define RD_SUBTITLE_TIMELINE_HPP

#include <QByteArray>
#include <QObject>
#include <QThreadPool>
#include <QTimer>

#include <memory>
#include <vector>

#include "qt.hpp"

class PlayerController;

/**
 * redesign: the cue times of the selected subtitle track, for the subtitle timeline seek bar
 * (P3-16, IA-27, video 6:52-7:04; the Playback tab's "Show Subtitle Timeline on Seekbar",
 * P4-35).
 *
 * Only a track loaded from an external text file is known ahead of playback (drag and drop,
 * Add Subtitles, --sub-file, a file found next to the video): its file is read and its cue
 * times parsed (SubRip .srt, WebVTT, and the Dialogue lines of SSA / ASS). Embedded tracks are
 * only known as the demuxer reaches them, so they show no timeline.
 *
 * Nothing runs until a seek bar asks for it (acquire(), while the option is on); the file is
 * then parsed once on a worker thread, and again only when the selected track or the media
 * changes. The cue times are the file's own: the subtitle delay moves them on the bar.
 */
class RdSubtitleTimeline : public QObject
{
    Q_OBJECT

    // the cues of the selected external subtitle file are known
    Q_PROPERTY(bool ready READ ready NOTIFY cuesChanged FINAL)
    // the playing media's length in milliseconds (0: unknown), the timeline's scale
    Q_PROPERTY(qreal lengthMs READ lengthMs NOTIFY lengthMsChanged FINAL)

public:
    // one subtitle line on screen, in milliseconds of the file's own times
    struct Cue
    {
        qint64 start;
        qint64 end;
    };

    // files larger than this are not read (a text subtitle file is a few hundred KB)
    static constexpr qint64 kMaxFileSize = 32 * 1024 * 1024;

    RdSubtitleTimeline(qt_intf_t* intf, PlayerController* player, QObject* parent = nullptr);
    ~RdSubtitleTimeline() override;

    bool ready() const { return !m_cues.empty(); }
    qreal lengthMs() const { return m_lengthMs; }
    // sorted by start
    const std::vector<Cue>& cues() const { return m_cues; }

    // a seek bar shows the timeline (counted; the file is read while one is held)
    void acquire();
    void release();

    // the cues of a subtitle file's contents (exposed for the parser's checks)
    static std::vector<Cue> parse(const QByteArray& data);

signals:
    void cuesChanged();
    void lengthMsChanged();

private:
    friend class RdSubtitleTimelineJob;

    void scheduleUpdate();
    void updateTrack();
    void updateLength();
    void startParse();
    void setCues(std::vector<Cue> cues);
    void onParsed(int generation, std::vector<Cue> cues);

    qt_intf_t* m_intf;
    PlayerController* m_player;
    std::unique_ptr<QThreadPool> m_pool;

    int m_users = 0;
    // the selected track's file ("file://..."; empty: none or not listed yet)
    QByteArray m_uri;
    // the file whose cues m_cues holds or is being parsed
    QByteArray m_parsedUri;
    int m_generation = 0;
    bool m_updatePending = false;

    // an external track is selected before VLC lists its file on the media: look again a few
    // times
    QTimer m_retry;
    int m_retries = 0;

    std::vector<Cue> m_cues;
    qreal m_lengthMs = 0;
};

#endif // RD_SUBTITLE_TIMELINE_HPP
