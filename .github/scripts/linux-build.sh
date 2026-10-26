#!/bin/bash
# Runs inside VideoLAN's Debian build image (VLC_DEBIAN_IMAGE in extras/ci/gitlab-ci.yml, used by
# .github/workflows/build-linux.yml), with the checkout mounted at /build.
#   linux-build.sh build    the media library from VLC's contrib, then VLC with the image's system
#                           libraries (autotools, like VideoLAN's own "debian" job) through ccache,
#                           installed into stage/
#   linux-build.sh package  the portable Cone folder and its tarball (redesign/LINUX_NOTES.md)
# Environment: VLC_BRAND (vlc or public), BRAND_VERSION (public profile's version),
# BRAND_PACKAGE_SUFFIX (public package names, e.g. -beta).
set -e

cd /build
git config --global --add safe.directory /build
NCPU=$(getconf _NPROCESSORS_ONLN)
PREFIX=/usr
STAGE=/build/stage
CONTRIB_PREFIX=/build/contrib/linux-ml

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
    export CCACHE_COMPILERCHECK=content
    # every path is under /build in the image, so the results stay valid between runs
    export CCACHE_BASEDIR=/build
    mkdir -p "$CCACHE_DIR"
    export CC="$CCACHE gcc" CXX="$CCACHE g++"
    echo "ccache: $("$CCACHE" --version | head -n 1) at $CCACHE"
    "$CCACHE" --zero-stats >/dev/null
    trap ccache_report EXIT
}

ccache_report()
{
    "$CCACHE" --show-stats || true
    "$CCACHE" --print-stats 2>/dev/null | awk '
        $1 == "direct_cache_hit" { d = $2 } $1 == "preprocessed_cache_hit" { p = $2 }
        $1 == "cache_miss" { m = $2 }
        END { t = d + p + m; printf "ccache: %d hits (%d direct, %d preprocessed), %d misses, hit rate %s\n",
              d + p, d, p, m, t ? sprintf("%.1f%%", 100 * (d + p) / t) : "n/a" }' | tee /build/.ccache-summary.txt
}

# the media library: the image has no package of it, so VLC's own contrib recipe builds it (static,
# linked into the media library plugin); its dependency sqlite comes from the image
build_medialibrary()
{
    if [ -f "$CONTRIB_PREFIX/lib/pkgconfig/medialibrary.pc" ]; then
        echo "medialibrary: already built in $CONTRIB_PREFIX"
        return
    fi
    mkdir -p contrib/linux-ml-build
    (
        cd contrib/linux-ml-build
        ../bootstrap --prefix="$CONTRIB_PREFIX"
        make -j"$NCPU" .medialibrary
    )
}

build()
{
    ccache_setup
    build_medialibrary

    local brand=()
    if [ -n "$VLC_BRAND" ]; then brand+=(--with-brand="$VLC_BRAND"); fi
    if [ "$VLC_BRAND" = public ] && [ -n "$BRAND_VERSION" ]; then
        brand+=(--with-brand-version="$BRAND_VERSION")
    fi
    # a release build without run-time assertions, as the Windows build (extras/package/win32/
    # build.sh -r): VLC's configure keeps them on by default, and a failed one ends the player
    local extra=(--disable-debug)
    # public: no skins interface (Cone has only the redesign); the update checker is off on
    # Linux anyway (configure's default)
    if [ "$VLC_BRAND" = public ]; then extra+=(--disable-skins2); fi

    ./bootstrap
    mkdir -p build-linux
    cd build-linux
    ../configure --prefix="$PREFIX" --with-contrib="$CONTRIB_PREFIX" \
        "${brand[@]}" "${extra[@]}" \
        || { tail -n 80 config.log; exit 1; }
    grep -E "^(#define VLC_BRAND_PUBLIC|#define BRAND_VERSION)" config.h || true
    make -j"$NCPU"
    rm -rf "$STAGE"
    make install DESTDIR="$STAGE"
    # the plugin cache, as VLC's packages ship it (vlc-cache-gen on the installed plugins)
    local cachegen
    cachegen=$(find "$STAGE$PREFIX" -name vlc-cache-gen -type f | head -n 1)
    LD_LIBRARY_PATH="$STAGE$PREFIX/lib" "$cachegen" "$STAGE$PREFIX/lib/vlc/plugins"
}

case "$1" in
build)
    build
    ;;
package)
    .github/scripts/linux-package.sh "$STAGE$PREFIX"
    ;;
*)
    echo "usage: $0 build|package" >&2
    exit 2
    ;;
esac
