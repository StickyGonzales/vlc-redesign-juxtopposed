# Fullscreen can always be left (branch wip/fix-fullscreen-exit)

Branch `wip/fix-fullscreen-exit`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt`), Cone build only (`VLC_BRAND_PUBLIC`); the vlc profile is unchanged.

## The bug
- **Reported by StickyGonzales** (2026-11-03, a screen recording of 1.2.0): "I can't exit fullscreen sometimes".
- **The recording** was gone through frame by frame. It covers only the left 1280 px of the screen, so the top bar's right end (the fullscreen button) and the pointer are not in it. It shows the episode in fullscreen, the top bar shown for about 9 s, then the Start menu opened to get out.

## Cause
- **Two holds:** the window is fullscreen while either of two sources holds it (`WindowStateHolder::holdFullscreen`, a bit per source).

| Source | Set by |
|---|---|
| the video (`VIDEO`) | F, a double click on the video, Escape (leave), the control bar's fullscreen button (`Player.fullscreen`) |
| the interface (`INTERFACE`) | the top bar's fullscreen button and the window frame's (Decision 1), F11, the menu (`MainCtx::toggleInterfaceFullScreen`) |

- **Leaving one way kept the other's hold:**
  - Entering with F or a double click, then the top bar's button: that button released only the interface's hold, so the window stayed fullscreen.
  - Entering with the top bar's button, then Escape or the control bar's button: they acted on the video's fullscreen only, and Escape found nothing to leave.
- **"Sometimes":** it depended on how fullscreen was entered.

## The fix (Cone build)
| Part | File |
|---|---|
| The top bar's and the window frame's button, F11 and the menu: in fullscreen they release both holds; out of fullscreen they enter through the video's fullscreen while a video plays (the interface's otherwise, e.g. the library), so F, Escape and a double click leave it again | `maininterface/mainctx.cpp` `toggleInterfaceFullScreen` |
| The control bar's fullscreen button does the same as the top bar's | `player/qml/controlbarcontrols/FullscreenButton.qml` |
| When the video leaves fullscreen at the user's request (F, Escape, a double click), the interface's hold goes too. Not when a video ends: a fullscreen library stays fullscreen | `maininterface/video_window_handler.cpp` `requestVideoWindowed` |

## Smoke check (new)
- `win64-smoke.ps1` `Check-FsExit`, on the zip's H.264 and HEVC sessions:
  - F enters fullscreen, the top bar's "Fullscreen" button leaves it;
  - the button enters fullscreen, Escape leaves it.

## Checks
- `qmlcheck.py`: errors 1 (the known HighResolutionTimeWidget stub limit), crashed 0. `privacycheck.py`: 0 problems.

## Runs
| Run | Head | Result |
|---|---|---|
| build-windows #182 (run 41551449627) | e71a22c05f | red in the check only: the new check passed on H.264 (F then the button: windowed; the button then Escape: windowed); on HEVC the pointer at y 4 and 6 did not bring up the top bar (H.264 passed because both bars were still shown after the F key). Every other check green |
| build-linux #83 (run 41551454130) | e71a22c05f | green |
| build-windows (rerun) | the check moves the pointer up to the top edge and takes the top bar's button | running |

## Windows retest (PC session)
Build: the build-windows run of this branch, Cone (portable), an episode.
1. **F, then the button.** Press F: fullscreen. Move to the top edge and click the top bar's fullscreen button: windowed.
2. **Double click, then the button.** Double click the video: fullscreen. The top bar's button: windowed.
3. **The button, then Escape.** The top bar's button: fullscreen. Escape: windowed.
4. **The button, then F or a double click.** The button: fullscreen. F: windowed. The button, then a double click: windowed.
5. **Control bar.** The control bar's fullscreen button enters and leaves fullscreen, mixed with F and Escape as above.
6. **F11 and the menu.** F11 and "..." > Fullscreen enter and leave, mixed with Escape.
7. **Library.** In the library, F11 makes the library fullscreen; F11 leaves it. Play a video from there and let it end: the library stays fullscreen.
8. **Next episode.** In fullscreen, let the next episode start (Up Next): it stays fullscreen; Escape still leaves.
