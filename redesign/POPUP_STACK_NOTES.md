# Cone's notices stack instead of covering each other

Branch `wip/fix-popup-stack`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-12. Interface only (`modules/gui/qt`), plus the smoke checks.

## 1. The bug
- **Report:** with an update available, opening a file watched before shows the "You already watched till …" prompt (the resume toast) and the update notice in the same spot, one over the other.
- **Reproduced** on the current Linux build (screenshot `fix-shots/popup-stack/before-window-two.jpg`):
  - the update notice covers the toast, and only the toast's top edge peeks out;
  - accessibility positions: toast at y 590 to 642, notice at y 596 to 648.
- **Why:** each notice placed itself on its own.
  - The resume toast is in the player: 24 px above the control bar.
  - The update notice and the profile notice are popups over the whole window: 18 px above the control bar, centered on the window.
  - None of them knew about the others.

## 2. Every notice that can show at the same time
| Notice | Where | Before | Now |
|---|---|---|---|
| Resume toast ("You already watched till …", Figma "continue") | bottom, centered over the video | 24 px above the bar | the stack's lowest place |
| Profile notice ("… applies after a restart") | bottom, centered on the window | 18 px above the bar | the stack, above the toast |
| Update notice ("Cone Player X is available") | bottom, centered on the window | 18 px above the bar; above the Up Next card while it shows | the stack's top place |
| Up Next card (Cone extra) | bottom right, 24 px above the bar | fixed | unchanged; the stack moves up above it when they would meet |
| On-screen message (speed, volume, …) | top center, 16 px under the top bar | its own place | unchanged; never meets the bottom stack (screenshots) |
| Tray popup (track change) | a window of its own at the screen's corner | | unchanged, outside Cone's window |

## 3. Placement and spacing (Figma)
- **Figma** shows one notice at a time: the "continue" toast, 552×52, centered, 24 px above the control bar (frames Player, Player - Music, Player - hide UI, …). So:
  - **Place:** every bottom notice uses the toast's place: centered over the video area (right of the compact library, left of an open panel), 24 px above the control bar (24 px above the bottom with the bars hidden by Hide UI, and outside the player).
  - **Order, bottom to top:** resume toast, profile notice, update notice.
    - The toast belongs to the file that just started and is answered first.
    - The update notice is the least urgent.
  - **Spacing:** 10 px between notices, the gap Figma uses between the toast's parts (Decision 21; Figma has no frame with two notices).
  - **Alignment:** all on the same center line.
- **Up Next:** when the widest notice would reach the card, the whole stack moves above it, 10 px over the card's top.
  - So the update notice still never covers the Next episode button.
  - When they don't meet (a wide window), the stack stays in its place.
- **Motion:**
  - When a notice under another one closes, the one above slides down into its place in 200 ms with an ease-out curve (the performance rule's limit).
  - A window resize, fullscreen or an opened panel moves the stack at once, without a slide.
- **Client-side decorations (Linux):** the notices over the window map the stack through the window's frame margin, so they line up with the toast in the player.

## 4. Code
| File | Change |
|---|---|
| `player/qml/RdNoticeStack.qml` (new singleton, VLC.Player) | The stack's single source of truth. Each notice reports its size while it shows. It gives each notice its bottom and center line: the bar, the Up Next lift, the order and the gaps. It also maps the stack into the window's overlay. |
| `player/qml/Player.qml` | The resume toast reads its place from the stack. Player.qml reports the toast's size, the video area's center line and width, and the Up Next card's left edge. |
| `maininterface/qml/RdUpdateNotice.qml` | Places itself from the stack (the top slot) and reports its size. Its lift over the notices under it slides. |
| `dialogs/toolbar/qml/RdProfileNotice.qml` | The same, in the middle slot. |
| `Makefile.am`, `meson.build` | The new singleton. |

## 5. Checks
- **Static checks:**
  - `qmlcheck.py`: errors 1 (the known HighResolutionTimeWidget stub), crashed 0.
  - `buildlists.py`: 0 problems.
  - `privacycheck.py`: 0 problems.
- **Independent review** (a subagent, before the second commit) found four things, all fixed:
  - the smoke checks expected a seek to close the toast; it closes by itself after 10 s;
  - on Windows, the earlier sessions' stored update answer kept the forced answer from being read;
  - with client-side decorations, the overlay notices were off by the frame margin;
  - the notices slid on a window resize.
- **Smoke check on Linux and Windows** (`check_popup_stack` / `Check-PopupStack`):
  1. Watch "Smoke Show S01E03" to 2:00, then quit.
  2. Open it again with the update notice forced on (`CONE_UPDATE_CHECK_TEST_FILE`).
  3. Both the toast and the notice show. They don't overlap, the notice is above the toast, the gap is 10 px (6 to 14 accepted) and the centers are within 2 px.
  4. After the toast closes, the notice moves down into its place.
  5. Cone quits cleanly: a killed Cone makes the next start ask to restore its playlist, which blocked the next checks in build-linux #123.
  - **Before the fix** the same measurement fails: the toast at y 590 to 642 and the notice at y 596 to 648 overlap.

### Linux screenshots (Cone's window only, generated test media)
In `fix-shots/popup-stack/`. Same build as build-linux #123, Xvfb 1600×900, openbox:

| Shot | What it shows |
|---|---|
| `before-window-two.jpg` | the bug on the current build: the notice over the toast |
| `window-two.jpg`, `maximized-two.jpg`, `fullscreen-two.jpg` | two at once: the update notice 10 px above the toast, the same center line |
| `window-three.jpg`, `maximized-three.jpg`, `fullscreen-three.jpg` | three at once: the speed message at the top, the update notice and the toast stacked at the bottom |
| `window-after-toast.jpg` | the toast gone: the notice in its place, 24 px above the bar |
| `window-upnext.jpg`, `narrow-upnext.jpg` | the Up Next card and the notice: the notice lifted 10 px above the card, the Next episode button free |
| `maximized-upnext.jpg` | a wide window: the notice and the card don't meet, the notice stays in its place |

Positions measured through accessibility:

| Window | Toast | Update notice | After the toast | With Up Next |
|---|---|---|---|---|
| 1280×720 | (367, 590, 545×52) | (320, 528, 640×52) | (320, 590) | notice (320, 403), Next button at y 590 |
| 960×600 | (207, 470) | (160, 408) | (160, 470) | notice (160, 283), Next button at y 470 |
| maximized 1600×900 | (527, 770) | (480, 708) | (480, 770) | notice (480, 770), Next button at x 1172 (no overlap) |
| fullscreen | (527, 770) | (480, 708) | (480, 770) | as maximized |

Not on screen: the profile notice (it needs a profile switch with settings that apply later). It uses the same stack slot logic as the update notice; Windows retest step 4 covers it.

## 6. Runs
| Run | Result |
|---|---|
| build-windows #235 (43259627528), 8bfceaa | **green**. The new check: toast (235, 582, 553×52), notice (188, 520, 648×52) above it, 10 px apart, centers 0 px apart; then the notice took the toast's place. |
| build-linux #123 (43259619815), 8bfceaa | The new check **passed**: toast (367, 590, 545×52), notice (320, 528, 640×52), 10 px, centers 0; after it, (320, 590). The installed and .deb quit checks then failed: the popup-stack session had been killed, so their start showed the "closed abruptly" dialog. Fixed in a6dbe22 (a clean quit). |
| build-linux #124 (43267097808), a6dbe22 | **green**, every smoke check (the new one, and the installed and .deb sessions after it), Ubuntu 24.04 and 22.04, Debian 12, the Wayland / X11 embed checks |
| build-windows #236 (43267107083), a6dbe22 | **green**, every smoke check |

## 7. Windows retest (PC session)
Build: build-windows on `wip/fix-popup-stack`, Cone portable.

To force the update notice, run in PowerShell before starting Cone:
```
$env:CONE_UPDATE_CHECK_TEST_FILE = '<WORK_DIR>\answer.json'
```
The file holds `{"tag_name": "v9.9.9", "html_url": "https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v9.9.9"}`. If Cone checked for updates in the last 6 hours, remove `AnsweredAt` from the `[RdUpdateCheck]` part of `portable\Cone\vlc-qt-interface.ini` first.

1. **Two at once:**
   - Play an episode of a show to the middle and quit.
   - Open it again with the variable set.
   - The "You already watched till …" prompt sits 24 px above the control bar. The update notice sits 10 px above it, centered on the same line. Neither covers the other.
2. **Slide:**
   - Click the toast's X.
   - The update notice slides down into its place in about 0.2 s.
   - Open the file again and wait 10 s: the same happens when the toast closes by itself.
3. **Three at once:** with both showing, click the video and press `]`. The speed message shows at the top and the two notices stay where they are. Press `=` to go back to normal speed.
4. **Profile notice:**
   - Settings > Profiles: switch to a profile whose settings apply only after a restart, while the toast or the update notice shows.
   - The profile notice takes the middle place (above the toast, under the update notice). All three are 10 px apart and on one center line.
5. **Window sizes:** repeat step 1 in a normal window, maximized and fullscreen (F).
   - The stack stays above the bar.
   - Going in or out of fullscreen moves it at once, without sliding.
6. **Panels:** open the settings sidebar (gear) while both show. The notices center over the video left of the panel. Close it: they center again.
7. **Up Next:**
   - In a narrow window (about 960 px wide), play a show episode to its last minute with the update notice showing.
   - The notice sits above the Up Next card. The Next episode button is fully visible and clickable.
   - In a wide window the notice stays at its normal place, clear of the card.
8. **Library:**
   - Go to the library while the update notice shows: it sits 24 px above the window's bottom, centered.
   - Back in the player it returns above the bar.
9. **Regression:**
   - The update notice's Download / Later / Skip this version buttons work.
   - The toast's Continue Watching and X work.
   - Escape still leaves fullscreen.
