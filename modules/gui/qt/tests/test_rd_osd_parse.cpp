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

// redesign: Cone's on-screen messages, the core's texts sorted into icon / name / value
// (player/rd_osd_parse.cpp). QtCore only; the texts untranslated.

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "player/rd_osd_parse.hpp"

#include <cstdio>

using namespace rdosd;

namespace {

int checks = 0;
int failures = 0;

void check(const Message& m, const char* icon, const char* label, const char* value, const char* what)
{
    ++checks;
    if (m.icon != QString::fromUtf8(icon) || m.label != QString::fromUtf8(label)
            || m.value != QString::fromUtf8(value))
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s: got %s | %s | %s\n", what, qPrintable(m.icon),
                     qPrintable(m.label), qPrintable(m.value));
    }
}

void checkTrue(bool ok, const char* what)
{
    ++checks;
    if (!ok)
    {
        ++failures;
        std::fprintf(stderr, "FAIL: %s\n", what);
    }
}

} // namespace

int main()
{
    const Parser p([](const char* text) { return QString::fromUtf8(text); });
    const auto s = [](const char* t) { return QString::fromUtf8(t); };

    const Message vol = p.message(s("Volume: 80%"));
    check(vol, "volume_value-high", "Volume", "80%", "volume");
    checkTrue(qAbs(vol.level - 0.8) < 1e-9 && !vol.muted, "volume level");
    checkTrue(qAbs(p.message(s("Volume: 200%")).level - 2.0) < 1e-9, "volume 200 %");
    const Message muted = p.message(s("Muted"));
    check(muted, "volume_value-muted", "Muted", "", "muted");
    checkTrue(muted.muted && muted.level == 0, "muted level");
    check(p.message(s("Speed: 1.50x")), "speed", "Speed", "1.5×", "speed");
    check(p.message(s("Speed: 2.00x")), "speed", "Speed", "2×", "speed 2");
    check(p.message(s("Audio delay: 50 ms")), "audio", "Audio delay", "+50 ms", "audio delay");
    check(p.message(s("Subtitle delay: -250 ms")), "subtitles", "Subtitle delay", "-250 ms", "subtitle delay");
    check(p.message(s("Audio track: English")), "audio", "Audio", "English", "audio track");
    check(p.message(s("Subtitle track: English")), "subtitles", "Subtitles", "English", "subtitle track");
    check(p.message(s("Subtitle track: N/A")), "subtitles", "Subtitles", "Off", "subtitles off");
    check(p.message(s("Subtitle tracks: English, Hindi")), "subtitles", "Subtitles", "English, Hindi", "two subtitle tracks");
    check(p.message(s("Video track: Track 2")), "video", "Video track", "Track 2", "video track");
    check(p.message(s("Aspect ratio: 16:9")), "window", "Aspect ratio", "16:9", "aspect ratio");
    check(p.message(s("Crop: 2.35:1")), "window", "Crop", "2.35:1", "crop");
    check(p.message(s("Top crop: 12 px")), "window", "Top crop", "12 px", "top crop");
    check(p.message(s("Zoom: x1.10")), "view", "Zoom", "×1.1", "zoom");
    check(p.message(s("Zoom mode: 2:1 Double")), "view", "Zoom", "2:1 Double", "zoom mode");
    check(p.message(s("Zooming reset")), "view", "Zoom reset", "", "zoom reset");
    check(p.message(s("Random: On")), "shuffle_direction-right", "Shuffle", "On", "random");
    check(p.message(s("Loop: All")), "repeat_direction-right", "Loop", "All", "loop");
    check(p.message(s("Deinterlace On (yadif)")), "eye", "Deinterlace", "On (yadif)", "deinterlace");
    check(p.message(s("Chapter 0")), "chapters", "Chapter", "1", "chapters count from 1");
    check(p.message(s("Next chapter")), "chapters", "Next chapter", "", "next chapter");
    check(p.message(s("Next")), "next", "Next", "", "next");
    check(p.message(s("Previous")), "previous", "Previous", "", "previous");
    check(p.message(s("00:12:40 / 00:42:10")), "playback", "00:12:40", "/ 00:42:10", "time");
    check(p.message(s("Sub sync: delay reset")), "subtitles", "Sub sync", "Delay reset", "sub sync");
    check(p.message(s("Subtitle position 40 px")), "subtitles", "Subtitle position", "40 px", "sub position");
    check(p.message(s("Recording")), "record", "Recording", "", "recording");
    check(p.message(s("Something new")), "info", "Something new", "", "unknown text");
    check(p.icon(s("pause")), "pause", "Paused", "", "pause icon");
    check(p.icon(s("play")), "play", "Playing", "", "play icon");
    checkTrue(Parser::keyText(s("Ctrl+Up")) == s("Ctrl + ↑"), "key Ctrl+Up");
    checkTrue(Parser::keyText(s("m")) == s("M"), "key m");
    checkTrue(Parser::keyText(s("Shift+Right")) == s("Shift + →"), "key Shift+Right");

    std::printf("rd_osd_parse: %d checks, %d failed\n", checks, failures);
    return failures == 0 ? 0 : 1;
}
