# Beta subtitles notes (branch wip/beta-subs)

Branch `wip/beta-subs`, made from `origin/wip/beta` (90f90b5a7a). Status: coded and compile-checked offline only. **Nothing here is verified**: it needs a build from this branch and a test round on the PC.

## 1. What changed

### A. Subtitles move above the control bar (beta blocker)
- While the bars are visible, subtitles at the bottom of the picture sit just above the control bar. When the bars hide, they go back down.
- The lift follows the bar's fade (it is the covered height times the bar's opacity), so the subtitles move with the same 200 ms fade as the bar, no jump.
- Uses VLC's own subtitle margin, the same mechanism as "Subtitle position" (`sub-margin`). The video itself never moves.
- Why a new core variable: setting `sub-margin` directly makes the player show the on-screen message "Subtitle position N px" every time the bars show or hide. The new vout variable `sub-ui-margin` is added to `sub-margin` inside the vout and has no on-screen message. The user's own Subtitle position still works and adds on top.
- Only the part of the bar that really covers the picture counts: the player works out where the bottom of the picture is from the picture's aspect ratio (video track size, pixel aspect, rotation, or a forced aspect ratio). A letterboxed film whose black bars are taller than the control bar gets no lift.
- The lift is 0 when nothing covers the picture: pinned controls (video sits above the bars), the music view (no video), the minimal view, the library, a hidden player. Leaving the player view sets it back to 0.
- The two-row Customize layout makes the bar taller, and the lift follows that height automatically (it reads the bar's real position).
- Windowed and fullscreen use the same code; the lift is in display pixels (window size times the screen scaling).

### B. External .srt under External Tracks (contained change)
- A subtitle file loaded from outside the media (drag and drop, Add Subtitles, `--sub-file`, autodetected next to the video) is now listed under **External Tracks** with its file name (for example `Episode 01.en.srt`) instead of "Track 1" under Embedded Tracks.
- How it is detected: VLC gives tracks from an external file an id that starts with a 32-character hash of the file's address (`<md5>/spu/0`); tracks of the media itself look like `spu/3`. The name comes from the media's slave list (VLC adds every loaded external file to it), matched by that hash.
- Embedded Tracks keeps its "None" row; it covers the external rows too (picking None turns any subtitle off). The External Tracks list has no None row.
- Audio and video tabs are unchanged (no external split there).

## 2. Files

| File | Change |
|---|---|
| `src/video_output/vout_intf.c` | **Core.** New vout variable `sub-ui-margin` (integer, not an option, no OSD); its callback and the `sub-margin` callback both apply `sub-margin + sub-ui-margin` to the primary subtitle channel. Both profiles (vlc and public). |
| `modules/gui/qt/player/rd_subtitle_lift.hpp`, `.cpp` | New. `RdSubtitleLift` QML singleton: `lift` (writes `sub-ui-margin` to every video output, also new ones) and `pictureAspect` (picture shape, 0 while unknown). |
| `modules/gui/qt/maininterface/mainui.cpp` | Registers the `RdSubtitleLift` singleton. |
| `modules/gui/qt/Makefile.am`, `modules/gui/qt/meson.build` | Build lists: the new .cpp/.hpp and its moc file. |
| `modules/gui/qt/player/qml/Player.qml` | `_subtitleLift`: covered height of the picture by the control bar, times opacity, in display pixels; bound to `RdSubtitleLift.lift`, reset to 0 on destruction. |
| `modules/gui/qt/player/input_models.hpp`, `.cpp` | `TrackListModel`: new `external` role; external tracks show their file name. |
| `modules/gui/qt/player/qml/TracksPopup.qml` | Subtitles tab: Embedded Tracks lists only embedded tracks, a new list under External Tracks lists the external ones. |
| `redesign/VIDEO_INDEX.md` | Two Decisions (Claude) lines, one Core changes line. |
| `redesign/INTERACTIONS.md` | Bars section: the subtitle lift and what must keep feeding it. |

## 3. How to test on the PC

Build this branch on its own (it has a core change): `gh workflow run build-windows.yml --ref wip/beta-subs`. Use a video with an .srt whose lines sit at the bottom.

**Subtitle lift**
1. Windowed, playing: move the mouse so the bars show. The subtitle line moves up and sits just above the control bar, nothing hidden. Stop moving: when the bars fade out, the subtitles slide back down with the fade. Watch for stutter or a jump at the start or end.
2. Fullscreen: bring the bottom bar in with the mouse near the bottom edge and out again. Same result.
3. Two-row Customize layout: switch to it in Customize Player, repeat 1 and 2. The subtitles clear the taller bar.
4. Pinned controls (VLC's "pin video controls"): the video sits above the bar; subtitles must not move at all.
5. Letterboxed film (2.35:1 in a 16:9 window): subtitles drawn on the black bar should move only if the control bar reaches into the picture, and only by that much.
6. Paused: show and hide the bars. The subtitles still follow (see risk 1 about small steps).
7. Settings, Subtitles, Subtitle position (or the sidebar slider) set to e.g. 50 px: the bars' lift adds on top; when the bars hide, the line goes back to the 50 px position, not to 0.
8. **No on-screen message** "Subtitle position ..." appears when the bars show or hide. Changing the user's own Subtitle position still shows it, as before.
9. Music view (audio file), minimal view, library: nothing changes there; going back to the video player, subtitles start in the right place.
10. Resize the window very small and to maximized, and Windows scaling 125 / 150 percent: the line stays just above the bar.
11. Next / previous file and opening a new file while the bars are visible: the new video starts with its subtitles above the bar (new video output gets the current lift).
12. Regression: subtitle on/off, track switching, secondary subtitles (they move with the primary), seek, and the subtitle sidebar sliders.

**External Tracks**
1. Drag an .srt onto a playing video. Open the subtitle tracks popup: the file shows under External Tracks with its file name and is selected. Embedded Tracks shows only the video's own tracks plus None.
2. Same with Add Subtitles (From Computer), with `--sub-file`, and with an .srt next to the video that VLC loads by itself.
3. Pick an embedded track, then the external one, then None: the selection marks are right in both lists.
4. A video without embedded subtitles plus an external .srt: Embedded Tracks shows only None, External Tracks shows the file.
5. Audio and video tabs look as before.

## 4. Risks
1. **Paused video:** VLC redraws a paused picture about every 80 ms, so while paused the subtitles move in steps instead of smoothly. Playing video moves every frame.
2. **Lock contention:** during a bar fade the interface writes the margin up to once per frame; each write takes the subtitle lock briefly. Should be harmless, but watch for a frame drop during a fade on 4K files (PERF rule).
3. **Not modelled:** crop, zoom, "fit" modes other than the default fit, and VLC's subtitles-in-black-bars option (spu fill). In those cases the lift can be a bit too big or too small.
4. **Units:** the margin is taken as display pixels, which is how the Windows output (d3d11) draws subtitles. Another video output that draws subtitles at the video's own size would lift by the wrong amount.
5. **Core change:** `src/video_output/vout_intf.c` must be built and tested on its own branch (Decision 27 / 55), and it affects both profiles (vlc and public).
6. **File name timing:** the file name is found once VLC has added the file to the media's slave list; for a moment right after loading, the track can still show its plain title.
7. **None row:** the only None row is under Embedded Tracks; it also turns off an external track. Check with StickyGonzales that this reads right.

Nothing in this file or in VIDEO_INDEX.md is marked verified.
