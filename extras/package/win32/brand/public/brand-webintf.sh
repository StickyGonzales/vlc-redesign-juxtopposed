#!/bin/sh
# redesign: brand layer, the public profile's web interface (Settings > Controls > Web interface)
# names and shows the app instead of VLC (redesign/BUILD_NOTES.md "Beta branding audit").
# Rewrites the packaged copy of share/lua/http in place; the sources stay VLC's, so the vlc
# profile is unchanged. The page titles become new English texts (their VLC wording is
# translated through the web interface's gettext; the Cone wording has no translation yet).
# usage: brand-webintf.sh <packaged lua/http folder> <product name> <brand pixmaps folder> <ico>
set -e

dir=$1
name=$2
pixmaps=$3
ico=$4

test -d "$dir" || exit 0

for f in "$dir"/*.html "$dir"/dialogs/*.html; do
    test -f "$f" || continue
    LC_ALL=C BRAND_NAME="$name" perl -pi -e '
        # footer of the main page: "VLC <version> - Lua Web Interface" keeps the attribution
        s/^(\s*)VLC (<\?vlc print\(vlc\.misc\.version\(\))/$1$ENV{BRAND_NAME}, based on VLC $2/;
        s/VLC media player/$ENV{BRAND_NAME}/g;
        s/(?<![\w.\/-])VLC(?= can )/$ENV{BRAND_NAME}/g;
    ' "$f"
done

# the cone pictures of the pages: the app's logo under the same file names
cp -f "$pixmaps/cone-48.png" "$dir/images/vlc-48.png"
cp -f "$pixmaps/cone-16.png" "$dir/images/vlc16x16.png"
cp -f "$ico" "$dir/favicon.ico"
