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
#include "rd_background_queue.hpp"

#include <QPointer>
#include <QThread>

#include <chrono>

namespace {

RdBackgroundQueue* g_instance = nullptr;

// the jobs actually running (a job paused at its gate is not)
struct Counters
{
    std::atomic<int>* active;
    std::atomic<int>* maxActive;

    void enter() const
    {
        const int now = ++*active;
        int seen = maxActive->load();
        while (now > seen && !maxActive->compare_exchange_weak(seen, now))
        {
        }
    }
    void leave() const { --*active; }
};

thread_local Counters* t_counters = nullptr;

} // namespace

bool RdBackgroundQueue::Control::waitWhilePaused(const std::function<bool()>& stop)
{
    if (!m_paused.load() || m_cancelled.load())
        return !m_cancelled.load();

    // stopped at the gate: another job may run meanwhile
    if (t_counters)
        t_counters->leave();
    m_parked.store(true);
    if (m_onParked)
        m_onParked();
    {
        std::unique_lock<std::mutex> lock(m_mutex);
        while (m_paused.load() && !m_cancelled.load() && !(stop && stop()))
            m_wake.wait_for(lock, std::chrono::milliseconds(100));
    }
    m_parked.store(false);
    if (t_counters)
        t_counters->enter();
    return !m_cancelled.load();
}

void RdBackgroundQueue::Control::setPaused(bool paused)
{
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_paused.store(paused);
    }
    if (!paused)
        m_wake.notify_all();
}

void RdBackgroundQueue::Control::setCancelHook(std::function<void()> hook)
{
    bool now = false;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_cancelHook = std::move(hook);
        now = m_cancelled.load();
    }
    if (now && m_cancelHook)
        m_cancelHook();
}

void RdBackgroundQueue::Control::cancel()
{
    std::function<void()> hook;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_cancelled.exchange(true))
            return;
        hook = m_cancelHook;
    }
    m_wake.notify_all();
    if (hook)
        hook();
}

RdBackgroundQueue::RdBackgroundQueue(QObject* parent, int startupDelayMs)
    : QObject(parent)
    , m_startupDelayMs(startupDelayMs)
{
    m_age.start();
    // one job runs; the others started are paused at their gate (a long job paused for a short
    // one): a few threads, never more than one of them busy
    m_pool.setMaxThreadCount(4);
    m_pool.setExpiryTimeout(5000);
    m_startupTimer.setSingleShot(true);
    connect(&m_startupTimer, &QTimer::timeout, this, &RdBackgroundQueue::schedule);
}

RdBackgroundQueue::~RdBackgroundQueue()
{
    shutdown();
    if (g_instance == this)
        g_instance = nullptr;
}

RdBackgroundQueue* RdBackgroundQueue::instance()
{
    return g_instance;
}

void RdBackgroundQueue::setInstance(RdBackgroundQueue* queue)
{
    g_instance = queue;
}

std::shared_ptr<RdBackgroundQueue::Control> RdBackgroundQueue::makeControl()
{
    auto control = std::make_shared<Control>();
    QPointer<RdBackgroundQueue> self(this);
    control->m_onParked = [self]() {
        QMetaObject::invokeMethod(self.data(), [self]() {
            if (self)
                self->schedule();
        }, Qt::QueuedConnection);
    };
    return control;
}

quint64 RdBackgroundQueue::post(const QString& name, Weight weight, int priority, Work work, Done done,
                                bool pausable)
{
    auto job = std::make_shared<Job>();
    job->id = m_nextId++;
    job->name = name;
    job->weight = weight;
    job->priority = priority;
    job->pausable = pausable;
    job->work = std::move(work);
    job->done = std::move(done);
    job->control = makeControl();
    if (m_shutdown)
    {
        job->control->cancel();
        return job->id;
    }
    m_pending.push_back(job);
    QMetaObject::invokeMethod(this, &RdBackgroundQueue::schedule, Qt::QueuedConnection);
    return job->id;
}

quint64 RdBackgroundQueue::postAsync(const QString& name, Weight weight, int priority, AsyncStart start,
                                     int timeoutMs)
{
    auto job = std::make_shared<Job>();
    job->id = m_nextId++;
    job->name = name;
    job->weight = weight;
    job->priority = priority;
    job->start = std::move(start);
    job->timeoutMs = timeoutMs;
    job->control = makeControl();
    if (m_shutdown)
    {
        job->control->cancel();
        return job->id;
    }
    m_pending.push_back(job);
    QMetaObject::invokeMethod(this, &RdBackgroundQueue::schedule, Qt::QueuedConnection);
    return job->id;
}

std::shared_ptr<RdBackgroundQueue::Control> RdBackgroundQueue::control(quint64 id) const
{
    if (const auto running = m_running.value(id))
        return running->control;
    for (const auto& job : m_pending)
        if (job->id == id)
            return job->control;
    return nullptr;
}

void RdBackgroundQueue::cancel(quint64 id)
{
    for (auto it = m_pending.begin(); it != m_pending.end(); ++it)
    {
        if ((*it)->id != id)
            continue;
        const std::shared_ptr<Job> job = *it;
        job->control->cancel();
        log(QStringLiteral("dropped %1 (#%2)").arg(job->name).arg(id));
        m_pending.erase(it);
        // its owner learns it is over (it may wait for it), as after a running job's cancel
        if (job->done)
            QMetaObject::invokeMethod(this, [this, job]() {
                if (!m_shutdown)
                    job->done();
            }, Qt::QueuedConnection);
        return;
    }
    if (const auto running = m_running.value(id))
        running->control->cancel();
}

void RdBackgroundQueue::hold(const QString& reason, int autoReleaseMs)
{
    if (m_shutdown)
        return;
    const bool first = m_holds.isEmpty();
    m_holds.insert(reason, true);
    if (autoReleaseMs > 0)
    {
        QTimer*& timer = m_holdTimers[reason];
        if (!timer)
        {
            timer = new QTimer(this);
            timer->setSingleShot(true);
            connect(timer, &QTimer::timeout, this, [this, reason]() { release(reason); });
        }
        timer->start(autoReleaseMs);
    }
    if (first)
        log(QStringLiteral("paused (%1)").arg(reason));
    updatePauses();
}

void RdBackgroundQueue::release(const QString& reason)
{
    if (m_holds.remove(reason) == 0)
        return;
    if (QTimer* timer = m_holdTimers.value(reason))
        timer->stop();
    if (m_holds.isEmpty())
    {
        log(QStringLiteral("resumed (%1)").arg(reason));
        schedule();
    }
}

void RdBackgroundQueue::shutdown()
{
    if (m_shutdown)
        return;
    m_shutdown = true;
    m_startupTimer.stop();
    for (const auto& job : m_pending)
        job->control->cancel();
    m_pending.clear();
    for (const auto& job : m_running)
        job->control->cancel();
    // a job stops at its next check (its own code cancels what it waits on): joined here, so
    // nothing runs after the interface is gone
    m_pool.waitForDone();
    m_running.clear();
}

void RdBackgroundQueue::log(const QString& text)
{
    if (m_logger)
        m_logger(QStringLiteral("background: ") + text);
}

void RdBackgroundQueue::updatePauses()
{
    if (m_holds.isEmpty())
        return;
    for (const auto& job : m_running)
        if (job->pausable && !job->control->paused())
            job->control->setPaused(true);
}

std::shared_ptr<RdBackgroundQueue::Job> RdBackgroundQueue::nextJob(bool* waitStartup)
{
    *waitStartup = false;
    const bool early = m_age.elapsed() < m_startupDelayMs;
    std::shared_ptr<Job> best;
    for (const auto& job : m_pending)
    {
        if (early && job->weight == Weight::Heavy)
        {
            *waitStartup = true;
            continue;
        }
        if (!best || job->priority < best->priority)
            best = job;
    }
    return best;
}

void RdBackgroundQueue::schedule()
{
    if (m_shutdown)
        return;
    updatePauses();

    bool waitStartup = false;
    const std::shared_ptr<Job> next = nextJob(&waitStartup);
    if (waitStartup && !m_startupTimer.isActive())
        m_startupTimer.start(std::max<qint64>(0, m_startupDelayMs - m_age.elapsed()) + 1);
    // held: only an urgent light job starts (show detection for the file opening)
    const bool held = !m_holds.isEmpty();
    if (held && !(next && next->weight == Weight::Light && next->priority == Urgent))
        return;

    // the job running now (one asked to pause counts until it stopped at its gate); an async
    // job waiting for its answer holds the slot against jobs of its priority or lower only
    std::shared_ptr<Job> active;
    std::shared_ptr<Job> parked;
    for (const auto& job : m_running)
    {
        if (job->control->paused() && job->control->m_parked.load())
        {
            if (!parked || job->priority < parked->priority
                || (job->priority == parked->priority && job->id < parked->id))
                parked = job;
        }
        else if (job->start && next && next->priority < job->priority)
            continue;
        else
            active = job;
    }

    if (active)
    {
        // a more urgent job pauses a long one that can pause; it starts once that one stopped
        if (next && active->pausable && next->priority < active->priority && !active->control->paused())
        {
            log(QStringLiteral("%1 (#%2) pauses for %3").arg(active->name).arg(active->id).arg(next->name));
            active->control->setPaused(true);
            // resumed a moment ago and not awake yet: it is still at its gate, no signal comes
            if (active->control->m_parked.load())
                QMetaObject::invokeMethod(this, &RdBackgroundQueue::schedule, Qt::QueuedConnection);
        }
        return;
    }
    if (held && parked)
        parked.reset();

    if (parked && (!next || parked->priority <= next->priority))
    {
        log(QStringLiteral("%1 (#%2) goes on").arg(parked->name).arg(parked->id));
        parked->control->setPaused(false);
        return;
    }
    if (!next)
        return;
    for (auto it = m_pending.begin(); it != m_pending.end(); ++it)
    {
        if (*it == next)
        {
            m_pending.erase(it);
            break;
        }
    }
    startJob(next);
}

void RdBackgroundQueue::startJob(const std::shared_ptr<Job>& job)
{
    m_running.insert(job->id, job);
    job->clock.start();
    log(QStringLiteral("start %1 (#%2)").arg(job->name).arg(job->id));
    emit jobStarted(job->name);

    const quint64 id = job->id;
    if (job->start)
    {
        // an async job takes the slot until it says it is done (or its time is up); it does its
        // work elsewhere (a request, a thumbnailer), so it is not counted as running here
        QPointer<RdBackgroundQueue> self(this);
        auto finished = std::make_shared<std::atomic<bool>>(false);
        Finish finish = [self, id, finished]() {
            if (finished->exchange(true))
                return;
            QMetaObject::invokeMethod(self.data(), [self, id]() {
                if (self)
                    self->finished(id);
            }, Qt::QueuedConnection);
        };
        if (job->timeoutMs > 0)
            QTimer::singleShot(job->timeoutMs, this, [this, id, finish]() {
                if (m_running.contains(id))
                    log(QStringLiteral("#%1 did not answer in time").arg(id));
                finish();
            });
        job->start(finish);
        return;
    }

    QPointer<RdBackgroundQueue> self(this);
    std::shared_ptr<Control> control = job->control;
    Work work = job->work;
    const std::shared_ptr<Counts> counts = m_counts;
    m_pool.start([self, id, control, work, counts]() {
        // background work never takes time from playback
        QThread::currentThread()->setPriority(QThread::LowestPriority);
        Counters counters{ &counts->active, &counts->max };
        t_counters = &counters;
        counters.enter();
        if (!control->cancelled())
            work(control);
        counters.leave();
        t_counters = nullptr;
        QMetaObject::invokeMethod(self.data(), [self, id]() {
            if (self)
                self->finished(id);
        }, Qt::QueuedConnection);
    });
}

void RdBackgroundQueue::finished(quint64 id)
{
    const std::shared_ptr<Job> job = m_running.take(id);
    if (!job)
        return;
    const bool cancelled = job->control->cancelled();
    log(QStringLiteral("end %1 (#%2, %3 ms%4)").arg(job->name).arg(id).arg(job->clock.elapsed())
            .arg(cancelled ? QStringLiteral(", cancelled") : QString()));
    if (!m_shutdown && job->done)
        job->done();
    emit jobEnded(job->name);
    schedule();
}
