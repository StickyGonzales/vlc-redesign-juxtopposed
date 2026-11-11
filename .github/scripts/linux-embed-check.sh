#!/bin/bash
# Is the video inside Cone's window? (#116, redesign/LINUX_WAYLAND_EMBED_NOTES.md)
#   linux-embed-check.sh <wayland|x11> <label> <out folder> <clip> <Cone command...>
# Starts a display server (wayland: a headless Weston session, Cone as a native Wayland client;
# x11: Xvfb), plays <clip> for a few seconds and reads Cone's log. Cone hands the video its own
# window only through the Qt interface's video window module ("qt"); when it has no compositor
# for the session (the Wayland case of #116: no libqt_wayland_plugin.so), VLC falls back to
# "wdummy" and the video opens in a separate window with no controls. Pass: the "qt" video
# window, a video output and no "wdummy". Writes <out>/<label>.log and a line for the summary.
set -u
MODE=$1 LABEL=$2 OUT=$3 CLIP=$4
shift 4
mkdir -p "$OUT"
LOG="$OUT/$LABEL.log"
RUNDIR=$(mktemp -d)
chmod 700 "$RUNDIR"
SERVER=
cleanup() { [ -n "$SERVER" ] && kill "$SERVER" 2>/dev/null; rm -rf "$RUNDIR"; }
trap cleanup EXIT

case "$MODE" in
wayland)
    # a Wayland session without X: no DISPLAY, so nothing can fall back to XWayland
    unset DISPLAY
    export XDG_RUNTIME_DIR=$RUNDIR WAYLAND_DISPLAY=cone-embed QT_QPA_PLATFORM=wayland
    weston --backend=headless --socket="$WAYLAND_DISPLAY" --width=1280 --height=720 --idle-time=0 \
        > "$OUT/$LABEL-weston.txt" 2>&1 &
    SERVER=$!
    for _ in $(seq 1 50); do [ -S "$RUNDIR/$WAYLAND_DISPLAY" ] && break; sleep 0.2; done
    [ -S "$RUNDIR/$WAYLAND_DISPLAY" ] || { echo "::error::$LABEL: Weston did not start"; cat "$OUT/$LABEL-weston.txt"; exit 1; }
    ;;
x11)
    unset WAYLAND_DISPLAY
    export XDG_RUNTIME_DIR=$RUNDIR QT_QPA_PLATFORM=xcb DISPLAY=:77
    Xvfb :77 -screen 0 1280x720x24 -nolisten tcp > "$OUT/$LABEL-xvfb.txt" 2>&1 &
    SERVER=$!
    for _ in $(seq 1 50); do [ -S /tmp/.X11-unix/X77 ] && break; sleep 0.2; done
    ;;
*)
    echo "usage: $0 <wayland|x11> <label> <out> <clip> <command...>"; exit 2 ;;
esac

rm -f "$LOG"
timeout 60 "$@" --no-qt-privacy-ask --no-qt-cone-update-check --aout=adummy --play-and-exit \
    --run-time=6 --file-logging --logfile="$LOG" --log-verbose=2 "$CLIP" \
    > "$OUT/$LABEL-stdout.txt" 2>&1
CODE=$?

ok=1
note() { echo "$LABEL: $*"; [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "- $LABEL: $*" >> "$GITHUB_STEP_SUMMARY"; }
[ -f "$LOG" ] || { echo "::error::$LABEL: Cone wrote no log (exit code $CODE)"; tail -n 30 "$OUT/$LABEL-stdout.txt"; exit 1; }
WINDOW=$(grep -o 'using vout window module "[^"]*"' "$LOG" | head -n 1)
DISPLAYMOD=$(grep -o 'using vout display module "[^"]*"' "$LOG" | head -n 1)
if [ "$WINDOW" = 'using vout window module "qt"' ]; then
    note "the video is in Cone's window ($WINDOW, ${DISPLAYMOD:-no display module})"
else
    echo "::error::$LABEL: the video is not in Cone's window (${WINDOW:-no video window module in the log})"; ok=0
fi
if grep -q 'using vout window module "wdummy"' "$LOG"; then
    echo "::error::$LABEL: VLC fell back to the wdummy video window (a separate window, no controls)"; ok=0
fi
[ -n "$DISPLAYMOD" ] || { echo "::error::$LABEL: no video output started"; ok=0; }
if [ "$MODE" = wayland ]; then
    # the Wayland compositor plugin, the file #116's packages lacked
    PLUGIN=$(grep -o 'using qtwayland module "[^"]*"' "$LOG" | head -n 1)
    [ -n "$PLUGIN" ] && note "Cone's Wayland compositor: $PLUGIN"
fi
[ "$CODE" = 0 ] || note "exit code $CODE"
[ "$ok" = 1 ]
