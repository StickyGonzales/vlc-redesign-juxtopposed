#!/bin/bash
# AppImage of the portable Linux folder (linux-package.sh), on the workflow's runner
# (redesign/LINUX_NOTES.md, Decision (Sticky) 2).
#   linux-appimage.sh <portable folder> <AppImage runtime> <output .AppImage>
# An AppImage is the runtime (a small static program that mounts or extracts the image) followed
# by a SquashFS image of the folder; the runtime starts the folder's AppRun, here the folder's
# launcher. Needs mksquashfs (squashfs-tools).
set -e

DIR=${1:?usage: $0 <folder> <runtime> <output>}
RUNTIME=${2:?}
OUT=${3:?}

# the top-level .desktop names the launcher (Exec=) and the icon (Icon=, a .png next to it); an
# AppImage's integration tools (AppImageLauncher, appimaged, Gear Lever) read both, and Cone's
# usr/share/applications and usr/share/icons inside
DESKTOP=$(find "$DIR" -maxdepth 1 -name '*.desktop' | head -n 1)
[ -n "$DESKTOP" ] || { echo "no desktop file in $DIR" >&2; exit 1; }
NAME=$(sed -n 's/^Exec=\([^ ]*\).*/\1/p' "$DESKTOP" | head -n 1)
ICON=$(sed -n 's/^Icon=//p' "$DESKTOP" | head -n 1)
[ -n "$NAME" ] && [ -x "$DIR/$NAME" ] || { echo "no launcher \"$NAME\" for $DESKTOP" >&2; exit 1; }
[ -f "$DIR/$ICON.png" ] || { echo "no icon $ICON.png in $DIR" >&2; exit 1; }

# AppRun: the launcher; .DirIcon: the icon file managers show for the AppImage
ln -sfn "$NAME" "$DIR/AppRun"
ln -sfn "$ICON.png" "$DIR/.DirIcon"

SQUASHFS=$(mktemp -u).squashfs
mksquashfs "$DIR" "$SQUASHFS" -root-owned -noappend -comp zstd -Xcompression-level 19 -no-progress -quiet
cat "$RUNTIME" "$SQUASHFS" > "$OUT"
chmod +x "$OUT"
rm -f "$SQUASHFS" "$DIR/AppRun" "$DIR/.DirIcon"
ls -la "$OUT"
