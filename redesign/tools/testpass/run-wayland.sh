#!/bin/bash
# usage: run-wayland.sh <cone> <out> [only]
export HOME=/home/tester XDG_RUNTIME_DIR=/tmp/xdg-tester-wl QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_ACCESSIBILITY=1
mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
unset DISPLAY
dbus-run-session -- bash -c "
  /usr/libexec/at-spi-bus-launcher --launch-immediately &
  weston --backend=headless --renderer=gl --idle-time=0 --width=1600 --height=900 --debug --socket=wayland-tp > '$2/weston.log' 2>&1 & sleep 3
  export WAYLAND_DISPLAY=wayland-tp QT_QPA_PLATFORM=wayland
  /usr/bin/python3.12 -I /home/tester/tp/tools/tp.py --mode wayland --cone '$1' --media /home/tester/tp/media --out '$2' --only '$3'"
