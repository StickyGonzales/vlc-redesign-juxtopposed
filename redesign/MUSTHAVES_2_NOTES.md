# Must-haves 2 (branch wip/musthaves-2)

Branch `wip/musthaves-2`, made from `redesign` 8acefcb918. Pull request into `redesign`. **Nothing here is verified**: it was built and tried on Linux in the web session's sandbox only (section 5). It needs its own Windows build (it has core changes, Decision 27 / 55) and a test round on the PC.

## 1. What was built

### A. Subtitle timeline on the seek bar (P3-16, IA-27, P4-35; video 6:52-7:04, 9:13-9:15)
- **Switch:** the Playback tab's new first row **Show Subtitle Timeline on Seekbar** (off by default, Figma's first row, Decision 13 order). New Qt option `qt-seek-subtitle-timeline`; profiles carry it.
- **When it shows:** the switch is on and the selected subtitle track comes from a text file (drag and drop, Add Subtitles, `--sub-file`, a file found next to the video). Formats: SubRip (.srt), WebVTT, and the Dialogue lines of SSA / ASS. Embedded tracks (MKV) show no timeline: VLC only knows their lines as the demuxer reaches them.
- **What it looks like:** the thick seek bar shows a **time window** (1 min at first) instead of the whole file. Every subtitle line is a square-cornered block as tall as the played fill: Accent/DIm left of the playhead, BG/A1 right of it, over the dark brown played fill and the black track. The time labels show the window's ends with an asterisk, for example `00:06:00*` and `00:07:00*` (video 6:52).
- **Dragging:** press on a block and drag sideways: every block slides with the pointer and VLC's subtitle delay follows **live** (the same value as the sidebar's Subtitle delay slider, G / H and presets, -600 to 600 s, so they all move the blocks). VLC's own on-screen message shows the new delay. The pointer shows the sideways arrows over a block. A click on a block without a 3 px drag seeks, like a click beside the blocks (blocks cover much of the bar). The preview card hides during a drag.
- **The window:** it turns its page when the playhead leaves it and stays put while the bar is held. Buttons beside the bar (small filled accent squares, dark glyphs): `<` and `-` left of the bar, `+` and `>` right of it. `<` / `>` move the window by half its length (the playhead then hides while it is outside; the window follows again once the playhead is back inside), `-` / `+` step its length through 10 s, 30 s, 1 min, 2 min, 5 min. They are disabled at the ends.
- **With other modes:** the timeline replaces the waveform while it shows (the waveform scan is released). The preview card, the time tooltip, chapter snapping, the keys and the right click work inside the window.
- **Performance:** the file is parsed once, on a worker thread at low priority, only while a thick seek bar holds the option; a 32 MB cap. Drawing is two flat-colour triangle lists; while playing only the cut at the playhead moves (no relayout). No timer runs except a short retry (8 x 400 ms at most) when a just-added file is not listed on the media yet.

### B. On-screen messages name the pressed shortcut (P7-07, P7-08, IB-38, P8-13; video 15:16-15:28, 18:12-18:14)
- A message that a key's action prints gets a **second line "Pressed C"** under it, for example `Crop: 2.35:1` / `Pressed C`. The key is worded as the interface shows keys elsewhere (Keyboard Shortcuts dialog, menus): `Ctrl + F`, letters in capitals.
- The second line is **80 %** of the message's size, regular weight, same colour and outline; both lines **left aligned** in the top right corner (IB-38). One-line messages are unchanged.
- **Settings > Subtitles > On-Screen Messages:** "Show feedback for shortcuts" is VLC's `osd` (all on-screen messages, as before). New row **"Show feedback for"** (Figma "Frame 146": slider 0.5 s to 5 s, ten ticks, labels "0.5 s" and "5 s"): how long the messages stay, new core option `osd-duration`, default VLC's 1 s. The volume / position bars stay 0.2 s longer, as VLC's did (1.2 s). Dimmed while "Show feedback for shortcuts" is off. It applies to the next message, no restart.
- Not for: the mouse wheel (not a key), icon-only messages (pause / play), actions an interface or a script triggers itself, and the interface's own notifications (for example "Bookmark added", Ctrl+B).

### C. "Additional command line options" (S2-01; video 18:50-18:54, Figma "Settings - global-1")
- **Settings > General > Advanced Options**, second row after "Show minor warnings": an empty text field. The (i) text says it applies the next time Cone starts.
- Options typed there apply **at every start**, as if typed after the program name, for example `--no-video-title-show --avcodec-threads=4`. Quotes keep blanks together (`--sub-language "en,fr"`); no escapes, so Windows paths keep their backslashes. File names are ignored.
- The **real command line wins** where both set the same option. Options that would print help or the version and quit (`--help`, `-H`, `--version`, `--list`, `-p`) are dropped. An invalid option is logged ("additional command line options: an option is not valid") and the options after it are ignored; Cone still starts.
- Limit (also in the option's description): the options read before the settings file (plugins cache, high priority, clock source) cannot be set here.

## 2. Files

| File | Change |
|---|---|
| `modules/control/hotkeys.c` | **Core module (Cone build).** While a key's action runs, the instance variable `osd-key-hint` holds the key's display name. |
| `src/video_output/video_text.c` | **Core (Cone build).** Messages: duration from `osd-duration`, the "Pressed" line (second, smaller, left-aligned text segment). |
| `src/video_output/video_widgets.c` | **Core (Cone build).** Volume / position bars: `osd-duration` + 200 ms. |
| `src/libvlc-module.c` | **Core (Cone build).** New options `osd-duration` (integer, 500-5000 ms) and `extra-options` (string). |
| `src/libvlc.c` | **Core (Cone build).** `libvlc_LoadExtraOptions()`, called right after the settings file loads. |
| `modules/gui/qt/player/rd_subtitle_timeline.{hpp,cpp}` | New. `RdSubtitleTimeline` singleton: the selected external subtitle file, its cue times (worker thread), the media length in ms. |
| `modules/gui/qt/player/rd_subtitle_timeline_item.{hpp,cpp}` | New. `RdSubtitleTimelineItem`: the blocks (scene graph). |
| `modules/gui/qt/player/input_models.{hpp,cpp}` | `TrackListModel`: new `externalUri` role (the file name lookup now shares it). |
| `modules/gui/qt/player/qml/SliderBar.qml` | Timeline mode: window mapping (`_positionAt`, `_viewPosition`), the blocks layer, FSM state `fsmShifting`, paging, pan / zoom. |
| `modules/gui/qt/player/qml/SubtitleTimelineButtons.qml` | New. The `<` `-` / `+` `>` buttons. |
| `modules/gui/qt/player/qml/ControlBar.qml` | Buttons in both seek row places, asterisk labels, narrow-window room. |
| `modules/gui/qt/player/qml/PlaybackSettingsPage.qml` | "Show Subtitle Timeline on Seekbar" row. |
| `modules/gui/qt/qt.cpp` | Option `qt-seek-subtitle-timeline`. |
| `modules/gui/qt/maininterface/mainui.cpp` | Registers the singleton and the item. |
| `modules/gui/qt/dialogs/redesign/settings/pages/SettingsSubtitlesPage.qml`, `SettingsGeneralPage.qml` | The two Settings rows. |
| `modules/gui/qt/dialogs/redesign/settings/settings_catalog.cpp` | The new options are curated (not repeated under "More ... options"). |
| `modules/gui/qt/dialogs/toolbar/rd_profile_settings.cpp` | `osd-duration` and `qt-seek-subtitle-timeline` apply at once on a profile switch. |
| `modules/gui/qt/Makefile.am`, `meson.build` | Build lists. |
| `redesign/VIDEO_INDEX.md` | Rows 87, 88, 145, 253, 254, 291, 350 "in progress"; Decisions (Claude); Core changes. |
| `redesign/INTERACTIONS.md` | Seek bar modes: the timeline; Keyboard: the OSD key line. |

## 3. Core changes
All inside `#ifdef VLC_BRAND_PUBLIC`: the vlc profile compiles VLC's code unchanged (the options do not exist there, and the two Settings rows hide themselves). Approved by Decision 27; listed in VIDEO_INDEX "Core changes (status)".
1. `modules/control/hotkeys.c` + `src/video_output/video_text.c` + `src/video_output/video_widgets.c` + `src/libvlc-module.c` (`osd-duration`): the OSD key line and the message time. Why core: VLC's on-screen messages are drawn by the video output from the core and the hotkeys module, not by the Qt interface. A Qt-only version would have to draw its own copy of every message.
2. `src/libvlc.c` + `src/libvlc-module.c` (`extra-options`): why core: options have to be in place before the interfaces and the player start; the Qt module starts too late for most of them (VIDEO_INDEX S2-01). The Windows launcher cannot read the settings file.
3. The subtitle timeline needs no core change (the Qt interface reads the file itself).

## 4. Open video questions (for the PC session)
1. **IA-27 buttons, 6:52-7:04 (frames f_00415 / f_00416):** what do `<` `-` `+` `>` do? Built: `<` / `>` move the window by half its length, `-` / `+` change its length. Other reading: `<` / `>` nudge the subtitles earlier / later (like G / H). Please check the frames and the transcript.
2. **IA-27 layout:** are the buttons between the time label and the bar (built: `00:06:00*  < -  [bar]  + >  00:07:00*`), or outside the labels? Their size, radius and gap (built: 20 px, radius 4, 4 px apart).
3. **IA-27 colours:** the played-side blocks ("lighter brown") are Accent/DIm here, the unplayed blocks BG/A1. Compare a crop of the video's bar (tl_416a/b) with the build.
4. **P3-16 window:** does her window turn pages (built) or scroll with the playhead? Is the window always one minute, or does it change?
5. **P3-16 / P3-18:** the timeline appears with the wand animation and stays while the sidebar is open (7:12-7:16). Built: it shows whenever the toggle is on (P4-35); the sidebar does not change it. Is that how she means it?
6. **IB-38 / P7-08, 15:23-15:28:** the size of "Pressed C" against "Crop: 2.35:1" (built 80 %), the gap between the lines, and the position (built: VLC's top right, which lies under the top bar while the bars show).
7. **P8-13, 18:12-18:14:** the "Show feedback for" slider's value in the video (built: VLC's 1 s by default; Figma's thumb sits near the middle).
8. Should the interface's own notifications (Ctrl+B "Bookmark added", above the control bar) also say "Pressed Ctrl + B"? Built: no.

## 5. Tested here (Linux sandbox, not verification)
See section 7.

## 6. How to test on Windows
Build this branch on its own (it has core changes): `gh workflow run build-windows.yml --ref wip/musthaves-2`, public profile. Test media: a video plus an .srt (generated or public test media only).

**A. Subtitle timeline**
1. Play the video, drop the .srt on it. Playback tab: turn on "Show Subtitle Timeline on Seekbar". The seek bar shows a 1 min window, labels `HH:MM:SS*` at both ends, a block for every line, the four buttons beside the bar.
2. Let it play past the window's end: the window turns its page; the blocks match when the lines show on the video.
3. Pause on a line. Drag its block left and right: all blocks slide, the line on the video appears / disappears accordingly, VLC's message shows "Subtitle delay ...", the sidebar's Subtitle delay slider follows. No stutter, audio and video stay in sync.
4. Click on a block without dragging: it seeks there. Click beside the blocks: seeks. Hover: the preview card and the sideways cursor over blocks.
5. G / H and the sidebar slider: the blocks move. A per-show preset with a delay: the blocks move when it applies.
6. `<` `>`: the window moves by half; with the playhead outside, it hides; `-` `+`: 10 s to 5 min; disabled at the ends. Very short file (under 10 s), very long file.
7. Turn the waveform on too: the timeline wins; turn the timeline off: the waveform comes back.
8. Pick an embedded track or None: back to the normal bar. Back to the .srt: the timeline returns. Next / previous file.
9. Narrow window, Customize Player two-row layout, fullscreen, 125 / 150 % scaling, light theme and another accent (blocks and buttons recolour live).
10. A UTF-16 .srt, a .vtt, an .ass file.

**B. "Pressed" line**
1. Press C (crop), A (aspect ratio), V (subtitle track), B (audio track), Up / Down or Ctrl + Up / Down (volume), G / H (subtitle delay), Z (zoom): the message has a second line "Pressed C" etc., smaller, left aligned with the first line.
2. Use the mouse wheel over the video for volume: no "Pressed" line. Click the bar's buttons: no "Pressed" line.
3. Settings > Subtitles > On-Screen Messages > "Show feedback for": 0.5 s, 5 s; press a key each time and time the message. Turn "Show feedback for shortcuts" off: no messages; the slider dims.
4. Settings > Controls / Keyboard Shortcuts: a key with Ctrl, Alt, Shift reads "Ctrl + Alt + ...".

**C. Additional command line options**
1. Settings > General > Advanced Options: type `--no-video-title-show`, close Settings, restart Cone: the file name no longer shows when a video starts. Remove it, restart: it shows again.
2. `--sub-language "en,fr"` with quotes. A wrong option `--no-such-option`: Cone still starts, the log says it was not valid.
3. `--help` or `--version` in the field: Cone still starts normally.
4. Start Cone from PowerShell with an option that conflicts with the field (field `--no-video-title-show`, command line `--video-title-show`): the command line wins.

Regression: open file, play, pause, seek, volume, mute, next / previous, fullscreen, subtitles on / off and track switching, audio track switching, queue, drag and drop, shortcuts, settings survive a restart, clean quit; the normal seek bar (timeline off) behaves exactly as before (drag, click, chapters, preview card).

## 7. Linux sandbox run
(filled in below)
