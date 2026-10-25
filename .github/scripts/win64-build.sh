#!/bin/bash
# Runs inside VideoLAN's win64 build image (.github/workflows/build-windows.yml), with the checkout
# mounted at /build.
#   win64-build.sh build      build.sh through ccache, then the portable zip
#   win64-build.sh installer  the NSIS installer of an already built tree (make package-win32-exe)
# Environment: VLC_BRAND (vlc or public), VLC_PREBUILT_CONTRIBS_URL (empty: contribs from source),
# BRAND_VERSION (public profile's version), BRAND_PACKAGE_SUFFIX (public package names, e.g. -beta).
#
# ccache only skips compiling a file it has compiled before with the same compiler, flags and
# preprocessed source, and returns that compiler output byte for byte, so the build produces the
# same files with or without it. It sits in front of the cross compilers through "masquerade"
# links (ccache named like the compiler, first in PATH): build.sh and its configure run unchanged.
set -e

cd /build
git config --global --add safe.directory /build
TRIPLET=x86_64-w64-mingw32

ccache_setup()
{
    CCACHE=$(command -v ccache || true)
    # the image has no ccache: the binary the workflow downloaded (pinned version, checked SHA-256)
    if [ -z "$CCACHE" ] && [ -x /build/.ccache-tool/ccache ]; then
        CCACHE=/build/.ccache-tool/ccache
    fi
    if [ -z "$CCACHE" ]; then
        echo "::warning::no ccache available, building without the compiler cache"
        return
    fi
    export CCACHE_DIR=/build/.ccache
    export CCACHE_MAXSIZE=${CCACHE_MAXSIZE:-2G}
    # a new build image (other compiler binary) never reuses old results
    export CCACHE_COMPILERCHECK=content
    mkdir -p "$CCACHE_DIR" /tmp/ccache-bin
    local wrapped=""
    for c in gcc g++ cc c++ clang clang++; do
        if command -v "$TRIPLET-$c" >/dev/null; then
            ln -sf "$CCACHE" "/tmp/ccache-bin/$TRIPLET-$c"
            wrapped="$wrapped $TRIPLET-$c"
        fi
    done
    export PATH="/tmp/ccache-bin:$PATH"
    echo "ccache: $("$CCACHE" --version | head -n 1) at $CCACHE"
    echo "ccache: cache dir $CCACHE_DIR, max size $CCACHE_MAXSIZE, compilers:$wrapped"
    echo "ccache: restored cache before the build:"
    "$CCACHE" --show-stats || true
    "$CCACHE" --zero-stats >/dev/null
    trap ccache_report EXIT
}

ccache_report()
{
    echo "::group::ccache statistics of this build"
    "$CCACHE" --show-stats --verbose || "$CCACHE" --show-stats || true
    echo "::endgroup::"
    # one line for the job summary: hits of this build (direct + preprocessed) against misses
    "$CCACHE" --print-stats 2>/dev/null | awk '
        $1 == "direct_cache_hit" { d = $2 } $1 == "preprocessed_cache_hit" { p = $2 }
        $1 == "cache_miss" { m = $2 }
        END { t = d + p + m; printf "ccache: %d hits (%d direct, %d preprocessed), %d misses, hit rate %s\n",
              d + p, d, p, m, t ? sprintf("%.1f%%", 100 * (d + p) / t) : "n/a" }' | tee /build/.ccache-summary.txt
}

case "$1" in
build)
    ccache_setup
    P=""
    if [ -n "$VLC_PREBUILT_CONTRIBS_URL" ]; then P="-p"; else unset VLC_PREBUILT_CONTRIBS_URL; fi
    extras/package/win32/build.sh -r -a x86_64 $P -B "$VLC_BRAND"
    cd win64
    # BRAND_PACKAGE_SUFFIX (public profile, e.g. -beta): package names only, never the version
    make package-win32-zip BRAND_PACKAGE_SUFFIX="${BRAND_PACKAGE_SUFFIX:-}"
    ;;
installer)
    cd win64
    make package-win32-exe
    ;;
*)
    echo "usage: $0 build|installer" >&2
    exit 2
    ;;
esac
