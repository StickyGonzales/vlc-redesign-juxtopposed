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
#ifndef RD_PROFILE_SETTINGS_HPP
#define RD_PROFILE_SETTINGS_HPP

#include <QStringList>
#include <QVariantMap>

#include <vlc_common.h>

/**
 * redesign (W8.2): the settings a profile holds (RdProfiles), read from and written to VLC's
 * configuration.
 *
 * The settings are every module's options (no passwords, not the first-run question nor the
 * audio outputs' last volume) whose value differs from VLC's default, by option name. The
 * option list is read once, on the first call (it walks every plugin). Both functions block
 * and are meant for a worker thread; VLC's configuration is thread safe.
 */
namespace RdProfileSettings
{

// the options that differ from VLC's defaults, as VLC has them now
QVariantMap capture();

struct ApplyResult
{
    // options changed that the input, decoders and outputs read when a media opens
    bool nextMedia = false;
    // options changed that are only read when VLC starts (interfaces, hotkeys, VLC's startup
    // and play queue options)
    QStringList restart;
};

// writes `target` (missing options: VLC's defaults) where VLC differs, and saves VLC's
// configuration; the interface's own live options are applied by the caller
ApplyResult write(libvlc_int_t* libvlc, const QVariantMap& target);

}

#endif // RD_PROFILE_SETTINGS_HPP
