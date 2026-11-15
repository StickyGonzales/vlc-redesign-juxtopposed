# Linux: a file double-clicked while Cone quits was lost

StickyGonzales, 2026-11-15. Branch wip/fix-linux-quit-handoff, separate from #144. It changes a
non-GUI module (`modules/control/dbus`, Decision 27), so it is built on its own branch.

## Is it ours?

**Yes, the user-visible bug is ours. The hand-off itself is VLC's design.**
- **VLC's part:** in one-instance mode, a new start sends its files to the running instance over
  D-Bus and exits. VLC keeps doing that while an instance quits, and in stock VLC 4 too.
- **Our part:** Cone's instant quit (#128) hides the window at once, while the process can live on
  for up to the quit watchdog's 5 s. During that gap Cone looks closed but still takes the files.
  #57 closed the gap on Windows only (the Windows hand-off is a different mechanism), so Linux kept
  it.

## Reproduced on Linux (before the fix)

**Setup.** My local Linux build (with the sanitizers), Xvfb. Cone A plays a file started like a
double-click (`--started-from-file`). Ctrl+Q, then B is double-clicked the same way.

**How long the name stays taken.** Three rounds each:

| Quit | Window gone | Name `org.mpris.MediaPlayer2.cone` free | Process ended |
|---|---|---|---|
| Normal | 0.03 s | 0.20-0.23 s | 0.34-0.39 s |
| Stalled (the watchdog ends it) | 0.03 s | 5.37-5.41 s | 5.37-5.41 s |

**The loss.**
- **Stalled quit, B double-clicked 1 s after Ctrl+Q:** 0 of 3 opened.
  - B's log says "running VLC instance - exiting...", then "adding track ... to running instance".
  - B exits with 0, and nothing ever opens.
- **Normal quit:** the gap is about 0.2 s after the window goes. My sanitizer build starts too
  slowly to land in it (B opened 5 of 5). A normal build starts much faster, so a double-click right
  after closing can hit it. The stalled case is the reliable one.

## Fix

**At the start of every quit, the quitting Cone gives up the one-instance name.**
- **Who triggers it.** The quit watchdog (`releaseOneInstance`), which every quit path already arms
  (the window's close, Quit, Ctrl+Q, and quits that do not start in the interface). On Linux it
  triggers the instance variable `one-instance-release`. On Windows the existing #57 code is
  unchanged.
- **Who releases it.** The D-Bus module (`modules/control/dbus/dbus.c`). Only when it owns the name,
  it registers a callback for that variable. The callback only sets a flag and wakes the module's
  own thread, which calls `dbus_bus_release_name`. So the quit never waits for the bus, and the
  private connection is used only by its own thread, as before.
- **What a new start sees.** No running instance: it becomes the instance itself, opens its own
  window and plays the file.
- **Log line** (info level, so a default log shows it): "one-instance name released (quitting), a
  new start opens its own window".
- **Without the D-Bus module** (or a Cone that did not get the name) the trigger does nothing.

**A VLC bug fixed on the way (upstream code, its own commit).**
- **The bug.** The D-Bus module's main loop sized its poll array for the D-Bus watches only, but
  slot 0 is its wake-up pipe, so every loop wrote one entry past the array.
- **How it showed.** AddressSanitizer stops Cone at once: a dynamic-stack-buffer-overflow in the
  vlc-ctrl-dbus thread. Release builds do not notice.
- **The fix.** The array now has room for the pipe. This was also needed to run the check with the
  sanitizers.

**After the fix**, on the same setup:
- **The name** is free at the moment the window goes: 0.03 s, for a normal and a stalled quit
  alike.
- **Stalled quit, B 1 s later:** 4 of 4 opened their own window and kept playing after the quitting
  Cone ended.
- **Normal quit, B 0.05 s later:** 4 of 4.

## The build-linux #152 failure was something else

That failure (#144's run) was "drawing: main window appears: Cone exited with 0". Its Cone log
shows:
- **It was not a hand-off.** That Cone got the one-instance name itself ("listening on dbus as:
  org.mpris.MediaPlayer2.cone").
- **It was quit from outside about 0.2 s after it started.** The watchdog logged "a quit that did
  not start in the interface". It came neither through the smoke's command socket (no "accepted
  socket" line) nor from the smoke's D-Bus call.
- **Not explained.** I could not find its source from the logs. Every log of that run has an
  "exiting" line right after the command interface starts, so that line is normal start-up noise,
  not the quit.

## Smoke (Linux)

- **New check `check_quit_handoff`** ("quit-handoff: a file double-clicked while Cone quits opens in
  a new window").
  - **Setup.** A plays a file started with `--started-from-file`, with `CONE_TEST_HANG_QUIT`, so its
    quit always stalls until the watchdog. Ctrl+Q, then B is double-clicked 1 s later.
  - **It must:** show B's own window with B's file, keep that window after A ended, and find "one-
    instance name released" in A's log.
  - **Could it see the bug?** Yes. The stall keeps the quitting Cone alive for 5 s, so on the old
    code the name is always still taken.
  - **Local result.** On the old code (only the poll array fix): fail, "the file double-clicked 1.0
    s after Ctrl+Q was lost: the new start exited with 0". With the fix: pass. The screenshot shows
    B's window playing.
- **A sturdier sequence.** Every start now waits until the Cones started before it have ended and
  no Cone holds the one-instance name (at most 10 s, then it ends the leftover and says so). So no
  check starts next to a Cone that is still quitting.
- **Clearer failures.** A Cone that exits before its window now names the quit lines of its own log.
- **Local runs.** popup-stack, drawing and the new check in a row: drawing and the new check pass.
  popup-stack fails in my sandbox ("resume toast None") with the unchanged script from wip/next-test
  too, so that one is this sandbox.

## Also seen (not changed)

**A quit pressed before the window is ready trips an assertion.** With a key stuck down in my test X
server, Ctrl+Q reached Cone during its start. The debug build then stopped at
`compositor_x11.cpp:296: Assertion 'm_qmlView' failed` (`CompositorX11::quickWindow()` called before
the view exists). Release builds have no assertion. Logged here as a note for later.

## Green runs

(filled in when CI has run)

## Windows retest (PC session)

Windows behaviour is unchanged (#57's code; the D-Bus module is not built for Windows). One quick
regression look:
1. **Windows.** Close a playing Cone and double-click another video within a second: it opens and
   plays, as with #57.

## Linux retest (optional; the smoke covers the stalled case)

Build: the build-linux artifact of wip/fix-linux-quit-handoff.
1. **Double-click right after closing.** Play a video opened from the file manager, close the
   window, and at once double-click another video: it opens in a new window and plays.
2. **The hand-off still works.** With Cone open and playing (not quitting), double-click another
   video: it opens in the same window, and no second window appears.
3. **Media keys and other players' controls.** While Cone plays, the desktop's media controls
   (MPRIS) still show and control it.
