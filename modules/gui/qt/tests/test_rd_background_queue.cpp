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

// Cone's background queue (redesign/STORAGE_CLEANUP_NOTES.md): one job at a time. QtCore only.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "util/rd_background_queue.hpp"

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QThread>

#include <atomic>
#include <cstdio>
#include <mutex>

namespace {

int checks = 0;
int failures = 0;

void check(bool ok, const char* what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::printf("FAIL: %s\n", what);
    }
}

bool waitUntil(const std::function<bool()>& done, int ms)
{
    QElapsedTimer clock;
    clock.start();
    while (!done() && clock.elapsed() < ms)
    {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
        QThread::msleep(2);
    }
    return done();
}

// a job that counts how many jobs are inside their work at once (beside the queue's own count)
struct Inside
{
    std::atomic<int> now{ 0 };
    std::atomic<int> most{ 0 };

    void enter()
    {
        const int n = ++now;
        int seen = most.load();
        while (n > seen && !most.compare_exchange_weak(seen, n))
        {
        }
    }
    void leave() { --now; }
};

void testOneAtATime()
{
    RdBackgroundQueue queue(nullptr, 0);
    Inside inside;
    std::atomic<int> ended{ 0 };
    for (int i = 0; i < 24; ++i)
    {
        const bool pausable = i % 3 == 0;
        queue.post(QStringLiteral("job %1").arg(i),
                   i % 2 ? RdBackgroundQueue::Weight::Heavy : RdBackgroundQueue::Weight::Light,
                   i % 4,
                   [&inside, &ended, pausable](const std::shared_ptr<RdBackgroundQueue::Control>& control) {
                       inside.enter();
                       for (int step = 0; step < 5; ++step)
                       {
                           QThread::msleep(2);
                           if (pausable)
                           {
                               inside.leave();
                               control->waitWhilePaused();
                               inside.enter();
                           }
                       }
                       inside.leave();
                       ++ended;
                   }, {}, pausable);
    }
    // urgent jobs arriving while the others run make long ones pause for them
    for (int i = 0; i < 6; ++i)
    {
        QThread::msleep(5);
        queue.post(QStringLiteral("urgent %1").arg(i), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent,
                   [&inside, &ended](const std::shared_ptr<RdBackgroundQueue::Control>&) {
                       inside.enter();
                       QThread::msleep(3);
                       inside.leave();
                       ++ended;
                   });
        QCoreApplication::processEvents();
    }
    check(waitUntil([&]() { return ended.load() == 30; }, 10000), "one at a time: every job ends");
    check(inside.most.load() == 1, "one at a time: never two jobs working at once");
    check(queue.maxActive() == 1, "one at a time: the queue's own count stays at 1");
}

void testPriorityOrder()
{
    RdBackgroundQueue queue(nullptr, 0);
    QStringList order;
    std::mutex lock;
    queue.hold(QStringLiteral("test"));
    auto job = [&order, &lock](const QString& name) {
        return [&order, &lock, name](const std::shared_ptr<RdBackgroundQueue::Control>&) {
            std::lock_guard<std::mutex> guard(lock);
            order.append(name);
        };
    };
    queue.post(QStringLiteral("low"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low, job(QStringLiteral("low")));
    queue.post(QStringLiteral("normal"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Normal, job(QStringLiteral("normal")));
    queue.post(QStringLiteral("urgent"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent, job(QStringLiteral("urgent")));
    queue.post(QStringLiteral("normal 2"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Normal, job(QStringLiteral("normal 2")));
    waitUntil([]() { return false; }, 50);
    check(order.isEmpty(), "priority: nothing runs while held");
    queue.release(QStringLiteral("test"));
    waitUntil([&]() { std::lock_guard<std::mutex> g(lock); return order.size() == 4; }, 3000);
    check(order == (QStringList{ QStringLiteral("urgent"), QStringLiteral("normal"), QStringLiteral("normal 2"), QStringLiteral("low") }),
          "priority: urgent first, then normal in order, then low");
}

void testStartupDelay()
{
    RdBackgroundQueue queue(nullptr, 400);
    QElapsedTimer clock;
    clock.start();
    std::atomic<qint64> light{ -1 }, heavy{ -1 };
    queue.post(QStringLiteral("heavy"), RdBackgroundQueue::Weight::Heavy, RdBackgroundQueue::Urgent,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>&) { heavy = clock.elapsed(); });
    queue.post(QStringLiteral("light"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>&) { light = clock.elapsed(); });
    waitUntil([&]() { return heavy.load() >= 0; }, 3000);
    check(light.load() >= 0 && light.load() < 300, "startup: a light job runs at once");
    check(heavy.load() >= 400, "startup: a heavy job waits for the first period");
}

void testHoldPauses()
{
    RdBackgroundQueue queue(nullptr, 0);
    std::atomic<int> steps{ 0 };
    std::atomic<bool> done{ false };
    queue.post(QStringLiteral("long"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>& control) {
                   for (int i = 0; i < 40 && control->waitWhilePaused(); ++i)
                   {
                       QThread::msleep(5);
                       ++steps;
                   }
                   done = true;
               }, {}, true);
    waitUntil([&]() { return steps.load() > 3; }, 2000);
    queue.hold(QStringLiteral("seek bar"));
    waitUntil([]() { return false; }, 60);
    const int at = steps.load();
    waitUntil([]() { return false; }, 200);
    check(steps.load() <= at + 1, "hold: a running job pauses while the user seeks");
    std::atomic<bool> other{ false };
    queue.post(QStringLiteral("other"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>&) { other = true; });
    waitUntil([]() { return false; }, 100);
    check(!other.load(), "hold: no job starts while held");
    queue.release(QStringLiteral("seek bar"));
    check(waitUntil([&]() { return done.load() && other.load(); }, 3000), "hold: both run after the release");

    // a hold that ends by itself
    queue.hold(QStringLiteral("opening"), 100);
    check(queue.held(), "hold: held");
    check(waitUntil([&]() { return !queue.held(); }, 1000), "hold: released by itself");
}

void testPreemption()
{
    RdBackgroundQueue queue(nullptr, 0);
    std::atomic<bool> longWorking{ false };
    std::atomic<bool> longEnded{ false };
    std::atomic<bool> urgentSawLongWorking{ true };
    std::atomic<bool> urgentEnded{ false };
    std::atomic<bool> urgentBeforeLong{ false };
    queue.post(QStringLiteral("credits scan"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>& control) {
                   for (int i = 0; i < 60; ++i)
                   {
                       longWorking = true;
                       QThread::msleep(5);
                       longWorking = false;
                       if (!control->waitWhilePaused())
                           break;
                   }
                   longEnded = true;
               }, {}, true);
    waitUntil([&]() { return longWorking.load(); }, 2000);
    queue.post(QStringLiteral("show detection"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>&) {
                   urgentSawLongWorking = longWorking.load();
                   QThread::msleep(10);
                   urgentSawLongWorking = urgentSawLongWorking.load() || longWorking.load();
                   urgentBeforeLong = !longEnded.load();
                   urgentEnded = true;
               });
    check(waitUntil([&]() { return urgentEnded.load() && longEnded.load(); }, 5000), "preemption: both end");
    check(urgentBeforeLong.load(), "preemption: the urgent job ran while the long one waited");
    check(!urgentSawLongWorking.load(), "preemption: the long job did not work meanwhile");
    check(queue.maxActive() == 1, "preemption: one at a time");
}

void testAsyncHoldsSlot()
{
    RdBackgroundQueue queue(nullptr, 0);
    std::atomic<bool> asyncDone{ false };
    std::atomic<bool> asyncStarted{ false };
    std::atomic<bool> laterRanAfter{ false };
    queue.postAsync(QStringLiteral("update check"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::High,
                    [&](const RdBackgroundQueue::Finish& finish) {
                        asyncStarted = true;
                        QTimer::singleShot(120, [&asyncDone, finish]() {
                            asyncDone = true;
                            finish();
                        });
                    });
    // posted once the request is on its way: an urgent job still waits for it
    waitUntil([&]() { return asyncStarted.load(); }, 2000);
    queue.post(QStringLiteral("later"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>&) { laterRanAfter = asyncDone.load(); });
    waitUntil([&]() { return queue.pending() == 0 && asyncDone.load(); }, 2000);
    waitUntil([]() { return false; }, 100);
    check(laterRanAfter.load(), "async: the next job waits until the request answered");

    // an async job that never answers frees the slot after its time
    std::atomic<bool> afterTimeout{ false };
    queue.postAsync(QStringLiteral("silent"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::High,
                    [](const RdBackgroundQueue::Finish&) {}, 150);
    queue.post(QStringLiteral("next"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
               [&](const std::shared_ptr<RdBackgroundQueue::Control>&) { afterTimeout = true; });
    check(waitUntil([&]() { return afterTimeout.load(); }, 2000), "async: a silent request times out");
}

void testShutdown()
{
    auto queue = std::make_unique<RdBackgroundQueue>(nullptr, 0);
    std::atomic<bool> started{ false };
    std::atomic<bool> doneCalled{ false };
    std::atomic<bool> laterRan{ false };
    queue->post(QStringLiteral("long"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
                [&](const std::shared_ptr<RdBackgroundQueue::Control>& control) {
                    started = true;
                    for (int i = 0; i < 1000 && !control->cancelled(); ++i)
                    {
                        QThread::msleep(5);
                        control->waitWhilePaused();
                    }
                }, [&]() { doneCalled = true; }, true);
    queue->post(QStringLiteral("later"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Low,
                [&](const std::shared_ptr<RdBackgroundQueue::Control>&) { laterRan = true; });
    waitUntil([&]() { return started.load(); }, 2000);
    queue->hold(QStringLiteral("seek bar"));
    waitUntil([]() { return false; }, 50);
    QElapsedTimer clock;
    clock.start();
    queue->shutdown();
    check(clock.elapsed() < 1000, "shutdown: stops at once, also a paused job");
    QCoreApplication::processEvents();
    check(!doneCalled.load() && !laterRan.load(), "shutdown: nothing after it");
    std::atomic<bool> afterShutdown{ false };
    queue->post(QStringLiteral("too late"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Urgent,
                [&](const std::shared_ptr<RdBackgroundQueue::Control>&) { afterShutdown = true; });
    waitUntil([]() { return false; }, 50);
    check(!afterShutdown.load(), "shutdown: a job posted after it never runs");
}

void testLog()
{
    RdBackgroundQueue queue(nullptr, 0);
    QStringList lines;
    std::mutex lock;
    queue.setLogger([&](const QString& line) {
        std::lock_guard<std::mutex> guard(lock);
        lines.append(line);
    });
    std::atomic<bool> done{ false };
    queue.post(QStringLiteral("waveform"), RdBackgroundQueue::Weight::Light, RdBackgroundQueue::Normal,
               [](const std::shared_ptr<RdBackgroundQueue::Control>&) {}, [&]() { done = true; });
    waitUntil([&]() { return done.load(); }, 2000);
    std::lock_guard<std::mutex> guard(lock);
    check(lines.size() >= 2 && lines.first().startsWith(QLatin1String("background: start waveform"))
          && lines.at(1).startsWith(QLatin1String("background: end waveform")), "log: start and end of each job");
}

} // namespace

int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    testOneAtATime();
    testPriorityOrder();
    testStartupDelay();
    testHoldPauses();
    testPreemption();
    testAsyncHoldsSlot();
    testShutdown();
    testLog();
    std::printf("rd_background_queue: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
