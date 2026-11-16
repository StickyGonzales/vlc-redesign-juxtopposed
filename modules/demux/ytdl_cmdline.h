/*****************************************************************************
 * ytdl_cmdline.h: Windows command line quoting for yt-dlp's arguments
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

#ifndef VLC_YTDL_CMDLINE_H
#define VLC_YTDL_CMDLINE_H

/*
 * Issue #143: vlc_spawnp() on Windows joins its arguments with spaces as they
 * are, so a yt-dlp in a folder with a space ("C:\Program Files") is split
 * into several arguments. The YT-DL extractor quotes its own arguments with
 * these functions before it calls vlc_spawnp(); every other caller of
 * vlc_spawnp() (the external preparser, ...) is left as it is.
 */

/**
 * Quotes one argument for a Windows command line, as ytdl_JoinArgs() does.
 *
 * \param arg UTF-8 argument
 * eturn a heap-allocated copy (free() it), in double quotes if needed, or
 *         NULL on error
 */
char *ytdl_QuoteArg(const char *arg);

/**
 * Joins arguments into one Windows command line.
 *
 * An argument that is empty or holds a space, a tab, a new line, a vertical
 * tab or a double quote is put in double quotes, with its quotes and the
 * backslashes in front of them escaped, so that the C run time
 * (CommandLineToArgvW and the Microsoft C start-up code) splits the line
 * back into the same arguments. Other arguments are copied as they are.
 *
 * \param argv NULL-terminated array of UTF-8 arguments
 * \return a heap-allocated command line (free() it), or NULL on error
 */
char *ytdl_JoinArgs(const char *const *argv);

#endif
