# The first start holds the opened file (F1, branch wip/fix-first-start-wait)

Branch `wip/fix-first-start-wait`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt`), both brands. Friday list item F1 in redesign/STATUS.md.

## The bug
- Found by StickyGonzales on a Windows 11 laptop, on a fresh install with "delete cache from last install" ticked.
- Cone's first start was by opening a video. The first-start onboarding showed, but the video already played behind it: the picture was hidden, the sound played.
- By the time Finish was clicked, about 30 s of the episode were gone.

## Cause
- The core starts the files given on the command line right after the interface says it is ready (`libvlc_InternalPlay`, called by `bin/winvlc.c` / `bin/vlc.c`).
- The onboarding opens a moment later, on top of the playing file. Nothing tied the two together.

## The fix
| Part | File |
|---|---|
| On a first start (`qt-privacy-ask`), while the interface starts, `playlist-autostart` is turned off on the libvlc object for that one call, so the core does not start the files. Only when autostart is on and nobody else set the option on the libvlc object. | `maininterface/mainctx.cpp` `holdFirstStartPlayback()` |
| When the first-run dialog closes, the option is the user's own again and the queue starts from its first item, from the beginning (what the core would have done). Nothing happens when something already plays. | `MainCtx::releaseFirstStartPlayback()` |
| The onboarding's close (Finish, Escape, the close button, any close) calls it. | `maininterface/qml/MainInterface.qml` (Onboarding `onDone`) |
| VLC's own first-run wizard (the fallback) calls it when it closes (finish or cancel). | `dialogs/dialogs_provider.cpp` `firstRunWizard()` |

- No core change: the core already reads `playlist-autostart` from the libvlc object.
- The player page still shows behind the onboarding (the queue has the file), as before; it only plays once the onboarding is gone.

## Smoke checks (new)
| Script | Check |
|---|---|
| `.github/scripts/linux-smoke.py` `first_start()` | first start with a file (`--qt-privacy-ask`): the onboarding shows ("Next"); the time stays at 0 or not started for 8 s; Escape closes it; playback starts at 4 s or less and advances |
| `.github/scripts/win64-smoke.ps1` `Run-FirstStart` | the same with the portable zip, closed with Next, Next, Finish |

## Checks
- `qmlcheck.py`: errors 1 (the known HighResolutionTimeWidget stub limit), crashed 0.
- `buildlists.py`: 0 problems. `privacycheck.py`: 0 problems.

## Runs
| Run | Head | Result |
|---|---|---|
| build-linux | see the PR | |
| build-windows | see the PR | |

## Windows retest (PC session)
Build: the build-windows run of this branch (or `gh workflow run build-windows.yml --ref wip/fix-first-start-wait`), Cone (portable).
1. **Fresh start with a file.** Deploy it to the test folder, then start it with `Cone.exe --qt-privacy-ask "<TEST_MEDIA_DIR>\<TEST_VIDEO>"` (or a fresh install with "delete cache from last install" ticked, then open the video by double-click).
2. **Waits.** The onboarding shows. Wait 30 s: no sound, the time behind it stays at 00:00.
3. **Finish.** Next, Next, Finish: the video plays from 00:00.
4. **Escape.** Repeat step 1, press Escape on the first screen: the onboarding closes, the video plays from 00:00.
5. **Close button.** Repeat step 1, close it with its close button: the same.
6. **No file.** `Cone.exe --qt-privacy-ask` alone: the onboarding shows, nothing plays after Finish, no error.
7. **Normal start.** Start Cone with a file again (no `--qt-privacy-ask`): it plays at once, as before.
8. **Setting.** Settings > Playback "Start playing automatically" (playlist-autostart) off, then step 1: nothing plays after Finish (the user's setting wins), and the setting is still off afterwards.
