# Quit watchdog (branch wip/quit-watchdog)

Branch `wip/quit-watchdog`, made from `origin/wip/next-test`, draft pull request into `wip/next-test`. PC session, handed over by StickyGonzales on 2026-10-20 (an exception to Decision 64). Qt only, no core change. It is a safety net, not the fix: the quit hang itself is analysed on its own branch.

## Why
On Windows, quitting Cone can leave the process running with no window. The player's teardown thread waits for good inside the Qt plug-in, and the interface never gets the "stopped" it waits for before it asks to quit. See STATUS.md on wip/next-test and redesign/FIX_QUIT_DEADLOCK_NOTES.md. Until the cause is fixed, a stuck Cone must not stay behind: it blocks the next start in the same folder, holds the files it played, and needs Task Manager to end.

## What it does
`modules/gui/qt/util/quit_watchdog.cpp`, `QuitWatchdog::arm()`, is called where a quit starts:
- `MainCtx::onWindowClose`: the main window's close button, Alt+F4, the window's own close.
- `DialogsProvider::quit`: Quit in the menus, Ctrl+Q, the tray's Quit, and the quit that follows the stop after a window close.

The first call does this, on the interface thread:
1. Starts a detached timer thread first, so a save that blocks cannot keep Cone alive: 5 s, or 30 s while the player records (a recording is finalised when its input stops).
2. Saves the interface state the main context's destructor saves (`MainCtx::saveSettings`: panel widths, scale, grid view, colour scheme, file dialog path) and the window geometry, then the Qt interface settings (`QSettings::sync`, the profile's `vlc-qt-interface.ini`) and VLC's settings (`config_SaveConfigFile`, the profile's `vlcrc`, skipped with `--ignore-config` as the core does).
3. Saves the resume position of the current media in the media library, as the core does when an input stops (`vlc_player_UpdateMLStates`: `vlc_ml_media_update_progress`, only with "save-recentplay" on, only below 90 %: at the end the core's own end-of-file handling owns the media's state). The position, playing state and address come from the player controller's cached values (the address byte for byte as VLC gives it, `PlayerController::getMrl`), so nothing here waits for the player's lock, which a stuck player thread may hold. A media the library does not know yet is left to the core, as before (logged at debug level).
4. Logs "quit watchdog: armed" (debug level).

A quit that starts outside the interface (`--play-and-exit`, `vlc://quit`, a remote control) arms the timer only (`armWithoutSaving`) when the last Qt interface closes (`qt.cpp` `Close()`, reference count 1).

When the timer fires: a line on stderr (and `OutputDebugString` on Windows), the error "quit watchdog: Cone did not finish quitting within 5 s, ending the process" through the VLC logger (the Cone log: console, debugger, the log file when "Save a log" is on) from a helper thread that only tries the lock, then after at most 300 ms the process ends (Windows `TerminateProcess`, otherwise `_exit`), exit code 0, whether the log line got through or not. `qt.cpp` `Close()` calls `QuitWatchdog::interfaceClosing()` first; after that only stderr / OutputDebugString carry the message.

A normal quit takes 0.3 to 0.8 s on the test PC, so 5 s never cuts a working quit short; a quit that finishes ends the process before the timer wakes. The Qt plug-in is never unloaded (`cannot_unload_broken_library()` in qt.cpp), so the sleeping thread always has its code.

Both brand profiles, Windows and Linux (no platform branch apart from the final exit call).

Independent review (fresh agent, 2026-10-20) and what changed: the timer now starts before the saves (it could deadlock before starting: `hasInput()` takes the player lock; replaced with the cached playing state); `--ignore-config` is respected; the kill no longer waits for the logger (try-lock, 300 ms deadline); the main context's state and the window geometry are saved too; the resume save uses the raw MRL and skips positions past 90 %; recordings get 30 s; quits started in the core arm the timer at Close. Kept as StickyGonzales specified: 5 s, Windows and Linux, exit code 0.

## Limits
- The media library's own state is in SQLite, which commits each change, so a forced end loses no committed change. A media library scan running at that moment is cut off and starts again on the next run.
- A conversion or stream output started through the player (not the record button) is not detected: if its close takes more than 5 s, it is cut.
- What only happens in the core's normal teardown does not happen after a forced end: the core's own resume save (step 2 covers it), the title, chapter, track and rate states it stores per media, and the module close callbacks. With the watchdog, a forced end loses those for the media that was playing when the quit hung.

## Retest on Windows
Safe rules: one player at a time, check that no Cone is left before each run, stop at the first hang that the watchdog does not end.
1. The hang recipe (test film, every sidebar slider dragged, the delay / speed / volume / seek / v / b key loops, close button), 4 times. Each run must end within about 5.5 s, with "quit watchdog" in the log when it had to fire.
2. The visualizer recipe (Spectrometer, subtitle delay keys, b, quit), twice.
3. Next file, stop and play, fullscreen in and out: unchanged.
4. Forced end: change a setting (accent colour and a vlcrc option), play a file to the middle, run the hang recipe, close, and let the watchdog end Cone. Start again: the setting is kept and the file resumes at its position.
