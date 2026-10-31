# Customize Player: outlines and the gap (branch wip/fix-customize-outlines, Decision 74)

Branch `wip/fix-customize-outlines`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. QML only (`dialogs/toolbar/qml`), Cone build only (`Brand.isPublic`): the vlc profile's Customize Player is unchanged.

## 1. What changed
| Before | After |
|---|---|
| Minimize, maximize and close had the dashed "movable" outline, though they cannot be moved | **No outline** (the logo already had none) |
| Fullscreen dragged out of the top bar left an **empty dashed slot** between maximize and close until Save | The slot **closes at once**: minimize, maximize and close sit together, as in Figma "Player - customize-6" |
| Each top-bar zone showed a wide dashed "free room" slot | Hidden at rest. It shows only while a drag is on and the pointer is over it (in the accent colour), so drops still work |
| - | With the right zone empty, a drop **anywhere over the window buttons** puts the element back in front of them (accent slot while hovering) |

Why the window buttons and the logo cannot move (Decision 74): Windows needs the window buttons in the top-right corner for Snap Layouts, the title bar drag and their hit test, and they would hide with the bars.

**Files:**
- `CustomizeZone.qml`:
  - `collapseWhenEmpty`: an empty zone takes no width, or one icon width while a drop hovers it.
  - `dropHover`: the hover state, so the empty slot is drawn in the accent colour.
  - The empty-slot frame is hidden in the top bar at rest.
- `CustomizeTopBar.qml`:
  - The right zone collapses when empty.
  - A drop area over the window buttons, active only while that zone is empty, drops into it.
  - The window buttons' dashed frame is shown in the vlc profile only.

## 2. Test (Linux sandbox, real mouse drags)
Build: build-linux #48 (run 41245976285), test-only branch `wip/test-linux-restore-customize` = wip/linux-build + this branch + wip/fix-restore-prompt-after-watchdog. Before = the earlier Linux build of wip/next-test.

Setup:
- Window 1440x900.
- Customize Player opened from the "..." menu.
- Drags made with real X mouse events (press, 30 moves, release).

Picture: `redesign/fix-shots/customize_outlines.jpg`. Every crop is the top bar at 2x, and the Figma frames are cropped at the same scale (they are 2x exports).

| Test | Before | After |
|---|---|---|
| Customize open | minimize, maximize, Fullscreen and close outlined | only Fullscreen outlined |
| Top left | the logo without an outline; a wide dashed free-room slot after "Folder" | the logo without an outline; no free-room slot |
| Drag Fullscreen into the box | an empty dashed slot stays between maximize and close | the gap closes at once; the three buttons sit where Figma customize-6 has them (same pixels) |
| While dragging it out | - | its place stays open, without an outline, until the drop |
| Drag it back over the window buttons | - | an accent slot opens in front of close; the drop puts Fullscreen back |
| Remove Fullscreen, Save | - | the real top bar: minimize, maximize, close, no gap |
| Reopen Customize after Save | - | no empty slot, no outlines on the window buttons |

The only difference from Figma left is deliberate (Decision 74): Figma outlines the window buttons in its customize frames.

## 3. Runs
| Run | Result |
|---|---|
| build-linux #48 (41245976285) | the sandbox drags above |
| build-windows #143 (41247520614), this branch | build and **all smoke checks pass** |

Checks: qmlcheck errors 1 (the known HighResolutionTimeWidget) / crashed 0, buildlists 0, privacycheck 0.

## 4. Windows retest (PC session)
Compare with the video at 19:12 to 19:28 and Figma "Player - customize" / "Player - customize-6".
1. **Open Customize Player** ("..." menu). The logo, minimize, maximize and close have no dashed outline. Fullscreen and the other movable items do.
2. **Drag Fullscreen into the box.** The gap closes at once, and the three window buttons sit together in the corner.
3. **Drag it back** over the window buttons: an accent slot shows, and the drop puts it back.
4. **Save** without Fullscreen: the top bar has no gap. Snap Layouts (hover maximize) still works.
5. **Try to drag a window button** in Customize: it does not move.
