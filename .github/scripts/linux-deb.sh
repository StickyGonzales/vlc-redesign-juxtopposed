#!/bin/bash
# Debian package (amd64) of the portable Cone folder (linux-package.sh), on the workflow's runner.
#   linux-deb.sh <portable folder Cone-X.Y.Z[-label]-linux-x86_64> <output folder>
# Installs:
#   /opt/cone-player/                       the portable folder, as it is
#   /usr/bin/cone-player                    the command
#   /usr/share/applications/cone-player.desktop, /usr/share/icons/hicolor/*/apps/cone-player.png
# Every path is Cone Player's own: it installs next to Debian's or Ubuntu's VLC (vlc, /usr/bin/vlc,
# vlc.desktop) and never replaces, conflicts with or diverts any of its files. Its menu entry lists
# the video, audio and subtitle types for "Open with" without making itself the default player
# (dpkg's triggers refresh the menu and icon caches).
set -e

DIR=${1:?usage: $0 <portable folder> <output folder>}
OUT=${2:?}
DIR=$(cd "$DIR" && pwd)
BASE=$(basename "$DIR")
case "$BASE" in
    Cone-*-linux-x86_64) ;;
    *) echo "$BASE is not a Cone portable folder (Cone-X.Y.Z-linux-x86_64)" >&2; exit 1 ;;
esac
VERSION=${BASE#Cone-}
VERSION=${VERSION%-linux-x86_64}
# 1.2.0-beta -> 1.2.0~beta: a pre-release sorts before its release
DEBVERSION=$(echo "$VERSION" | sed 's/-/~/')
GLIBC=$(grep -o 'glibc [0-9.]*' "$DIR/README-LINUX.txt" | head -n 1 | cut -d' ' -f2)
[ -n "$GLIBC" ] || { echo "no glibc version in $DIR/README-LINUX.txt" >&2; exit 1; }

STAGE=$(mktemp -d)
ROOT=$STAGE/cone-player
mkdir -p "$ROOT/opt" "$ROOT/usr/bin" "$ROOT/usr/share/applications" "$ROOT/usr/share/icons" \
         "$ROOT/usr/share/doc/cone-player" "$ROOT/DEBIAN"
cp -a "$DIR" "$ROOT/opt/cone-player"
# the per-user installer is for the tarball only
rm -f "$ROOT/opt/cone-player/install.sh" "$ROOT/opt/cone-player/uninstall.sh"

cat > "$ROOT/usr/bin/cone-player" <<'EOF'
#!/bin/sh
exec /opt/cone-player/cone "$@"
EOF
chmod 755 "$ROOT/usr/bin/cone-player"

sed -e 's|^Exec=.*|Exec=cone-player %U|' "$DIR/usr/share/applications/cone-player.desktop" \
    > "$ROOT/usr/share/applications/cone-player.desktop"
cp -a "$DIR/usr/share/icons/hicolor" "$ROOT/usr/share/icons/"

cat > "$ROOT/usr/share/doc/cone-player/copyright" <<'EOF'
Cone Player: Juxtopposed's VLC redesign on VLC media player 4 (development version).
Source: https://github.com/StickyGonzales/vlc-redesign-juxtopposed
Not affiliated with VideoLAN. "VLC" is a trademark of VideoLAN.

Files: *
License: GPL-2+ (VLC media player and Cone Player's changes); the bundled libraries keep their
 own licenses. On Debian systems the GPL version 2 is in /usr/share/common-licenses/GPL-2.

Design: Juxtopposed, "VLC Redesign" (CC BY 4.0),
 https://www.figma.com/community/file/1691465999134370980/vlc-redesign
EOF

SIZE=$(du -sk --exclude=DEBIAN "$ROOT" | cut -f1)
cat > "$ROOT/DEBIAN/control" <<EOF
Package: cone-player
Version: $DEBVERSION
Architecture: amd64
Maintainer: StickyGonzales <103277167+StickyGonzales@users.noreply.github.com>
Installed-Size: $SIZE
Depends: libc6 (>= $GLIBC), libgl1, libegl1, libx11-6, libx11-xcb1, libxcb1, libdrm2, libgbm1, libexpat1, zlib1g, libdbus-1-3, libudev1, libasound2t64 | libasound2
Recommends: libpulse0 | pipewire-pulse
Section: video
Priority: optional
Homepage: https://github.com/StickyGonzales/vlc-redesign-juxtopposed
Description: media player with Juxtopposed's VLC redesign
 Cone Player is VLC media player 4 with the full redesign by Juxtopposed: a new
 player, sidebars, library and settings on VLC's own playback engine.
 .
 It installs into /opt/cone-player with the command cone-player, keeps its own
 settings (~/.config/Cone) and runs next to an installed VLC without replacing
 it. Experimental: based on the development version of VLC.
EOF

mkdir -p "$OUT"
DEB=$OUT/cone-player_${DEBVERSION}_amd64.deb
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$DEB"
rm -rf "$STAGE"
dpkg-deb --info "$DEB"
ls -la "$DEB"
