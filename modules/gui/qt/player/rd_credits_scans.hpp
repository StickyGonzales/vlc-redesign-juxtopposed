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
#ifndef RD_CREDITS_SCANS_HPP
#define RD_CREDITS_SCANS_HPP

// redesign (Cone extra, Up Next, UP_NEXT_CREDITS_SCAN_NOTES.md section 5): the background
// credits scans of a show's episodes and what they found, per file and per show.
//
// - The first episodes of a show get a full scan of their last 8 minutes (audio fingerprint,
//   black frames, text subtitles); two of them with the same credits music give the show its
//   credits length (from the end) and the music's first minute.
// - A later episode whose length is within 5 minutes of the show's usual length gets a quick
//   check only: the kept music looked for 1 minute either side of where it is expected, audio
//   only. A miss, or an episode far from the usual length, gets the full scan.
// - One scan at a time on one low-priority thread, each file once (its result is cached by
//   path, size and time), paused while the seek bar is in use, none on Windows battery saver,
//   and stopped at once by shutdown() (the quit never waits for a scan).
// Kept in rd-shows.json ("creditsScan") by RdUpNext, which also decides what to scan.

#include <QDateTime>
#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QThreadPool>
#include <QVector>

#include <atomic>
#include <deque>
#include <memory>
#include <vector>

#include <vlc_common.h>

class RdCreditsScanner;

class RdCreditsScans : public QObject
{
    Q_OBJECT

public:
    // what the scans found in one episode, times from its start, -1 none
    struct Found
    {
        bool scanned = false;
        qint64 audioMs = -1;
        qint64 blackMs = -1;
        qint64 dialogueEndMs = -1;
    };

    RdCreditsScans(vlc_object_t* parent, QObject* parentObject = nullptr);
    ~RdCreditsScans() override;

    // queues `path`, an episode of the show `showKey` (its root folder, normalized), unless it
    // was scanned already; `slaves`: the subtitle files VLC loaded for it; `first`: the episode
    // playing, scanned before a next episode already waiting
    void request(const QString& showKey, const QString& showName, const QString& path,
                 const QStringList& slaves, bool first);
    Found found(const QString& path) const;

    // the time before the end the user fixed for a show, -1 when Automatic
    qint64 fixedLead(const QString& showKey) const;
    void setFixedLead(const QString& showKey, const QString& showName, qint64 leadMs);
    int fixedCount() const;
    QStringList fixedShows() const;

    // set while the seek bar is hovered or dragged: the read in progress waits
    void setPaused(bool paused);
    // stops at once: the scan in progress is cancelled, the queue dropped, nothing runs again
    void shutdown();
    // the queue goes and the scan in progress stops (Up Next switched off); the cache stays
    void stop();
    // Forget all: every show and file
    void clear();
    bool hasData() const;

    QJsonObject toJson() const;
    // `data`: as toJson() wrote it; what was set before (a Fixed point) wins. No scan starts
    // before this is called (with an empty object when there is no file)
    void load(const QJsonObject& data);

signals:
    // a scan of `path` finished with a result
    void resultReady(const QString& path);
    // something to write to rd-shows.json
    void changed();

private:
    struct FileInfo
    {
        QString path;
        QString showKey;
        qint64 lengthMs = -1;
        qint64 audioMs = -1;
        qint64 blackMs = -1;
        qint64 dialogueEndMs = -1;
        bool full = false;
        // the fingerprint of a full scan, kept until the show has its credits music
        std::vector<uint32_t> prints;
        qint64 printsFromMs = 0;
        qint64 seenAt = 0;
    };

    struct ShowInfo
    {
        QString name;
        qint64 creditsLeadMs = -1;
        std::vector<uint32_t> music;
        QVector<qint64> lengths;
        qint64 fixedLeadMs = -1;
    };

    struct Request
    {
        QString showKey;
        QString showName;
        QString path;
        QStringList slaves;
    };

    struct Outcome;
    struct OtherPrints;

    void startNext();
    static Outcome scan(RdCreditsScanner& scanner, const Request& request, const ShowInfo& show,
                        qint64 usual, const std::vector<OtherPrints>& others);
    void merge(const Request& request, const QString& fileKey, const Outcome& outcome);
    static QString fileKey(const QString& path);
    static qint64 usualLength(const ShowInfo& show);
    void prune();

    vlc_object_t* m_parent;
    QHash<QString, ShowInfo> m_shows;
    QHash<QString, FileInfo> m_files;
    std::deque<Request> m_queue;
    bool m_loaded = false;
    // stop() and clear() drop a result still on its way
    int m_generation = 0;
    // files whose scan failed for a reason that may not hold next time (not kept in the file)
    QSet<QString> m_skipped;
    bool m_running = false;
    bool m_shutdown = false;
    std::shared_ptr<std::atomic<bool>> m_paused;
    std::shared_ptr<RdCreditsScanner> m_current;
    QThreadPool m_pool;
};

#endif // RD_CREDITS_SCANS_HPP
