#!/bin/sh
# Removes Cone Player installed by install.sh for the current user: the program, the command, the
# menu entry and the icons. Your settings, media library and caches stay (~/.config/Cone,
# ~/.local/share/Cone, ~/.cache/Cone), unless you add --purge.
#   uninstall.sh [--purge]
set -e

DATA=${XDG_DATA_HOME:-$HOME/.local/share}
APP=$DATA/cone-player
BIN=$HOME/.local/bin
ID=cone-player
PURGE=0
[ "$1" = --purge ] && PURGE=1

# run from the installed folder, which this removes: continue from a copy outside it
case "$(cd "$(dirname "$0")" && pwd)" in
    "$APP")
        if [ -z "$CONE_UNINSTALL_COPY" ]; then
            tmp=$(mktemp)
            cp "$0" "$tmp"
            CONE_UNINSTALL_COPY=$tmp exec sh "$tmp" "$@"
        fi ;;
esac
[ -n "$CONE_UNINSTALL_COPY" ] && trap 'rm -f "$CONE_UNINSTALL_COPY"' EXIT

if [ ! -d "$APP" ] && [ ! -f "$DATA/applications/$ID.desktop" ]; then
    echo "Cone Player is not installed for this user ($APP)."
else
    echo "Removing Cone Player from $APP"
fi

rm -rf "$APP" "$APP.new"
# the command only if it is ours (a link into the installed folder)
if [ -L "$BIN/$ID" ]; then
    case "$(readlink "$BIN/$ID")" in "$APP"/*) rm -f "$BIN/$ID" ;; esac
fi
rm -f "$DATA/applications/$ID.desktop"
for icon in "$DATA"/icons/hicolor/*/apps/$ID.png; do
    [ -f "$icon" ] && rm -f "$icon"
done

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f "$DATA/icons/hicolor" 2>/dev/null || true

if [ "$PURGE" = 1 ]; then
    echo "Removing the settings, media library and caches"
    rm -rf "${XDG_CONFIG_HOME:-$HOME/.config}/Cone" "$DATA/Cone" "${XDG_CACHE_HOME:-$HOME/.cache}/Cone"
fi
echo "Done."
