# Windows checklist

Every VIDEO_INDEX row that is still not verified on wip/next-test (2ffda4e20b, 2026-10-19): **111 rows**, grouped by screen. Rows marked "verified" (Linux + Windows look, or Windows) are left out. Marks:

- **quick look**: built, and passed on Linux or in an earlier Windows round; open it on Windows, glance at it next to Figma (Decision 65), mark the row.
- **full Windows test**: needs Windows itself (core build, audio, folder dialog, network), her video (motion, montage), or a real mouse (drag and drop); use every control, then one screenshot next to Figma / the video frame.
- **needs a fix first**: not built, or a known bug still open; the web session fixes it, then it gets a test.
- **postponed**: not built on purpose under one of Sticky's decisions; nothing to fix or test until the decision changes.
- **none (context row)**: old VLC, problem, B-roll, sponsor or meme rows: nothing to build or check (listed so the count is complete).

Counts: quick look 18, full Windows test 28, needs a fix first 3, postponed 1, none (context row) 61.

Dropped: P4-30 (#139), the video filter preset previews, Decision 67 (PR #28); not counted.

Open pull requests that change these rows: #22 (subtitle timeline, "Pressed" line, command line options: core build), #23 and #26 (the PC bug list: they overlap on the title and the queue / library fixes, merge one first and drop its twin from the other), #25 (EQ curves), #28 (Decision 67).

## Linux re-check (wip/linux-recheck)

Test-only branch `wip/linux-recheck` (never merged): wip/next-test plus the open PRs #22, #23, #25 and #26 and the Linux build job. Run 39270926487 (build 10) had everything but the latest PR #22 commits; run 39274608830 (build 11, green) adds them (the timeline rows below were tested on it). Xvfb 1920x1080, scale 100 %, every screenshot looked at.

| Screen / feature | PR | Result on Linux |
|---|---|---|
| Quit after a slider drag and keys (close button) | #23, #26 | exits in 0.5 s, exit 0; the Windows hang never reproduced on Linux, so the fallback still needs the Windows test |
| Queue then library | #23, #26 | pass: both stay open side by side; a click inside the library keeps the queue |
| Escape in the library | #26 | pass: closes the library |
| Sidebar Audio tab | #23, #26 | pass: no note under Defaults |
| Disabled Settings rows (General, Save a log off) | #23 | pass: faint but readable in dark |
| Equalizer preset icons | #25 | pass: rounded curves close to Figma "EQ presets" |
| Audio delay and visualizer | #26 | pass: 0.150 s kept after picking Scope; the visualizer stays set; after a restart no stray visualizer window comes back |
| Visualizer window | #26 | **finding:** it opens as its own window titled "VLC media player" (branding: should say Cone or follow the main window); not in any PR yet |
| Onboarding | #20 (merged in next-test) | pass: Enter x3 finishes it, the page fills the window |
| "Pressed V" line in the OSD | #22 | pass: shows under "Subtitle track: Track 2 - [French]" |
| Settings > General > Advanced Options | #22 | pass: "Additional command line options" with the note "Options that change the interface are ignored: --intf, -I, --extraintf, skins" |
| Library file "..." menu, Add to Playlist > New Playlist... | next-test | pass (run 9): all 12 items in Figma order; the new playlist is created with the file |
| Library playlist "..." menu | next-test | **finding:** no "Favorite" item (F-11) |
| Subtitle timeline buttons | #22 | pass (build 11): `-` and `+` touch the bar's ends (no gap pixel), all four buttons 28 px tall in line with the bar; `<` / `-` dimmed at the start of the file |
| Timeline block colours | #22 | pass: played-side blocks #49331C, unplayed blocks #1F1F1F, played fill #371F06 |
| Timeline at 760 x 520 and 600 x 520 | #22 | pass: nothing overlaps; at 760 the right controls hide and the volume stays, at 600 the volume hides too; the bar stays wider than a time label (about 150 px); the labels show the timeline window's ends with "*" by design |
| "Show feedback for" default | #22 (core) | pass: fresh profile, Settings > Subtitles > On-Screen Messages: the thumb sits halfway between the 2.5 s and 3 s ticks (2.75 s) |
| Message position clear of the top bar | #22 | not done: core layout change, waiting for a decision by StickyGonzales (MUSTHAVES_2_NOTES.md section 9.5) |

## Player bars and seek bar

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 35 | IA-13 | quick look | built (990258263f); look at the thick bar next to Controls.png, then mark |
| 56 | IA-19 | full Windows test | motion: icons slide when one is inserted; needs her video at 4:35-4:44 and a 60 fps recording |
| 319 | IB-46 | full Windows test | montage seek bar with segments (20:23-20:31): compare with her frames on the PC |
| 320 | P8-35 | full Windows test | closing montage: controls, settings, subtitle timeline (20:24-20:35); needs PR #22 |
| 321 | P8-52 | full Windows test | montage close-ups: PC pass except the subtitle timeline, which needs PR #22 |
| 328 | F-02 | quick look | current time hover and click-to-edit; Linux pass (web fixes 2: the time field keeps select-all by decision) |

## Subtitle timeline (PR #22)

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 87 | P3-16 | full Windows test | timeline in the seek bar: PR #22 (core build); buttons, block colours and the 760 x 520 window pass on Linux (build 11); on Windows redo block drag, G / H, page turn while playing, and crop the bar next to the video at 7:00 / 7:04 |
| 88 | IA-27 | full Windows test | cue blocks and buttons: PR #22 (core build); buttons, block colours and the 760 x 520 window pass on Linux (build 11); on Windows redo block drag, G / H, page turn while playing, and crop the bar next to the video at 7:00 / 7:04 |
| 145 | P4-35 | full Windows test | "Show Subtitle Timeline on Seekbar" row: PR #22 (core build); buttons, block colours and the 760 x 520 window pass on Linux (build 11); on Windows redo block drag, G / H, page turn while playing, and crop the bar next to the video at 7:00 / 7:04 |

## On-screen messages (PR #22)

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 86 | P3-15 | full Windows test | subtitle delay keys in the OSD: Linux pass on wip/linux-recheck (V shows "Pressed V" under "Subtitle track: ..."); PR #22 core change, so run MUSTHAVES_2_NOTES.md section 6 B on Windows |
| 253 | IB-38 | full Windows test | OSD typography: Linux pass on wip/linux-recheck (V shows "Pressed V" under "Subtitle track: ..."); PR #22 core change, so run MUSTHAVES_2_NOTES.md section 6 B on Windows |
| 254 | P7-08 | full Windows test | "Pressed" line: Linux pass on wip/linux-recheck (V shows "Pressed V" under "Subtitle track: ..."); PR #22 core change, so run MUSTHAVES_2_NOTES.md section 6 B on Windows |
| 291 | P8-13 | full Windows test | OSD shows the pressed key: Linux pass on wip/linux-recheck (V shows "Pressed V" under "Subtitle track: ..."); PR #22 core change, so run MUSTHAVES_2_NOTES.md section 6 B on Windows |

## Settings sidebar

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 119 | P4-16 | full Windows test | tab switch crossfade: motion, compare with her video 8:40-8:42 |
| 120 | IA-37 | full Windows test | tab switch animation: motion, compare with her video 8:40-8:47 |
| 122 | P4-15 | quick look | Audio Defaults: Linux pass on wip/linux-recheck (no note); look once PR #23 or PR #26 is merged |
| 129 | P4-22 | quick look | Compressor expanded: Linux pass; Windows look |
| 131 | P4-24 | quick look | Equalizer expanded: Linux pass (0.0 dB fix; preset icons rounded like Figma "EQ presets" with PR #25); Windows look |
| 138 | P4-29 | full Windows test | rows appear one by one: check against her video whether it is UI or editing (8:57-9:06) |
| 143 | P4-33 | postponed | Reverse toggle: postponed under Decision 29 (reverse playback); VLC's engine has no reverse playback, so a toggle would do nothing |

## Queue, bookmarks, chapters

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 200 | IB-19 | quick look | mini player queue header glyphs (Decision 10: 5 icons) |
| 250 | IB-37 | quick look | bookmark / chapter typography: bookmarks fixed (web fixes 2, Linux pass); look |
| 251 | P7-06 | needs a fix first | chapter title 4 px right of Figma (72 vs 68 from the panel edge on Linux); cause not found |
| 318 | P8-34 | full Windows test | closing montage: playlists and queue, compare with her video 20:20-20:23 |

## Library

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 174 | IB-05 | full Windows test | Add Folder transition needs the Windows folder dialog |
| 208 | IB-21 | full Windows test | navigation crossfade: rows pass; the breadcrumb fade is in PR #23 (Linux pass); compare the motion with her video 12:12 |
| 226 | P6-14 | full Windows test | paste an IPTV m3u link: needs network |
| 230 | P6-17 | quick look | Linux pass (wip/linux-recheck sandbox): file "..." > Add to Playlist > New Playlist... opens the dialog with the file listed; saved playlist shows with its thumbnail |
| 231 | IB-31 | quick look | Linux pass: file "..." menu icons two-tone with the accent, hover row highlight |
| 316 | P8-33 | full Windows test | closing montage: library, compare with her video 20:08-20:19 |
| 337 | F-11 | needs a fix first | playlist "..." menu has no "Favorite" (Figma: Play, Favorite, Shuffle, ...); "Delete Playlist" at the end is covered by Decisions (Claude) 2026-10-14 Phase 5 |
| 338 | F-12 | quick look | Linux pass: all 12 items in Figma order ("Show in File Manager" on Linux, "Show in File Explorer" on Windows) |
| 342 | F-16 | full Windows test | compact library open / close motion (208 ms smart animate): 60 fps recording |

## Customize Player

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 304 | P8-25 | full Windows test | drag in / out with a real mouse; the title "Bet..." after Save is fixed in PR #23 / PR #26 |
| 306 | P8-26 | full Windows test | her full alternate layout rebuilt by real-mouse drags |
| 307 | P8-48 | full Windows test | alternate layout icon details, after P8-26 |
| 322 | P8-36 | full Windows test | closing montage: theme / accent and customization, compare with her video 20:36-20:46 |
| 348 | F-22 | full Windows test | drag timings (50 ms) with a 60 fps recording |

## Settings dialog

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 100 | P3-23 | quick look | Size values reads Relative / Precise by Decision (Claude) 2026-10-14 W6.2 / P3-22; look and mark |
| 285 | P8-10 | quick look | Video page: Linux pass |
| 286 | P8-11 | quick look | Audio page: Output device and Startup volume exist only on Windows (Linux hides them); look at them on Windows |
| 350 | S2-01 | full Windows test | "Additional command line options": Linux pass (the row and its note "Options that change the interface are ignored" show); PR #22 core change, so run section 6 C on Windows |
| 360 | S2-11 | quick look | Subtitles > Advanced Options row: Linux pass |

## Onboarding

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 311 | P8-29 | quick look | passed in the PR #20 Windows round (39148069447) and again on Linux (Enter x3 finishes it, the page fills the window); mark the row |
| 312 | P8-50 | full Windows test | transitions: instant by Decision 32; compare with her video 19:47-19:54 |
| 313 | P8-30 | quick look | passed in the PR #20 Windows round (39148069447) and again on Linux (Enter x3 finishes it, the page fills the window); mark the row |
| 314 | P8-31 | quick look | passed in the PR #20 Windows round (39148069447) and again on Linux (Enter x3 finishes it, the page fills the window); mark the row |

## Subtitles

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 70 | IA-25 | full Windows test | default subtitle rendering look: compare with her frames 5:39-6:34 on the PC |
| 81 | P3-10 | quick look | Save adds the external track: passed in the PR #20 round (External Tracks); mark |

## Visual style

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 7 | IA-01 | needs a fix first | public build shows Cone's icon instead of the cone (public release rules); look that the icon is used everywhere; the visualizer window is still titled "VLC media player" on Linux, fix that first |

## Context rows

| # | ID | Mark | Why / what to do |
|---|---|---|---|
| 1 | P1-01 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 2 | P1-02 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 3 | IA-07 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 4 | P1-03 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 8 | IA-02 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 9 | P1-06 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 16 | P1-10 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 18 | P1-11 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 19 | P1-12 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 20 | P1-13 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 38 | P2-05 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 40 | P2-07 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 46 | P2-11 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 49 | P2-13 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 50 | P2-14 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 51 | P2-15 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 58 | P2-19 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 63 | P2-22 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 68 | IA-24 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 69 | P2-26 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 71 | P3-01 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 72 | P3-02 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 73 | P3-03 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 83 | P3-12 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 85 | P3-14 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 99 | IA-33 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 102 | P4-01 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 103 | P4-02 | none (context row) | build-up state before the preset (context) |
| 111 | P4-08 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 112 | P4-09 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 113 | P4-10 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 114 | P4-11 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 117 | P4-13 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 148 | P4-38 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 149 | P4-39 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 150 | P5-01 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 153 | P5-03 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 154 | P5-04 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 155 | P5-05 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 161 | P5-09 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 162 | IB-01 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 164 | P5-10 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 180 | P5-19 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 181 | IB-09 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 184 | P5-21 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 201 | P5-31 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 216 | P6-08 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 218 | P6-10 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 239 | P6-22 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 242 | P6-24 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 244 | P7-01 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 245 | P7-02 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 246 | P7-03 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 252 | P7-07 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 256 | P7-10 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 257 | P7-11 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 301 | P8-23 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 310 | P8-28 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 315 | P8-32 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 317 | P8-51 | none (context row) | context or old-VLC row in the video: nothing to build or check |
| 323 | P8-37 | none (context row) | context or old-VLC row in the video: nothing to build or check |
