# Ctrl+Q always quits like the close button (1.4.0)

Branch `wip/fix-ctrlq-quit`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-11 (the CHECK row "did not close on Ctrl+Q").

## 1. The bug
- **The report:** Ctrl+Q sometimes left Cone running with its window, and the test harness ended it after about 40 s.
  - PC test 2026-11-08, once at `QT_SCALE_FACTOR=1.5`.
  - 2026-11-11, at 100 %, right after Settings was closed with its X.
  - The window's close button always quits.

## 2. The cause
Cone has two ways for Ctrl+Q to reach a quit:

- **Qt's shortcut** (`menus/qml/GlobalShortcuts.qml`): `DialogsProvider::quit()`, the same as the close button and the "..." menu's Quit.
  - It saves the interface state, settings and resume position.
  - It arms the **quit watchdog** (`util/quit_watchdog.cpp`), which ends the process if the quit does not finish within 5 s.
- **VLC's hotkeys:** while the player shows and no popup holds the keys, `MainCtx.preferHotkeys` is on. `InterfaceWindowHandler::applyKeyEvent` then sends every key straight to VLC's hotkeys, before Qt's shortcuts see it (Space must pause, not press a focused button).
  - Ctrl+Q is VLC's "key-quit" too, so the hotkeys module (`modules/control/hotkeys.c`, `ACTIONID_QUIT`) called `libvlc_Quit()` directly.
  - That skips `DialogsProvider::quit()`: nothing is saved first, and the watchdog is armed only when the interface module's Close runs.
  - When the quit stalled before that point, nothing ended Cone, so the window stayed until the harness ended it.

Which way a Ctrl+Q took depended on where the keyboard focus was:
- **After Settings closed with its X,** the focus goes back to the player, so the keys go to VLC's hotkeys: the second report.
- **With a menu or a panel focused,** the Qt shortcut wins and Ctrl+Q quits like the close button.

## 3. The fix
`MainCtx::sendVLCHotkey()` (`maininterface/mainctx.cpp`):
- A key set for "key-quit" (Ctrl+Q by default, or whatever the user set in Keyboard Shortcuts) calls `DialogsProvider::quit()` instead of going to VLC's hotkeys. This is the same path as the close button: state saved, watchdog armed, one quit only (`b_isDying`).
- Every key the player sends to VLC goes through this function: key presses, and mouse-wheel keys.

## 4. Windows retest (PC)
Use any video.
1. **After Settings' X:** play a video, open Settings (the "..." menu > Settings, or Ctrl+P), close it with its **X**, press **Ctrl+Q**: Cone closes within a second or two. Repeat 5 times.
2. **Player focused:** play a video, click the picture once, press **Ctrl+Q**: Cone closes.
3. **Paused, fullscreen:** Space to pause, F for fullscreen, Ctrl+Q: Cone closes.
4. **Simulated 150 %:** start Cone with `$env:QT_SCALE_FACTOR = '1.5'` in PowerShell, play a video, open and close Settings with its X, Ctrl+Q: Cone closes. Then `Remove-Item Env:QT_SCALE_FACTOR`.
5. **Settings survive:** change the volume, quit with Ctrl+Q and start again: the volume and the window size are kept (Ctrl+Q saves like the close button).
6. **A changed quit key:** Settings > Controls > Keyboard Shortcuts, set Quit to another key (for example Ctrl+Shift+Q), restart, play a video, press it: Cone closes. Set it back afterwards.
