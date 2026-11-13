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

// When the library's views refresh during a scan (redesign/PERF_AUDIT_NOTES.md): at most once a
// second, a single change still shown after 300 ms. No Qt.

#include "util/rd_reload_throttle.hpp"

#include <cstdio>
#include <vector>

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

// a view as RdLibraryModel drives it: a change starts the refresh timer unless one is waiting;
// the timer fires, the view refreshes. Returns the refresh times for changes at `events` (ms)
std::vector<int64_t> simulate(const std::vector<int64_t>& events, int64_t until)
{
    RdReloadThrottle throttle;
    std::vector<int64_t> reloads;
    int64_t pending = -1;
    size_t next = 0;
    for (int64_t now = 0; now <= until; ++now)
    {
        if (pending >= 0 && now >= pending)
        {
            reloads.push_back(now);
            throttle.reloaded(now);
            pending = -1;
        }
        while (next < events.size() && events[next] == now)
        {
            if (pending < 0)
                pending = now + throttle.delayFor(now);
            ++next;
        }
    }
    return reloads;
}

void testScan()
{
    // a scan: a change every 50 ms for 20 s
    std::vector<int64_t> events;
    for (int64_t t = 0; t < 20000; t += 50)
        events.push_back(t);
    const std::vector<int64_t> reloads = simulate(events, 22000);
    // the old fixed 300 ms delay refreshed about 60 times in these 20 s
    check(reloads.size() <= 21, "scan: at most one refresh a second");
    check(reloads.size() >= 15, "scan: the view still follows the scan (about once a second)");
    bool apart = true;
    for (size_t i = 1; i < reloads.size(); ++i)
        apart = apart && reloads[i] - reloads[i - 1] >= 1000;
    check(apart, "scan: refreshes at least 1 s apart");
    check(!reloads.empty() && reloads.back() >= 19950, "scan: the last change is shown");
}

void testSingleChange()
{
    const std::vector<int64_t> reloads = simulate({ 5000 }, 7000);
    check(reloads.size() == 1 && reloads[0] == 5300, "a single change: shown after 300 ms");
}

void testChangeRightAfterRefresh()
{
    // a refresh at 300 ms, then a change at 400 ms: waits until 1 s after that refresh
    const std::vector<int64_t> reloads = simulate({ 0, 400 }, 3000);
    check(reloads.size() == 2 && reloads[0] == 300 && reloads[1] == 1300,
          "a change right after a refresh: shown 1 s after it");
}

void testQuietThenChange()
{
    // long quiet: a later change is shown after the usual 300 ms
    const std::vector<int64_t> reloads = simulate({ 0, 10000 }, 12000);
    check(reloads.size() == 2 && reloads[1] == 10300, "after a quiet time: shown after 300 ms");
}

} // namespace

int main()
{
    testScan();
    testSingleChange();
    testChangeRightAfterRefresh();
    testQuietThenChange();
    std::printf("rd_reload_throttle: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
