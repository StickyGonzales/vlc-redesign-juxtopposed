# Quit hang after slider drags and player keys (branch wip/fix-quit-deadlock)

Branch `wip/fix-quit-deadlock`, made from `origin/wip/next-test` (bfc747782b), pull request into `wip/next-test`. Qt only (`modules/gui/qt/maininterface/compositor.cpp`), no core change. Build it on its own branch and test it before the merge (Decision 55). Nothing here is verified on Windows yet.

## What the dump shows
From STATUS.md on wip/next-test (round 2, step 3, run `quit8-fix-r1`, `quit-hang-572.txt`): after the window closes, `vlc-player-end` waits on a condition inside libqt_plugin.dll at +0x43C2F5. The main thread waits in Cone.exe. `vlc-qt` is still alive.

1. **The player thread's frame.** I looked up +0x43C2F5 in the libqt_plugin.dll of the PR #30 build (artifact of run 39300596915, image base 0x140000000). It is the return address of the wait inside Qt's `QMetaObject::invokeMethod` for a `BlockingQueuedConnection`. The function holds Qt's "invokeMethod: Dead lock detected" check, and Qt is linked into the plugin on Windows. The name "vlc_entry_license+0xCE3010" is only the nearest export, not the real function.
2. **Which call it is.** The only blocking calls the player thread can reach in the plugin are the video window callbacks in `compositor.cpp`. At the end of playback the player thread disables the window. It follows this chain and holds two locks while it waits for `vlc-qt`:
   - `src/player/player.c` (main loop, after the input is gone and the player is stopped)
   - `input_resource_StopFreeVout()` **holds the input resource lock**
   - `vout_Stop()`, then `vout_DisableWindow()` **holds the output's window lock**
   - `vlc_window_Disable()`, then `windowDisableCb()` does `invokeMethod(..., BlockingQueuedConnection)` and waits until `vlc-qt` has run the disable.
3. **The main thread.** Waiting in Cone.exe means `WinMain` is still waiting for the quit request: the interface never asked to quit. When the window closes, Cone first stops playback and asks to quit only when the player reports "stopped" (`MainCtx::onWindowClose`). The player thread posts "stopped" just before the disable above. So `vlc-qt` ran neither of the two: it was stuck before it reached them.

So the hang is two threads waiting for each other. The player thread waits for `vlc-qt` while it holds the kept output's window lock and the resource lock. `vlc-qt` does not run its queue.

**What the dump does not show:** the frame `vlc-qt` waits in (STATUS lists it as "waiting" only). Of the two locks the player thread holds, only the window lock is reachable from the interface thread. The resource lock is not: the player's hold functions use the separate `lock_hold`. The interface thread takes the window lock of that output whenever something sets one of its window variables. Examples:
- `fullscreen` through `vlc_player_vout_SetFullscreen()` or the hotkeys. This always goes to the first output, which is the kept one being stopped, and its callback always takes the lock.
- `video-on-top`, `autoscale`, `zoom`, `aspect-ratio` and `crop` (the choice models).
- A double click on the video.

Any of these at the moment of the stop closes the cycle. Whatever `vlc-qt` waits on, the player thread must not wait for it while it holds those locks. That wait is upstream VLC code: Cone never changed this callback, and VLC 4 master has the same `BlockingQueuedConnection`.

## Sandbox (Linux), before the fix
Build 39299659350 (wip/next-test + #30 + #31, Linux test branch `wip/fix-subs-linux`), generated stereo MKV with two SubRip tracks. The recipe is the PC's: every sidebar slider dragged, then the `h h g g j j k k ] [ + - Ctrl+Up Ctrl+Down Shift+Right Shift+Left v v b` keys, then the window's close button.

| Run | Result |
|---|---|
| X11 (render loop `basic`), 3 runs | exit in 0.65 to 0.83 s each |
| Same, gdb holding the player thread for 4 s inside `vlc_window_Disable` (both locks held) | exit, no hang |
| Wayland (weston nested, Qt's `threaded` render loop and threaded video surface updates, as on Windows), 3 runs | exit each time |
| Same as above, disable held for 4 s | exit, no hang |
| Stop key, then Escape or `f` while the disable is held | UI keeps answering (the view leaves the video at the stop, so nothing reaches the kept output) |

Not reproduced on Linux: on these builds the interface thread never waits for that output during the stop, even with the window held open for 4 s. Whatever `vlc-qt` does on Windows at that moment is Windows-only. Candidates are code that runs only there, such as the DirectComposition compositor, `mainctx_win32.cpp` and the mmdevice audio output.

## Fix
- `windowDisableCb` now **queues** the disable to the interface thread and returns at once. The core has already closed the output's display when it disables the window: the disable only tells the interface the video is gone (the DComp visual is removed, the surface provider stops reporting to the window). The interface does not have to finish it before the core goes on.
- **Ordering:** an enable that follows (the next file, a new video track) stays a blocking call. It is posted after the queued disable, so the interface runs them in order.
- **Destroy:** `windowDestroyCb` runs a disable that is still queued before the window goes away. It runs it directly when it is on the interface thread, because the last reference to an output can be dropped there. So the interface never reports into a destroyed window, and the DComp visual is removed before `windowDestroy()` resets it. The queued call keeps only a shared flag, never the window structure, so it does nothing once destroy has run it.
- **Result:** the player thread can no longer wait for `vlc-qt` while it holds the window and resource locks. Whatever `vlc-qt` waited for in the hang, the player thread now finishes the stop and lets go of both locks. `vlc-qt` then goes on, gets "stopped", asks to quit, and Cone exits.
- **Checks:**
  - The same `invokeMethod` and flag code compiles without warnings (`-Wall -Wextra`, Qt 6.4) in a standalone test and runs the disable exactly once when destroy comes first.
  - Linux build: see below.

## Sandbox (Linux), with the fix
Build: see the next section (test-only branch `wip/fix-quit-linux` = wip/next-test + this fix + the Linux build job; never merge it).

## Retest on Windows
Use a build of this branch (or wip/next-test with it merged) and the test folder of the hang runs. Before each run, check that no Cone is left running. Stop at the first hang.
1. **The hang recipe.** Open the test film and drag every sidebar slider (Speed, Audio Track Delay, Subtitle Track Delay, Subtitle Speed, Subtitle Duration Factor). Then run the subtitle delay, audio delay, speed, volume, seek, `v` and `b` key loops, and close the window with its close button. Cone must exit within about 2 s. Do this 4 times (before the fix it hung 4 of 4), and once each with Speed alone and with Subtitle Track Delay alone, followed by the key loops.
2. **Other quits after the recipe.** Run the recipe again, then quit with Ctrl+Q, and once with the main menu's Quit. Each must exit.
3. **Video window still works:**
   - Play a file to its end, then play the next file in the queue: the video shows in the window, not in a separate window.
   - Stop, then play again: the video comes back.
   - Switch the video track off and on: the picture comes back.
   - Double-click the video: fullscreen in and out.
   - Close while fullscreen: Cone exits.
4. **If it still hangs:** keep the process and capture every thread's stack, `vlc-qt` and `QSGRenderThread` included, with offsets in libqt_plugin.dll, libvlccore.dll and Qt. The `vlc-qt` frame is the missing half of this analysis.
