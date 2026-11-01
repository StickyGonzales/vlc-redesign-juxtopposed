# Fullscreen "..." menu (branch wip/fix-fs-menu)

Branch `wip/fix-fs-menu`, made from `origin/wip/next-test` (which has #65). Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt/widgets/qml/CSDWindowButtonSet.qml`) plus two smoke checks.

## The report
The PC session's test of #65: in fullscreen, a click on "..." in the top bar did not open the main menu, while the same click works in a window. Was it a real bug or its own click harness?

## Reproduced: a real bug, Windows only
New smoke checks click "..." with a real mouse (SetCursorPos, mouse_event), in a window and then in fullscreen, on a build that includes #65 (build-windows #141, run 41247457291, via smoke-windows-manual run 41251648899):

| Check | H.264 session | HEVC session |
|---|---|---|
| "..." in a window | **pass** (the menu opens) | **pass** |
| "..." in fullscreen | **fail**, also on the retry | **fail**, also on the retry |

The same harness opens the menu in a window, so the harness works. In fullscreen the top bar is shown (#65's check passes), the click lands on "...", and nothing happens. **In the Linux sandbox the fullscreen click opens the menu.**

## Cause
Two diagnostic Windows builds (test-only branch `wip/diag-fs-menu`, not for merging) logged the "..." button and the menu. In a window the button gets hover, press and click, and the menu opens. In fullscreen it gets **nothing**: no hover, no press. The click never reached the interface.

The same failure happens with each Windows compositor forced (`--qt-compositor=dcomp` / `win7`), so it is not the video window.

On Windows, Cone answers the system's hit test itself (`mainctx_win32.cpp`, `WM_NCHITTEST`):
- Where the client-side window buttons' model has a rectangle, the window reports minimize / maximize / close (`HTMINBUTTON` …), for Windows 11's snap layouts.
- A click there is a click on the window frame, and the interface never sees it.

Four button sets share that one model: the library's top bar (`LocalTopbar`), the player's top bar, the minimal view and the menu bar (`CSDWindowButtonSet.qml`). **Each wrote its rectangles on every window resize, shown or not.** Entering fullscreen is a resize:
- The player's top bar has no window buttons in fullscreen.
- The library's top bar is hidden behind the player but still alive, and it laid its buttons over the left of the screen: over "..." and the logo.
- Windows then answered "maximize" there, and the click was gone.

On Linux there is no such hit test, so it never failed there.

## Fix
`CSDWindowButtonSet.qml`, for every window button:
- it gives its rectangle **only while it is shown** (`visible`, which includes its parents);
- it gives it again when it is shown again;
- **when hidden or destroyed, it takes its rectangle away**, unless another, shown set has given one since.

This also covers a window: the library's hidden top bar can no longer leave its buttons where the player's are not. The vlc profile gets the same fix (the bug is not Cone-specific). No C++ change.

## New smoke checks (every Windows build)
`.github/scripts/win64-smoke.ps1`, in both portable sessions:
- **"..." opens the main menu in a window:** show the bars, a real click on "..." (UI Automation finds it). The "Open File(s)" row must appear within 2 s, still be there 1.8 s later, lie on the screen, and Escape must close it.
- **"..." opens the main menu in fullscreen:** F, let the bars hide, top edge, down onto "..." as a hand does, a short rest, the same real click and the same conditions. Then back to the window.

The same two checks run on Linux (wip/linux-smoke, `linux-smoke.py`), and pass there.

## Runs
| Run | Result |
|---|---|
| smoke-windows-manual 41251648899 on build-windows #141 (before the fix) | "..." in a window **passes**, in fullscreen **fails** (H.264 and HEVC, retries included) |
| build-windows #150 (41256927661), this branch | build and **all smoke checks pass**: "..." opens the main menu **in fullscreen** in both sessions (H.264 and HEVC, first try), and in a window as before |
| build-linux #56 (41258280658), wip/linux-smoke | the same two checks pass on Linux (tarball, H.264 and HEVC) |

## Windows retest (PC session)
Build: `gh workflow run build-windows.yml --ref wip/fix-fs-menu`.
1. **The report.** Play a video, F for fullscreen, let the bars hide. Move to the top, onto "...", click: the main menu opens under it. The same with the Cone logo and the library button.
2. **Windowed.** The same click in a window opens the menu as before.
3. **Window buttons.** In a window, hover the maximize button: Windows 11's snap layouts still open. Minimize, maximize and close work.
4. **Library and back.** Open the library (the top bar's library button), go back to the player, go fullscreen: "..." still opens the menu. In the library (windowed), the window buttons at the top right work.
5. **Client-side decorations off.** With VLC's "Use client-side decorations" option off (Settings > All Cone Settings > Interface > Main interfaces > Qt), the system frame's buttons work. Turn it back on: Cone's window buttons work.
