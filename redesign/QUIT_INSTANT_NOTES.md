# Instant quit and the quit watchdog (branch wip/quit-instant)

Follow-up of PR #125 (quit stalls), owned by the PC session (StickyGonzales, 2026-11-12).

## 1. What the PC measured (PR #125 retest, 2026-11-12)
- **Plain VLC 4 takes about 2 s to quit on Windows** (build #229, no fix, `redesign/tools/quit-stall-repro.ps1`):
  HEVC test file 2.13 / 2.01 / 2.01 / 1.88 / 1.92 s, a 1080p x265 film 1.94 / 1.89 / 1.87 / 2.13 / 2.33 s.
  So the slow quit is VLC 4 core. Cone 1.3.0 quits the same way (about 2 s).
- **#125's core change made no measurable difference:** plain VLC with it 1.5 to 2.3 s, Cone with it 1.5 to 2.1 s.
- **The audio-switch stall did not reproduce** in any build (5 switches per round, plus 5 by hand with hardware decoding).
- **The one 12-minute "hang"** (Ctrl+Q run 9 on Cone #233) was not the watchdog failing: its log has no quit
  at all before the watchdog was armed (no "exiting", playback simply went on), and the watchdog armed by the
  next Ctrl+Q 12 minutes later ended the process on time. The first Ctrl+Q never started a quit. The new
  "quit: requested by ... at hh:mm:ss.mmm" line tells such a case apart from a quit that hangs.

## 2. The change
- **One quit path** (`MainCtx::requestQuit`) for the quit key, the window's close button and Quit in the menu
  (`DialogsProvider::quit` goes through it unless a quit is already under way):
  1. logs the source and the time;
  2. arms the watchdog (its 5 s timer starts first, then the save);
  3. **hides every window at once**, unless a modal window (a dialog that needs the user) is open;
  4. stops playback, so the sound stops at once (now also for audio without video);
  5. quits; VLC's core shuts down in the background, the watchdog ends it within 5 s if it has not.
- **The watchdog** (`util/quit_watchdog.cpp`): the timer starts once from whichever path comes first (any
  thread), the save runs once, and its messages carry the wall-clock time.
- **Test switch** `CONE_TEST_HANG_QUIT`: the quit blocks on purpose after the watchdog is armed and the window
  hidden, so only the watchdog can end it.

## 3. Checks
- **Smoke (Windows):** `quit-instant` closes Cone like the close button: the window must be hidden within 0.5 s
  and the process gone within 5 s. `quit-hang` (with `CONE_TEST_HANG_QUIT`) must be gone within 6 s, ended by
  the watchdog.
- **PC test:** 20 Ctrl+Q and 20 close-button quits on a playing video: the window disappears at once every time,
  the process is gone within 5 s.

## 4. PR #125
Closed: its core change brought nothing measurable. Kept from it: `redesign/tools/quit-stall-repro.ps1`. The
upstream draft `redesign/upstream/decoder-picture-wait-deadlock.md` now describes only the confirmed 2 s quit of
plain VLC 4.
