# The pointer hides on the normal timer after Space resumes playback (1.4.0)

Branch `wip/fix-pointer-hide-resume`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-11.

## 1. The bug
- **The report:** after Space resumed playback, the pointer took about 6 s to hide instead of the usual about 3 s.
- **The cause** (`player/qml/Player.qml`, `PlayerToolbarVisibilityFSM.qml`):
  - Any key is keyboard input (`keyboardMove`), and keyboard input keeps the bars for twice the delay: `hideDelay * 2`, 6 s in a window. This is the "keyboard mode" that gives time to move through the controls with the arrow keys.
  - The pointer is hidden by the `Binding on cursorShape` over the video, which waited for the bars (`!isVisible`).
  - So after Space it followed the keyboard's 6 s.

## 2. The fix
- **The pointer's own idle timer:** `pointerIdleTimer`, at the bars' normal delay (`hideDelay`: 3 s in a window, VLC's mouse-hide timeout in fullscreen).
  - It is restarted by every mouse move and key (the bars' `mouseMove` / `keyboardMove`) and by the start of playback.
- **The binding** now also hides the pointer while the bars are up only for the keyboard mode (`keyboardShown`, not locked) once that timer has run out.
  - The bars keep their keyboard time; only the pointer stops waiting for it.
- **Unchanged:**
  - A mouse move shows the pointer and the bars as before (it ends the keyboard mode).
  - A hovered bar, an open menu, panel or dialog, and the Up Next card still keep the pointer (locked bars, and the existing conditions).
  - Paused: the pointer stays.
  - The fullscreen edge zones keep it too.
  - With "pin video controls" on (the bars never hide in a window), the pointer never hides either, after keys too (found by the independent review: the first version hid it 3 s after a key under pinned bars).
- **qmlcheck:** errors 1 (the known HighResolutionTimeWidget stub), crashed 0. **buildlists:** 0 problems.

## 3. Windows retest (PC)
Use a video longer than a minute, in a window. Rest the pointer over the middle of the picture without moving it, and time from the key press to the moment the pointer disappears.
1. **Space resumes.**
   - Pause with Space and wait 5 s (the pointer stays while paused).
   - Press Space: playback resumes, the bars show, and the pointer disappears after **about 3 s**.
   - The bars stay a little longer (about 6 s, keyboard mode) and then fade.
2. **Mouse only.** Move the mouse over the playing video and stop: the bars and the pointer hide after about 3 s, together (unchanged).
3. **Arrow keys in the bars.**
   - Press Space twice (pause, play), then Tab or an arrow key into the control bar within 3 s.
   - The bars stay while you move through them; the pointer is free to hide. Moving the mouse brings it back at once.
4. **Hovered bar.** Rest the pointer over the control bar while playing: the bar and the pointer stay (unchanged).
5. **Fullscreen.**
   - F, Space to pause, wait, Space to resume: the pointer hides after the fullscreen delay (VLC's "Hide cursor and fullscreen controller" setting, 1 s by default), not after the keyboard's double time.
   - Moving the pointer to the bottom edge shows the bar and keeps the pointer.
6. **Up Next card and menus.** With the "..." menu or a sidebar panel open, or the Up Next card showing, the pointer never hides (unchanged).
7. **Pinned bars.** Settings > Interface: pin the video controls. Play in a window, press Space twice: the bars stay and the pointer stays too. Unpin afterwards.
