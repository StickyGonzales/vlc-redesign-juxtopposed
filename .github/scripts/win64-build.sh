#!/bin/bash
# Runs inside VideoLAN's win64 build image (.github/workflows/build-windows.yml), with the checkout
# mounted at /build.
#   win64-build.sh build      build.sh through ccache, then the portable zip
#   win64-build.sh installer  the NSIS installer of an already built tree (make package-win32-exe)
#   win64-build.sh stage-for-signing          release signing: stage the tree, copy Cone.exe to sign/unsigned
#   win64-build.sh package-signed <Cone.exe>  release signing: the installer and zip with the signed Cone.exe
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
stage-for-signing)
    # release signing (CODE_SIGNING_POLICY.md): the package folder staged and stripped as the
    # installer takes it, then its Cone.exe is handed to the workflow, which sends it to SignPath
    cd win64
    make package-win32-src
    set -- vlc-*/Cone.exe
    [ $# -eq 1 ] && [ -f "$1" ] || { echo "::error::expected one vlc-*/Cone.exe, found: $*"; exit 1; }
    mkdir -p /build/sign/unsigned
    cp "$1" /build/sign/unsigned/Cone.exe
    echo "staged for signing: win64/$1"
    ;;
package-signed)
    # release signing: the signed Cone.exe ($2, relative to /build) into the staged package folder,
    # then the installer and the zip of that folder as it is (package.mak's *-staged targets: no new
    # staging or stripping, which would undo the signature). SIGNING_DRY_RUN=true (the workflow's
    # signing-dry-run input) takes the unsigned file, to check this path without SignPath.
    SIGNED=/build/$2
    [ -f "$SIGNED" ] || { echo "::error::no signed Cone.exe at $2"; exit 1; }
    cd win64
    set -- vlc-*/Cone.exe
    [ $# -eq 1 ] && [ -f "$1" ] || { echo "::error::expected one vlc-*/Cone.exe, found: $*"; exit 1; }
    STAGED=$1
    if [ "${SIGNING_DRY_RUN:-}" != true ] && cmp -s "$SIGNED" "$STAGED"; then
        echo "::error::the signed Cone.exe is the same file as the unsigned one"
        exit 1
    fi
    cp "$SIGNED" "$STAGED"
    # the zip first: makensis writes spad-setup.exe into the folder, which the zip's exclude list
    # does not catch (the normal build makes its zip before any installer too)
    make package-win32-zip-staged BRAND_PACKAGE_SUFFIX="${BRAND_PACKAGE_SUFFIX:-}"
    make package-win32-exe-staged
    # the folder both packages were made from still holds exactly that Cone.exe (the workflow
    # checks the zip's copy on the runner)
    cmp "$STAGED" "$SIGNED"
    ls -la ./*-win64.zip ./*-win64.exe
    ;;
*)
    echo "usage: $0 build|installer|stage-for-signing|package-signed <signed Cone.exe>" >&2
    exit 2
    ;;
esac
