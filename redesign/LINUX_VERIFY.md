# Linux verification (branch wip/verify-linux)

Screen-by-screen check of Cone on Linux: the GitHub-built AppImage of `wip/verify-linux` (= `wip/linux-build` + `wip/beta` + `wip/web-fixes-1`), run in the cloud sandbox. **Nothing here changes VIDEO_INDEX** and nothing is marked verified there: this is a Linux pass of the same QML the Windows build runs; the PC test stays the reference.

## How it was run
- Build: build-linux #2, run 39125070286 (head e84bfc9b0e), artifact `cone-linux-appimage-x86_64` (AppImage unpacked once with `--appimage-extract`, then `AppRun`, as the sandbox has no FUSE).
- Order (as asked): the screens that `wip/beta` and `wip/web-fixes-1` did not change were to start on build #1 (run 39119874209) while #2 built; #2 went green after the first screen, so everything below was checked on #2 and nothing was rechecked. Changed since #1 (from `git diff origin/wip/linux-build`): Settings pages General, Interface, Privacy, Playback, Subtitles, Extensions and the info popovers; sidebar Subtitles tab; tracks popup; Queue / Chapters rows; subtitles above the bar; every application shortcut on Linux (Ctrl+P matcher fix).
- Display: Xvfb 1920x1080, 24 bit, 96 dpi (100 % scaling), openbox, software rendering (llvmpipe), test user in a D-Bus session, PulseAudio with its null sink (no sound card; real sound is a Windows-only row).
- Media (generated, no personal files): "Test Show/Season 1" with 3 episodes (1280x720, two audio tracks eng/jpn, two subtitle tracks eng/fre, chapters Winter / Spring / Summer), an external `.srt` per episode in another folder, 6 tagged songs with cover art (2 artists, 2 albums, 2 genres), a portrait clip, a letterboxed film with a very long name, an IPTV `.m3u`.
- Figma: the 2x PNG exports scaled to 1x, compared at the same scale with a screenshot of the same element.
- Each row: **Function** = used the controls and checked what the VIDEO_INDEX row says; **Looks** = compared with its Figma frame for layout, colours, fonts, icons, wording and spacing. Font smoothing differences between Linux and Windows are not counted.

Results: **pass**, **fail** (what is wrong, what Figma shows, likely file), **skip** (Windows only, needs her video, or a context row with nothing to build).

## Summary (one line per screen)

| Screen | Rows passed | Rows failed | Rows skipped |
|---|---|---|---|

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
| IA-13 (#35) | Thick seek bar construction | **fail** | On a file with chapters the thin bar's chapter segments are drawn under the thick bar: a square accent frame shows around the played part (outside the rounded BG/Accent Bright fill) and dark gaps cut the track at each chapter start. Figma: rounded track, rounded played fill, no frame, no gaps. Cause: `modules/gui/qt/player/qml/SliderBar.qml` around line 405, `visible: Player.hasChapters && !control.thick` is set on the Repeater, but a Repeater's delegates are parented to the Repeater's parent and do not inherit its `visible`. Not Linux-specific (any file with chapters) |
| P2-04 (#36), IA-14 (#37) | Seek thumbnail on hover | pass | real frame of the hovered time, time under it, card as thumbnail.png |
| P2-05 (#38), P2-07 (#40) | Old top bar | skip | context |
| P2-06 (#39) | Restyled one-row top bar | **fail** | After Next (S01E01 to S01E02) the centred title reads "The Wand S01E..." and stays elided, with half the bar free. Figma: the whole title, centred. Likely `modules/gui/qt/player/qml/TopBar.qml` `centerTitleText` (about line 255): `width: Math.min(implicitWidth, _maxWidth)` with `elide: Text.ElideRight` keeps the width of an intermediate title. Seen with Qt 6.10 (Linux); check whether Qt 6.8 (Windows) does the same |
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
| F-02 (#328) | Current time: hover and click to edit | **fail** (small) | Hover box and typing a time (00:10:00, Enter) work. On click the field selects its whole text (orange selection); Figma's edit state shows white text with an orange caret at the end and no selection. `modules/gui/qt/player/qml/ControlBar.qml:266` `timeEditor.selectAll()` |
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
| P3-10 (#81) | Save adds the external track | **fail** | The file is added under External Tracks but not selected: "Track 1 - English" keeps the check. Video and row: the new external entry gets the orange check and the embedded one loses it. VLC loads it as a forced slave (`loading spu slave ... (forced: 1)`) but no track switch follows. `modules/gui/qt/dialogs/redesign/addsubtitles/add_subtitles.cpp:1389` (`vlc_player_AddAssociatedMedia(..., first, ...)`): select the track once it is listed. Clicking the row by hand selects it and moves the check (single selection) |
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
| P4-35 (#145), P3-16 (#87), IA-27 (#88) | Subtitle timeline on the seek bar | not built | status todo in VIDEO_INDEX; the Playback tab has no such toggle |
| P4-36 (#146), P6-06 (#213) | Show Waveform on Seekbar | pass | the seek bar turns into waveform bars (with the IA-13 chapter frame drawn behind them on this file) |
| P4-37 (#147), F-23 (#349) | Show Metadata, Statistics, Audio Visualizer, order | pass | Metadata and Statistics open their panels on the left (Decision 24); order as the video plus Figma's Statistics (Decision 13) |
| P4-27 (#135), P4-28 (#136) | Video tab Defaults, segmented control | pass | Flip None / Horizontal / Vertical, Rotate, Zoom, Resolution, Aspect Ratio, Crop, Render (Decision 24: Local). The HDR row is hidden: it is d3d11's HDR mode (Windows only) |
| P4-29 (#138), P4-16 (#119), IA-37 (#120) | Build-up and tab animations | skip | video only |
| P4-30 (#139) | Video filters with presets | pass | Essential / Crop / Colors / Geometry / Overlay / Advanced expanders; Essential as Video - Essential.png |
| F-18 (#344) | Crop link toggle | pass | link Top-Bottom, Top 40 px: Bottom follows, link icon orange, picture cropped (log `vsz 640x280`) |
| P4-15 (#122), P4-17 (#123), P4-18 (#124), IA-38 (#121) | Audio tab Defaults, Test button, Synchronization | **fail** | Stereo Mode lists raw numbers "7, 1, 3, 4, 2" and shows "1" instead of Mono / Stereo / Left / Right (Figma "Mono"; P8-01 words not numbers). The core adds the names (`src/audio_output/output.c` ADDCHOICE with `_("Mono")` ...), so the names are lost in the interface: `modules/gui/qt/player/qml/AudioSettingsPage.qml:146` choices `Player.audioStereoMode` (its choice model). Seen with PulseAudio on a mono track; check on Windows. The "-10 s ... +10 s" labels fix Figma's typo (Decision 17); the "Track and language apply from the next file" note is Decision (Claude) W4.6 |
| P4-19 (#125), P4-20 (#126), IA-39 (#128) | Filters list, toggle and expander styles | pass | |
| P4-21 (#127) | Sticky footer over the scrolling content | pass | |
| P4-25 (#133), P4-26 (#134), IA-40 (#132) | EQ preset dropdown with curve icons | pass | curves drawn per preset; "Full bass" fixes Figma's "Full base" (Decision 17) |
| P4-24 (#131), P4-23 (#130) | Equalizer expanded, band sliders | **fail** (small) | Picking Classical applies the equalizer (log) and moves the sliders, but its near-zero bands read "-0.0 dB" (Figma "0.0 dB"): VLC's preset holds -1.1e-15 dB. Round before formatting: the band value text in `modules/gui/qt/player/qml/AudioSettingsPage.qml` |
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
| P8-03 (#273) | General page | **fail** (Linux only) | "Interface language" is missing: the row shows only where VLC has its `language` option, which exists on Windows (registry) and OS/2 only. Figma: first row of Appearance. Linux needs its own way (e.g. Cone stores the language and sets `LANGUAGE` before Qt and gettext start): `SettingsGeneralPage.qml` row `shown: SettingsCatalog.languageSupported`, plus the start-up code. (web fix 2) Log details lists "Errors only" first: pass. "Check for updates automatically" is absent as on Windows (Cone has no update checker, CONE_RELEASE_NOTES 2) |
| P8-22 (#300) | Advanced Options expander | pass | Note (Linux only): the General advanced options add VLC's syslog rows; "System log identity" defaults to "vlc" in the public build (`syslog-ident`), which names VLC |
| S2-01 (#350) | Additional command line options | not built | status todo |
| P8-04 (#276), P8-05 (#279), IB-43 (#272) | Theme and accent rows | pass | (light theme itself: screen 14) |
| P8-06 (#281), S2-02 (#351) | Interface page | pass | no Skin section (Decision 63: Cone has no skins); window, playback controls, tray rows as Figma |
| P8-07 (#282), S2-04 (#353) | Privacy page | pass | (web fix 7) "Ask about internet access when Cone starts" after "Last.fm submission URL"; Figma's second "Last.fm username" reads "Last.fm password" (Decision 17) |
| P8-08 (#283), S2-05 (#354) | Controls page | pass | |
| P8-09 (#284) | Playback page | pass | default tracks as "Automatic" dropdowns (words, P8-01) |
| P8-10 (#285) | Video page | **fail** (small) | Deinterlacing > Method reads "Auto"; Figma "Automatic" (the Deinterlacing row above says "Automatic"). VLC's `deinterlace-mode` choice text: relabel it in `SettingsVideoPage.qml` (option at line 149) |
| P8-11 (#286), S2-06 (#355) | Audio page | **fail** (Linux only) | "Output device" is missing and "Always starts at:" has no value: both rows use the Windows outputs' options (`mmdevice-audio-device` / `waveout-*`, `mmdevice-volume`; `SettingsAudioPage.qml:45-46`). Figma: "Output device: System default" under Output, "Always starts at: 200%". Linux needs the PulseAudio / ALSA equivalents (or the player's device list and `volume`) |
| P8-44 (#287), IB-45 (#288) | Inline equalizer, slider variants | pass | |
| P8-12 (#289), P8-45 (#290), S2-11 (#360) | Subtitles page | pass | (web fix 6) Text encoding "Automatic"; Preferred language "Automatic" (Decision (Claude) 2026-10-18 P8-12). Font "Serif Bold" is FreeType's Linux default, a value |
| P8-14 (#292) | Library page | pass | "Apply to files opened from the file manager" (Linux wording) |
| P8-15 (#293) | Network page | **fail** (Linux only) | The "Proxy" header shows with no rows under it: `http-proxy` / `http-proxy-pwd` exist only on Windows (`src/libvlc-module.c:1961`, obsolete elsewhere). Figma: HTTP proxy, HTTP proxy password. Hide the section when its rows don't exist (the beta's new `SettingsSection.shown`), `SettingsNetworkPage.qml:101`, or offer the Linux proxy setting |
| P8-16 (#294), S2-07 (#356), S2-08 (#357), S2-09 (#358) | Performance page | **fail** (Linux only) | "Video post-processing" is missing between Hardware-accelerated decoding and Skip the H.264 loop filter: the Linux build has no postproc module (the row needs `postproc-q`). Add libpostproc to the Linux build (`.github/scripts/linux-build.sh`) or accept the gap |
| P8-17 (#295), S2-10 (#359) | Recording page | pass | |
| P8-18 (#296), P8-20 (#298) | Extensions page | pass | |
| P7-12 (#258) | Keyboard Shortcuts from Controls | see screen 9 | |
| P7-14 (#262), P7-15 (#263), P7-17 (#265), IB-41 (#266), P8-01 (#267) | Basic then advanced, worded dropdowns | pass | search filters the categories and pages (e.g. "subtitle") |
| P8-40 (#274), P8-43 (#275) | Open transition, control styles | pass | opens instantly (Decision 32) |
| S2-03 (#352), S2-12 (#361) | Popup duration, fullscreen controls sensitivity | pass | rows present |
| P3-22 (#98), IA-33 (#99), P7-10 (#256), P8-19 (#297) | Problem rows | skip | context |
