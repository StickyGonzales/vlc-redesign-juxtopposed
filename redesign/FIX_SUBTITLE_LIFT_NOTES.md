# Two-line subtitles under the control bar (branch wip/fix-subtitle-lift)

Branch `wip/fix-subtitle-lift`, made from `origin/wip/next-test` (eec9d03828), pull request into `wip/next-test`. Qt only (no core change). Nothing here is verified on Windows.

## Cause
With the bars shown, the lower line of a two-line subtitle sat half under the control bar (STATUS.md on wip/next-test, the test film at 1:28, also in the published beta). The lift (redesign/BETA_SUBS_NOTES.md) only counted the part of the bar that covers the **picture**: for a letterboxed film whose black bar is about as tall as the control bar, it was little or nothing. But VLC places text subtitles in the **whole window** ("spu-fill", on by default, with displays that blend subtitles: Direct3D 11 and OpenGL), so they sit on the black bar at the bottom of the video area, under the control bar. A 16:9 film in a 16:9 window has no black bar, so the beta's tests passed.

Sandbox (Linux build 11 of wip/linux-recheck, generated 2.39:1 MKV with two-line SubRip cues, window 1920 x 1080): bars hidden, the lines sit on the black bar at the bottom; bars shown, the lower line is half under the bar and one-line cues are cut.

## Fix
`Player.qml` `_subtitleLift`: the covered height is measured from the bottom of the video area, whatever the picture's shape. `RdSubtitleLift` loses its `pictureAspect` (the picture's shape is no longer needed). Bitmap subtitles (DVD, Blu-ray) are placed in the picture: in a letterboxed film they now rise by the whole bar too, so they also clear it (a few pixels higher than needed while the bars show).

Files: `modules/gui/qt/player/qml/Player.qml`, `modules/gui/qt/player/rd_subtitle_lift.hpp`, `.cpp`, `redesign/INTERACTIONS.md`.

## Retest on Windows
1. The test film at 1:28, windowed, bars shown: both lines of the two-line subtitle sit fully above the control bar; bars hidden: the lines go back down onto the black bar.
2. Fullscreen, pointer at the bottom edge: same.
3. A 16:9 file: unchanged from the beta (line just above the bar).
4. Pinned controls (video above the bar): subtitles do not move.
