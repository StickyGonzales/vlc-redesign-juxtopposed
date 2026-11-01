# OSD inventory: every on-screen message Cone can show

Read-only research for P7-08 (the redesigned on-screen message overlay). No code was changed.
Branch `wip/osd-inventory`, taken from `redesign` at fad0675. Every row points to the code that prints it.

## Totals

| | Count |
|---|---|
| **Messages in the tables** | **46** |
| Core on-screen messages, drawn into the video by VLC's core | 43 |
| Interface notifications, drawn by the Qt interface (FloatingNotification) | 3 |

Core messages by group:

| Group | Count | With a slider today |
|---|---|---|
| 1. Toggles (on/off) | 6 | none |
| 2. Values (volume, speed, delays, zoom, crop, subtitle position, subtitle sync) | 14 | Volume (vertical, fullscreen only) |
| 3. Track and mode switches | 10 | none |
| 4. Time, seeking and navigation | 7 | Position (horizontal, fullscreen only), EPG panel (its own progress bar) |
| 5. Play state icons | 2 | none (icons only) |
| 6. Long text (title, file path) | 3 | none |
| 7. Cone addition ("Pressed ...") | 1 | none |
| 8. Interface notifications (Qt, not core OSD) | 3 | none |

How rows are counted: one row per message family. A row's **Variants** column lists every text it can take, including both states of a toggle and both directions of next/previous.

## How the core draws them (applies to every core row)

| Function | File | Draws |
|---|---|---|
| `vlc_player_osd_Message()` / `vout_OSDMessage()` / `vout_OSDMessageVa()` | `src/player/osd.c:89`, `src/video_output/video_text.c:175` | Text, top right of the video. Cone build: stays for `osd-duration` ms (default 2750, setting "Show feedback for"), second line "Pressed X" when a key caused it (row 7.1). VLC build: 1 s. |
| `vout_OSDText()` | `src/video_output/video_text.c:169` | Text at a given position for a given time. Used only by the media title (row 6.1). Never gets the "Pressed X" line. |
| `vout_OSDIcon()` | `src/video_output/video_widgets.c` | Play, pause or mute icon. No text, so no "Pressed X" line. |
| `vout_OSDSlider()` | `src/video_output/video_widgets.c` | Horizontal bar (position) or vertical bar (volume), clipped to 0..100. Cone: stays `osd-duration` + 200 ms. |
| `vout_OSDEpg()` | `src/video_output/video_epg.c:532` | EPG panel (channel, current and next programme, progress bar, clock), 3 s. |
| Master switch | `src/libvlc-module.c:1836` option `osd` ("Show feedback for shortcuts") | When off, none of the core rows show (checked in `video_text.c:132` and `video_widgets.c:289`). |

Every new core message replaces the one on screen: `vlc_player_osd_HoldAll()` (`src/player/osd.c:33`) clears the OSD and both slider channels first.

Keys below are VLC's Windows defaults from `src/libvlc-module.c` (non-Apple block, from line 2472). Cone keeps them all (Decision 22). "—" means no default key.

---

## 1. Toggles (on/off)

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 1.1 | `Scaled to screen` / `Original size` | the two states of `autoscale` | `src/player/osd.c:294-296` | **O** (Toggle autoscale, when zoom is already 1.0; otherwise O resets zoom, see 2.6); Qt menu "Always Fit Window" (`modules/gui/qt/menus/menus.cpp:464`) | text | no |
| 1.2 | `Deinterlace %s (%s)` | 1st %s: `On` / `Off`; 2nd %s: the raw mode id: `auto`, `discard`, `blend`, `mean`, `bob`, `linear`, `x`, `yadif`, `yadif2x`, `phosphor`, `ivtc` | `src/player/osd.c:314-326` | **D** (deinterlace on/off), **Shift+D** (next deinterlace mode); any change of `deinterlace` / `deinterlace-mode` on the video output | text | no |
| 1.3 | `Recording` / `Recording done` | start / stop | `src/player/player.c:1802-1804` | **Shift+R**; Qt record button (`modules/gui/qt/player/player_controller.cpp:2132`) | text | no |
| 1.4 | `Projection: %s` | `enabled` / `disabled` (English only, not translated) | `src/video_output/vout_intf.c:681` | Toggle projection action (key-projection-toggle, no default key) | text | no |
| 1.5 | `%s subtitle control` | `Primary` / `Secondary` (English only, not translated) | `modules/control/hotkeys.c:505-506` | **Ctrl+Shift+V** (switch which subtitle the delay and position keys act on) | text | no |
| 1.6 | Mute icon | only when muting. Unmuting shows row 2.1 (`Volume: N%`) instead. There is **no "Muted" text** anywhere in the code | `src/player/osd.c:163-164` (called from `src/player/aout.c:103`) | **M**; any change of the audio output's `mute` (Qt mute button, volume popup, CLI, ...) | icon only (so no "Pressed M", the known LOW finding on P7-08) | no |

## 2. Values (volume, speed, delays, zoom, crop, subtitle position, subtitle sync)

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 2.1 | `Volume: %ld%%` | 0% to 200% (Decision 7) | `src/player/osd.c:169` (called from `src/player/aout.c:94` and `:103`) | **Ctrl+Up** / **Ctrl+Down**, mouse wheel over the video (no "Pressed" line for the wheel, `src/misc/actions.c:475`), unmute; any change of the audio output's `volume` (Qt volume slider, CLI, ...) | text + **vertical slider in fullscreen only** (`osd.c:167-168`). The slider is clipped to 100, so it stays full from 100% to 200% | **yes (fullscreen)** |
| 2.2 | `Speed: %.2fx` | e.g. `Speed: 1.50x`. Not translated (no `_()`) | `src/player/player.c:1430` | **+** / **-** (next/previous preset speed), **=** (normal), **]** / **[** (fine, 0.1 steps); Qt speed controls (`player_controller.cpp:1381`, `:1396`, `:1445`) | text | no |
| 2.3 | `%s delay: %i ms` (by category) | %s = `Audio`, `Subtitle` or `Video` (English only, `src/player/player.h:360`) | `src/player/player.c:1831-1833` | **K** / **J** (audio delay +/-50 ms), **H** / **G** (subtitle delay +/-50 ms); Qt sidebar delay controls (`player_controller.cpp:1550-1574`); subtitle sync apply/reset (2.12, 2.13) | text | no |
| 2.4 | `%s delay: %i ms` (by track) | %s = the track's name (secondary subtitle) | `src/player/player.c:1883-1885` | **H** / **G** while "Secondary subtitle control" is active (row 1.5); Qt secondary subtitle delay (`player_controller.cpp:313`, `:1585`, `:1594`) | text | no |
| 2.5 | `Zoom: x%.2f` | any zoom that is not one of the named modes in 3.6, e.g. `Zoom: x1.10` | `src/player/osd.c:346` | **Alt+O** / **Alt+Shift+O** (scale up/down by 0.1) | text | no |
| 2.6 | `Zooming reset` | — | `src/player/osd.c:340` | zoom set to 1.0: **O** when zoom is not 1.0, **Alt+3** (1:1 Original), scale back to 1.0 | text | no |
| 2.7 | `Top crop: %d px` / `Bottom crop: %d px` / `Left crop: %d px` / `Right crop: %d px` | four sides | `src/player/osd.c:302-312` | **Alt+R** / **Alt+Shift+R** (top), **Alt+C** / **Alt+Shift+C** (bottom), **Alt+D** / **Alt+Shift+D** (left), **Alt+F** / **Alt+Shift+F** (right) | text | no |
| 2.8 | `Subtitle position %d px` | only when the value changes | `src/player/osd.c:328-329` | Subtitle position up/down actions (no default key); any change of `sub-margin` on the video output | text | no |
| 2.9 | `Secondary subtitle position %d px` | only when the value changes | `src/player/osd.c:331-332` | same actions while "Secondary subtitle control" is active; any change of `secondary-sub-margin` | text | no |
| 2.10 | `Sub sync: bookmarked audio time` | — | `modules/control/hotkeys.c:517` | **Shift+H** | text | no |
| 2.11 | `Sub sync: bookmarked subtitle time` | — | `modules/control/hotkeys.c:521` | **Shift+J** | text | no |
| 2.12 | `Sub sync: set bookmarks first!` | — | `modules/control/hotkeys.c:528` | **Shift+K** before both bookmarks are set | text | no |
| 2.13 | `Sub sync: corrected %lld ms (total delay = %lld ms)` | — (also prints 2.3 `Subtitle delay: N ms` right before it, which this one replaces) | `modules/control/hotkeys.c:541-543` | **Shift+K** after both bookmarks | text | no |
| 2.14 | `Sub sync: delay reset` | — (also prints 2.3 first) | `modules/control/hotkeys.c:550` | **Ctrl+Shift+K** | text | no |

## 3. Track and mode switches

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 3.1 | `%s track: %s` | 1st %s: `Audio` / `Video` / `Subtitle` (English only); 2nd %s: track name, or `N/A` when the last track of that kind is turned off | `src/player/osd.c:186`, `:229`, `:238` | **B** (next audio track), **V** (next subtitle track), **Alt+V** (previous subtitle track), **Shift+V** (subtitles on/off); picking a track in the Qt tracks popup / menus (`modules/gui/qt/player/input_models.cpp:209`, `:212`) | text | no |
| 3.2 | `%s tracks: %s` | several selected tracks joined with `, ` (e.g. two subtitle tracks at once) | `src/player/osd.c:241` | selecting a second subtitle track (dual subtitles), `vlc_player_SelectEsIdList` (`src/player/player.c:543`) | text | no |
| 3.3 | `Program Service ID: %s` | %s = program name | `src/player/osd.c:249` (from `src/player/player.c:336`) | **X** / **Shift+X** (next/previous program); Qt program menu (`input_models.cpp:663`, `player_controller.cpp:1780`). Only for streams with several programs (DVB, TS) | text | no |
| 3.4 | `Aspect ratio: %s` | `Default`, `16:9`, `4:3`, `1:1`, `16:10`, `2.21:1`, `2.35:1`, `2.39:1`, `5:4`, `Fill Window`, plus any `custom-aspect-ratios` (`src/video_output/vout_intf.c:132-142`, `:289`) | `src/player/osd.c:290-292` | **A** (cycle); Qt aspect ratio menu / sidebar (`player_controller.cpp:1283`); a per-show preset that sets it (see Not sure) | text | no |
| 3.5 | `Crop: %s` | `Default`, `16:10`, `16:9`, `4:3`, `1.85:1`, `2.21:1`, `2.35:1`, `2.39:1`, `5:3`, `5:4`, `1:1`, plus any `custom-crop-ratios` (`vout_intf.c:114-126`) | `src/player/osd.c:298-300` | **C** (cycle); Qt crop menu / sidebar (`player_controller.cpp:1284`) | text | no |
| 3.6 | `Zoom mode: %s` | `1:4 Quarter`, `1:2 Half`, `2:1 Double` (`vout_intf.c:103-107`; `1:1 Original` shows 2.6 instead) | `src/player/osd.c:343-344` | **Z** / **Shift+Z** (cycle), **Alt+1**, **Alt+2**, **Alt+4**; Qt zoom menu (`player_controller.cpp:1282`) | text | no |
| 3.7 | `Projection: %s` | `source`, `rectangular`, `equirectangular`, `cubemap (standard)`, `unknown` (English only) | `src/video_output/vout_intf.c:702-704` | change of `projection-mode` (360° video), only when the value changes | text | no |
| 3.8 | `Random: %s` | `On` / `Off` | `src/playlist/control.c:69-70` | **R**; Qt shuffle button; any change of the playlist's playback order | text | no |
| 3.9 | `Loop: %s` | `Off` / `All` / `One` | `src/playlist/control.c:106-107` | **L** (cycles Off, All, One); Qt loop button; any change of the playlist's repeat mode | text | no |
| 3.10 | `Audio device: %s` | %s = the device's display name | `modules/control/hotkeys.c:674`; also `modules/control/cli/player.c:800` | **Shift+A** (next audio device); CLI `adev` command | text | no |

## 4. Time, seeking and navigation

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 4.1 | `%s / %s` (time / length) | `%s` alone when the length is unknown (streams) | `src/player/osd.c:121-153` (from `src/player/input.c:153`, `:179`, `src/player/player.c:1506`) | every seek: **Shift+Left/Right**, **Alt+Left/Right**, **Ctrl+Left/Right**, **Ctrl+Alt+Left/Right** (jumps); **T** (show position, when there is no EPG); Qt seek bar click/drag, jump buttons (`player_controller.cpp:1455-1519`); jumping to a bookmark (`modules/gui/qt/medialibrary/mlbookmarkmodel.cpp:437`) | text + **horizontal slider in fullscreen only** (`osd.c:150-151`) | **yes (fullscreen)** |
| 4.2 | EPG panel | channel name, current programme "HH:MM-HH:MM title", next programme, progress bar of the current programme, clock "HH:MM" | `src/video_output/video_epg.c:316-410`, `:532-642` (from `modules/control/hotkeys.c:336`) | **T** on a stream that carries EPG data (DVB/TS); otherwise T shows 4.1 | panel with art, text and its own progress bar, 3 s | own bar |
| 4.3 | `Next chapter` / `Previous chapter` | two directions | `src/player/player.c:991`, `:1011` | **Shift+N** / **Shift+P**; Qt chapter buttons (`player_controller.cpp:1650`, `:1665`, `:1738`, `:1748`) | text | no |
| 4.4 | `Chapter %ld` | the chapter's **0-based** index (first chapter shows `Chapter 0`) | `src/player/player.c:978` | picking a chapter in the Qt Chapters tab / menu (`input_models.cpp:505`, `:552`, via `vlc_player_SelectChapter`); CLI `chapter N`; Lua | text | no |
| 4.5 | `Next title` / `Previous title` | two directions | `src/player/player.c:919`, `:931` | **Shift+B** / **Shift+O** (DVD/Blu-ray titles) | text | no |
| 4.6 | `Next` / `Previous` | two directions (playlist item) | `src/playlist/control.c:397`, `:371` | **N** / **P**, media keys; Qt next/previous buttons | text | no |
| 4.7 | `Next frame` / `Previous frame` | shown only on success; errors open a dialog instead ("can't seek back", "no video found", "can't pause/seek/pace", "invalid state") | `src/player/input.c:920` (from `:952`, `:968`) | **E** / **Shift+E** | text | no |

## 5. Play state icons

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 5.1 | Play icon at start | — | `src/player/player.c:1292` | every time playback of a media starts (`vlc_player_Start`): open a file, double-click in the queue, **N**/**P**, Up Next | icon only | no |
| 5.2 | Pause icon / Play icon | pause / resume | `src/player/player.c:1349` | **Space**, media play/pause key, Qt play button, a left click a disc menu does not use (`src/player/input.c:901`, `:1186`) | icon only | no |

## 6. Long text (titles, file paths)

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 6.1 | Media title at playback start | Now Playing text (radio/streams), or `Title - Artist`, or `Title`, or the item's name (`src/input/resource.c:186-215`). Not repeated if equal to the previous title (`resource.c:164-174`) | `src/video_output/video_output.c:294-305` (from `src/input/resource.c:511`) | a video output starts for a new media, only when `video-title-show` is on: **off by default in the Cone build** (Decision 69, `src/libvlc-module.c:1727`), on in the vlc profile. Position `video-title-position` (default bottom), time `video-title-timeout` (default 5000 ms) | text at its own position and time; no "Pressed" line | no |
| 6.2 | Snapshot file path | the full path of the saved picture; plus a small picture-in-picture of the snapshot for 4 s when `snapshot-preview` is on (default on, `src/libvlc-module.c:1757`) | `src/video_output/vout_intf.c:480-490` (text `:483`, picture `:454-475`) | **Shift+S**; Qt snapshot action (`player_controller.cpp:2149`) | text + snapshot thumbnail | no |
| 6.3 | `Subtitle slave added` / `Slave added` | subtitle file / other file (e.g. audio track) | `src/player/player.c:1193-1203` | adding a subtitle or audio file to the playing media with notify on: drag and drop onto the player, "Add subtitle file" (`player_controller.cpp:2315`, `modules/gui/qt/dialogs/dialogs_provider.cpp:1194`). The redesign's Add Subtitles dialog passes notify off (`modules/gui/qt/dialogs/redesign/addsubtitles/add_subtitles.cpp:1420`), so it shows nothing | text | no |

## 7. Cone addition

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 7.1 | `Pressed %s` (second line under a message) | %s = the key as the interface names it, e.g. `C`, `Ctrl + Up` (`src/misc/actions.c:474-486`) | `src/video_output/video_text.c:184-195` | any text message (all rows except 1.6, 4.2, 5.x, 6.1) printed within 400 ms of a key press that triggered an action. Not for the mouse wheel, not for icons and sliders. Cone build only (`#ifdef VLC_BRAND_PUBLIC`). 80% of the message's font size (`video_text.c:42`) | text (2nd line) | no |

## 8. Interface notifications (Qt, not core OSD)

Drawn by `modules/gui/qt/widgets/qml/FloatingNotification.qml` (in `Player.qml:1807`, `MinimalView.qml:172`, `MainDisplay.qml:316`), fed by `modules/gui/qt/util/ui_notifier.cpp`. They already use the interface's theme, are not part of the core OSD and do not obey the `osd` option.

| # | Text / format | Variants | File:line | Trigger | Draws | Slider |
|---|---|---|---|---|---|---|
| 8.1 | `Scale: %1%` | interface scale in percent | `modules/gui/qt/util/ui_notifier.cpp:32-37` | **Ctrl+=** / **Ctrl+Shift+-** (`modules/gui/qt/menus/qml/GlobalShortcuts.qml:54-55`), **Ctrl+mouse wheel** (`modules/gui/qt/maininterface/interface_window_handler.cpp:169-175`), interface scale setting | text card | no |
| 8.2 | `Minimal View` | only when entering it | `ui_notifier.cpp:39-44` | **Ctrl+H** (`GlobalShortcuts.qml:52`), View menu "Minimal View" | text card | no |
| 8.3 | `Bookmark added: %1` | %1 = bookmark name | `ui_notifier.cpp:50-56` (from `modules/gui/qt/medialibrary/mlbookmarkmodel.cpp:367`) | **Ctrl+B** / bookmark added without a dialog (Decision 22) | text card | no |

---

## Other paths checked (not counted)

| Path | File | Why not counted |
|---|---|---|
| Lua `vlc.osd.message / icon / slider` | `modules/lua/libs/osd.c:60-160`, documented in `share/lua/README.txt:275-285` | An API only. No bundled script in `share/lua` calls it; a user-installed Lua extension could print any text, icon (`pause`, `play`, `speaker`, `mute`) or slider. |
| Lua / CLI / HTTP control commands (seek, volume, track, chapter, ...) | `modules/lua/libs/*.c`, `modules/control/cli/*.c` | They call the same player functions, so they produce the rows above, nothing new (the CLI's own text is 3.10). |
| skins2 `Quit` | `modules/gui/skins2/commands/cmd_quit.cpp:39-40` | skins2 is not in the Cone build (Decision 63). |
| macOS interface messages | `modules/gui/macosx/playqueue/VLCPlayerController.m:1228`, `:1959` | macOS interface only, not in the Windows build. |
| `OSD_SPEAKER_ICON` | `include/vlc_vout_osd.h:50` | No core caller; only reachable from Lua. |
| Video filters that draw text over the video (marq, logo, rss, subtitles) | `modules/spu/*` | Overlays the user configures, or subtitles; not on-screen feedback messages. |
| Other Cone cards over the player (Up Next, Resume, Show prompt, Profile notice, Update notice) | `modules/gui/qt/player/qml/RdUpNextCard.qml`, `ResumeDialog.qml`, `RdShowPrompt.qml`, `modules/gui/qt/dialogs/toolbar/qml/RdProfileNotice.qml`, `modules/gui/qt/maininterface/qml/RdUpdateNotice.qml` | Interactive prompts already built in Cone's style, not feedback messages. |

## Wording notes for the redesign (facts from the code)

- Not translated today: `Speed: %.2fx` (`player.c:1430`, no `_()`), the category names `Audio` / `Video` / `Subtitle` in 2.3 and 3.1 (`player.h:360`), `Primary` / `Secondary` (1.5), every `Projection:` text (1.4, 3.7).
- `Deinterlace %s (%s)` shows the raw mode id (`yadif2x`), not its display name (`Yadif (2x)`), and shows `Off` when deinterlace is set to Automatic (-1), because only the value 1 counts as `On` (`osd.c:323`).
- `Chapter %ld` counts from 0 (4.4).
- `Volume: %ld%%` passes an `int` to `%ld` (`osd.c:162`, `:169`). Works on the current targets but is a format mismatch.
- The volume slider is clipped to 100 (`video_widgets.c:291-292`), so it cannot show 101% to 200%.

## Not sure (could not confirm from the code alone)

1. **`Subtitle text scale %d%%` (`src/player/osd.c:334-335`) looks unreachable.** The callback handles `sub-text-scale`, but that variable is not in the list the callback is registered for (`src/player/vout.c:133-137`), and the text scale is set on the player object (`src/player/player.c:1941-1945`), not on the video output. So **Ctrl+0** and **Ctrl+mouse wheel** (subtitle text scale) and Cone's sidebar text size (`modules/gui/qt/player/rd_effects.cpp:1031`) probably show no message. Needs a test on the build. Not counted above.
2. **Ctrl+mouse wheel does two things?** It is VLC's default key for subtitle text scale up/down (`src/libvlc-module.c`, KEY_SUBTEXT_SCALEUP/DOWN) and also the Qt interface scale (8.1). Which one wins over the video, and whether both fire, is not clear from the code.
3. **Per-show presets and the sidebar.** Applying a preset sets `zoom`, `aspect-ratio`, `crop` and `sub-margin` on the video output (`modules/gui/qt/player/rd_presets.cpp:97`, `:129-131`, `:781-783`). Every change of those variables runs the OSD callback, so a preset switch probably flashes 3.4 / 3.5 / 3.6 / 2.8 messages. Not traced to the end.
4. **Automatic move to the next queue item** at the end of a file: `Next` (4.6) is printed only by `vlc_playlist_Next()`. It is not clear whether the end-of-file advance goes through it or through another path that shows only the play icon (5.1).
5. **`N/A` from `vlc_player_osd_Track()` with `select = false`** (`osd.c:185`): no caller passes `false` today (the only call is `player.c:603` with `true`), so that variant is likely unreachable; the reachable `N/A` comes from `vlc_player_osd_Tracks()` (`osd.c:229`).
6. **Subtitle position at video start.** `vout_intf.c:411-414` re-triggers `sub-margin` and `secondary-sub-margin` when a video output starts; `osd.c:328` and `:331` skip the message when the value did not change, which should hide it, but it was not confirmed on a build.
7. **Messages on several video outputs.** With more than one video window (e.g. a visualizer plus video), every message goes to every window (`osd.c:33-46`). Not checked how Cone's single-window layout handles that.
