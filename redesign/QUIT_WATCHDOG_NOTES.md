# Quit watchdog (branch wip/quit-watchdog)

Branch `wip/quit-watchdog`, made from `origin/wip/next-test`, draft pull request into `wip/next-test`. PC session, handed over by StickyGonzales on 2026-10-20 (an exception to Decision 64). Qt only, no core change. It is a safety net, not the fix: the quit hang itself is analysed on its own branch.

## Why
On Windows, quitting Cone can leave the process running with no window. The player's teardown thread waits for good inside the Qt plug-in, and the interface never gets the "stopped" it waits for before it asks to quit. See STATUS.md on wip/next-test and redesign/FIX_QUIT_DEADLOCK_NOTES.md. Until the cause is fixed, a stuck Cone must not stay behind: it blocks the next start in the same folder, holds the files it played, and needs Task Manager to end.

## What it does
`modules/gui/qt/util/quit_watchdog.cpp`, `QuitWatchdog::arm()`, is called where a quit starts:
- `MainCtx::onWindowClose`: the main window's close button, Alt+F4, the window's own close.
- `DialogsProvider::quit`: Quit in the menus, Ctrl+Q, the tray's Quit, and the quit that follows the stop after a window close.

The first call does this, in this order, on the interface thread:
1. Saves the Qt interface settings (`QSettings::sync`, the `vlc-qt-interface.ini` of the profile) and VLC's settings (`config_SaveConfigFile`, the `vlcrc` of the profile).
2. Saves the resume position of the current media in the media library, as the core does when an input stops (`vlc_player_UpdateMLStates`: `vlc_ml_media_update_progress`, only with "save-recentplay" on). The position and the address come from the player controller's cached values, so nothing here waits for the player's lock, which a stuck player thread may hold. A media the library does not know yet is left to the core, as before.
3. Logs "quit watchdog: armed" (debug level).
4. Starts a detached thread. If the process is still alive 5 s later, it logs an error and ends the process (Windows `TerminateProcess`, otherwise `_exit`), exit code 0.

The error is logged through the interface object while it exists, so it goes to every VLC log output: the console, the debugger and the log file when "Save a log" is on. `qt.cpp` `Close()` calls `QuitWatchdog::interfaceClosing()` first. After that, the error goes only to stderr and, on Windows, `OutputDebugString`.

A normal quit takes 0.3 to 0.8 s on the test PC, so 5 s never cuts a working quit short. A quit that does finish ends the process before the thread wakes. The Qt plug-in is never unloaded (`cannot_unload_broken_library()` in qt.cpp), so the sleeping thread always has its code.

Both brand profiles, Windows and Linux (the code has no platform branches apart from the final exit call; other platforms use `_exit` as well).

## Limits
- The media library's own state is in SQLite, which commits each change, so a forced end loses no committed change. A media library scan running at that moment is cut off and starts again on the next run.
- What only happens in the core's normal teardown does not happen after a forced end: the core's own resume save (step 2 covers it), the title, chapter, track and rate states it stores per media, and the module close callbacks. With the watchdog, a forced end loses those for the media that was playing when the quit hung.

## Retest on Windows
Safe rules: one player at a time, check that no Cone is left before each run, stop at the first hang that the watchdog does not end.
1. The hang recipe (test film, every sidebar slider dragged, the delay / speed / volume / seek / v / b key loops, close button), 4 times. Each run must end within about 5.5 s, with "quit watchdog" in the log when it had to fire.
2. The visualizer recipe (Spectrometer, subtitle delay keys, b, quit), twice.
3. Next file, stop and play, fullscreen in and out: unchanged.
4. Forced end: change a setting (accent colour and a vlcrc option), play a file to the middle, run the hang recipe, close, and let the watchdog end Cone. Start again: the setting is kept and the file resumes at its position.
