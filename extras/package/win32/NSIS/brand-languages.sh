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

# The English component names and descriptions, as Cone's installer words them (the other
# languages keep VLC's translations, with the name replaced above)
for f in "$dir"/EnglishExtra.nsh; do
    [ -f "$f" ] || continue
    LC_ALL=C BRAND_NAME="$name" perl -pi -e '
        s/^(\$\{LangFileString\} Name_Section01) .*/$1 "$ENV{BRAND_NAME} (required)"/;
        s/^(\$\{LangFileString\} Name_Section02a) .*/$1 "Start menu shortcut"/;
        s/^(\$\{LangFileString\} Name_Section02b) .*/$1 "Desktop shortcut"/;
        s/^(\$\{LangFileString\} Name_Section05) .*/$1 "DVD and Blu-ray playback"/;
        s/^(\$\{LangFileString\} Name_Section06) .*/$1 "File types"/;
        s/^(\$\{LangFileString\} Name_SectionGroupAudio) .*/$1 "Audio files"/;
        s/^(\$\{LangFileString\} Name_SectionGroupVideo) .*/$1 "Video files"/;
        s/^(\$\{LangFileString\} Name_SectionGroupOther) .*/$1 "Other files"/;
        s/^(\$\{LangFileString\} Name_Section07) .*/$1 "Right-click menu entries"/;
        s/^(\$\{LangFileString\} Name_Section08) .*/$1 "Delete old preferences and cache"/;
    ' "$f"
    # the descriptions are on the line after their ID
    LC_ALL=C BRAND_NAME="$name" perl -0pi -e '
        s/(Desc_Section01 \\\n\s*)".*?"/$1"$ENV{BRAND_NAME} itself"/;
        s/(Desc_Section02a \\\n\s*)".*?"/$1"Adds $ENV{BRAND_NAME} to the Start menu"/;
        s/(Desc_Section02b \\\n\s*)".*?"/$1"Adds a $ENV{BRAND_NAME} icon to your desktop"/;
        s/(Desc_Section05 \\\n\s*)".*?"/$1"Offers $ENV{BRAND_NAME} when you insert a DVD, Blu-ray or audio CD"/;
        s/(Desc_Section07 \\\n\s*)".*?"/$1"Adds \x27Play with $ENV{BRAND_NAME}\x27 and \x27Add to $ENV{BRAND_NAME}\x27s Playlist\x27 to the right-click menu of media files and folders"/;
        s/(Desc_Section08 \\\n\s*)".*?"/$1"Deletes $ENV{BRAND_NAME} preferences and cache files left over from earlier installations"/;
    ' "$f"
done
