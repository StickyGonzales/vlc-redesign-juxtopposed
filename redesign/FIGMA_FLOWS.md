# FIGMA_FLOWS: prototype interactions and specs from the Figma file

Source: Figma REST API `GET /v1/files/mNrr8joVY8wKLkEAuKP77p` ("VLC Redesign (Community)", version 2409521707817118521, last modified 2026-10-12), saved locally as `redesign/reference/figma/figma_file.json` (26 MB, committed). Generated from that JSON; nothing here was guessed from images. PNG names refer to `redesign/reference/figma/`.

How to read this together with the other references:
- `VIDEO_INDEX.md` = what she shows and says (primary source). This file = what the Figma prototype wires up (clicks, hovers, drags, keys, transitions) plus exact sizes. Where they disagree, see "Conflicts" below and VIDEO_INDEX "Decisions needed".
- Colors: always the style names from `figma/styles.txt` (shown here as `Dark/BG/B2=#090909`).
- A Figma prototype is a demo: some links are placeholders (for example "About VLC" opening the Customize screen). Those are listed under "Prototype wiring that is not design intent" and must not be built.

## Summary
- 2708 prototype interactions on 2197 nodes (1868 variant state changes, 356 navigate, 239 swap overlay, 181 open overlay, 34 back, 30 close overlay).
- Triggers: click 1513, hover 1127, drag 50, key 18 (keys used: F, V, Enter). No timed (after delay) or mouse-enter/leave triggers.
- 4 flow starting points: Flow 1 = Player (Player-6.png, also the page's prototype start), Flow 2 = Player - Light (Player - Light.png), Flow 3 = Player - customize (Player - customize.png), Flow 4 = Onboarding (Onboarding.png).
- 105 top-level frames, matched 1:1 to the 105 PNGs (duplicate names are numbered in layer order: first = no suffix, then -1, -2, ...; checked by eye on Player.png, Player-5.png, Player-6.png). 94 have interactions; 11 have none: thumbnail, Sorting Options, context menu, folder context menu, file context menu, playlist context menu, audio value, option, setting category, Components, Designs (these are overlay targets or labels, not starting points).
- 61 frames have interactions on their own screen; 33 component sets carry interactions inside their definitions (state machines that apply everywhere the component is used).

## Key behaviors the prototype defines
Control bar (component `Controls`, 15 variants: default, Variant10, waveform, music, queue, bookmarks, chapters, subtitles, playback, sub timeline, audio, video, video settings, audio settings, subtitle settings)
- Play button: click toggles play <-> pause (pause = gray pill `Dark/FG/A3=#6B6B6B`, play = `Dark/Accent/Main=#D37918`). Instant.
- Current time: hover gives a dark background (`Dark/BG/B2`); click turns it into an editable field with an orange 1 px caret; Enter returns to normal (type a time to jump).
- Total time (Duration): click toggles to remaining time ("-00:23:30") and back.
- Volume: hover on the speaker icon opens the "audio value" tooltip ("100 %", 121x37, 63 px above the icon). Dragging the cone switches 50% <-> 200% with smart animate 300 ms ease-in-out. The volume component has steps 0, 10..100%, 150%, 200% (max 200%).
- Seek bar: hovering the playhead opens the thumbnail overlay (272x189, 132 px left / 209 px above). Clicking the seek row toggles the waveform seek bar (prototype demo of the waveform option).
- Right-side buttons each open one panel inside the Controls component; clicking the same button again closes it, clicking another switches: subtitle button -> tracks popup on the Subtitles tab, audio button -> tracks popup on the Audio tab, gear -> settings sidebar on the Playback tab, list button -> Queue panel.
- Tracks popup (400x524): tabs Video / Audio / Subtitles switch instantly. "Show Preferences" opens the settings sidebar on the matching tab (Video -> Video settings, Audio -> Audio settings, Subtitles -> Subtitle settings). External Tracks "+" and pencil both open Add Subtitles in "To This File / From Computer" mode (Add Subtitles to Playlist/Folder-2.png).
- Settings sidebar (400x946): tabs Playback / Video / Audio / Subtitles. Toggling "Show Subtitle Timeline on Seekbar" switches the seek bar into subtitle-timeline mode (times "00:01:50*" / "00:02:40*"). Expand Settings / Collapse Settings toggle filter cards instantly. Dropdowns (Setting Preset, EQ presets, HDR Options, Audio Visualizer, sub filename, Dropdown) open on click. "Open Advanced Settings" opens the Settings dialog on the matching category (Audio -> Settings - audio.png, Subtitles -> Settings - subtitles.png, Video -> Settings - video.png).
- Queue panel (400x946): tabs Queue / Bookmarks / Chapters.

Top bar and windows
- "..." (top-left) opens the main menu overlay (menu.png) 17 px right / 38 px below. Menu: Settings -> Settings - global.png overlay; Keyboard Shortcuts -> Keyboard Shortcuts.png overlay; Customize Player -> Player - customize.png; Profile (Movies) -> swaps to Profiles.png (submenu open).
- Sidebar toggle icon and the folder chip ("Videos" / "S01" / "My Songs") open and close the compact library: smart animate, "slow" easing, 208 ms.
- Key F: Player -> Player - hide UI.png and back (smart animate, ease-in-and-out, 300 ms).
- Key V: opens Add Subtitles (Add Subtitles to Playlist/Folder.png) from any player screen.

Library sidebar (component `sidebar`, 10 variants)
- Rail icons (Home, Videos, Music, Network, Playlists, Recent) switch the panel content; rail icons hover to `#FFFFFF 6%` background.
- Drill-down: Videos -> Shows -> The Wand -> S01 / S02; Music -> Songs -> My Songs; "..." in the breadcrumb and earlier breadcrumb segments go back up.
- Rows (`media`, 337x32): hover changes unwatched/watched rows to their hover variants (title becomes `Dark/FG/2`, a "..." button appears). "..." on a row opens file context menu.png; "..." in the panel header opens folder context menu.png; "..." on a playlist opens playlist context menu.png; sort icon opens Sorting Options.png; grid/list icon opens View Options.png (both 11 px left / 30 px below the icon). Picking Grid View / List View switches the full library screen.
- Clicking a song row plays it in the music player (Player - Music.png).
- Mini player (Miniplayer, 391x339): hover shows the overlay controls; the queue button expands it upward to 391x690 with the queue; dragging moves it between the four corners (Player-1..Player-4.png, smart animate ease-out 300 ms); X and the open icon go back to the player.

Dialogs
- Add Subtitles: target dropdown (To This File / To This Folder / To This Playlist) and source dropdown (From Computer / From OpenSubtitles) swap between the four dialog frames; "subtitle one" rows toggle selected on click; "subtitle multiple" rows hover. Save and X close the overlay.
- Settings dialog: category rows swap the dialog to that category's frame; "Advanced Options" toggles between the basic and the -1 (expanded) frame; Theme and Size values segmented controls switch on click; toggles flip ON/OFF; Startup volume rows select.
- Keyboard Shortcuts, Open Network Stream, New Playlist: X closes; no other wiring.
- Onboarding: Next / Back between the three screens; the 9 color frames (Onboarding-3..10) exist but are not wired.
- Customize Player: the drag sequence seek bar -> top bar items -> title -> folder chip -> fullscreen -> Favorite (each drag smart animate 50 ms, the last one 600 ms) ends at Player - customize-6.png; Save shows the alternate layout (Player - customize-7.png); its sidebar toggle / folder chip open the library (Player - customize-8.png); Cancel and X go back to the player.

## Prototype wiring that is not design intent (do not build)
- Main menu "About VLC" -> Customize screen; right-click "More Settings", "Open Media", "Quit VLC" -> Customize screen; right-click "Playlist" -> Keyboard Shortcuts dialog. These are demo shortcuts in the prototype.
- Clicking any Customize palette item (Backward 15s, Bookmarks, Chapters, Favorite, Forward 15s, Go Home, Properties, Quit, Replay, Settings, Thumbnail, Sidebar) navigates to Player.png: demo only.
- Clicking the seek row to toggle the waveform: demo of the "Show Waveform on Seekbar" option, not a real click behavior.
- Key V -> Add Subtitles and key F -> Hide UI: probably demo hotkeys (see Conflicts).

## Exact specs of the main components (from the JSON, 1x units, Inter everywhere)

Typography (all Inter): body/labels 400 14 px / line 16.9; time labels 400 15 px / 18.2; section headers 500 16 px / 19.4 (`Dark/FG/A1`); dialog section titles 400 16 px / 28 (`Dark/FG/2`); hints 400 14 px / 24.5 (`Dark/FG/A3`); placeholders `Dark/FG/A4=#404040`; buttons 600 14 px (dialogs) or 600 16 px (onboarding); toggle text 400 12 px / 14.5; onboarding titles 300 32 px (welcome) and 300/400 24 px / 42; letter spacing 0 everywhere. Text colors: primary `Dark/FG/A2=#8F8F8F`, secondary `Dark/FG/A3=#6B6B6B`, emphasized `Dark/FG/2=#C6C6C6` and `Dark/FG/1=#EAEAEA` (selected settings category).

| Component | Size | Layout (auto-layout gap / padding T,R,B,L) | Radius | Fill / stroke / effect |
|---|---|---|---|---|
| Player window | 1920x1080 | video area inset: 10 px padding, 19 px radius, 20 px `Dark/BG/A3` stroke frame | 19 (video frame) | window `Dark/BG/A3=#1B1B1B` |
| Top bar | 1920x40 | horizontal, gap 10, pad 6; left group 300x28 (cone 24 px in 38x28 cell, "..." , sidebar toggle, folder chip 82x28 r6 gap 4), centered title, right group 300x24 of 36x24 icon cells | - | `Dark/BG/A3`, bg blur 50; title Inter 400 14 `Dark/FG/A2` |
| Control bar | 1920x54 | horizontal, gap 20, pad 11,20,11,20; groups: transport 130x28 (gap 8), seek row 1406x28 (gap 8), volume 120x28 (gap 8), track buttons 114x32 (gap 12), queue button | - | `Dark/BG/A3 Transparent` (#191919 95%), 1 px top stroke `Dark/Divider/Dim`, bg blur 50 |
| Prev / Next | 30x28 cells, 24 px icon | pad 2,3 | - | icons `Dark/FG/A2`, 1.5 px strokes |
| Play button | 54x28 | pad 2,15,2,17 (pause 2,15,2,15) | 6 | play `Dark/Accent/Main`, glyph `Dark/FG/B1=#161616`; pause `Dark/FG/A3` |
| Current time / Duration | 76x28 | pad 2,8 | 6 | text Inter 400 15 `Dark/FG/A2`; hover/edit fill `Dark/BG/B2`; edit caret 1 px `Dark/Accent/Main` |
| Seek bar | 1238x28 (flexible) | track; played fill 24 px tall; playhead 8x24 (4x24 in music/waveform) | track 6, fill/playhead 4 | track `Dark/BG/B2=#090909`, played `Dark/BG/Accent Bright=#371F06`, playhead `Dark/Accent/Main` |
| Waveform seek bar | 1204x28 | ~245 bars 2 px wide, heights 2-14 px | 4 | bars `Dark/FG/A4=#404040` (played in accent) |
| Subtitle timeline | 1238x28 | cue blocks 20x24 `#FFFFFF 14%` r1; end buttons 18-22x24 r4 `Dark/Accent/DIm=#AB6314` with 2 px `Dark/BG/B2` stroke and glyph | 4 | played `Dark/BG/Accent Bright` |
| Volume cone | 88x28 | wedge vector | 0-2 | track `Dark/BG/B2`, fill gradient, `#262626` body |
| Icon button (Icon Wrapper) | 30x32 (24 px icon) | pad 4 | 4 | hover `#FFFFFF 6%`; icons 1.5 px strokes `Dark/FG/A2`, active strokes 2 px `Dark/Accent/Main` |
| Volume tooltip (audio value) | 121x37 | pad 10 | 6 | `Dark/BG/B1 Transparent` (#0E0E0E 95%), effect "bg blur + shadow"; text 400 14 `Dark/FG/A1` |
| Seek thumbnail | 272x189 (image 252x142 r4) | vertical, gap 10, pad 10 | 14 | `Dark/BG/A3 Transparent`, bg blur 50; time 400 15 |
| Tracks popup / Queue panel / Settings sidebar | 400 wide (524 / 946 / 946 tall) | vertical, gap 1; tab header 400x50 `Dark/BG/B2` with 3-4 tabs (129 px each for 3 tabs, 108/85/85/108 for 4), underline 2 px `Dark/Accent/Main`; section label rows 60 px pad 0,28; list rows 360x32 gap 12 inside pad 0,20 | 10 | `Dark/BG/B1 Transparent`, bg blur 50 |
| Settings sidebar rows | 360x48 (label + control), sliders in "wrapper" 360x49 | section header 400x39 pad 20,24,0,24 (Inter 500 16 `Dark/FG/A1`); groups pad 10,20 gap 5; 1 px dividers `Dark/Divider/Dim` | - | - |
| Sidebar preset footer | 400x125 | pad 20, gap 10: Setting Preset 360x42 (r6 `Dark/BG/B2`, option 356x38 r4) + button 360x32 | 6 | `Dark/BG/B1 Transparent`, 1 px `Dark/Divider/Dim` stroke, bg blur 50 |
| Button (Show Preferences / Open Advanced Settings) | 360x32 | gap 6, 20 px gear icon | 4 | `Dark/BG/B2`, text `Dark/FG/A3`; hover `Dark/BG/A4` + text `Dark/FG/A2` |
| Library sidebar | 427x986 = rail 50 + panel 377 | rail vertical gap 14 pad 8 (`Dark/BG/A4=#191919`); panel vertical gap 17 pad 20; header rows 337x24 (nav 60, breadcrumb 197 gap 6, actions 60), count row 337x24 | - | panel `Dark/BG/B1 Transparent`, bg blur 50; 1 px divider `Dark/Divider/Dim` |
| Library row (media) | 337x32, gap 10 | thumb 32x32 r2 `#303030`; watched bar 28x3 `Dark/Accent/Main` at the thumbnail bottom | 2 | title 400 14: unwatched `Dark/FG/A1`, hover `Dark/FG/2`, watched `Dark/FG/A3` |
| Home sections | 337 wide, sections gap 30, inner gap 15 | 163 px tall card rows, 79 px list rows | - | - |
| Mini player | 391x339 (391x690 with queue) | vertical gap 20 pad 8; video 375x211 r6 with 2 px `Dark/BG/B2` stroke; seek 375x16 (fill 12 px); info pad 4,8 | 14 | `Dark/BG/A3`, drop shadow 11.8; queue header 391x58 radii 14,14,2,2 `Dark/BG/A5` |
| Menus (main, folder, file, playlist, sort, view) | main 375 wide, others 265 wide | vertical, pad 4; option rows 48 px tall (367 or 257 wide), pad 2,14, gap 10, 24 px icons | panel 10, row 6 | `Dark/BG/A3 Transparent`, effect "bg blur + shadow"; hover/selected row `Dark/BG/A2=#1F1F1F`; check 2 px `Dark/Accent/Main`; shortcut text `Dark/FG/A3`; dividers 1 px `Dark/Divider/Dim` |
| Right-click menu | 292x683 | pad 4; rows 284x48 | 10 / 6 | `Dark/BG/A3 Transparent`, no blur/shadow effect |
| Menu icons | 24 px, 1.5 px strokes | two-tone: gray `Dark/FG/A2` + accent part `Dark/Accent/DIm=#AB6314` (not Main) | 4 (icon shapes) | - |
| Dialogs (Add Subtitles, Keyboard Shortcuts) | 1048x800 | header 1048x96 (radii 14,14,0,0, `Dark/BG/B2`, pad 9, gap 12: title row 32 + control row 34); body 632; footer 72 (pad 20) | 14 | Add Subtitles `Dark/BG/B1 Transparent`, others `Dark/BG/A3 Transparent`; effect "bg blur + shadow" |
| Dialogs (Open Network Stream 1048x631, New Playlist 713x589) | header 50 | body pad 22,20 gap 20; fields r6 `Dark/BG/B2` with 2 px `Dark/BG/A4` stroke, pad 8,18,8,12 | 14 | `Dark/BG/A3 Transparent` |
| Dialog header controls | 200x34 dropdowns / 610-820x34 fields | pad 5,8,5,12 | 6 | `Dark/BG/A5=#151515`, text `Dark/FG/A1` |
| Cancel / Save | 100x32 | pad 4,8 | 6 | Cancel `Dark/BG/A3` + `Dark/FG/A2`; Save `Dark/BG/Accent Bright` + `Dark/Accent/Main` (disabled = 50% opacity) |
| Keyboard Shortcuts rows | 1008x33, gap 14 | label 290 wide `Dark/FG/2`; two key fields 270x33 r6 `Dark/BG/B2` pad 4,20 | 6 | group titles 400 16 / 28 `Dark/FG/A1` |
| Settings dialog | 1048x865 | header 50 (`Dark/BG/B2`, search 200x34, title, close); nav column 216 (inner 200, gap 8, pad 6, r6 `Dark/BG/A3 Transparent`); content 832 (pad 20,24,40,24, gap 20; 100 under it only in the collapsed "Settings - global"); Advanced Options bar 784x38 r2 | 14 | `Dark/BG/B1 Transparent`, "bg blur + shadow" |
| Settings category row | 188x40 | gap 8, pad 4, 32 px icon cell | 2 | selected `Dark/BG/A1=#222222`, icon filled `Dark/Accent/Main`, text `Dark/FG/1` |
| Toggle | 68x32 | knob 26x26 r3 + 33x26 track r3 + label | 6 | ON: knob `Dark/Accent/DIm`, track `Dark/BG/Accent Bright`, "ON" `Dark/Accent/Main`; OFF: knob `Dark/FG/A4`, track `Dark/BG/A4`, "OFF" `Dark/FG/A3`; base `Dark/BG/B2` |
| Dropdown | 364x48 closed (option 360x44 r4 `Dark/BG/A4`); open list 364 wide, gap 2 pad 2, drop shadow 13.8 | | 6 | `Dark/BG/B2`; selected option `Dark/BG/A2` |
| Onboarding | 1090x759 | | 14 | `Dark/BG/B1`, drop shadow 11.8; Next/Finish 100x32 r6 `Dark/Accent/Main` + `Dark/FG/B1` 600 16; Back `Dark/BG/A3`; theme tiles 116x116 r19 (inner 100x100 r12), selected 4 px `Dark/Accent/Main` ring; color dots 64x64 (40 px dot), selected ring 4 px accent 30%, others 50% opacity; keycaps 42 px tall r12 `Dark/BG/A3` with 3 px `Dark/Divider/Bright` stroke and drop shadow |
| Resume toast ("continue") | 552x52 | gap 60, pad 10,10,10,20 | 16 | `Dark/BG/A3 Transparent`, bg blur 50; text 400 16 `Dark/FG/2`; "Continue Watching" 146x32 r6 `Dark/Accent/Main` + 600 14 `Dark/FG/B1`; close 44x32 r6 `Dark/BG/A1` |

Accent color options (Onboarding color dots, exact values, in order): orange `#D37918`, red `#E15032`, olive `#C49E23`, green `#19A234`, teal `#18AAD3`, blue `#185DD3`, purple `#8E42FF`, pink `#F052B3`, gray `#AFAFAF`. These are not in `styles.txt`.

Effect styles used: "bg blur" = background blur 50; "bg blur + shadow" = background blur 50 + drop shadow #000000 46% y 8 blur 15 (see `styles.txt`).

## Cross-check with VIDEO_INDEX.md and the video

Interactions the Figma prototype shows that VIDEO_INDEX.md did not have were added to VIDEO_INDEX.md as rows F-01 to F-23 (section "Items from the Figma prototype").

### Conflicts between the Figma prototype and the video
| # | Topic | Figma prototype | Video | Related index rows |
|---|---|---|---|---|
| 1 | Hide UI shortcut | Key F toggles Player <-> Player - hide UI (300 ms smart animate). The Figma right-click menu itself labels Hide UI "Ctrl + \", and the Keyboard Shortcuts dialog and onboarding both use F for Toggle Fullscreen. | Ctrl + \ (5:25-5:30). F is fullscreen in her shortcut screen (19:50). | P2-24, P2-25, P8-31 |
| 2 | Key V | Opens the Add Subtitles dialog from any player screen. | V = "Cycle Subtitle Track" on her onboarding shortcut screen (19:50). Add Subtitles is opened with "+" on External Tracks (6:02). | P3-05, P8-31 |
| 3 | Playback tab rows | Show Subtitle Timeline on Seekbar, Show Statistics, Reverse, Sleep Timer, Audio Visualizer, Speed. No "Show Waveform" toggle (the prototype switches to the waveform bar by clicking the seek row). | Show Subtitle Timeline on Seekbar, Show Waveform on Seekbar, Show Metadata, Reverse, Sleep Timer, Audio Visualizer, Speed (9:13-9:19). "Show Statistics" never appears. | P4-35, P4-36, P4-37 |
| 4 | Which tab the gear opens | Gear opens the settings sidebar on the Playback tab. | The sidebar first appears with Subtitles as the only named tab (7:12); the final tab order is Playback, Video, Audio, Subtitles. | P3-18, P4-31 |
| 5 | "+" on External Tracks | Opens Add Subtitles in "To This File / From Computer" with the language list (Folder-2.png). Pencil does the same. | "+" opens the dialog on "To This File" with an empty body; pencil is never clicked (6:02, 6:22). | P3-05, P3-10 |
| 6 | Seek thumbnail trigger | Only hovering the playhead (the 8x24 orange rectangle) opens the thumbnail. | Hovering or dragging anywhere along the seek bar shows the preview at the cursor (3:24-3:31). | P2-04 |
| 7 | Volume range | Volume component goes 0 to 200% (steps 10% to 100%, then 150%, 200%); drag demo jumps 50% <-> 200%. | Only green to olive levels seen; old VLC max was 125%. | P2-01, IA-12 |
| 8 | Queue panel | Always tabbed: Queue / Bookmarks / Chapters (400x946 panel, header "4 items - 2h 3m"). | No tabs at 2:48 and 9:29; tabs only from 15:08. | P1-18, P5-02, P7-05 |
| 9 | Tracks popup content | Subtitles: Embedded None / English / Japanese, External "The_Wand_S01_EN.srt". Audio: Embedded None / English / Japanese. Video: None / Track 1. | Embedded None / "Track 1 - English", External "The_Wand_S01E04 [English]". | P2-16, P3-04 |
| 10 | Library Home | Includes a "Latest Streams" section ("TV Channels") after "Frequently Listened Artists". | Home ends at "Frequently Listened Artists" (13:44-13:48). | P6-20 |
| 11 | Library drill-down | Videos root: Add, Shows, Films, Anime (3 items); The Wand has S01 and S02. | Videos root: Add, Shows, Youtube Footage, Courses, Films, Anime (5 items); only S01 seen. | P5-29 |
| 12 | Onboarding colors | 9 color frames exist (Onboarding-3..10) but clicking a color is not wired; only Next / Back work. | Picking a color recolors the preview live (19:49). | P8-30 |
| 13 | Prototype placeholders | About VLC, Quit VLC, More Settings, Open Media lead to the Customize screen; right-click Playlist opens Keyboard Shortcuts. | Not shown in the video. | see "Prototype wiring that is not design intent" |
| 14 | Mini player queue header | Sort, minus, plus only (no repeat / shuffle). | Sort, repeat, shuffle, minus, plus (11:52). | P5-28 (already listed) |
| 15 | Sidebar footer button | Component default text "Show Advanced Settings"; used with text "Open Advanced Settings" in the sidebar and "Show Preferences" in the tracks popup. | "Open Advanced Settings" and "Show Preferences". | IA-34 (already listed) |

# Full prototype data

## Flow starting points

- **Flow 1** starts at Player (Player-6.png)
- **Flow 2** starts at Player - Light (Player - Light.png)
- **Flow 3** starts at Player - customize (Player - customize.png)
- **Flow 4** starts at Onboarding (Onboarding.png)
- Prototype start node of the page: Player (Player-6.png)

### Screens reachable from each flow (navigate / overlay / swap links, breadth-first)

- **Flow 1** (44 screens): Player-6.png -> Player.png -> Add Subtitles to Playlist/Folder.png -> folder context menu.png -> thumbnail.png -> audio value.png -> Player - hide UI.png -> menu.png -> Sorting Options.png -> View Options.png -> Player-3.png -> Player - customize.png -> Keyboard Shortcuts.png -> Profiles.png -> Settings - global.png -> Player-1.png -> Player-4.png -> Player - customize-1.png -> Settings - interface.png -> Settings - global-1.png -> Settings - privacy.png -> Settings - playback.png -> Settings - video.png -> Settings - audio.png -> Settings - subtitles.png -> Settings - controls.png -> Settings - library.png -> Settings - network.png -> Settings - performance.png -> Settings - recording.png -> Settings - extensions.png -> Player-2.png -> Player - customize-2.png -> Settings - interface-1.png -> Settings - playback-1.png -> Settings - video-1.png -> Settings - audio-1.png -> Settings - subtitles-1.png -> Player - customize-3.png -> Player - customize-4.png -> Player - customize-5.png -> Player - customize-6.png -> Player - customize-7.png -> Player - customize-8.png
- **Flow 2** (45 screens): Player - Light.png -> Player.png -> Add Subtitles to Playlist/Folder.png -> folder context menu.png -> thumbnail.png -> audio value.png -> Sorting Options.png -> View Options.png -> Player-3.png -> Player-6.png -> Player-1.png -> Player-4.png -> Player - hide UI.png -> menu.png -> Player-2.png -> Player - customize.png -> Keyboard Shortcuts.png -> Profiles.png -> Settings - global.png -> Player - customize-1.png -> Settings - interface.png -> Settings - global-1.png -> Settings - privacy.png -> Settings - playback.png -> Settings - video.png -> Settings - audio.png -> Settings - subtitles.png -> Settings - controls.png -> Settings - library.png -> Settings - network.png -> Settings - performance.png -> Settings - recording.png -> Settings - extensions.png -> Player - customize-2.png -> Settings - interface-1.png -> Settings - playback-1.png -> Settings - video-1.png -> Settings - audio-1.png -> Settings - subtitles-1.png -> Player - customize-3.png -> Player - customize-4.png -> Player - customize-5.png -> Player - customize-6.png -> Player - customize-7.png -> Player - customize-8.png
- **Flow 3** (44 screens): Player - customize.png -> Player.png -> Add Subtitles to Playlist/Folder.png -> folder context menu.png -> Player - customize-1.png -> Player-6.png -> Sorting Options.png -> View Options.png -> Player-3.png -> thumbnail.png -> audio value.png -> Player - customize-2.png -> Player - hide UI.png -> menu.png -> Player-1.png -> Player-4.png -> Player - customize-3.png -> Keyboard Shortcuts.png -> Profiles.png -> Settings - global.png -> Player-2.png -> Player - customize-4.png -> Settings - interface.png -> Settings - global-1.png -> Settings - privacy.png -> Settings - playback.png -> Settings - video.png -> Settings - audio.png -> Settings - subtitles.png -> Settings - controls.png -> Settings - library.png -> Settings - network.png -> Settings - performance.png -> Settings - recording.png -> Settings - extensions.png -> Player - customize-5.png -> Settings - interface-1.png -> Settings - playback-1.png -> Settings - video-1.png -> Settings - audio-1.png -> Settings - subtitles-1.png -> Player - customize-6.png -> Player - customize-7.png -> Player - customize-8.png
- **Flow 4** (12 screens): Onboarding.png -> Onboarding-1.png -> Onboarding-2.png -> folder context menu.png -> thumbnail.png -> audio value.png -> Sorting Options.png -> View Options.png -> Player-3.png -> Player-1.png -> Player-4.png -> Player-2.png

## Frame to PNG map

| Frame (layer) | Node id | Type | Size | PNG in figma/ | Interactions on screen | Interactions inside component definitions |
|---|---|---|---|---|---|---|
| Icon | 42:356 | component_set | 548x812 | Icon.png | 0 | 4 |
| Player | 187:328 | frame | 1920x1080 | Player.png | 38 | 0 |
| Player | 970:3308 | frame | 1920x1080 | Player-1.png | 30 | 0 |
| Player | 970:3792 | frame | 1920x1080 | Player-2.png | 30 | 0 |
| Player | 970:2703 | frame | 1920x1080 | Player-3.png | 15 | 0 |
| Player | 970:4028 | frame | 1920x1080 | Player-4.png | 11 | 0 |
| Player | 6261:15078 | frame | 1920x1080 | Player-5.png | 10 | 0 |
| Player | 247:445 | frame | 1920x1080 | Player-6.png | 59 | 0 |
| Player - Music | 4767:23726 | frame | 1920x1080 | Player - Music.png | 54 | 0 |
| Player - Music | 4778:25123 | frame | 1920x1080 | Player - Music-1.png | 40 | 0 |
| Player - hide UI | 3328:11554 | frame | 1920x1080 | Player - hide UI.png | 58 | 0 |
| Player - Light | 2425:13624 | frame | 1920x1080 | Player - Light.png | 56 | 0 |
| Player - customize | 2107:5604 | frame | 1920x1080 | Player - customize.png | 96 | 0 |
| Player - customize | 2160:6137 | frame | 1920x1080 | Player - customize-1.png | 97 | 0 |
| Player - customize | 2160:6564 | frame | 1920x1080 | Player - customize-2.png | 96 | 0 |
| Player - customize | 2160:7005 | frame | 1920x1080 | Player - customize-3.png | 96 | 0 |
| Player - customize | 2160:7437 | frame | 1920x1080 | Player - customize-4.png | 96 | 0 |
| Player - customize | 2160:7869 | frame | 1920x1080 | Player - customize-5.png | 96 | 0 |
| Player - customize | 6587:19923 | frame | 1920x1080 | Player - customize-6.png | 96 | 0 |
| Player - customize | 2160:8301 | frame | 1920x1080 | Player - customize-7.png | 51 | 0 |
| Player - customize | 2160:8732 | frame | 1920x1080 | Player - customize-8.png | 50 | 0 |
| Settings - global | 999:5047 | frame | 1048x865 | Settings - global.png | 21 | 0 |
| Settings - global | 3046:9282 | frame | 1048x865 | Settings - global-1.png | 25 | 0 |
| Settings - interface | 3046:10057 | frame | 1048x865 | Settings - interface.png | 26 | 0 |
| Settings - interface | 3062:11379 | frame | 1048x865 | Settings - interface-1.png | 30 | 0 |
| Settings - privacy | 3062:11911 | frame | 1048x865 | Settings - privacy.png | 18 | 0 |
| Settings - playback | 3062:12552 | frame | 1048x865 | Settings - playback.png | 22 | 0 |
| Settings - playback | 3072:13408 | frame | 1048x865 | Settings - playback-1.png | 22 | 0 |
| Settings - video | 3073:14187 | frame | 1048x865 | Settings - video.png | 22 | 0 |
| Settings - video | 3073:15375 | frame | 1048x865 | Settings - video-1.png | 22 | 0 |
| Settings - audio | 3073:15879 | frame | 1048x865 | Settings - audio.png | 29 | 0 |
| Settings - audio | 3180:17398 | frame | 1048x865 | Settings - audio-1.png | 30 | 0 |
| Settings - subtitles | 3180:17989 | frame | 1048x865 | Settings - subtitles.png | 22 | 0 |
| Settings - subtitles | 6536:13908 | frame | 1048x865 | Settings - subtitles-1.png | 22 | 0 |
| Settings - controls | 6536:14482 | frame | 1048x865 | Settings - controls.png | 17 | 0 |
| Settings - library | 6542:15251 | frame | 1048x865 | Settings - library.png | 19 | 0 |
| Settings - network | 6543:15649 | frame | 1048x865 | Settings - network.png | 16 | 0 |
| Settings - performance | 6571:15958 | frame | 1048x865 | Settings - performance.png | 16 | 0 |
| Settings - recording | 6571:16429 | frame | 1048x865 | Settings - recording.png | 19 | 0 |
| Settings - extensions | 6575:17137 | frame | 1048x865 | Settings - extensions.png | 14 | 0 |
| Add Subtitles to Playlist/Folder | 1911:7545 | frame | 1048x800 | Add Subtitles to Playlist/Folder.png | 19 | 0 |
| Add Subtitles to Playlist/Folder | 3336:11929 | frame | 1048x800 | Add Subtitles to Playlist/Folder-1.png | 19 | 0 |
| Add Subtitles to Playlist/Folder | 1919:8707 | frame | 1048x800 | Add Subtitles to Playlist/Folder-2.png | 11 | 0 |
| Add Subtitles to Playlist/Folder | 1919:9278 | frame | 1048x800 | Add Subtitles to Playlist/Folder-3.png | 7 | 0 |
| Keyboard Shortcuts | 2437:14832 | frame | 1048x800 | Keyboard Shortcuts.png | 2 | 0 |
| Open network stream | 6216:13614 | frame | 1048x631 | Open network stream.png | 2 | 0 |
| new playlist | 6259:14954 | frame | 713x589 | new playlist.png | 2 | 0 |
| Onboarding | 1899:3055 | frame | 1090x759 | Onboarding.png | 1 | 0 |
| Onboarding | 1902:3670 | frame | 1090x759 | Onboarding-1.png | 56 | 0 |
| Onboarding | 1902:6770 | frame | 1090x759 | Onboarding-2.png | 1 | 0 |
| Onboarding | 1902:4020 | frame | 1090x759 | Onboarding-3.png | 47 | 0 |
| Onboarding | 1902:4325 | frame | 1090x759 | Onboarding-4.png | 47 | 0 |
| Onboarding | 1902:4634 | frame | 1090x759 | Onboarding-5.png | 47 | 0 |
| Onboarding | 1902:4940 | frame | 1090x759 | Onboarding-6.png | 47 | 0 |
| Onboarding | 1902:5245 | frame | 1090x759 | Onboarding-7.png | 47 | 0 |
| Onboarding | 1902:5550 | frame | 1090x759 | Onboarding-8.png | 47 | 0 |
| Onboarding | 1902:6160 | frame | 1090x759 | Onboarding-9.png | 47 | 0 |
| Onboarding | 1902:6465 | frame | 1090x759 | Onboarding-10.png | 47 | 0 |
| Icon Wrapper | 177:98 | component_set | 72x122 | Icon Wrapper.png | 0 | 2 |
| volume | 244:184 | component_set | 130x646 | volume.png | 0 | 2 |
| Controls | 491:1780 | component_set | 1960x11139 | Controls.png | 0 | 286 |
| thumbnail | 2151:9673 | frame | 272x189 | thumbnail.png | 0 | 0 |
| Button | 500:3063 | component_set | 400x140 | Button.png | 0 | 1 |
| Toggle | 536:1014 | component_set | 120x194 | Toggle.png | 0 | 2 |
| Audio - Compressor Settings | 536:1513 | component_set | 400x821 | Audio - Compressor Settings.png | 0 | 2 |
| Audio - Equalizer | 6114:13610 | component_set | 400x1623 | Audio - Equalizer.png | 0 | 2 |
| Audio - Spatializer Settings | 536:1703 | component_set | 400x821 | Audio - Spatializer Settings.png | 0 | 2 |
| Audio - Stereo Widener | 612:1223 | component_set | 400x821 | Audio - Stereo Widener.png | 0 | 2 |
| Video - Essential | 536:1855 | component_set | 400x821 | Video - Essential.png | 0 | 2 |
| Video - Crop | 543:990 | component_set | 400x821 | Video - Crop.png | 0 | 6 |
| Video - Colors | 614:1430 | component_set | 400x888 | Video - Colors.png | 0 | 9 |
| Values | 804:1208 | component_set | 253x404 | Values.png | 0 | 8 |
| play | 848:1712 | component_set | 94x116 | play.png | 0 | 2 |
| sidebar | 848:1996 | component_set | 4492x1028 | sidebar.png | 0 | 221 |
| Sorting Options | 856:2215 | frame | 265x776 | Sorting Options.png | 0 | 0 |
| context menu | 2107:5903 | frame | 265x296 | context menu.png | 0 | 0 |
| folder context menu | 2139:8935 | frame | 265x296 | folder context menu.png | 0 | 0 |
| file context menu | 2404:13340 | frame | 265x584 | file context menu.png | 0 | 0 |
| playlist context menu | 2459:9389 | frame | 265x392 | playlist context menu.png | 0 | 0 |
| View Options | 858:3290 | frame | 265x104 | View Options.png | 2 | 0 |
| Miniplayer | 970:3091 | component_set | 431x2816 | Miniplayer.png | 0 | 15 |
| Current Time | 1904:7238 | component_set | 114x164 | Current Time.png | 0 | 3 |
| audio value | 2245:9805 | frame | 121x37 | audio value.png | 0 | 0 |
| Duration | 1905:7312 | component_set | 114x164 | Duration.png | 0 | 3 |
| subtitle multiple | 1915:8397 | component_set | 519x239 | subtitle multiple.png | 0 | 1 |
| subtitle one | 1919:9121 | component_set | 519x239 | subtitle one.png | 0 | 2 |
| target | 1959:5325 | component_set | 240x520 | target.png | 0 | 8 |
| origin | 1963:5465 | component_set | 240x525 | origin.png | 0 | 4 |
| option | 2107:5935 | component_set | 301x292 | option.png | 0 | 0 |
| menu | 6062:13354 | frame | 375x585 | menu.png | 5 | 0 |
| Dropdown | 2372:8300 | component_set | 406x369 | Dropdown.png | 0 | 2 |
| Setting Preset | 2372:8834 | component_set | 406x412 | Setting Preset.png | 0 | 2 |
| EQ presets | 2372:8487 | component_set | 406x460 | EQ presets.png | 0 | 2 |
| Audio Visualizer | 2372:8639 | component_set | 406x369 | Audio Visualizer.png | 0 | 2 |
| HDR Options | 2372:8733 | component_set | 406x422 | HDR Options.png | 0 | 2 |
| sub filename | 6456:13892 | component_set | 406x422 | sub filename.png | 0 | 2 |
| media | 2404:9167 | component_set | 377x228 | media.png | 0 | 4 |
| playlist | 2459:9352 | component_set | 377x228 | playlist.png | 0 | 2 |
| setting category | 3021:9835 | component_set | 228x140 | setting category.png | 0 | 0 |
| Values | 3176:16556 | component_set | 360x216 | Values-1.png | 0 | 2 |
| EQ | 3178:16769 | component_set | 824x628 | EQ.png | 0 | 2 |
| right-click menu | 6065:13616 | frame | 292x683 | right-click menu.png | 4 | 0 |
| Profiles | 6648:20666 | frame | 651x633 | Profiles.png | 3 | 0 |
| Components | 6841:16196 | text | 4220x847 | Components.png | 0 | 0 |
| Designs | 6841:16197 | text | 2645x847 | Designs.png | 0 | 0 |

## Interactions per screen

Each row is a unique interaction; (xN) = the same element and action repeated N times in that frame. "state a -> b" = the element swaps to another variant of its component (hover or pressed look, toggle, tab switch). Triggers: click, hover (state lasts while hovered), drag, key. Transitions: instant unless stated.

### Player (Player.png, node 187:328)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 12" "Videos" | topbar | click | go to Player (Player-6.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=active] | topbar | click | go to Player (Player-6.png) | smart animate, slow, 208ms |
| Duration [state=Default] "00:25:40" | Controls | hover | node | instant |
| Icon [name=sort, state=default] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=volume, state=default] | Controls | hover | open overlay audio value (audio value.png) (offset -2,-63) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |
| "Rectangle 10" | Controls | hover | open overlay thumbnail (thumbnail.png) (offset -132,-209) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 24" "00:02:10 / 00:25:40" | Controls | click | state of Controls: Property 1: default -> waveform | instant |
| Current Time [state=Default] "00:02:10" | Controls | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: playlists -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: playlists -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: playlists -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: playlists -> network | instant |
| Icon Wrapper [Property 1=Default] (x2) | sidebar | click | state of sidebar: Property 1=playlists | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> audio | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> playback | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> queue | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| playlist [Property 1=unwatched] "Anime to Watch" | sidebar | hover | state of playlist: Property 1: unwatched -> hover-unwatched | instant |
| playlist [Property 1=unwatched] "Cool Songs" | sidebar | hover | state of playlist: Property 1: unwatched -> hover-unwatched | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player (Player-1.png, node 970:3308)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Miniplayer [Property 1=Default] "The Wand_S01E04.mp4 / S01" |  | drag | go to Player (Player-2.png) | smart animate, ease-out, 300ms |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -235,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 28" | Miniplayer | hover | state of Miniplayer: Property 1: Default -> Variant3 | instant |
| Icon Wrapper [Property 1=Default] | Miniplayer | click | state of Miniplayer: Property 1: Default -> Variant2 | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] | Miniplayer | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |

### Player (Player-2.png, node 970:3792)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Miniplayer [Property 1=Default] "The Wand_S01E04.mp4 / S01" |  | drag | go to Player (Player-1.png) | smart animate, ease-out, 300ms |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -235,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 28" | Miniplayer | hover | state of Miniplayer: Property 1: Default -> Variant3 | instant |
| Icon Wrapper [Property 1=Default] | Miniplayer | click | state of Miniplayer: Property 1: Default -> Variant2 | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] | Miniplayer | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |

### Player (Player-3.png, node 970:2703)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Miniplayer [Property 1=Default] "The Wand_S01E04.mp4 / S01" |  | drag | go to Player (Player-4.png) | smart animate, ease-out, 300ms |
| "Frame 43" "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=grid, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -235,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 28" | Miniplayer | hover | state of Miniplayer: Property 1: Default -> Variant3 | instant |
| Icon Wrapper [Property 1=Default] | Miniplayer | click | state of Miniplayer: Property 1: Default -> Variant2 | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] | Miniplayer | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |

### Player (Player-4.png, node 970:4028)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 43" "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| Icon [name=sort, state=default] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=grid, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -235,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |

### Player (Player-5.png, node 6261:15078)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=sort, state=default] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=grid, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -235,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |

### Player (Player-6.png, node 247:445)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 12" "Videos" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "Player" "Videos / VLC Media Player" |  | key F | go to Player - hide UI (Player - hide UI.png) | smart animate, ease-in-and-out, 300ms |
| Duration [state=Default] "00:25:40" | Controls | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player" "Videos / VLC Media Player" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=volume, state=default] | Controls | hover | open overlay audio value (audio value.png) (offset -2,-63) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | topbar | click | open overlay menu (menu.png) (offset -17,38) | instant |
| "Rectangle 10" | Controls | hover | open overlay thumbnail (thumbnail.png) (offset -132,-209) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "Frame 24" "00:02:10 / 00:25:40" | Controls | click | state of Controls: Property 1: default -> waveform | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> audio | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> playback | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> queue | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - Music (Player - Music.png, node 4767:23726)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 12" "My Songs" | topbar | click | go to Player - Music (Player - Music-1.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player - Music (Player - Music-1.png) | smart animate, slow, 208ms |
| "Player - Music" "My Songs / untangle" |  | key F | go to Player - hide UI (Player - hide UI.png) | smart animate, ease-in-and-out, 300ms |
| Duration [state=Default] "00:01:40" | Controls | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=volume, state=default] | Controls | hover | open overlay audio value (audio value.png) (offset 0,-63) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "Frame 24" "00:00:10 / 00:01:40" | Controls | click | state of Controls: Property 1: music -> default | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:00:10" | Controls | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:01:40" | Controls | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: music -> audio | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: music -> playback | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: music -> queue | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x3) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - Music (Player - Music-1.png, node 4778:25123)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 12" "My Songs" | topbar | click | go to Player - Music (Player - Music.png) | smart animate, slow, 208ms |
| "Frame 46" "untangle - juxtopposed" | sidebar | click | go to Player - Music (Player - Music.png) | instant |
| "Frame 47" "moonlight - juxtopposed" | sidebar | click | go to Player - Music (Player - Music.png) | instant |
| "Frame 48" "black bird - juxtopposed" | sidebar | click | go to Player - Music (Player - Music.png) | instant |
| Icon [name=sidebar, state=active] | topbar | click | go to Player - Music (Player - Music.png) | smart animate, slow, 208ms |
| "Player - Music" "My Songs / untangle" |  | key F | go to Player - hide UI (Player - hide UI.png) | smart animate, ease-in-and-out, 300ms |
| Duration [state=Default] "00:01:40" | Controls | hover | node | instant |
| "Player - Music" "My Songs / untangle" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=default] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=volume, state=default] | Controls | hover | open overlay audio value (audio value.png) (offset 0,-63) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: music3 -> music | instant |
| "Frame 24" "00:00:10 / 00:01:40" | Controls | click | state of Controls: Property 1: music -> default | instant |
| "Songs" "Songs" | sidebar | click | state of sidebar: Property 1: music3 -> music2 | instant |
| Current Time [state=Default] "00:00:10" | Controls | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:01:40" | Controls | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: music -> audio | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: music -> playback | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: music -> queue | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: music3 -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: music3 -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: music3 -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: music3 -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x3) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - hide UI (Player - hide UI.png, node 3328:11554)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Player - hide UI" "... / ▶" |  | key F | go to Player (Player-6.png) | smart animate, ease-in-and-out, 300ms |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Duration [state=Default] "00:25:40" | Controls | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - hide UI" "... / ▶" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=volume, state=default] | Controls | hover | open overlay audio value (audio value.png) (offset -2,-63) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |
| "Rectangle 10" | Controls | hover | open overlay thumbnail (thumbnail.png) (offset -132,-209) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "Frame 24" "00:02:10 / 00:25:40" | Controls | click | state of Controls: Property 1: default -> waveform | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> audio | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> playback | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> queue | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - Light (Player - Light.png, node 2425:13624)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Duration [state=Default] "00:25:40" | Controls | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - Light" "S01 / The Wand S01E04" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=volume, state=default] | Controls | hover | open overlay audio value (audio value.png) (offset -2,-63) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |
| "Rectangle 10" | Controls | hover | open overlay thumbnail (thumbnail.png) (offset -132,-209) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "Frame 24" "00:02:10 / 00:25:40" | Controls | click | state of Controls: Property 1: default -> waveform | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> audio | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> playback | instant |
| Icon Wrapper [Property 1=Default] | Controls | click | state of Controls: Property 1: default -> queue | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |

### Player - customize (Player - customize.png, node 2107:5604)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 140" "Cancel" | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| Icon Wrapper [Property 1=Default] | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=backward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=bookmarks, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=chapters, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=favorite, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=forward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=home, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=info, state=default] (x11) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=quit, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=replay, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=settings, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=thumbnail, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "seekbar" "00:02:10 / 00:25:40" |  | drag | go to Player - customize (Player - customize-1.png) | smart animate, ease-in-and-out, 50ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "S01 / The Wand S01E11" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x11) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "10" (x2) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "HDR" | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-1.png, node 2160:6137)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 140" "Cancel" | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| Icon Wrapper [Property 1=Default] | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=backward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=bookmarks, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=chapters, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=favorite, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=forward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=home, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=info, state=default] (x11) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=quit, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=replay, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=settings, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=thumbnail, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "Frame 13" | Controls | drag | go to Player - customize (Player - customize-2.png) | smart animate, ease-in-and-out, 50ms |
| "seekbar" "00:02:10 / 00:25:40" |  | drag | go to Player - customize (Player - customize.png) | smart animate, ease-in-and-out, 50ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "S01 / The Wand S01E11" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x11) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "10" (x2) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "HDR" | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-2.png, node 2160:6564)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 140" "Cancel" | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| Icon Wrapper [Property 1=Default] | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=backward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=bookmarks, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=chapters, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=favorite, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=forward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=home, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=info, state=default] (x11) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=quit, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=replay, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=settings, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=thumbnail, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "Frame 229" "The Wand S01E11" | topbar | drag | go to Player - customize (Player - customize-3.png) | smart animate, ease-in-and-out, 50ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "00:02:10 / 00:25:40" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x11) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "10" (x2) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "HDR" | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-3.png, node 2160:7005)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 140" "Cancel" | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| Icon Wrapper [Property 1=Default] | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=backward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=bookmarks, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=chapters, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=favorite, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=forward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=home, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=info, state=default] (x11) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=quit, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=replay, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=settings, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=thumbnail, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "Frame 11" "S01" | topbar | drag | go to Player - customize (Player - customize-4.png) | smart animate, ease-in-and-out, 50ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "00:02:10 / 00:25:40" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x11) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "10" (x2) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "HDR" | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-4.png, node 2160:7437)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 140" "Cancel" | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| Icon Wrapper [Property 1=Default] | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=backward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=bookmarks, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=chapters, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=favorite, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=forward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=home, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=info, state=default] (x11) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=quit, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=replay, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=settings, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=thumbnail, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=fullscreen, state=default] | topbar | drag | go to Player - customize (Player - customize-5.png) | smart animate, ease-in-and-out, 50ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "00:02:10 / 00:25:40" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x11) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "10" (x2) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "HDR" | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-5.png, node 2160:7869)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 140" "Cancel" | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| Icon Wrapper [Property 1=Default] | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=backward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=bookmarks, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=chapters, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=favorite, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=forward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=home, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=info, state=default] (x11) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=quit, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=replay, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=settings, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=thumbnail, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "Frame 250" "Favorite" | Add Subtitles to Playlist/Folder | drag | go to Player - customize (Player - customize-6.png) | smart animate, ease-in-and-out, 600ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "00:02:10 / 00:25:40" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x11) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "10" (x2) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "HDR" | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-6.png, node 6587:19923)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 140" "Cancel" | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| Icon Wrapper [Property 1=Default] | Add Subtitles to Playlist/Folder | click | go to Player (Player-6.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=backward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=bookmarks, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=chapters, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=favorite, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=forward-15-sec, state=default] "15" (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=home, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=info, state=default] (x11) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=quit, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=replay, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=settings, state=default] (x2) | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| Icon [name=thumbnail, state=default] | Add Subtitles to Playlist/Folder | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "Frame 141" "Save" | Add Subtitles to Playlist/Folder | click | go to Player - customize (Player - customize-7.png) | instant |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "00:02:10 / 00:25:40" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x11) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "10" (x2) | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] "HDR" | Add Subtitles to Playlist/Folder | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-7.png, node 2160:8301)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| Icon [name=favorite, state=default] |  | click | go to Player (Player.png) | smart animate, slow, 208ms |
| "Frame 12" "S01" | topbar | click | go to Player - customize (Player - customize-8.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=default] | topbar | click | go to Player - customize (Player - customize-8.png) | smart animate, slow, 208ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "00:02:10 / 00:25:40" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Player - customize (Player - customize-8.png, node 2160:8732)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar | click | go back | instant |
| Icon [name=open, state=default] | sidebar | click | go to Player (Player-3.png) | instant |
| "Frame 12" "S01" | topbar | click | go to Player - customize (Player - customize-7.png) | smart animate, slow, 208ms |
| Icon [name=sidebar, state=active] | topbar | click | go to Player - customize (Player - customize-7.png) | smart animate, slow, 208ms |
| Duration [state=Default] "00:25:40" | seekbar | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | click | node | instant |
| "Player - customize" "00:02:10 / 00:25:40" |  | key V | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| Icon [name=sort, state=active] | sidebar | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | seekbar | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | seekbar | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Settings - global (Settings - global.png, node 999:5047)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - global (Settings - global-1.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "2" "Light" | Values | click | state of Values: option: 1 -> 2 | instant |
| "3" "System" | Values | click | state of Values: option: 1 -> 3 | instant |
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x3) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" |  | click | state of Toggle: Value: on -> off | instant |

### Settings - global (Settings - global-1.png, node 3046:9282)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "2" "Light" | Values | click | state of Values: option: 1 -> 2 | instant |
| "3" "System" | Values | click | state of Values: option: 1 -> 3 | instant |
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x6) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x2) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - interface (Settings - interface.png, node 3046:10057)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x3) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x8) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - interface (Settings - interface-1.png, node 3062:11379)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - interface (Settings - interface.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x4) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x11) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - privacy (Settings - privacy.png, node 3062:11911)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x2) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x2) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - playback (Settings - playback.png, node 3062:12552)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - playback (Settings - playback-1.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=on] "ON" (x7) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - playback (Settings - playback-1.png, node 3072:13408)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=on] "ON" (x7) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - video (Settings - video.png, node 3073:14187)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - video (Settings - video-1.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x2) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x5) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - video (Settings - video-1.png, node 3073:15375)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x2) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x5) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - audio (Settings - audio.png, node 3073:15879)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - audio (Settings - audio-1.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "2" "Always starts at: / 200%" | Values | click | state of Values: Property 1: Default -> Variant2 | instant |
| Audio Visualizer [state=default] "Disabled" |  | click | state of Audio Visualizer: state: default -> open | instant |
| EQ [Property 1=Default] "Open Equalizer" |  | click | state of EQ: Property 1: Default -> Variant2 | instant |
| EQ presets [state=default] "None" |  | click | state of EQ presets: state: default -> open | instant |
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x9) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" |  | click | state of Toggle: Value: on -> off | instant |

### Settings - audio (Settings - audio-1.png, node 3180:17398)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "2" "Always starts at: / 200%" | Values | click | state of Values: Property 1: Default -> Variant2 | instant |
| "Frame 275" "Close Equalizer" | EQ | click | state of EQ: Property 1: Variant2 -> Default | instant |
| Audio Visualizer [state=default] "Disabled" |  | click | state of Audio Visualizer: state: default -> open | instant |
| EQ presets [state=default] "None" |  | click | state of EQ presets: state: default -> open | instant |
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x10) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" |  | click | state of Toggle: Value: on -> off | instant |

### Settings - subtitles (Settings - subtitles.png, node 3180:17989)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| "Frame 265" "Advanced Options" |  | click | swap overlay with Settings - subtitles (Settings - subtitles-1.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 95" "Pixels" | Values | click | state of Values: option: 1 -> 2 | instant |
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x5) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - subtitles (Settings - subtitles-1.png, node 6536:13908)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Controls" |  | click | swap overlay with Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 95" "Pixels" | Values | click | state of Values: option: 1 -> 2 | instant |
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x2) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" (x5) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - controls (Settings - controls.png, node 6536:14482)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x3) |  | click | state of Toggle: Value: off -> on | instant |

### Settings - library (Settings - library.png, node 6542:15251)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Controls" |  | click | go to Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" (x4) |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" |  | click | state of Toggle: Value: on -> off | instant |

### Settings - network (Settings - network.png, node 6543:15649)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=streaming, state=active] | setting category | click | change_to -> <missing 87:1020> | instant |
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Controls" |  | click | go to Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=on] "ON" |  | click | state of Toggle: Value: on -> off | instant |

### Settings - performance (Settings - performance.png, node 6571:15958)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Controls" |  | click | go to Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Library" |  | click | swap overlay with Settings - library (Settings - library.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=off] "OFF" |  | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" |  | click | state of Toggle: Value: on -> off | instant |

### Settings - recording (Settings - recording.png, node 6571:16429)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Controls" |  | click | go to Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "Extensions" |  | click | swap overlay with Settings - extensions (Settings - extensions.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=on] "ON" (x6) |  | click | state of Toggle: Value: on -> off | instant |

### Settings - extensions (Settings - extensions.png, node 6575:17137)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |
| setting category [selected=no] "Controls" |  | click | go to Settings - controls (Settings - controls.png) | instant |
| setting category [selected=no] "Audio" |  | click | swap overlay with Settings - audio (Settings - audio.png) | instant |
| setting category [selected=no] "General" |  | click | swap overlay with Settings - global (Settings - global.png) | instant |
| setting category [selected=no] "Interface" |  | click | swap overlay with Settings - interface (Settings - interface-1.png) | instant |
| setting category [selected=no] "Network" |  | click | swap overlay with Settings - network (Settings - network.png) | instant |
| setting category [selected=no] "Performance" |  | click | swap overlay with Settings - performance (Settings - performance.png) | instant |
| setting category [selected=no] "Playback" |  | click | swap overlay with Settings - playback (Settings - playback.png) | instant |
| setting category [selected=no] "Privacy" |  | click | swap overlay with Settings - privacy (Settings - privacy.png) | instant |
| setting category [selected=no] "Recording" |  | click | swap overlay with Settings - recording (Settings - recording.png) | instant |
| setting category [selected=no] "Subtitles" |  | click | swap overlay with Settings - subtitles (Settings - subtitles.png) | instant |
| setting category [selected=no] "Video" |  | click | swap overlay with Settings - video (Settings - video.png) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Toggle [Value=on] "ON" |  | click | state of Toggle: Value: on -> off | instant |

### Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png, node 1911:7545)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 141" "Save" |  | click | close overlay | instant |
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E01.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E02.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E03.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E04.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E05.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E06.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E07.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E08.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E09.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E10.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E11.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E12.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E13.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E14.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E15.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| target [state=to this folder] "To This Folder" |  | click | state of target: state: to this folder -> dropdown 1 | instant |

### Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-1.png, node 3336:11929)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 141" "Save" |  | click | close overlay | instant |
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E01.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E02.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E03.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E04.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E05.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E06.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E07.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E08.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E09.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E10.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E11.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E12.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E13.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E14.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| subtitle multiple [Property 1=Default] "The_Wand_S01E15.srt" |  | hover | state of subtitle multiple: Property 1: Default -> hover | instant |
| target [state=to this folder] "To This Folder" |  | click | state of target: state: to this folder -> dropdown 1 | instant |

### Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-2.png, node 1919:8707)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 141" "Save" |  | click | close overlay | instant |
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| origin [state=from computer] "From Computer" |  | click | state of origin: state: from computer -> dropdown 1 | instant |
| subtitle one [Property 1=Default] "The_Wand_S01E01_Dutch.srt" |  | click | state of subtitle one: Property 1: Default -> selected | instant |
| subtitle one [Property 1=Default] "The_Wand_S01E01_French.srt" |  | click | state of subtitle one: Property 1: Default -> selected | instant |
| subtitle one [Property 1=Default] "The_Wand_S01E01_German.srt" |  | click | state of subtitle one: Property 1: Default -> selected | instant |
| subtitle one [Property 1=Default] "The_Wand_S01E01_Japanese.srt" |  | click | state of subtitle one: Property 1: Default -> selected | instant |
| subtitle one [Property 1=selected] "The_Wand_S01E01_English.srt" |  | click | state of subtitle one: Property 1: selected -> Default | instant |
| subtitle one [Property 1=selected] "The_Wand_S01E01_Spanish.srt" |  | click | state of subtitle one: Property 1: selected -> Default | instant |
| target [state=to this file] "To This File" |  | click | state of target: state: to this file -> dropdown 2 | instant |

### Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-3.png, node 1919:9278)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 141" "Save" |  | click | close overlay | instant |
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| origin [state=from opensub] "From OpenSubtitles" |  | click | state of origin: state: from opensub -> dropdown 2 | instant |
| subtitle one [Property 1=Default] "The_Wand_S01E01_EN.srt" |  | click | state of subtitle one: Property 1: Default -> selected | instant |
| subtitle one [Property 1=selected] "The_Wand_S01E01_English.srt" |  | click | state of subtitle one: Property 1: selected -> Default | instant |
| target [state=to this file] "To This File" |  | click | state of target: state: to this file -> dropdown 2 | instant |

### Keyboard Shortcuts (Keyboard Shortcuts.png, node 2437:14832)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |

### Open network stream (Open network stream.png, node 6216:13614)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |

### new playlist (new playlist.png, node 6259:14954)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | click | close overlay | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon Wrapper [Property 1=Default] |  | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |

### Onboarding (Onboarding.png, node 1899:3055)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 140" "Next" |  | click | go to Onboarding (Onboarding-1.png) | instant |

### Onboarding (Onboarding-1.png, node 1902:3670)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| "Frame 140" "Back" |  | click | go to Onboarding (Onboarding-1.png) | instant |
| "Frame 141" "Next" |  | click | go to Onboarding (Onboarding-2.png) | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=volume, state=default] | Controls < Player | hover | open overlay audio value (audio value.png) (offset -2,-63) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |
| "Rectangle 10" | Controls < Player | hover | open overlay thumbnail (thumbnail.png) (offset -132,-209) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "Frame 24" "00:02:10 / 00:25:40" | Controls < Player | click | state of Controls: Property 1: default -> waveform | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | Controls < Player | click | state of Controls: Property 1: default -> audio | instant |
| Icon Wrapper [Property 1=Default] | Controls < Player | click | state of Controls: Property 1: default -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | Controls < Player | click | state of Controls: Property 1: default -> playback | instant |
| Icon Wrapper [Property 1=Default] | Controls < Player | click | state of Controls: Property 1: default -> queue | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-2.png, node 1902:6770)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "Frame 140" "Back" |  | click | go to Onboarding (Onboarding-1.png) | instant |

### Onboarding (Onboarding-3.png, node 1902:4020)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-4.png, node 1902:4325)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-5.png, node 1902:4634)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-6.png, node 1902:4940)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-7.png, node 1902:5245)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-8.png, node 1902:5550)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-9.png, node 1902:6160)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### Onboarding (Onboarding-10.png, node 1902:6465)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| Icon [name=arrow, state=default] | sidebar < Player | click | go back | instant |
| Icon [name=open, state=default] | sidebar < Player | click | go to Player (Player-3.png) | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | hover | node | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | click | node | instant |
| Icon [name=sort, state=active] | sidebar < Player | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=list, state=default] | sidebar < Player | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] | sidebar < Player | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |

State changes on this screen:

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "..." "..." | sidebar < Player | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "The Wand" "The Wand" | sidebar < Player | click | state of sidebar: Property 1: Default -> videos3 | instant |
| Current Time [state=Default] "00:02:10" | Controls < Player | hover | state of Current Time: state: Default -> hover | instant |
| Duration [state=Default] "00:25:40" | Controls < Player | click | state of Duration: state: Default -> click | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | sidebar < Player | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | sidebar < Player | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] (x4) | Controls < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| Icon Wrapper [Property 1=Default] (x7) | sidebar < Player | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | sidebar < Player | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | sidebar < Player | hover | state of media: Property 1: watched -> hover-watched | instant |
| play [type=play] | Controls < Player | click | state of play: type: play -> pause | instant |
| volume [Property 1=50%] | Controls < Player | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

### View Options (View Options.png, node 858:3290)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| option [Property 1=selected] "List View" |  | click | go to Player (Player-1.png) | instant |
| option [Property 1=Default] "Grid View" |  | click | go to Player (Player-3.png) | instant |

### menu (menu.png, node 6062:13354)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "option" "About VLC / Shift + F1" |  | click | go to Player - customize (Player - customize.png) | instant |
| "option" "Customize Player" |  | click | go to Player - customize (Player - customize.png) | instant |
| "option" "Keyboard Shortcuts" |  | click | open overlay Keyboard Shortcuts (Keyboard Shortcuts.png) | instant |
| "option" "Settings / Ctrl + P" |  | click | open overlay Settings - global (Settings - global.png) | instant |
| "option" "Profile (Movies)" |  | click | swap overlay with Profiles (Profiles.png) | instant |

### right-click menu (right-click menu.png, node 6065:13616)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "option" "More Settings" |  | click | go to Player - customize (Player - customize.png) | instant |
| "option" "Open Media" |  | click | go to Player - customize (Player - customize.png) | instant |
| "option" "Quit VLC / Ctrl + Q" |  | click | go to Player - customize (Player - customize.png) | instant |
| "option" "Playlist" |  | click | open overlay Keyboard Shortcuts (Keyboard Shortcuts.png) | instant |

### Profiles (Profiles.png, node 6648:20666)

| Element | Inside | Trigger | Result | Transition |
|---|---|---|---|---|
| "option" "Customize Player" | menu | click | go to Player - customize (Player - customize.png) | instant |
| "option" "Keyboard Shortcuts" | menu | click | open overlay Keyboard Shortcuts (Keyboard Shortcuts.png) | instant |
| "option" "Settings / Ctrl + P" | menu | click | open overlay Settings - global (Settings - global.png) | instant |

## Component state machines (interactions defined inside reusable components)

These apply everywhere the component is used.

### Audio - Compressor Settings

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 75" "Collapse Settings" | click | state of Audio - Compressor Settings: Property 1: expanded -> collapsed | instant |
| Audio - Compressor Settings [Property 1=collapsed] "Expand Settings" (x2) | click | state of Audio - Compressor Settings: Property 1: collapsed -> expanded | instant |

### Audio - Equalizer

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 75" "Collapse Settings" | click | state of Audio - Equalizer: Property 1: expanded -> collapsed | instant |
| Audio - Equalizer [Property 1=collapsed] "Expand Settings" (x2) | click | state of Audio - Equalizer: Property 1: collapsed -> expanded | instant |

### Audio - Spatializer Settings

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 75" "Collapse Settings" | click | state of Audio - Spatializer Settings: Property 1: expanded -> collapsed | instant |
| Audio - Spatializer Settings [Property 1=collapsed] "Expand Settings" (x2) | click | state of Audio - Spatializer Settings: Property 1: collapsed -> expanded | instant |

### Audio - Stereo Widener

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 75" "Collapse Settings" | click | state of Audio - Stereo Widener: Property 1: expanded -> collapsed | instant |
| Audio - Stereo Widener [Property 1=collapsed] "Expand Settings" (x2) | click | state of Audio - Stereo Widener: Property 1: collapsed -> expanded | instant |

### Audio Visualizer

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Audio Visualizer [state=default] "Disabled" (x2) | click | state of Audio Visualizer: state: default -> open | instant |

### Button

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Button [Property 1=Default] "Open Advanced Settings" | click | open overlay Settings - video (Settings - video.png) | instant |
| Button [Property 1=Default] "Open Advanced Settings" | click | open overlay Settings - audio (Settings - audio.png) | instant |
| Button [Property 1=Default] "Open Advanced Settings" | click | open overlay Settings - subtitles (Settings - subtitles.png) | instant |
| Button [Property 1=Default] "Show Preferences" | click | state of Controls: Property 1: subtitles -> subtitle settings | instant |
| Button [Property 1=Default] "Show Preferences" | click | state of Controls: Property 1: audio -> audio settings | instant |
| Button [Property 1=Default] "Show Preferences" | click | state of Controls: Property 1: video -> video settings | instant |
| Button [Property 1=Default] "Open Advanced Settings" (x3) | hover | state of Button: Property 1: Default -> Variant2 | instant |
| Button [Property 1=Default] "Show Advanced Settings" | hover | state of Button: Property 1: Default -> Variant2 | instant |
| Button [Property 1=Default] "Show Preferences" (x3) | hover | state of Button: Property 1: Default -> Variant2 | instant |
| Button [Property 1=Default] "Test" | hover | state of Button: Property 1: Default -> Variant2 | instant |

### Controls

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "2" "Horizontal" | click | state of Values: option: 1 -> 2 | instant |
| "3" "Vertical" | click | state of Values: option: 1 -> 3 | instant |
| "Frame 24" "00:02:10 / 00:25:40" | click | state of Controls: Property 1: default -> waveform | instant |
| "Frame 24" "00:02:10 / 00:25:40" | click | state of Controls: Property 1: Variant10 -> waveform | instant |
| "Frame 24" "00:02:10 / 00:25:40" | click | state of Controls: Property 1: waveform -> default | instant |
| "Frame 24" "00:02:10 / 00:25:40" | click | state of Controls: Property 1: music -> default | instant |
| "Frame 57" "Queue" | click | state of Controls: Property 1: bookmarks -> queue | instant |
| "Frame 57" "Queue" | click | state of Controls: Property 1: chapters -> queue | instant |
| "Frame 57" "Subtitles" | click | state of Controls: Property 1: playback -> subtitle settings | instant |
| "Frame 57" "Subtitles" | click | state of Controls: Property 1: audio -> subtitles | instant |
| "Frame 57" "Subtitles" | click | state of Controls: Property 1: video -> subtitles | instant |
| "Frame 57" "Subtitles" | click | state of Controls: Property 1: video settings -> subtitle settings | instant |
| "Frame 57" "Subtitles" | click | state of Controls: Property 1: audio settings -> subtitle settings | instant |
| "Frame 58" "Audio" | click | state of Controls: Property 1: subtitles -> audio | instant |
| "Frame 58" "Audio" | click | state of Controls: Property 1: playback -> audio settings | instant |
| "Frame 58" "Audio" | click | state of Controls: Property 1: video -> audio | instant |
| "Frame 58" "Audio" | click | state of Controls: Property 1: video settings -> audio settings | instant |
| "Frame 58" "Audio" | click | state of Controls: Property 1: subtitle settings -> audio settings | instant |
| "Frame 58" "Chapters" | click | state of Controls: Property 1: queue -> chapters | instant |
| "Frame 58" "Chapters" | click | state of Controls: Property 1: bookmarks -> chapters | instant |
| "Frame 59" "Bookmarks" | click | state of Controls: Property 1: queue -> bookmarks | instant |
| "Frame 59" "Bookmarks" | click | state of Controls: Property 1: chapters -> bookmarks | instant |
| "Frame 59" "Playback" | click | state of Controls: Property 1: playback -> video settings | instant |
| "Frame 59" "Playback" | click | state of Controls: Property 1: subtitle settings -> playback | instant |
| "Frame 59" "Video" | click | state of Controls: Property 1: subtitles -> video | instant |
| "Frame 59" "Video" | click | state of Controls: Property 1: audio -> video | instant |
| "Frame 59" "Video" | click | state of Controls: Property 1: audio settings -> video settings | instant |
| "Frame 60" "Playback" | click | state of Controls: Property 1: video settings -> playback | instant |
| "Frame 60" "Playback" | click | state of Controls: Property 1: audio settings -> playback | instant |
| "Frame 60" "Video" | click | state of Controls: Property 1: playback -> video settings | instant |
| "Frame 60" "Video" | click | state of Controls: Property 1: subtitle settings -> video settings | instant |
| "Frame 69" "Show Subtitle Timeline on Seekbar / OFF" | click | state of Controls: Property 1: playback -> sub timeline | instant |
| "Frame 95" "Pixels" | click | state of Values: option: 1 -> 2 | instant |
| "Rectangle 10" (x9) | hover | open overlay thumbnail (thumbnail.png) (offset -132,-209) | instant |
| "Rectangle 10" | hover | open overlay thumbnail (thumbnail.png) (offset -128,-209) | instant |

### Current Time

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Current Time [state=hover] "00:02:10" | click | state of Current Time: state: hover -> click | instant |
| Current Time [state=Default] "00:01:50*" | hover | state of Current Time: state: Default -> hover | instant |
| Current Time [state=Default] "00:02:10" (x15) | hover | state of Current Time: state: Default -> hover | instant |
| Current Time [state=click] "00:02:10" | key Enter | state of Current Time: state: click -> Default | instant |

### Dropdown

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Dropdown [state=default] "Dropdown" | click | state of Dropdown: state: default -> open | instant |

### Duration

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Duration [state=Default] "00:02:40*" | click | state of Duration: state: Default -> click | instant |
| Duration [state=Default] "00:25:40" (x15) | click | state of Duration: state: Default -> click | instant |
| Duration [state=click] "-00:23:30" | click | state of Duration: state: click -> Default | instant |
| Duration [state=Default] "00:02:40*" | hover | node | instant |
| Duration [state=Default] "00:25:40" (x15) | hover | node | instant |

### EQ

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 275" "Close Equalizer" | click | state of EQ: Property 1: Variant2 -> Default | instant |
| EQ [Property 1=Default] "Open Equalizer" | click | state of EQ: Property 1: Default -> Variant2 | instant |

### EQ presets

| Element | Trigger | Result | Transition |
|---|---|---|---|
| EQ presets [state=default] "None" (x2) | click | state of EQ presets: state: default -> open | instant |

### HDR Options

| Element | Trigger | Result | Transition |
|---|---|---|---|
| HDR Options [state=default] "Auto" | click | state of HDR Options: state: default -> open | instant |

### Icon

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Icon [name=add, state=default] | click | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-2.png) | instant |
| Icon [name=arrow, state=default] (x10) | click | go back | instant |
| Icon [name=close, state=default] (x3) | click | go to Player (Player-6.png) | instant |
| Icon [name=edit, state=default] | click | open overlay Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-2.png) | instant |
| Icon [name=link, state=active] | click | state of Icon: state: active -> default | instant |
| Icon [name=link, state=default] (x3) | click | state of Icon: state: default -> active | instant |
| Icon [name=link, state=default] | click | state of Icon: two-tone: yes -> no | instant |
| Icon [name=list, state=default] (x10) | click | open overlay View Options (View Options.png) (offset -11,30) | instant |
| Icon [name=more, state=default] (x10) | click | open overlay folder context menu (folder context menu.png) (offset -11,30) | instant |
| Icon [name=more, state=default] (x2) | click | open overlay file context menu (file context menu.png) (offset -16,34) | instant |
| Icon [name=more, state=default] | click | open overlay playlist context menu (playlist context menu.png) (offset -16,34) | instant |
| Icon [name=open, state=default] (x10) | click | go to Player (Player-3.png) | instant |
| Icon [name=open, state=default] (x3) | click | go to Player (Player-6.png) | instant |
| Icon [name=sort, state=active] | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=sort, state=default] (x9) | click | open overlay Sorting Options (Sorting Options.png) (offset -11,30) | instant |
| Icon [name=streaming, state=active] (x2) | click | change_to -> <missing 87:1020> | instant |
| Icon [name=volume, state=default] | hover | open overlay audio value (audio value.png) (offset -2,-63) | instant |
| Icon [name=volume, state=default] (x13) | hover | open overlay audio value (audio value.png) (offset 0,-63) | instant |
| Icon [name=volume, state=default] | hover | open overlay audio value (audio value.png) (offset 2,-63) | instant |

### Icon Wrapper

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: default -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: default -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: default -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: default -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: Variant10 -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: Variant10 -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: Variant10 -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: Variant10 -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: waveform -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: waveform -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: waveform -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: waveform -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: music -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: music -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: music -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: queue -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: queue -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: queue -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: queue -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: bookmarks -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: bookmarks -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: bookmarks -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: bookmarks -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: chapters -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: chapters -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: chapters -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: chapters -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitles -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitles -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitles -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitles -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: playback -> audio | instant |
| Icon Wrapper [Property 1=Default] (x2) | click | state of Controls: Property 1: playback -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: playback -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: sub timeline -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: sub timeline -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: sub timeline -> video settings | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: sub timeline -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video -> playback | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video settings -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video settings -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video settings -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: video settings -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio settings -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio settings -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio settings -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: audio settings -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitle settings -> audio | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitle settings -> subtitles | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitle settings -> default | instant |
| Icon Wrapper [Property 1=Default] | click | state of Controls: Property 1: subtitle settings -> queue | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: Default -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: Default -> videos | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: Default -> music | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: Default -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: Default -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: home -> videos | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: home -> music | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: home -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: home -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos -> music | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: videos -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos2 -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos2 -> music | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos2 -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: videos2 -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos3 -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos3 -> music | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: videos3 -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: videos3 -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music -> videos | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: music -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music2 -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music2 -> videos | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music2 -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: music2 -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music3 -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music3 -> videos | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: music3 -> network | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: music3 -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: network -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: network -> videos | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: network -> music | instant |
| Icon Wrapper [Property 1=Default] (x3) | click | state of sidebar: Property 1: network -> playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: playlists -> home | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: playlists -> videos | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: playlists -> music | instant |
| Icon Wrapper [Property 1=Default] | click | state of sidebar: Property 1: playlists -> network | instant |
| Icon Wrapper [Property 1=Default] (x2) | click | state of sidebar: Property 1=playlists | instant |
| Icon Wrapper [Property 1=Default] | click | state of Miniplayer: Property 1: Default -> Variant2 | instant |
| Icon Wrapper [Property 1=Default] | click | state of Miniplayer: Property 1: Variant2 -> Default | instant |
| Icon Wrapper [Property 1=hover] | click | change_to -> <missing 178:139> | instant |
| Icon Wrapper [Property 1=Default] (x137) | hover | state of Icon Wrapper: Property 1: Default -> hover | instant |

### Miniplayer

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 28" | hover | state of Miniplayer: Property 1: Default -> Variant3 | instant |
| "Frame 28" | hover | state of Miniplayer: Property 1: Variant2 -> Variant4 | instant |

### Setting Preset

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Setting Preset [state=default] "Default Preset" (x4) | click | state of Setting Preset: state: default -> open | instant |

### Toggle

| Element | Trigger | Result | Transition |
|---|---|---|---|
| Toggle [Value=off] "OFF" (x16) | click | state of Toggle: Value: off -> on | instant |
| Toggle [Value=on] "ON" | click | state of Toggle: Value: on -> off | instant |

### Values

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "1" "1" | click | state of Values: option: 2 -> 1 | instant |
| "1" "1" | click | state of Values: option: 3 -> 1 | instant |
| "1" "Remember last volume" | click | state of Values: Property 1: Variant2 -> Default | instant |
| "2" "2" | click | state of Values: option: 1 -> 2 | instant |
| "2" "2" | click | state of Values: option: 3 -> 2 | instant |
| "2" "Always starts at: / 200%" | click | state of Values: Property 1: Default -> Variant2 | instant |
| "3" "3" | click | state of Values: option: 2 -> 3 | instant |
| "3" "3" | click | state of Values: option: 1 -> 3 | instant |
| "Frame 94" "Relative" | click | state of Values: option: 2 -> 1 | instant |
| "Frame 95" "Pixels" | click | state of Values: option: 1 -> 2 | instant |

### Video - Colors

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 75" "Collapse Settings" | click | state of Video - Colors: Property 1: expanded -> collapsed | instant |
| Video - Colors [Property 1=collapsed] "Expand Settings" (x2) | click | state of Video - Colors: Property 1: collapsed -> expanded | instant |

### Video - Crop

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 75" "Collapse Settings" | click | state of Video - Crop: Property 1: expanded -> collapsed | instant |
| Video - Crop [Property 1=collapsed] "Expand Settings" (x2) | click | state of Video - Crop: Property 1: collapsed -> expanded | instant |

### Video - Essential

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "Frame 75" "Collapse Settings" | click | state of Video - Essential: Property 1: expanded -> collapsed | instant |
| Video - Essential [Property 1=collapsed] "Expand Settings" (x2) | click | state of Video - Essential: Property 1: collapsed -> expanded | instant |

### media

| Element | Trigger | Result | Transition |
|---|---|---|---|
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | click | node | instant |
| media [Property 1=unwatched] "The Wand_S01E01.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E05.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E06.mp4" (x2) | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E07.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E08.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E09.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E10.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E11.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E12.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E13mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E14.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=unwatched] "The_Wand_S01E15.mp4" | hover | state of media: Property 1: unwatched -> hover-unwatched | instant |
| media [Property 1=watched] "The Wand_S01E01.mp4" | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E01.mp4" | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E02.mp4" | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E03.mp4" | hover | state of media: Property 1: watched -> hover-watched | instant |
| media [Property 1=watched] "The_Wand_S01E04.mp4" | hover | state of media: Property 1: watched -> hover-watched | instant |

### option

| Element | Trigger | Result | Transition |
|---|---|---|---|
| option [Property 1=Default] "Off" | click | state of sub filename: state: open -> default | instant |
| option [Property 1=selected] "Auto" | click | state of HDR Options: state: open -> default | instant |
| option [Property 1=selected] "Default Preset" | click | state of Setting Preset: state: open -> default | instant |
| option [Property 1=selected] "Disabled" | click | state of Audio Visualizer: state: open -> default | instant |
| option [Property 1=selected] "Dropdown" | click | state of Dropdown: state: open -> default | instant |
| option [Property 1=selected] "None" | click | state of EQ presets: state: open -> default | instant |

### origin

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "option" "From Computer" | click | swap overlay with Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-2.png) | instant |
| "option" "From OpenSubtitles" | click | swap overlay with Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-3.png) | instant |
| origin [state=from computer] "From Computer" | click | state of origin: state: from computer -> dropdown 1 | instant |
| origin [state=from opensub] "From OpenSubtitles" | click | state of origin: state: from opensub -> dropdown 2 | instant |

### play

| Element | Trigger | Result | Transition |
|---|---|---|---|
| play [type=pause] | click | state of play: type: pause -> play | instant |
| play [type=play] (x16) | click | state of play: type: play -> pause | instant |

### playlist

| Element | Trigger | Result | Transition |
|---|---|---|---|
| playlist [Property 1=unwatched] "Anime to Watch" | hover | state of playlist: Property 1: unwatched -> hover-unwatched | instant |
| playlist [Property 1=unwatched] "Cool Playlist" | hover | state of playlist: Property 1: unwatched -> hover-unwatched | instant |
| playlist [Property 1=unwatched] "Cool Songs" | hover | state of playlist: Property 1: unwatched -> hover-unwatched | instant |

### sidebar

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "..." "..." | click | state of sidebar: Property 1: Default -> videos2 | instant |
| "..." "..." | click | state of sidebar: Property 1: videos3 -> videos | instant |
| "..." "..." | click | state of sidebar: Property 1: music3 -> music | instant |
| "Frame 44" "S01" | click | state of sidebar: Property 1: videos3 -> Default | instant |
| "Frame 44" "Shows" | click | state of sidebar: Property 1: videos -> videos2 | instant |
| "Frame 44" "Songs" | click | state of sidebar: Property 1: music -> music2 | instant |
| "Frame 44" "The Wand" | click | state of sidebar: Property 1: videos2 -> videos3 | instant |
| "Frame 46" "My Songs" | click | state of sidebar: Property 1: music2 -> music3 | instant |
| "Frame 46" "untangle - juxtopposed" (x2) | click | go to Player - Music (Player - Music.png) | instant |
| "Frame 47" "moonlight - juxtopposed" (x2) | click | go to Player - Music (Player - Music.png) | instant |
| "Frame 48" "black bird - juxtopposed" (x2) | click | go to Player - Music (Player - Music.png) | instant |
| "Home" "Home" | click | state of sidebar: Property 1: home -> videos2 | instant |
| "Music" "Music" | click | state of sidebar: Property 1: music2 -> music | instant |
| "Shows" "Shows" | click | state of sidebar: Property 1: videos3 -> videos2 | instant |
| "Songs" "Songs" | click | state of sidebar: Property 1: music3 -> music2 | instant |
| "The Wand" "The Wand" | click | state of sidebar: Property 1: Default -> videos3 | instant |
| "Videos" "Videos" | click | state of sidebar: Property 1: videos2 -> videos | instant |

### sub filename

| Element | Trigger | Result | Transition |
|---|---|---|---|
| sub filename [state=default] "Title with extra characters" | click | state of sub filename: state: default -> open | instant |

### subtitle multiple

| Element | Trigger | Result | Transition |
|---|---|---|---|
| subtitle multiple [Property 1=Default] "The_Wand_S01E01.srt" | hover | state of subtitle multiple: Property 1: Default -> hover | instant |

### subtitle one

| Element | Trigger | Result | Transition |
|---|---|---|---|
| subtitle one [Property 1=Default] "The_Wand_S01E01.srt" | click | state of subtitle one: Property 1: Default -> selected | instant |
| subtitle one [Property 1=selected] "The_Wand_S01E01.srt" | click | state of subtitle one: Property 1: selected -> Default | instant |

### target

| Element | Trigger | Result | Transition |
|---|---|---|---|
| "option" "To This File" | click | swap overlay with Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-2.png) | instant |
| "option" "To This File" | click | state of target: state: dropdown 2 -> to this file | instant |
| "option" "To This Folder" | click | state of target: state: dropdown 1 -> to this folder | instant |
| "option" "To This Folder" | click | swap overlay with Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| "option" "To This Playlist" | click | swap overlay with Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder-2.png) | instant |
| "option" "To This Playlist" | click | swap overlay with Add Subtitles to Playlist/Folder (Add Subtitles to Playlist/Folder.png) | instant |
| target [state=to this file] "To This File" | click | state of target: state: to this file -> dropdown 2 | instant |
| target [state=to this folder] "To This Folder" | click | state of target: state: to this folder -> dropdown 1 | instant |

### volume

| Element | Trigger | Result | Transition |
|---|---|---|---|
| volume [Property 1=200%] | drag | state of volume: Property 1: 200% -> 50% | smart animate, ease-in-and-out, 300ms |
| volume [Property 1=50%] (x16) | drag | state of volume: Property 1: 50% -> 200% | smart animate, ease-in-and-out, 300ms |

## Appendix: layout trees of the main components

Raw from the JSON. Per line: type (FRAM/INST/COMP/TEXT/RECT/VECT), layer name, size, AL = auto-layout direction (H/V) with gap and padding (top,right,bottom,left), r = corner radius, fill / stroke with the color style name, fx = effect, font = family weight size line-height letter-spacing. Repeated siblings are collapsed ("... N more").

### Control bar (Controls default/music/waveform/sub timeline), volume, icon button, play, current time, thumbnail, volume tooltip

```
COMP "Property 1=default" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 25" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 24" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 11" 98x24 r=4.0 fill=Dark/BG/Accent Bright=#371F06
      RECT "Rectangle 10" 8x24 r=4.0 fill=Dark/Accent/Main=#D37918
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings

COMP "Property 1=music" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 13" 206x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    FRAM "Frame 12" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 11" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 24" 1372x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1204x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 10" 4x24 r=4.0 fill=Dark/Accent/Main=#D37918
      RECT "Rectangle 29" 2x14 r=4.0 fill=Dark/FG/A4=#404040
      ... 243 more RECTANGLE siblings
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 72x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings

COMP "Property 1=waveform" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 13" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 24" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 10" 4x24 r=4.0 fill=Dark/Accent/Main=#D37918
      RECT "Rectangle 29" 2x14 r=4.0 fill=Dark/FG/A4=#404040
      ... 243 more RECTANGLE siblings
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings

COMP "Property 1=sub timeline" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur:background_blur r=50.0
  FRAM "Frame 24" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 25" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 70x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:01:50*"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 11" 596x24 r=4.0 fill=Dark/BG/Accent Bright=#371F06
      RECT "Rectangle 13" 20x24 r=1.0 fill=#FFFFFF 14%
      FRAM "Frame 316" 18x24 r=4.0 stroke=Dark/BG/B2=#090909 w=2.0
        RECT "Rectangle 25" 18x24 r=4.0 fill=Dark/Accent/DIm=#AB6314
        VECT "Vector 27" 4x12 stroke=Dark/BG/B2=#090909 w=2.0
        VECT "Vector 28" 4x12 stroke=Dark/BG/B2=#090909 w=2.0
      FRAM "Frame 317" 18x24 r=4.0 stroke=Dark/BG/B2=#090909 w=2.0
        RECT "Rectangle 25" 18x24 r=4.0 fill=Dark/Accent/DIm=#AB6314
        VECT "Vector 27" 4x12 stroke=Dark/BG/B2=#090909 w=2.0
      FRAM "Frame 318" 22x24 r=4.0 stroke=Dark/BG/B2=#090909 w=2.0
        RECT "Rectangle 25" 22x24 r=4.0 fill=Dark/Accent/DIm=#AB6314
        VECT "Vector 28" 10x0 stroke=Dark/BG/B2=#090909 w=2.0
        VECT "Vector 29" 0x10 stroke=Dark/BG/B2=#090909 w=2.0
      FRAM "Frame 320" 22x24 r=4.0 stroke=Dark/BG/B2=#090909 w=2.0
        RECT "Rectangle 25" 22x24 r=4.0 fill=Dark/Accent/DIm=#AB6314
        VECT "Vector 28" 10x0 stroke=Dark/BG/B2=#090909 w=2.0
      ... 12 more RECTANGLE siblings
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 72x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:40*"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings

COMP "Property 1=200%" 88x28
  VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
  GROU "Group 14" 88x30 radii=[0.0, 0.0, 0.0, 0.0]
    VECT "Rectangle 7" 88x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
    VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%

COMP "Property 1=Default" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
      VECT "Vector 75" 18x18 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
      ELLI "Ellipse 10" 6x6 stroke=Dark/FG/A2=#8F8F8F w=1.5

COMP "Property 1=hover" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0 fill=#FFFFFF 6%
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
      VECT "Vector 75" 18x18 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
      ELLI "Ellipse 10" 6x6 stroke=Dark/FG/A2=#8F8F8F w=1.5

COMP "type=play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame" 24x24
      VECT "Vector 16" 9x14 r=1.0 fill=Dark/FG/B1=#161616 stroke=Dark/FG/B1=#161616 w=1.5

COMP "type=pause" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,15.0 align=CENTER/CENTER r=6.0 fill=Dark/FG/A3=#6B6B6B
  INST "Icon" 24x24 AL:H gap=4.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 16" 24x24
      VECT "Vector 17" 2x10 fill=Dark/BG/B1=#0E0E0E stroke=Dark/BG/B1=#0E0E0E w=1.5
      VECT "Vector 16" 2x10 fill=Dark/FG/B1=#161616 stroke=Dark/FG/B1=#161616 w=1.5

COMP "state=Default" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
  TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"

COMP "state=hover" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
  TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"

COMP "state=click" 76x28 AL:H gap=0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
  TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
  VECT "Vector 76" 0x16 stroke=Dark/Accent/Main=#D37918 w=1.0

FRAM "thumbnail" 272x189 AL:V gap=10.0 pad=10.0,10.0,10.0,10.0 align=/CENTER r=14.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur:background_blur r=50.0
  FRAM "Frame 244" 252x142 r=4.0 fill=image
  TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"

FRAM "audio value" 121x37 AL:H gap=10.0 pad=10.0,10.0,10.0,10.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur + shadow:background_blur r=50.0
  TEXT "100 %" 40x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "100 %"

```

### Right panels (Controls queue/subtitles/audio/playback/subtitle settings)

```
COMP "Property 1=queue" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 24" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 25" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 11" 98x24 r=4.0 fill=Dark/BG/Accent Bright=#371F06
      RECT "Rectangle 10" 8x24 r=4.0 fill=Dark/Accent/Main=#D37918
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/Accent/Main=#D37918 w=2.0
        VECT "Vector" 1x0 stroke=Dark/Accent/Main=#D37918 w=2.0
        ... 4 more VECTOR siblings
  FRAM "Queue" 400x946 AL:V gap=1.0 pad=0,0,0,0 align=/ r=10.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur:background_blur r=50.0
    FRAM "Frame 59" 400x50 AL:H gap=1.0 pad=0,6.0,0,6.0 align=/CENTER r=2.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 57" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2 fill=Dark/Accent/Main=#D37918
      FRAM "Frame 59" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2
      FRAM "Frame 58" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2
    FRAM "Frame 60" 400x68 AL:H gap=10.0 pad=20.0,20.0,20.0,28.0 align=SPACE_BETWEEN/CENTER
      TEXT "4 items - 2h 3m" 105x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "4 items - 2h 3m"
      FRAM "Frame 61" 180x28 AL:H gap=12.0 pad=0,0,0,0 align=MAX/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 11" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
        FRAM "Frame 12" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        ... 1 more INSTANCE Icon siblings
    FRAM "Frame 53" 400x826 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
      FRAM "Frame 44" 360x164 AL:V gap=12.0 pad=0,0,0,0 align=/
        FRAM "Frame 39" 360x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER
        FRAM "Frame 40" 360x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER
        FRAM "Frame 41" 360x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER
        FRAM "Frame 42" 360x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER

COMP "Property 1=subtitles" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 24" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 25" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 11" 98x24 r=4.0 fill=Dark/BG/Accent Bright=#371F06
      RECT "Rectangle 10" 8x24 r=4.0 fill=Dark/Accent/Main=#D37918
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings
  FRAM "Subtitles" 400x524 AL:V gap=1.0 pad=0,0,0,0 align=/CENTER r=10.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur:background_blur r=50.0
    FRAM "Frame 59" 400x50 AL:H gap=1.0 pad=0,6.0,0,6.0 align=/CENTER fill=Dark/BG/B2=#090909
      FRAM "Frame 59" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2
      FRAM "Frame 58" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2
      FRAM "Frame 57" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2 fill=Dark/Accent/Main=#D37918
    FRAM "Frame 60" 400x60 AL:H gap=10.0 pad=0,28.0,0,28.0 align=SPACE_BETWEEN/CENTER
      TEXT "Embedded Tracks" 120x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Embedded Tracks"
    FRAM "Frame 53" 400x138 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
      FRAM "Frame 44" 360x120 AL:V gap=12.0 pad=0,0,0,0 align=/
        FRAM "Frame 39" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 40" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 41" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 66" 400x60 AL:H gap=10.0 pad=0,28.0,0,28.0 align=SPACE_BETWEEN/CENTER
      TEXT "External Tracks" 102x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "External Tracks"
      FRAM "Frame 61" 68x24 AL:H gap=20.0 pad=0,0,0,0 align=MAX/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 67" 400x138 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
      FRAM "Frame 44" 360x32 AL:V gap=12.0 pad=0,0,0,0 align=/
        FRAM "Frame 40" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 65" 400x72 AL:V gap=10.0 pad=20.0,20.0,20.0,20.0 align=/
      INST "Button" 360x32 AL:H gap=6.0 pad=0,0,0,0 align=CENTER/CENTER r=4.0 fill=Dark/BG/B2=#090909
        INST "Icon" 20x20 HIDDEN AL:H gap=8.333333015441895 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "Show Advanced Settings" 121x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Show Preferences"

COMP "Property 1=audio" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 24" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 25" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 11" 98x24 r=4.0 fill=Dark/BG/Accent Bright=#371F06
      RECT "Rectangle 10" 8x24 r=4.0 fill=Dark/Accent/Main=#D37918
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings
  FRAM "Subtitles" 400x524 AL:V gap=1.0 pad=0,0,0,0 align=/ r=10.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur:background_blur r=50.0
    FRAM "Frame 59" 400x50 AL:H gap=1.0 pad=0,6.0,0,6.0 align=/CENTER fill=Dark/BG/B2=#090909
      FRAM "Frame 59" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2
      FRAM "Frame 58" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2 fill=Dark/Accent/Main=#D37918
      FRAM "Frame 57" 129x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 113x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 113x2
    FRAM "Frame 60" 400x60 AL:H gap=10.0 pad=0,28.0,0,28.0 align=SPACE_BETWEEN/CENTER
      TEXT "Embedded Tracks" 120x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Embedded Tracks"
    FRAM "Frame 53" 400x138 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
      FRAM "Frame 44" 360x120 AL:V gap=12.0 pad=0,0,0,0 align=/
        FRAM "Frame 39" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 41" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 40" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
    VECT "Vector" 400x0 stroke=Dark/Divider/Dim=#222222 w=1.0
    FRAM "Frame 63" 400x60 AL:H gap=10.0 pad=0,28.0,0,28.0 align=SPACE_BETWEEN/CENTER
      TEXT "Output Device" 95x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Output Device"
      FRAM "Frame 61" 24x24 AL:H gap=20.0 pad=0,0,0,0 align=MAX/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 64" 400x138 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
      FRAM "Frame 44" 360x76 AL:V gap=12.0 pad=0,0,0,0 align=/
        FRAM "Frame 39" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 40" 360x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 66" 400x72 AL:V gap=10.0 pad=20.0,20.0,20.0,20.0 align=CENTER/CENTER
      INST "Button" 360x32 AL:H gap=6.0 pad=0,0,0,0 align=CENTER/CENTER r=4.0 fill=Dark/BG/B2=#090909
        INST "Icon" 20x20 HIDDEN AL:H gap=8.333333015441895 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "Show Advanced Settings" 121x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Show Preferences"

COMP "Property 1=playback" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 24" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 25" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 11" 98x24 r=4.0 fill=Dark/BG/Accent Bright=#371F06
      RECT "Rectangle 10" 8x24 r=4.0 fill=Dark/Accent/Main=#D37918
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings
  FRAM "Subtitles" 400x946 AL:V gap=1.0 pad=0,0,0,0 align=/ r=10.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur:background_blur r=50.0
    FRAM "Frame 59" 400x50 AL:H gap=1.0 pad=0,6.0,0,6.0 align=/CENTER fill=Dark/BG/B2=#090909
      FRAM "Frame 59" 108x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 92x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 92x2 fill=Dark/Accent/Main=#D37918
      FRAM "Frame 60" 85x50 AL:V gap=14.0 pad=14.0,12.0,0,12.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 61x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 61x2
      FRAM "Frame 58" 85x50 AL:V gap=14.0 pad=14.0,12.0,0,12.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 61x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 61x2
      FRAM "Frame 57" 108x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 92x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 92x2
    FRAM "Frame 78" 400x895 AL:V gap=0 pad=0,0,0,0 align=/
      VECT "Vector" 400x0 stroke=Dark/Divider/Dim=#222222 w=1.0
      VECT "Vector" 400x0 stroke=Dark/Divider/Dim=#222222 w=1.0
      FRAM "Frame 108" 400x62 AL:V gap=10.0 pad=10.0,20.0,0,20.0 align=/CENTER
        FRAM "Frame 69" 360x52 AL:H gap=10.0 pad=10.0,0,10.0,4.0 align=SPACE_BETWEEN/CENTER
      FRAM "Frame 115" 400x52 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
        FRAM "Frame 69" 360x52 AL:H gap=10.0 pad=10.0,0,10.0,4.0 align=SPACE_BETWEEN/CENTER
      FRAM "Frame 116" 400x52 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
        FRAM "Frame 69" 360x52 AL:H gap=10.0 pad=10.0,0,10.0,4.0 align=SPACE_BETWEEN/CENTER
      FRAM "Frame 114" 400x78 AL:H gap=10.0 pad=10.0,20.0,20.0,20.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 69" 91x37 AL:H gap=10.0 pad=10.0,8.0,10.0,4.0 align=/CENTER
        FRAM "EQ" 220x48 AL:H gap=10.0 pad=2.0,2.0,2.0,2.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 111" 400x68 AL:H gap=10.0 pad=0,20.0,20.0,20.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 69" 118x37 AL:H gap=10.0 pad=10.0,8.0,10.0,4.0 align=/CENTER
        INST "Audio Visualizer" 220x48 AL:H gap=10.0 pad=2.0,2.0,2.0,2.0 align=CENTER/ r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 105" 400x126 AL:V gap=10.0 pad=0,20.0,15.0,20.0 align=/CENTER
        FRAM "Frame 60" 360x44 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "wrapper" 360x57 AL:V gap=10.0 pad=4.0,0,4.0,0 align=/

COMP "Property 1=subtitle settings" 1920x54 AL:H gap=20.0 pad=11.0,20.0,11.0,20.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
  FRAM "Frame 24" 130x28 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 8" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 18" 24x24
    INST "play" 54x28 AL:H gap=0 pad=2.0,15.0,2.0,17.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    FRAM "Frame 10" 30x28 AL:H gap=0 pad=2.0,3.0,2.0,3.0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 17" 24x24
  FRAM "Frame 25" 1406x28 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
    INST "Current Time" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:02:10" 63x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:02:10"
    FRAM "Frame 21" 1238x28 r=6.0 fill=Dark/BG/B2=#090909
      RECT "Rectangle 11" 98x24 r=4.0 fill=Dark/BG/Accent Bright=#371F06
      RECT "Rectangle 10" 8x24 r=4.0 fill=Dark/Accent/Main=#D37918
    INST "Duration" 76x28 AL:H gap=10.0 pad=2.0,8.0,2.0,8.0 align=CENTER/CENTER r=6.0
      TEXT "00:25:40" 65x18 fill=Dark/FG/A2=#8F8F8F font=Inter 400 15.0px lh=18.2 ls=0.0 "00:25:40"
  FRAM "Frame 15" 120x28 AL:H gap=8.0 pad=0,0,0,0 align=MAX/CENTER
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 31" 9x16 r=1.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 32" 0x2 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more VECTOR siblings
    INST "volume" 88x28
      VECT "Rectangle 6" 89x28 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
      GROU "Group 14" 33x30 radii=[0.0, 0.0, 0.0, 0.0]
        VECT "Rectangle 7" 33x30 radii=[1.0, 1.0, 1.0, 1.0] fill=#262626
        VECT "Rectangle 6" 86x25 r=2.0 fill=gradient_linear/#000000 20%
  FRAM "Frame 23" 114x32 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 1 more INSTANCE Icon Wrapper siblings
  INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector" 12x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector" 1x0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 4 more VECTOR siblings
  FRAM "Subtitles" 400x946 AL:V gap=1.0 pad=0,0,0,0 align=/ r=10.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur:background_blur r=50.0
    FRAM "Frame 59" 400x50 AL:H gap=1.0 pad=0,6.0,0,6.0 align=/CENTER fill=Dark/BG/B2=#090909
      FRAM "Frame 59" 108x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 92x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 92x2
      FRAM "Frame 60" 85x50 AL:V gap=14.0 pad=14.0,12.0,0,12.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 61x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 61x2
      FRAM "Frame 58" 85x50 AL:V gap=14.0 pad=14.0,12.0,0,12.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 61x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 61x2
      FRAM "Frame 57" 108x50 AL:V gap=14.0 pad=14.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 241" 92x20 AL:H gap=8.0 pad=0,0,0,0 align=CENTER/CENTER
        VECT "Vector" 92x2 fill=Dark/Accent/Main=#D37918
    FRAM "Frame 78" 400x769 AL:V gap=0 pad=0,0,0,0 align=/
      FRAM "Frame 101" 400x39 AL:H gap=10.0 pad=20.0,24.0,0,24.0 align=/CENTER
        TEXT "Defaults" 64x19 fill=Dark/FG/A1=#969696 font=Inter 500 16.0px lh=19.4 ls=0.0 "Defaults"
      FRAM "Frame 92" 400x121 AL:V gap=5.0 pad=10.0,20.0,10.0,20.0 align=/CENTER
        FRAM "Frame 60" 360x48 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 98" 360x48 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
      VECT "Vector" 400x0 stroke=Dark/Divider/Dim=#222222 w=1.0
      FRAM "Frame 99" 400x39 AL:H gap=10.0 pad=20.0,24.0,0,24.0 align=/CENTER
        TEXT "Synchronization" 124x19 fill=Dark/FG/A1=#969696 font=Inter 500 16.0px lh=19.4 ls=0.0 "Synchronization"
      FRAM "Frame 80" 400x320 AL:V gap=5.0 pad=10.0,20.0,20.0,20.0 align=/CENTER
        FRAM "Frame 60" 360x56 AL:H gap=10.0 pad=10.0,0,10.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "wrapper" 360x49 AL:V gap=10.0 pad=4.0,0,4.0,0 align=/
        FRAM "Frame 70" 360x56 AL:H gap=10.0 pad=10.0,0,10.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "wrapper" 360x24 AL:V gap=10.0 pad=4.0,0,4.0,0 align=/
        FRAM "Frame 71" 360x56 AL:H gap=10.0 pad=10.0,0,10.0,4.0 align=SPACE_BETWEEN/CENTER
        ... 1 more FRAME wrapper siblings
      VECT "Vector" 400x0 stroke=Dark/Divider/Dim=#222222 w=1.0
      FRAM "Frame 100" 400x39 AL:H gap=10.0 pad=20.0,24.0,0,24.0 align=/CENTER
        TEXT "Appearance" 93x19 fill=Dark/FG/A1=#969696 font=Inter 500 16.0px lh=19.4 ls=0.0 "Appearance"
      FRAM "Frame 91" 400x608 AL:V gap=5.0 pad=10.0,20.0,10.0,20.0 align=/CENTER
        FRAM "Frame 69" 360x48 AL:H gap=10.0 pad=10.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 60" 360x48 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 62" 360x48 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 63" 360x48 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 99" 360x48 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 61" 360x50 AL:H gap=10.0 pad=6.0,0,6.0,4.0 align=SPACE_BETWEEN/CENTER
        FRAM "Frame 96" 360x86 AL:V gap=5.0 pad=10.0,0,10.0,0 align=/
        FRAM "Frame 97" 360x86 AL:V gap=5.0 pad=10.0,0,10.0,0 align=/
        FRAM "Frame 98" 360x86 AL:V gap=5.0 pad=10.0,0,10.0,0 align=/
    FRAM "Frame 68" 400x125 AL:V gap=10.0 pad=20.0,20.0,20.0,20.0 align=CENTER/CENTER fill=Dark/BG/B1 Transparent=#0E0E0E 95% stroke=Dark/Divider/Dim=#222222 w=1.0 fx=bg blur:background_blur r=50.0
      INST "Setting Preset" 360x42 AL:H gap=10.0 pad=2.0,2.0,2.0,2.0 align=CENTER/ r=6.0 fill=Dark/BG/B2=#090909
        INST "option" 356x38 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=4.0
      INST "Button" 360x32 AL:H gap=6.0 pad=0,0,0,0 align=CENTER/CENTER r=4.0
        INST "Icon" 20x20 AL:H gap=8.333333015441895 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "Show Advanced Settings" 165x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Open Advanced Settings"

```

### Library sidebar (default, home), mini player, library rows, menu option, sorting and view menus

```
COMP "Property 1=Default" 427x986 AL:H gap=0 pad=0,0,0,0 align=/
  FRAM "Frame 3" 50x986 AL:V gap=14.0 pad=8.0,8.0,8.0,8.0 align=/CENTER fill=Dark/BG/A4=#191919
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 32x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    ... 5 more INSTANCE Icon Wrapper siblings
  FRAM "Frame 20" 377x986 AL:V gap=17.0 pad=20.0,20.0,20.0,20.0 align=/CENTER fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur:background_blur r=50.0
    FRAM "Frame 27" 337x68 AL:V gap=20.0 pad=0,0,0,0 align=/
      FRAM "Frame 25" 337x24 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 69" 60x24 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 323" 197x19 AL:H gap=6.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 103" 60x24 AL:H gap=12.0 pad=0,0,0,0 align=MAX/CENTER
      FRAM "Frame 28" 337x24 AL:H gap=130.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "15 items" 55x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "15 items"
        FRAM "Frame 102" 96x24 AL:H gap=12.0 pad=0,0,0,0 align=MAX/CENTER
    FRAM "Frame 55" 337x888 AL:V gap=0 pad=0,0,0,0 align=/
      VECT "Vector" 337x0 stroke=Dark/Divider/Dim=#222222 w=1.0
      FRAM "Frame 53" 337x888 AL:V gap=10.0 pad=20.0,0,20.0,0 align=/CENTER
        INST "media" 337x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        INST "media" 337x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        ... 14 more INSTANCE media siblings

COMP "Property 1=home" 427x986 AL:H gap=0 pad=0,0,0,0 align=/
  FRAM "Frame 3" 50x986 AL:V gap=14.0 pad=8.0,8.0,8.0,8.0 align=/CENTER fill=Dark/BG/A4=#191919
    INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
    INST "Icon Wrapper" 32x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
        VECT "Vector 23" 18x18 radii=[0.0, 0.0, 0.0, 0.0] stroke=Dark/FG/A2=#8F8F8F w=1.5
    ... 5 more INSTANCE Icon Wrapper siblings
  FRAM "Frame 20" 377x986 AL:V gap=17.0 pad=20.0,20.0,20.0,20.0 align=/CENTER fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur:background_blur r=50.0
    FRAM "Frame 27" 337x68 AL:V gap=20.0 pad=0,0,0,0 align=/
      FRAM "Frame 25" 337x24 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 69" 60x24 AL:H gap=12.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 323" 197x19 AL:H gap=6.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 103" 60x24 AL:H gap=12.0 pad=0,0,0,0 align=MAX/CENTER
      FRAM "Frame 28" 337x24 AL:H gap=130.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "110 items" 62x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "110 items"
        FRAM "Frame 102" 96x24 AL:H gap=12.0 pad=0,0,0,0 align=MAX/CENTER
    FRAM "Frame 54" 337x888 AL:V gap=0 pad=0,0,0,0 align=/
      VECT "Vector" 337x0 stroke=Dark/Divider/Dim=#222222 w=1.0
      FRAM "Frame 53" 337x888 AL:V gap=30.0 pad=20.0,0,20.0,0 align=/CENTER
        FRAM "Frame 134" 337x163 AL:V gap=15.0 pad=0,0,0,0 align=/
        FRAM "Frame 133" 337x163 AL:V gap=15.0 pad=0,0,0,0 align=/
        FRAM "Frame 135" 337x163 AL:V gap=15.0 pad=0,0,0,0 align=/
        FRAM "Frame 136" 337x163 AL:V gap=15.0 pad=0,0,0,0 align=/
        FRAM "Frame 137" 337x79 AL:V gap=15.0 pad=0,0,0,0 align=/
        FRAM "Frame 138" 337x79 AL:V gap=15.0 pad=0,0,0,0 align=/

COMP "Property 1=Default" 391x339 AL:V gap=20.0 pad=8.0,8.0,8.0,8.0 align=CENTER/ r=14.0 fill=Dark/BG/A3=#1B1B1B fx=:drop_shadow r=11.800000190734863
  FRAM "Frame 112" 375x230 AL:V gap=4.0 pad=0,0,0,0 align=/ r=14.0
    FRAM "Frame 28" 375x211 r=6.0 fill=#303030/image stroke=Dark/BG/B2=#090909 w=2.0
    FRAM "Frame 22" 375x16 AL:H gap=16.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 21" 375x16 r=6.0 fill=Dark/BG/B2=#090909
        RECT "Rectangle 11" 96x12 r=4.0 fill=Dark/BG/Accent Bright=#371F06
  FRAM "Frame 115" 375x73 AL:V gap=14.0 pad=4.0,8.0,4.0,8.0 align=/
    FRAM "Frame 113" 359x19 AL:H gap=20.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
      TEXT "The Wand_S01E11.mp4" 174x19 fill=Dark/FG/A1=#969696 font=Inter 400 16.0px lh=19.4 ls=0.0 "The Wand_S01E11.mp4"
    FRAM "Frame 114" 359x32 AL:H gap=20.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
      FRAM "Frame 118" 140x24 AL:H gap=20.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 116" 60x24 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 117" 60x24 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
      INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER

COMP "Property 1=Variant3" 391x339 AL:V gap=20.0 pad=8.0,8.0,8.0,8.0 align=CENTER/ r=14.0 fill=Dark/BG/A3=#1B1B1B fx=:drop_shadow r=11.800000190734863
  FRAM "Frame 112" 375x230 AL:V gap=4.0 pad=0,0,0,0 align=/ r=14.0
    FRAM "Frame 28" 375x211 r=6.0 fill=#303030/image/#000000 60% stroke=Dark/BG/B2=#090909 w=2.0
      INST "Icon" 43x43 AL:H gap=17.85714340209961 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 43x43
      FRAM "Frame 8" 54x50 AL:H gap=0 pad=3.5714285373687744,5.357142925262451,3.5714285373687744,5.357142925262451 align=CENTER/CENTER r=7.142857074737549 fx=:drop_shadow r=9.523809432983398
        INST "Icon" 43x43 AL:H gap=1.7857142686843872 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 10" 54x50 AL:H gap=0 pad=3.5714285373687744,5.357142925262451,3.5714285373687744,5.357142925262451 align=CENTER/CENTER r=7.142857074737549 fx=:drop_shadow r=9.523809432983398
        INST "Icon" 43x43 AL:H gap=1.7857142686843872 pad=0,0,0,0 align=CENTER/CENTER
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
      ... 1 more INSTANCE Icon siblings
    FRAM "Frame 22" 375x16 AL:H gap=16.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 21" 375x16 r=6.0 fill=Dark/BG/B2=#090909
        RECT "Rectangle 11" 96x12 r=4.0 fill=Dark/BG/Accent Bright=#371F06
        RECT "Rectangle 10" 8x12 r=4.0 fill=Dark/Accent/Main=#D37918
  FRAM "Frame 115" 375x73 AL:V gap=14.0 pad=4.0,8.0,4.0,8.0 align=/
    FRAM "Frame 113" 359x19 AL:H gap=20.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
      TEXT "The Wand_S01E11.mp4" 174x19 fill=Dark/FG/A1=#969696 font=Inter 400 16.0px lh=19.4 ls=0.0 "The Wand_S01E11.mp4"
    FRAM "Frame 114" 359x32 AL:H gap=20.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
      FRAM "Frame 118" 140x24 AL:H gap=20.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 116" 60x24 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 117" 60x24 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
      INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER

COMP "Property 1=Variant2" 391x690 AL:V gap=20.0 pad=8.0,8.0,8.0,8.0 align=MAX/CENTER r=14.0 fill=Dark/BG/A3=#1B1B1B fx=:drop_shadow r=11.800000190734863
  FRAM "Queue" 375x331 AL:V gap=1.0 pad=0,0,0,0 align=MAX/CENTER r=10.0 fill=Dark/BG/A3=#1B1B1B
    FRAM "Frame 61" 391x58 AL:H gap=1.0 pad=0,0,0,0 align=/CENTER radii=[14.0, 14.0, 2.0, 2.0] fill=Dark/BG/A5=#151515
      FRAM "Frame 57" 391x50 AL:V gap=14.0 pad=16.0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER
        TEXT "Queue" 375x19 fill=Dark/FG/A2=#8F8F8F font=Inter 400 16.0px lh=19.4 ls=0.0 "Queue"
    FRAM "Frame 60" 375x64 AL:H gap=10.0 pad=20.0,20.0,20.0,28.0 align=SPACE_BETWEEN/CENTER
      TEXT "4 items - 2h 3m" 105x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "4 items - 2h 3m"
      FRAM "Frame 61" 112x24 AL:H gap=20.0 pad=0,0,0,0 align=MAX/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        ... 1 more INSTANCE Icon siblings
    FRAM "Frame 53" 375x215 AL:V gap=10.0 pad=0,20.0,0,20.0 align=/CENTER
      FRAM "Frame 44" 335x164 AL:V gap=12.0 pad=0,0,0,0 align=/
        FRAM "Frame 39" 335x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER
        FRAM "Frame 40" 335x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER
        FRAM "Frame 41" 335x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER
        FRAM "Frame 42" 335x32 AL:H gap=10.0 pad=0,4.0,0,0 align=/CENTER
  FRAM "Frame 112" 375x230 AL:V gap=4.0 pad=0,0,0,0 align=/ r=14.0
    FRAM "Frame 28" 375x211 r=6.0 fill=#303030/image stroke=Dark/BG/B2=#090909 w=2.0
    FRAM "Frame 22" 375x16 AL:H gap=16.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 21" 375x16 r=6.0 fill=Dark/BG/B2=#090909
        RECT "Rectangle 11" 96x12 r=4.0 fill=Dark/BG/Accent Bright=#371F06
  FRAM "Frame 115" 375x73 AL:V gap=14.0 pad=4.0,8.0,4.0,8.0 align=/
    FRAM "Frame 113" 359x19 AL:H gap=20.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
      TEXT "The Wand_S01E11.mp4" 174x19 fill=Dark/FG/A1=#969696 font=Inter 400 16.0px lh=19.4 ls=0.0 "The Wand_S01E11.mp4"
    FRAM "Frame 114" 359x32 AL:H gap=20.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
      FRAM "Frame 118" 140x24 AL:H gap=20.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 116" 60x24 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 117" 60x24 AL:H gap=8.0 pad=0,0,0,0 align=/CENTER
      INST "Icon Wrapper" 30x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER

COMP "Property 1=unwatched" 337x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
  INST "Icon" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 28" 32x32 AL:V gap=10.0 pad=10.0,10.0,10.0,10.0 align=/ r=2.0 fill=#303030
  TEXT "The Wand_S01E01.mp4" 295x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The Wand_S01E01.mp4"
  INST "Icon" 24x24 HIDDEN AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame" 24x24
      FRAM "Frame 49" 18x18
        VECT "Vector 36" 0x0 stroke=Dark/FG/A2=#8F8F8F w=3.0
        VECT "Vector 37" 0x0 stroke=Dark/FG/A2=#8F8F8F w=3.0
        ... 1 more VECTOR siblings

COMP "Property 1=hover-unwatched" 337x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
  INST "Icon" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 28" 32x32 AL:V gap=10.0 pad=10.0,10.0,10.0,10.0 align=/ r=2.0 fill=#303030
  TEXT "The Wand_S01E01.mp4" 261x17 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=16.9 ls=0.0 "The Wand_S01E01.mp4"
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame" 24x24
      FRAM "Frame 49" 18x18
        VECT "Vector 36" 0x0 stroke=Dark/FG/A2=#8F8F8F w=3.0
        VECT "Vector 37" 0x0 stroke=Dark/FG/A2=#8F8F8F w=3.0
        ... 1 more VECTOR siblings

COMP "Property 1=watched" 337x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
  INST "Icon" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 28" 32x32 AL:V gap=10.0 pad=0,0,0,0 align=MAX/ r=2.0 fill=#303030
        RECT "Rectangle 12" 28x3 fill=Dark/Accent/Main=#D37918
  TEXT "The Wand_S01E01.mp4" 295x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "The Wand_S01E01.mp4"
  INST "Icon" 24x24 HIDDEN AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame" 24x24
      FRAM "Frame 49" 18x18
        VECT "Vector 36" 0x0 stroke=Dark/FG/A2=#8F8F8F w=3.0
        VECT "Vector 37" 0x0 stroke=Dark/FG/A2=#8F8F8F w=3.0
        ... 1 more VECTOR siblings

COMP "Property 1=Default" 261x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
  TEXT "Option" 165x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Option"
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24

COMP "Property 1=hover" 261x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0 fill=Dark/BG/A2=#1F1F1F
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
  TEXT "Option" 165x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Option"
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24

COMP "Property 1=selected" 261x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0 fill=Dark/BG/A2=#1F1F1F
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
  TEXT "Option" 165x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Option"
  INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
      VECT "Vector 44" 14x11 stroke=Dark/Accent/Main=#D37918 w=2.0

FRAM "Sorting Options" 265x776 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0 fill=Dark/BG/A2=#1F1F1F
    INST "Icon" 24x24 HIDDEN AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
    TEXT "Option" 195x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Unwatched First"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
        VECT "Vector 44" 14x11 stroke=Dark/Accent/Main=#D37918 w=2.0
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 HIDDEN AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
    TEXT "Option" 195x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Watched First"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  ... 14 more INSTANCE option siblings

FRAM "View Options" 265x104 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
        RECT "Rectangle 22" 10x8 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        RECT "Rectangle 24" 10x8 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        ... 2 more RECTANGLE siblings
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Grid View"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0 fill=Dark/BG/A2=#1F1F1F
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
        RECT "Rectangle 23" 6x6 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        RECT "Rectangle 24" 6x6 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 80" 11x0 r=0.8571428656578064 stroke=Dark/FG/A2=#8F8F8F w=1.2857142686843872
        VECT "Vector 81" 11x0 r=0.8571428656578064 stroke=Dark/FG/A2=#8F8F8F w=1.2857142686843872
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "List View"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
        VECT "Vector 44" 14x11 stroke=Dark/Accent/Main=#D37918 w=2.0

```

### Main menu, right-click menu, folder/file/playlist context menus, profiles

```
FRAM "menu" 375x585 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  FRAM "option" 367x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Rectangle 1" 18x20 radii=[4.0, 4.0, 4.0, 4.0] stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Rectangle 2" 5x5 radii=[4.0, 4.0, 4.0, 4.0] fill=Dark/Accent/DIm=#AB6314
    TEXT "Open File(s)" 148x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Open File(s)"
    TEXT "Ctrl + O" 148x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Ctrl + O"
  FRAM "option" 367x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 23" 18x16 radii=[0.0, 0.0, 0.0, 0.0] stroke=Dark/Accent/DIm=#AB6314 w=1.5
        VECT "Vector 24" 18x13 radii=[0.0, 0.0, 0.0, 0.0] stroke=Dark/FG/A2=#8F8F8F w=1.5
    TEXT "Open Folder" 148x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Open Folder"
    TEXT "Ctrl + F" 148x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Ctrl + F"
  VECT "Vector 104" 367x1 stroke=Dark/Divider/Dim=#222222 w=1.0
  ... 10 more FRAME option siblings

FRAM "right-click menu" 292x683 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95%
  FRAM "option" 284x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 16" 9x14 r=1.0 stroke=Dark/Accent/DIm=#AB6314 w=1.5
    TEXT "Play" 106x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Play"
    TEXT "Space" 106x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Space"
  FRAM "option" 284x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=1.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 17" 24x24
        VECT "Vector 16" 8x10 stroke=Dark/Accent/DIm=#AB6314 w=1.5
    TEXT "Stop" 106x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Stop"
    TEXT "S" 106x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "S"
  VECT "Vector 105" 284x1 stroke=Dark/Divider/Dim=#222222 w=1.0
  VECT "Vector 106" 284x1 stroke=Dark/Divider/Dim=#222222 w=1.0
  ... 12 more FRAME option siblings
  ... 1 more VECTOR siblings

FRAM "folder context menu" 265x296 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
        VECT "Vector 39" 0x14 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 40" 14x0 r=2.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Add File"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 23" 18x16 radii=[0.0, 0.0, 0.0, 0.0] stroke=Dark/FG/A2=#8F8F8F w=1.5
        VECT "Vector 39" 0x6 r=2.0 stroke=Dark/Accent/DIm=#AB6314 w=1.5
        ... 1 more VECTOR siblings
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Add Folder"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  ... 4 more INSTANCE option siblings

FRAM "file context menu" 265x584 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 16" 9x14 r=1.0 stroke=Dark/Accent/DIm=#AB6314 w=1.5
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Play"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
        VECT "Vector 44" 12x10 stroke=Dark/Accent/DIm=#AB6314 w=1.5
        VECT "Vector 114" 15x15 r=3.0 stroke=Dark/FG/A2=#8F8F8F w=1.5
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Mark as Watched"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  ... 10 more INSTANCE option siblings

FRAM "playlist context menu" 265x392 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 16" 9x14 r=1.0 stroke=Dark/Accent/DIm=#AB6314 w=1.5
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Play"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
        VECT "Union" 23x18 radii=[0.0, 0.0, 0.0, 0.0] stroke=Dark/Accent/DIm=#AB6314 w=1.5
    TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Favorite"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
  ... 6 more INSTANCE option siblings

FRAM "Profiles" 651x633
  FRAM "menu" 375x585 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
    FRAM "option" 367x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
      TEXT "Open File(s)" 148x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Open File(s)"
      TEXT "Ctrl + O" 148x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Ctrl + O"
    FRAM "option" 367x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
      TEXT "Open Folder" 148x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Open Folder"
      TEXT "Ctrl + F" 148x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Ctrl + F"
    VECT "Vector 104" 367x1 stroke=Dark/Divider/Dim=#222222 w=1.0 op=0.0
    ... 10 more FRAME option siblings
  FRAM "context menu" 265x249 AL:V gap=0 pad=4.0,4.0,4.0,4.0 align=/ r=10.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
    INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0 fill=Dark/BG/A2=#1F1F1F
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
      TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Movies"
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
    INST "option" 257x48 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=6.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
      TEXT "Option" 161x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Shows"
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
    VECT "Vector 104" 257x1 stroke=Dark/Divider/Dim=#222222 w=1.0
    ... 3 more INSTANCE option siblings

```

### Dialogs (Add Subtitles, Keyboard Shortcuts, Open Network Stream, New Playlist, Settings), setting category, toggle, dropdown, button, preset menu, onboarding

```
FRAM "Add Subtitles to Playlist/Folder" 1048x800 AL:V gap=0 pad=0,0,0,0 align=/ r=14.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur + shadow:background_blur r=50.0
  FRAM "Frame 120" 1048x96 AL:V gap=12.0 pad=9.0,9.0,9.0,9.0 align=/ radii=[14.0, 14.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
    FRAM "Frame 207" 1030x32 AL:H gap=1.0 pad=0,0,0,10.0 align=SPACE_BETWEEN/CENTER
      TEXT "Add Subtitles" 89x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Add Subtitles"
      INST "Icon Wrapper" 32x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 206" 1030x34 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      INST "target" 200x34 AL:H gap=10.0 pad=5.0,8.0,5.0,12.0 align=SPACE_BETWEEN/CENTER r=6.0 fill=Dark/BG/A5=#151515
        TEXT "To This Folder" 94x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "To This Folder"
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 123" 200x34 AL:H gap=10.0 pad=5.0,8.0,5.0,12.0 align=SPACE_BETWEEN/CENTER r=6.0 fill=Dark/BG/A5=#151515
        TEXT "From Computer" 104x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "From Computer"
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 122" 610x34 AL:H gap=10.0 pad=5.0,8.0,5.0,8.0 align=/CENTER r=6.0 fill=Dark/BG/A5=#151515
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "Videos / Shows / The Wand / S01" 219x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "Videos / Shows / The Wand / S01"
  FRAM "Frame 124" 1048x632 AL:H gap=0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 3" 519x632 AL:V gap=16.0 pad=30.0,0,30.0,30.0 align=/
      FRAM "Frame 223" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E01.mp4" 157x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E01.mp4"
        VECT "Vector 77" 280x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 208" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E02.mp4" 160x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E02.mp4"
        VECT "Vector 77" 277x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 209" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E03.mp4" 160x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E03.mp4"
        VECT "Vector 77" 277x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 210" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E04.mp4" 160x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E04.mp4"
        VECT "Vector 77" 277x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 211" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E05.mp4" 159x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E05.mp4"
        VECT "Vector 77" 278x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 212" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E06.mp4" 159x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E06.mp4"
        VECT "Vector 77" 278x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 213" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E07.mp4" 157x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E07.mp4"
        VECT "Vector 77" 280x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 214" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E08.mp4" 160x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E08.mp4"
        VECT "Vector 77" 277x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 215" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E09.mp4" 160x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E09.mp4"
        VECT "Vector 77" 277x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 216" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E10.mp4" 157x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E10.mp4"
        VECT "Vector 77" 280x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 217" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E11.mp4" 155x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E11.mp4"
        VECT "Vector 77" 282x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 218" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E12.mp4" 157x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E12.mp4"
        VECT "Vector 77" 280x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 219" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E13.mp4" 158x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E13.mp4"
        VECT "Vector 77" 279x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 220" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E14.mp4" 157x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E14.mp4"
        VECT "Vector 77" 280x0 stroke=Dark/Divider/Bright=#373737 w=1.0
      FRAM "Frame 221" 489x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "The_Wand_S01E15.mp4" 157x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "The_Wand_S01E15.mp4"
        VECT "Vector 77" 280x0 stroke=Dark/Divider/Bright=#373737 w=1.0
    FRAM "Frame 124" 529x632 AL:V gap=4.0 pad=22.0,20.0,22.0,20.0 align=/
      INST "subtitle multiple" 489x36 AL:H gap=16.0 pad=0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER r=6.0
        FRAM "Frame 208" 184x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
      INST "subtitle multiple" 489x36 AL:H gap=16.0 pad=0,8.0,0,8.0 align=SPACE_BETWEEN/CENTER r=6.0
        FRAM "Frame 208" 186x24 AL:H gap=14.0 pad=0,0,0,0 align=/CENTER
      ... 13 more INSTANCE subtitle multiple siblings
  FRAM "Frame 224" 1048x72 AL:H gap=20.0 pad=20.0,20.0,20.0,20.0 align=SPACE_BETWEEN/CENTER
    FRAM "Frame 140" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/A3=#1B1B1B
      TEXT "Cancel" 48x17 fill=Dark/FG/A2=#8F8F8F font=Inter 600 14.0px lh=16.9 ls=0.0 "Cancel"
    FRAM "Frame 141" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/Accent Bright=#371F06
      TEXT "Save" 33x17 fill=Dark/Accent/Main=#D37918 font=Inter 600 14.0px lh=16.9 ls=0.0 "Save"

FRAM "Keyboard Shortcuts" 1048x800 AL:V gap=0 pad=0,0,0,0 align=/ r=14.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  FRAM "Frame 120" 1048x96 AL:V gap=12.0 pad=9.0,9.0,9.0,9.0 align=/ radii=[14.0, 14.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
    FRAM "Frame 207" 1030x32 AL:H gap=1.0 pad=0,0,0,10.0 align=SPACE_BETWEEN/CENTER
      TEXT "Keyboard Shortcuts" 132x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Keyboard Shortcuts"
      INST "Icon Wrapper" 32x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 206" 1030x34 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 122" 820x34 AL:H gap=10.0 pad=5.0,8.0,5.0,8.0 align=/CENTER r=6.0 fill=Dark/BG/A5=#151515
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        TEXT "Search Keyboard Shortcuts..." 193x17 fill=Dark/FG/A4=#404040 font=Inter 400 14.0px lh=16.9 ls=0.0 "Search Keyboard Shortcuts..."
      FRAM "Frame 124" 200x34 AL:H gap=10.0 pad=5.0,8.0,5.0,12.0 align=SPACE_BETWEEN/CENTER r=6.0 fill=Dark/BG/A5=#151515
        TEXT "All Fields" 60x17 fill=Dark/FG/A1=#969696 font=Inter 400 14.0px lh=16.9 ls=0.0 "All Fields"
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
  FRAM "Frame 124" 1048x632 AL:V gap=20.0 pad=20.0,20.0,22.0,20.0 align=/
    FRAM "Frame 503" 1008x25 AL:H gap=0 pad=0,0,0,0 align=/CENTER
      TEXT "Action" 488x25 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=24.5 ls=0.0 "Action"
      TEXT "Hotkey" 332x25 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=24.5 ls=0.0 "Hotkey"
      TEXT "Global Hotkey" 93x25 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=24.5 ls=0.0 "Global Hotkey"
    VECT "Vector" 1008x0 stroke=Dark/Divider/Dim=#222222 w=1.0
    TEXT "Basic" 1008x28 fill=Dark/FG/A1=#969696 font=Inter 400 16.0px lh=28.0 ls=0.0 "Basic"
    FRAM "Frame 124" 1008x179 AL:V gap=14.0 pad=0,0,5.0,0 align=/
      FRAM "Frame 261" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Toggle fullscreen" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Toggle fullscreen"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 260" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Exit fullscreen / close dialog" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Exit fullscreen / close dialog"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 259" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Show playback position and time" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Show playback position and time"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 258" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Show interface controls in fullscreen" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Show interface controls in fullscreen"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
    VECT "Vector" 1008x0 stroke=Dark/Divider/Dim=#222222 w=1.0
    TEXT "Playback" 1008x28 fill=Dark/FG/A1=#969696 font=Inter 400 16.0px lh=28.0 ls=0.0 "Playback"
    FRAM "Frame 504" 1008x226 AL:V gap=14.0 pad=0,0,5.0,0 align=/
      FRAM "Frame 261" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Play / pause" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Play / pause"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 260" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Stop playback" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Stop playback"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 259" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Next track" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Next track"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 258" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Previous track" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Previous track"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
      FRAM "Frame 262" 1008x33 AL:H gap=96.0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
        TEXT "Next program / Service ID" 290x25 fill=Dark/FG/2=#C6C6C6 font=Inter 400 14.0px lh=24.5 ls=0.0 "Next program / Service ID"
        FRAM "Frame 162" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
        FRAM "Frame 252" 270x33 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909
  FRAM "Frame 225" 1048x72 AL:H gap=20.0 pad=20.0,20.0,20.0,20.0 align=SPACE_BETWEEN/CENTER
    FRAM "Frame 140" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/A3=#1B1B1B
      TEXT "Cancel" 48x17 fill=Dark/FG/A2=#8F8F8F font=Inter 600 14.0px lh=16.9 ls=0.0 "Cancel"
    FRAM "Frame 141" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/Accent Bright=#371F06 op=0.5
      TEXT "Save" 33x17 fill=Dark/Accent/Main=#D37918 font=Inter 600 14.0px lh=16.9 ls=0.0 "Save"

FRAM "Open network stream" 1048x631 AL:V gap=0 pad=0,0,0,0 align=/ r=14.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  FRAM "Frame 120" 1048x50 AL:V gap=12.0 pad=9.0,9.0,9.0,9.0 align=/ radii=[14.0, 14.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
    FRAM "Frame 207" 1030x32 AL:H gap=1.0 pad=0,0,0,10.0 align=SPACE_BETWEEN/CENTER
      TEXT "Open Network Stream" 147x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Open Network Stream"
      INST "Icon Wrapper" 32x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
  FRAM "Frame 124" 1048x509 AL:V gap=20.0 pad=22.0,20.0,22.0,20.0 align=/
    FRAM "Frame 324" 1008x58 AL:V gap=5.0 pad=0,0,0,0 align=/
      TEXT "Network URL" 1008x28 fill=Dark/FG/2=#C6C6C6 font=Inter 400 16.0px lh=28.0 ls=0.0 "Network URL "
      TEXT "You can enter multiple links to load." 1008x25 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=24.5 ls=0.0 "You can enter multiple links to load."
    FRAM "Frame 206" 1008x194 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 86" 1008x194 AL:H gap=10.0 pad=8.0,18.0,8.0,12.0 align=/ r=6.0 fill=Dark/BG/B2=#090909 stroke=Dark/BG/A4=#191919 w=2.0
        TEXT "e.g., https://www.example.com/stream.avi" 279x17 fill=Dark/FG/A4=#404040 font=Inter 400 14.0px lh=16.9 ls=0.0 "e.g., https://www.example.com/stream.avi"
    VECT "Vector" 1008x0 stroke=Dark/Divider/Dim=#222222 w=1.0
    FRAM "Frame 325" 1008x58 AL:V gap=5.0 pad=0,0,0,0 align=/
      TEXT "Playlist Name (optional)" 1008x28 fill=Dark/FG/2=#C6C6C6 font=Inter 400 16.0px lh=28.0 ls=0.0 "Playlist Name (optional)"
      TEXT "The playlist will be saved and displayed with this title." 1008x25 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=24.5 ls=0.0 "The playlist will be saved and displayed"
    FRAM "Frame 326" 1008x41 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 86" 1008x37 AL:H gap=10.0 pad=8.0,18.0,8.0,12.0 align=/ r=6.0 fill=Dark/BG/B2=#090909 stroke=Dark/BG/A4=#191919 w=2.0
        TEXT "e.g., Favorite TV Channels" 174x17 fill=Dark/FG/A4=#404040 font=Inter 400 14.0px lh=16.9 ls=0.0 "e.g., Favorite TV Channels"
  FRAM "Frame 225" 1048x72 AL:H gap=20.0 pad=20.0,20.0,20.0,20.0 align=SPACE_BETWEEN/CENTER
    FRAM "Frame 140" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/A3=#1B1B1B
      TEXT "Cancel" 48x17 fill=Dark/FG/A2=#8F8F8F font=Inter 600 14.0px lh=16.9 ls=0.0 "Cancel"
    FRAM "Frame 141" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/Accent Bright=#371F06 op=0.5
      TEXT "Save" 33x17 fill=Dark/Accent/Main=#D37918 font=Inter 600 14.0px lh=16.9 ls=0.0 "Save"

FRAM "new playlist" 713x589 AL:V gap=0 pad=0,0,0,0 align=/ r=14.0 fill=Dark/BG/A3 Transparent=#191919 95% fx=bg blur + shadow:background_blur r=50.0
  FRAM "Frame 120" 713x50 AL:V gap=12.0 pad=9.0,9.0,9.0,9.0 align=/ radii=[14.0, 14.0, 0.0, 0.0] fill=Dark/BG/B2=#090909
    FRAM "Frame 207" 695x32 AL:H gap=1.0 pad=0,0,0,10.0 align=SPACE_BETWEEN/CENTER
      TEXT "New Playlist" 81x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "New Playlist"
      INST "Icon Wrapper" 32x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
        INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
  FRAM "Frame 124" 713x467 AL:V gap=20.0 pad=22.0,20.0,22.0,20.0 align=/
    FRAM "Frame 499" 673x119 AL:H gap=20.0 pad=0,0,0,0 align=/MAX
      FRAM "Frame 498" 541x119 AL:V gap=20.0 pad=0,0,0,0 align=/
        FRAM "Frame 327" 541x58 AL:V gap=5.0 pad=0,0,0,0 align=/
        FRAM "Frame 328" 541x41 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 326" 112x112 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 86" 112x112 AL:H gap=10.0 pad=12.0,12.0,12.0,12.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909 stroke=Dark/BG/A4=#191919 w=2.0
    VECT "Vector" 673x0 stroke=Dark/Divider/Dim=#222222 w=1.0
    FRAM "Frame 324" 673x58 AL:V gap=5.0 pad=0,0,0,0 align=/
      TEXT "Select Files" 673x28 fill=Dark/FG/2=#C6C6C6 font=Inter 400 16.0px lh=28.0 ls=0.0 "Select Files"
      TEXT "These files will be added to the playlist." 673x25 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=24.5 ls=0.0 "These files will be added to the playlis"
    FRAM "Frame 206" 673x186 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 86" 673x186 AL:V gap=20.0 pad=8.0,18.0,8.0,12.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/B2=#090909 stroke=#2D2D2D w=2.0
        TEXT "Drag files into the box or click here to select files." 327x17 fill=Dark/FG/A4=#404040 font=Inter 400 14.0px lh=16.9 ls=0.0 "Drag files into the box or click here to"
        FRAM "Frame 327" 84x30 AL:H gap=10.0 pad=3.0,30.0,3.0,30.0 align=/CENTER r=5.0 fill=Dark/FG/B1=#161616
  FRAM "Frame 225" 713x72 AL:H gap=20.0 pad=20.0,20.0,20.0,20.0 align=SPACE_BETWEEN/CENTER
    FRAM "Frame 140" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/A3=#1B1B1B
      TEXT "Cancel" 48x17 fill=Dark/FG/A2=#8F8F8F font=Inter 600 14.0px lh=16.9 ls=0.0 "Cancel"
    FRAM "Frame 141" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/Accent Bright=#371F06 op=0.5
      TEXT "Save" 33x17 fill=Dark/Accent/Main=#D37918 font=Inter 600 14.0px lh=16.9 ls=0.0 "Save"

FRAM "Settings - global" 1048x865 AL:V gap=0 pad=0,0,0,0 align=/ r=14.0 fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=bg blur + shadow:background_blur r=50.0
  FRAM "Frame 120" 1048x50 AL:H gap=159.0 pad=0,14.0,0,8.0 align=SPACE_BETWEEN/CENTER fill=Dark/BG/B2=#090909
    FRAM "Frame 121" 200x34 AL:H gap=10.0 pad=5.0,8.0,5.0,8.0 align=/CENTER r=6.0 fill=Dark/BG/A5=#151515
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
      TEXT "Search" 47x17 fill=Dark/FG/A4=#404040 font=Inter 400 14.0px lh=16.9 ls=0.0 "Search"
    FRAM "Frame 311" 794x19 AL:H gap=10.0 pad=0,32.0,0,32.0 align=/CENTER
      TEXT "Global Settings" 115x19 fill=Dark/FG/A1=#969696 font=Inter 400 16.0px lh=19.4 ls=0.0 "Global Settings"
    INST "Icon Wrapper" 32x32 AL:H gap=10.0 pad=4.0,4.0,4.0,4.0 align=CENTER/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
  FRAM "Frame 124" 1048x815 AL:H gap=0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 3" 216x815 AL:V gap=14.0 pad=8.0,8.0,8.0,8.0 align=/ fill=Dark/BG/B1 Transparent=#0E0E0E 95%
      FRAM "Frame 110" 200x799 AL:V gap=8.0 pad=6.0,6.0,6.0,6.0 align=/ r=6.0 fill=Dark/BG/A3 Transparent=#191919 95%
        FRAM "Frame 260" 188x33 AL:H gap=10.0 pad=8.0,10.0,8.0,10.0 align=/CENTER
        INST "setting category" 188x40 AL:H gap=8.0 pad=4.0,4.0,4.0,4.0 align=/CENTER r=2.0 fill=Dark/BG/A1=#222222
        INST "setting category" 188x40 AL:H gap=8.0 pad=4.0,4.0,4.0,4.0 align=/CENTER r=2.0
        FRAM "Frame 261" 188x33 AL:H gap=10.0 pad=8.0,10.0,8.0,10.0 align=/CENTER
        FRAM "Frame 263" 188x33 AL:H gap=10.0 pad=8.0,10.0,8.0,10.0 align=/CENTER
        ... 11 more INSTANCE setting category siblings
    FRAM "Frame 123" 832x815 AL:V gap=20.0 pad=20.0,24.0,100.0,24.0 align=/
      FRAM "Frame 269" 784x695 AL:V gap=20.0 pad=0,0,0,0 align=/
        FRAM "Frame 125" 784x177 AL:V gap=0 pad=0,0,0,0 align=/
        FRAM "Frame 126" 784x123 AL:V gap=0 pad=0,0,0,0 align=/
        FRAM "Frame 267" 784x215 AL:V gap=0 pad=0,0,0,0 align=/
        FRAM "Frame 265" 784x38 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER r=2.0 fill=Dark/BG/A3 Transparent=#191919 95%

COMP "selected=no" 188x40 AL:H gap=8.0 pad=4.0,4.0,4.0,4.0 align=/CENTER r=2.0
  INST "Icon" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
      VECT "Vector 74" 12x20 radii=[0.0, 0.0, 0.0, 0.0] stroke=Dark/FG/A2=#8F8F8F w=1.5
  TEXT "Interface" 60x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Interface"

COMP "selected=yes" 188x40 AL:H gap=8.0 pad=4.0,4.0,4.0,4.0 align=/CENTER r=2.0 fill=Dark/BG/A1=#222222
  INST "Icon" 32x32 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 24x24
      VECT "Vector 74" 12x20 radii=[0.0, 0.0, 0.0, 0.0] fill=Dark/Accent/Main=#D37918 stroke=Dark/Accent/Main=#D37918 w=1.5
  TEXT "Interface" 60x17 fill=Dark/FG/1=#EAEAEA font=Inter 400 14.0px lh=16.9 ls=0.0 "Interface"

COMP "Value=on" 68x32 r=6.0 fill=Dark/BG/B2=#090909
  RECT "Rectangle 11" 33x26 r=3.0 fill=Dark/BG/Accent Bright=#371F06
  RECT "Rectangle 12" 26x26 r=3.0 fill=Dark/Accent/DIm=#AB6314
  TEXT "ON" 19x15 fill=Dark/Accent/Main=#D37918 font=Inter 400 12.0px lh=14.5 ls=0.0 "ON"

COMP "Value=off" 68x32 r=6.0 fill=Dark/BG/B2=#090909
  RECT "Rectangle 11" 33x26 r=3.0 fill=Dark/BG/A4=#191919
  RECT "Rectangle 12" 26x26 r=3.0 fill=Dark/FG/A4=#404040
  TEXT "OFF" 24x15 fill=Dark/FG/A3=#6B6B6B font=Inter 400 12.0px lh=14.5 ls=0.0 "OFF"

COMP "state=default" 364x48 AL:H gap=10.0 pad=2.0,2.0,2.0,2.0 align=CENTER/ r=6.0 fill=Dark/BG/B2=#090909
  INST "option" 360x44 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=4.0 fill=Dark/BG/A4=#191919
    INST "Icon" 24x24 HIDDEN AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame 1" 24x24
    TEXT "Option" 298x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Dropdown"
    INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
      FRAM "Frame" 24x24
        VECT "Vector 27" 10x5 stroke=Dark/FG/A2=#8F8F8F w=1.5

COMP "state=open" 364x48 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/ r=6.0 fill=Dark/BG/B2=#090909
  FRAM "Options" 364x232 AL:V gap=2.0 pad=2.0,2.0,2.0,2.0 align=/ r=6.0 fill=Dark/BG/A4=#191919 fx=:drop_shadow r=13.800000190734863
    INST "option" 360x44 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=4.0 fill=Dark/BG/A2=#1F1F1F
      INST "Icon" 24x24 HIDDEN AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
      TEXT "Option" 298x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Dropdown"
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
    INST "option" 360x44 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=4.0
      INST "Icon" 24x24 HIDDEN AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
      TEXT "Option" 298x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Dropdown"
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
    ... 3 more INSTANCE option siblings

COMP "Property 1=Default" 360x32 AL:H gap=6.0 pad=0,0,0,0 align=CENTER/CENTER r=4.0 fill=Dark/BG/B2=#090909
  INST "Icon" 20x20 AL:H gap=8.333333015441895 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 20x20
      VECT "Vector 75" 15x15 r=1.6666666269302368 stroke=Dark/FG/A2=#8F8F8F w=1.25
      ELLI "Ellipse 10" 5x5 stroke=Dark/FG/A2=#8F8F8F w=1.25
  TEXT "Show Advanced Settings" 166x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "Show Advanced Settings"

COMP "Property 1=Variant2" 360x32 AL:H gap=6.0 pad=0,0,0,0 align=CENTER/CENTER r=4.0 fill=Dark/BG/A4=#191919
  INST "Icon" 20x20 AL:H gap=8.333333015441895 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 1" 20x20
      VECT "Vector 75" 15x15 r=1.6666666269302368 stroke=Dark/FG/A2=#8F8F8F w=1.25
      ELLI "Ellipse 10" 5x5 stroke=Dark/FG/A2=#8F8F8F w=1.25
  TEXT "Show Advanced Settings" 166x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Show Advanced Settings"

COMP "state=open" 364x42 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/MAX r=6.0 fill=Dark/BG/B2=#090909
  FRAM "Options" 364x242 AL:V gap=2.0 pad=2.0,2.0,2.0,2.0 align=/ r=6.0 fill=Dark/BG/A4=#191919 fx=:drop_shadow r=14.0
    INST "option" 360x38 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
      TEXT "Option" 264x17 fill=Dark/FG/A3=#6B6B6B font=Inter 400 14.0px lh=16.9 ls=0.0 "New Preset"
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
    INST "option" 360x38 AL:H gap=10.0 pad=2.0,14.0,2.0,14.0 align=/CENTER r=4.0
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame" 24x24
      TEXT "Option" 264x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Custom Preset 01"
      INST "Icon" 24x24 AL:H gap=10.0 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 1" 24x24
    ... 4 more INSTANCE option siblings

FRAM "Onboarding" 1090x759 r=14.0 fill=Dark/BG/B1=#0E0E0E fx=:drop_shadow r=11.800000190734863
  INST "Icon" 141x141 AL:H gap=58.75 pad=0,0,0,0 align=CENTER/CENTER
    FRAM "Frame 4" 141x141
      VECT "Vector" 106x48 fill=#D37918
      VECT "Vector" 48x30 fill=#D37918
      ... 1 more VECTOR siblings
  TEXT "Welcome to VLC!" 256x39 fill=Dark/FG/1=#EAEAEA font=Inter 300 32.0px lh=38.7 ls=0.0 "Welcome to VLC!"
  TEXT "VLC is a free and open source cross-platform multimedia player and framework that plays most multimedia files as well as DVDs, Audio CDs, VCDs, and various streaming protocols." 595x84 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "VLC is a free and open source cross-plat"
  FRAM "Frame 140" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
    TEXT "Next" 37x19 fill=Dark/FG/B1=#161616 font=Inter 600 16.0px lh=19.4 ls=0.0 "Next"
  FRAM "Frame 69" 595x69 AL:V gap=16.0 pad=0,0,0,0 align=/
    FRAM "Frame 264" 280x17 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
      TEXT "Choose a Media Folder to get started with" 280x17 fill=Dark/FG/A2=#8F8F8F font=Inter 400 14.0px lh=16.9 ls=0.0 "Choose a Media Folder to get started wit"
    FRAM "Frame 268" 595x36 AL:H gap=10.0 pad=0,0,0,0 align=MAX/CENTER
      FRAM "Frame 86" 471x36 AL:H gap=10.0 pad=8.0,18.0,8.0,12.0 align=/CENTER r=6.0 fill=Dark/BG/B2=#090909 stroke=Dark/BG/A4=#191919 w=2.0
        TEXT "~/Videos" 69x28 fill=Dark/FG/2=#C6C6C6 font=Inter 400 16.0px lh=28.0 ls=0.0 "~/Videos"
      FRAM "Frame 141" 114x35 AL:H gap=10.0 pad=8.0,6.0,8.0,6.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/A3=#1B1B1B
        TEXT "Browse" 57x19 fill=Dark/FG/A2=#8F8F8F font=Inter 400 16.0px lh=19.4 ls=0.0 "Browse"

FRAM "Onboarding" 1090x759 r=14.0 fill=Dark/BG/B1=#0E0E0E fx=:drop_shadow r=11.800000190734863
  FRAM "Player" 1056x594 AL:V gap=0 pad=0,0,0,0 align=/ fill=Dark/BG/B2=#090909
    FRAM "Frame 55" 1056x594 AL:V gap=0 pad=0,0,0,0 align=SPACE_BETWEEN/CENTER
      FRAM "Frame 2" 1056x22 AL:H gap=5.5 pad=3.3000001907348633,3.3000001907348633,3.3000001907348633,3.3000001907348633 align=SPACE_BETWEEN/CENTER fill=#191919
        FRAM "Frame 9" 165x15 AL:H gap=3.8500001430511475 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 10" 165x13 AL:H gap=0 pad=0,0,0,0 align=MAX/CENTER
      INST "Controls" 1056x30 AL:H gap=11.0 pad=6.050000190734863,11.0,6.050000190734863,11.0 align=/CENTER fill=Dark/BG/A3 Transparent=#191919 95% stroke=Dark/Divider/Dim=#222222 w=0.550000011920929 fx=:background_blur r=27.5
        FRAM "Frame 25" 72x15 AL:H gap=4.400000095367432 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 24" 773x15 AL:H gap=4.400000095367432 pad=0,0,0,0 align=CENTER/CENTER
        FRAM "Frame 15" 66x15 AL:H gap=4.400000095367432 pad=0,0,0,0 align=MAX/CENTER
        FRAM "Frame 23" 63x18 AL:H gap=6.600000381469727 pad=0,0,0,0 align=/CENTER
        INST "Icon Wrapper" 16x18 AL:H gap=5.5 pad=2.200000047683716,2.200000047683716,2.200000047683716,2.200000047683716 align=CENTER/CENTER r=2.200000047683716
      INST "sidebar" 235x542 AL:H gap=0 pad=0,0,0,0 align=/
        FRAM "Frame 3" 28x542 AL:V gap=7.700000286102295 pad=4.400000095367432,4.400000095367432,4.400000095367432,4.400000095367432 align=/CENTER fill=Dark/BG/A4=#191919
        FRAM "Frame 20" 207x542 AL:V gap=9.350000381469727 pad=11.0,11.0,11.0,11.0 align=/CENTER fill=Dark/BG/B1 Transparent=#0E0E0E 95% fx=:background_blur r=27.5
  TEXT "Select your preferred theme and color." 432x42 fill=Dark/FG/A1=#969696 font=Inter 300 24.0px lh=42.0 ls=0.0 "Select your preferred theme and color."
  FRAM "Frame 141" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
    TEXT "Next" 37x19 fill=Dark/FG/B1=#161616 font=Inter 600 16.0px lh=19.4 ls=0.0 "Next"
  FRAM "Frame 148" 116x157 AL:V gap=22.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 151" 116x116 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=/CENTER r=19.0
      RECT "Rectangle 21" 100x100 r=12.0 fill=#AFAFAF
    TEXT "Light" 116x19 fill=Dark/FG/A2=#8F8F8F font=Inter 300 16.0px lh=19.4 ls=0.0 "Light"
  FRAM "Frame 151" 116x157 AL:V gap=22.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 151" 116x116 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=/CENTER r=19.0 stroke=Dark/Accent/Main=#D37918 w=4.0
      RECT "Rectangle 21" 100x100 r=12.0 fill=#222222
    TEXT "Dark" 116x19 fill=Dark/FG/A2=#8F8F8F font=Inter 300 16.0px lh=19.4 ls=0.0 "Dark"
  FRAM "Frame 152" 116x157 AL:V gap=22.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 151" 116x116 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=/CENTER r=19.0
      RECT "Rectangle 21" 100x100 r=12.0 fill=#AFAFAF/gradient_linear
    TEXT "System" 116x19 fill=Dark/FG/A2=#8F8F8F font=Inter 300 16.0px lh=19.4 ls=0.0 "System"
  FRAM "Frame 153" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 stroke=#D37918 30% w=4.0
    ELLI "Ellipse 11" 40x40 fill=#D37918
  FRAM "Frame 154" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#E15032
  FRAM "Frame 155" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#C49E23
  FRAM "Frame 156" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#19A234
  FRAM "Frame 157" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#18AAD3
  FRAM "Frame 158" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#185DD3
  FRAM "Frame 159" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#8E42FF
  FRAM "Frame 160" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#F052B3
  FRAM "Frame 161" 64x64 AL:H gap=10.0 pad=8.0,8.0,8.0,8.0 align=CENTER/CENTER r=100.0 op=0.5
    ELLI "Ellipse 11" 40x40 fill=#AFAFAF
  FRAM "Frame 140" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/A3=#1B1B1B
    TEXT "Back" 39x19 fill=Dark/FG/A2=#8F8F8F font=Inter 600 16.0px lh=19.4 ls=0.0 "Back"

FRAM "Onboarding" 1090x759 r=14.0 fill=Dark/BG/B1=#0E0E0E fx=:drop_shadow r=11.800000190734863
  TEXT "Learn the basic keyboard shortcuts." 409x42 fill=Dark/FG/A1=#969696 font=Inter 400 24.0px lh=42.0 ls=0.0 "Learn the basic keyboard shortcuts."
  TEXT "Find the full list in the menu." 213x28 fill=Dark/FG/A3=#6B6B6B font=Inter 400 16.0px lh=28.0 ls=0.0 "Find the full list in the menu."
  FRAM "Frame 141" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/Accent/Main=#D37918
    TEXT "Finish" 47x19 fill=Dark/FG/B1=#161616 font=Inter 600 16.0px lh=19.4 ls=0.0 "Finish"
  FRAM "Frame 204" 936x452 AL:H gap=150.0 pad=0,0,0,0 align=/CENTER
    FRAM "Frame 203" 393x452 AL:H gap=20.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 198" 220x438 AL:V gap=54.0 pad=0,0,0,0 align=/
        TEXT "Play / Pause" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Play / Pause"
        TEXT "Seek Backward / Forward" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Seek Backward / Forward"
        TEXT "Previous / Next Item" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Previous / Next Item"
        TEXT "Previous / Next Frame" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Previous / Next Frame"
        TEXT "Cycle Subtitle Track" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Cycle Subtitle Track"
        TEXT "Cycle Audio Track" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Cycle Audio Track"
      FRAM "Frame 199" 153x452 AL:V gap=40.0 pad=0,0,0,0 align=/
        FRAM "Frame 162" 93x42 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=12.0 fill=Dark/BG/A3=#1B1B1B stroke=Dark/Divider/Bright=#373737 w=3.0 fx=:drop_shadow
        FRAM "Frame 182" 153x42 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 193" 108x42 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 192" 96x42 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 177" 57x42 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=12.0 fill=Dark/BG/A3=#1B1B1B stroke=Dark/Divider/Bright=#373737 w=3.0 fx=:drop_shadow
        FRAM "Frame 178" 57x42 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=12.0 fill=Dark/BG/A3=#1B1B1B stroke=Dark/Divider/Bright=#373737 w=3.0 fx=:drop_shadow
    FRAM "Frame 202" 393x452 AL:H gap=20.0 pad=0,0,0,0 align=/CENTER
      FRAM "Frame 200" 220x438 AL:V gap=54.0 pad=0,0,0,0 align=/
        TEXT "Toggle Fullscreen" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Toggle Fullscreen"
        TEXT "Increase / Decrease Volume" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Increase / Decrease Volume"
        TEXT "Show / Hide Queue" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Show / Hide Queue"
        TEXT "Show / Hide File Browser" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Show / Hide File Browser"
        TEXT "Take a Snapshot" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Take a Snapshot"
        TEXT "Record" 220x28 fill=Dark/FG/A1=#969696 font=Inter 300 16.0px lh=28.0 ls=0.0 "Record"
      FRAM "Frame 201" 153x452 AL:V gap=40.0 pad=0,0,0,0 align=/
        FRAM "Frame 186" 56x42 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=12.0 fill=Dark/BG/A3=#1B1B1B stroke=Dark/Divider/Bright=#373737 w=3.0 fx=:drop_shadow
        FRAM "Frame 189" 118x42 AL:H gap=10.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 191" 59x42 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=12.0 fill=Dark/BG/A3=#1B1B1B stroke=Dark/Divider/Bright=#373737 w=3.0 fx=:drop_shadow
        FRAM "Frame 187" 55x42 AL:H gap=10.0 pad=4.0,20.0,4.0,20.0 align=CENTER/CENTER r=12.0 fill=Dark/BG/A3=#1B1B1B stroke=Dark/Divider/Bright=#373737 w=3.0 fx=:drop_shadow
        FRAM "Frame 197" 153x42 AL:H gap=4.0 pad=0,0,0,0 align=/CENTER
        FRAM "Frame 196" 153x42 AL:H gap=4.0 pad=0,0,0,0 align=/CENTER
  FRAM "Frame 140" 100x32 AL:H gap=10.0 pad=4.0,8.0,4.0,8.0 align=CENTER/CENTER r=6.0 fill=Dark/BG/A3=#1B1B1B
    TEXT "Back" 39x19 fill=Dark/FG/A2=#8F8F8F font=Inter 600 16.0px lh=19.4 ls=0.0 "Back"

```
