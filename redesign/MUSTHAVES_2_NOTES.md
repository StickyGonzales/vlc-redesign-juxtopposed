# Must-haves 2 (branch wip/musthaves-2)

Branch `wip/musthaves-2`, made from `redesign` 8acefcb918. Pull request into `redesign`: https://github.com/StickyGonzales/vlc-redesign-juxtopposed/pull/22 (draft). **Nothing here is verified**: it was built and tried on Linux in the web session's sandbox only (section 5). It needs its own Windows build (it has core changes, Decision 27 / 55) and a test round on the PC.

## 1. What was built

### A. Subtitle timeline on the seek bar (P3-16, IA-27, P4-35; video 6:52-7:04, 9:13-9:15)
- **Switch:** the Playback tab's new first row **Show Subtitle Timeline on Seekbar** (off by default, Figma's first row, Decision 13 order). New Qt option `qt-seek-subtitle-timeline`; profiles carry it.
- **When it shows:** the switch is on and the selected subtitle track comes from a text file (drag and drop, Add Subtitles, `--sub-file`, a file found next to the video). Formats: SubRip (.srt), WebVTT, and the Dialogue lines of SSA / ASS. Embedded tracks (MKV) show no timeline: VLC only knows their lines as the demuxer reaches them.
- **What it looks like:** the thick seek bar shows a **time window** (1 min at first) instead of the whole file. Every subtitle line is a square-cornered block as tall as the played fill: a lighter brown left of the playhead (`rdSeekBlockPlayed`, the played fill with 9 % white over it, #49331C), BG/A2 right of it (`rdSeekBlockUnplayed`), over the dark brown played fill and the black track (section 9). The time labels show the window's ends with an asterisk, for example `00:06:00*` and `00:07:00*` (video 6:52).
- **Dragging:** press on a block and drag sideways: every block slides with the pointer and VLC's subtitle delay follows **live** (written at most once per turn of the event loop) (the same value as the sidebar's Subtitle delay slider, G / H and presets, -600 to 600 s, so they all move the blocks). VLC's own on-screen message shows the new delay. The pointer shows the sideways arrows over a block. A click on a block without a 3 px drag seeks, like a click beside the blocks (blocks cover much of the bar). The preview card hides during a drag.
- **The window:** it turns its page when the playhead leaves it and stays put while the bar is held. Buttons beside the bar (filled accent, dark glyphs, as tall as the bar and touching its ends, the chevrons narrower; section 9): `<` and `-` left of the bar, `+` and `>` right of it. `<` / `>` move the window by half its length (the playhead then hides while it is outside; the window follows again once the playhead is back inside), `-` / `+` step its length through 10 s, 30 s, 1 min, 2 min, 5 min. They are disabled at the ends.
- **With other modes:** the timeline replaces the waveform while it shows (the waveform scan is released). The preview card, the time tooltip, chapter snapping, the keys and the right click work inside the window.
- **Performance:** the file is parsed once, on a worker thread at low priority, only while a thick seek bar holds the option; a 32 MB cap. Drawing is two flat-colour triangle lists; while playing only the cut at the playhead moves (no relayout). No timer runs except a short retry (8 x 400 ms at most) when a just-added file is not listed on the media yet.

### B. On-screen messages name the pressed shortcut (P7-07, P7-08, IB-38, P8-13; video 15:16-15:28, 18:12-18:14)
- A message printed within 400 ms of a key press that triggered an action gets a **second line "Pressed C"** under it (400 ms so the volume, which the sound output reports from its own thread a little later, gets it too), for example `Crop: 2.35:1` / `Pressed C`. The key is worded as the interface shows keys elsewhere (Keyboard Shortcuts dialog, menus): `Ctrl + F`, letters in capitals.
- The second line is **80 %** of the message's size, regular weight, same colour and outline; both lines **left aligned** in the top right corner (IB-38). One-line messages are unchanged.
- **Settings > Subtitles > On-Screen Messages:** "Show feedback for shortcuts" is VLC's `osd` (all on-screen messages, as before). New row **"Show feedback for"** (Figma "Frame 146": slider 0.5 s to 5 s, ten ticks, labels "0.5 s" and "5 s"): how long the messages stay, new core option `osd-duration`, default 2.75 s (the slider's position in the video and Figma, section 9; VLC used 1 s). The volume / position bars stay 0.2 s longer, as VLC's did. Dimmed while "Show feedback for shortcuts" is off. It applies to the next message, no restart.
- Not for: the mouse wheel (not a key), icon-only messages (pause / play), actions an interface or a script triggers itself (menus, the bar's buttons, Windows global hotkeys, which set the action directly, touch gestures), and the interface's own notifications (for example "Bookmark added", Ctrl+B). Limit: a message from something else printed in those 400 ms (rare) also gets the line.

### C. "Additional command line options" (S2-01; video 18:50-18:54, Figma "Settings - global-1")
- **Settings > General > Advanced Options**, second row after "Show minor warnings": an empty text field. The (i) text says it applies the next time Cone starts.
- Options typed there apply **at every start**, as if typed after the program name, for example `--no-video-title-show --avcodec-threads=4`. Quotes keep blanks together (`--sub-language "en,fr"`); no escapes, so Windows paths keep their backslashes. File names are ignored.
- The **real command line wins** where both set the same option. Options that would print help or the version and quit (`--help`, `-H`, `--version`, `--list`, `-p`) are dropped. An invalid option is logged ("additional command line options: an option is not valid") and the options after it are ignored; Cone still starts.
- **Interface options are ignored (Decision 66):** `--intf` / `-I` in any spelling (`-I dummy`, `-Idummy`, `-vIdummy`, `--intf=skins2`), `--extraintf` (dummy or any other interface) and the skins interface's options (`--skins2-*`, `--skinned-*`, with the value of `--skins2-last` / `--skins2-config`), the same way skins are blocked on the real command line (Decision 63). A note under the field says so (FG/A3, the option names on their own line); the log says "additional command line options: the options that change the interface are ignored". The real command line can still set them. How: the skins options are dropped before the parse (they are unknown in Cone and would stop it); `intf` / `extraintf` set by the field are taken back after the parse, whatever spelling set them, unless the real command line set them.
- Limit (also in the option's description): the options read before the settings file (plugins cache, high priority, clock source) cannot be set here.

## 2. Files

| File | Change |
|---|---|
| `src/misc/actions.c` | **Core (Cone build).** When a key press becomes an action (vlc_key_to_action), the instance variables `osd-key-hint` (the key's display name) and `osd-key-hint-date` are set. |
| `src/video_output/video_text.c` | **Core (Cone build).** Messages: duration from `osd-duration`, the "Pressed" line (second, smaller, left-aligned text segment). |
| `src/video_output/video_widgets.c` | **Core (Cone build).** Volume / position bars: `osd-duration` + 200 ms. |
| `src/libvlc-module.c` | **Core (Cone build).** New options `osd-duration` (integer, 500-5000 ms) and `extra-options` (string). |
| `src/libvlc.c` | **Core (Cone build).** `libvlc_LoadExtraOptions()`, called right after the settings file loads; it ignores the interface options (Decision 66). |
| `modules/gui/qt/player/rd_subtitle_timeline.{hpp,cpp}` | New. `RdSubtitleTimeline` singleton: the selected external subtitle file, its cue times (worker thread), the media length in ms. |
| `modules/gui/qt/player/rd_subtitle_timeline_item.{hpp,cpp}` | New. `RdSubtitleTimelineItem`: the blocks (scene graph). |
| `modules/gui/qt/player/input_models.{hpp,cpp}` | `TrackListModel`: new `externalUri` role (the file name lookup now shares it). |
| `modules/gui/qt/player/qml/SliderBar.qml` | Timeline mode: window mapping (`_positionAt`, `_viewPosition`), the blocks layer, FSM state `fsmShifting`, paging, pan / zoom. |
| `modules/gui/qt/player/qml/SubtitleTimelineButtons.qml` | New. The `<` `-` / `+` `>` buttons. |
| `modules/gui/qt/player/qml/ControlBar.qml` | Buttons in both seek row places, asterisk labels, narrow-window room. |
| `modules/gui/qt/style/systempalette.{hpp,cpp}`, `VLCStyle.qml` | The block colours `rdSeekBlockPlayed` / `rdSeekBlockUnplayed`; the button sizes and the timeline's minimum width (section 9). |
| `modules/gui/qt/player/qml/PlaybackSettingsPage.qml` | "Show Subtitle Timeline on Seekbar" row. |
| `modules/gui/qt/qt.cpp` | Option `qt-seek-subtitle-timeline`. |
| `modules/gui/qt/maininterface/mainui.cpp` | Registers the singleton and the item. |
| `modules/gui/qt/dialogs/redesign/settings/pages/SettingsSubtitlesPage.qml`, `SettingsGeneralPage.qml` | The two Settings rows; the note under "Additional command line options" (Decision 66). |
| `modules/gui/qt/dialogs/redesign/settings/settings_catalog.cpp` | The new options are curated (not repeated under "More ... options"). |
| `modules/gui/qt/dialogs/toolbar/rd_profile_settings.cpp` | `osd-duration` and `qt-seek-subtitle-timeline` apply at once on a profile switch. |
| `modules/gui/qt/Makefile.am`, `meson.build` | Build lists. |
| `redesign/VIDEO_INDEX.md` | Rows 87, 88, 145, 253, 254, 291, 350 "in progress"; Decisions (Claude); Core changes. |
| `redesign/INTERACTIONS.md` | Seek bar modes: the timeline; Keyboard: the OSD key line. |

## 3. Core changes
All inside `#ifdef VLC_BRAND_PUBLIC`: the vlc profile compiles VLC's code unchanged (the options do not exist there, and the two Settings rows hide themselves). Approved by Decision 27; listed in VIDEO_INDEX "Core changes (status)".
1. `src/misc/actions.c` + `src/video_output/video_text.c` + `src/video_output/video_widgets.c` + `src/libvlc-module.c` (`osd-duration`): the OSD key line and the message time. Why core: VLC's on-screen messages are drawn by the video output from the core and the hotkeys module, not by the Qt interface; only the core's key map knows which key produced an action. A Qt-only version would have to draw its own copy of every message.
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

### Answers from the video (PC session, 2026-10-19)
Frames at 4 fps over 6:50-7:17, 15:22-15:30 and 18:11-18:16, plus 7:17, 7:20, 7:24 and 7:30; transcript lines at the same times. Pixel values are from the 1920x1080 video, where her window fills the frame.
1. **Buttons:** not answerable from the video. The buttons are never clicked or hovered, and the narration around them only says that the timeline shows when lines appear and that you pause and move the subtitles back. The asterisk labels mark the window's ends, which fits the built reading (`<` / `>` move the window, `-` / `+` change its length). Keep it; it stays a Claude decision.
2. **Layout:** between the labels and the bar, as built: `00:06:00*  < -  [bar]  + >  00:07:00*` (7:04, and again at 7:24 / 7:30 with the sidebar open). Differences from the build:
   - **Attached to the bar.** The buttons touch the bar's ends (no gap): the bar starts right after `-` and ends right before `+`. Built: 8 px from the bar.
   - **As tall as the thick bar.** Buttons 22 px tall, bar 22 px (y 1044-1065).
   - **Two widths.** `-` / `+` are 20 px wide (about square). `<` / `>` are narrower, 15-16 px (about 0.73 of the bar height).
   - **4 px apart, small radius** (about 3-4 px at this scale). Glyphs are dark on the orange fill.
   - **Fill is darker than Accent/Main.** It measures about #AB5611-#B05300, near Accent/DIm #AB6314, while the play button in the same frame is brighter orange. Compare on the build next to the play button.
3. **Colours (7:00 close-up and the full window at 7:04):**
   - Played fill: #331902 (about BG/Accent Bright #371F06).
   - Played-side blocks: **#4A331D / #4C3521**, a lighter brown. That is the played fill with about 9 % white over it, not Accent/DIm #AB6314, which is far brighter.
   - Unplayed blocks: **#1F1F1F**, BG/A2 (built BG/A1 #222222, close).
   - Unplayed track: #000000. Playhead: #DD6700 pill, taller than the bar.
   - Blocks are square-cornered, full bar height, and separated by short gaps of the fill or track.
   - Change: the played blocks should be about #4A331D (fill + 9 % white), not Accent/DIm.
4. **Window:** not answerable. From 7:04 to 7:12 the video is paused (identical frames), and the playhead never reaches a window end on screen. The window reads 00:06:00* to 00:07:00* (1 min) throughout. Keep the built paging and the 1 min start.
5. **Sidebar:** yes. At 7:12-7:16 the camera is on the sidebar; at 7:24 and 7:30 the sidebar is open and the bar still shows the timeline (`00:07:00*`, `+ >`). Nothing in the video ties the timeline to the sidebar, so "shows whenever the toggle is on" matches.
6. **"Pressed C" (15:23-15:28, close-up):**
   - **Size:** the capital C of "Pressed C" is 80 px tall against 97 px for the C of "Crop: 2.35:1", **about 82 %** (built 80 %, fine).
   - **Weight and colour:** same regular weight and white as the first line.
   - **Gap:** baseline to baseline is about 1.65x the first line's cap height (about 1.15x its font size). Built is to be compared on Windows.
   - **Alignment:** left aligned (the P's stem sits a little left of the C's curve).
   - **Position:** the message's text sits about a third of the way down (y 326-372 of 1080 in the full window at 15:22, right edge 140 px from the window's right edge), clear of the top bar. VLC's top-right position under the top bar is a difference to check on the build while the bars show.
7. **"Show feedback for" (18:12):** the thumb sits at the middle of the 0.5-5 s track, between the 2.5 s and 3 s ticks (about 2.75 s), the same as Figma. "Show filename for" also sits in the middle (1-10 s). Built default VLC's 1 s: Sticky's call whether the default follows her (about 3 s) or VLC.
8. **Bookmark notification:** the video shows no notification for adding a bookmark (Ctrl+B is Sticky's Decision 22, not hers), so there is nothing to copy. Keep "no".

## 5. Tested here (Linux sandbox, not verification)
Built with autotools in VideoLAN's Debian image (`registry.videolan.org/vlc-debian-unstable:20260611225331`, Qt 6.10, `--with-brand=public --disable-skins2 --disable-medialibrary`), run from the build tree under Xvfb (1600x1000, Mesa software OpenGL, no window manager, no sound: `-A dummy`), driven with xdotool, generated test media only (a 150 s testsrc2 video and an .srt with a line every 4 s). The image has no Qt SVG plugin, so every icon is a placeholder square. **Not verification**: no GPU, no Windows, no real mouse.
- **Build:** clean; no compiler warning in any changed file (one found and fixed: a doubled `KEY_UNSET` test). qmlcheck errors 1 (the known HighResolutionTimeWidget stub) / crashed 0, buildlists 0, privacycheck 0. No QML warning from the changed files at runtime.
- **Subtitle timeline:** with the option on and the .srt loaded, the log says "subtitle timeline: 37 cues"; the bar shows `00:00:00*` / `00:01:00*`, a block per line (accent on the played side, grey after), `<` dimmed at the start. Paused at 10 s, a 60 px drag on a block: every block moved about 55 px, VLC's message read "Subtitle delay: 4622 ms", the playhead did not move (no seek). A click on a block without dragging seeked there and left the delay alone. `>`: window 00:00:30* to 00:01:30*, playhead hidden, all blocks "to come"; `+`: 00:00:45* to 00:01:15*; `-`: back to 1 min; `<` back to the start: playhead shown again. Tooltips show. The Playback tab's first row "Show Subtitle Timeline on Seekbar" switched off gives the normal bar (`00:00:24` / `00:02:30`), on brings the timeline back at once.
- **"Pressed" line:** C gave "Crop: 16:10" / "Pressed C", A gave "Aspect ratio: 16:9" / "Pressed A": second line smaller, both left aligned at the top right. With `osd-duration=3000` the messages stayed about 3 s. (Volume could not be tried: no sound output in the sandbox.)
- **Settings rows:** Settings > General > Advanced Options shows "Additional command line options" (empty field) after "Show minor warnings"; Settings > Subtitles > On-Screen Messages shows "Show feedback for" at 3 s with "0.5 s" / "5 s" and ten ticks under "Show feedback for shortcuts".
- **Additional command line options:** `extra-options=--no-spu "--marq-marquee=a b" --help -p qt bogus.mkv` in vlcrc: Cone started normally (help and module help dropped, file name ignored, the quoted option kept as one), and the subtitles were hidden; started with `--spu` on the real command line, the subtitles showed (the command line wins). Not a test: `--sub-text-scale` (Cone applies its own subtitle size after start, on the real command line too).
- **Interface options (Decision 66):** `extra-options=-I dummy --extraintf=dummy --skins2-last foo.vlt --skinned-video --intf=skins2 -vIdummy --extraintf dummy --no-spu`: the Qt window opened (no dummy interface loaded), the subtitles were hidden (so the parse went on past the dropped options to `--no-spu`, and `-v` applied), and the log had the "interface are ignored" warning. An ambiguous abbreviation such as `--inter=dummy` (intf or interact) is not valid and stops the parse there, as on the real command line. The note under the field reads "Options that change the interface are ignored:" / "--intf, -I, --extraintf, skins".
- **Not tried here:** Ctrl+P (opens "previous" on Linux, a known Linux-only issue; Settings opened from the main menu), drag and drop, light theme, scaling, fullscreen, Windows.

## 6. How to test on Windows
Build this branch on its own (it has core changes): `gh workflow run build-windows.yml --ref wip/musthaves-2`, public profile. Test media: a video plus an .srt (generated or public test media only).

**A. Subtitle timeline**
1. Play the video, drop the .srt on it. Playback tab: turn on "Show Subtitle Timeline on Seekbar". The seek bar shows a 1 min window, labels `HH:MM:SS*` at both ends, a block for every line, the four buttons beside the bar.
2. Let it play past the window's end: the window turns its page; the blocks match when the lines show on the video.
3. Pause on a line. Drag its block left and right: all blocks slide, the playhead does not jump, the line on the video appears / disappears accordingly, VLC's message shows "Subtitle delay ...", the sidebar's Subtitle delay slider follows. No stutter, audio and video stay in sync.
4. Click on a block without dragging: it seeks there. Click beside the blocks: seeks. Hover: the preview card and the sideways cursor over blocks.
5. G / H and the sidebar slider: the blocks move. A per-show preset with a delay: the blocks move when it applies.
6. `<` `>`: the window moves by half; with the playhead outside, it hides; `-` `+`: 10 s to 5 min; disabled at the ends. Very short file (under 10 s), very long file.
7. Turn the waveform on too: the timeline wins; turn the timeline off: the waveform comes back.
8. Pick an embedded track or None: back to the normal bar. Back to the .srt: the timeline returns. Next / previous file.
9. Narrow window, Customize Player two-row layout, fullscreen, 125 / 150 % scaling, light theme and another accent (blocks and buttons recolour live).
10. A UTF-16 .srt, a .vtt, an .ass file.

**B. "Pressed" line**
1. Press C (crop), A (aspect ratio), V (subtitle track), B (audio track), Up / Down or Ctrl + Up / Down (volume), M (mute), G / H (subtitle delay), Z (zoom): the message has a second line "Pressed C" etc., smaller, left aligned with the first line.
2. Use the mouse wheel over the video for volume: no "Pressed" line. Click the bar's buttons, or Playback menu > Faster (fine) right after pressing `]`: no "Pressed" line.
3. Settings > Subtitles > On-Screen Messages > "Show feedback for": 0.5 s, 5 s; press a key each time and time the message. Turn "Show feedback for shortcuts" off: no messages; the slider dims.
4. A key with Ctrl, Alt, Shift reads "Ctrl + Alt + ...". A global hotkey (Settings > Keyboard Shortcuts, global column) while another window is in front.

**C. Additional command line options**
1. Settings > General > Advanced Options: type `--no-video-title-show`, close Settings, restart Cone: the file name no longer shows when a video starts. Remove it, restart: it shows again.
2. `--sub-language "en,fr"` with quotes. A wrong option `--no-such-option`: Cone still starts, the log says it was not valid.
3. `--help` or `--version` in the field: Cone still starts normally.
4. Start Cone from PowerShell with an option that conflicts with the field (field `--no-video-title-show`, command line `--video-title-show`): the command line wins.
5. `-I dummy`, `-Idummy`, `--intf=skins2`, `--extraintf=dummy`, `--skins2-last x.vlt` in the field, with `--no-video-title-show` after them: Cone opens its normal window, the file name does not show at the start (the option after them still applies), and the note under the field is readable at 100 / 125 / 150 % scaling.

Regression: open file, play, pause, seek, volume, mute, next / previous, fullscreen, subtitles on / off and track switching, audio track switching, queue, drag and drop, shortcuts, settings survive a restart, clean quit; the normal seek bar (timeline off) behaves exactly as before (drag, click, chapters, preview card).

## 7. Independent review (fresh agent, full diff) and what changed
Fixed:
1. The volume / mute message rarely got the "Pressed" line: Windows' sound output (mmdevice) and PulseAudio report the new volume from their own thread after the action returned. The key's name now comes with a time and stays usable for 400 ms.
2. The line could name the wrong key: the last key press stays the value of "key-pressed", and menus, Windows global hotkeys, touch gestures and scripts set the action directly. The name is now set only where a key press really becomes an action (`src/misc/actions.c`, vlc_key_to_action), which also gives global keys their own key; `modules/control/hotkeys.c` is unchanged now.
3. Every block drag first seeked to the grabbed point: the bar's TapHandler reports a release when the DragHandler takes the press over. The click-seek now waits a turn of the event loop and is dropped when a drag took over (checked on the run above: no seek).
4. `QRegularExpression::matchView` needs Qt 6.5 (VLC accepts 6.2): `match()` instead.
5. A window panned away from the playhead cut the blocks at the bar's edge: now all played or all to come.
6. A block drag wrote the delay on every mouse move (each write is a VLC message and a decoder change): at most once per turn of the event loop.
7. The track lookup (player lock, MD5 of every external file's address) ran on every track list signal even with the timeline off: it now runs only while a seek bar shows it.
8. The message was left aligned even when building its second line failed: only when the line is there.
9. The option's description now says the options win over the same settings made elsewhere.
Decided after the review (Decision 66, 2026-10-19): the field ignores every option that changes or removes the interface (section 1C).

Not changed (for the PC session or StickyGonzales):
- The sideways cursor over a block is worked out on pointer moves only: when the blocks move under a still pointer (page turn, G / H), it updates on the next move.
- The four timeline buttons take Tab focus but are not in the control bar's arrow-key navigation.

## 8. Commits
See `git log origin/redesign..wip/musthaves-2`: two core commits (OSD line + duration, extra options), the Settings rows, the subtitle timeline, the review fixes, docs. After the PC answers (section 9): the buttons, the block colours, the 2.75 s default (core) and the narrow window, one commit each.

## 9. Changes after the PC answers
Made from the answers in section 4 (2026-10-19). Not verified: retest on the Windows build of this branch.
1. **Timeline buttons attached to the bar** (answer 2): they touch the bar's ends (the seek row's 8 px gap is taken back on the bar's side), are as tall as the thick bar (28 px) and the chevrons are narrower: `-` / `+` 26 px wide, `<` / `>` 20 px, 4 px apart, radius 4. Tooltips, accessible names, Tab focus and the disabled look are unchanged. Kept: the fill stays Accent/Main (the answer measured it near Accent/DIm; compare it next to the play button on the Windows build before changing it). Files: `player/qml/SubtitleTimelineButtons.qml`, `player/qml/ControlBar.qml`, `style/VLCStyle.qml` (`rd_timelineButtonWidth`, `rd_timelineChevronWidth`). Retest: timeline on (section 6 A1); crop the bar next to the video at 7:04: no gap between `-` and the bar or between the bar and `+`, the buttons' top and bottom in line with the bar's; Tab reaches the four buttons, `<` dimmed at the start.
2. **Block colours** (answer 3): played-side blocks `rdSeekBlockPlayed` = BG/Accent Bright (the played fill) with 9 % white over it, #49331C with the default accent (video #4A331D); unplayed blocks `rdSeekBlockUnplayed` = BG/A2 #1F1F1F. No palette token was close to #4A331D, so both are new palette entries computed in `SystemPalette::applyRdColors()`: they follow the accent (from the accent's BG/Accent Bright) and the theme; Light uses 9 % black over the same surfaces (#C5A98C, and #CACACA instead of Light BG/A2, which is as light as the track #DEDEDE and would hide the blocks). Files: `style/systempalette.hpp`, `style/systempalette.cpp`, `player/qml/SliderBar.qml`. Retest: section 6 A1, crop the bar next to the video at 7:00 / 7:04 (played blocks a lighter brown than the fill, not orange); switch the accent and the light theme: the blocks recolour live and stay visible.
3. **"Show feedback for" defaults to 2.75 s** (answer 7): `osd-duration` default 2750 ms in `src/libvlc-module.c` (core, Cone build only, inside `#ifdef VLC_BRAND_PUBLIC`, one number; the QML row reads the core default, nothing else changed). The volume / position bars stay 2.95 s. VIDEO_INDEX's Decisions (Claude) line updated. Retest: with a fresh portable folder (or after Reset all settings), Settings > Subtitles > On-Screen Messages: the thumb sits between the 2.5 s and 3 s ticks; press C: the message stays about 2.75 s.
4. **Narrow window** (Windows test at 760 x 520): the middle slot's minimum width, which decides when the right controls hide, left out the timeline's buttons, so the seek row overflowed into the right controls (bar at its minimum, end label over the mute icon). Now the minimum counts the buttons, and the timeline's bar keeps at least `rd_seekTimelineMinimumWidth` (120 px, 2 px per second of a 1 min window) while there is room. Order as the window narrows: the right controls hide from the queue button inwards (as for the normal bar), then the timeline buttons (the window still turns its pages by itself), then the duration, then the current time. On its own row (Customize Player two-row layouts) nothing changes. Files: `player/qml/ControlBar.qml`, `player/qml/SubtitleTimelineButtons.qml`, `style/VLCStyle.qml`. Retest: timeline on, window 760 x 520: nothing overlaps, the volume control stays, the bar is clearly wider than a time label; narrow the window step by step down to the minimum: right controls go first, then the buttons, then the labels, never an overlap; widen again: everything comes back in reverse order; timeline off: the normal bar behaves as before.
5. **Message position clear of the top bar** (answer 6): not done. VLC's on-screen messages are placed by the core (`src/video_output/video_text.c`, 4 % from the top right corner of the video), which does not know the top bar's height or whether the bars show. Her message sits about a third of the way down and 7 % from the right edge; moving every top-right message there (or by the bar's height) is a core layout change with a choice to make (fixed place like the video, or only clear of the bar while it shows). Left for a decision by StickyGonzales.
