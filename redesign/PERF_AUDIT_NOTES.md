# Performance and stability audit (Linux build)

Task (StickyGonzales 2026-11-12): find real problems in Cone's own code before users hit them, on
the Linux build. (1) CPU, memory and rendering paused, minimized while playing, idle on the home
page and over 2 hours of a show with autoplay; anything that keeps working when it should not;
memory that keeps growing; start-up to the first frame. (2) An AddressSanitizer +
UndefinedBehaviorSanitizer build running the smoke and unit tests; every report in Cone's code,
VLC's own reports listed apart. Clear bugs fixed on wip/perf-audit with tests, bigger ones listed
for StickyGonzales.

Branch: wip/perf-audit = wip/next-test + PR #127 (storage cleanup and background queue, not merged
yet; the audit covers its queue, so #127 is merged first, then this).

"Ours" = code Cone added (files and lines that are not in upstream VLC at merge-base a5538c557d).
"VLC" = upstream VLC, its core or its own Qt interface code that Cone ships unchanged.

## 1. How it was measured

- Build: build-linux #128 (wip/perf-audit before the fixes, 05ce70438a), the portable tarball.
- Machine: the web session's Linux container, 4 cores, no GPU: Qt renders with Mesa llvmpipe
  (software), so every frame Qt draws costs CPU here that a GPU would mostly absorb. Xvfb
  1600x1000 with openbox, window 1280x720, VLC's dummy audio output.
- `perf.py` (kept outside the repo; the method): Cone in portable mode with a fresh home per run,
  every thread's CPU time and context switches from /proc (wake-ups per second, per thread name),
  RSS, thread count, and the frames Qt renders (QSG_RENDER_TIMING, Cone's log with --qt-verbose).
  Each scenario starts 20 s after the window appears and measures 60 s; the pointer rests outside
  the window (the bars hidden).
- Media: testsrc2 640x360 H.264 + AAC; "Audit Show" (S01E01-E08, 15 min each) for the 2-hour run;
  "Short Show" (10 x 2 min) for the memory A/B.

## 2. Results

| Scenario | CPU (one core = 100 %) | Wake-ups/s | Qt frames/s | RSS | Threads |
|---|---|---|---|---|---|
| Home page, idle, no media | 0.0 % | 0.1 | 0 | 239 MB | 24 |
| Playing a show episode, bars hidden | 6.3 % | 342 | 2.1 | 331 MB | 39 |
| Playing a single file (no show), bars hidden | 4.7 % | 335 | 2.1 | 307 MB | 36 |
| Paused | 0.5 % | 70 | 0 | 327 MB | 39 |
| Minimized while playing (window unmapped) | 6.3 % | 317 | 2.1 | 326 MB | 38 |

Where the time goes (per thread, playing): VLC's input 1.6 %, video output 1.3 %, llvmpipe
(Qt's software rendering) 4 x 0.6 %, audio decoder 0.3 %, video decoder 0.3 %, Qt UI 0.3 %.

### 2.1 Things that keep working when they should not

- **Paused: nothing of Cone's runs.** 0.5 % CPU, no frame drawn. The 70 wake-ups a second are
  VLC's: the video output re-displaying the paused picture (42/s), the subtitle pre-renderer
  (17/s), and the X11 compositor's damage watcher answering the video output (a Qt thread with
  its own event loop, 9/s; seen with gdb and strace). Stock VLC 4 does the same (VLC).
- **Idle on the home page: nothing runs at all.** 0.0 % CPU, 0.1 wake-ups a second, no frame.
  The storage cleanup ran once at its 60 s mark and took 0 ms (ours, as intended).
- **Playing with the bars hidden, and minimized: Qt still draws 2.1 empty frames a second.**
  The scene-graph dump is identical from frame to frame: nothing on screen changes, something
  only asks for a redraw on every playback time update (2 a second). Minimized (window unmapped,
  checked with xwininfo) changes nothing, because VLC's X11 compositor renders the interface
  offscreen whether the window is shown or not. The cause is the items bound to the playback
  time inside the hidden control bar: 7 bindings in ControlBar.qml and 5 in SliderBar.qml are
  upstream VLC's (Cone added 2 and 3 more in the same items, which does not change the rate).
  Cost here: llvmpipe 4 x 0.6 % = about 2.3 % of one core with software rendering; with a GPU the
  driver absorbs most of it. VLC's own behaviour, made a little more visible by software
  rendering; listed in section 5 (b) because the fix would touch VLC's interface code.
- **Minimized while playing, VLC keeps decoding and showing the video** (input 1.6 %, video
  output 1.4 %): VLC core, the same in stock VLC.
- **The background queue sleeps when idle** (no wake-up in the home page measurement), but a job
  paused at its gate woke 10 times a second, and a pointer resting on the seek bar paused every
  background job for good: both ours, fixed (section 4).

### 2.2 Start-up

From starting `cone` with an episode to the window: 0.41 to 0.48 s (5 runs). To the first video
frame on screen (screenshots every ~0.1 s until the test picture shows): 1.53, 1.63, 1.63, 1.66 s
(4 of 5 runs; one run's capture missed it). Software rendering, a fresh profile each time. No
stock VLC 4 Linux build to compare with here (the vlc profile is not built for Linux); the
Windows numbers against stock VLC stay in PERF.md.

### 2.3 Two hours of a show with autoplay, and memory

**Two hours of "Audit Show" with autoplay** (8 x 15 min, started on E01, pointer outside the
window, sampled every minute): see the table below. Autoplay moved E01 to E04 by itself; E05
then opened paused: that is Cone's "Ask if I'm still watching after 3 episodes" (on by default,
Settings > Playback, rd_up_next.cpp kStillWatchingAfter = 3), working as intended. The run was
resumed through the cli (as a viewer pressing Play) and went on.

| Time | Playing | RSS | CPU | Threads |
|---|---|---|---|---|
| 1 min | E01 | 299 MB | 5.7 % | 44 (start-up) |
| 15 min | E02 | 315 MB | 5.5 % | 37 |
| 30 min | E03 | 344 MB | 5.0 % | 37 |
| 45 min | E04 | 373 MB | 4.5 % | 37 |
| 60 min | E05, paused by "still watching?" | 405 MB | 0.8 % | 37 |
| 75 min | E05 (resumed) | 415 MB | 5.1 % | 37 |
| 90 min | E06 | 432 MB | 4.8 % | 37 |
| 105 min | E07 | 430 MB | 4.9 % | 37 |
| 120 min | E08 | 428 MB | 4.7 % | 37 |

Memory rose about 28 MB with each of the first five episodes, then stayed flat for the last
45 minutes (428 to 432 MB); CPU stayed at about 5 % throughout, the thread count at 37. The
background queue ran every job and ended each one (8 credits scans, 7 credits subtitle passes,
7 Up Next pictures, 8 show detections, the daily cleanup, 16 saves). The A/B below shows the
rise is the same without Cone's show features.

**Memory over video changes, show vs plain files** (A/B, 10 x 2 min, same files, 21 min each):

| Minute | As a show (Up Next autoplays, credits scans, pictures, waveforms) | As plain files in a playlist (no show detection) |
|---|---|---|
| 0.5 | 308 MB | 308 MB |
| 3 | 350 MB | 330 MB |
| 5 | 367 MB | 345 MB |
| 7 | 385 MB | 363 MB |
| 9 to 15 | 391 MB, flat | 380 to 398 MB, flat |

Memory rises over the first four or five changes of video and then stays flat, the same with or
without Cone's show features: VLC's and Qt's pools and caches filling up (decoder and picture
pools, glyph and texture caches), not a leak, and not ours. In the show run the background jobs
all started and ended (6 credits scans, 4 credits subtitle passes, 5 Up Next pictures, 5 show
detections, the cleanup, 11 saves) and the thread count stayed at 37 to 38.

## 3. Sanitizer build (ASan + UBSan)

Build: VLC and Cone compiled with `-fsanitize=address,undefined -fno-omit-frame-pointer -O1 -g`
in the CI image (cone-linux-build:jammy, GCC 11, Qt 6.8.3), packaged like the release tarball
(linux-package.sh), run on this machine under Xvfb + openbox + AT-SPI with
`ASAN_OPTIONS=detect_leaks=1:use_sigaltstack=0`.

- **Unit tests** (all 7 programs, 795 checks): clean under ASan + UBSan, leaks included; now run
  that way in CI too (unit-tests.yml, unit-tests.sh SANITIZE=1). ThreadSanitizer on the
  background queue test: only the known false positive of an uninstrumented Qt (a functor handed
  through Qt's event queue; Qt's own mutexes are invisible to TSan), no real race.
- **Smoke suite** (linux-smoke.py, every check: playback H.264 / HEVC, subtitles, on-screen
  messages, Settings, seek, the seek bar rest check, the menu in a window and fullscreen, the
  speed slider drag, pointer hiding, the window class, a second start handing over its file,
  the onboarding, Up Next's Next episode, the popup stack, install.sh and its session): 42 checks
  pass. **No memory error and no undefined behaviour in Cone's code.** Three checks fail, none
  with a sanitizer report: two quits took 4.4 and 6.1 s (limit 3 s; ASan makes everything 2 to 3
  times slower), and the popup-stack check, which also fails on the normal build on this machine
  and passes in CI (build-linux #128): this machine's timing.
- **13 minutes of a show with autoplay under ASan** (Up Next, credits scans and subtitles, Up
  Next pictures, show detection, the storage cleanup and saves): no report except exit leaks.
- **Leaks**, all at exit only (nothing grows while Cone runs): a few KB per session, in VLC's
  interface code (the X11 compositor's surfaces, MainCtx, the side panel context, MainUI's root
  item) and one 64-byte connection per opened submenu in Cone's RdMenuModel, which lives as long
  as VLC's menus, which VLC never deletes at exit. Nothing to fix.
- **The one real memory error is VLC's**: see section 6 (1). It stopped every Cone start after
  the first under ASan, so the suite above ran with that one line patched in the ASan build
  only (the patch is not in this branch).

## 4. Fixed on this branch (ours)

| # | Problem | Who it hits | Numbers | Fix | Test |
|---|---|---|---|---|---|
| 1 | A pointer resting on the seek bar held the background queue for good: credits scans, waveforms, Up Next pictures and the cleanup all stopped. Hovering the control bar keeps the bars shown, so a pointer left on the bar after a mouse seek never let go | Anyone who leaves the mouse on the seek bar (common right after a seek); Up Next's credits point, pictures and waveforms then silently never come | Old build: "background: paused (seek bar)" still there after 8 s of rest (local smoke run of the build-linux #128 tarball); the hold had no time limit | SliderBar.qml: the queue waits while the bar is dragged or the pointer moves over it, and goes on 3 s after the pointer stops (`_holdsQueue`, `scrubMoveTimer`) | Linux smoke "the background queue goes on while the pointer rests on the seek bar": fails on the old build, passes on the fix |
| 2 | A job paused at its gate (a credits scan or waveform paused for a seek, a hover or an urgent job) woke every 100 ms to check whether to stop | Every user, during any hold; wake-ups and battery, not CPU | 10 wake-ups a second per parked job, for as long as the hold lasts (with #1: forever) | rd_background_queue.cpp: waits on the condition variable without a timeout; resume and every cancel (the only ways a job stops) wake it | test_rd_background_queue "parked: a paused job is not woken while it waits": 1 wake-up in 1 s allowed; fails with the old 100 ms poll (watched), passes now |
| 3 | The daily cleanup asked a network share that had gone away (or a drive that does not answer) again for every saved show on it: 2 s wait and one more blocked thread each | Users with shows on a network share that disappears mid-session | 2 s and 1 to 2 leaked threads per entry per daily check | rd_volume: SystemFileSystem remembers a drive that did not answer and counts later paths on it as not answered at once, for that check | Code review (no Linux way to make a share hang in a unit test); a "not answered" never deletes anything (presenceOf: Disconnected) |
| 4 | The Linux smoke took one of Qt's inner windows instead of Cone's on a slow start, then every check of that session failed | CI on a slow runner; found running the ASan build | All checks after the window one failed in the first ASan run | linux-smoke.py: the window manager's client list decides | The ASan run passes them |

Also new: the unit tests also run with ASan and UBSan in CI (unit-tests.yml).

## 5. For StickyGonzales to decide (decided 2026-11-13, see section 9)

| | What | Whose | Who it affects, numbers | Options |
|---|---|---|---|---|
| a | **Cast discovery runs all session.** "Discover cast devices" is on by default (Figma S2-10), so the renderer discovery services (Chromecast over mDNS, UPnP) start with the window and run until quit; stock VLC scans only while the Render picker is open (20 s) | Ours (the option and its default) | Every user, home page, paused and minimized included. Not measurable here: on Linux only the avahi module loads and the container has no avahi daemon or devices. On Windows it is microdns plus UPnP threads and multicast traffic | Measure on the PC (CPU, wake-ups, network with it on and off, idle on the home page); if it costs, keep the option but start discovery when the Render picker or the cast menu first opens |
| b | **Hidden or minimized UI redraws 2 frames a second while playing** (section 2.1) | VLC (its X11 compositor and the time bindings in the control bar); Cone ships it | Everyone on Linux X11; here 2.3 % of a core with software rendering, little with a GPU | Leave it, or freeze the hidden bar's time bindings while the bars are hidden or the window is minimized (touches VLC's ControlBar / SliderBar and the compositor) |
| c | **The home page reloads its rows on every media library event during a scan** (rdlibrarymodel.cpp isRelevantEvent / onMlEvent: every event except 7 types reloads; 6 row models, each with its own listener, a reload every 300 ms while the scan runs; "frequent artists" re-reads 200 history entries each time) | Ours | Users with large libraries, during the first scan or a rescan. Not measured: Cone has no command-line way to add a library folder, a scan needs the UI | Reload only for the events that change a row (media and history added, updated, deleted), and longer coalescing during a scan; then measure a 2,000-song scan |
| d | **Quit waits for a stuck job**: the background queue joins its running job on quit, and a credits or waveform read on a slow or vanished drive is not interruptible on Windows; the Settings plugin rescan waits without a limit (settings_catalog.cpp, WaitForSingleObject INFINITE) | Ours | Rare; the 5 s quit watchdog ends it | Part of the PC session's quit-instant task (wip/quit-instant), not changed here |
| e | Small, low impact (ours): the interface settings are written on the UI thread 500 ms after an accent / theme change (mainctx.cpp scheduleConfigSave; RdEffects already writes on a worker); the library's visit counts (rdlibrarystore.cpp m_visits) keep one key per folder, playlist or artist ever opened, never pruned; after one Stereo "Test" its test player and audio output stay open for the session (audio_device_model.cpp); three separate thumbnailers (seek previews, filter previews, Up Next) each keep an idle thread; Up Next works out its card on every time update, also minimized (cheap) | Ours | Each well under 1 % of anything measured here | Leave, or tidy in a later pass |

## 6. VLC's own reports (not Cone's code; (1) is carried since 2026-11-13, section 9)

1. **Stack use after scope at every start after the first** (qt.cpp, the asynchronous RHI probe,
   upstream "qt: do asynchronous rhi probing at start in a separate thread"): the lambda posted
   with `QMetaObject::invokeMethod(&app, [&]() {...})` reads `graphicsApiValue`, a local of the
   block that has ended by the time the event loop runs it. Reached once the graphics API is
   cached in the settings, so on every start but the very first. Undefined behaviour; in practice
   it reads the stale but intact value, so nobody notices, but a compiler or stack change could
   make Cone pick a wrong graphics API at start. One-line fix (capture `graphicsApiValue` and
   `enableRhiSoftwareRenderer` by value); a VideoLAN report candidate. Not changed here (VLC's
   code, StickyGonzales's call whether to carry the fix).
2. Exit leaks in VLC's interface code (X11 compositor surfaces, MainCtx, the side panel context,
   MainUI's root item): a few KB, only at exit.
3. Paused wake-ups (video output re-display 42/s, subtitle pre-renderer 17/s, the compositor's
   damage watcher 9/s) and video decoding while minimized: VLC core behaviour.
4. Tools, not code: GCC 11's ASan runtime aborts in `sigaltstack` at thread exit on a newer glibc
   (avoided with use_sigaltstack=0); TSan's Qt event-queue false positive.

## 7. Independent review

A fresh subagent reviewed the fixes (`git diff 05ce70438a HEAD`): no blocking finding.
- waitWhilePaused without a timeout: every caller and every cancel path checked; all stops go
  through the queue's cancel (which notifies), quit cancels every job before joining, no lost
  wake-up (flags written under the mutex, notified after). A future direct scanner cancel that
  skips the queue would leave a parked job asleep until the hold ends: the header comment says
  every stop goes through cancel.
- SliderBar `_holdsQueue`: balanced +1 / -1 (a bool binding, changes only), released on
  destruction; handler names valid.
- rd_volume: a "not answered" can only make an entry Disconnected, never deleted. Minor, left:
  the mount table is re-read per call on Linux (cheap); on Windows a folder-mounted volume is
  grouped with its drive letter (only more "not answered", safe); a drive slow once counts as not
  answered for the rest of that daily check (cleanup waits a day).
- Smoke: taken: the client list read once per pass; the seek bar rest check first waits for an
  earlier hold to end, so the "paused" it sees is the seek bar's.

## 8. Windows retest (PC session)

On the build-windows run of this branch (after #127 is merged or together with it):

1. **Seek bar rest (fix 1).** Play an episode of a show folder with 3+ episodes, Settings >
   About > Save log on (or a portable log). Seek with the mouse, then leave the pointer still on
   the seek bar for 10 s. Expected in the log: `background: paused (seek bar)` while moving, then
   `background: resumed (seek bar)` about 3 s after the pointer stops. Before the fix it stayed
   paused.
2. **No polling (fix 2).** Process Explorer > the Cone process > Threads: with the pointer moving
   over the seek bar while a credits scan runs (first play of a new show), the paused job's
   thread shows no context switches until the pointer leaves (before: about 10 a second).
3. **Network share (fix 3, optional).** A show on a network share played once, the share then
   disconnected, Cone left open past its daily check (or the clock moved a day): the log's
   `storage cleanup` job ends within about 2 s, not 2 s per show.
4. **Cast discovery only with the picker open (section 9 c).** Start Cone, wait 20 s on the home
   page: the log has no `starting renderer discovery service`. Open the settings sidebar > Video >
   Render: the log shows `starting renderer discovery service` (Chromecast / UPnP), devices on the
   network appear in the list within a few seconds; close the list (Escape or a click outside):
   `renderer discovery stopped`. Settings > Recording > Casting "Discover cast devices" off: opening
   the list starts nothing. Process Explorer: no microdns / UPnP threads while the list is closed.
5. **No drawing while hidden (section 9 b).** Process Explorer > Cone > Threads, or Task Manager
   GPU: play a video, let the bars fade out (pointer still): the GPU engine and Cone's render
   thread stay idle apart from the video (before: a UI frame twice a second). Pin the controls
   (Settings > Interface > pin video controls), minimize Cone: no UI frames; restore: the bars
   show the right time at once. Show the bars after a while hidden: time and seek bar are current
   at once, no jump afterwards; the same in fullscreen and in the mini player.
6. **Home page during a library scan (section 9 d).** Add a large music folder (thousands of
   files) and stay on the home page while it scans: the rows fill in about once a second, the
   window stays responsive (scroll, hover), CPU of Cone lower than before.
7. **The graphics check at start (section 9 a).** Start Cone 3 times: it starts normally each
   time (the cached graphics API is applied; Help > About > the log shows `Asynchronous rhi
   re-probe completed`).
8. **Quit while Cone asks to restore the playlist (section 9 e).** Play a file 15 s, end Cone
   with Task Manager > End task. Start it again: "The application closed abruptly ... restore the
   playlist?" shows; press Ctrl+Q (or the close button) without answering. Cone ends normally:
   no "Cone has stopped working" / Windows Error Reporting entry (Event Viewer > Windows Logs >
   Application, no APPCRASH for Cone.exe). The next start asks again.
9. **Right-click Render list (section 9 f).** Right-click the video > Playback > Render: the log
   shows `starting renderer discovery service`; close the menu with Escape: `renderer discovery
   stopped` at once.
10. Regression: play, pause, seek with the mouse and the keys, Up Next autoplay to the next
   episode, the Render list with a real Chromecast if there is one, quit (under 2 s).

## 9. Follow-ups decided by StickyGonzales (2026-11-13)

Decisions on section 5: (a) carry the one-line fix for VLC's RHI probe, (b) no drawing while
minimized or with the bars hidden, (c) cast discovery only while the picker is open, (d) home
page reloads at most once a second during a scan. Left: the quit on a stuck read (#128 hides the
window at once, the watchdog ends it) and the small items.

| | What changed | Measured / test |
|---|---|---|
| a | qt.cpp: the lambda queued at start captures `graphicsApiValue` and `enableRhiSoftwareRenderer` by value (VLC's code; report draft redesign/upstream/qt-rhi-probe-stale-read.md) | ASan build: the stack-use-after-scope at every start after the first is gone (the smoke suite under ASan starts Cone a dozen times with no stack-use-after-scope report); before, every session after the first aborted |
| b | Hidden bars: ControlBar.qml follows the time (`_shownTime`, `_shownRemainingTime`) and SliderBar.qml the position only while visible, and catch up when they show. Minimized: VLC's X11 compositor (compositor_x11_uisurface.cpp) draws nothing while the main window is not exposed, and draws again on Expose | Qt frames while playing with the bars hidden: 2.1/s before, 0.0/s after. Minimized with pinned bars (the time on screen): 2.13/s before, 0.0/s after; visible and pinned 2.1/s (the time does change). Linux smoke "drawing: nothing is drawn while playing with the bars hidden" (at most 4 frames in 10 s) and "drawing: nothing is drawn while minimized, the window draws again after" (pinned bars: frames while shown, at most 2 in 10 s minimized, frames again after restore) |
| c | renderer_manager.* back to VLC's (the background mode and its worker start removed); the picker (RendererMenu: the sidebar's Render list, the Render button, the menus) searches from aboutToShow to aboutToHide; "Discover cast devices" off now means the picker searches for nothing (before: on = search all session, off = only with the picker open; with this decision "on" behaves like the old "off", so "off" had to mean something else). The log says `renderer discovery stopped` when a search ends | Linux smoke "cast: devices are looked for only while the Render picker is open": nothing 12 s after start, a search when the right-click menu's Playback > Renderer opens, stopped within 5 s of closing the menu (VLC's own countdown would stop it only after 20 s, so the check also covers f below) |
| d | util/rd_reload_throttle.hpp: a library change still shows after 300 ms, but two reloads of a row are at least 1 s apart (RdLibraryModel, every home page row) | Unit test test_rd_reload_throttle (7 checks): a scan sending a change every 50 ms for 20 s reloads 20 times instead of about 60, at least 1 s apart, the last change shown; a single change after 300 ms. Fails with the old fixed delay (3 failures, watched). Not measured with a real scan (no scripted way to add a library folder here) |

**Found on the way (ASan smoke run of the follow-ups), fixed:**

| | What | Measured / test |
|---|---|---|
| e | **Quitting while Cone asks to restore the playlist crashed** (VLC's code, util/model_recovery_agent.hpp). After a session that ended abruptly (a crash, a kill, a power cut), the next start asks "The application closed abruptly. Do you want to restore the playlist ...?". The question runs an event loop of its own inside ModelRecoveryAgent's constructor; a quit meanwhile (Ctrl+Q, the close button, the system shutting down) deleted the playlist controller and the settings, and the constructor then connected to the deleted controller. The recovery file stayed, so the next start asked again. Now the constructor gives up when they are gone and leaves the recovery file for the next start | Linux build #128, quit while the question is open: the process ended by signal 11 (segfault), 1 of 1; with the fix: ends normally (exit 0) in 0.3 s, also under ASan with no report. Linux smoke "restore: quitting while Cone asks to restore the playlist ends normally" (a killed session, a start that asks, a quit) |
| f | **The right-click menu's Playback > Render list kept searching for 20 s after the menu closed** (Cone's RdCascadeMenu told a submenu when it opened, never when it closed). The submenus that close now get aboutToHide, as a QMenu would | Independent review; covered by section 8 step 4 on Windows |

**Independent review of the follow-ups:** no crash or correctness bug in the C++ or QML. Taken:
the right-click Render list (f above); the smoke checks' retries (the picture check read its
first attempt, the cast check counted the first attempt's log lines; the picture check no longer
delays the card's click). Checked and sound: the picture job as a light job still waits for every
hold and keeps its 30 s timeout; the RHI lambda reaches only `p_intf` by reference (alive for
the whole event loop); the renderer manager equals VLC's apart from setDiscoveryEnabled and the
log line, and applyCastDiscovery runs once the player exists; the hidden bars come back current
before their first frame, no binding loop, no other SliderBar; the compositor draws again on
either expose order; the throttle and its test.

**CI:** #127's build-windows #244 failed in the HEVC session: from its fourth check on, the
interface stopped answering (no key or click handled, no log line from the interface, the quit
watchdog did not end it), while VLC's core logged "failed to start audio output" in a loop (the
runner has no sound device). That session plays a plain file, where the only code change of that
commit (the Up Next picture job) never runs; the same smoke passed on #127's build #238, on
#131's build-windows #245 and in the HEVC session of every other run. Re-run once on the new
head (the rule); if it comes back, it goes to the PC session's quit and HEVC investigation (the
"Quit known issues" row: an HEVC audio-output stall that freezes the interface is VLC core).
