#!/bin/bash
# usage: run-x11.sh <cone> <out> [only]
export HOME=/home/tester XDG_RUNTIME_DIR=/tmp/xdg-tester-x11 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_ACCESSIBILITY=1
mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp & XV=$!
sleep 2
export DISPLAY=:99
dbus-run-session -- bash -c "
  /usr/libexec/at-spi-bus-launcher --launch-immediately &
  openbox & sleep 2
  /usr/bin/python3.12 -I /home/tester/tp/tools/tp.py --mode x11 --cone '$1' --media /home/tester/tp/media --out '$2' --only '$3'"
kill $XV
