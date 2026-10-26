# Time jumps after a pause at a changed speed (issue #52, branch wip/fix-pause-rate)

Branch `wip/fix-pause-rate`, made from `origin/wip/next-test` (7e88341685), draft pull request into `wip/next-test`. **Core change** (`src/audio_output/dec.c`): build this branch on its own (Decision 55, build rounds rule), test on Windows, then merge. Nothing here is verified on Windows.

## The report
[Issue #52](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues/52) (beta 2, fullscreen): playing at 2x, paused for 10 to 15 minutes, resumed: the time jumped 20 to 30 minutes ahead (pause time x speed), the picture stayed frozen while the audio played; a seek fixed it.

## Cause
`vlc_aout_stream_ChangePause()` in `src/audio_output/dec.c`, on resume:

1. called the audio output module's `pause(false)` callback first,
2. and only then moved the stream's rate point (`timing.rate_system_ts`, the system time at which the audio played the first sample after the last speed change) by the pause.

Once the speed has been changed (to anything, also back to 1x), `vlc_aout_stream_NotifyTiming()` does not use the module's audio position; it computes the clock point from the rate point: `rate_audio_ts + (system_ts - rate_system_ts) * rate`. Windows' audio output (WASAPI, `modules/audio_output/wasapi.c`) reports a timing point from inside its resume callback (`Pause()` > `StartNow()` > `TimingReport()`). That report arrived in step 1, before step 2, so it was converted with the rate point of before the pause: the audio clock got a point exactly **pause duration x speed** ahead. The master clock then reset itself on that point ("coefficient too unstable"), so the shown time jumped ahead and every video frame was late against the clock and dropped, while the audio went on; a seek resets the clocks, which is why it fixed it. A file whose speed was never changed has no rate point and is not affected; after any speed change, even back to 1x, the jump is pause x the current speed (at 1x: the pause duration).

The Linux outputs report their timing later (PulseAudio and PipeWire from their own threads after the stream restarts, the dummy output from its next play call), which is why the sandbox's normal outputs do not show it; on Linux it would only be a narrow race.

Stock VLC 4: the same. `src/audio_output/dec.c`, `src/clock/`, `src/input/es_out.c`, `src/player/` and `modules/audio_output/wasapi.c` are identical to upstream VLC master (checked 2026-10-25, file by file) except for one unrelated hunk in `stream_Reset()`; this is an upstream VLC 4 bug.

## Fix
`vlc_aout_stream_ChangePause()` updates the rate point **before** it resumes the module, so a report from the resume callback is converted with the moved rate point. The pause bookkeeping and the rate point are now written under `timing.lock`, the lock `vlc_aout_stream_NotifyTiming()` reads them under from the module's thread (the struct's comment already listed `rate_system_ts` as guarded by it; the old code wrote it without the lock). Lock order is the one `vlc_aout_stream_NotifyTiming()` already uses (timing lock, then the clock lock). The rest is unchanged: the rate point is still converted with the clock, which the input has already moved by the pause (`EsOutChangePause()` resumes the program clocks before the decoders).

## Sandbox test (Linux)
The cloud sandbox's Linux build of `wip/next-test` (autotools, VideoLAN's Debian image), driven by a small libvlc program (`libvlc_media_player_set_rate`, `set_pause`, `get_time`, video through the memory callbacks to count the pictures shown): play 14 s, pause, resume, 15 s more; "jump" = time at the end - (time at the pause + speed x 15 s); the frame rate after the resume is compared with the one before the pause. Media: generated 20 minute clips, 320x180 25 fps with an AAC tone, H.264 in MP4 and HEVC in MKV (ffmpeg, no personal files).

Cores, each the same build with only libvlccore swapped:
- **ours**: `wip/next-test` 7e88341685;
- **stock**: the same with upstream VLC master's versions of the six core files that differ from ours (`src/input/input.c`, `src/input/decoder.c`, `src/audio_output/dec.c`, `src/video_output/video_text.c`, `video_widgets.c`, `vout_intf.c`; Cone's texts, the start-up deadlock fix, the OSD and subtitle margin changes);
- **fixed**: ours with this branch's `dec.c`.

Audio outputs: the sandbox has no WASAPI, so the dummy output was given, **in the sandbox build only** (never committed), WASAPI's behaviour of reporting its timing from the resume callback ("WASAPI-like"); plus the unmodified dummy output and PulseAudio (null sink).

3 minute pauses (the requested check: 2x should jump about 6 minutes):

| Output | Speed | Ours (H.264 / HEVC) | Stock (H.264 / HEVC) | Fixed (H.264 / HEVC) |
|---|---|---|---|---|
| WASAPI-like | 1x | 0 s / 0 s | 0 s / 0 s | 0 s / 0 s |
| WASAPI-like | 1.5x | **270.0 s / 270.0 s**, 12.7 fps of 37.5 | **270.0 s / 270.0 s** | 0 s / 0 s, 37.4 fps |
| WASAPI-like | 2x | **360.0 s / 360.0 s**, 12.8 fps of 50 | **360.0 s / 360.0 s** | 0 s / 0 s, 49.9 fps |
| dummy (unmodified) | 2x | 0 s / 0 s | | 0 s / 0 s |
| PulseAudio | 2x | 0 s / 0 s | | 0 s / 0 s |

The jump is exactly pause x speed (360 s = 6 minutes for 3 minutes at 2x), the picture drops to about 13 pictures a second (every picture "too late to be displayed" by the pause duration, after "resetting master clock: coefficient too unstable" in the log), and stock VLC 4 does the same. The PulseAudio null sink drops pictures at 2x in the sandbox before and after the pause alike (one HEVC run at 13 fps on both sides): a sandbox sink effect, not this bug.

Edge cases (WASAPI-like, H.264 unless said):

| Case | Ours | Fixed |
|---|---|---|
| 2x, back to 1x for 6 s, pause 60 s | **60.0 s** | 0 s |
| 2x, pause 60 s, 1.5x set while paused | **91.4 s** | 0.7 s (the speed change itself), then 1.5x |
| 2x, 20 pauses of 2 s, then pause 30 s | each pause jumped (time 80 s ahead before the last pause), then **60.0 s** | 0 s / 0 s (HEVC -0.3 s) |
| 2x, pause 20 s, seek to 2:00 while paused, resume (PulseAudio) | plays on at 2x, 50 fps | same (H.264, HEVC, and at 1x) |

The seek while paused could not be measured with the dummy output: its `Flush()` clears its pause date and its next `Pause(false)` then computes a wrong start (`adummy.c`, also in upstream, the sandbox's test output only), so it was run with PulseAudio. Unrelated and the same before and after the fix, also at 1x: a precise seek to 2:00 in the generated MP4 lands at about 2:50 (the MKV lands at 2:00).

VLC's own tests with the fix: `test_src_clock_clock`, `test_src_clock_start`, `test_src_player_pause`, `_timers`, `_seeks`, `_outputs`, `_discontinuities`, `_capabilities`: all pass. Independent review (fresh agent): no findings; lock order checked against every clock and timing lock user; it pointed out the "back to 1x" case above.

## Retest on Windows
Build this branch on its own (`gh workflow run build-windows.yml --ref wip/fix-pause-rate`), deploy it to the test folder as usual. Test files: a landscape H.264 MP4 and an HEVC MKV (not the designer's video). The speed is set in the settings sidebar, Playback tab (or with `]` / `[`); the time is read from the control bar.

0. Before, on 0.2.0 beta (optional, confirms the bug on this PC): 2x, play 30 s, pause 3 minutes, resume: the time jumps about 6 minutes ahead, the picture freezes, the audio plays.
1. This build, H.264, windowed: 2x, play 30 s, pause 3 minutes, resume. The time goes on from where it paused (within a second), the picture moves, audio and picture stay in sync for a minute.
2. Same at 1.5x and at 1x.
3. Same with the HEVC file, in fullscreen (the report's case), pausing with Space and resuming with a click on the video.
4. The report's own case: 2x, fullscreen, pause 15 minutes, resume: no jump, the picture moves.
5. 2x for 20 s, back to 1x for 10 s, pause 2 minutes, resume: no jump (the rate point stays active after any speed change).
6. 2x, pause, change the speed to 1.5x while paused, resume: the time goes on at 1.5x from the paused time.
7. 2x, pause, seek to a later chapter while paused, resume: playback continues from the seek target, picture moving.
8. 2x, 20 quick pause / resume presses (Space, about one a second): the time keeps moving forward at 2x, no jump, the picture keeps moving.
9. Regression: 1x pause / resume, seeking while playing, volume, track switching, quit (Ctrl+Q) after a paused resume: as before.

Settings > Audio > Output must be the default (WASAPI). If a test fails, note the output device and whether it was a Bluetooth or USB device, and rerun it with a log: `Cone.exe --file-logging --logfile=<TEST_MEDIA_DIR>\cone-52.log --log-verbose=2` (the lines around the resume: "resetting master clock", "picture is too late").

## Windows result (PC session, 2026-10-25): passed, merged into wip/next-test
Build 40235578425 (this branch at 3a799246a87), default output (WASAPI), generated 12 minute 720p30 files (a seconds counter in the picture; H.264 in MP4, HEVC in MKV), speed with `--rate` at start and the hotkeys afterwards, pause / resume with Space unless said, shown time read from the control bar (UI Automation), the picture checked on screen copies.

| Step | Fixed build | Unfixed (40223509797) / stock VLC 4 |
|---|---|---|
| 0. 2x, H.264, windowed, pause 3 min | | 0:41 -> 6:51 (Cone), 0:41 -> 6:50 (stock), picture frozen, "late video" storm |
| 1. 2x, H.264, windowed, pause 3 min | 0:43 -> 0:46, picture moving, 2 late pictures, no clock reset | |
| 2. 1.5x / 1x, pause 60 s | 2 s / 2 s | 1.5x: 98 s; 1x: 2 s |
| 3. 2x, HEVC, fullscreen, pause 60 s, resume with the Play button (a click on the video does not toggle pause in Cone, as in VLC 4) | 3 s, picture moving | |
| 4. 2x, HEVC, fullscreen, pause 15 min | 0:46 -> 0:49, counter 46 -> 50 -> 56 -> 68 over 9 s | |
| 5. 2x, back to 1x (`=`), pause 2 min | 3 s | |
| 6. 2x, slower (`-`) while paused | resumes at about 1.5x, 3 s | |
| 7. 2x, seek +60 s (Ctrl+Right) while paused | HEVC MKV: exact (+3 s); H.264 MP4: +16 / +76 s | H.264 MP4: +12 / +27 s: the generated MP4's own seek inaccuracy (see "Sandbox test"), not this fix |
| 8. 2x, 20 pause / resume presses about 1 s apart, then pause 10 s | time kept moving, resume 3 s; 24 late pictures, 2 clock resets during the presses | 31 s jump, picture frozen, 1428 late pictures, 11 clock resets |
| 9. Regression | smoke pass (7 shots looked at); every run quit cleanly with Ctrl+Q after a resume. Tracks / screens: in the final wip/next-test check | |

Jumps of 2-4 s are the measurement itself (the time is read 1 s after the resume plus the time to show the bar, at 2x). `[` / `]` did not change the speed in Cone (`-` / `=` did): not part of this fix, to look at separately.

## Draft reply for issue #52 (not posted)
> Thanks for the clear report, it was enough to find the bug. Once the playback speed has been changed, the pause bookkeeping in the VLC engine Cone is built on was updated in the wrong order on resume. Windows' audio output reports its position right when it resumes, so the clock took that report as if the pause had been playing at your speed and jumped ahead by pause time x speed. The picture then lagged behind that clock and was dropped, which is why you saw it frozen while the sound played, until a seek reset everything. It's the same in stock VLC 4, not something Cone added. A fix is ready and is being tested on Windows. It will be in the next Cone build, and I'll post here when it's out. Until then, a quick seek after resuming puts it right.
