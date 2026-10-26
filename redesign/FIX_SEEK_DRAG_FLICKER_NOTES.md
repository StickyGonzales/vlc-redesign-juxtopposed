# Seek bar: lighter block flickering at the start while dragging (branch wip/fix-seek-drag-flicker)

Branch `wip/fix-seek-drag-flicker`, made from `origin/wip/next-test` (894453c1ad). Draft pull request into `wip/next-test`, for 1.0.1. Interface only (`modules/gui/qt/player/qml/SliderBar.qml`), no core change.

The bug, as reported in STATUS.md (2026-10-26, found by StickyGonzales in the installed 1.0.0 and reproduced on the 1.0.0 release zip):
- Pressing the seek bar and dragging makes a lighter rounded block flicker at the very start of the bar for the whole drag. It is about 120 px wide at 1600 x 900, 125 %. StickyGonzales: "the first 5 cm discolored".
- It goes away on release, and shows on Sintel (MKV), so it is not format related.

## 1. Cause
VLC's own seek bar code has a "buffering not started" loading animation: a 100 dp block, 40 % opaque and rounded, that bounces from the start of the bar.
- It showed whenever the player's buffering was exactly 0.
- Every seek sets the buffering back to 0 for a moment, until the decoder has data again.
- A drag seeks continuously, so the block appeared at x = 0 (the animation restarts at its start) and vanished again, frame after frame.

In stock VLC 4 the bar is 5 px thin, so the same flash is hard to see. Cone's 28 px thick bar shows it plainly.

## 2. Fix
The animation is meant for a media that is still opening, such as a stream that has sent nothing yet. It now shows only:
- once the buffering has stayed at 0 for `VLCStyle.duration_humanMoment` (2 s). That is VLC's documented "wait this long before showing a spinner" value, and the bar's other buffering display already uses it;
- and never while the bar is being dragged.

The states and the animation itself are unchanged.

## 3. Checks
qmlcheck: errors 1 (the known HighResolutionTimeWidget stub), crashed 0. buildlists 0, privacycheck 0.

## 4. Sandbox test (Linux)
Builds:
- **Before:** build-linux #38 (run 40216428165).
- **After:** build-linux #39 (run 40347524734), test-only branch `wip/seekfix-linux` = wip/linux-build + this branch + wip/fix-seek-thumbnails.

Setup: AppImage, Xvfb 1600x1000, window 1440x900, openbox. Generated episode (25:40, MKV).

**Method:**
- Press on the bar, then drag right in 60 steps and back in 30 steps, about 4 s.
- Record the bar area at 30 fps (ffmpeg x11grab).
- Measure the mean brightness of the bar's first 160 px in every frame.

| | Frames | Frames with the lighter block |
|---|---|---|
| Before (#38) | 150 | 33 (brightness 50-51 against 35, scattered over the whole drag) |
| After (#39) | 150 | 0 (35 in every frame of the drag) |

Pictures: `redesign/fix-shots/seek_drag_flicker_before_after.png` (two frames of the drag from each build, at 1.5x).

**The loading animation still works where it is meant to.** With a local HTTP server that accepts the connection and never answers, the block appears and bounces along the bar about 2 s after the open (`redesign/fix-shots/seek_loading_stream.png`).

## 5. Windows retest (PC session)
Build this branch: `gh workflow run build-windows.yml --ref wip/fix-seek-drag-flicker`, then the asset `wip-fix-seek-drag-flicker--win64-public.zip` from the `test-builds` draft (redesign/TEST_BUILDS.md).
1. Sintel (MKV), window 1600 x 900 at 125 %. Press the seek bar and drag slowly right and left for about 5 s. Record the bar area at 60 fps (gdigrab), as in run verifyruns\seekbugs. Expected: no lighter block at the start of the bar in any frame (before: on and off during the whole drag).
2. Same with the MP4 test files of seekbugs2 (one keyframe, keyframe every 2 s): no block.
3. Single clicks at several positions, and keyboard seeks (Right / Left, Ctrl+Right): no block.
4. Open a network stream that is slow to start (or a URL that does not answer): the bouncing block appears after about 2 s, as before, and disappears when playback starts.
5. Smoke: play, pause, seek, quit.
