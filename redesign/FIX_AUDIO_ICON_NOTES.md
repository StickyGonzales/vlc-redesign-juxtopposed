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
RESULTS

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
