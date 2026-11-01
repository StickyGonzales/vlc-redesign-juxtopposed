# Linux UX audit (Cone build)

Web session 2, 2026-11-01. Task owners row "Linux UX audit". Each fix is its own draft pull request into `wip/next-test`, built with build-linux and its Linux smoke checks.

Checked on the released **linux-v1.1.2-beta2** tarball in the sandbox (Ubuntu 24.04, no GPU): Xvfb with openbox for X11, Weston 13 nested in Xvfb for Wayland (real pointer input through xdotool, `WAYLAND_DEBUG=client` for the window requests), a D-Bus session bus, generated test clips. Then each fix on its own CI build.

## 1. Results at a glance

| Area | Beta 2 | Now | PR |
|---|---|---|---|
| Update notice | asked for the Windows release (`/releases/latest` never answers pre-releases) | the newest `linux-` release, pre-releases included; Download opens that page | #90 |
| Open a file while Cone runs (file manager, "Open with") | **a second Cone window** (menu entry without `--started-from-file`) | the running window plays it; the second start exits | #91 |
| Menu entry while Cone runs | (second window, see above) | the running window comes to the front (MPRIS Raise) | #91 |
| Window identity: Wayland app id, X11 class, MPRIS entry, sound mixer | `cone` everywhere, but the installed entry and icon are `cone-player`: no name or icon for the window on Wayland, no icon in the media controls or the mixer, MPRIS name "Cone" | `cone-player` everywhere, MPRIS "Cone Player" | #92 |
| VA-API / VDPAU built in | yes (vaapi, vdpau, glinterop plug-ins; libva 1.23 and libvdpau bundled) but the drivers are only searched in the Debian/Ubuntu folder | the launcher also names `/usr/lib64/dri` (Fedora, openSUSE), `/usr/lib/dri` (Arch), NixOS | #93 |
| Media controls (MPRIS) | work | unchanged | none |
| Media keys sent to the focused window | Play/Pause and Stop work; a separate Pause key does nothing | unchanged (VLC has no Pause-only key binding; desktops send media keys through MPRIS, where Pause works) | none |
| Wayland window handling | works (details below) | unchanged | none |
| Scaling 125 % / 150 % | works (details below) | unchanged | none |
| No tray icon | works (details below) | unchanged | none |

## 2. What works (no change needed)

**Media controls (MPRIS, D-Bus).** Cone registers `org.mpris.MediaPlayer2.cone` (its own name, never VLC's). Tested with `dbus-send` on the running beta 2: PlaybackStatus Playing / Paused, PlayPause, Pause, Play, Seek (+60 s: 12.3 s to 72.6 s), Next and Previous through a two-file queue, Metadata (URL, length), CanGoNext, Raise (a minimized window comes back, active), Quit (Cone ends). GNOME's and KDE's media controls and the media keys use exactly these calls.

**Media keys to the focused window (X11).** XF86AudioPlay toggles play and pause; XF86AudioStop stops. XF86AudioPause does nothing: VLC binds "Media Play Pause", not a Pause-only key. Desktops route media keys to MPRIS, so this only matters on a bare window manager; left as it is.

**Wayland** (Weston 13, Qt's wayland platform, Cone's own top bar):
- Cone starts, plays (video through a subsurface) and draws its own window buttons.
- Dragging the top bar moves the window (`xdg_toplevel.move`).
- Maximize button: `set_maximized`, the window fills the screen; the button toggles back.
- Resizing from the edges and corners works (`xdg_toplevel.resize`, the window follows). The grab zone is a few pixels outside the visible edge (in the shadow), as with other apps that draw their own frame.
- Fullscreen button: `set_fullscreen`; Escape leaves it (`unset_fullscreen`).
- Minimize button: `set_minimized`, the window goes.
- Close button: Cone quits.
- Window title "long.mp4 — Cone Player".

**Scaling** (X11, `QT_SCALE_FACTOR` 1, 1.25, 1.5, window 1500 x 900): the player's bars, buttons, seek bar and text scale evenly, nothing clipped or overlapping. Settings at 150 % in that window: the category list is taller than the window and scrolls under the pinned "All Cone Settings" row (wheel tested); no scroll bar or fade hints that more categories are there (same on Windows; not Linux-specific). Pictures: section 6.

**No tray icon** (Xvfb with openbox, no tray): Cone starts and plays. With "Start minimized to the tray" on, it still shows its window (log: "cannot start minimized without system tray bar"). With "close to tray" on, the close button quits Cone instead of hiding it where it can not be reached. Settings > Interface still offers the tray options; they do nothing without a tray.

## 3. What was fixed

### #90 Update notice on Linux
- `rd_update_check.cpp`: on Linux the check reads `/releases?per_page=50` and offers the highest version among the `linux-` tags (pre-releases included, drafts never listed without a token, of equal versions the newest). Download opens that release's page; the fallback page is the releases list. A list without a Linux release counts as "no release yet". Windows still reads `/releases/latest`.
- Unit test (the helpers compiled with Qt 6 against the real release list): `linux-v1.1.2-beta2` is offered; a newer Windows `v1.2.0` is ignored; a newer `linux-v1.2.0-beta1` wins; a draft is skipped; no Linux release gives none.
- Real build (build-linux #66's tarball, Cone 0.1.0, `CONE_UPDATE_CHECK_TEST_FILE` with a release list in GitHub's format, a stand-in `xdg-open` recording the URL): the real list of releases: "update check: 1.1.2 is available", the notice shows (Download / Later / Skip this version), **Download opens `.../releases/tag/linux-v1.1.2-beta2`**; a list with `linux-v1.2.0-beta1` added: "1.2.0 is available"; a list with Windows releases only: "no release yet", no notice.
- Known limit: the app knows only X.Y.Z of its version, not the label, so 1.1.2-beta2 is not offered 1.1.2 (same X.Y.Z). A new Linux release has always had a new X.Y.Z so far.

### #91 Files go to the running window
- Menu entries (tarball and AppImage, `install.sh`, the .deb) run `cone --started-from-file %U`, which turns on VLC's own hand-off (one-instance-when-started-from-file) over Cone's D-Bus name.
- Core, `src/posix/specific.c`, Cone build only: after handing the files over, the second start calls MPRIS Raise, so the running window comes forward, also with no file (clicking the menu entry while Cone runs did nothing before).
- New smoke checks: the Exec line of the installed entries; a second start that must exit while the running window plays its file. On build-linux #67: "a second start opens the file in the running window: the second start ended after 0.0 s; the running window plays handoff.mp4"; the Exec checks of install.sh and the .deb pass.

### #92 Window identity
- `BRAND_DESKTOP_FILE` (Qt desktop file name = Wayland app id, and the X11 WM_CLASS) `cone-player`; `StartupWMClass=cone-player`; MPRIS `DesktopEntry` `cone-player`, `Identity` "Cone Player"; the sound mixer's app id and icon (`bin/vlc.c`) `cone-player`.
- New smoke check: the window class matches StartupWMClass, MPRIS reports cone-player / Cone Player.
- Real build (build-linux #68's tarball) in the sandbox: WM_CLASS `"cone-player", "Cone"`, StartupWMClass `cone-player`, MPRIS DesktopEntry `cone-player` and Identity "Cone Player", and on Wayland `set_app_id("cone-player")` (beta 2: `cone` everywhere).

### #93 Hardware decoding driver folders
- The bundled libva and libvdpau come from the Debian build image and only search `/usr/lib/x86_64-linux-gnu`. The launcher now sets `LIBVA_DRIVERS_PATH` to every driver folder that exists (Debian/Ubuntu first, then `/usr/lib64/dri`, `dri-freeworld`, `dri-nonfree`, `/usr/lib/dri`, `/run/opengl-driver/lib/dri`), and `VDPAU_DRIVER_PATH` when the Debian folder is missing. A value the user set is kept.
- Tested on the generated launcher (Ubuntu, Fedora-like layout, user values); new smoke check reads the running Cone's environment.

## 4. Not testable here (needs real hardware or a real desktop)

| What | Why | Who checks |
|---|---|---|
| VA-API / VDPAU decoding itself | no GPU in the sandbox or on GitHub's runners | a Linux user, test 4 |
| Wayland with OpenGL video | the sandbox has no GPU render node, so Cone used its software output (`wl_shm`). In that mode the letterbox area under the hidden control bar was see-through (desktop visible). The OpenGL output normally clears its whole surface black, so this is expected to be a software-output-only effect, but it could not be checked here | a Linux user, test 3 |
| GNOME / KDE shells: dock icon, media controls popup, sound mixer icon | no desktop shell in the sandbox; checked the values they read (app id, WM_CLASS, MPRIS, PulseAudio app id) | a Linux user, tests 2 and 5 |
| Fractional scaling set in GNOME / KDE (not `QT_SCALE_FACTOR`) | no desktop | a Linux user, test 6 |
| KDE's tray (StatusNotifier) | no tray host | a Linux user, test 7 |
| Opening files from Nautilus / Dolphin | no file manager; the same command line was run | a Linux user, test 1 |

## 5. Runs

| PR | Run | Result |
|---|---|---|
| #90 update notice | build-linux #66 (41337560768) | green, Linux smoke checks all pass |
| #91 open in running window | build-linux #67 (41337699213) | green, smoke checks all pass, the new hand-off and Exec checks included |
| #92 window identity | build-linux #68 (41337784857) | green, smoke checks all pass, the new identity check included |
| #93 driver folders | build-linux #69 (41338595984) | green, smoke checks all pass, the new driver-folder check included |

## 6. Pictures

`redesign/linux-shots/ux-wayland.jpg` (Weston: playing, maximized, resized, fullscreen), `redesign/linux-shots/ux-scaling.jpg` (player at 100 / 125 / 150 %). Generated test video only.

## 7. Test list for a real Linux user (about 15 minutes)

Use the next Linux build with these fixes (tarball with `./install.sh`, or the .deb). GNOME or KDE, Wayland session if you have it (log out, pick "GNOME" / "Plasma (Wayland)" at the login screen).

1. **Open with, one window.** Start Cone from the menu and play a video. In the file manager, double-click (or right-click > Open With > Cone Player) another video. Expected: the same Cone window plays it and comes to the front; no second window. Click Cone Player in the menu again: the window comes to the front.
2. **Name and icon.** While Cone runs: the dock / taskbar shows the Cone Player icon and name, grouped with the menu entry (not a generic icon, not a second entry).
3. **Window on Wayland.** Drag the top bar; double-click it; use the maximize, fullscreen, minimize and close buttons; resize from each edge and corner. Expected: all work as on Windows. Maximize and let the bars hide: the area under them is dark, never the desktop showing through.
4. **Hardware decoding.** Play a 4K or HEVC file. Tools > Codec Information (or Settings > Video > hardware decoding) shows a VA-API (Intel / AMD) or VDPAU (NVIDIA) decoder; CPU use stays low. Fedora / Arch users especially. If it says software decoding, run `vainfo` and note what it prints.
5. **Media controls.** The desktop's media popup (GNOME: top bar clock; KDE: the media player widget) shows "Cone Player" with its icon and the file name; play/pause, next and previous work from there and from the keyboard's media keys. The sound mixer (GNOME Settings > Sound, KDE volume widget) lists Cone Player with its icon.
6. **Scaling.** In the desktop's display settings set 125 %, then 150 %. Cone's bars, Settings and menus are sharp and nothing is cut off.
7. **Tray.** On KDE (has a tray): Settings > Interface > "Show a system tray icon" on, restart Cone: the tray icon shows. On GNOME (no tray): Cone starts normally and the close button quits it.
8. **Update notice.** Settings > General > Check now: it reports the newest Linux release (for example 1.1.2 beta 2), never a Windows-only version; Download opens the Linux release page.
