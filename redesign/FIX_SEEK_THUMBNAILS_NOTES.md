# Seek preview: the same frame at every position on files with few keyframes (branch wip/fix-seek-thumbnails)

Branch `wip/fix-seek-thumbnails`, made from `origin/wip/next-test` (894453c1ad). Draft pull request into `wip/next-test`, for 1.0.1. Interface only (`modules/gui/qt/player/rd_seek_thumbnailer.cpp` / `.hpp`), no core change.

The bug, as reported in STATUS.md (2026-10-26, found by StickyGonzales in the installed 1.0.0 and reproduced on the 1.0.0 release zip):
- Hovering the seek bar shows the same thumbnail at every point.
- StickyGonzales's case was an MP4 screen recording.
- The PC's two generated H.264 MP4s (one keyframe; "a keyframe every 2 s") showed the first frame at 10, 30, 50, 70 and 90 %. Sintel (MKV) was fine.

## 1. Cause
The preview used **fast seeks** only: VLC's thumbnailer jumps to the keyframe (sync sample) before the position and decodes that one picture.
- In a file with few keyframes, every position lands on the same keyframe, so every hover shows the same frame.
- Reproduced in the sandbox (build-linux #38): a generated 720p MP4 with one keyframe shows "00:00:00.000" at all five points. A file with a real keyframe every 2 s (`x264 -g 60`) shows the nearest keyframe (10, 26, 44, 62, 80 s), as designed.

**Why the PC's "keyframe every 2 s" file was stuck too (inferred, please confirm):**
- ffmpeg's `-force_key_frames` makes x264 I-frames that are not IDR (x264's `forced-idr` is off by default).
- MP4 lists only IDR frames as sync samples, so VLC sees one keyframe. Fast seeks then land on the first frame.
- MKV marks keyframes differently, which fits Sintel being fine.
- Screen recorders can write the same kind of file (long GOPs, or I-frames that are not sync samples).

## 2. Fix
1. **Detect it from the frames themselves.** Two fast-seek frames whose timestamps differ from the hovered times' difference by more than an eighth of the length (4 to 12 s; normal GOPs stay under 10 s) mean the fast seeks miss.
   - Only differences are compared, because timestamps do not start at 0 in every format (MPEG-TS).
   - The media then switches to precise mode: the frames shown so far are dropped, and the log says `seek preview: the keyframes are too sparse for fast seeks, using precise seeks for this media`.
2. **Precise mode.** A precise seek decodes every frame from the keyframe before the position up to the position itself. It uses 4 decoder threads instead of 2, and no loop filter (invisible at the card's size). For each position:
   - The first frame's timestamp is taken once, as the time base.
   - A fast seek finds the keyframe before the position.
   - **Close keyframe:** within 1 s (or half a bucket) of the position, its frame is shown as it is.
   - **Within budget:** otherwise a precise seek runs, if decoding from the keyframe fits a budget in pixels decoded (width x height x frames).
   - **Too far:** the card shows the time only (log: `... s from a keyframe, too far to decode in time`), not a wrong frame.
3. **Why a budget.** VLC lets a precise seek stop only once it has reached its position: the input waits in `vlc_input_decoder_Wait`, which neither a cancel nor the thumbnailer's timeout ends. Without a bound, a hover near the end of a long one-keyframe file kept the thumbnailer decoding for minutes, and a quit during it waited too (sandbox: 3.9 s instead of 0.3 s).
   - The budget is 1.5 s of decoding at the speed the last precise seek measured: pixels per second, from any precise seek that took at least 300 ms, kept between 2.5e8 and 4e9.
   - Before the first measurement it is 1e9: about 16 s of 1080p30 or 36 s of 720p30 on the sandbox's 4 cores.
   - A precise request is never cancelled as stale (it would run to its end anyway); its frame is kept.

Making that wait interruptible is a core change. It is the same escape STATUS.md lists for the HEVC quit stall ("needs a decision"), so it is not part of this branch.

## 3. Checks
- `rd_seek_thumbnailer.cpp` compiles with no new warnings (g++ `-Wall -Wextra -Wconversion`, syntax check against Qt 6 headers).
- buildlists 0, privacycheck 0. No QML changed.
- Windows names (2026-10-26): the first version did not compile on Windows (build 40360964324): the local variable `far` is a macro in Windows' `minwindef.h`. It is now `farLimit`. Every identifier the change adds was checked against Windows' header macros (`far`, `near`, `small`, `interface`, `pascal`, `min`, `max`, `ERROR`, `IN`, `OUT`, ...): only `far` clashed. `min` / `max` appear only as `std::min` / `std::max`, which the file already used before. A syntax check with those macros defined (`-Dfar= -Dnear= -Dsmall=char -Dinterface=struct -Dpascal=`) gives the same 2 errors as the Windows build on the old code and none now.

## 4. Sandbox test (Linux)
Builds:
- **Before:** build-linux #38 (run 40216428165).
- **After:** build-linux #41 (run 40354935239), test-only branch `wip/seekfix-linux` = wip/linux-build + this branch + wip/fix-seek-drag-flicker.

Setup: AppImage, Xvfb 1600x1000, window 1440x900. Hover at 10, 30, 50, 70 and 90 % of the bar, 4 s each. Generated test files show their own time stamped in the picture.

| File | Before | After |
|---|---|---|
| 720p MP4, 90 s, one keyframe | 00:00:00.000 at all five points | 10.4 s and 27.4 s exact; 45 s and later: time only (too far) |
| 720p MP4, keyframe every 2 s | nearest keyframe (10, 26, 44, 62, 80 s) | the same, fast seeks, no switch |
| the same as MKV | the same | the same |
| 1080p MP4, 3 min, keyframe every 30 s | - | 90.0, 125.5, 160.5 s exact; 20 s and 55 s: time only (20-25 s past a keyframe) |
| 1080p MP4, 3 min, one keyframe | - | time only at every point from 20 s on |

Picture: `redesign/fix-shots/seek_thumbnails_before_after.jpg`.

Quit (Ctrl+Q) right after hovering:

| Case | Quit time |
|---|---|
| No hover | 0.2-0.3 s |
| Precise request running, before the budget | 3.9 s (twice) |
| Precise request running, after (#41) | 1.0 and 1.1 s |
| Far positions on the 1080p one-keyframe file (no precise request runs) | 0.5 s |

**Limits:**
- On a long file with a single keyframe, only the first part previews (as far as about 1.5 s of decoding reaches); later positions show the time only.
- A fragmented MP4 (`-movflags frag_keyframe+empty_moov`, as OBS writes by default) shows grey, broken frames, before and after this change. Without an index, VLC's MP4 demuxer seeks to the exact sample in the fragment, not to its keyframe (`FragSeekToTime`). That is upstream demuxer behaviour, and a core change; not touched here.
- The colour-filter previews (`rd_filter_preview.cpp`) also use fast seeks; not changed (they show one frame of the playing position).

## 5. Windows retest (PC session)
Build this branch: `gh workflow run build-windows.yml --ref wip/fix-seek-thumbnails`, then the asset `wip-fix-seek-thumbnails--win64-public.zip` from the `test-builds` draft (redesign/TEST_BUILDS.md). Use a Cone log with Developer mode (Settings > General > Diagnostics) to see the `seek preview:` lines.
1. **The two seekbugs2 MP4s** (one keyframe; keyframe every 2 s). Hover at 10, 30, 50, 70, 90 %, holding about 3 s each.
   - Expected: from the second hover on, each preview shows its own position's frame, or the time only for positions too far from a keyframe; never the same frame everywhere.
   - The log shows the "too sparse" line once per file.
2. **StickyGonzales's MP4 screen recording.** Same hovers. Note how much of the bar previews and how long a preview takes. (The budget aims at about 1.5 s per preview; a faster PC measures its own speed after the first preview and reaches further.)
3. **Sintel (MKV) and a normal MP4 film.** Previews as fast as before, no "too sparse" line in the log.
4. **Quit right after hovering** (Ctrl+Q while a preview is still loading) on the one-keyframe MP4: Cone closes within about 2 s, with no watchdog line in the log.
5. **Hover while playing** the screen recording for 20 s: playback stays smooth (no dropped frames in Show Statistics compared with no hover).
6. Smoke: play, pause, seek, quit.
