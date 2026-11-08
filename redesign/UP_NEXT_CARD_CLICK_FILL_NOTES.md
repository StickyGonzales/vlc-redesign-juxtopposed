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
  - **What changes for the place:** with the bars hidden, the card waits where it sits when they are shown, so it never has to move when they come (see 1b for the height).

## 1b. The card sat too high (StickyGonzales, 1.2.0, 2026-11-03)
- **Found by StickyGonzales on 1.2.0** (screenshots: a Punisher episode, the dual-audio files with subtitles on): the card sat about a third of the screen up, with the bars shown and hidden.
- **Cause:** with a subtitle track on, the card reserved the subtitle band above the control bar: the bar's lift, sub-margin and two subtitle lines at the current size. At 1080p a line is about 88 px, so the card rose about 190 px above its usual place, also during the credits, which rarely have subtitles.
- **Reference:** Netflix shows its "Next Episode" button low in the bottom right corner, by the controls, and does not move it for subtitles. Netflix's other post-play layout shrinks the credits into a corner, which Cone does not do.
- **Fix:** the card always sits 24 px above the control bar's place, and 24 px from the right edge (or left of an open panel). This holds with or without subtitles, with the bars shown or hidden. Hide UI places it 24 px above the bottom edge. Its place is still held while it shows (section 1).
- **Trade-off:** centered subtitles pass beside the card. Only a long subtitle line that reaches the right quarter of the picture can meet the card's left part, for the seconds the card shows.

## 1c. "Sometimes a click on the card leads to the home page" (investigated)
- **What leads to the home page:** the main window leaves the player for the library when the player stops (`MainInterface.qml`: a stopped `Player.playingState` sets `MainCtx.playerView = false`). This happens when nothing plays any more, for example after the last episode, after Stop, or when the next file fails to open.
- **"Next episode" does not pass through stopped:** it calls the playlist's next, and the core sets the next file before it stops the current one (`vlc_player_SetCurrentMedia`: `next_media` first, so neither STOPPING nor STOPPED reaches the interface).
- **Tried on build-linux #79 in the sandbox** with a generated 5-episode show: Next episode in the waiting phase, Next episode in the last second as the episode ends, the thumbnail during the countdown, a double click on Next episode. Each time the next episode played and the player stayed up. Not reproduced.
- **Likely in 1.2.0:** the click itself showed the control bar and moved the card up (section 1). The press then landed on the button and the release beside it, so no click was made, or the click landed on what was under the pointer after the jump. The fix in section 1 removes that.
- **If it happens again on this build:** turn on Settings > General > "Save a log", reproduce, and send the log. Its "up next:" and player state lines show whether the next file failed to open or the queue ended.

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
| build-linux #82 (run 41550937673) | 9b61c57c15 (low place, 1b) | green, smoke included |
| build-windows #181 (run 41550932884) | 9b61c57c15 (low place, 1b) | green, smoke included |

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
**Linux sandbox on build-linux #82** (the low place, 1b; same media and steps):
| Check | Result |
|---|---|
| the card shows, bars hidden: extents 856, 484, 400 x 158 in the 1280 x 720 window, its bottom 78 px above the window's bottom (24 px above the control bar's place) | pass |
| press and release on the card's text: no control bar, the card does not move | pass |
| a mouse move shows the bars: the card stays at the same place, just above the bar | pass |
| countdown: "Playing in 4 seconds" | pass |
| no QML warning or error for RdUpNextCard | pass |

- **Screenshots:** `redesign/fix-shots/up_next_fill.jpg` (the fill, build #79) and `redesign/fix-shots/up_next_low.jpg` (build #82: top, bars hidden; bottom, bars shown, the card at the same place) (generated test video).

## Round 2 (PC test of #101, 2026-11-08)
1. **A click on the card's text still showed the control bar** (the buttons no longer did).
   - **Fix:** a passive press watcher over the whole card (`RdUpNextCard.pointerBusy`: pressed, and a double-click interval after the release). While it is busy, the player's pointer tracking takes no mouse move, and the video surface's press reports wake no bars (`Player.qml`).
   - So no click anywhere on the card (text, picture, buttons, empty space) shows the bar. Moving the pointer still shows the bars in a window, as everywhere (Decision 30).
2. **Next episode stopped the next episode at once and Cone went to the home page.** See `FIX_UP_NEXT_NEXT_STOP_NOTES.md`. There is a new smoke check on Windows and Linux.
3. **The update notice could sit on the card's Next episode button.** While the card shows, the notice sits 12 px above the card's top (`RdPanels.upNextCardTop`, set by `Player.qml`), never over it.

## Windows retest (PC session)
Build: the build-windows run of this branch (or `gh workflow run build-windows.yml --ref wip/up-next-card-click-fill`), Cone (portable), the 11-min test episodes of the #87 retest (strong names).
1. **Card place.** Play S01E01, seek to 1:30 before the end and keep the mouse still until the bars hide; the card shows. Move the mouse: the bars show and the card does not move (it already sits above the bar's place). Let the bars hide again: the card does not move.
2. **Click.** With the bars hidden, click Cancel: the card goes, the control bar does not show. Seek back, wait for the card, click on the card's text: nothing moves, no bar. Click Next episode: S01E02 starts, no jump during the click.
3. **Picture.** Click the thumbnail: the next episode starts, no bar during the click.
4. **Countdown fill.** Seek to 0:15 before the end: in the last 10 s "Next episode" turns dim and fills from left to right with "Playing in 10 s ... 1 s"; S01E02 starts as it is full. Hover the button during the countdown: the filled part is brighter.
5. **Narrow window.** Make the window under 900 px wide: the pill's Next episode button fills the same way, the heading counts "Up next in N s".
6. **Keyboard.** During the card, press Tab until Next episode has the focus ring: the control bar shows and stays while it has the focus; Enter plays the next episode. Escape on a focused card button cancels.
7. **Subtitles and height.** With a subtitle track on (the dual-audio Punisher files), the card sits low in the bottom right, 24 px above the control bar's place, as without subtitles, and does not move when the bars show or hide.
7b. **Click to the next episode, several times (high priority).** In the waiting phase, during the countdown and in the last second, with Next episode and with the thumbnail: the next episode starts and is **still playing 5 s later** every time; the player never goes to the home page. Do it with hardware decoding on (the default) and with the media library on.
7c. **Text click.** With the bars hidden, click the card's heading, the show name, the episode line and the empty space beside the buttons: no control bar every time.
7d. **Update notice.** With the update notice showing (an older build or the test switch), let the card show: the notice moves above the card and never covers Next episode; when the card goes, the notice goes back down.
8. **Hide UI.** Ctrl+\: the card sits 24 px above the bottom edge and stays there.
9. **Turn off autoplay.** Click it: autoplay turns off, no bar on the click.
