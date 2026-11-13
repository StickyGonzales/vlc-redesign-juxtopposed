# The music player's cover stays square (#129, #69)

StickyGonzales, 2026-11-13: issues #129 (Windows, FLAC and MP3) and #69 (macOS). The music
player's album cover was squeezed into a tall, narrow card instead of staying square. The PC
reproduced it on 1.4.0 and wip/next-test with a square 600x600 cover: about 120x380 at a 1040x570
window, 215x505 at 1500x600, 490x765 at 1100x900 (redesign/ISSUE_TRIAGE.md on wip/issue-triage).

**Reference.** Figma "Player - Music" and VIDEO_INDEX rows 209 (P6-04) and 211 (IB-23): a centred
square cover with rounded corners, 737 px high in a 1080 px window.

## Cause

`Player.qml` sized the cover's box from two unrelated things:
- its height from the window (the Figma share of it, capped by the pane's width and the space
  between the bars);
- its width from the image's painted width (`cover.paintedWidth`).

The image was anchored to the box's top and bottom but had no width of its own, so it took its
implicit width (the decoded picture's size). The painted width then depended on the picture and on
when it had loaded, not on the box. The rounded copy (`roundedCover`, the one on screen) filled that
box with "fit", so any mismatch drew a narrow or wide card. A cover that is not square was never
shown square at all.

## Fix

- **One explicit square.** The cover's box is now a square of side min(the Figma share of the window
  height, the pane's width minus margins, the space between the bars). Nothing in it depends on the
  image's size.
- **Any cover shape fills it.** The image and its rounded copy fill the square with
  PreserveAspectCrop, centred: a wide or tall cover shows its middle as a square, like a song row's
  thumbnail. The corners stay rounded (`rd_radius_cover`) and the glow is unchanged.
- **The blurred background still follows the picture's own shape.** Its aspect now comes from the
  image's implicit size instead of its painted size.
- **The no-artwork placeholder** uses the same square.
- **The rounded cover is named "Cover"** for accessibility (screen readers and the smoke check); the
  plain image carrying that name is hidden whenever the rounded copy draws.

## Test

- **Linux smoke `check_music_cover`.** Two generated FLAC songs: a square 600x600 cover and a wide
  800x400 one (smoke-media.sh).
  - **Sizes.** For each song the cover's on-screen box is measured through AT-SPI at 1040x570,
    1500x600, 1100x900, 600x900, 480x360, 1280x720 and the screen size.
  - **Fullscreen.** Measured last for both songs, entered with the top bar's Fullscreen button.
  - **Screenshots.** One for each size (`cover-<song>-<size>.png`).
  - **It fails if:**
    - width and height differ by more than 2 px, or the cover is under 40 px;
    - the cover shows no picture over its whole height. The middle and thin strips near the top and
      the bottom must be colourful: the grey placeholder fails the middle, and a wide cover fitted
      (letterboxed) instead of cropped fails the strips.
  - **Waiting.** It waits for the picture to load before measuring, so the placeholder standing in
    while it loads is never measured.
- **Local result (ASan Linux build).** Both songs are square everywhere:

  | Window | Cover |
  |---|---|
  | 1040x570 | 388x388 |
  | 1500x600 | 409x409 |
  | 1100x900 | 614x614 |
  | 600x900 | 552x552 |
  | 480x360 | 245x245 |
  | 1280x720 | 491x491 |
  | screen-sized (1600x1000 test screen) | 682x682 |
  | fullscreen | 682x682 |

- **The check against the old layout** (old Player.qml with only the accessible name added): the
  wide cover failed at once (777x388 at 1040x570).
- **What Linux could not reproduce.** The old layout kept the square cover square on Linux, so the
  exact 120x380 squeeze is Windows-specific: there the image's painted width differed from the box
  (the picture's decode size or its loading). The new layout no longer reads the painted width, so
  the Windows retest below is the check for that case.

- **Not changed: the blurred background.** For a cover that is not square it still blurs the whole
  picture behind the square crop. Figma only shows square art. Cropping the blur's texture would
  have to handle texture atlases (small covers); recorded in VIDEO_INDEX "Decisions (Claude)".
- **Independent review.** Seven findings, all fixed except the blur above. The main ones were in the
  check:
  - a wide cover letterboxed would have passed;
  - the fullscreen step was not verified;
  - the placeholder could be measured while the cover loaded.
  In the QML, the height cap now follows the pane (the lyrics pane is shorter), and screen readers
  hear "Cover" once.

## Green runs

- build-linux #143 (9d54fe6b23): build, packages and smoke pass, including the three music-cover
  checks (square cover at every size, wide cover cropped, both in fullscreen).
- build-windows #254 (9d54fe6b23): build, installer and the Windows smoke pass.

## Found on the way (not changed, for StickyGonzales)

- **F and Escape do not toggle fullscreen while only music plays.** Seen on the Linux build with
  this branch and the code before it. The top bar's Fullscreen button works. With a video, F and
  Escape work. VLC's fullscreen keys act on the video output, so this is likely VLC's behaviour with
  no video. Worth a look on Windows during the retest (step 2); if Cone should toggle fullscreen
  with F in the music view too, that is a separate task.

## Windows retest (PC session)

Build: build-windows on wip/fix-music-cover (the run in the PR). Media: the same MP3 with a square
600x600 cover as in the reproduction, plus any song whose cover is not square.

1. **The reproduction.** Play the MP3 in a window of about 1040x570. The cover is square, rounded,
   centred, with the title under it. Then 1500x600 and 1100x900: square each time.
2. **Window sizes.** Drag the window small (about 480x360), very wide, very tall, then maximize, then
   fullscreen (the top bar's Fullscreen button; also try F and Escape, see "Found on the way"): the
   cover stays square and scales with the space; nothing overlaps the bars.
3. **Another song.** Play the next song in the queue while the window is small: the new cover is
   square at once, with no tall card flash while it loads.
4. **A cover that is not square.** The cover is a square showing the middle of the picture; the
   blurred background shows the whole picture.
5. **A song without a cover.** The grey square placeholder with the music icon, square at every size.
6. **Lyrics** (a song with lyrics, the lyrics pane open): the cover in the right pane stays square
   and fits the pane.
7. **Regression.** Play, pause, seek, Next and Previous between songs, the mini player in the
   library, quit.
