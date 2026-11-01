# Speed slider freezes Cone (branch wip/fix-speed-freeze)

Branch `wip/fix-speed-freeze`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt/player/player_controller.cpp`, one function) plus a smoke check on Windows and Linux.

## The report
The PC session: dragging the playback speed slider while an HEVC film plays freezes Cone Player; the released 1.1.0 does the same.

## Reproduced (Linux sandbox)
- **Media:** a 90 s 1080p 10-bit HEVC MKV with 5.1 E-AC-3 audio, made with ffmpeg; also the smoke checks' 480p H.264 file.
- **Steps:** the gear opens the sidebar on Playback, then a real mouse drag on its Speed slider.
- **Build:** the Linux build of wip/next-test (build-linux #53), which has VLC's run-time assertions on.
- **Result:** Cone **aborts at the first speed change**, 3 of 3 times once the drag reached the slider, and with H.264 as well:

```
qt debug: setRate 2.000000
main debug: control type=1
vlc: ../../src/misc/threads.c:134: vlc_mutex_trylock: Assertion `!vlc_mutex_held(mtx)' failed.
```

Setting the speed through the cli (`rate 2`) does not abort: only the interface's path does.

## Cause
The core dump's stack (main thread):

```
vlc_mutex_lock            <- the player lock, already held by this thread
vlc_player_Lock
libqt_plugin (RdUpNext::updateCard -> PlayerController::isStarted)
QObject signal            <- PlayerController::rateChanged
libqt_plugin (PlayerController::setRate, inside vlc_player_locker)
QObjectWrapper::setProperty  <- QML: Player.rate = v (the Speed slider's onMoved)
```

- `PlayerController::setRate` emitted `rateChanged` **while it still held the player lock**.
- Cone's Up Next (`RdUpNext`, a Cone extra since 1.1.0) is connected to `rateChanged` directly. Its `updateCard()` first asks `m_player->isStarted()`, which locks the player again on the same thread.
- The player lock is not recursive, so the thread waits for itself:
  - **in a release build** (every Windows build, Cone 1.1.0), the interface **freezes** for good: no repaint, no input;
  - **in an assertion build** (the Linux beta build), it aborts.
- Every speed change from the interface goes through `setRate`: the sidebar's Speed slider and value box, the control bar's speed popup. **So any file freezes, not only HEVC** (the H.264 test file does too).

## Plain VLC 4
Upstream VLC master (`origin/master`, the base of Cone) has the same `emit` inside the lock, but **nothing in it listens to `rateChanged` in a way that locks the player again**:
- its only listener is `PlaybackSpeed.qml`'s `onRateChanged`, which moves the slider;
- property bindings read `Player.rate`, which returns a cached value without the lock.

So plain VLC 4 does not freeze. The lock re-entry needs Cone's `RdUpNext`, which explains "1.1.0 too": Up Next shipped in 1.1.0.

This rests on reading upstream's code; the sandbox has no build of plain VLC 4. Windows retest step 5 confirms it with the stock VLC 4 build on the PC.

## Fix
`PlayerController::setRate` emits `rateChanged` after the player lock is released, as `jumpToPos` already does with `seekRequested`. These are the only two signals the player controller emitted under its lock; `jumpToPos` was already right. No other change to what happens: the same rate reaches VLC and the same signal reaches the interface.

## Smoke check (Windows and Linux, H.264 and HEVC)
**"speed slider drag, Cone keeps responding"**, in both full sessions (H.264 and HEVC), after the other checks:
1. A real click on the gear ("Playback Settings").
2. The "Speed" slider (UI Automation / AT-SPI).
3. Press on its thumb at 1x, then drag back and forth across the track for 4 s.
4. Release near 2x.

Then Cone must answer:
- the process is still running;
- **Windows:** the window responds to messages (`Process.Responding`, which a frozen interface fails);
- **Linux:** the interface answers AT-SPI within 5 s;
- the cli gives the speed (1.5x or more, which proves the drag reached the slider);
- after `rate 1`, the playback time moves on.

Windows: `.github/scripts/win64-smoke.ps1` (this branch). Linux: `.github/scripts/linux-smoke.py` (wip/linux-smoke, PR #83, which merges this branch so its CI stays green).

## Runs
| Run | Result |
|---|---|
| Linux sandbox, build-linux #53 (wip/next-test, without the fix), the new `linux-smoke.py` | the speed check **fails**: "Cone exited during the drag (exit code -6)" (the assertion above) |
| **build-windows #153 (41303303636)**, test-only `wip/test-speed-check-only` = the check **without** the fix | the speed check **fails** in both sessions: "after the drag Cone's window does not respond (the interface froze)"; then Ctrl+Q is never handled (still running 10 s later), as in the PC session's report |
| **build-windows #154 (41303559683)**, this branch (c6aa4e7dcf) | build and **all smoke checks pass**: zip-h264 "127 moves across the slider, released at 1.75x; the window responds; time 14 s, then 17 s"; zip-hevc the same (14 s, then 16 s); quit 2.1 s / 1.44 s |
| **build-linux #57 (41303592768)**, `wip/linux-smoke` (bf74a5c28b) = the fix + the Linux check | build and **all smoke checks pass**: tar-h264 "118 moves, released at 1.75x; the interface answers (0.02 s)"; tar-hevc "120 moves, released at 1.75x (0.04 s)"; quit 0.11 s |

Checks: privacycheck 0. No QML or build list change.

## Windows retest (PC session)
Build: `gh workflow run build-windows.yml --ref wip/fix-speed-freeze`.
1. **The report.** Play the HEVC film, open the sidebar with the gear (Playback), drag the Speed slider back and forth for a few seconds, release. Cone keeps playing at the new speed, the bars and the sidebar answer, the "Speed: 1.75x" message shows.
2. **H.264.** The same with an H.264 file (it froze too before the fix).
3. **The other speed controls.** The value box (type 1.5, Enter), the control bar's speed popup if added in Customize Player, the [ and ] keys: no freeze.
4. **Up Next.** A show episode with Up Next armed (Settings > Playback > Episodes): change the speed near the end, the "Up next" countdown still shows and counts in real seconds.
5. **Plain VLC 4.** The stock VLC 4 build (builds\38315049322), the same drag: no freeze (the bug needs Cone's Up Next).
