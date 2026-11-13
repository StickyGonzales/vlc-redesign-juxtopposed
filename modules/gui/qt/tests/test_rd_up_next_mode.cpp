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

// "When an episode ends" (redesign/UP_NEXT_PLAN.md 2.3): the saved values, which episodes play by
// themselves in each mode, and the card's "Turn off autoplay". No Qt.

#include "player/rd_up_next_mode.hpp"

#include <cstdio>

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

}

int main()
{
    using namespace rdupnext;

    // saved values: the old switch keeps its meaning, the old "Always" plays on, click mode is 3
    check(modeFromOption(0, ModeOn) == ModeOff, "saved Off (0) is Do nothing");
    check(modeFromOption(1, ModeOff) == ModeOn, "saved On (1) is Play the next episode");
    check(modeFromOption(2, ModeOff) == ModeOn, "the old Always (2) is Play the next episode");
    check(modeFromOption(3, ModeOff) == ModeClick, "3 is Show Up Next, I'll click");
    check(modeFromOption(4, ModeOn) == ModeOn, "an unknown value is the build's default (Cone)");
    check(modeFromOption(-1, ModeOff) == ModeOff, "an unknown value is the build's default (vlc)");
    check(modeFromOption(1LL << 40, ModeOn) == ModeOn, "a huge value is the default");

    // which episodes play by themselves
    check(autoplays(ModeOn, true), "Play the next episode: S01E02 plays by itself");
    check(!autoplays(ModeOn, false), "Play the next episode: Part 2 waits for a click, as before");
    check(!autoplays(ModeClick, true), "click mode: S01E02 waits for a click");
    check(!autoplays(ModeClick, false), "click mode: Part 2 waits for a click");
    check(!autoplays(ModeOff, true), "Do nothing: nothing plays");
    check(!autoplays(ModeOff, false), "Do nothing: nothing plays (weak name)");

    // the card's link: from counting to waiting; nothing else changes
    check(afterTurnOff(ModeOn) == ModeClick, "Turn off autoplay switches to click mode");
    check(afterTurnOff(ModeClick) == ModeClick, "Turn off autoplay in click mode changes nothing");
    check(afterTurnOff(ModeOff) == ModeOff, "Turn off autoplay never turns Up Next on");

    // the values the settings list offers are the modes themselves
    check(modeFromOption(ModeOn, ModeOff) == ModeOn && modeFromOption(ModeClick, ModeOff) == ModeClick
              && modeFromOption(ModeOff, ModeOn) == ModeOff, "every listed value reads back as itself");

    std::printf("test_rd_up_next_mode: %d checks, %d failures\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
