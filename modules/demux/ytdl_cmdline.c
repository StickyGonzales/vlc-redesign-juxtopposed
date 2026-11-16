/*****************************************************************************
 * ytdl_cmdline.c: Windows command line quoting for yt-dlp's arguments
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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "ytdl_cmdline.h"

static bool NeedsQuotes(const char *arg)
{
    return arg[0] == '\0' || strpbrk(arg, " \t\n\v\"") != NULL;
}

/* Writes one argument to out (if not NULL); returns its length */
static size_t QuoteArg(const char *arg, char *out)
{
    size_t len = 0;

    if (!NeedsQuotes(arg)) {
        len = strlen(arg);
        if (out != NULL)
            memcpy(out, arg, len);
        return len;
    }

#define PUT(c) do { if (out != NULL) out[len] = (c); len++; } while (0)
    PUT('"');
    for (const char *p = arg;; p++) {
        size_t backslashes = 0;

        while (*p == '\\') {
            backslashes++;
            p++;
        }

        if (*p == '\0') {
            /* Backslashes before the closing quote are doubled */
            for (size_t i = 0; i < 2 * backslashes; i++)
                PUT('\\');
            break;
        }

        if (*p == '"') {
            /* Backslashes before a quote are doubled, and the quote escaped */
            for (size_t i = 0; i < 2 * backslashes + 1; i++)
                PUT('\\');
        } else {
            /* Other backslashes are literal */
            for (size_t i = 0; i < backslashes; i++)
                PUT('\\');
        }
        PUT(*p);
    }
    PUT('"');
#undef PUT
    return len;
}

char *ytdl_QuoteArg(const char *arg)
{
    char *quoted = malloc(QuoteArg(arg, NULL) + 1);

    if (quoted == NULL)
        return NULL;
    quoted[QuoteArg(arg, quoted)] = '\0';
    return quoted;
}

char *ytdl_JoinArgs(const char *const *argv)
{
    size_t size = 1;

    for (size_t i = 0; argv[i] != NULL; i++)
        size += QuoteArg(argv[i], NULL) + 1;

    char *cmdline = malloc(size);
    if (cmdline == NULL)
        return NULL;

    size_t len = 0;
    for (size_t i = 0; argv[i] != NULL; i++) {
        if (i > 0)
            cmdline[len++] = ' ';
        len += QuoteArg(argv[i], cmdline + len);
    }
    cmdline[len] = '\0';
    return cmdline;
}
