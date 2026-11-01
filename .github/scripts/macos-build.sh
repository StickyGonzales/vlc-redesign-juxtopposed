#!/bin/bash
# Experimental macOS build of Cone (the public profile) on a GitHub macOS runner
# (build-macos.yml, redesign/MACOS_NOTES.md). VLC's own macOS steps
# (extras/package/macosx/build.sh): its extra tools, VideoLAN's prebuilt contribs, then VLC with
# autotools. Two differences: the interface is Qt (Cone's redesign) instead of VLC's native macOS
# interface, which is not built, and Qt comes from Qt's own macOS binaries (VLC's contribs build
# no Qt for macOS).
#   macos-build.sh build      tools, contribs, configure, make, make install into macos-install/
#   macos-build.sh package    "Cone Player.app" and its .dmg in macos/ (macos-package.sh)
# Environment:
#   HOST_ARCH                  aarch64 (Apple Silicon) or x86_64 (Intel)
#   QT_ROOT                    Qt 6 for macOS (the folder with bin/qmake)
#   VLC_PREBUILT_CONTRIBS_URL  VideoLAN's prebuilt contribs for this source (empty: built from source)
#   BRAND_VERSION              Cone's version (empty: configure's default)
#   VLC_CCACHE_BINS_PATH       optional: a folder with cc / c++ links to ccache
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="$ROOT/build-macos"
DEST="$ROOT/macos-install"
MODE="${1:-build}"
JOBS="$(sysctl -n hw.ncpu)"
# Qt 6.8 runs on macOS 12 and later: the app's minimum (VLC's own macOS app says 10.13)
MIN_MACOS=12.0

: "${HOST_ARCH:?HOST_ARCH is not set}"
: "${QT_ROOT:?QT_ROOT is not set}"

# VLC's macOS build environment (compilers, ac_cv_* overrides, contrib flags). It resets PATH:
# VLC_PATH is appended to it, so the Qt tools come through there. Never Homebrew's folder:
# extras/tools then takes Homebrew's autotools and pkg-config instead of building its own, and
# autoconf misses their macros (run 41321099631). python3 is the system's (/usr/bin)
export VLC_FORCE_KERNELVERSION=19
# configure looks for "qmake6"; Qt's macOS binaries call it "qmake"
SHIM="$ROOT/.qt-shim"
mkdir -p "$SHIM"
ln -sf "$QT_ROOT/bin/qmake" "$SHIM/qmake6"
export VLC_PATH="$SHIM:$QT_ROOT/bin"
# found before VLC's environment resets PATH
CCACHE_BIN="$(command -v ccache || true)"
# shellcheck source=/dev/null
source "$ROOT/extras/package/macosx/env.build.sh" none
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export SDKROOT
BUILD_TRIPLET="$(vlcGetBuildTriplet)"
HOST_TRIPLET="$(vlcGetHostTriplet)"
ACTUAL_HOST_ARCH="$(get_actual_arch "$HOST_ARCH")"

build() {
    vlcSetBaseEnvironment
    echo "Building Cone for macOS $ACTUAL_HOST_ARCH ($HOST_TRIPLET) on $BUILD_TRIPLET, SDK $SDKROOT"
    echo "Qt: $("$SHIM/qmake6" -query QT_VERSION) at $QT_ROOT"

    echo "::group::extras/tools"
    (cd "$ROOT/extras/tools" && ./bootstrap && make -j"$JOBS")
    echo "::endgroup::"

    mkdir -p "$BUILD/contrib/contrib-$HOST_TRIPLET"
    vlcSetSymbolEnvironment
    vlcSetContribEnvironment "$MINIMAL_OSX_VERSION"
    echo "::group::contribs"
    (
        cd "$BUILD/contrib/contrib-$HOST_TRIPLET"
        "$ROOT/contrib/bootstrap" --build="$BUILD_TRIPLET" --host="$HOST_TRIPLET" --enable-sections
        if [ ! -e "../$HOST_TRIPLET" ]; then
            if [ -n "${VLC_PREBUILT_CONTRIBS_URL:-}" ] \
                    && make prebuilt PREBUILT_URL="$VLC_PREBUILT_CONTRIBS_URL"; then
                make -j"$JOBS" tools
            else
                echo "::warning::no prebuilt contribs: building them from source (slow)"
                make -j"$JOBS" fetch
                make -j"$JOBS" -k || make -j1
            fi
        fi
        # VideoLAN's prebuilt contribs name their build machine's SDK (…/MacOSX26.2.sdk) in their
        # pkg-config and libtool files; a link with a missing SDK loses the system libraries
        # ("library 'm' not found", run 41323064735): point them at this runner's SDK
        local_files="$(grep -rlE '/SDKs/MacOSX[0-9.]*\.sdk' "../$HOST_TRIPLET/lib" 2>/dev/null \
            | grep -E '\.(pc|la)$' || true)"
        for f in $local_files; do
            sed -i '' -E "s#/[^ \"']*/SDKs/MacOSX[0-9.]*\.sdk#$SDKROOT#g" "$f"
            echo "SDK path set in ${f#../}"
        done
    )
    echo "::endgroup::"
    vlcUnsetContribEnvironment
    vlcSetLibVLCEnvironment

    echo "::group::bootstrap and configure"
    [ -e "$ROOT/configure" ] || (cd "$ROOT" && ./bootstrap)
    local brand=(--with-brand=public)
    if [ -n "${BRAND_VERSION:-}" ]; then brand+=(--with-brand-version="$BRAND_VERSION"); fi
    cd "$BUILD"
    # VLC's macOS options (configure.sh), then Cone's: the Qt interface instead of the native
    # one (the later option wins), no Sparkle updater (Cone has its own update notice), no
    # crash reporter, and no debug checks that end the player on a failed assertion
    "$ROOT/extras/package/macosx/configure.sh" \
        --build="$BUILD_TRIPLET" \
        --host="$HOST_TRIPLET" \
        --with-contrib="contrib/$HOST_TRIPLET" \
        --with-macosx-sdk="$SDKROOT" \
        --with-macosx-version-min="$MIN_MACOS" \
        --disable-macosx \
        --disable-sparkle \
        --enable-qt \
        --disable-debug \
        "${brand[@]}"
    grep -E "^(#define VLC_BRAND_PUBLIC|#define BRAND_VERSION)" config.h || true
    echo "::endgroup::"

    make -j"$JOBS"

    echo "::group::make install"
    rm -rf "$DEST"
    make install DESTDIR="$DEST"
    echo "::endgroup::"
    if [ -n "${VLC_CCACHE_BINS_PATH:-}" ] && [ -n "$CCACHE_BIN" ]; then
        "$CCACHE_BIN" --show-stats | tee "$ROOT/.ccache-summary.txt" || true
    fi
}

case "$MODE" in
    build) build ;;
    package)
        exec "$ROOT/.github/scripts/macos-package.sh" "$DEST" "$ROOT/macos" "$ACTUAL_HOST_ARCH"
        ;;
    *) echo "usage: $0 build|package" >&2; exit 2 ;;
esac
