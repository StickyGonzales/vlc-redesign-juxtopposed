# Linux smoke checks on GitHub (branch wip/linux-smoke)

Branch `wip/linux-smoke`, on top of `wip/linux-deb` (it checks that branch's install scripts and package). Draft pull request into `wip/next-test`. CI only.

## What runs, and when
After **every Linux build** (`build-linux.yml`, the public profile), including the Linux release build (release-linux.yml waits for it). A `smoke` job calls `smoke-linux.yml`; a failed check fails the run, with an error naming it. `smoke-linux-manual.yml` runs the same checks on an earlier build's artifacts (they last one day): Actions > smoke-linux-manual > Run workflow > the build run's id.

| File | What it is |
|---|---|
| `.github/workflows/smoke-linux.yml` | `smoke-media` (the same test media as Windows, from the same cache) and `smoke` (Ubuntu 24.04) |
| `.github/workflows/smoke-linux-manual.yml` | the manual entry point (asks for `actions: read`, which a called workflow may not) |
| `.github/scripts/linux-smoke.py` | the checks |

**The runner:**
- Xvfb (1920x1080), openbox, a D-Bus session with the accessibility bus.
- VLC's dummy audio output (`--aout=adummy`); Qt renders in software.
- The interface's controls are found through **AT-SPI** (Qt's accessibility, as UI Automation on Windows).
- The input is real X input (xdotool); the playback state comes from VLC's cli interface on a Unix socket.
- Ubuntu's VLC (`vlc-bin`) is installed first, so the .deb is checked next to it.
- The system libraries of the optional plug-ins are installed too, so "every plug-in loads" also catches a library the package should bundle.

Each failed check runs once more; every retry is listed in the summary. Results artifact: `cone-linux-smoke-results` (summary, log, Cone's logs, screenshots).

## The checks
**Tarball, two sessions (H.264, HEVC):**
- main window within 30 s;
- playback time advances (3 s apart);
- the subtitle file loads (`strack`);
- the seek bar (the "Progress" slider) clicked at 75 % → the time is 75 % of the length;
- Ctrl+P opens Settings ("Search settings"), Escape closes it;
- the top bar's "..." opens the main menu ("Open File(s)") with a real click, in a window and in fullscreen (F), and Escape closes it;
- the speed slider (the gear, the sidebar's Speed): a real drag back and forth for 4 s, released near 2x; then Cone must still answer (AT-SPI within 5 s, the cli gives the speed, 1.5x or more, and the time moves on). Added with the speed slider freeze fix (#85, redesign/FIX_SPEED_FREEZE_NOTES.md), which this branch merges;
- Ctrl+Q quits in under 3 s (HEVC: a quit the watchdog ends is a warning, as on Windows);
- no "cannot load plug-in" line in Cone's log.

**Settings in the home folder:** `~/.config/Cone/vlc-qt-interface.conf`.

**install.sh / uninstall.sh** (a fresh home folder, no sudo):
- program, command, menu entry (`desktop-file-validate` without errors), icons 16 to 256 px;
- `mimeinfo.cache` offers `cone-player.desktop` for `video/mp4`, `video/x-matroska`, `audio/mpeg`, `application/x-subrip`;
- no `mimeapps.list` default;
- the installed `cone-player` plays, quits and loads every plug-in;
- `uninstall.sh` leaves nothing named `cone-player`.

**.deb:**
- `apt-get install` next to Ubuntu's VLC: the files are in place, VLC's version is unchanged, the entry is valid;
- `/usr/bin/cone-player` plays, quits and loads every plug-in;
- `apt-get remove`: everything goes, VLC stays.

**A note on Qt's accessibility:** Qt does not report the "showing" state of Qt Quick items over AT-SPI. A hidden control's geometry call fails, a shown one has its place on the screen; the checks use that.

## Local run (Linux sandbox)
Every tarball and install check, on the real tarball of build-linux #52 (run 41252263765), the same Python script under the same Xvfb, openbox and accessibility setup, without the .deb part (`--skip-deb`; the .deb was checked in a clean Ubuntu 24.04 container, LINUX_DEB_NOTES.md): **25 of 25 passed, no retries.**

| Check | tar H.264 | tar HEVC | installed |
|---|---|---|---|
| window | 1.5 s | 1.6 s | 1.5 s |
| time advances | 2 → 6 s | 3 → 6 s | 2 → 6 s |
| subtitle file | track 1 | track 1 | - |
| Settings | pass | pass | - |
| seek bar at 75 % | 23 s of 30 | 23 s of 30 | - |
| "..." menu, window | pass | pass | - |
| "..." menu, fullscreen | pass | pass | - |
| quit | 0.21 s | 0.22 s | 0.16 s |
| plug-ins | all load | all load | all load |

## Runs
| Run | Result |
|---|---|
| build-linux #54 (41256425136), first version | build green, **smoke red**: the bare runner had no `libEGL.so.1`, so the tarball's Qt plug-in did not load (the .deb, which depends on it, passed). Every desktop has it. |
| build-linux #56 (41258280658), with libEGL on the runner (5e6e0951) | build and **all smoke checks pass** (31 of 31): tarball H.264 and HEVC (window, playback, subtitle file, Settings, seek, "..." menu in a window and in fullscreen, quit 0.21 s, every plug-in loads), settings in ~/.config/Cone, install.sh / uninstall.sh, the .deb installed next to Ubuntu's VLC 3.0.20, started (quit 0.16 s) and removed |
| build-linux #57 (41303592768), with the speed check and #85's fix (bf74a5c28b) | build and **all smoke checks pass**: the speed drag released at 1.75x in both tarball sessions, the interface answers in 0.02 / 0.04 s. Without the fix (local run on build-linux #53) the check fails: "Cone exited during the drag (exit code -6)" |

## What it does not cover
The same limits as the Windows checks (redesign/CI_SMOKE_NOTES.md section 3):
- real sound and GPU video;
- the look against Figma;
- drag and drop;
- the library;
- Wayland (the runner is X11);
- other distributions than Ubuntu 24.04.
