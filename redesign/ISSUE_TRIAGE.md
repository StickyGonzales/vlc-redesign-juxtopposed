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

# Round 2 (2026-11-13, PC session)

Everything new since the first triage (2026-11-11 15:55 UTC): the new issues #132 and #129, and new comments on #116, #98 and #69. #68 has nothing new. Read-only on GitHub: no comment, label, close or edit. Nothing fixed.

**How it was checked**
- All new text read in full; the three new screenshots (one in #129, two in #69) downloaded and looked at (not committed: the reporters' content).
- **Builds:** released **Cone 1.4.0** (Windows) and **wip/next-test** at `7ef172adfdb` (build-windows run 43432779701, green with smoke; it has #126, #127, #128, #130, #131).
- **Test media:** a generated MP3 with a square 600x600 cover (`attached_pic`), played in a window like the reporter's (about 1040x570), a wide one (1500x600) and a tall one (1100x900).
- **References:** Juxtopposed's Figma "Player - Music" and "Miniplayer" frames, VIDEO_INDEX rows 209 (P6-04) and 211 (IB-23), Decision 1, UP_NEXT_PLAN.md.

## The table

| Issue | Point | Classification | Ours or VLC | Evidence and reference | Reproduction (Windows) |
|---|---|---|---|---|---|
| #129 (Windows, FLAC and MP3) | Album art stretched when the window is resized; fine maximized | **Bug** | Ours (Cone's music view) | Their screenshot: a square cover squeezed into a tall, narrow rounded card at about 1040x570. Reference: Figma "Player - Music" and VIDEO_INDEX 209 / 211: "centered large square cover art with rounded corners". | **Reproduced on 1.4.0 and on wip/next-test:** at 1040x570 the cover is a narrow pill (about 120x380), at 1500x600 a tall card (about 215x505), at 1100x900 still taller than wide (about 490x765). The cover is never kept square except in some window shapes. |
| #69 (macOS) | Album art proportions "warped and random, depending on the song" | **Bug, the same as #129** | Ours | Their screenshot: a square cover in a tall card at a 16:10 window. | Same cause as #129 (the Windows reproduction above); the Mac part needs a Mac only to confirm. |
| #69 | "Picture-in-picture" with a long strip overlapping everything | **Needs more info; likely works as designed** | Ours (the mini player) | Their screenshot shows Cone's mini player at the bottom right of the library: picture, progress strip, title, folder, artist and queue icon, exactly Figma "Miniplayer". A real floating picture-in-picture window over other apps does not exist: skipped by Decision 1. | Not run (the screenshot already shows the design). Ask which part they mean: the progress strip, or the wish for a window over other apps (feature idea). |
| #69 | Opening a file from Finder while Cone is closed still does not play it | **Bug (known), macOS only** | Ours | Already in the 1.4.0 known issues ("double-clicking a file in Finder while Cone Player is closed opens Cone without playing the file"). | Needs a Mac. |
| #69 | The earlier bugs are fixed | Not a report (thanks) | - | - | - |
| #98 (new comment) | An optional close button in fullscreen, off by default | **Feature idea** | Ours | VLC and Juxtopposed's design have none (first triage, point 2). An opt-in setting would not change the default. | - |
| #98 | Filters in the OpenSubtitles search (type, year, season, episode) | **Feature idea** (asked again) | Ours | Her dialog has the search box and language only (W6.5). | - |
| #98 | Several API keys from separate OpenSubtitles accounts, to get more downloads a day | **Feature idea, with a caution** | Ours | Each account has its own daily limit, so it would work technically; rotating accounts to get around a service's limit may go against OpenSubtitles' terms. For StickyGonzales to decide. | - |
| #98 | Subtitle timeline: it was an MKV with built-in subtitles; elapsed time and FastStream answered | Answered, nothing to do | - | Confirms the first triage. | - |
| #132 | Play several audio tracks at the same time, each toggleable | **Feature idea** | VLC core | VLC plays one audio track at a time (one audio output per player; the core selects audio tracks exclusively). Mixing tracks would be a core change, not a Cone setting. | Not run (VLC behaviour). |
| #116 (new comment) | The maintainer's reply only (the fix is in 1.4.0, linux-v1.4.0-beta5) | Nothing new from the reporter | - | Could be closed once they confirm beta 5. | - |

## Confirmed bugs, by how many users they hit
1. **Album art not kept square (#129 Windows, #69 macOS).**
   - **Status:** reproduced on 1.4.0 and wip/next-test.
   - **Who it hits:** everyone playing music with a cover in a window that is not maximized.
   - **For the fix:** the cover must stay square (the Figma frame), the largest square that fits the space above the title, centred, rounded corners as now.
2. **Finder open while Cone is closed (#69).** Known, in the 1.4.0 known issues. Mac only.

## Drafted replies (not posted)

**#129**
> Thanks a lot for the report and the screenshot! You're right: the cover should always stay square, like in the design, and in a smaller or wider window Cone squeezes it. I could reproduce it with FLAC and MP3 here. It will be fixed in the next release, and I'll let you know here when it's out. Until then, a maximized window shows it correctly.

**#132**
> Thanks for the idea! Right now Cone plays one audio track at a time, which comes from VLC's engine underneath: the engine can only pick one audio track for playback. Mixing several would need changes deep in VLC itself, so it isn't something Cone can add as a setting soon. I've noted it as a feature idea though, and I'm keeping an eye on whether VLC adds it.

**#98**
> Thanks for the follow-up, and glad Auto-sync is doing the job! An optional close button in fullscreen, off by default, is a fair idea since it wouldn't change anything for anyone who doesn't want it. I've noted it, together with the OpenSubtitles search filters. About the extra keys: thanks for explaining, that makes sense. Switching between several accounts to get past the daily limit is something OpenSubtitles might not be happy with, so I'd rather not build that in. I hope that's understandable.

**#69**
> Thank you for testing again, great to hear the earlier bugs are gone! The cover that looks stretched is a real bug: the cover should stay square and Cone squeezes it in some window sizes. It also happens on Windows, and it's being fixed for the next release. Opening a file from Finder while Cone is closed is a known issue we're still working on. About the picture-in-picture: the small player in the corner is Cone's mini player from the design, and it lives inside Cone's window. Is the strip you mean the progress bar under the picture, or would you like a small window that floats above other apps? That would help me understand.

**#116** (only if StickyGonzales wants to follow up)
> Linux beta 5 (1.4.0) is out with the Wayland fix: https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/linux-v1.4.0-beta5. If you get a chance, could you check that the video now plays inside Cone with the controls in fullscreen? Thanks again!
## Round 2, strict check (2026-11-13, at StickyGonzales's rule)

A point is a **bug** only with evidence of a crash, freeze, data loss or wrong result, or of Cone not matching its reference (Juxtopposed's Figma or video, StickyGonzales's decisions and plan files for Cone extras, plain VLC 4 for VLC behaviour). Everything else is **works as designed** (with the reference) or a **feature idea** (default: not now; "worth considering" only if it helps most users). This replaces the judgements of the round 2 table above where they differ.

**New checks for this pass**
- **VLC 4 and several audio tracks (#132):** in the vlc profile build (`builds\current\vlc.exe`, the fork's VLC-branded build of 2026-10-16, same engine), a file with two audio tracks: the tracks list offers one choice (radio buttons), and choosing the second unselects the first in the log (`ES track unselected: 'audio/2'`, then `ES track selected (forced): 'audio/3'`). In VLC 4's engine (`src/input/es_out.c`, `EsOutPropsInit`) audio is created `ES_OUT_ES_POLICY_EXCLUSIVE`, while video and subtitles are `ES_OUT_ES_POLICY_AUTO` (several at once when asked). Plain VLC 4 cannot play two audio tracks together.
- **The fullscreen window buttons (#98):** Juxtopposed's video shows the top bar with minimize, maximize and close only in a window (3:48-3:55, VIDEO_INDEX row 41 P2-08: "window with both bars ... thin window border"); no frame or video moment shows fullscreen with window buttons. The vlc profile build uses Cone's interface, so stock VLC 4's own fullscreen could not be checked on this PC.
- **VLSub:** VLC's subtitle search extension (`lua\extensions\VLSub.luac`) ships in both the vlc build and Cone #250 (the Lua extensions are VLC's, not a search field in her design).

| Issue | Point | Verdict | Reference and evidence | Ours or VLC | Feature idea: who it helps, VLC or design has it, recommendation |
|---|---|---|---|---|---|
| #129 | Album art stretched when the window is resized | **Bug** | Figma "Player - Music" and VIDEO_INDEX 209 (P6-04) / 211 (IB-23): "centered large square cover art with rounded corners". Reproduced on 1.4.0 and wip/next-test: a square 600x600 cover becomes about 120x380 at 1040x570, 215x505 at 1500x600, 490x765 at 1100x900. | Ours | - |
| #69 | Album art proportions warped | **Bug, the same as #129** | Same reference; their screenshot shows the same squeeze on macOS. | Ours | - |
| #69 | Opening a file from Finder while Cone is closed does nothing | **Bug (known)** | A wrong result (the file is not played); already in the 1.4.0 known issues. Needs a Mac to retest. | Ours (macOS integration) | - |
| #69 | "Picture-in-picture" with a long strip | **Works as designed (Figma "Miniplayer")**; a real floating window would be a feature idea | Their screenshot is the mini player exactly as Figma "Miniplayer" (picture, progress strip, title, folder, artist, queue). Picture-in-picture over other apps: skipped by Decision 1. Ask which strip they mean. | Ours | Floating PiP: helps some users, VLC 4 has no PiP, her design marks the PiP icon only; **not now** (Decision 1). |
| #132 | Play several audio tracks at the same time | **Feature idea** | Plain VLC 4 plays one audio track at a time (checked above). | VLC core (the engine's audio policy) | Helps few users (commentary or language mixing); neither VLC nor the design has it; needs an engine change; **not now**. |
| #98 | An optional close button in fullscreen, off by default | **Feature idea** | Her design shows the window buttons only in a window (row 41); Ctrl+Q, Alt+F4 and leaving fullscreen work today. | Ours | Helps some users (mouse-only); the design does not have it; stock VLC 4 not checked here; **not now**. |
| #98 | Filters in the OpenSubtitles search (type, year, season, episode) | **Feature idea** | Her Add Subtitles dialog has the search box and language only (W6.5). | Ours | Helps users with ambiguous titles; the design does not have it; VLC's VLSub extension has its own search (title, season, episode); **not now**. |
| #98 | Several API keys from separate OpenSubtitles accounts | **Feature idea** | Cone has one key and one account, as designed. | Ours | Helps only users who exceed the daily limit and keep several accounts; neither VLC nor the design has it; rotating accounts may go against OpenSubtitles' terms; **not now**. |
| #116 | (the maintainer's reply only) | Nothing to judge | - | - | - |

**Bugs:** 2 (album art not square, #129 and #69; Finder cold open on macOS, known). **Worth considering:** none: no feature idea here helps most users.

### Reply drafts (replace the round 2 drafts above where they differ)

**#132**
> Thanks for the idea! I checked: VLC's engine, which Cone uses for playback, plays one audio track at a time, and choosing another track replaces the first. Mixing several tracks would need changes inside VLC itself, so it isn't planned for Cone for now. I've noted it as a feature idea.

**#98**
> Thanks for the follow-up, and glad Auto-sync does the job! I've noted the optional fullscreen close button, the search filters and the multiple keys as feature ideas. They aren't planned for now: the fullscreen bar follows Juxtopposed's design, and switching between several OpenSubtitles accounts to get past the daily limit is something their terms may not allow. Ctrl+Q and Alt+F4 close Cone from fullscreen in the meantime.

**#129** and **#69** and **#116:** the round 2 drafts above stand (#129 and #69: a real bug, being fixed for the next release; #69: the mini player question; #116: please confirm beta 5).