# Fullscreen top bar hides under the pointer (branch wip/fix-fs-topbar-hover)

Branch `wip/fix-fs-topbar-hover`, made from `origin/wip/next-test` (fad0675581). Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt`), plus one smoke check.

## Report (StickyGonzales, 2026-10-27)
In fullscreen the top bar appears only while the mouse touches the top edge of the screen. As soon as the mouse moves down onto the bar, the bar disappears, so the Cone logo and "..." can hardly be clicked.

## Cause
Reproduced on the GitHub Windows runner, not in the Linux sandbox (there the bar stays). Probe on build-windows #137 (run 40426986761, `wip/next-test`), fullscreen, the bars hidden, the pointer at the top edge and then moved down 2 px at a time:

| Pointer | Bar |
|---|---|
| over the empty middle of the bar (x 300), y 0 to 70 | shown all the way |
| over the logo and "..." (x 70), y 4 to 38 | gone |
| same, y 40 and below (back over the video, in the zone) | shown again |
| resting on "..." (70, 20) | hidden for good |

Steps of the failure:
1. A button's tooltip is a native window on Windows (`ToolTipExt.qml`: `Popup.Window`).
2. A tooltip sits above its button. The fullscreen top bar touches the top of the screen, so there is no room, and the tooltip is pushed down **onto the button, under the pointer**.
3. The main window then reports that the pointer left (`QEvent::Leave`, and the hover handlers lose their hover).
4. The player takes that as "the pointer left the player": `_cursorY = -1`, outside both fullscreen zones, and the bar hides.
5. The tooltip closes with the bar. The next mouse move shows the bar again, its tooltip comes back, and the loop starts over. A pointer at rest stays in the hidden state.

The empty middle of the bar has no tooltip, so it never failed there. The Linux sandbox does not report a leave for the tooltip window.

## Fix
1. **`ToolTipExt.qml`:** a tooltip opens **below** its item when the window has no room above it. It never covers the button or lies under the pointer. This also helps the top bar in a window.
2. **`Player.qml`:** a leave reported while the pointer is still over the player and the window is the active one is not a leave (`_pointerStillOverPlayer()`). It covers both the window's leave and the hover handlers' one. This is the safety net for any other popup window of Cone's (menus, popovers).

A real leave still clears the zones:
- the pointer leaves the player, or another screen gets it;
- another application becomes active.

## New smoke check (all Windows builds)
`.github/scripts/win64-smoke.ps1`, "fullscreen top bar stays under the pointer", in both portable sessions (H.264 and HEVC):
1. Press F and let the bars hide.
2. Move the pointer to the top edge; the "..." button must appear.
3. Move down onto "..." in 2 px steps, as a hand does, and rest there 1.5 s.
4. The bar must still be shown.

| Build | Result |
|---|---|
| **old**, build #137 (smoke-windows-manual run 40546156961) | fails for both codecs, also on the retry: "the top bar hid while the pointer rested on its "..." button (65, 20)" |
| **fixed**, build-windows #138 (run 40546161841; test-only branch `wip/test-fs-topbar` = this branch + `wip/fix-smoke-media`) | passes for both codecs, first try: "still shown 1.5 s after the pointer came to rest on "..." (65, 20)". All 22 checks passed, no retries |

## Checks
- qmlcheck: errors 1 (the known HighResolutionTimeWidget), crashed 0. privacycheck 0. No C++ change.

## Windows retest (PC session)
Build this branch: `gh workflow run build-windows.yml --ref wip/fix-fs-topbar-hover`. Then:
1. **The reported case.** Play a video in fullscreen and let the bars hide. Move to the top edge, then down onto the Cone logo, "...", the library button and the folder chip.
   - The bar stays while the pointer is on it.
   - The tooltips open below the buttons.
   - Clicking "..." opens the menu.
2. **The bar goes away.** Move down onto the video: the bar fades out once the pointer is past the zone (Settings > Interface "Fullscreen controls sensitivity").
3. **The control bar.** The same on the bottom bar's buttons: their tooltips have room above them and open there as before.
4. **Windowed.** The top bar tooltips now open below the buttons; the other tooltips are unchanged.
5. **Leaving.** In fullscreen with the top bar shown:
   - Alt+Tab to another application: the bar hides as before.
   - With two screens, move the pointer to the other screen: the bar hides.
