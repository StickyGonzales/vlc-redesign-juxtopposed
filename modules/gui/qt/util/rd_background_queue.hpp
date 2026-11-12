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
#ifndef RD_BACKGROUND_QUEUE_HPP
#define RD_BACKGROUND_QUEUE_HPP

// Cone's one queue for background work (redesign/STORAGE_CLEANUP_NOTES.md): show detection,
// fingerprint matching, credits scans, waveforms, Up Next pictures, the update check and the
// storage cleanup run one at a time, at low priority, instead of in parallel.
// - one job at a time: a long job that can pause (a credits scan, a waveform) pauses when a more
//   urgent one comes (show detection) and goes on after it; nothing else ever runs beside it
// - nothing heavy in the first minute after Cone opens (light jobs may: the update check is one
//   small request, show detection one folder listing)
// - paused while the user seeks, hovers or drags the seek bar, or opens a file (hold())
// - stopped at once on quit (shutdown())
// - each job's start and end go to the debug log
// QtCore only (tests/test_rd_background_queue.cpp).
#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QString>
#include <QThreadPool>
#include <QTimer>

#include <atomic>
#include <condition_variable>
#include <deque>
#include <functional>
#include <memory>
#include <mutex>

class RdBackgroundQueue : public QObject
{
    Q_OBJECT

public:
    // heavy: reads files or decodes (not in the first minute); light: a folder listing or a
    // small request
    enum class Weight { Light, Heavy };
    // lower runs first; a job waits for the ones before it of the same priority
    enum Priority { Urgent = 0, High = 1, Normal = 2, Low = 3 };

    static constexpr int kStartupDelayMs = 60000;

    // what a job running on the queue's thread sees: whether it is cancelled, and a gate it
    // passes now and then, where it waits while the queue is paused
    class Control
    {
    public:
        bool cancelled() const { return m_cancelled.load(); }
        // waits while paused; `stop` (checked every 100 ms) ends the wait early, like a
        // cancellation; false when cancelled
        bool waitWhilePaused(const std::function<bool()>& stop = {});
        bool paused() const { return m_paused.load(); }
        // what stops the job's own waits at once (a scanner's interrupt), called on cancel
        void setCancelHook(std::function<void()> hook);

    private:
        friend class RdBackgroundQueue;
        void setPaused(bool paused);
        void cancel();

        std::mutex m_mutex;
        std::condition_variable m_wake;
        std::atomic<bool> m_paused{ false };
        std::atomic<bool> m_cancelled{ false };
        std::atomic<bool> m_parked{ false };
        // the queue is told when the job stops at its gate (another job may then run)
        std::function<void()> m_onParked;
        std::function<void()> m_cancelHook;
    };

    using Work = std::function<void(const std::shared_ptr<Control>&)>;
    using Done = std::function<void()>;
    // an async job (a request answered later): started on the queue's thread, it calls finish
    // when it is done; the queue's slot stays taken until then (or the timeout)
    using Finish = std::function<void()>;
    using AsyncStart = std::function<void(const Finish& finish)>;

    explicit RdBackgroundQueue(QObject* parent = nullptr, int startupDelayMs = kStartupDelayMs);
    ~RdBackgroundQueue() override;

    // the interface's queue (set while it exists)
    static RdBackgroundQueue* instance();
    static void setInstance(RdBackgroundQueue* queue);

    // a job run on the queue's thread; `done` on this object's thread afterwards, also after a
    // cancel (the job's control tells), never after shutdown(). `pausable`: it passes
    // Control::waitWhilePaused() often
    quint64 post(const QString& name, Weight weight, int priority, Work work, Done done = {},
                 bool pausable = false);
    quint64 postAsync(const QString& name, Weight weight, int priority, AsyncStart start,
                      int timeoutMs = 60000);
    // the control of a job (waiting or running), for code that hands it to a scanner
    std::shared_ptr<Control> control(quint64 id) const;
    // a waiting job is dropped; a running one is told to stop (its own code stops it)
    void cancel(quint64 id);

    // the user is busy (seeking, the seek bar, a file opening): no job starts, a running one
    // pauses at its gate; `autoReleaseMs` > 0 ends the hold by itself
    void hold(const QString& reason, int autoReleaseMs = 0);
    void release(const QString& reason);
    bool held() const { return !m_holds.isEmpty(); }

    // stops everything at once and waits for the queue's threads
    void shutdown();

    void setLogger(std::function<void(const QString&)> logger) { m_logger = std::move(logger); }

    // tests: the most jobs that ever ran at once (not counting one paused at its gate)
    int maxActive() const { return m_maxActive.load(); }
    int pending() const { return int(m_pending.size()); }

signals:
    void jobStarted(const QString& name);
    void jobEnded(const QString& name);

private:
    struct Job
    {
        quint64 id = 0;
        QString name;
        Weight weight = Weight::Light;
        int priority = Normal;
        bool pausable = false;
        Work work;
        Done done;
        AsyncStart start;
        int timeoutMs = 0;
        std::shared_ptr<Control> control;
        QElapsedTimer clock;
    };

    void schedule();
    void startJob(const std::shared_ptr<Job>& job);
    void finished(quint64 id);
    void updatePauses();
    std::shared_ptr<Job> nextJob(bool* waitStartup);
    void log(const QString& text);
    std::shared_ptr<Control> makeControl();

    std::deque<std::shared_ptr<Job>> m_pending;
    // the jobs started and not finished: one active, the others paused at their gate
    QHash<quint64, std::shared_ptr<Job>> m_running;
    QHash<QString, bool> m_holds;
    QHash<QString, QTimer*> m_holdTimers;
    QThreadPool m_pool;
    QTimer m_startupTimer;
    QElapsedTimer m_age;
    int m_startupDelayMs;
    quint64 m_nextId = 1;
    bool m_shutdown = false;
    std::function<void(const QString&)> m_logger;
    std::atomic<int> m_active{ 0 };
    std::atomic<int> m_maxActive{ 0 };
};

#endif
