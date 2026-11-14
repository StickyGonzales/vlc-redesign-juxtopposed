# 1.5.0 test pass, Linux and macOS side (branch wip/test-pass-1.5.0, test-only)

StickyGonzales, 2026-11-14, before the 1.5.0 release on 11/19; the PC does Windows. On the current `wip/next-test` code. Fix nothing, release nothing. **State: paused (usage limit), no results yet.**

## Where it stands
- **macOS:** build-macos run 33 (both architectures) of this branch: `wip/next-test` plus Mac smoke screenshots of the Up Next card and the music view (`.github/scripts/macos-smoke.py`, information notes only; the branch's only change).
- **Linux:** build-linux run 149 of this branch (the same code; its own smoke gives an X11 baseline). Its tarball runs in the sandbox.
- **Harness:** `redesign/tools/testpass/`:
  - `genmedia.py` makes "Pass Show" (5 episodes of 7:00, English and French audio and subtitles) and a sync clip (speech-like audio, subtitles 2.4 s late);
  - `smoke-media.sh` gives the covers and Smoke Show;
  - `tp.py` runs every test with screenshots, under X11 (Xvfb, openbox, xdotool) or Wayland (headless Weston, GL renderer, AT-SPI actions, no input device);
  - `run-x11.sh` / `run-wayland.sh` start the sessions. Run them as a non-root user, with Ubuntu's python3.12 for pyatspi.
- **Tests (both modes):**
  - Up Next in the three end modes, and "Still watching?" after 3 episodes;
  - track memory;
  - Auto-sync and Undo;
  - square covers at 5 window sizes;
  - wheel seeking (X11 only: no pointer device under headless Weston);
  - the popup stack;
  - 10 instant quits;
  - the restore question after a killed Cone.

## Next
Download build-linux 149's tarball, run both modes, read build-macos 33's smoke results and screenshots, write the results here.
