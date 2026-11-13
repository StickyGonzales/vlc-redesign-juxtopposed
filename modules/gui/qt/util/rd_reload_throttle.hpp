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
#ifndef RD_RELOAD_THROTTLE_HPP
#define RD_RELOAD_THROTTLE_HPP

// When a view refreshes after the media library changed (redesign/PERF_AUDIT_NOTES.md): a change
// is shown `delayMs` after it came (a burst of changes joins the refresh already waiting), and
// two refreshes are at least `minIntervalMs` apart, so a library scan sending changes all the
// time refreshes the home page at most once a second. Times in milliseconds on any clock that
// only goes forward; no Qt, unit-tested (tests/test_rd_reload_throttle.cpp)
#include <algorithm>
#include <cstdint>

class RdReloadThrottle
{
public:
    explicit RdReloadThrottle(int delayMs = 300, int minIntervalMs = 1000)
        : m_delayMs(delayMs), m_minIntervalMs(minIntervalMs) {}

    // a change came at `now`: how long to wait before the refresh
    int delayFor(int64_t now) const
    {
        if (m_last < 0)
            return m_delayMs;
        const int64_t earliest = m_last + m_minIntervalMs;
        return int(std::max<int64_t>(m_delayMs, earliest - now));
    }

    // the view refreshed at `now`
    void reloaded(int64_t now) { m_last = now; }

private:
    int m_delayMs;
    int m_minIntervalMs;
    int64_t m_last = -1;
};

#endif
