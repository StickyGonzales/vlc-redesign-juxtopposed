# Issue triage (2026-11-11)

Every open GitHub issue (#116, #98, #69, #68), each point classified against its reference, following the "User reports and issues" rule in CLAUDE.md:
- **Juxtopposed's design:** her Figma file and her video.
- **Cone extras:** StickyGonzales's decisions and the extra's plan file.
- **Anything that behaves like VLC itself:** as intended.

Read-only on GitHub: no comment, label, close or edit. Nothing fixed.

**How it was checked**
- **Issues and attachments:** all four issues and every comment read; all 12 attachments (11 screenshots, 1 screen recording) downloaded and looked at. The recording was viewed as a one-frame-a-second contact sheet. Not committed: they are the reporters' content.
- **Sandbox:** Linux, X11 (Xvfb) and a real Wayland session (headless Weston, Cone as a native Wayland client).
- **Builds used:**
  - **Released Linux 1.3.0 beta 4** (`linux-v1.3.0-beta4`), the reporter's own build, for #116.
  - **build-linux #103** for everything else. It is `wip/next-test` of 2026-11-08 plus #101 and #107, and has the same interface code as the issues need.
- **Why not a fresh `wip/next-test` build:** build-linux #108 on `wip/next-test` (`fd89953b41`) fails before compiling. `apt-get install` in the Ubuntu 22.04 image exits with code 100 on all three tries (run 43051428950). That is a CI problem, not an issue, and is listed at the end.

**Classifications:** likely bug / works as designed (with the reference) / feature idea / needs more info.

## The table

| Issue | Point | Classification | Evidence | Reproduction (Linux sandbox) | Steps on Windows (PC) |
|---|---|---|---|---|---|
| #116 (Linux 1.3.0 beta 4, KDE Plasma 6.8 on Wayland, NVIDIA) | Video plays in a separate window instead of inside Cone | **Bug (confirmed), a regression from beta 3.** | Their windowed screenshot: a second window titled "Cone Player" holds the picture, while Cone's own window shows the placeholder card and "Do you want to restart the playback…". Their beta 3 screenshot shows the picture inside Cone. | **Reproduced** with the released beta 4 under Wayland: Cone's window shows the placeholder while the time runs (`fix-shots/issue116-wayland-beta4.png`); the log has `using vout window module "wdummy"`, so the video is not given Cone's window. A build from the old Debian image under the same Wayland session draws the picture inside Cone (`fix-shots/issue116-wayland-debian-image-build.png`). On X11 beta 4 embeds correctly (`vout window "qt"`, `xcb_render`). **Cause:** the beta 4 package has no `plugins/gui/libqt_wayland_plugin.so` (the Debian-image build has it). Without it Cone has no Wayland compositor (`QT_HAS_WAYLAND_COMPOSITOR` needs Wayland and Qt's private GUI headers at configure time). The packages moved to Ubuntu 22.04 with the official Qt 6.8.3 in `be9479502b` (glibc 2.35), and the build no longer finds what the Wayland compositor needs. | Linux only (Wayland session). Not a Windows issue. |
| #116 | No playback controls in fullscreen | **Bug (confirmed), the same cause.** | Their fullscreen screenshot: only the picture, no bars, with the pointer over the seek bar's place. | Follows from the previous point. Fullscreen shows the separate video window, which has no Cone bars. Fixing the Wayland compositor fixes both. | Not needed. |
| #98 (Windows, about 1.1 / 1.2) | 1a. Changing the subtitle font changes the interface font | **Needs the PC (not reproducible on the current build).** | Text only. | **Not reproducible:** with the subtitle font set to FreeMono the subtitle uses it and the interface stays in Inter. Both the sidebar row and the Settings dialog row write VLC's `freetype-font`, which the interface never reads. Likely what they saw: before #104 (merged 2026-11-08, after this report) VLC's on-screen messages (volume, seek, speed) were drawn with that same font. They are Cone's own now. My check of the on-screen message was inconclusive: the volume key did not show a message in the sandbox. | Settings > Subtitles > Font: type "Courier New". Play a video with an SRT. Press Ctrl+Up / Ctrl+Down and look at the volume message and the top bar: they keep Cone's font; the subtitle is in Courier New. |
| #98 | 1b. Some videos' subtitles keep their font | **Works as designed (like VLC).** | Text only. | Not run. ASS/SSA subtitles carry their own fonts and styles, and VLC draws them as written. Cone has "Ignore styling in ASS and SSA subtitles" (S2-11, VIDEO_INDEX "Core changes") for this. | — |
| #98 | 1c. The font change only shows after a restart | **Works as designed.** | Text only. | VLC reads these options when the subtitle renderer opens. The sidebar says "Font, colors, outline and background apply from the next file" (VIDEO_INDEX W4.6, Decision 29). Live styling would need a core change (an open decision, "pixel subtitle size / live style"). | — |
| #98 | 1d. Keyboard shortcut changes only work after a restart | **Works as designed (like VLC).** | Text only. | VLC builds its key map once at start (`src/misc/actions.c`). The Keyboard Shortcuts dialog says "New shortcuts take effect after a restart." Live shortcuts would be a feature idea. | — |
| #98 | 2. No close / minimize / maximize buttons in fullscreen | **Works as designed (like VLC); the alternatives are feature ideas.** | Text only. | Like VLC: leave fullscreen (F, Esc or the top bar's button), Ctrl+Q, Alt+F4. A fullscreen-only Quit button, or keeping the window buttons in fullscreen, is a feature idea for StickyGonzales. | — |
| #98 | 3. "Show Subtitle Timeline on Seekbar" does nothing | **Works as designed for embedded subtitles; needs more info** (their file's subtitle type). | Their screenshot is an MKV from a download site, which usually carries embedded subtitles. | **Not reproducible with a subtitle file.** With an external SRT the sidebar toggle turns the seek bar into the timeline (`fix-shots/issue98-subtitle-timeline-on.png`). It is saved (`qt-seek-subtitle-timeline=1`) and comes back after a restart and on replay. Embedded tracks show no timeline, by design (VIDEO_INDEX 2026-10-18 P3-16: "embedded tracks show no timeline"; Decision 27: "embedded later if feasible"). The toggle gives no sign of that, which a user cannot tell from a bug: worth a hint (feature idea). | Play a video with an external .srt next to it. Sidebar > Playback > Show Subtitle Timeline on Seekbar ON: the timeline shows. Then an MKV with only embedded subtitles: no timeline (by design). |
| #98 | 3b. A subtitle timeline like FastStream's (text in blocks under the seek bar, drag the row to shift the subtitles) | **Feature idea.** | Their screenshot and 9 s recording: blocks with the subtitle text under the seek bar, dragged left and right while the subtitle on the video follows. | Cone already moves subtitles by dragging the timeline's blocks (VIDEO_INDEX 87, Juxtopposed's 6:52-7:04, verified on Windows). Text inside the blocks and a separate row are a different look than her design. | — |
| #98 | 4. Filters in Add Subtitles' OpenSubtitles search (type, year, season, episode) | **Feature idea.** | Text only. | Her dialog has the search box and language only (W6.5). | — |
| #98 | 5. Several OpenSubtitles API keys, switching when one hits its daily limit | **Feature idea** (with a caution). | Text only. | OpenSubtitles counts downloads per user account, not per API key, so more keys may not give more downloads. For StickyGonzales to decide. | — |
| #98 | 6. Clicking the elapsed time makes it editable | **Works as designed (Figma).** | Their screenshot: the time field in edit mode with a caret. | As designed: Figma's "Current Time" component turns into an editable field on click, and Enter jumps to the typed time (FIGMA_FLOWS.md "Current time"; built in W3.5, `d61c5843a1`). | — |
| #69 (macOS, Apple Silicon, test build) | The video is see-through or only partly drawn; sound plays | **Likely bug, macOS only.** | Their screenshots: the window behind (a text editor) shows through Cone's video area, the subtitle draws, and the picture covers only the lower part. A later comment: "a part of the video would show up, but then subsequent videos wouldn't". | **Not reproducible here** (needs a Mac). GitHub's Mac runner also showed no picture. MACOS_NOTES.md put that down to the runner's virtual GPU, but this report shows the same family of fault on a real Mac, so that conclusion needs revising: the picture problem is in Cone's macOS video output path. | Not Windows: needs a real Mac (the volunteer in #69). |
| #69 | Opening a file from Finder does nothing (no error) | **Likely bug, macOS only.** | Text only. | Not reproducible here. On macOS, Finder opens files through an "open document" event, not the command line; Cone's macOS build uses the Qt interface instead of VLC's macOS one, which handles that event. | Needs a Mac. |
| #69 | Opening a `.m3u` lists "Your media can't be opened" for every song | **Needs more info**, probably macOS privacy (Desktop folder access). | Their screenshot: every song is under `~/Desktop/…/Music/Albums/…`; errors only, no permission prompt. | Not reproducible here. macOS asks before an app reads the Desktop folder. An unsigned app may not get that prompt, which would explain why files there fail. Same songs from another folder would tell. | Needs a Mac. |
| #69 | Onboarding "Learn the basic keyboard shortcuts": key caps run past the right edge | **Likely bug, macOS** (long key names). | Their screenshot: with "COMMAND" spelled out, the Mute, Snapshot and Record keys are cut off at the right edge, and a "/" overlaps "Increase". | Not reproducible with Linux key names (short). Could be checked on Linux by giving those actions long shortcuts. | Needs a Mac (or long shortcuts on any system). |
| #69 | Escape closes Settings | **Works.** | Their comment: "escape does exit the settings window." | — (answer to the tester list) | — |
| #69 | Offer to help test and build on Mac | Not a report. | — | — | — |
| #68 (Windows) | RTX Video Super Resolution and RTX HDR | **Partly there (VLC); the rest are feature ideas.** | Text only. | **Already there:** VLC 4's Direct3D 11 output has RTX HDR, and Cone shows that setting in the sidebar's Video tab (HDR, `d3d11-hdr-mode`) and as Customize Player's HDR button. It also has "Super Resolution" scaling (`d3d11-upscale-mode`, RTX VSR on NVIDIA), which Cone does not show outside All Cone Settings. **Feature ideas:** a hotkey for each, a status display, whole-number upscale steps only. | Sidebar > Video: the HDR row lists VLC's choices. All Cone Settings > Video > Output modules > Direct3D11: the upscale mode lists Super Resolution. |

## Confirmed and likely bugs, by how many users they would affect

1. **#116: Linux on Wayland, video in a separate window and no fullscreen controls.**
   - **Status:** confirmed and reproduced.
   - **Who it hits:** every 1.3.0 beta 4 user on a Wayland session, the default on current KDE Plasma, GNOME and most distributions. X11 sessions are fine.
   - **Cause:** the Ubuntu 22.04 / official Qt 6.8.3 build has no Wayland compositor (`libqt_wayland_plugin.so` missing).
   - **Workaround until fixed:** an X11 session, or starting Cone with `QT_QPA_PLATFORM=xcb` (runs it through XWayland). Expected from the X11 result, not tested under XWayland.
2. **#69: macOS, the picture is see-through or partly drawn.**
   - **Status:** likely.
   - **Who it hits:** probably every Mac user. Needs a Mac to reproduce, and revises MACOS_NOTES.md's "the runner, not Cone".
3. **#69: macOS, opening files from Finder does nothing.**
   - **Status:** likely.
   - **Who it hits:** every Mac user who opens files from Finder.
4. **#69: macOS onboarding, shortcut key caps cut off.**
   - **Status:** likely.
   - **Who it hits:** every Mac user once, at the first start. Cosmetic.
5. **#98 1a: subtitle font seen in the interface.**
   - **Status:** not reproducible on the current build; most likely the old on-screen messages, fixed by #104. One Windows look decides.
6. **#69: `.m3u` songs under Desktop cannot be opened.**
   - **Status:** needs more info; probably macOS privacy, not Cone.

## Found on the way (not from an issue)
- **The `wip/next-test` Linux build is broken.**
  - build-linux #108 (run 43051428950) stops at "Build image": `apt-get install` in `.github/linux/jammy.Dockerfile` exits with code 100, three tries.
  - The step builds the Ubuntu 22.04 image from `be9479502b`. A package that stopped installing on Ubuntu 22.04 is the likely cause.
  - Not fixed here.
- **Cone crashed when the sandbox stopped it.** After SIGTERM under the headless Wayland session, Cone ended with a segmentation fault: once with the Debian-image build, once with beta 4. The next start then offered to restore the playlist. Seen only in the sandbox's kill path; not investigated.
