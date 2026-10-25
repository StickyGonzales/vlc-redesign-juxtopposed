# Linux verification (Cone on Linux, sandbox)

Screen-by-screen check of Cone on Linux in the cloud sandbox, with the GitHub-built AppImage. **Nothing here changes VIDEO_INDEX** and nothing is marked verified there: this is a Linux pass of the same QML the Windows build runs; the PC test stays the reference (Decision 65 decides which rows count as "verified (Linux)").

Two runs:
- **First run, 2026-10-19:** build-linux #2 of `wip/verify-linux`; 249 pass, 14 fail.
- **Rerun, 2026-10-25:** the Linux catch-up after Cone 0.2.0. Its results are in the "Rerun" section below. The tables under "Results by screen" keep the first run's rows; every row the rerun changed starts with **Rerun**.

## Rerun 2026-10-25

### Builds
| Build | Run | Branch | What |
|---|---|---|---|
| build-linux #33 | 40211192797 | `wip/linux-build` (6c3dbb6bba) | `wip/next-test` merged into the Linux branch (0.2.0, the HEVC surface fix, the Spectrometer fix, everything since) |
| build-linux #35 | 40213274248 | `wip/linux-fixes-linux` (ef74cd8212) | #33 + the three Linux fix branches (language, audio device, postproc); test only, never merged |
| build-linux #36 | 40214838893 | `wip/linux-fixes-linux` (663b7c0e81) | #35 + the sub-ui-margin core fix (assertions still on, so the fix is proven) |

Same sandbox as the first run, apart from:
- Xvfb 1600x1000 with the window at 1440x900; openbox; llvmpipe; PulseAudio null sink; a fresh test profile.
- Media: the first run's set plus `pgs-subs.mkv`, a generated 720p clip with a PGS (bitmap) subtitle track.
- Every screen was opened again and screenshotted. Every changed element was cropped next to the same Figma crop at the same scale (e.g. the thick seek bar at 300 % next to Player.png, the Keyboard Shortcuts header next to Keyboard Shortcuts.png). Positions were measured in pixels where the first run had found an offset.

### The 14 fails of the first run
| # | Row | First run | Rerun | How it was fixed |
|---|---|---|---|---|
| 1 | IA-13 thick seek bar | chapter frame and gaps under the thick bar | **pass** (#33) | shared QML, already in next-test |
| 2 | P2-06 top bar title | elided after Next | **pass** (#33) | shared QML, already in next-test |
| 3 | F-02 current time edit | select-all on click | **pass by decision** | kept on purpose (web fixes 2) |
| 4 | P3-10 external track | added but not selected | **pass** (#33) | shared, already in next-test |
| 5 | P4-15 Stereo Mode | raw numbers | **pass** (#33) | shared, already in next-test |
| 6 | P4-24 equalizer | "-0.0 dB" | **pass** (#33) | shared, already in next-test |
| 7 | P8-03 Interface language | missing on Linux | **pass** (#35) | **Linux bug, fixed:** `wip/fix-linux-language`, draft PR #48 into wip/next-test |
| 8 | P8-10 Deinterlacing method | "Auto" | **pass** (#33) | shared, already in next-test |
| 9 | P8-11 Output device | missing on Linux | **pass** (#35) | **Linux bug, fixed:** `wip/fix-linux-audio-device`, draft PR #49 into wip/next-test (the start volume stays Windows only: the sound server keeps Cone's volume) |
| 10 | P8-15 Proxy header | empty header on Linux | **pass** (#33) | the section hides itself now; the proxy rows are Windows only (Linux takes the system proxy) |
| 11 | P8-16 Video post-processing | missing on Linux (no libpostproc) | **pass** (#35) | **Linux bug, fixed:** `wip/fix-linux-postproc`, draft PR #50 into wip/linux-build (the script exists only there) |
| 12 | IB-37 bookmark typography | times, 3 px offset | **pass** (#33) | shared, already in next-test |
| 13 | P7-06 chapter title x | 72 px instead of 69 | **pass** (#33) | shared, already in next-test |
| 14 | P7-12 Keyboard Shortcuts search | no focus on Linux | **pass** (#33) | already in next-test |

### Every screen again (#33, the Linux rows on #35)
| Screen | Rerun result | Notes |
|---|---|---|
| 1. Player, windowed | pass | IA-13 and P2-06 fixed; the rest as the first run |
| 2. Bars, fullscreen, Hide UI | pass | fullscreen: bottom bar at the bottom edge, top bar at the top edge, both gone when the mouse is in the middle; the "Continue Watching" toast keeps the bottom bar up while it shows (by design); Ctrl+\ hides and restores |
| 3. Tracks popup | pass | P3-10 fixed |
| 4. Add Subtitles dialog | pass | target menu, folder picker (Qt's own dialog in the sandbox), file list, Save |
| 5. Settings sidebar | pass | Playback tab now has "Show Subtitle Timeline on Seekbar" (built since) and the timeline works; Stereo Mode and equalizer fixed; Video and Subtitles tabs as before |
| 6. Settings dialog | pass | all 13 pages opened; P8-10 and P8-15 fixed on #33, P8-03 / P8-11 / P8-16 fixed on #35; "Additional command line options" (built since) with its note |
| 7. Queue, Bookmarks, Chapters | pass | Ctrl+B adds "The Wand S01E02 1" at 00:00:44:480; offsets measured 21 / 25 / 69 px |
| 8. Main "..." menu | pass | |
| 9. Keyboard Shortcuts | pass | P7-12 fixed |
| 10. Right-click menu | pass | |
| 11. Open Network Stream | pass | |
| 12. Library | pass | compact panel, Home (Continue Watching, Listen Again) |
| 13. Music view | pass | |
| 14. Customize Player | pass (drags: not checked) | items, tabs, light theme in the dialog; drags see "Cannot be tested in the sandbox" |
| 15. Light theme and accent | pass | Light + blue accent recolour the dialog and the player live |
| 16. Onboarding | pass | `--qt-privacy-ask` on a fresh profile: "Welcome to Cone!", media folder, Next |
| 17. Resume toast, on-screen messages | pass | "Pressed A" / "Pressed Ctrl + Up" lines under the OSD (built since) |

### Since 0.2.0 (tag v0.2.0-beta, 5e32ace57c)
| Change | Linux result |
|---|---|
| HEVC surface fix (directx_va) | Windows-only code (not compiled on Linux). HEVC itself: `subs16-x265.mkv` plays (software decoding, codec "MPEG-H Part2/HEVC (H.265)"), its two-line subtitles show above the bar, and quitting during playback takes 0.4 s (exit 0). Hardware decoding (VA-API) cannot be tested here: no GPU |
| Spectrometer fix (mmdevice stop under lock) | Windows-only code. On Linux, picking **Spectrometer while a song plays aborted Cone** on #33. Cause: `vout_ChangeSpuChannelMargin: Assertion '!sys->dummy'`. A new bug in our own core change (sub-ui-margin, the subtitle lift), see "New findings" 1. Fixed on `wip/fix-sub-ui-margin-dummy` (draft PR #51). Tested on #36 (assertions still on): the same steps draw the spectrometer, 3 rounds of Spectrometer / Scope / Spectrum / Disabled keep Cone running with no assertion in the log, and the subtitle lift still works (letterboxed film, cues above the bar) |
| Subtitle fixes: subsdelay | with `--sub-filter=subsdelay` and the PGS (bitmap) track picked, the cues show and clear on time, the picture keeps moving, no abort (assertions on) |
| Subtitle fixes: lift above the bar | letterboxed `scope-subs.mkv`: one- and two-line subtitles sit above the control bar while it shows |
| Quit watchdog | arms on quit ("quit watchdog: armed ... in 5 s"). With the sound server frozen (PulseAudio stopped with SIGSTOP, so the audio output's teardown blocks) the quit ends after 5.4 s with the watchdog's message and exit 0. A normal quit takes 0.4 s |

### New findings
1. **Spectrometer aborted Cone on Linux (fixed, core).** With no video output (a song, or a visualizer whose output is not open yet), `vlc_player_vout_HoldAll` hands out the input's dummy output. The subtitle lift set `sub-ui-margin` on it, and that variable's callback was added in `vout_CreateVars`, which the dummy runs too. The callback calls `vout_ChangeSpuChannelMargin`, which asserts the output is not the dummy. Windows release builds have no assertions, and the dummy has no subpicture unit, so nothing visible happened there. Fix: the callback is added in `vout_IntfInit`, like `sub-margin`'s. Branch `wip/fix-sub-ui-margin-dummy`, draft PR #51 into wip/next-test; tested on #36. Core change: its own Windows build.
2. **The Linux build kept VLC's run-time assertions (fixed, CI).** VLC's configure keeps assertions on unless `--disable-debug`; the Windows build passes it (`build.sh -r`). So a check that is harmless on Windows ended Cone on Linux. The release build now matches Windows: branch `wip/fix-linux-release-build`, draft PR into wip/linux-build. Test builds of the fix branches keep assertions on, so they still catch this kind of bug. (build of this branch: pending)
3. After the quit watchdog ends Cone, the next start asks "Do you want to restore the playlist model from …?" in an unstyled message box. That is VLC's crash recovery. STATUS.md already lists the "closed abruptly" prompt after forced closes as not a bug, so it is only noted here (shared with Windows).
4. Small: the Audio Visualizer list's Linux-only entry "3D OpenGL spectrum" is elided ("3D OpenGL spectru…") in the sidebar dropdown. It has no Figma counterpart and is not changed here.

### Cannot be tested in the sandbox
These need a real Linux PC (or the Windows PC for the shared rows) and are marked "(sandbox)" in the tables:
| Area | Why | Rows |
|---|---|---|
| Real sound | PulseAudio null sink, no sound card: device switching and volume are checked, what comes out of the speakers is not | P1-19 start volume note; any audio-quality check |
| GPU video and hardware decoding | no GPU: VLC's OpenGL output refuses llvmpipe and falls back, VA-API fails to initialise | HEVC / VA-API decoding, HDR (Windows only anyway), dropped frames, every motion row (F-16, IB-05, IB-21, P8-50) |
| Wayland fullscreen and window placement | the sandbox has only X11 (Xvfb + openbox) | fullscreen on Wayland, tray popup position, "keep above" |
| Display scaling (125 / 150 / 200 %) | Xvfb at 96 dpi only | every layout row at other scale factors |
| Real mouse drag and drop | synthetic xdotool drags do not finish a Qt drag here | P5-24, IB-15, P5-28, IB-19 (drag to the queue), P8-25, P8-47, P8-26, P8-48, F-22 (Customize drags) |
| Network streams | no reachable streams | P6-14, P6-17, IB-31, F-11, F-12 |

## Summary (one line per screen)

First run (2026-10-19) → rerun (2026-10-25). Rerun counts include the fix branches of build #35 (P8-03, P8-11, P8-16 still fail on #33 alone).

| Screen | Passed | Failed | Not built / not checked | Skipped |
|---|---|---|---|---|
| 1. Player, windowed, video playing | 40 → 43 | 3 → 0 | 0 | 9 |
| 2. Bars over the video, fullscreen, Hide UI | 4 | 0 | 0 | 1 |
| 3. Tracks popup | 9 → 10 | 1 → 0 | 0 | 1 |
| 4. Add Subtitles dialog | 9 | 0 | 0 | 2 |
| 5. Settings sidebar: Playback, Video, Audio, Subtitles tabs | 47 → 52 | 2 → 0 | 3 → 0 | 7 |
| 6. Settings dialog | 42 → 48 | 5 → 0 | 1 → 0 | 4 |
| 7. Queue panel: Queue, Bookmarks, Chapters | 10 → 12 | 2 → 0 | 0 | 0 |
| 8. Main "..." menu | 14 | 0 | 0 | 6 |
| 9. Keyboard Shortcuts dialog | 1 → 2 | 1 → 0 | 0 | 0 |
| 10. Right-click menu | 4 | 0 | 0 | 0 |
| 11. Open Network Stream | 2 | 0 | 0 | 1 |
| 12. Library: compact panel, full library, Home, Recent, pins, Network, Playlists | 50 | 0 | 9 | 12 |
| 13. Music player view | 5 | 0 | 0 | 0 |
| 14. Customize Player | 2 | 0 | 5 | 2 |
| 15. Light theme and accent colour | 6 | 0 | 0 | 0 |
| 16. Onboarding | 3 | 0 | 0 | 5 |
| 17. Resume toast, on-screen messages | 1 → 5 | 0 | 4 → 0 | 7 |
| **Total** | **249 → 271** | **14 → 0** | **22 → 14** | **57** |

Counted per VIDEO_INDEX row ID (plus one per web-fix line); a table line that groups several IDs counts each of them. The 14 rows left "not checked" are the sandbox limits above (drag and drop, network streams). First run: the Linux-only fails were General (Interface language), Audio page (Output device), Network page (Proxy), Performance page (Video post-processing) and the Keyboard Shortcuts search; all now pass.

Screenshots of the rerun (generated test media only): `redesign/linux-shots/rerun-2026-10-25/`.

## First run 2026-10-19: how it was run
- Build: build-linux #2, run 39125070286 (head e84bfc9b0e), artifact `cone-linux-appimage-x86_64` (AppImage unpacked once with `--appimage-extract`, then `AppRun`, as the sandbox has no FUSE).
- Order (as asked): the screens that `wip/beta` and `wip/web-fixes-1` did not change were to start on build #1 (run 39119874209) while #2 built; #2 went green after the first screen, so everything below was checked on #2 and nothing was rechecked. Changed since #1 (from `git diff origin/wip/linux-build`): Settings pages General, Interface, Privacy, Playback, Subtitles, Extensions and the info popovers; sidebar Subtitles tab; tracks popup; Queue / Chapters rows; subtitles above the bar; every application shortcut on Linux (Ctrl+P matcher fix).
- Display: Xvfb 1920x1080, 24 bit, 96 dpi (100 % scaling), openbox, software rendering (llvmpipe), test user in a D-Bus session, PulseAudio with its null sink (no sound card; real sound is a Windows-only row).
- Media (generated, no personal files): "Test Show/Season 1" with 3 episodes (25:40, 640x360, two audio tracks eng/jpn, two subtitle tracks eng/fre, chapters Winter / Spring / Summer / Fall / Winter 10 Years Later), an external `.srt` per episode in another folder, 6 tagged songs with cover art (2 artists, 2 albums, 2 genres), a portrait clip, a letterboxed film with a very long name, an IPTV `.m3u`.
- Figma: the 2x PNG exports scaled to 1x, compared at the same scale with a screenshot of the same element.
- Each row: **Function** = used the controls and checked what the VIDEO_INDEX row says; **Looks** = compared with its Figma frame for layout, colours, fonts, icons, wording and spacing. Font smoothing differences between Linux and Windows are not counted.

Results: **pass**, **fail** (what is wrong, what Figma shows, likely file), **not built** (VIDEO_INDEX status todo), **not checked** (could not be driven in the sandbox, said why), **skip** (Windows only, needs her video, or a context row with nothing to build). Rows already verified on Windows were rechecked here only for their screen, not motion.


## Results by screen

### 1. Player, windowed, video playing (Figma Player.png, Controls.png, play.png, volume.png, audio value.png, Current Time.png, Duration.png, thumbnail.png, Icon Wrapper.png)

Compared at 100 % in crops of the top bar left / centre / right and of both ends of the control bar (paused, as Figma). The window title and folder name are the run's content.

| Row | Item | Result | Notes |
|---|---|---|---|
| P1-04 (#5) | Keep the cone and orange | pass | Cone's own icon at the top left (public brand rule), accent orange everywhere |
| P1-05 (#6) | Colour palette | pass | bar BG, track, played fill, playhead, text greys and accent identical in the crops |
| IA-01 (#7) | Flat cone logo geometry | skip | the public build shows Cone's icon instead of the VLC cone (public release rules) |
| IA-02 (#8), P1-06 (#9) | Palette swatches, old icons | skip | video only / context |
| P1-08 (#12), IA-04 (#13) | Monochrome clickable icons | pass | prev, next, speaker, waveform, subtitles, gear, queue, window buttons: same glyphs and weight as Figma |
| P1-09 (#14) | Corner radius | pass | play pill, seek track, time boxes and tooltip radii as Figma |
| IA-06 (#17), P2-12 (#47), IA-17 (#48) | Play button glyph, states, colours | pass | paused: orange pill + dark play; playing: grey pill + dark pause (play.png) |
| P1-12 (#19), P1-13 (#20), P4-38 (#148) | Problem / rejected / context | skip | context rows |
| P1-14 (#21), IA-08 (#22) | Play bigger, prev / next around it | pass | prev is drawn disabled on the first queue item, next on the last |
| P1-15 (#23), P1-17 (#26), IA-10 (#27), P3-13 (#84) | Right group: queue, gear-with-play | pass | order waveform, subtitles, gear, queue; gear glyph as Figma |
| P1-19 (#30), P2-01 (#31), IA-12 (#32) | Cone volume slider and speaker | pass | click at the start / middle / end of the cone: fill follows, green to red over 100 %. Sandbox note: with PulseAudio the cone reads empty until the first volume change (the null sink reports no volume at start); recheck on a real Linux desktop |
| P2-02 (#33), P2-03 (#34) | Thick seek bar in the one-row bar | pass | layout and sizes as Figma |
| IA-13 (#35) | Thick seek bar construction | pass (rerun) | **Rerun #33:** no frame, no gaps: rounded track and played fill as Figma (crop at 300 % next to Figma Player.png, file with chapters). Fixed in shared QML (`model: control.thick ? 0 : Player.chapters`). First run: fail, square accent frame and chapter gaps. |
| P2-04 (#36), IA-14 (#37) | Seek thumbnail on hover | pass | real frame of the hovered time, time under it, card as thumbnail.png |
| P2-05 (#38), P2-07 (#40) | Old top bar | skip | context |
| P2-06 (#39) | Restyled one-row top bar | pass (rerun) | **Rerun #33:** after Next the whole title "The Wand S01E02" shows centred. First run: fail, elided "The Wand S01E...". |
| P2-09 (#43), IA-16 (#44), P2-10 (#45) | Fullscreen in the top bar, window glyphs | pass | minimise, maximise, fullscreen, close as Figma (Decision 1: no PiP); Cone draws them on Linux (LINUX_NOTES Decision (Sticky) 1) |
| IA-21 (#59), P2-20 (#60) | Top bar typography, single "..." menu | pass | |
| IB-08 (#179) | Inset rounded video area | pass | 10 px inset, rounded corners; bars float over the picture (Decision 30) |
| P5-18 (#178) | Next episode plays | pass | Next loads S01E02 and plays |
| P5-01 (#150) | Next episode problem | skip | context |
| P5-20 (#182), IB-10 (#183) | Folder chip opens the library | pass | chip "Season 1" (outline folder, grey text, divider) opens the compact library. With no folder added it opens on Home |
| P5-22 (#185), IB-11 (#186) | Sidebar toggle and its states | pass | outline when closed, left column filled when open |
| P5-30 (#191) | Top bar with the library open | pass | same items; the title is centred on the window (see P2-06 for the elided title) |
| IB-16 (#192), IB-17 (#243), IB-48 (#163) | Glyph details, played fill colour, conventions | pass | |
| F-01 (#327) | Click the total time for the remaining time | pass | 00:25:40 to -00:24:05 and back; hover box as Figma |
| F-02 (#328) | Current time: hover and click to edit | pass (by decision) | **Rerun:** unchanged on purpose: "the time field keeps select-all by decision" (web fixes 2). First run: fail (small), select-all on click. |
| F-03 (#329) | Volume tooltip | pass | hovering the speaker shows the "195 %" card 63 px above, 121 wide, as audio value.png. Extra: hovering the cone itself shows VLC's small pointing tooltip "195%" (no space), which Figma doesn't have |
| F-04 (#330) | Volume 0 to 200 % | pass | |
| F-05 (#331) | Hover state on icon buttons | pass | square BG on hover (speaker, time boxes) as Icon Wrapper.png |

### 2. Bars over the video, fullscreen, Hide UI (Figma Player - hide UI.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| P2-08 (#41), IA-15 (#42), P3-11 (#82) | Bars show on movement, hide when it stops | pass | windowed: both bars on mouse movement, gone 3 s after it stops; fullscreen: bottom edge shows only the bottom bar, top edge only the top bar, centre none (Decision 30). Fullscreen in and out (top bar button, Escape) |
| P2-25 (#67) | Hide UI and Ctrl+\ | pass | Ctrl+\ hides both bars and the mouse no longer brings them back, also at the edges; Ctrl+\ again restores them (needs build #2: application shortcuts did not fire on Linux before the web fixes 1 matcher fix) |
| IA-24 (#68) | Keycap graphic | skip | video only |

### 3. Tracks popup (Figma Controls.png popup variants, subtitle one.png)

Colours sampled from the PNGs (they are translucent: `BG/B1 Transparent` panel, `BG/B2` header), not judged by eye.

| Row | Item | Result | Notes |
|---|---|---|---|
| P2-16 (#52), P3-04 (#74) | Subtitle button opens the tracks popup on Subtitles | pass | button turns solid orange while open; Embedded None / Track 1 - English / Track 2 - French, External Tracks with pencil and "+", Show Preferences. "Track 1 - English" is the video's wording (Decision 11) |
| IA-18 (#53), IA-20 (#54) | Tab bar style, audio and video glyphs | pass | 3 tabs, orange underline and orange icon on the active one |
| P2-17 (#55) | Audio tab: tracks and output devices | pass | Track 1 - English / Track 2 - Japanese, Output Device list (here PulseAudio's "Dummy Output") with the refresh icon |
| P2-18 (#57) | Video tab | pass | None / Track 1 |
| IA-19 (#56) | Bar icons slide when one is inserted | skip | video only |
| IA-05 (#15) | Third icon state: solid orange = active | pass | subtitle and audio buttons while their popup is open |
| (web fix 8) External Tracks names | | pass | a subtitle file added during playback (Add Subtitles, To This File) is listed as "The_Wand_S01E02_EN.srt", the file name only, as Figma "Frame 67" |
| P3-10 (#81) | Save adds the external track | pass (rerun) | **Rerun #33:** To This File / From Computer / Subs folder / Save: "The_Wand_S01E02 [English]" is added under External Tracks with the orange check, the embedded track loses it, OSD "Subtitle track: Track 3 - [English]". First run: fail, not selected. |
| (beta) subtitles above the control bar | | pass | with the bars shown the subtitle line sits just above the control bar; with the bars hidden it is back at the bottom (windowed) |

### 4. Add Subtitles dialog (Figma Add Subtitles to Playlist/Folder.png, -1, -2, -3, subtitle multiple.png, subtitle one.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| P3-05 (#76), IA-26 (#75) | "+" opens the modal; header, footer, colours | pass | `BG/B2` header with title and X, `BG/B1` body (sampled #090909 / #0E0E0E, same as Figma), Cancel bottom left, orange Save bottom right, the video stays sharp behind |
| P3-06 (#77) | Target dropdown opens on load | pass | opens on load in place over its trigger: To This File (check) / To This Folder / To This Playlist |
| P3-07 (#78) | Source dropdown | pass | From Computer (check) / From OpenSubtitles / From Link... |
| F-09 (#335), F-10 (#336) | "+" and pencil open To This File / From Computer; file list | pass | the folder chip opens a folder picker; in the Subs folder the list shows the three .srt files with the one for the playing episode (S01E02) preselected and checked, as Folder-2.png |
| P3-08 (#79) | To This Folder: episodes, leader line, matched subtitle | pass | From Computer: three episodes (film icon) with a dashed leader to The_Wand_S01E01_EN.srt / E02 / E03 matched although the names differ (spaces vs underscores, _EN), as Folder.png. From OpenSubtitles needs the internet and an account: not tried |
| P3-09 (#80) | Hover a match: dark row and swap icon | pass | as subtitle multiple.png |
| P3-02 (#72), P3-03 (#73) | Problem rows | skip | context |
| (UX) | Escape closes the open dropdown, a second Escape the dialog | pass | |

Linux note: the folder picker is Qt's own widget dialog in the sandbox (no desktop portal); a desktop with xdg-desktop-portal shows its own picker.

### 5. Settings sidebar: Playback, Video, Audio, Subtitles tabs (Figma Controls.png sidebar variants, Values.png, Toggle.png, Dropdown.png, Video - Essential.png, Video - Crop.png, EQ presets.png, Audio - Equalizer.png, Setting Preset.png)

Positions measured from the panel top: every row sits where Figma has it. Colours sampled (2 px `BG/B2` frame + `BG/A4` fill on dropdowns, `BG/A4` frame + `BG/B2` fill on value boxes: same in both).

| Row | Item | Result | Notes |
|---|---|---|---|
| F-06 (#332), P4-03 (#104) | Gear opens the sidebar on Playback; active state | pass | Decision 5; gear solid orange while open |
| P3-17 (#89), P3-18 (#91), IA-28 (#90) | Right sidebar with four tabs | pass | Playback / Video / Audio / Subtitles, 400 wide, rounded, opaque |
| IA-41 (#137), IB-36 (#249) | Tab glyphs and states | pass | |
| P4-31 (#140), P4-32 (#141), IA-42 (#142) | Speed, stepped slider with tick labels | pass | clicking the 1.5 tick sets the rate (log: `changing rate: 1.500000`) |
| P4-33 (#143) | Reverse toggle | skip | reverse playback postponed (Decision 29) |
| P4-34 (#144) | Sleep Timer | pass | Off / 15 / 30 / 45 / 60 min / End of current file (Decision 23) |
| P4-35 (#145), P3-16 (#87), IA-27 (#88) | Subtitle timeline on the seek bar | pass (rerun) | **Rerun #33:** built since (verified on Windows in round 5): the Playback tab row "Show Subtitle Timeline on Seekbar" turns the seek bar into the subtitle timeline (blocks, page buttons, window edges marked *). First run: not built. |
| P4-36 (#146), P6-06 (#213) | Show Waveform on Seekbar | pass | the seek bar turns into waveform bars (with the IA-13 chapter frame drawn behind them on this file) |
| P4-37 (#147), F-23 (#349) | Show Metadata, Statistics, Audio Visualizer, order | pass | Metadata and Statistics open their panels on the left (Decision 24); order as the video plus Figma's Statistics (Decision 13) |
| P4-27 (#135), P4-28 (#136) | Video tab Defaults, segmented control | pass | Flip None / Horizontal / Vertical, Rotate, Zoom, Resolution, Aspect Ratio, Crop, Render (Decision 24: Local). The HDR row is hidden: it is d3d11's HDR mode (Windows only) |
| P4-29 (#138), P4-16 (#119), IA-37 (#120) | Build-up and tab animations | skip | video only |
| P4-30 (#139) | Video filters with presets | pass | Essential / Crop / Colors / Geometry / Overlay / Advanced expanders; Essential as Video - Essential.png |
| F-18 (#344) | Crop link toggle | pass | link Top-Bottom, Top 40 px: Bottom follows, link icon orange, picture cropped (log `vsz 640x280`) |
| P4-17 (#123), P4-18 (#124), IA-38 (#121) | Test button, Synchronization | pass | |
| P4-15 (#122) | Audio tab Defaults | pass (rerun) | **Rerun #33:** Stereo Mode reads "Stereo", list Mono / Stereo / Left / Right / Reverse stereo with the check on Stereo. First run: fail, raw numbers. |
| P4-19 (#125), P4-20 (#126), IA-39 (#128) | Filters list, toggle and expander styles | pass | |
| P4-21 (#127) | Sticky footer over the scrolling content | pass | |
| P4-25 (#133), P4-26 (#134), IA-40 (#132) | EQ preset dropdown with curve icons | pass | curves drawn per preset; "Full bass" fixes Figma's "Full base" (Decision 17) |
| P4-23 (#130) | Filter parameter sliders | pass | |
| P4-24 (#131) | Equalizer expanded, band sliders | pass (rerun) | **Rerun #33:** Classical: Preamp 12.0 dB, near-zero bands "0.0 dB". First run: fail (small), "-0.0 dB". |
| P3-19 (#92), P3-20 (#94), P4-14 (#118), IA-30 (#95) | Subtitles tab Synchronization, bipolar delay slider | pass | -4.000 s typed (Figma demo state): fill from 0 to the handle, same as Figma |
| P3-21 (#96), IA-31 (#97), P3-23 (#100), IA-32 (#101) | Appearance, toggle, segmented control | pass | the "apply from the next file" note under Appearance is Decision (Claude) W4.6 |
| P4-12 (#116), IA-29 (#93), IA-36 (#115) | Subtitles tab Defaults, typography, dividers | pass | (web fix 3) no line under Defaults any more: Subtitle Track sits 123 px below the panel top, Figma 124 |
| P4-02 (#103), P4-13 (#117), P4-08 (#111) | Context / build-up rows | skip | context or video only |
| P4-04 to P4-07, IA-34, IA-35 (#105-110) | Preset footer | pass | "Default Preset" footer and "Open Advanced Settings" as Setting Preset.png (preset list not reopened: verified on the PC, unchanged code) |
| F-07 (#333) | Show Preferences opens the matching tab | pass | from the tracks popup |
| F-08 (#334) | Open Advanced Settings opens the matching category | pass | from the Subtitles tab: Settings on "Subtitle Defaults" |

### 6. Settings dialog (Figma Settings - *.png, setting category.png, Dropdown.png)

All 13 pages captured at 100 % beside their Figma frame. Values that are the run's (Off / On, folder names, Ask vs Always) are not counted; Decisions listed in SHEET_CONFIRMATIONS.md still apply (All Cone Settings, info icons on every row, OpenSubtitles section, "Precise", "Extensions & Scripts", process priority, dimmed dependent rows, Cone for VLC).

| Row | Item | Result | Notes |
|---|---|---|---|
| (web fix 1) Ctrl+P | | pass | opens Settings on General, from the player |
| P7-18 (#268), IB-42 (#269), P8-02 (#270), P8-39 (#271), F-19 (#345) | Window, category list, switching | pass | |
| P7-16 (#264), P8-21 (#299) | Info icon on every row, popovers | pass | (web fixes 3 and 6) Subtitles > Preferred language ends "Automatic picks the subtitle track the file marks as its default. Applies from the next file."; Playback > Default subtitle track ends "Applies from the next file." |
| P8-03 (#273) | General page | pass (rerun, fix branch) | **Rerun #35 (wip/fix-linux-language, draft PR #48):** "Interface language" is the first row of Appearance ("System language", list of VLC's languages in their own names). Català saved as `Interface/language=ca` in Cone's Qt settings; after a restart with a desktop locale (`LANG=en_US.UTF-8`) VLC's translations are Catalan ("Obre una carpeta", "Paràmetres", OSD "Pressed Ctrl + Amunt"), Cone's new texts stay English (no translations yet, same on Windows). "System language" removes the key. Under the C locale (no `LANG`) gettext ignores the choice, as VLC itself on Linux. On #33 (without the branch) the row is still missing. First run: fail (Linux only). |
| P8-22 (#300) | Advanced Options expander | pass | Note (Linux only): the General advanced options add VLC's syslog rows; "System log identity" defaults to "vlc" in the public build (`syslog-ident`), which names VLC |
| S2-01 (#350) | Additional command line options | pass (rerun) | **Rerun #33:** built since (verified on Windows in round 5): Advanced Options > "Additional command line options" with the note "Options that change the interface are ignored: --intf, -I, --extraintf, skins". First run: not built. |
| P8-04 (#276), P8-05 (#279), IB-43 (#272) | Theme and accent rows | pass | (light theme itself: screen 14) |
| P8-06 (#281), S2-02 (#351) | Interface page | pass | no Skin section (Decision 63: Cone has no skins); window, playback controls, tray rows as Figma |
| P8-07 (#282), S2-04 (#353) | Privacy page | pass | (web fix 7) "Ask about internet access when Cone starts" after "Last.fm submission URL"; Figma's second "Last.fm username" reads "Last.fm password" (Decision 17) |
| P8-08 (#283), S2-05 (#354) | Controls page | pass | |
| P8-09 (#284) | Playback page | pass | default tracks as "Automatic" dropdowns (words, P8-01) |
| P8-10 (#285) | Video page | pass (rerun) | **Rerun #33:** Deinterlacing > Method reads "Automatic", as the row above. First run: fail (small), "Auto". |
| S2-06 (#355) | Night mode | pass | |
| P8-11 (#286) | Audio page | pass (rerun, fix branch) | **Rerun #35 (wip/fix-linux-audio-device, draft PR #49):** "Output device" shows (PulseAudio null sink: "Dummy Output"). With two sinks loaded (Headphones, Speakers) the open list updates, the current one is checked, picking Speakers moves Cone's stream at once (`pactl list short sink-inputs`: sink 1 to 2). No "System default" on PulseAudio (it cannot move a stream back to default); the sound server keeps the choice, as it keeps the volume, so "Always starts at" stays Windows only and is no longer shown. On #33 the row is still missing. First run: fail (Linux only). |
| P8-44 (#287), IB-45 (#288) | Inline equalizer, slider variants | pass | |
| P8-12 (#289), P8-45 (#290), S2-11 (#360) | Subtitles page | pass | (web fix 6) Text encoding "Automatic"; Preferred language "Automatic" (Decision (Claude) 2026-10-18 P8-12). Font "Serif Bold" is FreeType's Linux default, a value |
| P8-14 (#292) | Library page | pass | "Apply to files opened from the file manager" (Linux wording) |
| P8-15 (#293) | Network page | pass (rerun) | **Rerun #33:** no empty "Proxy" header any more (a section with no shown rows hides itself). The proxy rows themselves exist only on Windows: on Linux VLC takes the proxy from the system (libproxy's `proxy` tool, else `http_proxy`). First run: fail (Linux only), empty header. |
| S2-07 (#356), S2-08 (#357), S2-09 (#358) | Process priority, Rescan plugins, Encoder | pass | |
| P8-16 (#294) | Performance page | pass (rerun, fix branch) | **Rerun #35 (wip/fix-linux-postproc, draft PR #50):** "Video post-processing" shows between Hardware-accelerated decoding and Skip the H.264 loop filter (Off / Lowest / Low / Medium / High / Very high / Highest). Medium writes `postproc-q=3`, `video-filter=postproc`; after a restart the log shows `using video filter module "postproc"` in the video chain. On #33 the row is still missing. First run: fail (Linux only). |
| P8-17 (#295), S2-10 (#359) | Recording page | pass | |
| P8-18 (#296), P8-20 (#298) | Extensions page | pass | |
| P7-12 (#258) | Keyboard Shortcuts from Controls | see screen 9 | |
| P7-14 (#262), P7-15 (#263), P7-17 (#265), IB-41 (#266), P8-01 (#267) | Basic then advanced, worded dropdowns | pass | search filters the categories and pages (e.g. "subtitle") |
| P8-40 (#274), P8-43 (#275) | Open transition, control styles | pass | opens instantly (Decision 32) |
| S2-03 (#352), S2-12 (#361) | Popup duration, fullscreen controls sensitivity | pass | rows present |
| P3-22 (#98), IA-33 (#99), P7-10 (#256), P8-19 (#297) | Problem rows | skip | context |

### 7. Queue panel: Queue, Bookmarks, Chapters (Figma Controls.png panel variants, playlist.png)

Text positions measured in pixels from the panel's left edge (Cone screenshot vs Figma crop at 1x).

| Row | Item | Result | Notes |
|---|---|---|---|
| P1-16 (#24), IA-09 (#25) | Queue button and glyph | pass | |
| P1-18 (#28), P5-02 (#151), IA-43 (#152), P6-09 (#217) | Queue panel over the video | pass | 3 items - 1h 17m, sort / repeat / shuffle / remove / add, playing row orange; double-click plays (S01E03) |
| IA-11 (#29) | Queue typography and icons | pass | (web fix 4) handle at 30 and title at 62 px from the panel edge; Figma 30 and 63 |
| P7-04 (#247) | Ctrl+B adds a bookmark | pass | two presses give "The Wand S01E02 1" and "... 2" (needs build #2: application shortcuts) |
| P7-05 (#248) | Bookmarks tab | pass | |
| IB-37 (#250) | Bookmark and chapter list typography | pass (rerun) | **Rerun #33:** bookmark time "00:00:44:480" (h:m:s:ms), title at 21 px from the panel edge (measured), as Figma. First run: fail (small). |
| P7-06 (#251) | Chapters tab | pass (rerun) | **Rerun #33:** chapter number at 25 px, title at 69 px from the panel edge (measured), as Figma. First run: fail (small), 72 px. |
| IB-36 (#249) | Tab glyphs and states | pass | |
| P5-24 (#193), IB-15 (#194), P5-28 (#199), IB-19 (#200) | Drag to queue, mini player queue | see screen 11 | |

### 8. Main "..." menu (Figma menu.png, Profiles.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| P2-21 (#61), P6-11 (#221), P7-09 (#255), P7-13 (#260) | Contents and final order | pass | Open File(s), Open Folder, Open Network Stream, Open Disc, Open Capture Device, Convert, Open Recent / Profile / Keyboard Shortcuts, Customize Player, Settings, About Cone, with the shortcuts as Figma; "About Cone" for "About VLC" (brand) |
| IA-22 (#62), IB-26 (#219), IB-27 (#220), IB-39 (#261), F-21 (#347), P1-07 (#10), IA-03 (#11) | Two-tone icons, accent, typography, spacing | pass | same glyphs, Accent/DIm parts (Decision 16), row height and dividers as Figma |
| P8-27 (#308), P8-49 (#309) | Profiles entry | pass | "Profile (Default Style)" with submenu arrow (Figma "Profile (Movies)": the run's profile name) |
| P6-12 (#222) | Each item opens its own dialog | pass | Keyboard Shortcuts opens its dialog; Settings via Ctrl+P (screen 6); Open Network Stream via Ctrl+N (screen 11) |
| P6-10 (#218), IB-28 (#223) | Old menu, re-order transition | skip | context / video only |
| P2-13 (#49), P2-19 (#58), P2-22 (#63), P7-02 (#245) | Problem rows | skip | context |

### 9. Keyboard Shortcuts dialog (Figma Keyboard Shortcuts.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| IB-40 (#259) | Fine styling | pass | |
| P7-12 (#258) | Dialog, columns, fields, search | pass (rerun) | **Rerun #33:** typing right after opening goes into the search field ("mute" filters to Audio > Mute); hotkey fields in the monospace font as Figma. First run: fail (Linux, small), search field had no focus. |

### 10. Right-click menu (Figma right-click menu.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| P2-23 (#64), IA-23 (#65) | Cleaned right-click menu, icon colours and sizes | pass | Play/Pause, Stop, Previous Item, Next Item, Record / Hide UI / Playback, Video, Audio, Subtitle / More Settings, Playlist, Open Media / Quit Cone; opens at the cursor, moved up to stay inside the window. Record shows VLC's Shift + R (Decision 22 keeps VLC's keys) |
| P2-24 (#66) | Hide UI with Ctrl + \ | pass | item and shortcut shown; the shortcut works (screen 2) |
| (submenus) | | pass | Playback submenu: Title, Chapter, Program, Bookmarks, Renderer, Speed, Jump Forward / Backward, Jump to Specific Time, Previous / Next Title / Chapter |

### 11. Open Network Stream (Figma Open network stream.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| P6-13 (#224), IB-29 (#225) | Dialog and styling | pass | Ctrl+N opens it; header, Network URL with its hint, URL box (focused, typing works), divider, Playlist Name (optional), Cancel / Save; every element where the spec has it. Escape closes it |
| P6-08 (#216) | Old dialog critique | skip | context |

### 12. Library: compact panel, full library, Home, Recent, pins, Network, Playlists (Figma sidebar.png, Player.png, Player-1.png, media.png, Sorting Options.png, View Options.png, folder context menu.png, new playlist.png)

Folders added with the library's own "Add" rows (Videos: Test Show, Music: Music); the media library scanned the tags and covers.

| Row | Item | Result | Notes |
|---|---|---|---|
| P5-06 (#156), P5-07 (#157), IA-44 (#158) | Library categories, icons | pass | rail Home, Videos, Music, Network, Playlists, Recent, pins, +; active icon orange |
| P5-08 (#159), IA-45 (#160) | Back / forward, breadcrumb | pass | "Videos > Test Show > Season 1"; in the compact panel "... > Season 1" |
| P5-11 (#165), P5-12 (#166), P5-14 (#167), IB-02 (#168) | Toolbar, view mode, search | pass | count, sort, Grid / List View (check on the current one), search field |
| P5-13 (#169), IB-03 (#170) | Sort menu with Unwatched / Watched First | pass | Unwatched First, Watched First, Newest / Oldest First, Title A-Z / Z-A, URI; (video folder: no artist / album entries) |
| P5-15 (#171), IB-04 (#172) | Library "..." menu | pass | Add File, Add Folder, Edit Subtitle Tracks, Edit Audio Tracks, Resync, Info, two-tone icons as folder context menu.png |
| P5-16 (#173), P5-29 (#202), F-14 (#340) | Add Folder result, navigation | pass | the folder picker (Qt's own on Linux, see screen 4) adds "Test Show" and opens it; drill down and back |
| P5-17 (#175), IB-06 (#176), IB-07 (#177), F-13 (#339) | Grid thumbnails, watched state, row states | pass | real frames, orange progress line on started episodes, the playing one dimmed with a play icon and orange title |
| P5-23 (#187), IB-12 (#188), IB-13 (#189), IB-14 (#190) | Compact library over the video | pass | header glyphs, rows with thumbnails, playing row orange with a play icon over its thumbnail |
| P5-25 (#195), P5-26 (#196) | Open in full, full library | pass | the open-in-full icon opens the full library on the same folder |
| P5-27 (#197), IB-18 (#198), F-17 (#343) | Mini player | pass | card with the picture, progress, file name, folder chip (+ artist chip for music), queue button; hover shows close, open-player, prev / play / next as Miniplayer.png; open-player returns to the player |
| P6-01 (#203), IB-22 (#204), P6-02 (#205), IB-20 (#206), P6-03 (#207) | Music root and views | pass | Add, Songs, Albums, Artists, Genres with their icons; Artists and Albums show the covers. Note: an album lists its songs by title (Afterglow, City Pulse, Neon Road), not by track number (01 Neon Road first) |
| P6-07 (#214), IB-25 (#215) | Network list | pass | Add Network Stream, Podcasts, Radio (VLC's discovery) |
| P6-15 (#227), P6-16 (#228), IB-30 (#229) | Playlists, New Playlist dialog | pass | empty state, Create playlist opens New Playlist 713x589 as Figma: details + thumbnail drop square, Select Files drop zone with "+", Cancel / Save; Escape closes it |
| P6-18 (#232), IB-32 (#233) | Pins | pass | "+" offers Pin This Page / Pin a Folder...; pinning Season 1 adds a folder icon between Recent and "+". Small: the "Add item" tooltip of "+" is clipped by the panel |
| P6-19 (#234) | Recent | pass | clock icon, recent files with thumbnails, playing one orange. Note: the order is not newest first (E01, E02, Neon Road, E03 after playing E01, E02, E03, Neon Road) |
| P6-20 (#235), IB-33 (#236), F-15 (#341) | Home sections | pass | Continue Watching (with progress stubs), Listen Again, Frequently Visited Folders, Frequently Listened Artists; Latest Streams appears only with streams (none played) |
| P6-21 (#237), IB-34 (#238), P8-38 (#324), P8-53 (#325), IB-47 (#326) | Full-library Home, empty state | pass | full Home with cards (first run, before any folder) |
| F-16 (#342), IB-05 (#174), IB-21 (#208) | Open / close and navigation animations | skip (sandbox) | motion: needs the video and a real GPU (the sandbox renders with llvmpipe) |
| P6-14 (#226), P6-17 (#230), IB-31 (#231), F-11 (#337), F-12 (#338) | IPTV link to playlist, file and playlist "..." menus | not checked | no network streams in the sandbox; file "..." menu not opened in this pass |
| P5-24 (#193), IB-15 (#194), P5-28 (#199), IB-19 (#200) | Drag to the queue, mini player queue | not checked (sandbox) | **Rerun:** cannot be tested in the sandbox: synthetic drags (xdotool, also stepwise with 40 moves) do not complete a Qt drag and drop here. Real mouse on the PC (Decision 65: drag and drop with a real mouse is verified on Windows). |
| P5-03..P5-05, P5-09, P5-10, IB-01, P5-19, P5-21, P5-31, P8-33 (#153-155, 161, 162, 164, 180, 184, 201, 316) | Context and montage rows | skip | |

### 13. Music player view (Figma Player - Music.png, Player - Music-1.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| P6-04 (#209), IB-23 (#211) | Big cover, background | pass | 360 px cover card with rounded corners, "Neon Road - Nova Lights" under it, the cover zoomed and blurred (radius 20) as the background, as the spec |
| P6-05 (#210), IB-24 (#212) | Music control bar | pass | 15 s back / forward around the play button |
| P6-06 (#213) | Waveform seek bar | pass | (toggle tested on screen 5) |
| (P2-06 again) | | | the top bar title reads "Neon Ro..." with the whole bar free: same elide failure as screen 1 |

### 14. Customize Player (Figma Player - customize.png .. -8.png)

| Row | Item | Result | Notes |
|---|---|---|---|
| P8-24 (#302), P8-46 (#303) | Customize dialog and palette icons | pass | from the main menu; the bars get dashed outlines, the palette shows Figma's items in Figma's order with their icons, then VLC's other controls (CUSTOMIZE_NOTES: kept until StickyGonzales decides); "Quit Cone", "Cone Settings" for VLC (brand); the Video / Audio / Mini player tabs are Decision W8.1a; Picture in Picture left out (Decision 1). The 15 s items sit in the music bar, so the Audio player palette doesn't list them |
| P8-25 (#304), P8-47 (#305), P8-26 (#306), P8-48 (#307), F-22 (#348) | Drag items in and out, alternate layout | not checked (sandbox) | **Rerun:** a stepwise xdotool drag of Stop shows the drop preview in the bar (placeholder after Next), but the release does not keep it. Cannot be tested in the sandbox; real mouse on the PC (Decision 65). |
| P8-23 (#301), P8-36 (#322) | Old editor, montage | skip | context |

### 15. Light theme and accent colour (Figma Player - Light.png, Settings - global.png, styles.txt)

| Row | Item | Result | Notes |
|---|---|---|---|
| P8-04 (#276), IB-44 (#278) | Light theme, light control bar | pass | Settings > General > Light recolours the player at once: light bars, light seek track, light played fill, as Player - Light.png |
| P8-41 (#277), P8-42 (#280) | Theme and accent switch instantly | pass | |
| P8-05 (#279), F-20 (#346) | Accent colour setting and values | pass | green swatch: toggles, segmented control, active category, icons turn green in both themes; back to dark and orange |

### 16. Onboarding (Figma Onboarding.png, Onboarding-1.png .. -10.png)

Started with `--qt-privacy-ask`.

| Row | Item | Result | Notes |
|---|---|---|---|
| P8-29 (#311) | Screen 1: Welcome | pass | Cone's icon and name (brand), text, media folder field with Browse, Next. Linux note: the folder field shows the home folder when there is no `~/Videos` (the sandbox has none) |
| P8-30 (#313) | Screen 2: theme and colour | pass | Light / Dark / System tiles, preview, 9 round swatches, Back / Next, as Onboarding-1.png |
| P8-31 (#314) | Screen 3: shortcuts | pass | layout as Onboarding-2.png; the keys are Cone's real ones (Decision 22: VLC's defaults), so several differ from Figma's (Shift+arrows, Ctrl+arrows, Ctrl+L, M) |
| P8-50 (#312) | Transitions | skip | motion |
| P8-28 (#310), P8-32 (#315), P8-37 (#323), P8-51 (#317) | Context / outro rows | skip | |

### 17. Resume toast, on-screen messages

| Row | Item | Result | Notes |
|---|---|---|---|
| P6-23 (#240) | "Continue where you left off" toast | pass | reopening S01E02 shows "You already watched till 00:17:48 [Continue Watching] X" above the control bar |
| IB-35 (#241) | Toast styling | skip | video only |
| P7-08 (#254), IB-38 (#253), P8-13 (#291), P3-15 (#86) | On-screen message shows the pressed shortcut | pass (rerun) | **Rerun #33:** built since (verified on Windows in round 5): A shows "Aspect ratio: 16:9" with "Pressed A" under it, Ctrl+Up "Volume: 105 %" with "Pressed Ctrl + Up". First run: not built. |
| P7-07 (#252), P6-22 (#239), P6-24 (#242), P7-01 (#244), P7-03 (#246), P7-11 (#257) | Problem / sponsor rows | skip | context |

### 18. Rows skipped as a whole

- Windows only: quit freeze, installer, file associations, Windows fonts and scaling (125 / 150 %), real sound output, GPU video and HDR output (d3d11), dropped-frame and performance rows (PERF.md).
- Need her video (no Figma frame, look or motion only): every row marked "none (video only)" that is not listed above with a function check, and the 59 context rows (old VLC, B-roll, sponsor, memes, survey charts: P1-01..P1-03, IA-07, P1-10, P1-11, P2-11, P2-26, P3-01, P4-01, P4-09..P4-11, ...).

## Sandbox notes (not row results)

- PulseAudio: the volume cone reads empty until the first volume change, and the speaker tooltip read "-100 %" with `--aout=dummy` (no volume). Recheck the start volume on a real Linux desktop.
- Openbox was not running for part of the session (a race in the test script, fixed). The keyboard rows checked in that time passed anyway; the Keyboard Shortcuts search (screen 9) was retried with openbox running and still failed.
- Folder pickers are Qt's own widget dialogs here (no xdg-desktop-portal in the sandbox).
