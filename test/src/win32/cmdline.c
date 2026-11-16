/*****************************************************************************
 * cmdline.c: test for the Windows command line quoting of vlc_spawn()
 *****************************************************************************
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

/* Pure C: builds and runs on any platform (src/win32/cmdline.c uses no
 * Windows API). Each command line is checked against the expected text and
 * split again with the rules of CommandLineToArgvW / the Microsoft C
 * start-up code, which must give back the same arguments. */

#undef NDEBUG
#include <assert.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "../../../src/win32/cmdline.h"

#define MAX_ARGS 16

/* Splits a command line as CommandLineToArgvW does. The first argument
 * (the program) has no escapes: quotes only group. */
static int split(const char *line, char *out[MAX_ARGS])
{
    int argc = 0;
    const char *p = line;
    char *buf;

    /* program name */
    buf = calloc(strlen(line) + 1, 1);
    assert(buf != NULL);
    {
        size_t n = 0;
        bool quoted = false;

        while (*p != '\0' && (quoted || (*p != ' ' && *p != '\t'))) {
            if (*p == '"')
                quoted = !quoted;
            else
                buf[n++] = *p;
            p++;
        }
        out[argc++] = buf;
    }

    for (;;) {
        while (*p == ' ' || *p == '\t')
            p++;
        if (*p == '\0')
            break;

        buf = calloc(strlen(line) + 1, 1);
        assert(buf != NULL);

        size_t n = 0;
        bool quoted = false;

        while (*p != '\0' && (quoted || (*p != ' ' && *p != '\t'))) {
            size_t backslashes = 0;

            while (*p == '\\') {
                backslashes++;
                p++;
            }
            if (*p == '"') {
                for (size_t i = 0; i < backslashes / 2; i++)
                    buf[n++] = '\\';
                if (backslashes % 2) {
                    buf[n++] = '"';
                } else if (quoted && p[1] == '"') {
                    buf[n++] = '"'; /* "" inside quotes */
                    p++;
                } else {
                    quoted = !quoted;
                }
                p++;
            } else {
                for (size_t i = 0; i < backslashes; i++)
                    buf[n++] = '\\';
                if (*p != '\0' && (quoted || (*p != ' ' && *p != '\t')))
                    buf[n++] = *p++;
            }
        }
        assert(argc < MAX_ARGS);
        out[argc++] = buf;
    }
    return argc;
}

static void check(const char *const *argv, const char *expected)
{
    char *line = vlc_win32_cmdline(argv);

    assert(line != NULL);
    printf("[%s]\n", line);
    if (expected != NULL && strcmp(line, expected) != 0) {
        fprintf(stderr, "  expected [%s]\n", expected);
        abort();
    }

    char *out[MAX_ARGS];
    int argc = split(line, out);
    int n = 0;

    while (argv[n] != NULL)
        n++;
    assert(argc == n);
    for (int i = 0; i < n; i++) {
        if (strcmp(out[i], argv[i]) != 0) {
            fprintf(stderr, "  argument %d: [%s], expected [%s]\n", i,
                    out[i], argv[i]);
            abort();
        }
        free(out[i]);
    }
    free(line);
}

int main(void)
{
    /* Issue #143: yt-dlp in a folder with a space */
    check((const char *[]){ "C:\\Program Files\\yt-dlp\\yt-dlp.exe",
            "--flat-playlist", "--dump-single-json", "--",
            "https://www.youtube.com/watch?v=z-g2huBo9qY", NULL },
          "\"C:\\Program Files\\yt-dlp\\yt-dlp.exe\" --flat-playlist"
          " --dump-single-json -- https://www.youtube.com/watch?v=z-g2huBo9qY");

    /* No space: unchanged, as before */
    check((const char *[]){ "C:\\Tools\\yt-dlp.exe", "--", "a&b", NULL },
          "C:\\Tools\\yt-dlp.exe -- a&b");
    check((const char *[]){ "yt-dlp.exe", NULL }, "yt-dlp.exe");

    /* Empty argument */
    check((const char *[]){ "prog", "", "x", NULL }, "prog \"\" x");

    /* Quotes and backslashes */
    check((const char *[]){ "prog", "say \"hi\"", NULL },
          "prog \"say \\\"hi\\\"\"");
    check((const char *[]){ "prog", "a\"b", NULL }, "prog \"a\\\"b\"");
    check((const char *[]){ "prog", "C:\\dir with space\\", NULL },
          "prog \"C:\\dir with space\\\\\"");
    check((const char *[]){ "prog", "back\\\\\"quote", NULL },
          "prog \"back\\\\\\\\\\\"quote\"");
    check((const char *[]){ "prog", "C:\\no\\space\\", NULL },
          "prog C:\\no\\space\\");
    check((const char *[]){ "prog", "tab\there", "new\nline", NULL },
          "prog \"tab\there\" \"new\nline\"");

    /* UTF-8 is copied as it is */
    check((const char *[]){ "C:\\Users\\Zo\xc3\xab\\yt dlp\\yt-dlp.exe",
            "--", "https://example.org/caf\xc3\xa9", NULL },
          "\"C:\\Users\\Zo\xc3\xab\\yt dlp\\yt-dlp.exe\" --"
          " https://example.org/caf\xc3\xa9");

    printf("cmdline tests: pass\n");
    return 0;
}
