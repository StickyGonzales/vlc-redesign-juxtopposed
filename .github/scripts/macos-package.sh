#!/bin/bash
# "Cone Player.app" and its .dmg from a macOS build's make install (macos-build.sh package;
# redesign/MACOS_NOTES.md). The layout is VLC.app's (extras/package/macosx/package.mak) without
# VLC's native interface:
#   Contents/MacOS/Cone Player        VLC's macOS binary (bin/darwinvlc.m), renamed
#   Contents/MacOS/vlc-preparser      VLC's helpers: the bundle's auxiliary executables
#   Contents/MacOS/vlc-qt-check
#   Contents/Frameworks/libvlc*.dylib, plugins/, Qt*.framework (macdeployqt)
#   Contents/PlugIns/                 Qt's own plugins (platform, style, image formats; macdeployqt)
#   Contents/Resources/share/         Lua scripts, HRTFs, translations; qml/ (Qt Quick modules)
# Signed ad hoc (no Apple developer account): Gatekeeper asks once (MACOS_NOTES.md).
#   macos-package.sh <make install folder> <out folder> <arm64|x86_64>
# Environment: QT_ROOT (macdeployqt), BRAND_VERSION, BRAND_PACKAGE_SUFFIX
set -euo pipefail

SRC="$(cd "$1" && pwd)"
OUT="$2"
ARCH="$3"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="${BRAND_VERSION:-0.1.0}"
NAME="Cone Player"
APP="$OUT/$NAME.app"
C="$APP/Contents"
: "${QT_ROOT:?QT_ROOT is not set}"

mkdir -p "$OUT"
rm -rf "$APP"
mkdir -p "$C/MacOS" "$C/Frameworks/plugins" "$C/Resources/share"

# --- binaries -------------------------------------------------------------------------------------
cp "$SRC/bin/vlc" "$C/MacOS/$NAME"
for helper in vlc-preparser vlc-qt-check; do
    found="$(find "$SRC" -type f -name "$helper" | head -n 1)"
    [ -n "$found" ] || { echo "::error::$helper is missing from the build"; exit 1; }
    cp "$found" "$C/MacOS/$helper"
done
cp -a "$SRC"/lib/libvlc*.dylib "$C/Frameworks/"
# every plugin, flat, as VLC.app has them
find "$SRC/lib/vlc/plugins" -name 'lib*_plugin.dylib' -exec cp -a {} "$C/Frameworks/plugins/" \;
echo "$(find "$C/Frameworks/plugins" -name '*.dylib' | wc -l | tr -d ' ') plugins"
[ -e "$C/Frameworks/plugins/libqt_plugin.dylib" ] || { echo "::error::the Qt interface plugin was not built"; exit 1; }
[ ! -e "$C/Frameworks/plugins/libmacosx_plugin.dylib" ] || { echo "::error::VLC's native macOS interface was built: Cone uses the Qt interface"; exit 1; }
# the binaries find libvlc in the bundle: make install linked them with the install's library
# folder as their search path, which is replaced
for exe in "$C/MacOS/$NAME" "$C/MacOS/vlc-preparser"; do
    otool -l "$exe" | awk '/cmd LC_RPATH/ { getline; getline; print $2 }' | while read -r rp; do
        install_name_tool -delete_rpath "$rp" "$exe"
    done
    install_name_tool -add_rpath "@executable_path/../Frameworks/" "$exe"
    otool -l "$exe" | grep -A2 LC_RPATH | grep path
done

# --- data -----------------------------------------------------------------------------------------
cp -R "$SRC/share/vlc/lua" "$C/Resources/share/"
cp -R "$ROOT/share/hrtfs" "$C/Resources/share/"
[ -d "$SRC/share/locale" ] && cp -R "$SRC/share/locale" "$C/Resources/share/"

# --- icon: Cone's logo at every size macOS asks for -------------------------------------------------
ICONSET="$(mktemp -d)/cone.iconset"
mkdir -p "$ICONSET"
ICON_SRC="$ROOT/modules/gui/qt/pixmaps/brand/public/cone-256.png"
for s in 16 32 128 256; do
    sips -z $s $s "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}.png" > /dev/null
    d=$((s * 2))
    sips -z $d $d "$ICON_SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$C/Resources/cone.icns"

# --- Info.plist -----------------------------------------------------------------------------------
# own bundle identifier: Cone keeps its settings in ~/Library/Preferences/<identifier> and
# ~/Library/Application Support/<identifier> (src/darwin/dirs.m), apart from VLC's
cat > "$C/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleDisplayName</key><string>$NAME</string>
    <key>CFBundleExecutable</key><string>$NAME</string>
    <key>CFBundleIconFile</key><string>cone</string>
    <key>CFBundleIdentifier</key><string>io.github.stickygonzales.coneplayer</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleGetInfoString</key><string>Cone Player $VERSION (experimental), based on VLC media player</string>
    <key>NSHumanReadableCopyright</key><string>Built by StickyGonzales, based on VLC media player (GPLv2 or later). Not a VideoLAN product.</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.entertainment</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSLocalNetworkUsageDescription</key><string>Cone Player looks for media servers and devices on your network (UPnP, Bonjour) for its Network view.</string>
</dict>
</plist>
EOF
plutil -lint "$C/Info.plist"
printf 'APPL????' > "$C/PkgInfo"

# --- Qt: frameworks, plugins and Qt Quick modules ---------------------------------------------------
# macdeployqt follows the Qt interface plugin and vlc-qt-check (the main binary has no Qt), copies
# the frameworks into Contents/Frameworks, Qt's plugins into Contents/PlugIns and the Qt Quick
# modules the interface's QML imports into Contents/Resources/qml, rewrites their load paths and
# writes Contents/Resources/qt.conf
"$QT_ROOT/bin/macdeployqt" "$APP" \
    -qmldir="$ROOT/modules/gui/qt" \
    -executable="$C/Frameworks/plugins/libqt_plugin.dylib" \
    -executable="$C/MacOS/vlc-qt-check" \
    -verbose=1
cat "$C/Resources/qt.conf"
# Qt's SQL drivers come with QtSql's plugins, which the interface never loads; they point at
# database client libraries that are not there (macdeployqt: "no file at ...libpq...")
rm -rf "$C/PlugIns/sqldrivers"
rm -rf "$C/Frameworks/QtSql.framework"
if otool -L "$C/Frameworks/plugins/libqt_plugin.dylib" | grep -q QtSql; then
    echo "::error::the Qt interface links QtSql: keep it"; exit 1
fi
for f in QtCore QtGui QtQml QtQuick QtWidgets QtSvg QtQuickControls2; do
    [ -d "$C/Frameworks/$f.framework" ] || { echo "::error::$f.framework is missing from the app"; exit 1; }
done
[ -e "$C/PlugIns/platforms/libqcocoa.dylib" ] || { echo "::error::Qt's Cocoa platform plugin is missing"; exit 1; }
# nothing in the app may still load from the build machine's Qt
if otool -L "$C/Frameworks/plugins/libqt_plugin.dylib" "$C/MacOS/vlc-qt-check" | grep -F "$QT_ROOT"; then
    echo "::error::the app still links Qt from $QT_ROOT"
    exit 1
fi

# --- ad-hoc signature, inside out (as extras/package/macosx/codesign.sh): the plug-ins and their
# cache, the libraries, Qt's plug-ins and Qt Quick modules, the helpers, the frameworks, then the
# app, which signs its main executable. Codesign checks every file under Contents/Frameworks
# when it signs the app: plugins.dat, which is data, is signed too (its signature goes into an
# extended attribute), or the app's signature fails ("plugins.dat: code object is not signed",
# run 41331290193)
sign() {
    codesign --force --sign - --timestamp=none "$1"
}
is_macho() {
    file -b "$1" | grep -q 'Mach-O'
}
while IFS= read -r -d '' f; do
    sign "$f"
done < <(find "$C/Frameworks/plugins" -type f -name '*.dylib' -print0)

# the plug-in cache after the plug-ins are signed: signing changes them, and a cache made before
# is stale ("stale plugins cache: modified ...", every plug-in loaded again at each start, run
# 41333588279). The installed generator (bin/vlc-cache-gen in the build folder is libtool's
# wrapper script) loads libvlccore from the install, as make install's own run of it does
CACHE_GEN="$SRC/libexec/vlc/vlc-cache-gen"
if [ "$(uname -m)" = "$ARCH" ]; then
    [ -x "$CACHE_GEN" ] || { echo "::error::$CACHE_GEN is missing"; exit 1; }
    DYLD_LIBRARY_PATH="$SRC/lib" "$CACHE_GEN" "$C/Frameworks/plugins"
    ls -la "$C/Frameworks/plugins/plugins.dat"
    sign "$C/Frameworks/plugins/plugins.dat"
fi
while IFS= read -r -d '' f; do
    sign "$f"
done < <(find "$C/Frameworks" -maxdepth 1 -type f -name '*.dylib' -print0)
while IFS= read -r -d '' f; do
    if is_macho "$f"; then sign "$f"; fi
done < <(find "$C/PlugIns" "$C/Resources" -type f -print0)
for helper in vlc-preparser vlc-qt-check; do
    sign "$C/MacOS/$helper"
done
while IFS= read -r -d '' fw; do
    sign "$fw"
done < <(find "$C/Frameworks" -maxdepth 1 -name '*.framework' -print0)
# anything else under Frameworks outside the frameworks is signed the same way (VLC signs its
# plug-ins' .jar like this)
while IFS= read -r -d '' f; do
    echo "signing a file that is not a library: ${f#"$C/"}"
    sign "$f"
done < <(find "$C/Frameworks" -type f ! -path '*.framework/*' ! -name '*.dylib' ! -name plugins.dat -print0)
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "app: $(du -sh "$APP" | cut -f1)"

# --- dmg: the app and a link to Applications ---------------------------------------------------------
DMG="$OUT/Cone-$VERSION${BRAND_PACKAGE_SUFFIX:-}-macos-$ARCH.dmg"
STAGE="$(mktemp -d)/Cone Player"
mkdir -p "$STAGE"
# ditto keeps the files' times: VLC checks its plug-in cache against them (to the second), and a
# plain copy made every plug-in look modified ("stale plugins cache", run 41336561372)
ditto "$APP" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/COPYING" "$STAGE/COPYING.txt"
rm -f "$DMG"
hdiutil create -srcfolder "$STAGE" -volname "Cone Player" -format UDBZ -fs HFS+ -o "$DMG"
hdiutil verify "$DMG"
echo "dmg: $(basename "$DMG") ($(du -h "$DMG" | cut -f1))"
