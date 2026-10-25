# PERF: performance and motion log

Sticky's rule (CLAUDE.md, Quality rules): the redesign must feel at least as snappy as stock VLC.
Every build round is measured on this PC against stock VLC 4 (Phase 1 build, run 38315049322),
both in portable mode, same media, on a quiet machine. A regression on any target stops
everything, like a crash.

## How to measure
- `redesign/tools/perf/vlcperf.ps1 -Build <build dir> -Kind stock|redesign -Out <json>` runs every
  scenario (startup, open, play, idle, panel, seek, motion, 4k, queue); results go into the
  tables below. It refuses to run when the PC is busy (> 15 % CPU before starting).
- PC: 8 logical cores, NVIDIA RTX 2060, 2560x1440 at 99 Hz, Windows scaling 125 %; window
  2400x1350 physical (1920x1080 logical). Media: `<TEST_VIDEO>` (2560x1440 H.264),
  `perfmedia\4k60_80mbps.mp4` (3840x2160 60 fps, about 80 Mbit/s, generated with ffmpeg),
  `perfmedia\queue500.m3u` (520 entries).
- Smoothness: VLC renders its QML through its own compositor (QQuickRenderControl), so
  QSG_RENDER_TIMING prints nothing, and VLC's Qt has no QML profiler. Instead the screen is
  captured with Desktop Duplication (ffmpeg ddagrab polling at 240 Hz, only changed frames, no
  pointer, millisecond timestamps via `-enc_time_base 1:1000`) during scripted interactions on a
  paused video. The input is driven from C# on a 1 ms timer: a pointer step every 4 ms (2.5 steps
  per 99 Hz refresh), so every refresh has new input to show; every event is logged on the QPC
  clock. A 20x20 marker square of our own (bottom-left corner, no focus, click-through) flips
  black/white at logged times before and after each interaction; `motion.py` uses the flips to
  map the input log onto the capture (`sync.spread_ms` says how well they agree). It reports, per
  interaction: drags and wheel scrolling: gaps between UI updates only while the input moves,
  how many input steps arrived inside each gap (`worst_gap_steps`, `stalls` = gaps over 16.7 ms
  with an input waiting more than one refresh) and per-step response time; hover: latency from
  the pointer crossing a control to its first change, frame pacing inside the hover animations;
  panel open/close: click release to first change in the panel region, animation length, gaps.
  On the 99 Hz monitor a smooth update is every ~10 ms; a gap over 16.7 ms is below 60 fps.
  Capture stamps are 0-4 ms after the real present; latencies are relative to the marker (a GDI
  paint shown at the next refresh). Each capture has `<capture>.input.json` and `<capture>.png`
  (last frame) next to it: check the PNG shows the panel open where the region expects it.
  Offline check of the analysis: synthetic captures with known stalls and latencies, encoded the
  same way, are recovered within one refresh.
- CPU from the process times, RAM private bytes, GPU from nvidia-smi (whole GPU and the video
  decoder; valid because the machine is quiet). Dropped frames from VLC's own statistics (cli
  interface on 127.0.0.1, `stats`: frames displayed / lost).

## Targets
| Target | Measure | Limit |
|---|---|---|
| UI never below 60 fps (hover, panels, popups, seek/volume drag, list scroll) | worst gap between UI updates during the interaction | <= 16.7 ms, and no worse than stock |
| Clicks and keys react instantly | input to first visible change | <= 1 frame (~10-17 ms) plus the stock baseline |
| Animations short | measured duration | Figma duration, else 150-200 ms |
| Startup / open file | launch to window / launch to first video frame | no worse than stock |
| CPU, GPU, RAM (playing, idle, panels open, seeking) | averages | close to stock; any big gap is a bug |
| 4K / high bitrate, windowed and fullscreen | frames lost (VLC stats) | no more than stock |
| 500+ item queue | open latency, scroll gaps | smooth (as above) |

## Rounds

### Round 1 (2026-10-14): stock 38315049322 vs redesign 38441433330
Raw results: `<WORK_DIR>\perfruns\r1\*.json` (not committed). The first
redesign pass ran with 29 % background CPU (Sticky working), so startup and open were measured again
back to back, two rounds of three launches each, alternating stock and redesign.

| Measure | Stock | Redesign | Verdict |
|---|---|---|---|
| Startup to window (ms, back to back) | 1191/1202/903, 1049/914/893 (median ~1000) | 1124/1021/1222, 1546/1122/1070 (median ~1120) | about +100 ms, within noise of the busy PC; re-measure |
| Open file to first video frame (ms, back to back) | 1490/1402/1460, 1250/1413/1396 (median ~1400) | 2993/1622/1673, 1661/1681/1784 (median ~1680) | **REGRESSION ~+300 ms** (stop-everything). Likely cause: every player panel is built eagerly on the first video; the lazy panels branch should fix it |
| Playing: CPU / RAM private / GPU / decoder | 0.2 % / 296 MB / 6.3 % / 20 % | 0.4 % / 321 MB / 8.7 % / 20 % | OK (+25 MB RAM, GPU within noise of the busy PC) |
| Idle paused: CPU / RAM | 1.1 % / 295 MB | 0.1 % / 317 MB | OK |
| Seeking: CPU / RAM | 1.4 % / 420 MB | 1.3 % / 442 MB | OK |
| Panel open while playing: CPU / RAM | 0.2 % / 280 MB | 0.3 % / 300 MB | **invalid**: the click hit VLC's console window, no panel was open (see below) |
| 4K60 80 Mbit/s windowed: frames lost | 0 of 1335 | 0 of 1351 | OK, but at VLC's own window size (the console window was resized instead) |
| 4K60 80 Mbit/s fullscreen: frames lost | 43 of 1289 | 85 of 1250 | **suspect**: redesign ran with 29 % background CPU; re-measure on a quiet PC |
| 520-entry queue open: RAM | 291 MB | 341 MB | +50 MB with the queue loaded but never shown (the click hit the console); re-measure |

Motion (Desktop Duplication captures, both builds):

| Interaction | Stock median / worst gap | Redesign median / worst gap |
|---|---|---|
| Hover across the control bar | 33.5 / 358 ms | 33 / 350 ms |
| Seek bar drag | 17 / 216 ms | 17 / 233 ms |
| Volume drag | 33 / 208 ms | 25 / 217 ms |
| Queue scroll | 100 / 1367 ms | 50 / 325 ms |

**These motion numbers are invalid (found after the round, from the captures).** Every motion and
queue capture of both builds shows VLC's console window, not the player: with `--extraintf=cli`
VLC on Windows opens a console (no `--rc-quiet`), and the harness took `MainWindowHandle`, which
was that console. So it resized, focused, clicked and captured the console: the hover and drag
"updates" are the pointer and the console's text selection, the wheel scrolled the console, and
panel/queue open found 0 changes because no panel opened. Same cause, also invalid: "Panel open
while playing" CPU/RAM (no panel was open), the queue RAM (the queue was never opened), and
4K windowed ran at VLC's own window size, not 2400x1350 (so did play / idle / seek, the same
for both builds, so those stay comparable). The button positions themselves were
right (checked on earlier screenshots at this window size). Also: the capture timestamps were
rounded to 1/120 s by the encoder, and the pointer was drawn into the capture and counted as UI.
Fixed in the harness (Qt window by class, `--rc-quiet`, window position checked before any
input, pointer not captured, ms timestamps, 4 ms input steps, QPC input log with sync marker,
gaps only while the input moves); re-measure in round 2.

### Round 2 (2026-10-14): stock 38315049322 vs redesign 38600975461 (lazy panels + event-driven cursor)
Raw results: `perfruns\r2\stock.json` (19:09, background 13 %) and `redesign.json` (19:39,
background 21 %; Sticky away, the session's own agents running). The fixed harness worked for
stock: sync spread <= 17 ms, 4 ms input steps, panels and queue detected. For the redesign the
input scenarios (panel, motion, queue) were skipped: VLC could not take the foreground at that
moment; they run in round 3.

| Measure | Stock | Redesign | Verdict |
|---|---|---|---|
| Startup to window (ms) | 1430/910/1126 | 1135/1087/1248 | equal (noise) |
| Open file to first video frame (ms) | 1498/1731/1849 | 1466/1032/1291 | **round 1 regression fixed** (lazy panels) |
| Playing / idle CPU | 0.7 % / 0 % | 0.7 % / 0.6 % | OK |
| 4K windowed frames lost | 0 of 1335 | 0 of 1335 | OK |
| 4K fullscreen frames lost | 4 of 1317 | 46 of 1302 | **suspect**, measured 30 min apart under different load: re-measure back to back |
| RAM and decoder load while playing | 300 MB, NVDEC 20 % (19:09) | 417 MB, NVDEC 42 % (19:39) | **not a regression**: back to back at 19:50 all three builds read the same (stock 429 MB / 42 %, round 1 redesign 437 MB / 42 %, this build 403 MB / 42 %); the machine state changed between the runs |

Stock motion baseline (valid, fixed method): hover latency 6 ms, hover animation gaps median 10 ms
(worst 21); seek drag 67 updates/s, gap median 15 ms, p95 22, worst 26, 19 stalls; volume drag
96 updates/s, median 8.5 ms, worst 22; panel open 41 ms to first change, 96 ms animation, worst
gap 19; panel close 8 ms, 90 ms; queue open 35 ms, 90 ms; queue scroll median 10 ms, worst 30.

Lesson: RAM, GPU and lost frames drift with the machine state, so every comparison runs back to
back (stock, then redesign, minutes apart) with the same background load.

### Round 3 (2026-10-15): stock 38315049322 vs redesign 38727073546, back to back
Raw results: `perfruns\r3\stock.json` (14:25, background 20 %) and `redesign.json` (14:29,
background 17 %), four minutes apart under the same load.

| Measure | Stock | Redesign | Verdict |
|---|---|---|---|
| Startup to window (ms) | 927/1062/1112 | 1031/981/921 | equal |
| Open file to first video frame (ms) | 1256/1130/1339 | 1671/1258/1230 | equal except one slow first open; watch it next round |
| Playing: CPU / RAM private / GPU / decoder | 0.1 % / 310 MB / 8.3 % / 20 % | 0.1 % / 309 MB / 8.9 % / 20 % | equal |
| Idle paused: CPU / RAM | 0 % / 309 MB | 0 % / 304 MB | equal |
| Panel open while playing: CPU / RAM | 0.1 % / 313 MB | 0.3 % / 305 MB | equal |
| Seeking: CPU / RAM | 1.1 % / 442 MB | 1.3 % / 429 MB | equal |
| 4K60 80 Mbit/s windowed: frames lost | 0 of 1349 | 0 of 1335 | equal |
| 4K60 80 Mbit/s fullscreen: frames lost | 23 of 1327 | 23 of 1311 | equal (round 1 and 2 gaps were load, not the redesign) |
| 520-entry queue: RAM | 334 MB | 329 MB | equal |
| 520-entry queue scroll: gap median / p95 / worst | 11 / 24 / 31 ms | 10 / 20 / 21 ms | redesign smoother |
| 520-entry queue open: first change | 24 ms (90 ms animation) | 24 ms (instant, Decision 32 style) | equal latency; the capture shows a second change 449 ms later: check what changes |

Stock motion (seek drag median 11 ms / worst 24; volume drag 9 / 22; panel open 29 ms to first
change, 91 ms animation) is the baseline; the redesign hover, drag and panel captures were
skipped (VLC lost the foreground while Sticky was active): run them in round 4 with Sticky away.

## Motion measurements
| Element | Source | Measured | Built |
|---|---|---|---|
| Main "..." menu open | video 5:08.15-5:08.40 (unedited prototype stretch), 60 fps | opacity fade, no slide, about 7 frames = ~115 ms (steps every 3-4 frames suggest a lower-fps capture) | 120 ms OutQuad fade in (`rd_menuFadeDuration`), close instant |
| Submenu open | video 19:30.45-19:30.80 | instant (absent at frame 13, complete at 15) | instant |
| Right-click menu | video 5:13-5:30 | no usable motion (meme cut, magic-wand edit effect) | same 120 ms fade as the main menu |
| Dialogs (Open Network Stream, Settings, Keyboard Shortcuts) | Figma prototype: overlays open instantly; video fades are edits | instant | instant (Decision 32) |
| Settings sidebar open | video 7:10-7:13 | editing only (dissolve of the old Effects window, then a camera zoom) | instant (no Figma transition) |
| Library open | Figma prototype | smart animate "slow" 208 ms | (Phase 5) |
| Hide UI | Figma prototype | smart animate ease-in-and-out 300 ms | to check against the perf cap with Sticky |
| Volume drag | Figma prototype | smart animate ease-in-and-out 300 ms | to check |
| Mini player | Figma prototype | smart animate ease-out 300 ms | (Phase 5) |
| Customize drags | Figma prototype | 50 ms | (W8.1) |

### Profile switch (2026-10-16, build 38829058873, public)
Desktop Duplication capture at 240 Hz (changed frames only), Default Style -> Minimalist Style from the main menu: the new bars appear in the frame after the menu closes (~7 ms); one 23 ms gap at the switch (one missed refresh at 99 Hz), then 10 ms steady. Target 16.7 ms: one dropped frame.
