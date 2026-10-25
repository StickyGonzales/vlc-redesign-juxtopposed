# RESIDUAL_AUDIT: every element of VLC's current interface vs the redesign

**NOTHING IS REMOVED UNTIL STICKY DECIDES.** This file only marks where each element of VLC master's current Qt/QML interface ends up in the redesign. No element is deleted from the code because of this file. Elements marked NOT IN VIDEO stay in the app, working as today, until Sticky decides about them (section "Decisions needed from Sticky").

Sources: a local inventory of VLC 4's current interface (`vlc_ui_inventory.md`, local only, not committed; the 380 elements, same grouping and names), `redesign/VIDEO_INDEX.md` (rows P*, IA*, IB*, F*, Decisions (Sticky) and (Claude)), `redesign/FIGMA_FLOWS.md` (prototype menus and specs), `redesign/BUILD_PLAN.md` section 0 (Step 1 UI only / Step 2 new features). Written 2026-10-13.

## Marks
- **KEEP**: the element exists in the redesign at the same kind of place. The row names the VIDEO_INDEX row(s) or Figma element.
- **MOVE**: the function stays but its entry point moves. The row says exactly where.
- **NOT IN VIDEO**: not shown anywhere in the video or the Figma file. The row also says what VLC function it gives, whether that function is reachable elsewhere in the redesign as planned, and "Unreachable if removed: yes / no".
- **?**: unsure; the row explains why.

## Planned entry points used in this file (assumptions)
- **main "..."**: the top bar "..." menu, final Figma version (Decision 2): Open File(s) Ctrl + O, Open Folder Ctrl + F, Open Network Stream Ctrl + N, Open Disc Ctrl + D, Open Capture Device Ctrl + C, Convert Ctrl + R, Open Recent >, Profile >, Keyboard Shortcuts, Customize Player, Settings Ctrl + P, About VLC Shift + F1.
- **right-click**: the right-click menu (P2-23, right-click menu.png): Play, Stop, Previous Item, Next Item, Record, Hide UI (Ctrl + \), Playback >, Video >, Audio >, Subtitle >, More Settings >, Playlist >, Open Media >, Quit VLC. Its submenus keep VLC's submenus, so **RC > Playback**, **RC > Video**, **RC > Audio**, **RC > Subtitle** are VLC's Playback, Video, Audio, Subtitle menus; **RC > More Settings** is the former Tools + View menus (P2-23); **RC > Open Media** is VLC's Open Media submenu (Open File, Open Directory, Open Disc, Open Network, Open Capture Device). VLC master's popup has no Playlist submenu, so the content of **RC > Playlist** is still to be defined when it is wired (Decision 14); this file does not count anything as reachable through it. Decision 14 wires About VLC, Quit VLC, More Settings, Open Media and right-click Playlist to real actions.
- **HK**: hotkeys. Decision 22 keeps every VLC default shortcut (core hotkeys and Qt window shortcuts), adds Ctrl+\ = Hide UI and Ctrl+B = create bookmark, and ignores the prototype's F and V bindings.
- **Settings > page**: the new Settings dialog (P8-02 to P8-22). Every page has "Advanced Options" (P7-14, P8-22), and BUILD_PLAN section 2 keeps VLC's old preferences dialog reachable from Advanced. An option that only lives there is written "full preferences" and counts as reachable (but very hidden).
- **Customize palette**: the items she shows at 19:12 (P8-24, P8-46): Spacer, Divider, Playback Speed, Forward 10s, Backward 10s, Forward 15s, Backward 15s, Stop, Repeat, Shuffle, Record, Snapshot, Picture in Picture, HDR, Zoom, Right Sidebar, Quit VLC, VLC Settings, Go Home, Thumbnail, File Name, Artist Name, Folder Name, Playlist Name, Properties, Replay, Chapters, Favorite, Bookmark, Bookmarks, Playlists. W8.1a restyles VLC's existing toolbar editor, so other existing control types could stay in the palette, but they are not shown.
- **Right sidebar** = gear sidebar with tabs Playback / Video / Audio / Subtitles. **Queue sidebar** = Queue / Bookmarks / Chapters (Decision 3). **Tracks popup** = Video / Audio / Subtitles popup from the audio and subtitle buttons (Decision 5).
- Rows that show old VLC only as a problem (for example P5-04 Browse, P6-08 Open Media dialog) do not count as the redesign showing that element.
- **Unreachable if removed**: would the VLC function become unreachable if this element were removed, counting KEEP / MOVE entry points, hotkeys, Settings pages (including full preferences), the Customize palette and the right-click submenus, but NOT other NOT IN VIDEO elements (they are removal candidates too). For KEEP and MOVE rows the column says "-".
- Step 2 successors (BUILD_PLAN section 0) are flagged, for example "Step 2 W4.3b": the old entry must stay until that package lands.

## Summary

| Area | Elements | KEEP | MOVE | NOT IN VIDEO | ? | NOT IN VIDEO that would become unreachable |
|---|---|---|---|---|---|---|
| 1.1 Media menu | 15 | 7 | 4 | 1 | 3 | 1 |
| 1.2 Playback menu | 24 | 0 | 24 | 0 | 0 | 0 |
| 1.3 Audio menu | 8 | 0 | 8 | 0 | 0 | 0 |
| 1.4 Video menu | 12 | 0 | 12 | 0 | 0 | 0 |
| 1.5 Subtitle menu | 2 | 0 | 2 | 0 | 0 | 0 |
| 1.6 Tools menu | 10 | 0 | 10 | 0 | 0 | 0 |
| 1.7 View menu | 10 | 0 | 10 | 0 | 0 | 0 |
| 1.8 Help menu | 3 | 1 | 0 | 2 | 0 | 0 |
| 1.9 Menu bar containers | 2 | 1 | 1 | 0 | 0 | 0 |
| 1.10 Right-click / popup menus | 24 | 2 | 11 | 9 | 2 | 6 |
| 1.11 Systray menu | 7 | 0 | 0 | 7 | 0 | 2 |
| 2.1 Player top bar | 9 | 5 | 4 | 0 | 0 | 0 |
| 2.2 Player body | 16 | 3 | 4 | 9 | 0 | 4 |
| 2.3 Control bar fixed parts | 5 | 4 | 1 | 0 | 0 | 0 |
| 2.4 Control bar control types | 43 | 19 | 6 | 17 | 1 | 4 |
| 2.5 Tracks menu | 8 | 0 | 7 | 1 | 0 | 0 |
| 2.6 Default toolbar profiles | 6 | 0 | 1 | 5 | 0 | 0 |
| 2.7 Mini player, PIP, minimal view | 3 | 0 | 3 | 0 | 0 | 0 |
| 3.1 Window chrome and navigation | 19 | 3 | 8 | 8 | 0 | 4 |
| 3.2 Common page header toolbar | 6 | 4 | 2 | 0 | 0 | 0 |
| 3.3 Library views | 27 | 9 | 9 | 9 | 0 | 3 |
| 3.4 Play queue panel | 9 | 4 | 1 | 4 | 0 | 2 |
| 4.1 Open Media dialog | 7 | 0 | 5 | 2 | 0 | 2 |
| 4.2 Convert dialog | 6 | 0 | 0 | 6 | 0 | 5 |
| 4.3 Stream Output wizard | 5 | 0 | 0 | 5 | 0 | 4 |
| 4.4 Bookmarks dialog | 2 | 0 | 2 | 0 | 0 | 0 |
| 4.5 Adjustments and Effects | 16 | 0 | 11 | 5 | 0 | 1 |
| 4.6 Media Information | 6 | 0 | 3 | 3 | 0 | 3 |
| 4.7 Messages | 4 | 0 | 0 | 4 | 0 | 1 |
| 4.8 Plugins and extensions | 5 | 0 | 3 | 2 | 0 | 2 |
| 4.9 Other dialogs | 12 | 1 | 4 | 7 | 0 | 6 |
| 4.10 Preferences | 10 | 0 | 9 | 1 | 0 | 0 |
| 4.11 QML core dialogs | 5 | 0 | 0 | 5 | 0 | 4 |
| 5.1 Qt/QML window shortcuts | 5 | 4 | 0 | 0 | 1 | 0 |
| 5.2 Core hotkey actions with no or limited Qt UI | 24 | 24 | 0 | 0 | 0 | 0 |
| 5.3 Other user-visible behaviour | 5 | 1 | 0 | 4 | 0 | 2 |
| **Total** | **380** | **92** | **165** | **116** | **7** | **56** |

Totals: 380 elements: 92 KEEP, 165 MOVE, 116 NOT IN VIDEO, 7 "?". Of the 116 NOT IN VIDEO elements, 56 would become unreachable if removed, 59 would not, and 1 is unknown (2.2 Toggle control bar button, needs a DVD menu test). The 7 "?" rows and that one are listed in "Decisions needed from Sticky", part C.

## 1. Main menu bar and popup menus

### 1.1 Media menu (VLCMenuBar::FileMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Open File... (Ctrl+O) | KEEP | main "..." > Open File(s) Ctrl + O (P6-11, P8-27, Figma menu.png); RC > Open Media > Open File; HK Ctrl+O | Native file picker, plays the selection | - |
| Open Multiple Files... (Ctrl+Shift+O) | MOVE | Merged into main "..." > Open File(s) (P6-11: "Open Multiple Files merged into Open File(s)"). The full Open Media dialog (File tab) stays reachable from RC > Open Media > Open File... and HK Ctrl+Shift+O (Decision 22). W6.4 splits and restyles the open dialogs. | Full Open Media dialog on the File tab (several files, subtitle file, more options) | - |
| Open Directory... / Open Folder... (Ctrl+F) | KEEP | main "..." > Open Folder Ctrl + F (Figma; the video says "Open Folder(s)", P6-11); RC > Open Media; HK Ctrl+F | Pick a folder and play it | - |
| Open Disc... (Ctrl+D) | KEEP | main "..." > Open Disc Ctrl + D (P6-11, Figma), its own dialog (P6-12, W6.4); RC > Open Media; HK Ctrl+D | Open Media dialog, Disc tab | - |
| Open Network Stream... (Ctrl+N) | KEEP | main "..." > Open Network Stream Ctrl + N, new dialog (P6-13, IB-29); library Network > "+ Add Network Stream" (P6-07); HK Ctrl+N | Open a network MRL | - |
| Open Capture Device... (Ctrl+C) | KEEP | main "..." > Open Capture Device Ctrl + C (P6-11, Figma); RC > Open Media; HK Ctrl+C | Open Media dialog, Capture Device tab | - |
| Open Location from clipboard (Ctrl+V) | ? | Shown in both video menu versions (P2-21 at 5:08, P6-11 at 13:08 as "Open from Clipboard Ctrl + V") but not in the final Figma menu that Decision 2 picked. Only HK Ctrl+V stays (Decision 22, paste with confirmation). | Opens the URL found in the clipboard | no (HK Ctrl+V only, no visible entry) |
| Open Recent Media > (10 recent items) | KEEP | main "..." > Open Recent > (P6-11, Figma); also library rail Recent (P6-19), Home Continue Watching (P6-20); HK Ctrl+1..Ctrl+0 | Play a recent media from the ML history | - |
| Open Recent Media > Clear | MOVE | Settings > Privacy > History > "Clear history now" (P8-07). The Open Recent submenu content is never shown, so whether Clear also stays inside it is unknown. | MLRecentMediaModel::clearHistory | - |
| Save Play Queue to File... (Ctrl+Y) | ? | Shown as "Save Playlist to File Ctrl + Y" in the provisional 5:08 menu (P2-21) and removed from the final menu (P6-11, Figma). The queue sidebar header has only sort, repeat, shuffle, minus, plus (IB-19). Playlist "..." > Export Playlist (F-11) exports saved ML playlists, not the queue. Only HK Ctrl+Y stays (Decision 22). | Export the play queue to m3u / xspf / html | no (HK Ctrl+Y only, no visible entry) |
| Convert / Save... (Ctrl+R) | KEEP | main "..." > Convert Ctrl + R (P6-11, Figma); library file "..." > Convert (P6-17, F-12); HK Ctrl+R | Open dialog in Convert mode, then the Convert dialog | - |
| Stream... (Ctrl+S) | MOVE | Library file "..." > Stream (P6-17, F-12) and HK Ctrl+S (Decision 22). It is in the video's final menu (P6-11) but not in the Figma menu that Decision 2 picked. Stream defaults live in Settings > Recording > Streaming (P8-17). | Open dialog in Stream mode, then the Stream Output wizard | - |
| Quit at the end of play queue (checkable) | ? | Probably Settings > Playback > Order > "When playback finishes" (P8-09; its value list is never shown). That is a saved setting, not a one-session toggle. The Sleep Timer "End of current file" (Decision 23) stops playback, it does not quit. | PlaylistController::setMediaStopAction(MEDIA_STOPPED_EXIT) | no if the "When playback finishes" list gets a "Quit VLC" value (W6.2), otherwise yes |
| Close to systray | NOT IN VIDEO | Not shown. The tray is outside the redesign; Settings > Interface has a "Notifications and System Tray" section (P8-06, rows not shown). | Hide the main window to the tray (VLCSystray::toggleUpdateMenu) | yes (only the tray menu, also NOT IN VIDEO, does the same) |
| Quit (Ctrl+Q) | MOVE | right-click > Quit VLC Ctrl + Q (P2-23, wired by Decision 14); Customize palette "Quit VLC" (P8-24); top bar close button (P2-09); HK Ctrl+Q. Not in the main "..." menu. | DialogsProvider::quit, libvlc_Quit | - |

### 1.2 Playback menu (VLCMenuBar::NavigMenu + RebuildNavigMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Title > (list) | MOVE | RC > Playback > Title. No other new entry (the Chapters tab lists chapters only). HK Shift+O / Shift+B. | Select title | - |
| Chapter > (list, tear-off) | MOVE | Queue sidebar > Chapters tab (P7-06, Decision 3); RC > Playback > Chapter; seek bar chapter segments (IB-46) | Select chapter | - |
| Program > (list) | MOVE | RC > Playback > Program; HK x / Shift+X | Select program (DVB/TS service) | - |
| Bookmarks > Manage (Ctrl+B) | MOVE | Queue sidebar > Bookmarks tab (P7-05) takes over the dialog's job; RC > Playback > Bookmarks > Manage keeps the old dialog. Ctrl+B is reassigned to "create bookmark" (Decision 22, Step 2 W4.8b), so Manage loses its shortcut. | Edit Bookmarks dialog | - |
| Bookmarks > (bookmark list, tear-off) | MOVE | Queue sidebar > Bookmarks tab, click a row (P7-05); RC > Playback > Bookmarks; HK F1..F10 (see the F1/F10 clash in Upstream issues) | Jump to an ML bookmark | - |
| Renderer > <Local> | MOVE | Right sidebar > Video tab > "Render" dropdown [Local] (P4-27, Decision 24); RC > Playback > Renderer | Play locally (no renderer) | - |
| Renderer > (discovered renderers) + "Scanning... (Ns)" | MOVE | Same Render dropdown (P4-27, Decision 24); RC > Playback > Renderer; Settings > Recording > Casting > "Discover cast devices" (P8-17) | RendererManager: scan and cast | - |
| Speed > Faster | MOVE | Right sidebar > Playback tab > Speed slider 0.25 to 2 (P4-31); Customize palette "Playback Speed" (P8-24); RC > Playback > Speed; HK "+" | PlayerController::faster | - |
| Speed > Faster (fine) | MOVE | Same as Faster; HK "]" | PlayerController::littlefaster | - |
| Speed > Normal Speed | MOVE | Speed slider tick "1" (P4-31); RC > Playback > Speed; HK "=" | PlayerController::normalRate | - |
| Speed > Slower (fine) | MOVE | Same as Faster; HK "[" | PlayerController::littleslower | - |
| Speed > Slower | MOVE | Same as Faster; HK "-" | PlayerController::slower | - |
| Jump Forward | MOVE | RC > Playback > Jump Forward; Customize palette Forward 10s / Forward 15s (P8-24); music bar forward 15 (P6-05); HK Shift/Alt/Ctrl+Right; step sizes in Settings > Controls > Skip Amounts (P8-08) | PlayerController::jumpFwd | - |
| Jump Backward | MOVE | RC > Playback > Jump Backward; Customize palette Backward 10s / Backward 15s; music bar rewind 15 (P6-05); HK Shift/Alt/Ctrl+Left | PlayerController::jumpBwd | - |
| Jump to Specific Time (Ctrl+T) | MOVE | Click the current time label and type a time (F-02, W3.5); RC > Playback > Jump to Specific Time; HK Ctrl+T | Go to Time dialog | - |
| Previous Title (visible only if titles) | MOVE | RC > Playback; HK Shift+O | PlayerController::titlePrev | - |
| Next Title (visible only if titles) | MOVE | RC > Playback; HK Shift+B | PlayerController::titleNext | - |
| Previous Chapter (visible only if chapters) | MOVE | Queue sidebar > Chapters tab rows (P7-06); RC > Playback; HK Shift+P | PlayerController::chapterPrev | - |
| Next Chapter (visible only if chapters) | MOVE | Queue sidebar > Chapters tab rows (P7-06); RC > Playback; HK Shift+N | PlayerController::chapterNext | - |
| Play / Pause | MOVE | right-click > Play Space (top level, P2-23); control bar play button (P1-14, IA-17); RC > Playback; HK Space | togglePlayPause | - |
| Stop | MOVE | right-click > Stop S (P2-23); Customize palette "Stop" (P8-24); HK s. Removed from the default control bar (P1-14). | PlaylistController::stop | - |
| Previous | MOVE | right-click > Previous Item P (P2-23); control bar Previous (P1-14); HK p | PlaylistController::prev | - |
| Next | MOVE | right-click > Next Item N (P2-23); control bar Next (P1-14); HK n | PlaylistController::next | - |
| Record | MOVE | right-click > Record (P2-23); Customize palette "Record" (P8-24); HK Shift+R. Note: the Figma right-click menu labels it "R"; Decision 22 keeps VLC's Shift+R (plain R is Random in VLC), so the label should read "Shift + R". | PlayerController::toggleRecord | - |

### 1.3 Audio menu (VLCMenuBar::AudioMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Audio Track > (list) | MOVE | Tracks popup > Audio tab > Embedded Tracks (P2-17, Decision 5); RC > Audio > Audio Track; HK b. Right sidebar > Audio tab > Defaults "Audio Track" (P4-15) sets the default, not the live track. | Select audio ES | - |
| Audio Device > (list) | MOVE | Tracks popup > Audio tab > Output Device with refresh (P2-17); Settings > Audio > Output > Output device (P8-11); RC > Audio > Audio Device; HK Shift+A | Select audio output device | - |
| Stereo Mode > (list) (shown if no mix modes) | MOVE | Right sidebar > Audio tab > Defaults > Stereo Mode [Mono] dropdown (P4-15); RC > Audio > Stereo Mode | Stereo mode | - |
| Mix Mode > (list) (replaces Stereo Mode when the output has mix modes) | MOVE | RC > Audio > Mix Mode. Unclear whether the sidebar Stereo Mode dropdown (P4-15) or Settings > Audio > Speaker setup (P8-11) should list mix modes when the output has them. | Audio channel mix mode | - |
| Visualizations > (list) | MOVE | Right sidebar > Playback tab > Audio Visualizer [Disabled] (P4-37, Audio Visualizer.png); RC > Audio > Visualizations | Audio visualization filter | - |
| Increase Volume | MOVE | Cone volume slider 0 to 200% (P2-01, F-04, Decision 7); RC > Audio; HK Ctrl+Up; mouse wheel (Settings > Controls > Mouse > Scroll wheel, P8-08) | setVolumeUp | - |
| Decrease Volume | MOVE | Same as Increase Volume; HK Ctrl+Down | setVolumeDown | - |
| Mute | MOVE | RC > Audio > Mute; HK m; control bar speaker icon (IA-12; Icon.png has a muted variant, but a click-to-mute is never shown) | toggleMuted | - |

### 1.4 Video menu (VLCMenuBar::VideoMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Video Track > (list, multi-select) | MOVE | Tracks popup > Video tab (P2-18); RC > Video > Video Track (named at P2-18) | Select video ES | - |
| 3D Output > (list) | MOVE | RC > Video > 3D Output (only entry) | Video stereo (3D) output mode | - |
| Fullscreen (checkable) | MOVE | Top bar fullscreen button (P2-09, Decision 1); RC > Video > Fullscreen; HK f; double-click (Settings > Controls > Mouse > Double click, P8-08). The old top-level right-click Fullscreen row is not in the new right-click menu (P2-23). | "fullscreen" property | - |
| Always Fit Window (checkable) | MOVE | RC > Video; HK o. Settings > Interface > Window > "Resize window to fit video" (P8-06) is related but may not be the same option. | "autoscale" property | - |
| Set as Wallpaper (checkable) | MOVE | RC > Video; Settings > Video > Output > "Play video as desktop wallpaper" (P8-10); HK w | "wallpaperMode" property | - |
| Zoom > (list) | MOVE | Right sidebar > Video tab > Zoom [1:1 Original] (P4-27); Customize palette "Zoom" (P8-24); RC > Video; HK z / Shift+z, Alt+1..Alt+4 | Video zoom | - |
| Aspect Ratio > (list) | MOVE | Right sidebar > Video tab > Aspect Ratio (P4-27); Settings > Video > Framing > Aspect ratio (P8-10); RC > Video; HK a | Forced aspect ratio | - |
| Crop > (list) | MOVE | Right sidebar > Video tab > Crop (P4-27, Video - Crop.png, F-18); RC > Video; HK c | Crop ratio | - |
| Fit > (list) | MOVE | RC > Video > Fit (only entry) | Video fit mode (smaller / larger / width / height) | - |
| Deinterlace > (list) | MOVE | Settings > Video > Deinterlacing (P8-10); RC > Video; HK d | Deinterlace on / off / auto | - |
| Deinterlace mode > (list) | MOVE | Settings > Video > Deinterlacing > Method (P8-10); RC > Video; HK Shift+D | Deinterlace algorithm | - |
| Take Snapshot | MOVE | Customize palette "Snapshot" (P8-24); RC > Video > Take Snapshot; HK Shift+S | PlayerController::snapshot | - |

### 1.5 Subtitle menu (VLCMenuBar::SubtitleMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Add Subtitle File... | MOVE | Tracks popup > Subtitles tab > External Tracks "+" (P3-05, F-09, Decision 12; until W6.5 it uses VLC's load-subtitle action, Decisions (Claude) W4.2); RC > Subtitle > Add Subtitle File; drag and drop onto the video (P3-03) | DialogsProvider::loadSubtitlesFile | - |
| Sub Track > (list) | MOVE | Tracks popup > Subtitles tab > Embedded / External Tracks (P2-16, P3-04); RC > Subtitle > Sub Track; HK v (Decision 22) | Select subtitle ES | - |

### 1.6 Tools menu (VLCMenuBar::ToolsMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Effects and Filters (Ctrl+E) | MOVE | Right sidebar from the gear (P3-13, P3-17): Video tab filters (P4-30), Audio tab filters (P4-19 to P4-25); RC > More Settings > Effects and Filters; HK Ctrl+E. Until W4.3 to W4.6 land, "Show Preferences" opens this dialog (Decisions (Claude) W4.2). | ExtendedDialog (audio / video effects, sync, v4l2) | - |
| Track Synchronization | MOVE | Right sidebar > Subtitles tab > Synchronization (P3-19, P3-20) and Audio tab > Synchronization (P4-18); RC > More Settings | ExtendedDialog on the Synchronization tab | - |
| Media Information (Ctrl+I) | MOVE | Library file / playlist "..." > Properties & Metadata (F-11, F-12); Customize palette "Properties" (P8-24); library "..." > Info (P5-15); Playback tab "Show Metadata" panel (Decision 24, Step 2 W4.3b); RC > More Settings; HK Ctrl+I | MediaInfoDialog for the current item | - |
| Codec Information (Ctrl+J) | MOVE | RC > More Settings > Codec Information; HK Ctrl+J. No new entry in the video. | MediaInfoDialog on the Codec tab | - |
| VLM Configuration (Ctrl+Shift+W) (ENABLE_VLM builds) | MOVE | RC > More Settings > VLM Configuration; HK Ctrl+Shift+W. Not in the video. | VLMDialog | - |
| Program Guide | MOVE | RC > More Settings > Program Guide (only entry, no hotkey). Not in the video. | EpgDialog (DVB EPG) | - |
| Messages (Ctrl+M) | MOVE | RC > More Settings > Messages; HK Ctrl+M; logging options in Settings > General > Diagnostics (P8-03) | MessagesDialog log viewer | - |
| Plugins and extensions | MOVE | Settings > Extensions page (P8-18), plugin list behind its Advanced Options (P8-20); RC > More Settings. The video's "Plugins & Extensions >" menu row (P2-21, P6-11) is not in the final Figma menu (Decision 2). | PluginDialog | - |
| Customize Interface... | MOVE | main "..." > Customize Player (P8-24, Figma menu); RC > More Settings | Toolbar editor | - |
| Preferences (Ctrl+P) | MOVE | main "..." > Settings Ctrl + P (P8-02, Figma menu); RC > More Settings; HK Ctrl+P | PrefsDialog (to become the new Settings dialog, W6.1) | - |

### 1.7 View menu (VLCMenuBar::ViewMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Play Queue (Ctrl+L, checkable) | MOVE | Control bar queue button (P1-17, P5-02, F-06); mini player queue icon (P5-27); RC > More Settings; HK Ctrl+L | Show / hide the play queue | - |
| Docked Play Queue (checkable) | MOVE | RC > More Settings > Docked Play Queue (former View menu). The redesign queue is always a docked sidebar (Decision 3) or the mini player card (P5-28); see 3.4 "Detached play queue window". | Docked vs detached queue window | - |
| Always on top (checkable) | MOVE | Settings > Interface > Window > "Keep window above other windows" (P8-06); RC > More Settings | MainCtx::setInterfaceAlwaysOnTop | - |
| Big Player View (checkable) | MOVE | Mini player expand icon (P5-27); folder chip, sidebar toggle, compact library open-in-full icon (P5-20, P5-22, P5-25); RC > More Settings | Switch between library and player | - |
| Fullscreen Interface (F11, checkable) | MOVE | RC > More Settings; HK F11. Not in the video. | MainCtx::toggleInterfaceFullScreen | - |
| Minimal View (Ctrl+H, checkable) | MOVE | RC > More Settings > Minimal View; HK Ctrl+H; maybe Settings > Interface > "Start in compact mode" (P8-06). The new right-click "Hide UI" Ctrl + \ (P2-24) does almost the same inside the player; Sticky may want only one of the two. | MainCtx::setMinimalView | - |
| View Items as Grid (checkable) | MOVE | Library toolbar view icon > View Options: Grid View / List View (P5-12, View Options.png); RC > More Settings | MainCtx::setGridView | - |
| Color Scheme > System / Day / Night | MOVE | Settings > General > Appearance > Theme Dark / Light / System (P8-03); onboarding theme tiles (P8-30); RC > More Settings | Color scheme | - |
| Interfaces > (intf-add list, e.g. web, telnet, console) | MOVE | RC > More Settings > Interfaces; Settings > Controls > Remotes > Web remote control (P8-08, web only) | Spawn extra interface modules | - |
| Extensions (entries per active Lua extension, "Empty", "Deactivate") | MOVE | RC > More Settings > Extensions (former View menu); installed add-ons listed in Settings > Extensions (P8-18) | Run Lua extension menu actions (e.g. VLsub) | - |

### 1.8 Help menu (VLCMenuBar::HelpMenu)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Help (F1) | NOT IN VIDEO | Not shown; no Help row in the final main menu. HK F1 stays (Decision 22) but clashes with the core "play bookmark 1" hotkey (Upstream issues). | HelpDialog (help text, links to the docs) | no (HK F1 only, and F1 clashes) |
| Check for Updates... (UPDATE_CHECK builds) | NOT IN VIDEO | Not shown. Settings > General > Startup > "Check for updates automatically" (P8-03) covers the automatic check; the About dialog (main "..." > About VLC) has an Update button. | UpdateModel::checkUpdate(true) | no (About VLC > Update button; automatic-check setting) |
| About (Shift+F1) | KEEP | main "..." > About VLC Shift + F1 (P2-21, P8-27, Figma; Decision 14 wires it to the real About dialog) | AboutDialog | - |

### 1.9 Menu bar containers

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| QML menu bar (Media, Playback, Video, Audio, Subtitle, Tools, View, Help, overflow ">") | MOVE | Restyled once (P2-06), then replaced by the single "..." button (P2-20). Media items go to main "..."; Playback, Video, Audio, Subtitle, Tools, View go to the right-click submenus (P2-23). | Hosts sections 1.1 to 1.8 | - |
| "..." global menu button | KEEP | Top bar "..." (P2-20, Decision 2) with the final Figma content; it can be dragged to the bottom bar in Customize Player (P8-25, P8-26) | Global menu popup | - |

### 1.10 Right-click / popup menus

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Video popup menu (RC): Play/Pause, Stop, Previous, Next, Record, Fullscreen, Audio >, Video >, Subtitle >, Playback >, Tools >, View >, Open Media >, Quit | KEEP | Right-click menu (P2-23, IA-23, right-click menu.png). Tools and View merge into More Settings; Fullscreen leaves the top level (still in RC > Video); Hide UI (P2-24) and Playlist > are added. HK Menu key (Decision 22). | Full player context menu | - |
| Skins/dialog-provider variant of popup | NOT IN VIDEO | Not shown; used only when Qt is the dialog provider for the skins2 interface. Settings > Interface > Skin > "Use a custom skin" stays (P8-06), so skins2 users still need it. | Right-click menu of the skins2 interface | yes (skins2 has no other popup) |
| AudioPopupMenu (Audio menu as popup) | NOT IN VIDEO | Not shown; opened by skins2 / core requests (INTF_DIALOG_AUDIOPOPUPMENU) | Audio menu at the cursor | yes (for skins2 / core requests) |
| VideoPopupMenu (Video menu as popup) | NOT IN VIDEO | Not shown; opened by skins2 / core requests | Video menu at the cursor | yes (for skins2 / core requests) |
| MiscPopupMenu: playback, speed/jump, Open Media, Quit | NOT IN VIDEO | Not shown; opened by skins2 / core requests | Playback / speed / open / quit menu at the cursor | yes (for skins2 / core requests) |
| QmlAudioContextMenu | ? | The right-click menu is only shown over video (P2-23). Right-click on the music player view (P6-04) is never shown; assumed to open the same menu. | Opens the full popup on right-click when there is no video | no for its functions (all reachable elsewhere), but right-click on the music view would do nothing |
| Play queue context menu (Play, Jump to current playing, Stream, Save, Information, Show Containing Directory, Add File, Add Directory, Advanced Open, Save Play Queue to File, Remove Selected, Clear, Sort by, Shuffle, Discard filtered) | MOVE | Queue sidebar header (P1-18, P5-02, IB-19): sort = Sort by, shuffle = Shuffle the play queue, "-" = Remove Selected, "+" = Add File; rows: double-click and drag reorder (P5-24). A row context menu is never shown. No new entry for: Jump to current playing, Stream, Save (convert), Information, Show Containing Directory, Add Directory, Advanced Open, Save Play Queue to File, Clear the play queue, Discard the filtered out items (see Decisions). | Play queue management | - |
| ML media context menu (MLContextMenu): Play, Play as audio, Play as album, Enqueue, Enqueue as album, favorites, add to playlists, Mark as seen / unseen, Open Containing Folder, Delete (streams), Information, Delete File From System, Media Information | MOVE | Library file "..." menu (P6-17, IB-31, F-12): Play, Mark as Watched (= seen / unseen), Favorite (= add / remove favorites), Stream, Convert, Add to Queue (= Enqueue), Add to Playlist, Show in File Explorer (= Open Containing Folder), Go to Source, Add Subtitle Tracks, Add Audio Tracks, Properties & Metadata (= Information). No new entry for: Play as audio, Play as album, Enqueue as album, Delete (streams), Delete File From System (see Decisions). | Media library item actions | - |
| ML playlist list context menu: Add and play, Enqueue, Rename, Delete | MOVE | Playlist "..." menu (F-11): Play, Favorite, Shuffle, Export Playlist, Add to Queue, Add Subtitle Tracks, Add Audio Tracks, Properties & Metadata. Rename and Delete have no shown entry (see Decisions). | Playlist management (rename, delete with confirmation) | - |
| ML playlist content context menu: Add and play, Enqueue, Add to playlist, Play as audio, Information, Remove Selected | MOVE | Rows inside a playlist use the file "..." menu (F-12, F-13): Play, Add to Queue, Add to Playlist, Properties & Metadata. "Play as audio" and "Remove Selected" (remove from this playlist) have no shown entry. | Act on items inside a playlist | - |
| Network media context menu: Add and play, Enqueue, Information, Add to / Remove from Media Library | ? | The "..." of Network rows (P6-07, P6-14) is never opened; assumed to be the file "..." menu (Play, Add to Queue, Properties & Metadata). "Add to Media Library" maps to folder "..." > Add Folder (P5-15) and "+ Add" (P5-29); removing has no shown entry. | Browse / service item actions incl. indexing a folder | no for play / enqueue / info if the file "..." menu applies; yes for "Remove from Media Library" |
| Network device context menu: Add and play, Enqueue, Information | NOT IN VIDEO | Not shown (service / device level) | Play / enqueue / info for a whole device or service | yes (enqueue and info of a whole device; playing by clicking stays) |
| Navigation bar context menu | NOT IN VIDEO | Not shown; the rail (P5-07) and the category rows (Music: Songs, Albums, Artists, Genres, P6-02) reach the same pages | Jump to sub-pages from the side navigation | no |
| Address bar overflow menu (hidden path segments) | KEEP | Compact library breadcrumb "..." truncation; clicking it goes up (P5-23, IB-12, F-14) | Jump to a parent folder | - |
| Service source menu: Configure... | NOT IN VIDEO | Not shown; the Network > Podcasts row exists (P6-07) | Opens the Podcast configuration dialog | no (podcast URL option in the full preferences) |
| Sort menu (library pages), with Video extras: Do not group / Group by name / Group by folder | MOVE | Library toolbar sort icon > Sorting Options (P5-13, Sorting Options.png, 16 items). Video grouping is not shown: folder browsing (P5-16) replaces "group by folder"; "group by name" has no entry. | Sort criteria and order; MainCtx.grouping | - |
| Sort menu Albums extra: Album sections (checkable) | NOT IN VIDEO | Not shown | MainCtx.albumSections (section headers in artist album lists) | yes |
| Bookmark button menu: Titles, Chapters, Bookmarks, Manage, bookmark list | MOVE | Queue sidebar > Bookmarks and Chapters tabs (P7-05, P7-06); Customize palette "Bookmark", "Bookmarks", "Chapters" (P8-24, P8-46); titles in RC > Playback > Title | Title / chapter / bookmark selection | - |
| Program button menu: Programs list | MOVE | RC > Playback > Program; HK x / Shift+X. No Program control in the Customize palette. | Program selection | - |
| Renderer button menu | MOVE | Right sidebar > Video tab > Render (P4-27, Decision 24); RC > Playback > Renderer | Renderer selection | - |
| Subtitle track menu: Open file, Synchronize, Search online, Select multiple (checkable) | MOVE | Tracks popup > Subtitles tab: "+" = Open file (P3-05); "Show Preferences" opens the Subtitles tab with Synchronization (F-07); Add Subtitles "From OpenSubtitles" (P3-07, Step 2 W6.5) replaces Search online (VLsub also stays in RC > More Settings > Extensions). "Select multiple" (dual subtitles) has no shown entry. | Load subtitle, sync page, VLsub, dual subtitles | - |
| Audio track menu: Open file, Synchronize | MOVE | Tracks popup > Audio tab "Show Preferences" opens the Audio tab with Synchronization (P4-18, F-07); library file "..." > Add Audio Tracks (P6-17, F-12) for library files. Loading an external audio track for the playing item from the tracks popup is not shown. | Load an external audio track, audio sync page | - |
| Hotkey table context menu: Modify, Copy value, Unset, Reset, Reset all | MOVE | Keyboard Shortcuts dialog: pencil in each key field = Modify (P7-12, IB-40); Settings > Controls > "Reset all shortcuts" Reset button (P8-08). Copy value, Unset and per-row Reset are not shown. | Edit hotkeys | - |
| Expert prefs context menu: Reset, Toggle, Modify, Copy name, Copy value | NOT IN VIDEO | Not shown; part of VLC's old preferences, which stay reachable behind Advanced Options (BUILD_PLAN section 2) | Reset / toggle / modify / copy any option | no (same options editable in the All tree) |

### 1.11 Systray menu (VLCSystray)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Tray icon (tooltip / notification with now playing on change) | NOT IN VIDEO | Not shown. Settings > Interface has a "Notifications and System Tray" header (P8-06, rows not shown), so the tray is expected to stay. | Show / hide the main window from the tray, track change popup | yes |
| Hide VLC media player in taskbar / Show VLC media player | NOT IN VIDEO | Not shown | Hide / show the main window | yes (only Media > Close to systray, also NOT IN VIDEO) |
| Play/Pause, Stop, Previous, Next, Record | NOT IN VIDEO | Not shown | Playback | no (control bar, right-click, HK) |
| Speed > Faster (fine), Normal Speed, Slower (fine) | NOT IN VIDEO | Not shown | Rate | no (Playback tab Speed, RC > Playback > Speed, HK) |
| Increase Volume, Decrease Volume, Mute | NOT IN VIDEO | Not shown | Volume | no (cone volume, RC > Audio, HK) |
| Open Media | NOT IN VIDEO | Not shown | Full Open Media dialog | no (main "..." > Open File(s), RC > Open Media) |
| Quit | NOT IN VIDEO | Not shown | Quit | no (right-click > Quit VLC, close button, HK Ctrl+Q) |

## 2. Player view

### 2.1 Player top bar (player/qml/TopBar.qml)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Back button | MOVE | A back arrow is explicitly rejected for the player top bar (P5-19). Leaving the player: folder chip and sidebar toggle open the library (P5-20, P5-22), open-in-full icon for the full library (P5-25). | Leave the player view | - |
| VLC cone logo (BannerCone) | KEEP | Flat cone at the top bar left (IA-01, IB-08), recolored by the accent (P8-05); public builds use Sticky's icon (CLAUDE.md) | Decorative | - |
| Media title (left or centered) | KEEP | Centered title (P2-06, P5-20); Settings > Interface > "Show the file name in the title bar" (P8-06) | Shows Player.title | - |
| Menu bar (when pinned controls + menubar) | MOVE | Replaced by "..." (P2-20); see 1.9 | Full menu bar in the player | - |
| "..." menu button (QmlGlobalMenu) | KEEP | Top bar "..." (P2-20) | Global menu | - |
| Play Queue toggle button | MOVE | Control bar queue button, bottom right (P1-17, F-06) | Show / hide the queue in the player | - |
| CSD window buttons (minimize, maximize/restore, close) or themed CSD set | KEEP | Top bar right: minimize, maximize, fullscreen, close (P2-09, IA-16, Decision 1; PiP skipped) | Client-side window decorations | - |
| Title bar drag / double-click to maximize | KEEP | Not shown explicitly, but the redesigned top bar is the window title bar (P2-06, one row with the window buttons), so dragging it must still move the window | Window move / maximize with CSD | - |
| Resume dialog ("restart where you left off", Continue, Dismiss) | MOVE | Toast at bottom center above the control bar: "You already watched till ...", "Continue Watching", "x" (P6-23, IB-35, W3.8); Settings > Playback > Startup > "Continue where you left off" (P8-09) | Player.restorePlaybackPos | - |

### 2.2 Player body

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Video surface (double-click fullscreen, right-click popup, wheel, cursor auto-hide) | KEEP | Inset rounded video area (IA-21, IB-08, W3.7); click / double-click / wheel behavior set in Settings > Controls > Mouse (P8-08); right-click menu (P2-23) | Video rendering and core mouse handling | - |
| Touch drag on video (converted to wheel: volume/seek) | NOT IN VIDEO | Not shown | Touch gesture for volume / seek | no (volume and seek stay reachable; only the touch gesture would be lost) |
| Audio player: blurred artwork background, cover, album, artist labels | KEEP | Music player view: big centered cover, blurred enlarged copy behind, "title - artist" under it (P6-04, IB-23) | Now-playing display for audio | - |
| Audio player: Step back button | MOVE | Music control bar rewind 15 (P6-05, IB-24) | jumpBwd | - |
| Audio player: Visualization toggle | MOVE | Right sidebar > Playback tab > Audio Visualizer (P4-37); RC > Audio > Visualizations | Player.toggleVisualization | - |
| Audio player: Lyrics toggle | NOT IN VIDEO | Not shown; the music view (P6-04) has no lyrics button | MainCtx.lyricsMode (lyrics panel) | yes |
| Audio player: Step forward button | MOVE | Music control bar forward 15 (P6-05, IB-24) | jumpFwd | - |
| Lyrics view with "Sync lyrics to playback" and click-to-seek lines | NOT IN VIDEO | Not shown | Synced lyrics display, seek by clicking a lyric line | yes |
| Volume OSD label "Volume N%" (fades) | NOT IN VIDEO | Not shown as such; the speaker hover tooltip "100 %" (F-03) and the core OSD (Settings > Subtitles > On-Screen Messages, P8-12) show the level | Shows the volume change in the audio view | no |
| Floating notification above control bar | NOT IN VIDEO | Not shown; the resume toast (P6-23) sits in the same place with a new look | Transient player notifications | yes (those messages would not show anywhere) |
| Play queue overlay panel with resize handle | MOVE | Queue sidebar docked right inside the video area, fixed 400 px (P5-02, IA-43, Decision 3, FIGMA_FLOWS specs); no resize handle shown | Play queue inside the player | - |
| Toggle control bar button (expand arrow, interactive / DVD menu mode) | NOT IN VIDEO | Not shown | Shows the hidden control bar while a DVD menu takes the mouse | ? (likely no: the bottom hover zone shows the bar, Decision 4; must be tested with a DVD menu where the video output takes the mouse, BUILD_PLAN risk 2) |
| Navigation box (DVD navigation: Close, Up, Left, Select, Right, Down) | NOT IN VIDEO | Not shown; no palette item | DVD / BD menu navigation with the mouse | no (HK arrows / Enter, clicking the disc menu on the video) |
| Dialogs layer (login, question, progress, error popups) | NOT IN VIDEO | Not shown | Core vlc_dialog requests | yes (the core would have no UI for them) |
| Mouse Back button returns to library | NOT IN VIDEO | Not shown | MainCtx.playerView = false | no (folder chip, sidebar toggle) |
| Auto-hide of top bar / control bar (FSM) | KEEP | Per-bar hover show / hide, instant (P2-08, IA-15, Decision 4), hidden while playing (P3-11); Settings > Interface > Playback Controls: Auto-hide the controls, Hide after, Show controls in fullscreen (P8-06) | Hide controls during playback | - |

### 2.3 Control bar fixed parts (player/qml/ControlBar.qml)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Elapsed time label | KEEP | Current time right of Next (P2-03); hover and click-to-edit jump (F-02) | Player.time | - |
| Remaining/total time label (click toggles; tooltip with speed-adjusted remaining) | KEEP | Total time; click toggles remaining "-00:23:30" (F-01). The speed-adjusted remaining-time tooltip is not shown. | MainCtx.showRemainingTime | - |
| Seek slider (click/drag, hover time with chapter name, chapter marks, A-B markers, wheel, Left/Right keys) | KEEP | Thick seek bar (P2-02, IA-13), hover thumbnail with time (P2-04, Decision 6, Step 2 W3.3b), chapter segments (IB-46). A-B markers, the chapter-name tooltip and arrow keys are not shown (keep them); the wheel over the seek bar is removed (Decision 54: over the bars only the volume control takes the wheel). | Seek, chapters, jumpFwd / jumpBwd | - |
| Bookmarks strip above slider | MOVE | Queue sidebar > Bookmarks tab lists and jumps (P7-05). Ticks on the seek bar are not shown (INTERACTIONS.md section 5 plans a bookmark-marks layer). | MLBookmarkModel::select | - |
| Configurable button rows (left / center / right) | KEEP | Control bar zones, edited in Customize Player (P8-24 to P8-26; the alternate layout uses left / center / right) | Hosts the controls of 2.4 | - |

### 2.4 Control bar control types (control_list_model.hpp, PlayerControlbarControls.qml, controlbarcontrols/*)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| PLAY_BUTTON "Play" | KEEP | Orange / gray pill at the left of the bar (P1-14, P2-12, IA-17) | togglePlayPause | - |
| STOP_BUTTON "Stop" | KEEP | Customize palette "Stop" (P8-24); not in the default bar (P1-14) | MainPlaylistController.stop | - |
| OPEN_BUTTON "Open" | NOT IN VIDEO | Not in the default bar or the palette (P8-24) | DialogsProvider.openDialog | no (main "..." > Open File(s), RC > Open Media, HK Ctrl+O) |
| PREVIOUS_BUTTON "Previous" | KEEP | Previous left of play (P1-14, IA-08) | prev | - |
| NEXT_BUTTON "Next" | KEEP | Next right of play (P1-14, IA-08) | next | - |
| SLOWER_BUTTON "Slower" | NOT IN VIDEO | Not in the palette; the palette has "Playback Speed" instead | Player.slower | no (Playback tab Speed, palette Playback Speed, RC > Playback > Speed, HK "-") |
| FASTER_BUTTON "Faster" | NOT IN VIDEO | Not in the palette; the palette has "Playback Speed" instead | Player.faster | no (Playback tab Speed, palette Playback Speed, RC > Playback > Speed, HK "+") |
| FULLSCREEN_BUTTON "Fullscreen" | KEEP | Top bar (P2-09, Decision 1); movable to the bottom bar (P8-26) | Player.fullscreen toggle | - |
| EXTENDED_BUTTON "Extended panel" | MOVE | The gear-with-play button opens the right sidebar on the Playback tab (P3-13, P3-17, Decision 5, Decision 19) | DialogsProvider.extendedDialog | - |
| PLAYLIST_BUTTON "Play Queue" | KEEP | Queue button bottom right (P1-17, P5-02) | Toggle the queue panel | - |
| SNAPSHOT_BUTTON "Snapshot" | KEEP | Customize palette "Snapshot" (P8-24) | Player.snapshot | - |
| RECORD_BUTTON "Record" | KEEP | Customize palette "Record" (P8-24) | Player.toggleRecord | - |
| ATOB_BUTTON "A-B Loop" | NOT IN VIDEO | Not in the bar or the palette | Player.toggleABloopState | yes (no menu entry and no default hotkey; see Upstream issues) |
| FRAME_PREV_BUTTON ("Next Frame" label, loads FrameNextButton.qml) | NOT IN VIDEO | Not in the palette. Onboarding lists "Previous / Next Frame , ." (P8-31), but Decision 22 keeps VLC's keys. Base swaps the two ids (Upstream issues). | Player.frameNext | no (HK e) |
| FRAME_NEXT_BUTTON ("Previous Frame" label, loads FramePrevButton.qml) | NOT IN VIDEO | Not in the palette (same notes as the row above) | Player.framePrev | no (HK Shift+E) |
| REVERSE_BUTTON "Trickplay Reverse" | ? | Its successor is the Playback tab "Reverse" toggle (P4-33), which is postponed (Decision 29). Not in the palette. | Player.reverse (negative rate; refused by most inputs) | yes until the Reverse toggle is built (no menu, no hotkey) |
| SKIP_BACK_BUTTON "Step backward" | KEEP | Customize palette "Backward 10s" / "Backward 15s" (P8-24, P8-46); music bar rewind 15 (P6-05) | Player.jumpBwd | - |
| SKIP_FW_BUTTON "Step forward" | KEEP | Customize palette "Forward 10s" / "Forward 15s"; music bar forward 15 (P6-05) | Player.jumpFwd | - |
| QUIT_BUTTON "Quit" | KEEP | Customize palette "Quit VLC" (P8-24) | MainCtx.close | - |
| RANDOM_BUTTON "Random" | KEEP | Customize palette "Shuffle" (P8-46); queue header shuffle (P1-18) | toggleRandom | - |
| LOOP_BUTTON "Loop" | KEEP | Customize palette "Repeat" (P8-46); queue header repeat (P1-18) | toggleRepeatMode | - |
| INFO_BUTTON "Information" | KEEP | Customize palette "Properties" (circled i, P8-24, P8-46; assumed to be media information) | mediaInfoDialog | - |
| LANG_BUTTON "Open subtitles" / "Languages and tracks" | MOVE | Split into the audio and subtitle buttons at the bottom right; both open the tracks popup on their tab (P2-15 to P2-17, Decision 5) | TracksMenu | - |
| MENU_BUTTON "Menu" (deprecated) | KEEP | "..." is a movable bar item, dragged to the bottom bar in the alternate layout (P8-25, P8-26) | QmlGlobalMenu popup | - |
| BACK_BUTTON "Back" (deprecated) | NOT IN VIDEO | Not in the palette; "Go Home" (house, P8-46) goes to the library home, not back in history | History.previous | no (folder chip, sidebar toggle, library back arrow P5-08) |
| CHAPTER_PREVIOUS_BUTTON "Previous chapter" | NOT IN VIDEO | Not in the palette (palette "Chapters" is the list) | chapterPrev | no (Chapters tab, RC > Playback, HK Shift+P) |
| CHAPTER_NEXT_BUTTON "Next chapter" | NOT IN VIDEO | Not in the palette | chapterNext | no (Chapters tab, RC > Playback, HK Shift+N) |
| PLAYER_SWITCH_BUTTON "Switch Player" | MOVE | Mini player expand icon (P5-27); folder chip and sidebar toggle (P5-20, P5-22) | MainCtx.playerView toggle | - |
| ARTWORK_INFO "Artwork Info" | MOVE | Mini player card: preview, filename, folder chip (P5-27); Customize palette "Thumbnail", "File Name", "Artist Name" (P8-24) | Open the player, drag the current item | - |
| PLAYBACK_SPEED_BUTTON "Playback Speed" | KEEP | Customize palette "Playback Speed" (P8-24); Playback tab Speed slider (P4-31) | Player.rate | - |
| HIGH_RESOLUTION_TIME_WIDGET "High Resolution Time" (SMPTE timecode) | NOT IN VIDEO | Not in the palette | Player.requestAddSMPTETimer (frame-accurate timecode) | yes (control bar only; see Upstream issues) |
| VOLUME "Volume Widget" | KEEP | Speaker icon + cone slider (P2-01, IA-12, F-03, F-04) | Player.volume / muted | - |
| TELETEXT_BUTTONS "Teletext" | NOT IN VIDEO | Not in the palette | teletextEnabled / Transparency / Page | yes (control bar only; see Upstream issues) |
| ASPECT_RATIO_COMBOBOX "Aspect Ratio" | MOVE | Right sidebar > Video tab > Aspect Ratio (P4-27); not in the palette | Player.aspectRatio | - |
| DVD_MENUS_BUTTON "DVD menus" | NOT IN VIDEO | Not in the palette | Player.sectionMenu (disc root menu) | no (HK Shift+M only) |
| BOOKMARK_BUTTON "Bookmark Button" | KEEP | Customize palette "Bookmark" / "Bookmarks" (P8-46) | QmlBookmarkMenu | - |
| RENDERER_BUTTON "Renderer Button" | MOVE | Right sidebar > Video tab > Render (P4-27, Decision 24) | QmlRendererMenu | - |
| NAVIGATION_BUTTONS "Navigation" (DVD menu / Program / Teletext) | NOT IN VIDEO | Not in the palette | Shows the three when available | yes (its teletext part; DVD menu and program have hotkeys) |
| PROGRAM_BUTTON "Program Button" | NOT IN VIDEO | Not in the palette | QmlProgramMenu | no (RC > Playback > Program, HK x) |
| NAVIGATION_BOX "Navigation Box" | NOT IN VIDEO | Not in the palette | MainCtx.navBoxToggled | no (HK navigation keys) |
| WIDGET_SPACER "Spacer" | KEEP | Customize palette "Spacer" (P8-24) | Layout spacing | - |
| WIDGET_SPACER_EXTEND "Expanding Spacer" | NOT IN VIDEO | The palette shows "Spacer" and "Divider" only; unknown whether her Spacer expands | Layout spacing | no (layout only) |
| Fallback "WIDGET NOT FOUND" | NOT IN VIDEO | Internal placeholder | Placeholder for unknown ids | no (no user function; keep for safety) |

### 2.5 Tracks menu (LangButton popup, player/qml/TracksMenu.qml)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Playback speed shortcut button ("1x") | MOVE | Right sidebar > Playback tab > Speed (P4-31) | Pushes the speed page | - |
| Subtitle column: track list + "Menu" button | MOVE | Tracks popup > Subtitles tab (P2-16, P3-04, IA-18) | Select subtitle tracks; QmlSubtitleMenu | - |
| Audio column: track list + "Menu" button | MOVE | Tracks popup > Audio tab (P2-17) | Select audio track; QmlAudioMenu | - |
| Video Tracks column: track list + "Add" button | MOVE | Tracks popup > Video tab (P2-18). "Add" (load a video file as an extra track) has no shown entry. | Select video track; DialogsProvider.loadVideoFile | - |
| Back button on sub-pages | NOT IN VIDEO | The tracks popup has tabs, no sub-pages | Return to the list page | no (navigation only) |
| Audio sync page: delay, Reset, "Sound Heard" / "Sound Spotted" | MOVE | Right sidebar > Audio tab > Synchronization > Audio Track Delay + slider (P4-18); HK j / k. Reset and the "heard / spotted" estimator are not shown. | Player.audioDelayMS, addAudioDelay | - |
| Subtitle sync page: primary delay + estimator, secondary delay + estimator, Subtitle Speed | MOVE | Right sidebar > Subtitles tab > Synchronization: Subtitle Track Delay, Subtitle Speed, Subtitle Duration Factor (P3-19, P3-20); Settings > Subtitles > Timing (P8-12); HK g / h, Shift+H/J/K, Ctrl+Shift+K. The secondary subtitle delay and the on-screen estimator are not shown. | subtitleDelayMS, secondarySubtitleDelayMS, subtitleFPS | - |
| Speed page | MOVE | Right sidebar > Playback tab > Speed (P4-31) | PlaybackSpeed control | - |

### 2.6 Default toolbar profiles (dialogs/toolbar/controlbar_profile_model.cpp)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Empty Style | NOT IN VIDEO | Built-in toolbar profiles are not shown; main "..." > Profile (P8-27) holds user profiles (Movies, Shows, Music, Work, + New) | Empty layout preset | no (Customize Player can empty the bar) |
| Default Style | MOVE | Replaced by the redesign default layouts: video bar (P2-03, P5-01, fullscreen in the top bar per Decision 1), music bar (P6-05), mini player card (P5-27) | Default layout preset (video / audio / mini) | - |
| Minimalist Style | NOT IN VIDEO | Not shown (see Empty Style) | Layout preset | no (rebuildable in Customize Player) |
| One-liner Style | NOT IN VIDEO | Not shown (see Empty Style) | Layout preset with Record, Snapshot, A-B, frame step | no, except its A-B and frame-step buttons (see 2.4) |
| Simplest Style | NOT IN VIDEO | Not shown (see Empty Style) | Layout preset | no (rebuildable in Customize Player) |
| Classic Style | NOT IN VIDEO | Not shown; onboarding has no layout choice (P8-29 to P8-31) | Layout preset; first run "Classic" layout | no (rebuildable in Customize Player) |

### 2.7 Mini player, PIP, minimal view

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Mini player (bottom bar in library view) | MOVE | Mini player card at the bottom right of the full library, with a queue card, draggable to the corners (P5-27, P5-28, IB-18, F-17) | Playback control while browsing | - |
| PIP player (floating video thumbnail in library) | MOVE | Merged into the same mini player card: video preview, close, expand, prev / play / next on hover (P5-27, IB-18). The separate Picture-in-Picture window is skipped (Decision 1). | Watch video while browsing | - |
| Minimal view (video or cone only) | MOVE | RC > More Settings > Minimal View, HK Ctrl+H; the new right-click "Hide UI" Ctrl + \ (P2-24, P2-25) covers the same need inside the player | Chrome-less window | - |

## 3. Main library interface

### 3.1 Window chrome and navigation

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Side navigation pane (collapsible) | MOVE | Library icon rail + panel (P5-07, P5-23, P6-18 to P6-20); sidebar toggle (P5-22) | Switch top-level views | - |
| Nav: Home | KEEP | Rail Home (P6-20, P6-21, P8-38) | HomeDisplay / NoMedialibHome | - |
| Nav: Video > All, Playlists (ML only) | MOVE | Rail Videos, folder based (P5-16, P5-29); video playlists in rail Playlists (P6-15). A flat list of all indexed videos is not shown (see Decisions). | VideoDisplay tabs | - |
| Nav: Music > Artists, Albums, Tracks, Genres, Playlists (ML only) | MOVE | Rail Music > Songs, Albums, Artists, Genres (P6-02); playlists in rail Playlists (P6-15) | MusicDisplay tabs | - |
| Nav: Browse | NOT IN VIDEO | Shown only as the old VLC 4 problem (P5-04). In the final design Network = streams (Podcasts, Radio, saved m3u, P6-07, P6-14), and Videos / Music hold user folders (P5-29). | BrowseDisplay: local drives, removable devices, LAN shares (SMB, UPnP, ...) | yes (browsing LAN shares and devices; single URLs still open via Open Network Stream) |
| Nav: Discover > Services, URL | MOVE | Services: rail Network rows Podcasts, Radio (P6-07). URL: main "..." > Open Network Stream (P6-13) and saved streams under Network (P6-14). | DiscoverDisplay | - |
| Nav: Preferences button (bottom of sidebar) | MOVE | main "..." > Settings (P8-02); the rail bottom now holds "+" for pins (P6-18) | prefsDialog | - |
| "mlsettings" route to MLFoldersSettings.qml | NOT IN VIDEO | Dead route at base, the file does not exist (Upstream issues) | none | no (no working function; ML folders via "+ Add", P5-29) |
| Local top bar: Show navigation menu (hamburger) | MOVE | Sidebar toggle icon in the player top bar (P5-22, IB-11); the full library always shows its sidebar (P5-26) | Toggle the sidebar | - |
| Local top bar: Previous (back in history) | MOVE | Library back / forward arrows by the breadcrumb (P5-08, IA-45) | History.previous | - |
| Local top bar: logo, Play queue toggle, "..." menu, CSD buttons | KEEP | Full library top bar: cone, "...", window buttons (P5-26, P6-21); the queue toggle moves to the mini player queue icon (P5-27) | see 1.9, 2.1 | - |
| Menu top bar (menu bar row) | MOVE | Replaced by "..." (P2-20); see 1.9 | Menubar.qml | - |
| Drag and drop files/URLs onto window | KEEP | Drop onto the player (P3-03) and into the queue (P1-18, P5-24) | Enqueue / play dropped media | - |
| Ctrl+wheel / Ctrl+= / Ctrl+- interface zoom | NOT IN VIDEO | Not shown; the shortcuts stay (Decision 22) | Interface scale factor | no (shortcuts; scale factor in the full preferences) |
| Update pane (new version / latest / error / checking; Details, Re-check, Download, Dismiss) | NOT IN VIDEO | Not shown | Shows the update check result, Download | yes (the automatic check in Settings > General, P8-03, would have nowhere to show its result) |
| Scan progress bar ("Scanning %1" / "Indexing Medias (%)") | NOT IN VIDEO | Not shown | ML scan / indexing status | yes |
| Floating notification (library) | NOT IN VIDEO | Not shown | Transient messages | yes (those messages would not show) |
| Small-screen overlay dismiss | NOT IN VIDEO | Not shown | Hide side panels on small windows | no (layout helper) |
| Play queue resize handle | NOT IN VIDEO | The queue panel is a fixed 400 px (FIGMA_FLOWS specs) | Resize the docked queue | no (the queue stays usable) |

### 3.2 Common page header toolbar (widgets/qml/PageExt.qml, GridSortFilterControls.qml)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Page title label | KEEP | Breadcrumb last segment / "Home" (P5-08, P8-38) | Current view name | - |
| List/Grid toggle | KEEP | View icon > Grid View / List View (P5-12, View Options.png) | MainCtx.gridView | - |
| Sort button (SortControl) | KEEP | Sort icon > Sorting Options (P5-13) | Sort criteria / order per page | - |
| Filter search box (Case sensitive, Use regular expression, Clear) | KEEP | Search field; magnifier only in the compact library (P5-14, IB-02). Case-sensitive and regular-expression options are not shown. | Filter the current view | - |
| Tab bar for sub-views (BannerTabButton) | MOVE | Category rows inside the panel (Music: Songs, Albums, Artists, Genres, P6-02) and the rail | Sub-view switch | - |
| Empty state label with "Browse" button | MOVE | "+ Add" rows (P5-29, P6-02), "+ Add Network Stream" (P6-07), "+ Create playlist" (P6-15), empty Home placeholder card (P8-38) | Go to Browse to add sources | - |

### 3.3 Library views

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Home: Continue Watching row (See All) | KEEP | Home > Continue Watching (P6-20, P6-21, IB-34) | Resume recent videos | - |
| Home: Favorites row (See All) | NOT IN VIDEO | Home sections are Continue Watching, Listen Again, Frequently Visited Folders, Frequently Visited Playlists, Frequently Listened Artists, Latest Streams (P6-20, F-15, Decision 8). Favorite can be set (file "..." > Favorite, palette Favorite) but no list of favorites is shown. | List of favorited media | yes |
| Home: New Videos row (See All) | NOT IN VIDEO | Not shown | Recently added videos | no (Videos with Sorting > Newest First, P5-13) |
| Home: New Music row (See All) | NOT IN VIDEO | Not shown | Recently added music | no (Music > Songs with Newest First) |
| Home sort: Alphabetic, Duration | KEEP | Home toolbar sort icon (P6-20, P6-21) | Sorting | - |
| No-ML Home: cone, "Open File", "Open Disc" | NOT IN VIDEO | Not shown; Home without the media library (Settings > Library > "Use the media library" OFF, P8-14) is never shown | simpleOpenDialog, openDiscDialog | no (main "..." > Open File(s), Open Disc) |
| Video > All (grid/list; groups; sort; columns) | MOVE | Videos folder view, grid and list (P5-16, P5-17, P5-26); sort / view / search (P5-11) | Browse indexed videos | - |
| Video group view ("Videos") | NOT IN VIDEO | Folder drill-down (P5-16) replaces "group by folder"; "group by name" is not shown | Contents of a video group | yes (name grouping only) |
| Video grid item: thumbnail, quality badges, watched progress, play overlay, "..." | KEEP | 16:9 thumbnails with progress line (P5-17, IB-06), "..." on hover (F-13). Quality badges (HD / 4K) are not shown. | Play / context menu | - |
| Video expand info panel (Play, Enqueue, Close, file name, path, tracks) | NOT IN VIDEO | Not shown | Inline media info | no (file "..." > Properties & Metadata, Play, Add to Queue) |
| Video > Playlists (video-only playlists) | MOVE | Rail Playlists, one list for all (P6-15) | Playlist management | - |
| Music > Artists | KEEP | Music > Artists (P6-02, P6-03) | Artist list | - |
| Music > Artist detail: banner Play all / Enqueue all; albums row; tracks table; Album sections | MOVE | Artists > artist shows its songs (P6-03). Play all / Enqueue all and the albums row are not shown (row "..." menus act on one item). | Play an artist, browse albums | - |
| Music > Albums | KEEP | Music > Albums (P6-02) | Album list | - |
| Album expand panel: Play, Enqueue, Close Panel, track list | NOT IN VIDEO | Not shown; albums presumably drill down like artists (P6-03) | Play an album / its tracks | no (drill-down + row "..." menus) |
| Album section header in lists: Play, Enqueue, Prev, Next | NOT IN VIDEO | Not shown | Album section navigation | no |
| Music > Tracks | KEEP | Music > Songs (P6-01, P6-02) | Track list | - |
| Music > Genres and "Genres - X" detail | KEEP | Music > Genres (P6-02) | Genre browse | - |
| Music > Playlists (audio-only playlists) | MOVE | Rail Playlists (P6-15) | Playlist management, drop media to add | - |
| Playlist detail (Title, Duration; drag reorder; "Processing...") | KEEP | Opening a playlist from rail Playlists (P6-15; rows F-13). Its content view and drag reorder are not shown. | Edit playlist content | - |
| Generic media view (See All target) | MOVE | Home section ">" chevrons (P6-20, IB-33) | Flat list of media | - |
| Discover > URL: URL field + recent URL table | MOVE | main "..." > Open Network Stream (P6-13); saved streams under Network (P6-14); Home Latest Streams (F-15, Decision 8); rail Recent (P6-19) | Open a network URL; stream history | - |
| Discover > Services: sources, "Add a service", per-source Configure... | MOVE | Rail Network > Podcasts, Radio (P6-07); service add-ons via Settings > Extensions > Find more extensions (P8-18) | Service discovery modules | - |
| Discover > Install services (addon list) | MOVE | Settings > Extensions page (P8-18, P8-20) | Addons manager for SD addons | - |
| Browse home: Folders, Computer, Devices, Network sections | NOT IN VIDEO | Not in the final design (see Nav: Browse) | Local folders, drives, LAN shares | yes (drives, devices and LAN shares browsing) |
| Browse tree: address bar, "Add to / Remove from medialibrary", grid/list, sort, columns, empty text | MOVE | Library breadcrumb, sort, view, search (P5-08, P5-11); "Add to medialibrary" = folder "..." > Add Folder (P5-15) and "+ Add" (P5-29). "Remove from medialibrary" has no shown entry. | File system / share browsing and ML indexing | - |
| Network grid/thumbnail items with play overlay | KEEP | Library rows and grid items (P5-17, P6-07, F-13) | Play an item | - |

### 3.4 Play queue panel (playlist/qml/PlaylistPane.qml)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| "Play Queue" title | MOVE | Queue sidebar tab "Queue" (P7-05, Decision 3); mini player queue card title "Queue" (P5-28) | Label | - |
| Sort control | KEEP | Queue header sort icon (P1-18, IB-19) | MainPlaylistController.sort | - |
| Filter search box | NOT IN VIDEO | The queue header has no search (P1-18, IB-19) | Filter the queue, then "Discard the filtered out items" | yes |
| Summary "N elements, duration" | KEEP | "2 items - 48m" (P1-18, IB-19) | Count / duration | - |
| Column header (Cover, Title, Duration) | NOT IN VIDEO | Rows show filename and duration with no header (P1-18) | Labels only | no |
| Queue item delegate (cover, playing indicator, title, artist, duration; select; double-click; drag; drop) | KEEP | Rows with drag handle, filename, duration, playing row orange (P1-18, IB-19); drop media in (P5-24). Cover and artist are not shown. | goTo, insert, move | - |
| Empty states ("No content yet", "No results", "Drag & Drop some content here!") | NOT IN VIDEO | Not shown | Hint text | no |
| Play queue toggle button component | KEEP | Control bar queue button (P1-17); mini player queue icon (P5-27) | Show / hide the queue | - |
| Detached play queue window | NOT IN VIDEO | Not shown; the queue is a sidebar everywhere (Decision 3) or the mini player card | Undocked queue window | yes (goes together with View > Docked Play Queue) |

## 4. Dialogs

### 4.1 Open Media dialog (dialogs/open/*)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| File tab: file list, Add..., Remove, "Use a subtitle file" + Browse... | MOVE | main "..." > Open File(s) (several files, P6-11), its own dialog per P6-12 (W6.4). The subtitle-with-file option has no shown entry; the tracks popup "+" adds one after opening (P3-05). | Pick files and an external subtitle | - |
| Disc tab (DVD / Blu-ray / Audio CD / SVCD-VCD, device, no disc menus, start title/chapter, tracks) | MOVE | main "..." > Open Disc, its own dialog (P6-12, W6.4); content not shown | Disc playback options | - |
| Network tab: URL combobox with history, Clear History | MOVE | Open Network Stream dialog (P6-13: several URLs, optional playlist name). URL history and Clear History are not shown. | Network MRL | - |
| Capture Device tab (DirectShow, TV, Desktop, ... and per-mode fields) | MOVE | main "..." > Open Capture Device, its own dialog (P6-12, W6.4); content not shown | Capture inputs | - |
| Show more options: Caching, Start Time, Stop Time, MRL, Edit Options, "Play another media synchronously" | NOT IN VIDEO | Not shown in the split dialogs (only Network is shown, P6-13); global caching is in Settings > Network > Buffering (P8-15) | Per-input options (:start-time, :stop-time, :input-slave, custom options) | yes (per-input start / stop time, extra synchronous media, custom options) |
| Play button with dropdown: Enqueue, Play, Stream, Convert; Cancel; Select | MOVE | Dialog Cancel / Save (P6-13). Enqueue: queue "+", drag to the queue, file "..." > Add to Queue (P1-18, P5-24, F-12; P6-09 calls Enqueue redundant). Stream: file "..." > Stream, HK Ctrl+S. Convert: main "..." > Convert. | Final open action | - |
| Advanced Options sub-dialog (OK / Cancel) | NOT IN VIDEO | Not shown | Module-specific capture options | yes |

### 4.2 Convert dialog (dialogs/sout/convert.cpp)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Source MRL (or "Multiple files selected.") | NOT IN VIDEO | The Convert dialog content is never shown (its entry, main "..." > Convert, is KEEP) | Display only | no |
| Settings: Convert / Dump raw input, Display the output, Deinterlace | NOT IN VIDEO | Dialog content not shown | Transcode vs dump | yes |
| Profile selector: profile combo, Edit / Delete / New profile | NOT IN VIDEO | Dialog content not shown (not related to main "..." > Profile, which is a VLC-wide profile) | Transcoding profiles (25 built-ins) | yes |
| Profile edition dialog (encapsulation, video / audio / subtitle codecs, name) | NOT IN VIDEO | Dialog content not shown | Custom transcoding profiles | yes |
| Destination file + Browse, "Append '-converted' to filename" | NOT IN VIDEO | Dialog content not shown | Output path | yes |
| Start / Cancel | NOT IN VIDEO | Dialog content not shown | Run the conversion | yes |

### 4.3 Stream Output wizard (dialogs/sout/*)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Source page (Source, Type) | NOT IN VIDEO | The wizard content is never shown (entries: file "..." > Stream, HK Ctrl+S) | Display only | no |
| Destination Setup (File, HTTP, MMSH, RTSP, SRT, RIST, RTP, UDP, Icecast; fields; Display locally) | NOT IN VIDEO | "Display locally" matches Settings > Recording > Streaming > "Play locally while streaming" (P8-17); destinations are not shown | sout chain destinations | yes (choice of destination) |
| Transcoding Options: Activate Transcoding + profile selector | NOT IN VIDEO | Settings > Recording > Streaming has Encoding preset, Tuning, Include audio / video / subtitles (P8-17), not a profile selector | Transcode while streaming | yes (per-stream profile) |
| Option Setup: Stream all elementary streams, generated sout string | NOT IN VIDEO | Not shown | Raw sout chain | yes |
| Back / Next / Stream / Cancel | NOT IN VIDEO | Not shown | Wizard navigation | yes |

### 4.4 Bookmarks dialog (dialogs/bookmarks/bookmarks.cpp)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Bookmark list (description, time; editable) | MOVE | Queue sidebar > Bookmarks tab: name + time rows (P7-05, IB-37). Renaming a bookmark is not shown. | ML bookmarks of the current media | - |
| Create, Delete, Clear, Extract, Close | MOVE | Bookmarks tab "+" = Create, "-" = Delete (P7-05); Ctrl+B creates instantly (Decision 22, Step 2 W4.8b). Clear and Extract are not shown. | Bookmark management, extract a segment | - |

### 4.5 Adjustments and Effects (dialogs/extended/*)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Audio Effects > Equalizer: Enable, 2 Pass, Preset, Preamp, 10 bands | MOVE | Right sidebar > Audio tab > Filters > Equalizer, presets with curve icons, 2 Pass (P4-19, P4-24, P4-25); Settings > Audio > Effects (P8-11, P8-44) | equalizer filter | - |
| Audio Effects > Compressor | MOVE | Audio tab > Compressor (P4-22, Audio - Compressor Settings.png) | compressor filter | - |
| Audio Effects > Expander | NOT IN VIDEO | The Audio tab shows Equalizer, Compressor, Spatializer, Stereo Widener, Adjust Pitch only (P4-19) | expander filter | no (full preferences) |
| Audio Effects > Limiter | NOT IN VIDEO | Not in the Audio tab (P4-19) | limiter filter | no (full preferences) |
| Audio Effects > Spatializer | MOVE | Audio tab > Spatializer (P4-19, Audio - Spatializer Settings.png) | spatializer | - |
| Audio Effects > Stereo Widener | MOVE | Audio tab > Stereo Widener (P4-19); Settings > Audio > Stereo widening (P8-11) | stereo widener | - |
| Audio Effects > Advanced: Adjust pitch, Adjust pan | MOVE | Audio tab > Adjust Pitch "4.0 semitones" (P4-19). Adjust pan is not shown. | pitch shift, stereo pan | - |
| Video Effects > Essential (image adjust, sharpen, banding removal, film grain) | MOVE | Right sidebar > Video tab > Filters > Essential (P4-30, Video - Essential.png); Settings > Video > Picture (P8-10) | adjust, sharpen, gradfun, grain | - |
| Video Effects > Crop (Top / Bottom / Left / Right, synchronize) | MOVE | Video tab > Crop with Top / Bottom / Left / Right and the link toggle (P4-27, Video - Crop.png, F-18) | croppadd | - |
| Video Effects > Colors | MOVE | Video tab > Filters > Colors (P4-30, Video - Colors.png) | color filters | - |
| Video Effects > Geometry: Interactive Zoom, Wall, Transform, Rotate, Puzzle game | MOVE | Video tab > Flip None / Horizontal / Vertical and Rotate (P4-27). Interactive Zoom, Wall and Puzzle are not shown. | geometry filters | - |
| Video Effects > Overlay: Add logo, Add text, Logo erase | NOT IN VIDEO | Not shown | logo, marq, erase filters | no (full preferences) |
| Video Effects > Advanced: Anaglyph 3D, Mirror, Psychedelic, Waves, Water, Motion detect, blurs, Anti-Flickering, Soften, Denoiser, Clone | NOT IN VIDEO | Not shown | misc video filters | no (full preferences) |
| Synchronization tab (audio, primary / secondary subtitle, subtitle speed, duration factor) | MOVE | Subtitles tab > Synchronization (P3-19), Audio tab > Synchronization (P4-18); Settings > Subtitles > Timing (P8-12). Secondary subtitle sync is not shown. | Delays and subtitle timing | - |
| v4l2 controls tab | NOT IN VIDEO | Not shown | Live camera controls | yes |
| Save / Close | MOVE | Right sidebar preset footer saves the settings (P4-04, Decision 18, Step 2 W4.7); Settings pages hold the defaults (P8-10, P8-11) | Persist filter config | - |

### 4.6 Media Information (dialogs/mediainfo/*)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| General tab: meta fields, artwork, Fingerprint button | MOVE | Library file / playlist "..." > Properties & Metadata (F-11, F-12), palette "Properties" (P8-24), Playback tab "Show Metadata" panel (Decision 24, Step 2 W4.3b). Their content is never shown; assumed to be this dialog. | Edit metadata, audio fingerprinting | - |
| Metadata tab: extra metadata table | MOVE | Same entries as the General tab | Extra meta | - |
| Codec tab: streams and codec details | NOT IN VIDEO | Content not shown (dialog reached via RC > More Settings > Codec Information, HK Ctrl+J) | Elementary stream / codec details | yes |
| Statistics tab (input, video, audio counters, graph) | MOVE | Playback tab "Show Statistics" toggle (F-23, Decision 13, Step 2 W4.3b) | Playback statistics | - |
| Location field, Save Metadata, Close | NOT IN VIDEO | Not shown | Save metadata to the file | yes (saving edited metadata) |
| Audio Fingerprinting dialog | NOT IN VIDEO | Not shown | AcoustID lookup to fill metadata | yes |

### 4.7 Messages (dialogs/messages/*)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Messages tab: log view, Verbosity, Filter, Save as..., Clear | NOT IN VIDEO | Dialog content not shown (reached via RC > More Settings > Messages, HK Ctrl+M); Settings > General > Diagnostics: Save a log, Log file, Log details (P8-03) | Live log viewer | no (log file via Settings > General > Diagnostics; no live view) |
| Errors tab (Clear the errors) | NOT IN VIDEO | Dialog content not shown | Error list | no (errors are in the log file) |
| Modules Tree tab (Update the tree) | NOT IN VIDEO | Dialog content not shown | Live object / module tree | yes |
| Close | NOT IN VIDEO | Dialog content not shown | Close the dialog | no |

### 4.8 Plugins and extensions (dialogs/plugins/plugins.cpp)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Addons Manager tab (categories, Only installed, search, Find more addons online, Install / Uninstall, More information) | MOVE | Settings > Extensions: list, Search, Find more extensions, Add, Remove (P8-18) | Addons repository | - |
| Active Extensions tab (list, More information, Reload extensions) | MOVE | Settings > Extensions list and "Load extensions on startup" (P8-18). Reload extensions and More information are not shown. | Lua extensions | - |
| Plugins tab (Search, Name / Capability / Score) | MOVE | Settings > Extensions > Advanced Options (P8-20) | Module list | - |
| About plugin / addon info dialogs | NOT IN VIDEO | Not shown | Version, author, website, files | yes (details only) |
| Extension dialogs (dynamic widgets created by Lua extensions) | NOT IN VIDEO | Not shown | UIs of Lua extensions (e.g. VLsub) | yes |

### 4.9 Other dialogs

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| VLM configurator | NOT IN VIDEO | Content not shown (entry: RC > More Settings > VLM Configuration, HK Ctrl+Shift+W) | VLM broadcast / schedule / VOD | yes |
| Program Guide (EPG) | NOT IN VIDEO | Content not shown (entry: RC > More Settings > Program Guide) | DVB EPG | yes |
| Podcast configuration (URLs, Add, Delete) | NOT IN VIDEO | Not shown (its entry, Discover > Services > Configure..., is also NOT IN VIDEO) | Podcast service discovery URLs | no (podcast URL option in the full preferences) |
| Add to Playlist (existing playlist list, new playlist name) | MOVE | File "..." > Add to Playlist (P6-17, F-12); New Playlist dialog (P6-16). The picker content is not shown. | Add ML items to a playlist | - |
| Go to Time (time edit, Reset, Go, Cancel) | MOVE | Click the current time and type (F-02, W3.5); RC > Playback > Jump to Specific Time; HK Ctrl+T | Seek to a time | - |
| Help (help HTML, Close) | NOT IN VIDEO | Not shown (entry: HK F1 only) | Help text | yes |
| About (title, version, License, Authors, Credits, Update button) | KEEP | main "..." > About VLC (Decision 14); content not shown, keep VLC's (license, authors, Update button); public builds rename it (CLAUDE.md) | About info | - |
| VLC media player updates (check, status, recheck, download, Close) | NOT IN VIDEO | Not shown (entry: About > Update button) | Updater | yes |
| First run wizard (privacy / network access text, Allow metadata network access, Enable the Media Library + folders, color scheme, layout Modern / Classic) | MOVE | Onboarding (P8-29 to P8-31): media folder, theme + accent, shortcuts. Not shown: the privacy / network access text and "Allow metadata network access" (now Settings > Privacy > "Fetch titles and cover art from the internet", P8-07), layout Modern / Classic. | Initial settings | - |
| Toolbar Editor (profiles, Video / Audio / Mini player tabs, LEFT / CENTER / RIGHT zones, palette) | MOVE | Customize Player from main "..." > Customize Player (P8-24 to P8-26); profiles move to main "..." > Profile > (P8-27, Decision 25). Separate Video / Audio / Mini player layouts are not shown (see Decisions). | Control bar customization | - |
| Text input dialog (rename playlist, profile name) | NOT IN VIDEO | Not shown; Profile "+ New" asks for a name (Decision 25), so a prompt is still needed | Generic text prompt | yes |
| Question / message boxes (delete confirm, discard filtered items, paste from clipboard, reset prefs) | NOT IN VIDEO | Not shown | Confirmations | yes |

### 4.10 Preferences (dialogs/preferences/*)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Show settings: Simple / All / Expert; Save, Cancel, Reset Preferences | MOVE | Settings dialog with per-page Advanced Options and no Simple / All switch (P7-14, P8-02, P8-22); "Reset all settings" in General > Advanced (P8-22) | Mode switch, save, reset | - |
| Simple > Interface (language, look and feel, window options, menu bar, controls, instances, privacy, file associations) | MOVE | Settings > General (language, theme, P8-03), Interface (P8-06), Privacy (recent items, clear, metadata network access, P8-07), Library (one instance, P8-14), Playback (continue playback, P8-09). Not visible on any page: Look and feel Modern / Classic, Force window style, Auto raising, Pause playback when minimized, Interface scale factor, Show the menu bar, Pin video controls, Display play queue tree, File extensions association (see Decisions). | Interface config | - |
| Simple > Audio | MOVE | Settings > Audio (P8-11); Last.fm in Settings > Privacy (P8-07); default audio track in Settings > Playback > Tracks (P8-09) | Audio config | - |
| Simple > Video | MOVE | Settings > Video (P8-10) and Performance (P8-16). Snapshot directory, prefix, sequential numbering and format are not shown. | Video config | - |
| Simple > Subtitles / OSD | MOVE | Settings > Subtitles (P8-12) | Subtitle / OSD config | - |
| Simple > Input / Codecs | MOVE | Settings > Performance (hardware decoding, post-processing, skip loop filter, P8-16), Network (caching policy, HTTP proxy, P8-15), Recording (record directory, P8-17); fast seek maybe = Playback > Seeking > "Seek precisely" (P8-09). Not shown: x264 options, default optical device, damaged AVI, preload MKV, Live555 transport. | Input / codec config | - |
| Simple > Hotkeys | MOVE | Keyboard Shortcuts dialog (P7-12) from main "..." > Keyboard Shortcuts (P7-13) and Settings > Controls (P8-08); wheel modes in Settings > Controls > Mouse (P8-08) | Hotkey editing | - |
| Simple > Media Library (folders, Reload All Folders, Banned folders) | MOVE | Videos / Music "+ Add" (P5-29), folder "..." > Add Folder and Resync (P5-15), onboarding media folder (P8-29), Settings > Library > "Use the media library" (P8-14). Removing a folder and banned folders are not shown. | ML roots | - |
| All (advanced) tree | MOVE | Per-page Advanced Options (P7-14, P8-22); the old tree stays reachable from Advanced (BUILD_PLAN section 2) | Every module option | - |
| Expert view (flat table, Modified only, search, set value) | NOT IN VIDEO | Not shown | Every option as a table | no (All tree behind Advanced Options) |

### 4.11 QML core dialogs (dialogs/dialogs/qml/Dialogs.qml)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Error popup (message, Show Details, Dismiss) | NOT IN VIDEO | Not shown | vlc_dialog error display | yes (errors would only reach the log) |
| Login dialog (User, Password, Save password) | NOT IN VIDEO | Not shown | Credentials for SMB / HTTP / ... | yes |
| Progress dialog | NOT IN VIDEO | Not shown | Long core operations | yes |
| Question dialog | NOT IN VIDEO | Not shown | Core questions (e.g. insecure TLS) | yes |
| Custom dialog / ask() helper | NOT IN VIDEO | Internal helper | Generic QML modal | no (no user function of its own; keep while anything uses it) |

## 5. Keyboard-only and other user-visible features

### 5.1 Qt/QML window shortcuts (GlobalShortcuts.qml, MLGlobalShortcuts.qml)

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| F10 toggle menu bar | ? | Decision 22 keeps VLC shortcuts, but the menu bar it toggles is replaced by "..." (P2-20); F10 also clashes with the core "play bookmark 10" hotkey (Upstream issues) | MainCtx.toggleToolbarMenu | no (the menu bar contents stay reachable) |
| Ctrl+= / Ctrl+Shift+- / ZoomIn / ZoomOut | KEEP | Decision 22 | Interface scale | - |
| Ctrl+1 ... Ctrl+0 | KEEP | Decision 22 | Play recent media 1..10 | - |
| Paste (Ctrl+V) | KEEP | Decision 22 | pasteFromClipboard with confirmation | - |
| All menu accelerators (Ctrl+O, Ctrl+Shift+O, Ctrl+F, Ctrl+D, Ctrl+N, Ctrl+C, Ctrl+Y, Ctrl+R, Ctrl+S, Ctrl+Q, Ctrl+E, Ctrl+I, Ctrl+J, Ctrl+M, Ctrl+P, Ctrl+T, Ctrl+Shift+W, Ctrl+L, F1, F11, Ctrl+H, Ctrl+B) | KEEP | Decision 22; shown next to the main "..." and right-click rows (Figma). Ctrl+B changes from "Manage bookmarks" to "create bookmark" (Decision 22). These Qt shortcuts are not core hotkeys, so the Keyboard Shortcuts dialog (P7-12) does not list them unless they are added. | Same as the menu items | - |

### 5.2 Core hotkey actions with no or limited Qt UI (src/libvlc-module.c defaults)

All rows here stay because Decision 22 keeps every VLC default shortcut, and the Keyboard Shortcuts dialog (P7-12) lists the core hotkeys. The onboarding shortcut screen (P8-31) shows different keys; under Decision 22 its text must show VLC's keys.

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Position OSD (t) | KEEP | Decision 22; Keyboard Shortcuts > Basic "Show playback position and time T" (P7-12) | Time OSD | - |
| Jump extra-short / short / medium / long fwd / back | KEEP | Decision 22; step sizes in Settings > Controls > Skip Amounts (P8-08) | Seek by configured steps | - |
| Frame previous (Shift+E) | KEEP | Decision 22 | Frame step back | - |
| Subtitle delay down/up (g/h), audio delay down/up (j/k) | KEEP | Decision 22; same values as the sidebar sliders (P3-20, P4-18; INTERACTIONS.md section 4) | Delay adjustment | - |
| Subtitle sync mark audio / mark sub / apply / reset (Shift+H/J/K, Ctrl+Shift+K) | KEEP | Decision 22 | Manual subtitle sync | - |
| Subtitle position up/down, text scale up/down/normal | KEEP | Decision 22; Subtitles tab Subtitle Offset and Font Size (P3-21) | Subtitle placement and size | - |
| Subtitle toggle (Shift+V), secondary subtitle control (Ctrl+Shift+V), reverse cycle (Alt+V) | KEEP | Decision 22 (V = cycle subtitle track) | Subtitle cycling | - |
| Program SID next/prev (x / Shift+X) | KEEP | Decision 22; Keyboard Shortcuts > Playback "Next program / Service ID X" (P7-12) | Program cycling | - |
| Disc menu (Shift+M) | KEEP | Decision 22 | DVD / BD root menu | - |
| Navigate up/down/left/right/activate (arrows, Enter) | KEEP | Decision 22 | Disc menu navigation | - |
| Title prev/next (Shift+O / Shift+B) | KEEP | Decision 22 | Title navigation | - |
| Crop edges (Alt+R/D/C/F, Shift to uncrop) | KEEP | Decision 22 | Fine crop | - |
| Zoom quarter/half/original/double (Alt+1..4), unzoom (Shift+Z) | KEEP | Decision 22 | Zoom | - |
| Scale up/down (Alt+O / Alt+Shift+O), toggle autoscale (o) | KEEP | Decision 22 | Video scaling | - |
| 360 viewpoint FOV in/out, roll, projection toggle | KEEP | Decision 22 (no 360 UI in the video; mouse drag on 360 video stays) | 360 video controls | - |
| Audio device cycle (Shift+A) | KEEP | Decision 22 | Next output device | - |
| Wallpaper (w) | KEEP | Decision 22 | Wallpaper mode | - |
| Show interface / boss key (i / unbound) | KEEP | Decision 22; Keyboard Shortcuts > Basic "Show interface controls in fullscreen I" (P7-12) | Show controls / boss key | - |
| Popup menu (Menu key) | KEEP | Decision 22; opens the new right-click menu (P2-23) | Right-click popup | - |
| Set bookmark 1..10 (Ctrl+F1..F10) / play bookmark 1..10 (F1..F10) | KEEP | Decision 22; F1 / F10 clash (Upstream issues) | Quick bookmarks | - |
| Clear play queue (Ctrl+W) | KEEP | Decision 22 | Clear the queue | - |
| Leave fullscreen (Esc), media keys | KEEP | Decision 22; Keyboard Shortcuts > Basic "Exit fullscreen / close dialog esc" (P7-12) | Standard controls | - |
| Mouse wheel on video (Y: volume, X: seek) | KEEP | Settings > Controls > Mouse: Scroll wheel, Horizontal scroll, Reverse scroll direction (P8-08) | Volume / seek by wheel | - |
| Arbitrary hotkeys forwarded from QML (sendHotkey / sendVLCHotkey) | KEEP | Used by every new QML key handler (BUILD_PLAN section 1, Hotkeys) | Routes keys to core actions | - |

### 5.3 Other user-visible behaviour

| Element | Mark | Where in the redesign / reason | VLC function | Unreachable if removed |
|---|---|---|---|---|
| Dialog provider events from core (INTF_DIALOG_*) | NOT IN VIDEO | Internal, not visible as such | Lets skins2, hotkeys and Lua open Qt dialogs | yes (those requests would do nothing) |
| Xmas cone variants | NOT IN VIDEO | Not shown; public builds use Sticky's icon (CLAUDE.md) | Seasonal logo | no (decorative) |
| Window title showing now playing | KEEP | Settings > Interface > "Show the file name in the title bar" (P8-06); centered top bar title (P2-06) | Window title | - |
| Taskbar integration (Windows thumbnail toolbar, progress) | NOT IN VIDEO | Not shown | Prev / Play / Next in the Windows taskbar preview, taskbar progress | no (same actions elsewhere; only the taskbar convenience is lost) |
| Tooltips and accessibility names on all controls | NOT IN VIDEO | Not shown except the volume tooltip (F-03) and the info icons (P8-21); INTERACTIONS.md section 7 already requires Accessible.name on every new element | Screen-reader labels, tooltips | yes (screen-reader access) |

## Decisions needed from Sticky

### A. NOT IN VIDEO elements that would become unreachable if removed

Each group ends with a recommendation. Nothing here is removed until Sticky decides.

**A1. Player controls that only exist as control bar buttons**
- 2.4 ATOB_BUTTON (A-B loop), 2.4 HIGH_RESOLUTION_TIME_WIDGET (SMPTE timecode), 2.4 TELETEXT_BUTTONS, 2.4 NAVIGATION_BUTTONS (its teletext part).
- Recommendation: keep all four as Customize Player palette items (W8.1a restyles VLC's toolbar editor, which already has them). Also add "A-B Loop" to RC > Playback and "Teletext" to RC > Subtitle, so they are not palette-only. Draw the A-B markers on the seek bar (2.3).

**A2. Core dialogs and feedback the core relies on**
- 2.2 Dialogs layer; 4.11 Error popup, Login dialog, Progress dialog, Question dialog; 4.9 Question / message boxes, Text input dialog; 5.3 Dialog provider events from core; 4.8 Extension dialogs; 2.2 Floating notification above control bar; 3.1 Floating notification (library).
- Recommendation: keep all, restyled with the redesign dialog frame (IB-29, FIGMA_FLOWS dialog specs) and the toast look (IB-35) for notifications. Without them, logins for network shares, TLS questions, confirmations and extensions like VLsub stop working.

**A3. Old dialogs that stay behind a menu entry but are never shown**
- 4.9 VLM configurator, Program Guide (EPG), Help, VLC media player updates; 4.6 Codec tab, Location / Save Metadata / Close, Audio Fingerprinting dialog; 4.7 Modules Tree tab; 4.8 About plugin / addon info dialogs; 4.5 v4l2 controls tab.
- Recommendation: keep them as they are, reached from RC > More Settings (VLM, Program Guide, Messages, Codec Information, Media Information, Effects and Filters), About VLC (updates) and F1 (Help). Restyle later only if wanted.

**A4. Convert, Stream and Open dialog contents**
- 4.2 Convert: Settings, Profile selector, Profile edition dialog, Destination file, Start / Cancel. 4.3 Stream wizard: Destination Setup, Transcoding Options, Option Setup, Back / Next / Stream / Cancel. 4.1 Open Media: Show more options, capture Advanced Options sub-dialog.
- Recommendation: keep the existing Convert dialog behind main "..." > Convert and the Stream wizard behind file "..." > Stream and Ctrl+S. In the split open dialogs (W6.4) keep a "More options" expander (start / stop time, extra media, custom options) and the capture "Advanced options" button.

**A5. Library**
- 3.1 Nav: Browse and 3.3 Browse home (local drives, devices, LAN shares): recommend rows "Local Network" and "Devices" in rail Network next to Podcasts and Radio (P6-07), using VLC's existing browse models, and letting "+ Add" folder pickers browse network shares too.
- 3.3 Home: Favorites row: recommend a "Favorites" section on Home in the same style as the other Home sections (P6-20), since the file "..." menu and the palette can set Favorite (F-12, P8-24).
- 3.3 Video group view (group by name): recommend dropping name grouping (folders replace it, P5-16), or keeping it as a Sorting Options extra.
- 1.10 Sort menu Albums extra: Album sections: recommend dropping it or keeping it as a Sorting Options extra on the artist view.
- 3.1 Scan progress bar: recommend a thin progress line with "Indexing ..." under the panel count row (P5-23).
- 3.1 Update pane: recommend a toast or a Home notice in the resume-toast style (IB-35), shown when the automatic check (Settings > General, P8-03) finds an update.
- 2.2 Audio player: Lyrics toggle and Lyrics view: recommend a "Lyrics" button in the music view (P6-04) or a Customize palette item, with the synced lyrics panel kept.
- 3.4 Filter search box (queue): recommend a magnifier in the queue header like the compact library (IB-12), keeping "Discard the filtered out items".
- 3.4 Detached play queue window (with 1.7 Docked Play Queue): recommend dropping both together, because Decision 3 makes the queue a sidebar everywhere; or keep both in RC > More Settings.
- 1.10 Network device context menu: recommend reusing the folder "..." menu (P5-15) on device rows.

**A6. System tray**
- 1.11 Tray icon; 1.11 Hide / Show VLC media player in taskbar; 1.1 Close to systray.
- Recommendation: keep the tray as it is (it is outside the redesigned window) and fill Settings > Interface > "Notifications and System Tray" (P8-06) with VLC's "Show systray icon", "Show media change popup" and a "Close to tray" option.

**A7. skins2 popups**
- 1.10 Skins / dialog-provider variant of popup, AudioPopupMenu, VideoPopupMenu, MiscPopupMenu.
- Recommendation: keep untouched; Settings > Interface keeps "Use a custom skin" (P8-06), and these menus are skins2's only popups.

**A8. Accessibility**
- 5.3 Tooltips and accessibility names.
- Recommendation: keep; INTERACTIONS.md section 7 already requires Accessible.name and translations on every new element.

### B. Sub-items inside KEEP / MOVE rows that lose their only entry point

These rows are marked MOVE or KEEP because the element as a whole has a new home, but these parts have none in the video or Figma:
- Play queue context menu (1.10): Jump to current playing, Show Containing Directory, Information for a non-playing item, Clear the play queue (only HK Ctrl+W), Save Play Queue to File (only HK Ctrl+Y), Discard the filtered out items. Recommend a row "..." menu in the queue that reuses the file "..." menu (F-12) plus Clear and Save in the queue header or RC > Playlist.
- ML media context menu (1.10): Play as audio, Play as album, Enqueue as album, Delete (streams), Delete File From System. Recommend adding "Delete" (with confirmation) and "Play as audio" to the file "..." menu.
- ML playlist list context menu (1.10): Rename, Delete. Recommend adding both to the playlist "..." menu (F-11).
- ML playlist content context menu (1.10): Remove from this playlist. Recommend adding it to the file "..." menu when opened inside a playlist.
- Network media context menu / Browse tree / Simple > Media Library: Remove from Media Library, banned folders, Reload All Folders. Recommend "Remove from Library" in the folder "..." menu (P5-15) and a folder list on Settings > Library.
- Subtitle track menu (1.10): "Select multiple" (dual subtitles); Subtitle sync page (2.5) and Synchronization tab (4.5): secondary subtitle delay. Recommend allowing two checked rows in the tracks popup Subtitles tab and showing a second delay slider in the Subtitles tab when a secondary track is on.
- Audio sync page (2.5): Reset and the "Sound Heard / Sound Spotted" estimator (no hotkey for audio). Recommend a small Reset next to Audio Track Delay; estimator optional.
- Audio track menu (1.10) and Video Tracks "Add" (2.5): load an external audio / video track for the playing item. Recommend an "External Tracks +" section on the Audio and Video tabs of the tracks popup, like Subtitles.
- Advanced audio (4.5): Adjust pan. Video Geometry (4.5): Interactive Zoom, Wall, Puzzle. Recommend extra expandable cards in the Audio / Video tabs or leave them in full preferences.
- Bookmarks (4.4): rename, Clear, Extract. Recommend rename by double-click on a row and Clear / Extract in a "..." on the Bookmarks tab header.
- Open Media Network tab (4.1): URL history and Clear History. Recommend relying on Recent / Latest Streams (P6-19, F-15) and a clear option in Settings > Privacy.
- First run wizard (4.9): the privacy / network access notice. Recommend keeping it as an onboarding step (VideoLAN privacy policy), with "Allow metadata network access" there.
- Simple > Interface (4.10): File extensions association (important for a Windows app), Pause playback when minimized, Interface scale factor, Pin video controls, Look and feel / custom skin choice already in Interface > Skin. Recommend adding File associations to Settings > General or Interface.
- Simple > Video (4.10): snapshot directory / prefix / format. Recommend Settings > Recording next to "Save recordings to" (P8-17).
- Toolbar Editor (4.9): separate Video / Audio / Mini player layouts. Customize Player only shows the video bar (P8-24); the music bar (P6-05) and the mini player need their own layouts or a tab in Customize Player.
- Nav: Video > All (3.1): a flat list of all indexed videos. Music > Artist detail (3.3): Play all / Enqueue all. Filter search box (3.2): case-sensitive and regex options. Hotkey table context menu (1.10): Unset, Copy value, per-row Reset. Seek slider (2.3): A-B markers, chapter-name tooltip; remaining-time label: speed-adjusted tooltip. Recommend keeping these behaviors in the new components where cheap.
- Hotkey-only after the redesign (reachable, but with no visible entry): Save Play Queue to File (Ctrl+Y), Open from clipboard (Ctrl+V), Help (F1), DVD root menu (Shift+M), frame step (e / Shift+E), Codec Information also has RC > More Settings. Recommend at least RC > Playlist for Save Play Queue and RC > Playback for the disc menu and frame step.

### C. Rows marked "?" (need a call), plus the one NOT IN VIDEO row whose reachability is unknown
- 1.1 Open Location from clipboard: in both video menus, not in the final Figma menu (Decision 2). Keep only Ctrl+V, or add "Open from Clipboard" back to main "..."?
- 1.1 Save Play Queue to File: removed in the final menu; keep only Ctrl+Y, or put it in the queue header / RC > Playlist?
- 1.1 Quit at the end of play queue: map to a "Quit VLC" value of Settings > Playback > "When playback finishes" (P8-09)?
- 1.10 QmlAudioContextMenu: confirm the right-click menu also opens on the music player view (P6-04).
- 1.10 Network media context menu: confirm that Network rows use the file "..." menu.
- 2.4 REVERSE_BUTTON: the Reverse toggle is postponed (Decision 29); keep the old button as a palette item until then?
- 5.1 F10 toggle menu bar: the menu bar is gone; let F10 fall through to the core "play bookmark 10", or keep F10 for a classic menu bar?
- 2.2 Toggle control bar button (DVD interactive mode): unreachable status unknown until tested with a real DVD menu (BUILD_PLAN risk 2).

## Upstream issues found

Copied from `vlc_ui_inventory.md` (base commit a5538c557d276378d5ba0f8f8010a8b87eaa6f78). These are bugs or gaps in VLC master itself, not in the redesign.
1. Next / Previous Frame control bar buttons are swapped in `player/qml/PlayerControlbarControls.qml`: the FRAME_PREV_BUTTON id is labelled "Next Frame" and loads `FrameNextButton.qml` (Player.frameNext), and FRAME_NEXT_BUTTON is labelled "Previous Frame" and loads `FramePrevButton.qml`.
2. Play queue context menu "Sort by" (`menus/qml_menu_wrapper.cpp` PlaylistContextMenu) reads the key "key" but the list provides "criteria", so every entry likely sorts by Title only.
3. `maininterface/qml/MainDisplay.qml` routes "mlsettings" to `MLFoldersSettings.qml`, which does not exist (dead route).
4. F1 / F10 clash: the Qt menus use F1 = Help and F10 = toggle menu bar (`menus/qml/GlobalShortcuts.qml`), while the core default hotkeys use F1..F10 = play bookmark 1..10 (`src/libvlc-module.c`).
5. A-B loop, reverse (trickplay), timecode (SMPTE high resolution time) and teletext are only reachable from control bar buttons: no menu entry and no default hotkey.
