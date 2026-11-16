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
#ifndef RD_UP_NEXT_MODE_HPP
#define RD_UP_NEXT_MODE_HPP

// Cone extra (Decision 71, redesign/UP_NEXT_PLAN.md 2.3): what Cone does when an episode of a show
// ends, the setting qt-autoplay-next ("When an episode ends"). No Qt, no VLC: unit-tested on its
// own (tests/test_rd_up_next_mode.cpp).
namespace rdupnext {

enum Mode : int
{
    ModeOff = 0,    // "Do nothing": no card, the episode ends as in VLC
    ModeOn = 1,     // "Play the next episode": the card counts down, then the next one plays
    ModeClick = 3,  // "Show Up Next, I'll click": the card waits for a click, nothing plays by itself
};

// the saved value of qt-autoplay-next. 0 and 1 are the old switch's Off and On (a bool is saved as
// 0 / 1), so a saved switch keeps its meaning; 2 was "Always" before 1.0 and plays on; click mode is
// 3, a value the option never had; anything else is the build's default
constexpr int modeFromOption(long long value, int fallback)
{
    switch (value)
    {
    case 0:
        return ModeOff;
    case 1:
    case 2:
        return ModeOn;
    case 3:
        return ModeClick;
    default:
        return fallback;
    }
}

// the next episode plays by itself only with "Play the next episode" and a clear episode name
// (S01E02, 1x02); a plain number or "Part 2" always waits for a click, as before
constexpr bool autoplays(int mode, bool strongName)
{
    return mode == ModeOn && strongName;
}

// the card's "Turn off autoplay": the countdown goes, the card stays and waits for a click
constexpr int afterTurnOff(int mode)
{
    return mode == ModeOn ? ModeClick : mode;
}

}

#endif // RD_UP_NEXT_MODE_HPP
