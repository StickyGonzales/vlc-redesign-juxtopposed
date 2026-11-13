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
- **Cone tidies up after itself.** Up Next pictures, waveforms and downloaded subtitles are cleaned up: a show you deleted is forgotten after 14 days, a drive you unplugged keeps its data, a show you renamed or moved (also to another drive or drive letter) keeps its track choices, Up Next answers and credits points, and downloaded subtitles you tried but never used are deleted when the video closes. Settings > Playback > Remembered shows > Forget all also clears the pictures and downloaded subtitles. (PR #127)
- **Background work waits its turn.** Show detection, credits scans, waveforms and Up Next pictures share one low-priority queue: one job at a time, nothing heavy in Cone's first minute, paused while you seek or hover the seek bar. The Up Next card's picture is made a few seconds after an episode starts, so the card always has it. (PR #127)
- **Less work in the background.** Cone no longer redraws its interface while the bars are hidden or the window is minimized, searches for cast devices only while a Render list is open, and keeps the home page smooth during a big library scan. Quitting while Cone asks to restore the playlist no longer crashes. (PR #131)

- **A crash can now restore your playlist on Windows.** Cone saves the playlist at most 10 seconds after it changes, also while a video plays, so after a crash the next start offers to restore it. Quitting while that question is open keeps it for the next start; only Yes or No clears it. (PR #134)
- **Cleanup finishes even when you quit at once.** A downloaded subtitle you never used is deleted even if you quit right after moving on to the next file, each download is recorded once, and a file too short to be an episode gets no Up Next picture. (PR #134)

## Changed
- **Choose what happens when an episode ends.** Settings > Playback > Episodes > "When an episode ends" replaces "Play episodes in a row": **Play the next episode** (the countdown on the Up Next card, as before), **Show Up Next, I'll click** (the card offers the next episode and waits for your click, no countdown), or **Do nothing**. Your saved choice carries over. The card's "Turn off autoplay" now switches to "Show Up Next, I'll click". (PR #135)
