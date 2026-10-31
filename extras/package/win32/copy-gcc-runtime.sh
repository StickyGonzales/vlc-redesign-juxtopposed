#!/bin/sh
# redesign: copies the MinGW GCC runtime DLLs that packaged modules import next to the exe, for
# the zip and the installer alike (the installer takes every *.dll of the package root).
# The C++ plug-ins (x265, libsrt, game-music-emu) link libgcc_s dynamically with the GCC
# toolchain, although configure asks for -static-libgcc (libtool drops it for their C++
# dependencies): without the DLL, Windows refused to load libx265_plugin, libaccess_srt_plugin,
# libaccess_output_srt_plugin and libgme_plugin ("cannot load plug-in", error 126). The posix
# toolchain's libgcc_s itself imports libwinpthread.
#   copy-gcc-runtime.sh <package dir> <objdump> <compiler>
set -eu
DEST="$1"
OBJDUMP="$2"
CC="$3"
IMPORTS=$(mktemp)
trap 'rm -f "$IMPORTS"' EXIT

imports_of() {
    "$OBJDUMP" -p "$@" 2>/dev/null | sed -n 's/^[[:space:]]*DLL Name: //p'
}

find "$DEST" \( -iname '*.dll' -o -iname '*.exe' \) -exec "$OBJDUMP" -p {} + 2>/dev/null \
    | sed -n 's/^[[:space:]]*DLL Name: //p' | sort -fu > "$IMPORTS"

# libstdc++ imports libgcc_s, which imports libwinpthread: each is checked after the ones that
# may import it
for rt in libstdc++-6.dll libgcc_s_seh-1.dll libgcc_s_dw2-1.dll libwinpthread-1.dll; do
    grep -qix "$rt" "$IMPORTS" || continue
    src=$($CC -print-file-name="$rt")
    if [ ! -f "$src" ]; then
        echo "copy-gcc-runtime: packaged modules import $rt, which $CC does not have" >&2
        exit 1
    fi
    cp "$src" "$DEST/"
    echo "copy-gcc-runtime: $rt from $src"
    imports_of "$DEST/$rt" >> "$IMPORTS"
done
