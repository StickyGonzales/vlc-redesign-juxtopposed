# Follow-ups from the PC retest of #127 and #131 (web 2, wip/retest-followups)

StickyGonzales, 2026-11-13: three small storage issues, cast search on Windows, and the restore
question after #128 (BUG rows in redesign/STATUS.md). One branch, one draft PR into wip/next-test.

## 1. Storage (ours)

| | What was wrong | Fix | Test |
|---|---|---|---|
| a | A planned delete of unused downloaded subtitles ran as a Low job of the background queue. Next from one playing file to the next keeps the "opening a file" hold for its full 8 s, because the playing state never changes and only PLAYING released it. A quit in those 8 s dropped the job, while the registry had already forgotten the files, so they stayed and the start-up scan registered them again as used now (protected 30 days) | (1) `rd_storage`: files to delete are kept in the registry (`pendingDelete` in rd-storage.json) until the delete ran. A quit before it deletes them in `~RdStorage` (a few of Cone's own files, the same folder check); after a crash the next start deletes them. A file Windows still holds open (a subtitle in use) stays pending for the next try. (2) `mainui.cpp`: the new file's first time update while playing ends the hold, so the queue goes on as soon as the next file plays | unit test `test_rd_storage_model` "pending deletes" (saved, read back, gone once deleted by either spelling); Linux smoke "next-short: the background queue resumes once the next file plays": 0.4 s after Next; with the old mainui.cpp the same check failed at 8.1 s |
| b | Each OpenSubtitles download was registered twice: `C:\...\portable/subtitles/...` (written by the download, linked to its video) and `C:/.../portable/subtitles/...` (the start-up scan, no video) | One spelling for every registry path (`Model::artifactPath`: Qt separators, cleaned). An old registry's duplicates are merged on load (the video, the latest use and the selection kept). The scan's owner lookup uses the same spelling | unit test "one spelling" (a download written with backslashes, then scanned: one entry with its video; an old registry's two entries become one). The guard was watched failing with the normalization taken out (7 checks red) |
| c | A 90 s file (not an episode) still made the next episode's Up Next picture. After Next the player still gives the previous file's length until the new file's first update, so the decision used the old length and requested the picture | `rd_up_next`: the length counts only once it is the playing file's (`lengthKnown()`: different from the previous file's, or the new file's time has come); the picture waits for it, then is made only when a card can show | Linux smoke "open-short: no Up Next picture for an episode too short for the card" (Mixed Show: the 60 s E02 opened directly; with the old rd_up_next the check failed: `thumbnailing 'Mixed Show S01E03.mp4'`, now none) and "next-short: no Up Next picture after an episode too short for the card" (a 200 s E01, then Next to E02). The Up Next card check still makes the next episode's picture |

## 2. Cast search on Windows

**Finding: not missing from our build, and not VLC core.** The Windows zip and the installer ship
`plugins/services_discovery/libmicrodns_plugin.dll` and `libupnp_plugin.dll`; both import only
`libvlccore.dll` and Windows system DLLs (ADVAPI32, IPHLPAPI, KERNEL32, msvcrt, WS2_32). They load:

- on the GitHub Windows runner (build-windows smoke, cone-zip-h264.log): `looking for renderer
  probe module matching "any": 2 candidates`, then `using renderer_discovery module "upnp"`;
- under wine, the 1.4.0 zip with no plug-in cache: `services_discovery module matching
  "microdns": 1 candidates`; `vlc-cache-gen` on the 1.4.0 plug-ins writes both
  (`microdns_renderer`, `upnp_renderer`, 2 "renderer probe" entries).

So on the PC the two DLLs are not loaded into Cone at all (0 candidates is VLC's plug-in list,
before any network use). The cause is on that PC, and the PC's log does not say why: VLC loads its
plug-ins before the log file opens. What this branch adds:

- **A diagnostic in Cone** (`renderer_manager.cpp`): when the Render list finds no discovery
  service, the log says how many renderer probe modules VLC has, and for microdns and upnp whether
  the plug-in is known, whether its file is there, and, on Windows, what `LoadLibraryEx` answers
  for it (the same call VLC's plug-in loader makes, e.g. `error 126` a missing DLL, `error 5`
  access denied, `error 225` blocked as a virus, `error 1114` its start failed).
- **Windows smoke checks** (win64-smoke.ps1, zip and installed): "cast discovery plug-ins load"
  (Cone without its interface asks for microdns and upnp by name: 1 candidate each) and "cast
  discovery renderer probes register" (`vlc-cache-gen` on a copy of the zip's plug-ins, and the
  installer's own `plugins.dat`: `microdns_renderer` and `upnp_renderer`, 2 renderer probes).

Once the PC log names the reason it can be fixed where it belongs (see the retest steps).

## 3. Restore question after #128

#128 drops the playlist's recovery agent at once on a quit (`QuitWatchdog::setDiscardOnQuit`).
While "Restore the playlist?" is open, the agent is still being made (the question runs inside its
constructor); the quit emptied the holder, and when the constructor returned, the new agent was
stored again and destroyed at the end, which deleted the recovery file and its setting. Now
`qt.cpp` sees the holder emptied by the quit and calls `ModelRecoveryAgent::keepForNextStart()`:
the file and the setting stay, the next start asks again; only Yes or No clears them.

Test: Linux smoke `check_restore_quit` now has "restore: a quit without an answer keeps the
question for the next start" (asked again, answered No) and "restore: answering No clears the
recovery data" (no question at the start after); it quits with Ctrl+Q, as on the PC. On Linux the
old code kept the data too (with Ctrl+Q and with the cli's quit; checked with the qt.cpp change taken
out): there the playlist is gone before the question returns, so the constructor gives up and the
file stays. The loss needs the Windows order (the question returns while the playlist still exists),
so the same sequence is also a Windows smoke check (win64-smoke.ps1 `Check-RestoreQuestion`: kill,
Ctrl+Q while asked, asked again, No through UI Automation, not asked).

### 3b. The playlist backup was never written on Windows while a file played (found by the Windows smoke)

The new Windows check killed Cone after 13, 20 and then 60 s of playback, and each time the
saved-playlist file was still empty (`restore: saved playlist ... (0 bytes)`), so the next start
asked nothing: on Windows a crash offered no restore at all. ModelRecoveryAgent (VLC's code) saved
10 s after the *last* change, and every change restarted the wait; on Windows the playing item
keeps being updated, so the wait never ended. Now the backup is written at most 10 s after the
first change (`model_recovery_agent.hpp`), and each save is logged (`playlist recovery: saved to
...`, or why it was not). Windows smoke: `restore: the playlist is saved for a restore` saved after
10 s (128 bytes), then all three restore checks pass.

Since killed sessions now leave a saved playlist on Windows too, the Windows smoke forgets it
before each start (`Clear-RestoreState`), except inside the restore checks; otherwise the question
stood in front of the next sessions (quit-instant, quit-hang and first-start failed on #250). The
Linux smoke already did this (`quit_cleanly`, restore-clear).

### Green runs

- build-windows #250 (def3582b94): build, installer and every smoke check but the three above,
  which failed only because of the left-over question; smoke-windows-manual #17 on #250's files
  with the fixed script (1b259d9093): all checks pass, including cast discovery (zip and
  installed) and the restore question.
- build-linux #140 (1b259d9093): running when this was written
- unit-tests #7 (0994e0cd04; the storage tests are unchanged since).

## Windows retest (PC session)

Build: build-windows on wip/retest-followups (the run named in the PR).

1. **Pending delete survives a quit (1a).** Play episode 1 of a show, add a subtitle from
   OpenSubtitles but keep the embedded one selected (the download stays unused), press Next, then
   Ctrl+Q within 3 s. In `rd-storage.json` (the portable folder) before the quit the file may be listed
   under `pendingDelete`; after the quit the downloaded .srt is gone from
   `portable\subtitles\opensubtitles`. The log of the next start has no "still to delete" line.
2. **Hold ends after Next (1a).** With `--verbose=2`, play episode 1, press Next: the log shows
   `background: resumed (opening a file)` within about a second of the new episode playing, not
   8 s later.
3. **One spelling (1b).** After step 1 (or any download), `rd-storage.json` lists each downloaded
   subtitle once, with forward slashes, linked to its video (`media`); an older file with two
   spellings is merged at the next start.
4. **No picture for a short file (1c).** A show folder with a 90 s file between two episodes: play
   the one before it, press Next to the 90 s file: the log shows `up next: not an episode` and no
   `thumbnailing` of the episode after it; the `up-next` picture folder gets no new PNG.
5. **Cast search (2).** Open a Render list (right-click the video > Playback > Render). If it shows
   only `<Local>`, the log now has `no renderer discovery service: N renderer probe module(s)
   among M modules` and one line each for microdns and upnp. Send those lines: they name the
   reason (file missing, not loaded, Windows error number). Also run once, in the build folder:
   `.\vlc-cache-gen.exe .\plugins` in PowerShell and send its output (it prints `cannot load
   plug-in` with the reason), then delete the `plugins\plugins.dat` it wrote.
6. **Restore question (3).** Play a file 15 s, end Cone with Task Manager > End task. Start it:
   "The application closed abruptly ... restore the playlist?" shows; press Ctrl+Q without
   answering. Start again: the question shows again. Answer No. Start again: no question.
7. Regression: Up Next autoplay to the next episode and its card picture; subtitles download and
   select; quit under 2 s.

## Independent review (fixed)

- The Windows restore check sent only Ctrl (PowerShell bound `Keys 0x11 0x51`'s second key to
  nothing): now `Keys @(0x11, 0x51)`, as every other call.
- The start-up downloads scan registered a file still waiting to be deleted again (used now,
  protected 30 days): it skips pending files.
- A pending delete could remove a file written again under the same name (a picture made anew, the
  same subtitle downloaded again): registering a file takes it off the pending list.
- The "opening a file" hold and Up Next's same-length check could take the previous file's clock,
  still ticking a moment after Next, for the new file's: only a time before the previous file's
  counts.
- Windows: the registry's spelling also folds the drive letter's case.
- Windows smoke: the ini is rewritten as UTF-8 without a BOM (as Qt writes it), and the quit after
  the question finds the main window again (falls back to the cli's quit).
- Known limits: with no length at all (a stream) the next episode gets no picture until a length
  comes; the cast check counts the plug-ins' renderer entries, not which probe belongs to which file.
