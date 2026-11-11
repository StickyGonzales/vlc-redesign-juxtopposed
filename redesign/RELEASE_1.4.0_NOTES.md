# Release 1.4.0: release texts (draft, started 2026-11-11)

Nothing is released before StickyGonzales says go (earliest 2026-11-15, one Windows release a week).
Same layout as RELEASE_1.3.0_NOTES.md: Windows (full, Latest), Linux beta (pre-release), macOS
preview (pre-release). The fixes list leads with the settings fix (StickyGonzales, 2026-11-11).

---

## 1. Cone Player 1.4.0 (Windows), fixes section (draft)

## Fixed

- **Updating no longer deletes your settings.** The installer has an option "Delete preferences and
  cache", unticked by default. Earlier installers remembered it: if it had been ticked once, every
  later update deleted Cone Player's settings again, so the first-start screens came back and the
  OpenSubtitles API key, accent color, shows and library choices were gone. If that happened to you
  with 1.3.0, it won't happen again: from 1.4.0 the option starts unticked on every install, and an
  update keeps your settings unless you tick it yourself. Your settings can't be brought back, so
  please enter your OpenSubtitles API key once more after updating.
- **The OpenSubtitles account is saved as you type** (Settings > Subtitles > OpenSubtitles), so the
  API key, username and password are kept even if Cone Player closes while Settings is open.
- **Volume keys don't bring up the bars in movie mode.** When Cone Player is maximized or fullscreen,
  Up / Down and the mouse wheel over the video change the volume and show the volume message only;
  the top bar and the control bar stay hidden. In a normal window they show as before.

## New

- **Seek with the mouse wheel.** With the pointer on the timeline, each wheel notch jumps 10 seconds,
  forward when you scroll up, back when you scroll down. Elsewhere on the control bar the wheel still does
  nothing, and over the video it still changes the volume.

## Linux (beta)

- **On Wayland the video plays inside Cone Player's window again, and fullscreen has its bars (issue #116).**
  In 1.3.0 beta 4 on Wayland desktops it opened in a separate window with no controls; X11 was not affected.

(The rest of 1.4.0 is added as it is merged.)
