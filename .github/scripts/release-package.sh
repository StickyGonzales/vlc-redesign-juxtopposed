#!/bin/bash
# release.yml: turns the build's packages into the release files.
#   release-package.sh <built dir> <out dir> <version tag>
# <built dir> holds the build's two packages, already named for the version tag by the build
# (build-windows.yml's version input; redesign/RENAME_CONE_PLAYER.md): for v1.0.0-rc1,
# ConePlayer-1.0.0-rc1-win64.zip (top folder ConePlayer-1.0.0-rc1) and coneplayer-1.0.0-win64.exe
# (the installer's name has no suffix). The release files are the zip as built plus an empty
# ConePlayer-<version>/portable folder (Cone keeps its settings there, next to Cone.exe, as the
# betas did; src/win32/dirs.c), and the installer as coneplayer-<version>-win64.exe, with
# SHA256SUMS.txt. Writes version, zip, exe, their SHA-256
# and vlc_version (configure.ac's) to GITHUB_OUTPUT when set.
set -euo pipefail

BUILT=$1
OUT=$2
VER=${3#v}

BUILT_ZIP=ConePlayer-$VER-win64.zip
BUILT_EXE=coneplayer-${VER%%-*}-win64.exe
ZIP=$BUILT_ZIP
EXE=coneplayer-$VER-win64.exe

for f in "$BUILT_ZIP" "$BUILT_EXE"; do
    [ -f "$BUILT/$f" ] || { echo "::error::$f is not in the build's packages: $(cd "$BUILT" && echo *)"; exit 1; }
done

TOP=$(unzip -Z1 "$BUILT/$BUILT_ZIP" | cut -d/ -f1 | sort -u)
[ "$TOP" = "ConePlayer-$VER" ] \
    || { echo "::error::$BUILT_ZIP must hold the one top folder ConePlayer-$VER, it holds: $TOP"; exit 1; }

VLC_VERSION=$(sed -n 's/^AC_INIT(\[vlc\], *\[\([^]]*\)\].*/\1/p' configure.ac)
[ -n "$VLC_VERSION" ] || { echo "::error::no VLC version in configure.ac's AC_INIT"; exit 1; }

unzip -Z1 "$BUILT/$BUILT_ZIP" | grep -q "^ConePlayer-$VER/portable/" \
    && { echo "::error::$BUILT_ZIP already holds a portable folder"; exit 1; }

mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
cp "$BUILT/$BUILT_ZIP" "$OUT/$ZIP"
cp "$BUILT/$BUILT_EXE" "$OUT/$EXE"

# the empty portable folder, added to the zip only: the installer is built from the same files,
# and an installed Cone keeps its settings in %APPDATA%\Cone
STAGE=$(mktemp -d)
mkdir -p "$STAGE/ConePlayer-$VER/portable"
(cd "$STAGE" && zip -q "$OUT/$ZIP" "ConePlayer-$VER/portable/")
rm -r "$STAGE"
unzip -Z1 "$OUT/$ZIP" | grep -qx "ConePlayer-$VER/portable/" \
    || { echo "::error::the portable folder is not in $ZIP"; exit 1; }

(cd "$OUT" && sha256sum "$ZIP" "$EXE" > SHA256SUMS.txt)
cat "$OUT/SHA256SUMS.txt"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "version=$VER"
        echo "zip=$ZIP"
        echo "exe=$EXE"
        echo "zip_sha256=$(sha256sum "$OUT/$ZIP" | cut -d' ' -f1)"
        echo "exe_sha256=$(sha256sum "$OUT/$EXE" | cut -d' ' -f1)"
        echo "vlc_version=$VLC_VERSION"
    } >> "$GITHUB_OUTPUT"
fi
