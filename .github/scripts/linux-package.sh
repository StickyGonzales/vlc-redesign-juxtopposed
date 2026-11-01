#!/bin/bash
# Portable Linux package of an installed VLC tree (.github/scripts/linux-build.sh package, inside
# VideoLAN's Debian build image): one folder that runs from wherever it is unpacked, and its
# tarball in linux/ (redesign/LINUX_NOTES.md).
#   linux-package.sh <installed prefix, e.g. /build/stage/usr>
# Environment: VLC_BRAND (vlc or public), BRAND_VERSION, BRAND_PACKAGE_SUFFIX, PATCHELF (path of
# patchelf; the workflow downloads a pinned release).
#
# Layout of the folder:
#   cone (or vlc)       launcher: portable mode, then usr/bin/vlc
#   cone-player.desktop, cone-player.png, install.sh, uninstall.sh (Cone; vlc.desktop and vlc.png
#                       for the vlc profile), README-LINUX.txt
#   usr/share/applications, usr/share/icons/hicolor   Cone Player's menu entry and icons
#   usr/                the installed tree (bin, lib, lib/vlc/plugins, share)
#   usr/lib/deps/       the image's libraries VLC and Qt need, except the ones every desktop
#                       system has (C library, graphics drivers, X11, sound servers, fonts)
#   usr/lib/qt6/        Qt's plugins and QML modules, found through usr/bin/qt.conf
# Every program and library finds the bundled ones through its own RUNPATH ($ORIGIN), so nothing
# leaks into the programs it starts (file manager, browser), as LD_LIBRARY_PATH would.
set -e

SRC=${1:?usage: $0 <installed prefix>}
PATCHELF=${PATCHELF:-patchelf}
QT_LIBDIR=/usr/lib/x86_64-linux-gnu
QT_PLUGINS=$QT_LIBDIR/qt6/plugins
QT_QML=$QT_LIBDIR/qt6/qml

if [ "$VLC_BRAND" = public ]; then
    NAME=cone
    VERSION=${BRAND_VERSION:-0.1.0}
    PKG="Cone-$VERSION${BRAND_PACKAGE_SUFFIX:-}-linux-x86_64"
    TITLE="Cone"
    ICON_SRC=/build/modules/gui/qt/pixmaps/brand/public/cone-256.png
else
    NAME=vlc
    VERSION=$(grep -m1 '^#define PACKAGE_VERSION' /build/build-linux/config.h | cut -d'"' -f2)
    PKG="vlc-$VERSION-linux-x86_64"
    TITLE="VLC media player"
    ICON_SRC=$SRC/share/icons/hicolor/256x256/apps/vlc.png
fi

OUT=/build/linux
DIR=$OUT/$PKG
rm -rf "$OUT"
mkdir -p "$DIR"
cp -a "$SRC" "$DIR/usr"
U=$DIR/usr

# headers, static and libtool files, pkg-config: not needed to run
rm -rf "$U/include" "$U/lib/pkgconfig"
find "$U" \( -name '*.la' -o -name '*.a' \) -delete

# --- Qt plugins and QML modules -----------------------------------------------------------------
mkdir -p "$U/lib/qt6/plugins" "$U/lib/qt6/qml"
for d in platforms xcbglintegrations wayland-decoration-client wayland-graphics-integration-client \
         wayland-shell-integration imageformats iconengines tls platforminputcontexts; do
    [ -d "$QT_PLUGINS/$d" ] && cp -a "$QT_PLUGINS/$d" "$U/lib/qt6/plugins/"
done
# Qt's SVG image and icon plugins: the interface draws every icon through them, and the image has
# no package of them (Debian's qt6-svg-plugins, the image's exact qt6-svg version, unpacked by the
# workflow into .qt-svg-plugins)
QT_SVG_PLUGINS=/build/.qt-svg-plugins$QT_PLUGINS
if [ ! -f "$QT_SVG_PLUGINS/imageformats/libqsvg.so" ]; then
    echo "::error::Qt's SVG plugins are missing ($QT_SVG_PLUGINS): the interface would have no icons"
    exit 1
fi
mkdir -p "$U/lib/qt6/plugins/imageformats" "$U/lib/qt6/plugins/iconengines"
cp -a "$QT_SVG_PLUGINS/imageformats/libqsvg.so" "$U/lib/qt6/plugins/imageformats/"
cp -a "$QT_SVG_PLUGINS/iconengines/libqsvgicon.so" "$U/lib/qt6/plugins/iconengines/"
# the portal theme only (native file dialogs through xdg-desktop-portal); the GTK one would pull
# in GTK
mkdir -p "$U/lib/qt6/plugins/platformthemes"
cp -a "$QT_PLUGINS"/platformthemes/libqxdgdesktopportal.so "$U/lib/qt6/plugins/platformthemes/" 2>/dev/null || true
# the modules the interface imports (QtQuick, its Controls, Templates, Layouts, Window, QtQml)
cp -a "$QT_QML/QtQml" "$QT_QML/QtQuick" "$U/lib/qt6/qml/"
rm -rf "$U/lib/qt6/qml/QtQuick/"{Particles,LocalStorage,Scene2D,Scene3D,VectorImage,tooling}
# Qt reads qt.conf next to the program: vlc, and vlc-qt-check (the interface's start test, which
# VLC runs from usr/libexec/vlc before it loads the Qt interface); Prefix is relative to the file
write_qt_conf() {
    printf '[Paths]\nPrefix = %s\nPlugins = lib/qt6/plugins\nQmlImports = lib/qt6/qml\n' "$2" > "$1/qt.conf"
}
write_qt_conf "$U/bin" ..
QTCHECK=$(find "$U" -name vlc-qt-check -type f | head -n 1)
[ -n "$QTCHECK" ] && write_qt_conf "$(dirname "$QTCHECK")" "$(realpath --relative-to="$(dirname "$QTCHECK")" "$U")"

# --- libraries ------------------------------------------------------------------------------------
# provided by the system: the C library, graphics drivers and their loaders (OpenGL, EGL, Vulkan,
# GBM, DRM), X11 and its core connection, sound servers, D-Bus, udev (the same idea as AppImage's
# exclude list). The VA-API and VDPAU loaders are bundled: the image's FFmpeg needs a newer libva
# than many systems have, and both load the system's drivers (backward compatible). The font
# libraries (fontconfig, freetype, harfbuzz) are bundled though: the image's pango, which FFmpeg's
# SVG support loads, needs the newer fontconfig it was built with. Also left to the system: the
# terminal, SSH, Samba and GTK libraries, which desktop systems have and which would raise the
# oldest C library the package runs with (Debian's builds of them need glibc 2.42) or add a
# hundred libraries (Samba, GTK); without them only the plugin using them (ncurses interface,
# SFTP, SMB shares, notifications) does not load. Everything else is copied from the image
EXCLUDE='^(ld-linux-x86-64|libc|libm|libdl|libpthread|librt|libresolv|libutil|libanl|libmvec|libnss_.*|libBrokenLocale|libGL|libGLX|libGLdispatch|libOpenGL|libEGL|libGLESv1_CM|libGLESv2|libgbm|libdrm|libvulkan|libX11|libX11-xcb|libxcb|libasound|libjack|libpipewire-0\.3|libexpat|libz|libdbus-1|libudev|libsystemd|libtinfo|libncursesw|libssh|libsmbclient|libgtk-3|libgdk-3)\.so'

mkdir -p "$U/lib/deps"
elf_files() { find "$DIR" -type f \( -name '*.so*' -o -perm -u+x \) -exec file -N --mime-type {} + \
              | awk -F': ' '$2 ~ /application\/x-(sharedlib|executable|pie-executable)/ { print $1 }'; }

# VLC's own files without their debug information (the image's libraries come stripped)
while read -r f; do strip --strip-unneeded "$f"; done < <(elf_files)

# VLC's helper libraries (PulseAudio, PipeWire, XCB, VDPAU) sit in usr/lib/vlc
SEARCH="$U/lib:$U/lib/vlc:$U/lib/deps"

# copies the missing libraries until nothing new is needed: each file's own needed libraries
# (its NEEDED entries, found where ldd finds them), so an excluded library's own dependencies are
# never pulled in
for pass in 1 2 3 4 5 6 7 8; do
    added=0
    while read -r f; do
        needed=$("$PATCHELF" --print-needed "$f" 2>/dev/null) || continue
        [ -z "$needed" ] && continue
        LD_LIBRARY_PATH="$SEARCH" ldd "$f" 2>/dev/null | awk -v list="$needed" '
            BEGIN { n = split(list, names, "\n"); for (i = 1; i <= n; i++) want[names[i]] = 1 }
            /=> \// && ($1 in want) { print $1, $3 }'
    done < <(elf_files) | sort -u > /tmp/linux-package-deps.txt
    while read -r soname path; do
        case "$path" in "$DIR"/*) continue ;; esac
        echo "$soname" | grep -Eq "$EXCLUDE" && continue
        [ -e "$U/lib/deps/$soname" ] && continue
        cp -L "$path" "$U/lib/deps/$soname"
        added=$((added + 1))
    done < /tmp/linux-package-deps.txt
    echo "libraries pass $pass: $added added"
    [ "$added" = 0 ] && break
done

# not found anywhere: a missing library makes its plugin fail to load, never the app; listed
MISSING=$(while read -r f; do LD_LIBRARY_PATH="$SEARCH" ldd "$f" 2>/dev/null | grep 'not found' | sed "s|^|$f: |"; done < <(elf_files) | sort -u)
[ -n "$MISSING" ] && { echo "::warning::libraries not found:"; echo "$MISSING"; }

# RUNPATH of every program and library: its folder's way to usr/lib, usr/lib/vlc and usr/lib/deps
# (statically linked programs have none and are left as they are)
while read -r f; do
    [ -z "$("$PATCHELF" --print-needed "$f" 2>/dev/null)" ] && continue
    d=$(dirname "$f")
    lib=$(realpath --relative-to="$d" "$U/lib")
    vlc=$(realpath --relative-to="$d" "$U/lib/vlc")
    deps=$(realpath --relative-to="$d" "$U/lib/deps")
    "$PATCHELF" --set-rpath "\$ORIGIN/$lib:\$ORIGIN/$vlc:\$ORIGIN/$deps" "$f"
done < <(elf_files)

# the plugin cache keeps each plugin's size and time: rebuilt after the RUNPATH change, or VLC
# would load every plugin at each start
CACHEGEN=$(find "$U" -name vlc-cache-gen -type f | head -n 1)
"$CACHEGEN" "$U/lib/vlc/plugins"

# the oldest C library the package runs with: the newest GLIBC_ symbol version anything needs
GLIBC_MIN=$(while read -r f; do objdump -T "$f" 2>/dev/null | grep -o 'GLIBC_[0-9.]*'; done < <(elf_files) \
            | sed 's/GLIBC_//' | sort -uV | tail -n 1)
echo "needs glibc $GLIBC_MIN or newer"

# --- launcher, desktop file, icon, readme ---------------------------------------------------------
cat > "$DIR/$NAME" <<EOF
#!/bin/sh
# Starts $TITLE from this folder (also the AppImage's AppRun). With a folder named "portable" next
# to this file, or next to the AppImage file, $TITLE keeps its settings, media library and caches
# there instead of in your home folder.
HERE=\$(dirname "\$(readlink -f "\$0")")
BASE=\$HERE
[ -n "\$APPIMAGE" ] && BASE=\$(dirname "\$APPIMAGE")
if [ -d "\$BASE/portable" ]; then
    export XDG_CONFIG_HOME="\$BASE/portable/config"
    export XDG_DATA_HOME="\$BASE/portable/data"
    export XDG_CACHE_HOME="\$BASE/portable/cache"
fi
exec "\$HERE/usr/bin/vlc" "\$@"
EOF
chmod +x "$DIR/$NAME"

# the file types offered in "Open with": VLC's own list (share/vlc.desktop.mimetypes) without its
# URL schemes, plus the subtitle formats; listing them never makes the app the default one
MIMETYPES=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' /build/share/vlc.desktop.mimetypes \
            | grep -v -e '^$' -e '^x-scheme-handler/' | tr '\n' ';')
SUBTITLE_TYPES='application/x-subrip;text/x-ssa;text/vtt;text/x-microdvd;text/x-mpsub;text/x-subviewer;application/x-sami;'

if [ "$NAME" = cone ]; then
    # Cone Player's desktop integration: the desktop ID cone-player (VLC's is vlc), the same entry
    # and icons for the folder (install.sh), the AppImage (its integration tools read the top-level
    # .desktop and icon, and usr/share inside) and the .deb (linux-deb.sh)
    ID=cone-player
    BRAND_ICONS=/build/modules/gui/qt/pixmaps/brand/public
    for size in 16 24 32 48 64 128 256; do
        mkdir -p "$U/share/icons/hicolor/${size}x${size}/apps"
        cp "$BRAND_ICONS/cone-$size.png" "$U/share/icons/hicolor/${size}x${size}/apps/$ID.png"
    done
    # VLC's own menu entries, icons and AppStream file would show VLC in the AppImage's and the
    # .deb's integration
    rm -rf "$U/share/applications" "$U/share/metainfo"
    find "$U/share/icons" -name 'vlc*' -delete
    mkdir -p "$U/share/applications"
    {
        echo '[Desktop Entry]'
        echo 'Type=Application'
        echo 'Version=1.0'
        echo 'Name=Cone Player'
        echo 'GenericName=Media Player'
        echo 'Comment=Play your videos and music (based on VLC media player)'
        echo "Exec=$NAME %U"
        echo "Icon=$ID"
        echo 'Terminal=false'
        echo 'Categories=AudioVideo;Player;Video;Audio;'
        echo 'Keywords=Player;Video;Audio;Music;Movie;Subtitles;'
        echo 'StartupNotify=true'
        # the app's X11 window class and Wayland app id (BRAND_DESKTOP_FILE, brand.hpp)
        echo "StartupWMClass=$ID"
        echo "MimeType=$MIMETYPES$SUBTITLE_TYPES"
    } > "$U/share/applications/$ID.desktop"
    cp "$U/share/applications/$ID.desktop" "$DIR/$ID.desktop"
    cp "$BRAND_ICONS/cone-256.png" "$DIR/$ID.png"
    cp /build/extras/package/linux/install.sh /build/extras/package/linux/uninstall.sh "$DIR/"
    chmod +x "$DIR/install.sh" "$DIR/uninstall.sh"
    INSTALL_TEXT='Install for your user (no sudo): ./install.sh
  The program goes to ~/.local/share/cone-player, the command to ~/.local/bin/cone-player, and
  Cone Player appears in the applications menu and in "Open with" for video, audio and subtitle
  files. It does not make itself the default player. Run install.sh again from a newer folder to
  update.
Remove it: ~/.local/share/cone-player/uninstall.sh  (add --purge to also delete the settings,
  media library and caches)'
else
    cp "$ICON_SRC" "$DIR/$NAME.png"
    cat > "$DIR/$NAME.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$TITLE
GenericName=Media player
Comment=Play videos and music
Exec=$NAME %U
Icon=$NAME
Terminal=false
Categories=AudioVideo;Player;Video;Audio;
StartupWMClass=$NAME
MimeType=video/mp4;video/x-matroska;video/webm;video/quicktime;video/x-msvideo;video/mpeg;audio/mpeg;audio/flac;audio/ogg;audio/x-wav;audio/mp4;
EOF
    INSTALL_TEXT="Menu entry (optional): copy $NAME.desktop to ~/.local/share/applications/ and change its
Exec= line to the full path of \"$NAME\"; copy $NAME.png to ~/.local/share/icons/hicolor/256x256/apps/."
fi

cat > "$DIR/README-LINUX.txt" <<EOF
$TITLE $VERSION for Linux (x86_64), portable
$( [ "$NAME" = cone ] && echo "Based on VLC media player. " )Built in VideoLAN's Debian build image.

Start: ./$NAME  (or ./$NAME <file or URL>)
Needs: a 64-bit Linux desktop (X11 or Wayland) with glibc $GLIBC_MIN or newer, OpenGL drivers,
X11 libraries (libX11, libxcb) and PulseAudio, PipeWire or ALSA.

Settings: ~/.config/$( [ "$NAME" = cone ] && echo Cone || echo vlc ), media library and data: ~/.local/share/$( [ "$NAME" = cone ] && echo Cone || echo vlc ), caches: ~/.cache/$( [ "$NAME" = cone ] && echo Cone || echo vlc ).
Portable mode: create a folder named "portable" next to "$NAME"; everything then stays in it.

$INSTALL_TEXT
EOF

cd "$OUT"
tar -cJf "$PKG.tar.xz" "$PKG"
ls -la "$OUT"
du -sh "$DIR"
