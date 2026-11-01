# The mouse pointer hides over the playing video again

Branch `wip/fix-cursor-hide`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Release blocker for 1.2.0 (StickyGonzales, 2026-11-01). Player QML and the smoke checks only; nothing outside `modules/gui/qt` changes. Cone build only (`Brand.isPublic`), apart from #74's own change (see section 3).

Includes the commit of pull request #74 by **krishvaghasiya705** ("Player: hide cursor only during playback", kept as it is, with its author): thank you. It keeps the pointer visible while paused or stopped. This branch adds the fix that makes the pointer hide at all, the conditions for menus, panels and the Up Next card, and smoke checks.

## 1. The bug

While a video plays, the pointer never hides, in a window or in fullscreen. The bars do hide.

## 2. Cause and the change that brought it

`panelDismissArea` in `modules/gui/qt/player/qml/Player.qml` is a MouseArea that fills the whole player, above the video. It closes the player panels on a click outside them. It came with **538627909e** "redesign: player panels close on a click outside them" (2026-10-15), before the 0.1.0 beta.

A MouseArea sets the arrow cursor by default. Qt takes the cursor of the topmost item under the pointer that has one, **whether that item is enabled or not**. So the video surface's hidden cursor (`Qt.BlankCursor`, set by the `Binding on cursorShape` on the video surface) was always covered by this MouseArea's arrow. The panel area is only enabled while a panel is open, so its clicks worked as intended and nobody saw the side effect in the code.

- **Not** the recent fullscreen top bar and hover fixes (#65, #82) or the "..." menu fix: the pointer already stays in the released 1.1.0 and 1.1.2.
- **1.1.2 has it**, and so does every release since 0.1.0.

| Test | Result |
|---|---|
| Released Linux 1.1.2-beta2, playing, bars hidden, 6 s after the last move | pointer still shown (254 visible pixels, XFixes cursor image) |
| Released Linux 1.1.0-beta, the same | still shown (254 pixels) |
| Cone's own item cursors reach the screen on Linux X11 (the play button's hand cursor) | yes (337 pixels): the item cursor is what decides |
| Qt 6.8.3 (the version Cone bundles, PySide6 under Xvfb): an item with `Qt.BlankCursor` below a MouseArea | the arrow shows. Also when the MouseArea is disabled, has `acceptedButtons: Qt.NoButton`, or sits in a parent with opacity 0 |
| The same with `cursorShape: undefined` on the MouseArea | the pointer hides |
| A HoverHandler without a cursorShape, or an invisible (`visible: false`) item above | does not block |

## 3. The fix

`Player.qml`, two changes:

1. `panelDismissArea` gets `cursorShape: undefined` in the Cone build (`Brand.isPublic ? undefined : Qt.ArrowCursor`, checked in the Qt 6.8.3 harness: hidden with `isPublic` true, the arrow with false): no cursor of its own, so the video's cursor shows through. Its clicks are unchanged. (The Back/Forward MouseArea over the player already did this.) The other items that cover the video were checked: the bars are `visible: false` once faded out, the library pane is only visible while the library is open, the z 100 item has only a PointHandler.
2. The video surface's `Binding on cursorShape` (hide the pointer) now also needs:
   - playback playing (from #74, both builds),
   - and in the Cone build:
     - no player panel open (`RdPanels.current === ""`: tracks popup, settings sidebar, queue sidebar),
     - no modal open (`RdPanels.modalCount === 0`: the dialogs inside the player),
     - the "..." menu closed (`playerMenu.shown`),
     - the Up Next card not showing (`upNextCard.shown`).

   It already needed the bars hidden and the mouse away from the top and bottom edges, so the pointer hides at the same moment as the bars: after about 3 s without a move in a window, after VLC's `mouse-hide-timeout` in fullscreen.

From #74 (`MinimalView.qml`): the minimal view (Hide UI) hides the pointer only while playing, and pausing or stopping shows it again at once.

Settings opens its own window, so the player's pointer setting does not reach it.

The vlc profile keeps its behavior apart from #74's change (pointer only hidden while playing, in the binding and in the minimal view); its panel area keeps the arrow cursor.

## 4. Smoke checks (every build)

Linux (`.github/scripts/linux-smoke.py`, Xvfb, the pointer read with XFixesGetCursorImage) and Windows (`.github/scripts/win64-smoke.ps1`, GetCursorInfo and the cursor's pixels), on the h264 session, after the speed check (seeked to 1 s first, so the 30 s clip does not restart during them):

| Check | What it does | Must |
|---|---|---|
| pointer hides while playing (window) | move over the video, wait 4.5 s without moving, then move | shown after the move; hidden after 4.5 s; shown again after the next move |
| pointer stays while paused | pause, move, wait 4.5 s | still shown; then play again |
| pointer hides while playing (fullscreen) | F, move to the screen centre, wait 4.5 s | hidden; then F again |

`smoke-linux.yml` installs `libxfixes3` for the Linux check.

The window and fullscreen checks first ask the cli whether the video plays (`status`). After the paused check they resume with the cli's `pause` (a toggle): its `play` does not resume a paused player (`vlc_player_Start` returns at once on a started player). The first run used `play`, so its fullscreen check ran on a paused video and rightly saw the pointer kept (build-linux #75); checked by hand on that build: after `play` the status stays `pause`, after `pause` it is `play`.

## 5. Runs

| Run | Result |
|---|---|
| (filled in below the PR) | |

## 6. Windows retest (PC session)

Use this branch's build-windows zip or installer. Play `<TEST_VIDEO>`.

1. **Window.** Play, move the mouse over the video, then leave it still. After about 3 s the bars fade out **and the pointer disappears at the same moment**. Move the mouse: the pointer and the bars come back.
2. **Fullscreen.** Press F, leave the mouse still in the middle: the pointer disappears with the bars. Move it: it shows. Move to the top and bottom edges: the bars show and the pointer stays while it is there.
3. **Paused (PR #74).** Pause with Space, leave the mouse still for 10 s: the pointer stays. Press Space to play: the pointer hides about 3 s later.
4. **Menu.** Open "..." in the top bar and leave the mouse still over the menu or over the video: the pointer stays while the menu is open.
5. **Sidebar and tracks popup.** Open the gear sidebar, then the subtitles popup, then the queue: with each open, leave the mouse still over the video for 5 s: the pointer stays. Close it (click outside, or Escape): it hides again about 3 s later.
6. **Settings.** Open Settings while playing: the pointer stays over the Settings window.
7. **Up Next card.** Near the end of an episode with a next one in the folder, wait for the Up Next card: the pointer stays while it shows; pick an option, the next video plays, the pointer hides again after 3 s.
8. **Hide UI.** Ctrl+\ while playing: the pointer hides after the timeout; pause: it shows at once.
9. Clicks outside an open panel still close it (the area changed in step 1 of the fix only lost its cursor).
