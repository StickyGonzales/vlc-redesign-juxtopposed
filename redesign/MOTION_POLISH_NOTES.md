# Motion polish: sidebar tab crossfades (branch wip/motion-polish)

Branch `wip/motion-polish`, made from `origin/wip/next-test` (9290edc6b2). Draft pull request into `wip/next-test`: **do not merge before beta 2**. Qt only (`modules/gui/qt`), no core change. Nothing here is verified on Windows yet.

## 1. The rows
STATUS.md counts three optional rows in "Sidebars, menus and panels". In VIDEO_INDEX.md they are the three motion rows of the sidebar section, all marked "none (video only)" (no Figma frame):

| # | ID | Time | What the row shows | Built here |
|---|---|---|---|---|
| 119 | P4-16 | 8:40-8:42 | **Tab switch transition (crossfade).** Subtitles → Audio: the old rows (Subtitle Track / Language, Synchronization, delay slider) and the new ones (Audio Track / Language, Stereo Mode, Audio Track Delay) cross-fade in place; the orange underline moves from Subtitles to Audio, both underlines briefly visible. The row itself says it may be an editing transition. | yes |
| 120 | IA-37 | 8:40-8:47 | **Tab switch animation.** The same switch seen from the tab bar: the whole panel content cross-fades (both tabs' rows half visible in one frame), the underline moves to the new tab, the Audio icon becomes two-tone and the Subtitles icon grey. | yes |
| 138 | P4-29 | 8:57-9:06 | **Rows appear one by one (build-up).** New rows fade in as she narrates (Crop, Render, Filters on the Video tab; Reverse, Sleep Timer and the other Playback rows), pushing the rest down. "Probably an editing effect." | no (as asked) |

So the group has three rows, not four. Rows 119 and 120 are the same switch described twice: 119 names the content crossfade and the underline, 120 adds the icon tones. Built: everything those two rows show. Not built: 138.

## 2. What was there and what changed
**Before:** the page under the tabs already cross-faded (`RdSidePanelPageLoader`, 100 ms InOutSine), with the comment pointing at IA-37. The tab bar itself switched in one frame: the underline jumped to the new tab and the icons and labels swapped. In the sandbox frames below, the underline and both icons are already on Audio while the page is still half Subtitles.

**Now** (`player/qml/RdSidePanel.qml`, `RdSidePanelPageLoader.qml`):
- **One fade value per tab.** Each tab has a selection value from 0 to 1, animated when the tab is picked. It drives together:
  - the plain icon (fades out) and the two-tone icon (fades in), stacked in the same place;
  - the label colour (FG/A3 to FG/A2);
  - the underline. The old tab's underline fades out while the new one fades in, so both show for a moment, as row 119 describes. It does not slide: the video shows both at once, not one bar travelling.
- **Same timing for the page.** The page crossfade uses the same timing as the tabs.
- **Hover:** the hover colours stay instant (the selection value is not involved).
- **Where it applies:** the queue sidebar (Queue / Bookmarks / Chapters) uses the same panel, so it gets the same tab switch.

**Timing (Decision (Claude), logged in VIDEO_INDEX):** the rows give no duration, and the 8:40 switch is probably a dissolve of the edit. So: **150 ms ease-out** (`Easing.OutQuad`, `VLCStyle.rd_tabSwitchDuration`), for the page and for the tab parts.

## 3. Rules
- **Animation effects:**
  - New `MainCtx.systemAnimations`. On Windows it reads Settings > Accessibility > Visual effects > **Animation effects** (`SPI_GETCLIENTAREAANIMATION`) at start, and again on `WM_SETTINGCHANGE` while Cone runs.
  - When it is off, the tab switch is instant: page, icons, label, underline.
  - Other platforms: on (no such system switch is read there).
- **60 fps / UI thread:**
  - It is one number animation per tab, plus the existing page opacity. All of it is opacity and colour of a few items: no layout change, no timer, nothing when idle.
  - The only work on the UI thread is the property binding updates, the same kind as the existing page fade.
  - Pages are still created ahead (prewarm), so a switch never loads a page while it fades.
- **Themes:** the colours come from the palette (`rdFgA3`, `rdFgA2`, `rdAccentMain`, `rdAccentDim`), so dark and light both work. Checked in the sandbox in both.
- **Profiles:** nothing depends on the brand profile.

## 4. Checks
- qmlcheck: errors 1 (the known HighResolutionTimeWidget stub), crashed 0.
- buildlists: 0 problems. privacycheck: 0 problems.
- `SPI_GETCLIENTAREAANIMATION` is in the mingw headers CI uses (needs `_WIN32_WINNT` 0x0600+; VLC targets Windows 7+).

## 5. Sandbox (Linux)
- **Builds:** before = build-linux 39313634848 (wip/next-test + #32); after = build-linux 39420022308 of the test-only branch `wip/motion-polish-linux` (wip/next-test + this branch + the Linux build job; never merge it).
- **Method:** the settings sidebar on a paused video, dark and light theme.
  - A still of every tab (Playback, Video, Audio, Subtitles).
  - A 60 fps screen recording (ffmpeg x11grab, sidebar only) of a click from Subtitles to Audio.
  - Screenshots and frames looked at side by side.

| Check | Before | After |
|---|---|---|
| Settled tabs, dark | every tab as in Figma | the same. Tab bar pixel diff: no pixel off by more than 2 levels |
| Settled tabs, light | every tab | the same. The only differing pixels (5) are in the panel's rounded corner, where the video shows through |
| Mid-switch, dark and light | underline already only under Audio, Audio icon already two-tone and Subtitles grey, while the page is still half Subtitles | both underlines show (Subtitles fading out, Audio fading in), both icons and labels mid-fade, the page half and half |
| End of the switch | Audio tab | the same final state |
| Queue sidebar (same panel) | n/a | opens normally: Queue tab two-tone with its underline |
| QML warnings in the log | none | none |

**Limits of the sandbox:**
- It renders with software OpenGL, so only 3 or 4 frames of each switch were drawn: the frames show the steps, not the 60 fps smoothness.
- Windows' "Animation effects" setting does not exist on Linux (it is always on there).
- Smoothness and the setting are Windows retest steps 5 and 6.

## 6. Retest on Windows
Use a build of this branch merged with wip/next-test, a video, and the settings sidebar (gear). Then do the same with the queue sidebar.
1. **Dark theme.** Click Subtitles, then Audio. The page cross-fades, and so do the underlines: Subtitles fades out while Audio fades in, both briefly visible. The Audio icon fades to two-tone and the Subtitles icon to grey. All of it is over in about 0.15 s, with no jump at the end. Click through Playback, Video, Audio, Subtitles quickly: no flicker, no tab left half selected.
2. **Light theme** (Settings > General > Theme > Light): same.
3. **Hover:** hovering a tab still changes its icon and label colour at once.
4. **Keyboard:** Left / Right on the tabs switches them with the same fade. Down goes into the page.
5. **Animation effects off** (Windows Settings > Accessibility > Visual effects > Animation effects: off, while Cone runs). The tab switch is instant: no fade, the new page and underline appear in one frame. Turn it back on: the fades return without restarting Cone.
6. **Performance:** with `QSG_RENDER_TIMING=1` (or the usual 60 fps recording), switch tabs 10 times: no frame over 16.7 ms caused by the switch.
7. **Queue sidebar:** Queue → Bookmarks → Chapters fades the same way.
