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

#ifndef RD_STEREO_TEST_HPP
#define RD_STEREO_TEST_HPP

#include <QString>
#include <QTemporaryDir>

#include "qt.hpp"

extern "C" {
    typedef struct vlc_player_t vlc_player_t;
}

/**
 * redesign: the "Test" button next to Stereo Mode in the settings sidebar's Audio tab (video
 * 8:41, Figma "audio settings" 2250:9842). VLC has no test sound: this plays a short generated
 * one, a tone on the left channel then on the right, so the user hears which speaker plays
 * what. The stereo mode chosen for the playing file (Mono, Left, Right, Reverse stereo) is
 * applied to the tone, so the test sounds like the mode does.
 *
 * The tone plays on its own player (the playing file is not interrupted), on the device of the
 * player's audio output, without the audio effects, visualization or speed of the playing file.
 * The sound files are written once per stereo mode into a temporary folder removed on exit.
 */
class RdStereoTest
{
public:
    // parent: the VLC object the test player is created under (the main player)
    explicit RdStereoTest(vlc_object_t *parent);
    ~RdStereoTest();

    RdStereoTest(const RdStereoTest &) = delete;
    RdStereoTest &operator=(const RdStereoTest &) = delete;

    // plays the test sound with `stereoMode` (AOUT_VAR_CHAN_*) on `device` (an audio output
    // device id, "" or null for the default one); a test still playing starts again. `volume`
    // is the playing file's (0 to 2, negative when unknown), for outputs without a session
    void play(int stereoMode, const char *device, float volume);

private:
    bool createPlayer(float volume);
    // the test sound for a stereo mode (written on first use); empty on failure
    QString soundFile(int stereoMode);

    vlc_object_t *m_parent = nullptr;
    // holds the variables the test player inherits instead of the main player's
    vlc_object_t *m_object = nullptr;
    vlc_player_t *m_player = nullptr;
    QTemporaryDir m_dir;
};

#endif // RD_STEREO_TEST_HPP
