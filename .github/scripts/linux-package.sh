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
#   cone.desktop, cone.png, README-LINUX.txt
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
# the portal theme only (native file dialogs through xdg-desktop-portal); the GTK one would pull
# in GTK
mkdir -p "$U/lib/qt6/plugins/platformthemes"
cp -a "$QT_PLUGINS"/platformthemes/libqxdgdesktopportal.so "$U/lib/qt6/plugins/platformthemes/" 2>/dev/null || true
# the modules the interface imports (QtQuick, its Controls, Templates, Layouts, Window, QtQml)
cp -a "$QT_QML/QtQml" "$QT_QML/QtQuick" "$U/lib/qt6/qml/"
rm -rf "$U/lib/qt6/qml/QtQuick/"{Particles,LocalStorage,Scene2D,Scene3D,VectorImage,tooling}
cat > "$U/bin/qt.conf" <<'EOF'
[Paths]
Prefix = ..
Plugins = lib/qt6/plugins
QmlImports = lib/qt6/qml
EOF

# --- libraries ------------------------------------------------------------------------------------
# provided by the system: the C library, graphics drivers and their loaders, X11 and its core
# connection, sound servers, fonts and their configuration, D-Bus, udev (the same idea as
# AppImage's exclude list); everything else the programs need is copied from the image
EXCLUDE='^(ld-linux-x86-64|libc|libm|libdl|libpthread|librt|libresolv|libutil|libanl|libmvec|libnss_.*|libBrokenLocale|libGL|libGLX|libGLdispatch|libOpenGL|libEGL|libGLESv1_CM|libGLESv2|libgbm|libdrm|libvulkan|libva|libva-drm|libva-x11|libva-wayland|libvdpau|libX11|libX11-xcb|libxcb|libasound|libjack|libpipewire-0\.3|libfontconfig|libfreetype|libharfbuzz|libexpat|libz|libdbus-1|libudev|libsystemd)\.so'

mkdir -p "$U/lib/deps"
elf_files() { find "$DIR" -type f \( -name '*.so*' -o -perm -u+x \) -exec file -N --mime-type {} + \
              | awk -F': ' '$2 ~ /application\/x-(sharedlib|executable|pie-executable)/ { print $1 }'; }

# copies the missing libraries until nothing new is needed
for pass in 1 2 3 4 5 6; do
    added=0
    while read -r f; do
        LD_LIBRARY_PATH="$U/lib:$U/lib/deps" ldd "$f" 2>/dev/null | awk '/=> \// { print $1, $3 }'
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
MISSING=$(while read -r f; do LD_LIBRARY_PATH="$U/lib:$U/lib/deps" ldd "$f" 2>/dev/null | grep 'not found' | sed "s|^|$f: |"; done < <(elf_files) | sort -u)
[ -n "$MISSING" ] && { echo "::warning::libraries not found:"; echo "$MISSING"; }

# RUNPATH of every program and library: its folder's way to usr/lib and usr/lib/deps
# (statically linked programs have none and are left as they are)
while read -r f; do
    [ -z "$("$PATCHELF" --print-needed "$f" 2>/dev/null)" ] && continue
    d=$(dirname "$f")
    lib=$(realpath --relative-to="$d" "$U/lib")
    deps=$(realpath --relative-to="$d" "$U/lib/deps")
    "$PATCHELF" --set-rpath "\$ORIGIN/$lib:\$ORIGIN/$deps" "$f"
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
# Starts $TITLE from this folder. With a folder named "portable" next to this file, $TITLE keeps
# its settings, media library and caches there instead of in your home folder.
HERE=\$(dirname "\$(readlink -f "\$0")")
if [ -d "\$HERE/portable" ]; then
    export XDG_CONFIG_HOME="\$HERE/portable/config"
    export XDG_DATA_HOME="\$HERE/portable/data"
    export XDG_CACHE_HOME="\$HERE/portable/cache"
fi
exec "\$HERE/usr/bin/vlc" "\$@"
EOF
chmod +x "$DIR/$NAME"

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

cat > "$DIR/README-LINUX.txt" <<EOF
$TITLE $VERSION for Linux (x86_64), portable
$( [ "$NAME" = cone ] && echo "Based on VLC media player. " )Built in VideoLAN's Debian build image.

Start: ./$NAME  (or ./$NAME <file or URL>)
Needs: a 64-bit Linux desktop (X11 or Wayland) with glibc $GLIBC_MIN or newer, OpenGL drivers,
X11 libraries (libX11, libxcb), fontconfig and freetype, and PulseAudio, PipeWire or ALSA.

Settings: ~/.config/$( [ "$NAME" = cone ] && echo Cone || echo vlc ), media library and data: ~/.local/share/$( [ "$NAME" = cone ] && echo Cone || echo vlc ), caches: ~/.cache/$( [ "$NAME" = cone ] && echo Cone || echo vlc ).
Portable mode: create a folder named "portable" next to "$NAME"; everything then stays in it.

Menu entry (optional): copy $NAME.desktop to ~/.local/share/applications/ and change its
Exec= line to the full path of "$NAME"; copy $NAME.png to ~/.local/share/icons/hicolor/256x256/apps/.
EOF

cd "$OUT"
tar -cJf "$PKG.tar.xz" "$PKG"
ls -la "$OUT"
du -sh "$DIR"
