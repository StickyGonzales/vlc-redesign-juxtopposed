#!/bin/sh
# Installs Cone Player for the current user, without sudo, from this unpacked folder:
#   the program            ~/.local/share/cone-player/
#   the command            ~/.local/bin/cone-player
#   the menu entry         ~/.local/share/applications/cone-player.desktop
#   the icons              ~/.local/share/icons/hicolor/<size>/apps/cone-player.png
# The menu entry lists Cone Player in "Open with" for video, audio and subtitle files. It never
# makes itself the default application: your current defaults stay as they are.
# Run it again to update. uninstall.sh (also copied into the installed folder) removes it all.
set -e

HERE=$(cd "$(dirname "$0")" && pwd)
DATA=${XDG_DATA_HOME:-$HOME/.local/share}
APP=$DATA/cone-player
BIN=$HOME/.local/bin
ID=cone-player

if [ "$(id -u)" = 0 ]; then
    echo "install.sh installs Cone Player for one user: run it as that user, without sudo." >&2
    echo "(For every user of the computer, install the .deb package instead.)" >&2
    exit 1
fi
if [ ! -x "$HERE/cone" ] || [ ! -f "$HERE/$ID.desktop" ]; then
    echo "install.sh must stay in the unpacked Cone Player folder (next to \"cone\")." >&2
    exit 1
fi
if [ "$HERE" = "$APP" ]; then
    echo "Cone Player is already installed here. To update it, run install.sh from a newly unpacked folder." >&2
    exit 1
fi

echo "Installing Cone Player into $APP"
mkdir -p "$DATA"
rm -rf "$APP.new"
mkdir "$APP.new"
# everything but a "portable" folder (an installed Cone keeps its settings in your home folder)
for f in "$HERE"/* "$HERE"/.[!.]*; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = portable ] && continue
    cp -a "$f" "$APP.new/"
done
rm -rf "$APP"
mv "$APP.new" "$APP"

mkdir -p "$BIN"
ln -sfn "$APP/cone" "$BIN/$ID"

mkdir -p "$DATA/applications"
# the full path: a menu entry does not search ~/.local/bin, which is not always on the PATH
sed -e "s|^Exec=.*|Exec=\"$APP/cone\" %U|" \
    "$APP/$ID.desktop" > "$DATA/applications/$ID.desktop"
chmod 644 "$DATA/applications/$ID.desktop"

for icon in "$APP"/usr/share/icons/hicolor/*/apps/$ID.png; do
    [ -f "$icon" ] || continue
    size=$(basename "$(dirname "$(dirname "$icon")")")
    mkdir -p "$DATA/icons/hicolor/$size/apps"
    cp "$icon" "$DATA/icons/hicolor/$size/apps/$ID.png"
done

# the desktop's caches (optional tools: a desktop without them rereads the folders itself)
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f "$DATA/icons/hicolor" 2>/dev/null || true

echo "Done. Cone Player is in your applications menu."
case ":$PATH:" in
    *":$BIN:"*) echo "From a terminal: cone-player [file]" ;;
    *) echo "From a terminal: $BIN/cone-player [file]  ($BIN is not on your PATH)" ;;
esac
echo "To remove it: $APP/uninstall.sh"
