#!/bin/sh
# Cone's QtCore-only unit tests (the test_rd_* programs of modules/gui/qt/Makefile.am): built
# with the system's Qt 6 and run; the build workflows do not run them. A failed test fails the
# script. Used by unit-tests.yml; locally: .github/scripts/unit-tests.sh <out dir>
# SANITIZE=1: built with AddressSanitizer and UndefinedBehaviorSanitizer, and any report (a leak
# included) fails the test (redesign/PERF_AUDIT_NOTES.md)
set -eu
OUT="${1:-/tmp/cone-unit-tests}"
mkdir -p "$OUT"
cd "$(dirname "$0")/../../modules/gui/qt"
CFLAGS="$(pkg-config --cflags Qt6Core) -std=c++17 -fPIC -Wall -Wextra -I."
if [ -n "${SANITIZE:-}" ]; then
    CFLAGS="$CFLAGS -g -O1 -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=undefined"
    export ASAN_OPTIONS="${ASAN_OPTIONS:-detect_leaks=1:abort_on_error=0}"
    export UBSAN_OPTIONS="${UBSAN_OPTIONS:-print_stacktrace=1}"
fi
LIBS="$(pkg-config --libs Qt6Core) -lpthread"
MOC="${MOC:-$(pkg-config --variable=libexecdir Qt6Core)/moc}"

failed=0
run() {
    name="$1"; shift
    echo "== $name"
    # shellcheck disable=SC2086
    if ! g++ $CFLAGS "$@" $LIBS -o "$OUT/$name"; then
        echo "BUILD FAILED: $name"; failed=1; return
    fi
    if ! timeout 120 "$OUT/$name"; then
        echo "FAILED: $name"; failed=1
    fi
}

"$MOC" util/rd_background_queue.hpp -o "$OUT/moc_rd_background_queue.cpp"

run test_rd_storage_model tests/test_rd_storage_model.cpp util/rd_storage_model.cpp
run test_rd_background_queue tests/test_rd_background_queue.cpp util/rd_background_queue.cpp "$OUT/moc_rd_background_queue.cpp"
run test_rd_show_tracks tests/test_rd_show_tracks.cpp player/rd_show_tracks.cpp
run test_rd_episode_parser tests/test_rd_episode_parser.cpp player/rd_episode_parser.cpp dialogs/redesign/addsubtitles/subtitle_matcher.cpp
run test_rd_credits_audio tests/test_rd_credits_audio.cpp player/rd_credits_audio.cpp
run test_rd_credits_point tests/test_rd_credits_point.cpp player/rd_credits_point.cpp
run test_rd_osd_parse tests/test_rd_osd_parse.cpp player/rd_osd_parse.cpp
run test_rd_reload_throttle tests/test_rd_reload_throttle.cpp
run test_rd_up_next_mode tests/test_rd_up_next_mode.cpp

exit $failed
