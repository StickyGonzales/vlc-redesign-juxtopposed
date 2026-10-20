# Cone's icon everywhere, video window class on Linux (IA-01, branch wip/fix-window-class)

Branch `wip/fix-window-class`, made from `origin/wip/next-test` (8e005df792). Draft pull request into `wip/next-test`.

**This is a core change** (`modules/video_output/xcb/window.c` is outside `modules/gui/qt`), so it gets its own build and test before the merge (Decision 55, build rounds rule). It only builds on Linux; the Windows build compiles nothing new.

WINDOWS_CHECKLIST.md row 7 (IA-01): the public build shows Cone's icon instead of the cone; check that the icon is used everywhere; the visualizer window was still titled "VLC media player" on Linux, fix that first.

## 1. What was still VLC's
- **Title of the separate video / visualizer window:** fixed in PR #36 (`wip/fix-visualizer`): "Cone" on Windows, X11 and Wayland in the Cone build.
- **Icons, audited:**
  - Qt interface: every icon goes through the brand layer (`modules/gui/qt/util/brand.cpp`): window, tray, tray menu, About logo, extension fallback.
  - QML: every cone image (home, minimal view, banner) uses `Brand.logoSvg` in the public profile. `UpdatePane` still has the cone, but the update checker is off in Cone, so it never shows.
  - Windows video / visualizer window: its class icon is the first icon of `cone.exe` (`ExtractIconW`), which is Cone's (`VLC_ICON` = `BRAND_ICON_RC`).
  - Wayland video window: app id "cone" (bin/vlc.c on wip/linux-build), so the compositor takes the icon from cone.desktop.
- **Remaining gap, X11 video / visualizer window:** its `WM_CLASS` was VLC's ("vlc", "Vlc"). Linux taskbars find a window's icon and group windows through `WM_CLASS` and the desktop file's `StartupWMClass` (cone.desktop: `StartupWMClass=cone`). So that window showed VLC's cone where VLC is installed, or a generic icon, and was not grouped with Cone.

## 2. Fix
`modules/video_output/xcb/window.c`: in the public profile `WM_CLASS` is "cone", "Cone", the same as Cone's Qt windows (`BRAND_DESKTOP_FILE`) and its desktop file. The vlc profile is unchanged ("vlc", "Vlc"). Length 10 = both strings with their NULs, the same way upstream counts 8 for "vlc\0Vlc".

It merges cleanly with PR #36, which changes the lines just above.

## 3. Checks
- `window.c` syntax-checked in both profiles (gcc `-Wall -Wextra`); no warning on the changed lines.
- privacycheck: 0 problems.

## 4. Sandbox test (Linux, together with PR #36)
RESULTS

## 5. Windows retest steps (IA-01, quick look)
1. Start Cone. Check the taskbar button, the Alt+Tab icon and the window's top-left icon.
   - Expect: Cone's icon, not VLC's cone.
2. Right-click the tray icon (if the tray is on).
   - Expect: Cone's icon in the tray and in its menu.
3. Play an audio file, turn on a visualizer (right-click > Audio > Visualizations > Spectrometer) so its separate window opens.
   - Expect: that window's title reads "Cone" (PR #36), and its taskbar button and Alt+Tab entry show Cone's icon.
4. Open About.
   - Expect: Cone's logo, "Cone 0.1.0", "based on VLC 4.0.0-dev".
5. Windows Settings > Apps > Default apps, look for Cone.
   - Expect: Cone's icon.
