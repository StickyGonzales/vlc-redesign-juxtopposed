# No "restore the playlist" prompt after a quit (branch wip/fix-restore-prompt-after-watchdog)

Branch `wip/fix-restore-prompt-after-watchdog`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt`), Cone build only.

## 1. The report
A Reddit user: after watching a video and opening another, Cone shows "The application closed abruptly. Do you want to restore the playlist model from ...?".

## 2. Cause (confirmed)
VLC 4's queue crash recovery (`util/model_recovery_agent.hpp`, created in `qt.cpp`):
- 10 s after each queue change, it writes the queue to a temporary file and stores that file's path in the settings (`Playlist/RecoveryFilePath`).
- Only its **destructor** removes the file and the key. It runs after `app.exec()` returns, which is **after** `ThreadCleanup` (the player and its threads shut down).
- On the next start, a key with a non-empty file shows the prompt.

The quit watchdog (#34) ends a quit that stalls in that cleanup after 5 s (`TerminateProcess` / `_exit`), as with the known HEVC stall (STATUS.md). The destructor never runs, so the next start asks to restore. "Opening another video" fits the 1.1.0 one-instance handoff: a double-click while the old Cone is still quitting starts a new Cone at once, and that new Cone finds the recovery file.

**Reproduced in the Linux sandbox** with the build before this fix:
1. Play a file for 16 s, so the recovery file exists.
2. Stop only the input thread (ptrace on that one thread, like a decoder stuck in teardown).
3. Ctrl+Q. The quit hangs in the cleanup, and the watchdog logs "Cone did not finish quitting within 5 s" and ends the process.
4. The next start shows the exact prompt from the report (picture, section 4).

## 3. The fix
A quit is not a crash. In the Cone build, the recovery is dropped as soon as a quit starts, which is when the watchdog is armed:
- `QuitWatchdog::setDiscardOnQuit(fn)`: `qt.cpp` hands over the recovery agent's reset once the agent exists.
- `QuitWatchdog::arm()` (Ctrl+Q, the menu's Quit, closing the window) calls it after saving the state.
- `Close()` (a quit started elsewhere, such as `vlc://quit` or the core) calls it before `ThreadCleanup`.

Resetting the agent runs its own destructor on the Qt thread, which removes the file, the lock and the settings key, as a clean quit always did.

What does not change:
- **A real crash** (no quit started) still leaves the file, so the next start still offers the restore.
- **The vlc profile:** the hand-over is compiled only with `VLC_BRAND_PUBLIC`, so VLC keeps its behaviour.

## 4. Sandbox test (Linux)
Build: build-linux #48 (run 41245976285), test-only branch `wip/test-linux-restore-customize` = wip/linux-build + this branch + wip/fix-customize-outlines.

Picture: `redesign/fix-shots/restore_prompt.jpg`.

How the stall was made: Cone plays the test video for 18 s. Then a small ptrace helper stops only the `vlc-input` thread (PTRACE_SEIZE + PTRACE_INTERRUPT, the other threads keep running), and Ctrl+Q is pressed. The quit hangs joining that thread, and the watchdog logs "Cone did not finish quitting within 5 s, ending the process" and ends it: the same path as the HEVC stall on Windows.

| Test | Before (older build) | After (this branch) |
|---|---|---|
| Stalled quit ended by the watchdog, then start again | the prompt "The application closed abruptly" | **no prompt**; the settings key and the recovery file are gone after the watchdog's exit |
| Process killed while playing (kill -9, a crash), then start again | the prompt | the prompt (a crash still offers the restore) |
| Normal Ctrl+Q, then start again | no prompt | no prompt |

## 5. Runs
| Run | Result |
|---|---|
| build-linux #48 (41245976285) | the sandbox tests above |
| build-windows #142 (41247518158), this branch | build and **all smoke checks pass** (start, play, subtitles, seek, Settings, quit in under 3 s, portable folder, plug-ins, silent install and uninstall). The smoke checks do not stall a quit on purpose, so the watchdog path itself is covered by the sandbox test and the Windows retest below |

## 6. Windows retest (PC session)
The HEVC quit stall triggers the watchdog on the PC (STATUS.md).
1. **Stalled quit.** Play an HEVC file for at least 15 s and quit with Ctrl+Q. If the quit takes about 5 s (the watchdog), start Cone again: **no** "The application closed abruptly" prompt.
2. **The report's case.** Play a file for 15 s, close Cone and double-click another file at once: the new Cone opens the file with no prompt.
3. **A real crash still offers it.** Play a file for 15 s, end Cone in Task Manager (End task on Cone.exe), start Cone: the prompt appears. Yes restores the queue.
4. **Normal quit.** Play, Ctrl+Q, start again: no prompt (as before).
