#!/bin/sh
# redesign: brand layer, the public profile's installer texts name the app instead of VLC
# (redesign/CONE_RELEASE_NOTES.md). Rewrites the copied NSIS language files in place; the
# string IDs (MessageBox_VLCRunning, ...) stay as they are.
# usage: brand-languages.sh <languages folder> <product name>
# meson passes the folder relative to the install prefix (MESON_INSTALL_DESTDIR_PREFIX).
set -e

dir=$1
name=$2
if [ -n "$MESON_INSTALL_DESTDIR_PREFIX" ]; then
    dir="$MESON_INSTALL_DESTDIR_PREFIX/$dir"
fi

for f in "$dir"/*Extra.nsh; do
    LC_ALL=C BRAND_NAME="$name" perl -pi -e '
        s/VideoLAN VLC media player/$ENV{BRAND_NAME}/gi;
        s/VLC media player/$ENV{BRAND_NAME}/g;
        s/VideoLAN VLC/$ENV{BRAND_NAME}/gi;
        s/(?<!MessageBox_)VLC/$ENV{BRAND_NAME}/g;
        s/VideoLAN/$ENV{BRAND_NAME}/gi;
    ' "$f"
done
