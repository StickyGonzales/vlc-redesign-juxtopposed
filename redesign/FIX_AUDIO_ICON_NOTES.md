# Audio track menu entries: Figma's audio icon (branch wip/fix-audio-icon)

Branch `wip/fix-audio-icon`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Interface only (`modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml`), no core change.

Found in the F-11 sandbox test (PR #41): the "Add Audio Tracks" icon had more bars than Figma's.

## 1. Cause
The library "..." menus used the icon set's `waveform_two-tone-yes` (Figma component "waveform": 6 bars, x 2 to 22) for their audio track entries. Figma's menus use the component "audio, two-tone" (2461:9697) everywhere:
- file context menu, "Add Audio Tracks";
- playlist context menu, "Add Audio Tracks";
- folder context menu, "Edit Audio Tracks".

That icon has 5 bars at x 4, 8, 12, 16, 20 (heights 2, 8, 18, 12, 6). The bars at 8 and 16 are accent, the others FG.

The icon set already has it as `audio_two-tone-yes.svg`, path for path the same as the Figma node.

## 2. Fix
The three entries use `audio_two-tone-yes`. The waveform icon stays in the icon set (it is a Figma component of its own); nothing else used it.

## 3. Checks
- qmlcheck: errors 1 (the known HighResolutionTimeWidget stub), crashed 0.
- buildlists: 0 problems.
- privacycheck: 0 problems.

## 4. Sandbox test (Linux)
Linux build 27 (run 39434844289, branch `wip/fix-audio-icon-linux` = this branch + wip/linux-build), AppImage, Xvfb, openbox. A playlist row's "..." on the Playlists page; "before" = Linux build 26.

| | Bars (x in the 24 px icon) | Accent bars | FG bars |
|---|---|---|---|
| Before | 6 (2, 6, 10, 14, 18, 22) | 2, 10, 18 | 6, 14, 22 |
| After | 5 (4, 8, 12, 16, 20) | 8, 16 | 4, 12, 20 |
| Figma (2461:9697) | 5 (4, 8, 12, 16, 20) | 8, 16 | 4, 12, 20 |

Side by side at 4x (before / after / Figma "playlist context menu"): `redesign/fix-shots/audio_icon_sbs.png`. The accent bars use the same Accent/DIm colour as the other menu icons. Cone quits cleanly (exit 0).

The other two entries (file "Add Audio Tracks", folder "Edit Audio Tracks") use the same icon name in the same file and were not opened in the sandbox; the Windows steps below cover them.

## 5. Windows retest steps
1. Open the library, go to **Playlists**, open a playlist row's "...".
   - Expect: "Add Audio Tracks" shows 5 bars, the middle one tallest, the 2nd and 4th in the accent colour, as in Figma "playlist context menu".
2. Same in the playlist page's header "...".
3. Open a video file row's "..." (Videos page).
   - Expect: same icon on "Add Audio Tracks" (Figma "file context menu").
4. Open a folder page's header "..." (Videos > a folder).
   - Expect: same icon on "Edit Audio Tracks" (Figma "folder context menu").
5. Settings > General > "Accent color": pick another accent.
   - Expect: the two accent bars follow it.
