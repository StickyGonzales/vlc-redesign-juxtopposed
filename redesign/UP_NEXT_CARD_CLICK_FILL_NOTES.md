# Up Next card: a click shows no control bar, the card holds still, the button fills (branch wip/up-next-card-click-fill)

Branch `wip/up-next-card-click-fill`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone extra (Decision 71, Up Next). Interface only: `player/qml/RdUpNextCard.qml`, `player/qml/Player.qml`.

## 1. A click on the card showed the control bar and moved the card
- **Found by StickyGonzales:** clicking "Next episode" also showed the control bar. The card sits above the bar, so it jumped up during the click and the click almost missed the button. Moving the mouse over the card did not show the bar, only the click did.
- **Cause:**
  1. A click gave the button the keyboard focus (`focusPolicy: Qt.StrongFocus`).
  2. A focused card holds the bars up (`onActiveFocusChanged: rootPlayer.lockUnlockAutoHide(activeFocus)` in Player.qml, so Tab users keep the bar while on the card), and that lock shows them first.
  3. The card's place counted the bar only while it was shown (`controlBar.opacity`), so it rose with the bar.
- **Fix:**
  - **No focus on a click:** the card's buttons (Next episode, Cancel, Turn off autoplay, the pill's buttons) take the focus only by Tab (`Qt.TabFocus`). A click on them, on the picture or on the card does not focus the card, so it does not show the bar. Tab still reaches them, holds the bar up while they have the focus, and Escape cancels.
  - **The card holds still:** its place counts the control bar as shown, whether it is or not: 24 px above the bar's height, or 16 px above the subtitle band with the bar's lift. The place is held from the moment the card appears until it is gone, so nothing under it (a bar showing or hiding, the subtitles rising) moves it. Hide UI places it 24 px above the bottom edge.
  - **What changes for the place:** with the bars hidden, the card now waits where it sits when they are shown (a bar's height higher than before), so it never has to move when they come.

## 2. Netflix-style countdown
- **During the credits** (no countdown yet): unchanged. "Next episode" in the accent color, "Plays at the end of the episode".
- **The last 10 s:**
  - The Next episode button turns Accent/Dim and fills with the accent color from left to right as "Playing in N s" counts down. It is full as the next episode starts.
  - Each second's step glides over that second (linear), one step ahead of the number. Under the pointer, the filled part is Accent/Bright, like the button's hover.
  - The button keeps its "Next episode" text through the countdown (it said "Play now" before).
- **Dropped:** the 3 px countdown line at the card's foot and the 2 px line in the compact pill. The button's fill replaces them, and the card is 9 px shorter without the line's room.
- **The compact pill:** its Next episode button fills the same way; its heading still says "Up next in N s".
- **Unchanged:** "Still watching?" (no countdown, no fill).

## Checks
- `qmlcheck.py`: errors 1 (the known HighResolutionTimeWidget stub limit), crashed 0.
- `buildlists.py`: 0 problems. `privacycheck.py`: 0 problems.

## Runs
| Run | Head | Result |
|---|---|---|
| build-linux #79 (run 41535409514) | 1fe7791682 | green, smoke included |
| build-windows #176 (run 41535414370) | 1fe7791682 | green, smoke included |

**Linux sandbox on build-linux #79** (Xvfb + openbox, the generated "Plain Show" 10 min episodes, card at 9:05):
| Check | Result |
|---|---|
| the card shows ("Up next: Plain Show, S01E02. Plays at the end of the episode.") | pass |
| pointer resting on the card's text until the bars hide, then mouse button down and up on it: the control bar stays hidden (bottom strip of the screenshot stays the bright picture before, during and after the press) | pass |
| the card's place (AT-SPI extents 856, 484, 400 x 158) before, during and after the press | pass, unchanged |
| a mouse move over the video shows the bars: the card stays at the same place, above the bar | pass |
| countdown at 4 s left: "Playing in 4 seconds", the Next episode button filled about 70 % (one step ahead, full as the next episode starts) | pass |
| no QML warning or error for RdUpNextCard in the log | pass |

- **The test's own mouse move:** in a window, any mouse move over the video shows the bars (Decision 30), so a test that moves onto the card shows them by moving. The check presses only once the pointer has rested on the card and the bars have hidden.
- **Screenshots:** `redesign/fix-shots/up_next_fill.jpg` (generated test video).

## Windows retest (PC session)
Build: the build-windows run of this branch (or `gh workflow run build-windows.yml --ref wip/up-next-card-click-fill`), Cone (portable), the 11-min test episodes of the #87 retest (strong names).
1. **Card place.** Play S01E01, seek to 1:30 before the end and keep the mouse still until the bars hide; the card shows. Move the mouse: the bars show and the card does not move (it already sits above the bar's place). Let the bars hide again: the card does not move.
2. **Click.** With the bars hidden, click Cancel: the card goes, the control bar does not show. Seek back, wait for the card, click on the card's text: nothing moves, no bar. Click Next episode: S01E02 starts, no jump during the click.
3. **Picture.** Click the thumbnail: the next episode starts, no bar during the click.
4. **Countdown fill.** Seek to 0:15 before the end: in the last 10 s "Next episode" turns dim and fills from left to right with "Playing in 10 s ... 1 s"; S01E02 starts as it is full. Hover the button during the countdown: the filled part is brighter.
5. **Narrow window.** Make the window under 900 px wide: the pill's Next episode button fills the same way, the heading counts "Up next in N s".
6. **Keyboard.** During the card, press Tab until Next episode has the focus ring: the control bar shows and stays while it has the focus; Enter plays the next episode. Escape on a focused card button cancels.
7. **Subtitles.** With a subtitle track on, the card sits above the subtitle band and does not move when the bars show or hide; the subtitles never go under it.
8. **Hide UI.** Ctrl+\: the card sits 24 px above the bottom edge and stays there.
9. **Turn off autoplay.** Click it: autoplay turns off, no bar on the click.
