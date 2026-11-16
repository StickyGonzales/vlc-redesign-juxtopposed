/*****************************************************************************
 * ytdl_formats.h: format choice for the YT-DL extractor
 *****************************************************************************
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifndef VLC_YTDL_FORMATS_H
#define VLC_YTDL_FORMATS_H

struct json_object;

/**
 * Picks the format to play from a yt-dlp info dictionary.
 *
 * Formats without any audio or video (storyboards) are never picked.
 * Formats with both video and audio are preferred over formats whose content
 * is unknown, then over audio-only, then over video-only formats.
 * Among formats of the same kind, the highest height at or below
 * \p pref_height wins (the lowest above it if none fits), or the highest
 * height if \p pref_height is NaN; then the highest bit rate.
 *
 * \param entry info dictionary (one video)
 * \param pref_height preferred video height, or NaN for the best available
 * \return the chosen format, \p entry itself if it has no format list,
 *         or NULL if no format can be played
 */
const struct json_object *ytdl_PickFormat(const struct json_object *entry,
                                          double pref_height);

#endif
