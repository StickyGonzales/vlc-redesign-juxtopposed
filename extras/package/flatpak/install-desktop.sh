#!/bin/sh
# Cone Player's desktop integration in its Flatpak (io.github.StickyGonzales.ConePlayer.yml):
# the launcher, the menu entry with the file types (the same list as the other Linux packages,
# .github/scripts/linux-package.sh), the icons and the AppStream file. Run from the source tree
# after "make install", with the install prefix (/app).
set -e
PREFIX=${1:?usage: $0 <prefix>}
ID=io.github.StickyGonzales.ConePlayer
# where the launcher and the AppStream file are (the manifest brings them in as cone-flatpak/)
HERE=${CONE_FLATPAK_DIR:-extras/package/flatpak}

install -Dm755 "$HERE/cone" "$PREFIX/bin/cone"

# VLC's own menu entry, icons and AppStream file would show VLC
rm -rf "$PREFIX/share/applications" "$PREFIX/share/metainfo"
find "$PREFIX/share/icons" -name 'vlc*' -delete 2>/dev/null || true

for size in 16 24 32 48 64 128 256; do
    install -Dm644 "modules/gui/qt/pixmaps/brand/public/cone-$size.png" \
        "$PREFIX/share/icons/hicolor/${size}x${size}/apps/$ID.png"
done

MIMETYPES=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' share/vlc.desktop.mimetypes \
            | grep -v -e '^$' -e '^x-scheme-handler/' | tr '\n' ';')
SUBTITLE_TYPES='application/x-subrip;text/x-ssa;text/vtt;text/x-microdvd;text/x-mpsub;text/x-subviewer;application/x-sami;'
mkdir -p "$PREFIX/share/applications"
cat > "$PREFIX/share/applications/$ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Cone Player
GenericName=Media Player
Comment=Play your videos and music (based on VLC media player)
Exec=cone --started-from-file %U
Icon=$ID
Terminal=false
Categories=AudioVideo;Player;Video;Audio;
Keywords=Player;Video;Audio;Music;Movie;Subtitles;
StartupNotify=true
StartupWMClass=$ID
MimeType=$MIMETYPES$SUBTITLE_TYPES
DESKTOP

install -Dm644 "$HERE/$ID.metainfo.xml" "$PREFIX/share/metainfo/$ID.metainfo.xml"
