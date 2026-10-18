# SETTINGS_NOTES: Settings dialog category pages (W6.2), web session

Branch `redesign-settings`, branched from `redesign` (10b542199c). Built by the web session; the PC session reviews, merges, builds and tests it (CLAUDE.md "Parallel work"). Draft PR: https://github.com/StickyGonzales/vlc-redesign-juxtopposed/pull/2. Nothing is marked verified in VIDEO_INDEX.md.

## 1. Status

- All 13 category pages are built and wired to VLC's real options. The Add Subtitles dialog (W6.5) is excluded, as asked.
- qmlcheck (PySide6 6.8.3): `errors: 1` (the known HighResolutionTimeWidget stub limit), `crashed: 0`, 318 files. Every new file imports what it uses.
- C++: syntax and type checked here against VLC's headers with Qt 6.4 headers (the only Qt in this container); the `_WIN32` parts (registry) could not be compiled here. Nothing was compiled, linked or run: the first real compile is the CI build after the merge.
- Independent review: see section 8.

## 2. What was built

**Settings bridge use.** Every row reads and writes VLC's options through `RdEffects` (the bridge of the settings sidebar): a change applies at once where VLC allows it, is saved in VLC's configuration, and the sidebar and the dialog stay in sync. Equalizer, picture and audio effects use the sidebar's own RdEffects calls.

**C++ (new): `dialogs/redesign/settings/settings_catalog.{hpp,cpp}`, singleton `SettingsCatalog` (VLC.Dialogs)**
- Files every option of VLC and of its plugins under one of the 13 categories, from the category VLC itself gives it (VLC subcategory to Settings category table in the .cpp; a few plugins are placed by name: loggers to General, Lua to Extensions, Last.fm to Privacy, media library to Library, GnuTLS to Network). Options VLC hides or never saves (internal, volatile, obsolete) and hotkeys (edited in Keyboard Shortcuts) are left out, as in VLC's own preferences.
- The rows the pages show by name (`curatedOptions()`) are left out of the generated lists, so no option shows twice.
- Read once on a worker thread, the first time a page's Advanced Options opens or the dialog's search runs.
- Also: the plugin list (name, capability, score), `describe(option)` (type, texts, range, default), file and folder pickers, the configuration folder, Reset all settings (VLC's `config_ResetAll` + save), clearing the history (media library), the interface language (Windows registry, as VLC's preferences).

**QML components (new, `dialogs/redesign/settings/`)**
- `SettingsOption`: a row bound to one VLC option. The control follows the option's type (toggle, dropdown in words, number with unit, slider, text, password, file / folder with Browse, color hex + swatch) unless the page names one; VLC's explanation in the info popover; hidden when this build of VLC has no such option; `restartRequired` adds "VLC uses this setting the next time it starts." to the popover.
- `SettingsMoreOptions`: the last section of each page's Advanced Options, "All Other Options": every remaining option of the category, one collapsed row per plugin (with its number of settings); a plugin's settings are created when it is opened. The dialog's search finds a plugin by any of its settings.
- `SettingsOptionGroup`, `SettingsPluginList` (Extensions > Advanced: Name / Capability / Score in a 360 px list with its own search), `SettingsAccentPicker` (nine square swatches, Decision 15 colors, live through `MainCtx.accentColor`), `SettingsEqualizer` (inline equalizer: Open / Close Equalizer, preamp and ten vertical band sliders with value boxes, Figma "EQ"), `SettingsLanguageOption` (track languages in words), `SettingsInterfaceToggle` (VLC extra interfaces: Last.fm, web remote, as `config_AddIntf` / `config_RemoveIntf`).

**Pages (`dialogs/redesign/settings/pages/`)**: rows and order from the Figma frames ("Settings - *"), wording from the video where it differs (Decision 11), values in words.
- General: interface language (Windows), Theme (Dark / Light / System through `MainCtx.colorScheme`, instant), Accent color (live), Startup, Diagnostics (logging), Advanced: minor warnings, log format, statistics, configuration folder, Reset all settings, Developer Options (system log; Linux/BSD only).
- Interface: skin, window, playback controls (Decision 30: "Auto-hide the controls" = VLC's pin controls), tray and notifications, playlist; Advanced: opacity, minimized pause, raising, cover art, open dialog, app icon, fullscreen controls opacity, menu bar, interface size, smooth scrolling, blur, picture-in-picture, safe area.
- Privacy: history, remember position, Clear history, internet metadata, ask about internet access, Last.fm (no Advanced Options, as the video and Figma).
- Controls: Edit Keyboard Shortcuts (opens the dialog), Reset all shortcuts (HotkeysModel), skip amounts, single click, scroll wheels and reverse direction in words, web remote with port and password; Advanced: mouse / key handling on the video, media keys.
- Playback: continue where you left off, autostart, default speed slider, cork; video quality, menu language, default tracks in words; repeat (Off / All / One) and end of list (Stop / Pause on the last frame / Quit VLC); precise seeking; optical drive, AVI repair, MKV preload; Advanced: time-shift folder and size, start paused, playback states, default video track, audio CD drive.
- Video: output, picture sliders (the sidebar's adjust filter) and Reset picture, deinterlacing, framing in words, snapshots; Advanced: custom ratios, monitor PAR, video output, filters, zoom factor, black and white, decorations.
- Audio: output, device of the output in use, speaker setup; maximum volume, startup volume (stacked choice, Figma "Values"), volume step in %; loudness, replay gain; Effects: equalizer toggle, preset, inline equalizer, two-pass, spatial audio and its mode, stereo widening, compressor, pitch shift, chorus/flanger, karaoke; track language and delay; visualizer; Advanced: passthrough, Dolby detection, resampler, media role, visualization size, output module, time stretch, stereo mode, gain, audio filters.
- Subtitles: enable, language, encoding; automatic loading and file name matching in words (P7-17); font, Size values (Relative words / Precise percent), font size, bold, colors, opacities, outline, shadow, background, vertical position; delay (bipolar slider); on-screen messages; Advanced: folders, shadow angle, text direction, monospace font, title position, alignment, second subtitles.
- Library: one window and its two dependent rows (dimmed while off, video 18:15), folders in words, hidden files, metadata, media library; Advanced: preparsing, ignored extensions.
- Network: Buffering in words (Low latency / Normal / More buffering / Custom; the four sizes dimmed until Custom), proxy, certificates, ciphers in words; Advanced: connection timeout, MTU.
- Performance: hardware decoding (VLC's on/off and device in one list: Automatic / the devices / Off), post-processing (Off takes VLC's post-processing filter out) and loop filter in words, threads; late frames, priority; Advanced "Developer": decoder, clock options.
- Recording: recording folder and native recording, cast quality, stream out tracks, x264 preset and tuning in words; Advanced: keep / all tracks, H.264 profile and level.
- Extensions: the add-ons VLC manages (VLC's add-ons model, `ServicesDiscoveryModel`): installed list, search, Find more extensions (VLC's online catalog), Add (selected catalog add-on, or a `.vlp` package file / drop), Remove (with confirmation), Load extensions on startup; Advanced: plugins list (P8-20).
- Every page ends its Advanced Options with "All Other Options" (except Privacy, which has none).

**Snappiness**: pages load when first shown (dialog shell); the catalog is read once off the UI thread; the generated lists are built once (asynchronous Loader) and never rebuilt on keystrokes; a plugin's rows exist only while it is open; the plugin and add-on lists create rows as they scroll in; no timers.

**Opaque bodies**: every panel and popup these pages add is opaque (equalizer BG/A4, lists BG/B2, accent strip BG/B2, dropdown lists BG/A4 from the kit). The info popover is the shared `Widgets.RdTooltip`, still on `rdBgB1Transparent` (section 5).

## 3. VIDEO_INDEX rows covered

Status: **built** = coded on this branch, needs the PC test; **partly** = built, with the limit named in section 6; **PC** = needs a shared-file change (section 5).

| Rows | Status | Where |
|---|---|---|
| P7-14 (basic first, advanced below on one page), P8-45 | built | every page; "All Other Options" |
| P7-15 (every setting has a place, none repeated) | built | SettingsCatalog, curated list |
| P7-16, P8-21 (info icon on every setting) | built | SettingsOption (VLC's descriptions) and own descriptions on custom rows |
| P7-17, IB-41, P8-01 (words instead of numbers) | built | Subtitles "File name matching" and every dropdown |
| P3-22 (exact font sizes) | partly | Subtitles "Size values" Relative / Precise (section 6) |
| P8-03 General, P8-22 Advanced Options rows | partly | General (section 6: command line options) |
| P8-04, P8-41 theme | built (instant switch is the palette's) | General > Theme |
| P8-05, P8-42, IB-43 accent | built | SettingsAccentPicker |
| P8-06 Interface | partly | (section 6: window size memory, popup duration) |
| P8-07 Privacy | partly | (section 6: "Never remember items matching") |
| P8-08 Controls | partly | (section 6: double click) |
| P8-09 Playback | yes | "Show thumbnail while scrubbing" added by W3.3b (qt-seek-thumbnails) |
| P8-10 Video | built | |
| P8-11 Audio, P8-44 inline equalizer, IB-45 slider variants | partly | (section 6: night mode) |
| P8-12 Subtitles | partly | (section 6: OSD feedback duration, ASS styling) |
| P8-13 shortcut shown in OSD | not built | needs a core change (section 6) |
| P8-14 Library | built | |
| P8-15 Network | built | |
| P8-16 Performance | partly | (section 6: process priority, rescan, encoder) |
| P8-17 Recording | partly | (section 6: discover cast devices) |
| P8-18 Extensions, P8-19, P8-20 add-ons vs plugins | built | |
| P8-43 control styles | built (Rd kit) | |
| F-19 switching | built (dialog shell + pages) | |

Rows of the dialog shell (P7-18, IB-42, P8-02, P8-39, P8-40) and the Keyboard Shortcuts dialog (P7-12, IB-40) were done on `redesign` before this branch.

## 4. Decisions (Claude) to add to VIDEO_INDEX.md

- Every VLC option has a place: the page's curated rows first, then under Advanced Options "All Other Options", one row per plugin, from VLC's own category of each option. "All VLC Settings" (VLC's old preferences) stays in the dialog as before.
- Developer mode = VLC's "qt-verbose" (debug messages of the interface); Developer Options are always under Advanced Options (as in Figma, where they show with Developer mode off).
- "Show confirmation and error dialogs" = "interact"; "Show minor warnings" = "qt-error-dialogs".
- Font size: VLC 4 has no pixel font size ("freetype-fontsize" is obsolete); "Size values" is Relative (Smaller / Small / Automatic / Large / Larger) or Precise (exact percent of VLC's size, "sub-text-scale").
- Track languages: Automatic (VLC's default), System language (the system's code), then languages by name (ISO 639-1 codes).
- Auto-hide the controls: Always = VLC's pin controls off, In fullscreen only = on (Decision 30).
- Remember the playback position (Privacy) is ON = Always; Playback > Continue where you left off has Never / Ask / Always.
- Spatial audio: VLC's headphone virtualization filter or the room spatializer, chosen by "Spatial audio mode".
- Reverse scroll direction reverses wheels set to Seek (VLC's "Position control reversed").
- Accent: the first swatch writes VLC's orange explicitly.
- Extensions page keeps the video's words ("Extensions", "Load extensions on startup", Decision 11).
- Performance: "Give VLC high priority" (VLC's "high-priority" raises the process priority, it is not real-time).
- Hardware-accelerated decoding = "hw-dec" (on/off) and "dec-dev" (device) in one dropdown, as Figma's single "Automatic" list.
- Video post-processing: Off = VLC's post-processing filter not in the video filters; Lowest to Highest = the filter with that quality ("postproc-q").
- Interface options MainCtx caches (maximum volume, hide timeout, pinned controls, opacity, menu bar...) apply at once: MainCtx reads its options again after the write, as after VLC's preferences.
- The generated "All Other Options" lists are built once Advanced Options opens; before that, a search of three letters or more lists only the matching plugins (one or two letters match nearly everything).
- Snapshot sizes are widths that keep the video's proportions.
- Recording: Cast quality uses VLC's levels (High / Medium / Low / Low processor use); there is no "Automatic".

## 5. What the PC session must change in shared files

1. `maininterface/mainui.cpp`: this branch adds one include and one registration line (`SettingsCatalog` singleton in the VLC.Dialogs block); without it no page can list VLC's options or plugins. Review it with the merge. Build lists (`Makefile.am`, `meson.build`) register the new C++ and QML files.
2. `widgets/qml/RdTooltip.qml` (the info popover) still uses `rdBgB1Transparent`: make it opaque like the other popups (`Qt.alpha(..., 1.0)`), so it never shows the video through where it passes the dialog's edge.
3. Palette: a red text token for the "Reset all settings" button (Figma red text, P8-43); until then it uses the standard button.
4. `widgets/qml/RdSegmented.qml` is mouse-only. The settings pages wrap it in `SettingsSegmented` (Tab, Left / Right); the kit widget itself could take that over for its other users.
   The interface rows (maximum volume, hide timeout...) call `MainCtx.reloadPrefs()` like VLC's preferences; it also re-applies values the session changed without saving them (e.g. compact mode toggled by a hotkey).
5. `network/addonsmodel.cpp` / `util/listcache.hxx`: a row state update can be lost when two add-on events come back to back (section 8).
6. Done by W3.3b (497730a4ce1 ecc261e4664 9a50a146c1f a80ff78a4a0): option qt-seek-thumbnails (on) and the "Show thumbnail while scrubbing" row in Playback > Seeking.
7. VIDEO_INDEX.md: set the rows of section 3 to "in progress" (built, unverified) at the merge; add the decisions of section 4.

## 6. Not done / limits

Update 2026-10-15 (Step 2, VIDEO_INDEX S2-02..S2-10, see BUILD_NOTES "Step 2 Settings rows"): Remember window size and position, Popup duration (with VLC's own tray popup), Never remember items matching, Double click on the video, Night mode, Process priority, Rescan plugins, Encoder and Discover cast devices are built now (Qt only). Still missing: Additional command line options (S2-01) and Ignore styling in ASS and SSA subtitles (S2-11), both core changes for a separate build, plus the rows below that are not settings rows of section S2.

Rows of the design without a VLC option behind them (left out rather than shown without effect):
- General > Advanced "Additional command line options": VLC keeps no such setting.
- Interface "Remember window size and position" (VLC 4 always remembers), "Popup duration" (no option), "Fullscreen controls sensitivity" (VLC 4's interface no longer reads "qt-fs-sensitivity"; the option is kept out of the lists too).
- Privacy "Never remember items matching" (VLC 4 removed the filter).
- Controls "Double click on the video" (always fullscreen in VLC).
- Audio "Night mode" (no VLC option; the compressor row is the closest).
- Subtitles "Show feedback for (duration)" and P8-13 (the shortcut shown in on-screen messages): need a core change (Decision 27, own build); "Ignore styling in ASS and SSA subtitles" (no option).
- Performance "Process priority" (only "high-priority" exists), "Rescan plugins" (VLC rescans at every start; its options are not saved), "Encoder" (obsolete in VLC 4).
- Recording "Discover cast devices" (discovery runs while the cast menu is open).
- Extensions: "Add" installs catalog add-ons or reads a `.vlp` package; loose Lua files cannot be installed (no VLC API).
- Reset all settings resets VLC's options (the accent color included); the interface's own state kept outside them (window layout, library, pins) stays, unlike VLC's old Reset Preferences which also cleared it.
- The Windows-only code (registry language) was not compiled here.

## 7. Files

New C++: `dialogs/redesign/settings/settings_catalog.{hpp,cpp}`.
New QML: `dialogs/redesign/settings/SettingsOption.qml`, `SettingsOptionGroup.qml`, `SettingsMoreOptions.qml`, `SettingsPluginList.qml`, `SettingsAccentPicker.qml`, `SettingsEqualizer.qml`, `SettingsLanguageOption.qml`, `SettingsInterfaceToggle.qml`, `SettingsSegmented.qml`.
Rewritten pages: all 13 in `dialogs/redesign/settings/pages/`.
Changed shared files: `maininterface/mainui.cpp` (registration), `Makefile.am`, `meson.build`.
Not touched: the dialog shell (SettingsDialog, SettingsPage, SettingsRow, SettingsSection, ...), the palette, MainCtx, RdEffects, the widgets.

## 8. Independent review

Three fresh subagents that did not write the code reviewed the branch (the C++ catalog, the components and ten pages; then the three pages built by two parallel agents; then the fixes). Fixed:

- Reset all shortcuts did nothing (the shortcuts were not loaded before the reset).
- Options the interface caches (maximum volume, hide timeout, pinned controls...) only applied after a restart; now MainCtx reads them again once written. Reset all settings left the interface and the accent stale; it now refreshes both.
- Snapshot width presets stretched the picture (height -1 keeps the video's height; 0 keeps the proportions).
- English users saw "System language" when choosing English; the system language is now listed once, with its name.
- The plugin list message was cut in half (it lived inside the list).
- The first search keystroke built every plugin row of all 13 pages; the full lists are now built only once Advanced Options opens, and searches of 3+ letters list only matching plugins.
- Spatial audio mode stopped following the filters after a choice; it now follows the filters and Off turns both off.
- The value scale of option rows shadowed Item.scale (qmllint warning); renamed.
- The audio effect toggles had no description (a module name was passed as an option).
- The start volume was capped at 125% for waveout; it uses the option's range.
- Obsolete options counted as existing (hidden HTTP proxy rows showed on other platforms); options a plugin declares before its first subcategory were dropped from the lists.
- The segmented controls (Theme, Size values, sensitivity) could not be used from the keyboard; a focusable wrapper adds Tab and Left / Right.
- The font size row could misalign the Precise box (two controls in one slot); one control at a time now.
- Hardware-accelerated decoding showed the device option instead of VLC's on/off; both are in one list now, and "hw-dec" is no longer duplicated in the generated list.
- Extensions: the online catalog could not be fetched again after an offline attempt; "Add" could uninstall an add-on whose install was still running (VLC's install request is a toggle) and now acts on the live state; the selection follows rows loaded later and every reload; the "no match" message no longer flashes while the search reloads.
- Video post-processing "Off" changed nothing (the quality is only read by the post-processing filter); Off now takes the filter out.
- The x264 preset text claimed to set casting (casting uses its own fast settings).

Verification round (a fourth reviewer, on the fixes):
- Two quick clicks on Add while VLC's installer was busy could install then remove an add-on; Add is now disabled for an add-on whose install is queued.
- Changing the post-processing level did not reach the running filter; it now does.
- A hardware decoding device set to VLC's "none" showed as Automatic; it shows Off.
- Typing an exact font size could swap the control under the user; Precise stays chosen.
- A search like "a b" listed almost every option; every word must have 3+ letters.
- Dragging an interface slider re-read MainCtx's options at every step; now once, on release.
- A build without the post-processing filter no longer logs a missing module.
- "Fullscreen controls sensitivity" was removed: nothing in VLC 4's interface reads its option.

Not changed, with reasons:
- Opening the Extensions page creates VLC's add-ons model, which reads the local add-ons catalog on the UI thread (VLC's own model). Only noticeable with many installed add-ons; measure on the PC.
- VLC's add-ons model can miss a row update when two state changes arrive back to back (util/listcache.hxx); the page re-reads the selected add-on on every reload, but a list row may show a stale state until the next reload. A fix belongs in VLC's AddonsModel (C++, shared).

## 9. Performance-sensitive: measure first on the PC

1. Opening Advanced Options of Video or Audio for the first time: the "All Other Options" list (one row per plugin, built asynchronously). The catalog itself is read once on a worker thread.
2. The dialog's first search: all 13 pages load (dialog shell); the generated lists add only the plugins a 3+ letter search matches.
3. Opening a plugin with many settings (e.g. x264 under Recording, about 70 rows).
4. Extensions page: VLC's add-ons model reads the local catalog when the page is created; Find more extensions downloads the online catalog.
5. Interface rows (maximum volume, hide timeout...): each change makes MainCtx read its options again once.

## 10. Real-build verification on the PC (integration, 2026-10-15)

Offline renders only helped while coding; every page is verified on the built VLC. Method: Windows scaling 100 %, VLC window large enough for the full 1048x865 dialog, dark theme, orange accent. Open Settings (Ctrl+P), pick the category, screenshot the dialog, crop the same rect, scale x2 (the Figma PNGs are 2x exports with the drop shadow margin, 15 px left and 7 px above, so a frame point (x, y) is PNG pixel ((x + 15) * 2, (y + 7) * 2)), and compare side by side at the same scale. The whole dialog is PNG rect 30,14,2096,1730. The "-1" frames show Advanced Options open (click the bar first); audio-1 is scrolled about 761 px (scroll until "Effects" is at the top of the content; its negative rects are above the visible area). The PNGs show Figma's sample values: set the same values first (e.g. General: Save a log ON, Log details Errors only) or compare geometry only.

Rects (PNG pixels x,y,w,h): each visible section (header + rows) and one instance of each control kind.

- **Settings - global.png**
   section 'Appearance' 510,154,1568,354
   section 'Startup' 510,548,1568,246
   section 'Diagnostics' 510,834,1568,430
   control: dropdown ('Interface language') 1438,242,640,72
   control: segmented/stacked ('Theme') 1438,334,640,72
   control: toggle ('Show confirmation and error dialogs') 1942,636,136,64
   control: field + Browse ('Log file') 1438,1090,640,72
- **Settings - global-1.png**
   section 'Appearance' 510,154,1568,354
   section 'Startup' 510,548,1568,246
   section 'Diagnostics' 510,834,1568,430
   control: dropdown ('Interface language') 1438,242,640,72
   control: segmented/stacked ('Theme') 1438,334,640,72
   control: toggle ('Show confirmation and error dialogs') 1942,636,136,64
   control: field + Browse ('Log file') 1438,1090,640,72
   control: text input ('Additional command line options') 1438,1514,640,72
- **Settings - interface.png**
   section 'Skin' 510,154,1568,254
   section 'Window' 510,448,1568,682
   section 'Playback Controls' 510,1170,1568,452
   section 'Notifications and System Tray' 510,1662,1568,82
   control: toggle ('Use a custom skin') 1942,242,136,64
   control: field + Browse ('Skin file') 1438,326,640,72
   control: dropdown ('Resize window to fit video') 1438,620,640,72
   control: slider ('Hide after') 1438,1434,640,94
- **Settings - interface-1.png**
   section 'Skin' 510,154,1568,254
   section 'Window' 510,448,1568,682
   section 'Playback Controls' 510,1170,1568,452
   section 'Notifications and System Tray' 510,1662,1568,82
   control: toggle ('Use a custom skin') 1942,242,136,64
   control: field + Browse ('Skin file') 1438,326,640,72
   control: dropdown ('Resize window to fit video') 1438,620,640,72
   control: slider ('Hide after') 1438,1434,640,94
- **Settings - privacy.png**
   section 'History' 510,154,1568,422
   section 'Network' 510,616,1568,522
   control: toggle ('Save recently played items') 1942,242,136,64
   control: text input ('Never remember items matching') 1438,410,640,72
   control: button ('Clear history now') 1878,502,200,64
- **Settings - playback.png**
   section 'Startup' 510,154,1568,472
   section 'Tracks' 510,666,1568,446
   section 'Order' 510,1152,1568,430
   section 'Seeking' 510,1622,1568,122
   control: dropdown ('Continue where you left off') 1438,242,640,72
   control: toggle ('Start playing as soon as a file opens') 1942,334,136,64
   control: slider ('Default playback speed') 1438,418,640,114
   control: text input ('Default audio track') 1438,938,640,72
- **Settings - playback-1.png**
   section 'Startup' 510,154,1568,472
   section 'Tracks' 510,666,1568,450
   section 'Order' 510,1156,1568,430
   section 'Seeking' 510,1626,1568,118
   control: dropdown ('Continue where you left off') 1438,242,640,72
   control: toggle ('Start playing as soon as a file opens') 1942,334,136,64
   control: slider ('Default playback speed') 1438,418,640,114
   control: text input ('Default audio track') 1438,940,640,72
- **Settings - video.png**
   section 'Output' 510,154,1568,414
   section 'Picture' 510,608,1568,582
   section 'Deinterlacing' 510,1230,1568,262
   section 'Framing' 510,1532,1568,212
   control: toggle ('Enable video') 1942,242,136,64
   control: slider ('Hue') 1438,704,640,48
   control: button ('Reset picture') 1878,1116,200,64
   control: dropdown ('Deinterlacing') 1438,1318,640,72
- **Settings - video-1.png**
   section 'Output' 510,154,1568,414
   section 'Picture' 510,608,1568,582
   section 'Deinterlacing' 510,1230,1568,262
   section 'Framing' 510,1532,1568,212
   control: toggle ('Enable video') 1942,242,136,64
   control: slider ('Hue') 1438,704,640,48
   control: button ('Reset picture') 1878,1116,200,64
   control: dropdown ('Deinterlacing') 1438,1318,640,72
- **Settings - audio.png**
   section 'Output' 510,154,1568,346
   section 'Volume' 510,540,1568,504
   section 'Loudness' 510,1084,1568,530
   section 'Effects' 510,1654,1568,90
   control: toggle ('Enable audio') 1942,242,136,64
   control: dropdown ('Output device') 1438,326,640,72
   control: slider ('Maximum volume') 1438,628,640,114
   control: segmented/stacked ('Startup volume') 1438,772,640,156
   control: text input ('Volume step') 1438,960,640,72
- **Settings - audio-1.png**
   section 'Output' 510,-1369,1568,346
   section 'Volume' 510,-983,1568,504
   section 'Loudness' 510,-439,1568,530
   section 'Effects' 510,131,1568,1613
   control: toggle ('Enable audio') 1942,-1281,136,64
   control: dropdown ('Output device') 1438,-1197,640,72
   control: slider ('Maximum volume') 1438,-895,640,114
   control: segmented/stacked ('Startup volume') 1438,-751,640,156
   control: text input ('Volume step') 1438,-563,640,72
- **Settings - subtitles.png**
   section 'Tracks & Languages' 510,154,1568,346
   section 'Loading Subtitles' 510,540,1568,254
   section 'Appearance' 510,834,1568,910
   control: toggle ('Enable subtitles') 1942,242,136,64
   control: dropdown ('Preferred language') 1438,326,640,72
   control: text input ('Font') 1438,924,640,72
   control: segmented/stacked ('Size values') 1438,1020,640,72
   control: color field ('Text color') 1438,1290,640,64
   control: slider ('Text opacity') 1438,1374,640,114
- **Settings - subtitles-1.png**
   section 'Tracks & Languages' 510,154,1568,346
   section 'Loading Subtitles' 510,540,1568,254
   section 'Appearance' 510,834,1568,910
   control: toggle ('Enable subtitles') 1942,242,136,64
   control: dropdown ('Preferred language') 1438,326,640,72
   control: text input ('Font') 1438,924,640,72
   control: segmented/stacked ('Size values') 1438,1020,640,72
   control: color field ('Text color') 1438,1290,640,64
   control: slider ('Text opacity') 1438,1374,640,114
- **Settings - controls.png**
   section 'Keyboard Shortcuts' 510,154,1568,246
   section 'Skip Amounts' 510,440,1568,462
   section 'Mouse' 510,942,1568,530
   section 'Remotes' 510,1512,1568,232
   control: button ('Defaults') 1438,242,640,64
   control: text input ('Very short skip') 1438,530,640,72
   control: dropdown ('Single click on the video') 1438,1030,640,72
   control: toggle ('Reverse scroll direction') 1942,1398,136,64
- **Settings - library.png**
   section 'Opening Files' 510,154,1568,506
   section 'Metadata & Artwork' 510,700,1568,254
   control: toggle ('Only allow one VLC window') 1942,242,136,64
   control: dropdown ('When opening a folder') 1438,494,640,72
- **Settings - network.png**
   section 'Buffering' 510,154,1568,554
   section 'Proxy' 510,748,1568,270
   section 'Security' 510,1058,1568,254
   control: dropdown ('Buffering') 1438,242,640,72
   control: text input ('Local files') 1438,336,640,72
   control: toggle ('Verify certificates against the system trust store') 1942,1146,136,64
- **Settings - performance.png**
   section 'Decoding' 510,154,1568,450
   section 'Smooth Playback' 510,644,1568,426
   section 'Developer' 510,1226,1568,518
   control: dropdown ('Hardware-accelerated decoding') 1438,242,640,72
   control: text input ('Decoding threads') 1438,520,640,72
   control: toggle ('Drop frames when the system can't keep up') 1942,732,136,64
   control: button ('Rescan plugins') 1438,996,640,64
- **Settings - recording.png**
   section 'Recording' 510,154,1568,258
   section 'Casting' 510,452,1568,254
   section 'Streaming' 510,746,1568,598
   control: field + Browse ('Save recordings to') 1438,244,640,72
   control: toggle ('Record without re-encoding when possible') 1942,338,136,64
   control: dropdown ('Cast quality') 1438,624,640,72
- **Settings - extensions.png**
   section 'Add-ons' 510,154,1568,656
   control: search + buttons ('Search') 1268,636,810,64
   control: toggle ('Load add-ons on startup') 1942,736,136,64

Expected differences (Decisions (Claude) 2026-10-15): rows without a VLC option are missing (S2-01 and S2-11; S2-02..S2-10 are built since, Process priority as a dropdown in words, Decision 35); every row has an info icon (Figma omits it on some rows, P7-16); Size values reads Precise (not Pixels); Default audio / subtitle track are dropdowns in words (Figma: a "1" field); "Give VLC high priority" (Figma: real-time); the Last.fm password and web remote password rows exist; Extensions keeps "Extensions" / "Load extensions on startup" (video wording); rows Figma does not show are under Advanced Options > All Other Options.
