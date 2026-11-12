# The release after 1.4.0: release notes (draft, started 2026-11-12)

Nothing is released before StickyGonzales says go. Items are added as they are merged into wip/next-test;
the texts are written up in the 1.4.0 style (by area, with tips) when the release is made.

## Fixed

- **Notices no longer cover each other.** The "You already watched till ..." prompt, the update notice and the
  profile notice ("Some settings of ... apply after Cone restarts") now stack above the control bar, centered,
  10 px apart: the prompt at the bottom, the profile notice in the middle, the update notice on top. When one
  closes, the ones above it slide down into its place. This works in a window, maximized and in fullscreen, and
  the stack stays clear of the Up Next card's Next episode button in a narrow window. (PR #126)
- **Quitting is instant.** Ctrl+Q, the window's close button and Quit in the menu hide Cone Player at once and
  stop the sound; the rest of the shutdown happens in the background (VLC 4 itself takes about 2 seconds to quit
  on Windows). If a shutdown ever gets stuck, Cone Player still ends itself within 5 seconds. A window that is
  waiting for your answer (a dialog) stays until the quit ends. (PR #128)
