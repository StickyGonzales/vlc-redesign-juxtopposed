#!/bin/bash
# usage: run-x11.sh <cone> <out> [only]
export HOME=/home/tester XDG_RUNTIME_DIR=/tmp/xdg-tester-x11 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 QT_ACCESSIBILITY=1
mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 & XV=$!
sleep 2
export DISPLAY=:99
dbus-run-session -- bash -c "
  /usr/libexec/at-spi-bus-launcher --launch-immediately >/dev/null 2>&1 & A=\$!
  openbox >/dev/null 2>&1 & O=\$!
  sleep 2
  /usr/bin/python3.12 -I /home/tester/tp/tools/tp.py --mode x11 --cone '$1' --media /home/tester/tp/media --out '$2' --only '$3'
  kill \$O \$A 2>/dev/null" </dev/null
kill $XV 2>/dev/null
pkill -u tester -f at-spi2-registryd 2>/dev/null; pkill -u tester -f 'dbus-daemon' 2>/dev/null; true
