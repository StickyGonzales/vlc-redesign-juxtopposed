#!/bin/sh
# Issue #143, built without a VLC build:
# - the Windows command line quoting of yt-dlp's arguments (modules/demux/ytdl_cmdline.c, pure C,
#   so it runs here too), test/modules/demux/ytdl_cmdline.c;
# - the YT-DL extractor's format choice (modules/demux/ytdl_formats.c) against saved yt-dlp
#   format lists, test/modules/demux/ytdl_formats.c: VLC's
# JSON parser is generated with bison and flex, and its libvlccore charset calls are
# mapped to the C library's iconv. The same test also runs in VLC's own `make check` / `meson test`.
# Used by unit-tests.yml; locally: .github/scripts/ytdl-tests.sh <out dir>
# SANITIZE=1: with AddressSanitizer and UndefinedBehaviorSanitizer.
set -eu
OUT="${1:-/tmp/cone-ytdl-tests}"
mkdir -p "$OUT"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
J="$ROOT/modules/demux/json"
bison -d -o "$OUT/grammar.c" "$J/grammar.y"
flex --outfile="$OUT/lex.yy.c" "$J/lexicon.l"
cat > "$OUT/stubs.c" <<'STUB'
/* json.c converts every string to UTF-16 and back with libvlccore's iconv
 * wrappers: the C library's iconv does the same */
#include <iconv.h>
#include <stdlib.h>
#include <string.h>
typedef void *vlc_iconv_t;
vlc_iconv_t vlc_iconv_open(const char *to, const char *from)
{ return (vlc_iconv_t)iconv_open(to, from); }
size_t vlc_iconv(vlc_iconv_t cd, const char **in, size_t *inl, char **out, size_t *outl)
{ return iconv((iconv_t)cd, (char **)in, inl, out, outl); }
int vlc_iconv_close(vlc_iconv_t cd) { return iconv_close((iconv_t)cd); }
char *FromCharset(const char *cs, const void *d, size_t n)
{
    iconv_t cd = iconv_open("UTF-8", cs);
    if (cd == (iconv_t)-1)
        return NULL;
    size_t outl = n * 2 + 1;
    char *out = malloc(outl), *p = out, *in = (char *)d;
    if (out != NULL && iconv(cd, &in, &n, &p, &outl) != (size_t)-1 && outl > 0)
        *p = 0;
    else {
        free(out);
        out = NULL;
    }
    iconv_close(cd);
    return out;
}
STUB
CFLAGS="-std=gnu17 -Wall -Wextra -Wno-unused-parameter -Wno-sign-compare -O1 -g"
CFLAGS="$CFLAGS -I$ROOT/include -I$J -I$OUT -D_GNU_SOURCE -DMODULE_STRING=\"ytdl\""
if [ -n "${SANITIZE:-}" ]; then
    CFLAGS="$CFLAGS -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=undefined"
    export ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=1:abort_on_error=0}"
fi
# shellcheck disable=SC2086
cc $CFLAGS -Werror -c "$ROOT/modules/demux/ytdl_formats.c" -o "$OUT/ytdl_formats.o"
# shellcheck disable=SC2086
cc $CFLAGS -o "$OUT/test_ytdl_formats" \
    "$ROOT/test/modules/demux/ytdl_formats.c" "$OUT/ytdl_formats.o" \
    "$J/json.c" "$OUT/grammar.c" "$OUT/lex.yy.c" "$OUT/stubs.c" -lm
timeout 60 "$OUT/test_ytdl_formats"
echo "ytdl format tests: pass"
# shellcheck disable=SC2086
cc $CFLAGS -Werror -o "$OUT/test_win32_cmdline" \
    "$ROOT/test/modules/demux/ytdl_cmdline.c" "$ROOT/modules/demux/ytdl_cmdline.c"
timeout 60 "$OUT/test_win32_cmdline"
