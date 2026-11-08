# Open with while Cone plays: the file plays in the running window (branch wip/fix-open-in-running-window)

Branch `wip/fix-open-in-running-window`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. **Core change** (Decision 27, minimal and isolated): `src/win32/specific.c` and `modules/control/win_msg.c`, Cone build only (`VLC_BRAND_PUBLIC`), Windows only; the vlc profile is unchanged. Built on its own branch, not mixed with interface changes. Linux got the same in #91 (LINUX_UX_NOTES.md).

## The bug
- **Reported by StickyGonzales on Windows:** with an episode playing in Cone, right-click an mp4 > Open with > Cone Player did nothing visible. It works when Cone is not running.

## What happened
- **Handed over, then only queued.** VLC's one-instance mode hands the file to the running Cone: `one-instance-when-started-from-file` is on by default, and Explorer starts Cone with `--started-from-file`. The second start finds the running Cone's IPC window ("Cone ipc <version>", Decision 57), sends its files with WM_COPYDATA and exits.
- **The receiver** (`win_msg.c` `add_to_playlist`) appends the file, and for the first file (unless "playlist-enqueue" is on) calls `vlc_playlist_Start()`.
- **Start does nothing while something plays** (`vlc_player_Start` returns at once when the player is started). The file therefore went to the end of the queue and the episode played on.
  - VLC 4 itself does the same; it is not the "enqueue in one-instance mode" setting, which is off.
  - With the queue stopped, Start played the queue's current item, not the new file.
- **Not handed over at all** when the running Cone was started from the Start menu (no file): only a start with `--started-from-file` (or with "Allow only one instance") created the IPC window, so a later Open with opened a second Cone window.
- **The window stayed behind:** nothing brought the running window to the front.

## The fix (Cone build)
| Part | File |
|---|---|
| The handed-over first file becomes the queue's current item (`vlc_playlist_GoTo` to it, then Start): it plays at once, like Next. The episode it replaces is stopped and its resume position saved as usual. Further files of the same start are queued after it. With "playlist-enqueue" on, the files are only queued, as the setting says. | `modules/control/win_msg.c` |
| The running window comes to the front with the file (`intf-show`, which Qt's MainCtx turns into a raise). | `modules/control/win_msg.c` |
| The second start lets the running Cone take the foreground (`AllowSetForegroundWindow` for its process) before it hands the file over, as Windows allows only the process the user just started to give it away. | `src/win32/specific.c` |
| Every first Cone listens for files (creates the mutex and the IPC window), also when started from the Start menu. A later start that does not hand over (no file, without "Allow only one instance") opens its own window as before. | `src/win32/specific.c` |

- **The three ways:**
  - **Open with, double-click:** Explorer starts `Cone.exe --started-from-file "<file>"` (the installer's ProgIDs), so both take this path.
  - **Drag onto the taskbar button:** Windows shows the window, and the drop lands on it: Cone's own drop handler (MainInterface.qml) plays it, unchanged.
  - **Drop on a pinned taskbar icon:** this starts Cone with the file, so it takes the Open with path.

## Smoke check (new)
- `.github/scripts/win64-smoke.ps1` `Run-OpenInRunning`:
  1. The portable zip's Cone plays test-h264.mp4. It was started without `--started-from-file`, like one opened from the Start menu.
  2. A second start `Cone.exe --started-from-file test-hevc.mp4` must exit within 15 s.
  3. Within 8 s the running window must play test-hevc.mp4: the cli's `status` shows the new input and the playing state.

## Checks
- `privacycheck.py`: 0 problems. No QML or build list change.

## Runs
| Run | Head | Result |
|---|---|---|
| build-windows #178 (run 41536483824) | 527bf89e22 | green, smoke included: "open-in-running: a second start with a file plays it in the running window: the second start exited, the running window plays test-hevc.mp4 after 0.8 s" |

## Windows retest (PC session)
Build: the build-windows run of this branch (or `gh workflow run build-windows.yml --ref wip/fix-open-in-running-window`), the installer (the ProgIDs and Open with need the installed Cone).
1. **Open with while playing.** Open an episode in Cone by double-click and let it play for a minute. In Explorer, right-click another mp4 > Open with > Cone Player: Cone comes to the front and plays the new file at once; the queue holds both.
2. **Resume.** Open the first episode again: Cone offers to continue where it stopped.
3. **Double-click while playing:** the same as step 1.
4. **Started from the Start menu.** Quit Cone, start it from the Start menu, open a file in it, then double-click another file in Explorer: it plays in the same window, no second Cone window.
5. **Paused.** Pause, then Open with another file: it plays.
6. **Minimized.** Minimize Cone while it plays, then Open with: the window comes back and plays the file.
7. **Several files.** Select 3 files in Explorer > Open with > Cone Player (or Enter): the first plays, the other two follow in the queue.
8. **Enqueue setting.** Settings: "Enqueue items in one instance mode" (playlist-enqueue) on, then Open with: the file is only added to the end of the queue, the episode plays on. Turn it off again.
9. **Taskbar.** Drag a file onto Cone's taskbar button, wait for the window to show, drop it on the player: it plays.
10. **Start menu twice.** Start Cone from the Start menu while it runs: a second window opens (unchanged, VLC's behavior without "Allow only one instance").
