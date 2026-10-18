# STATUS

- Updated: 2026-10-19 evening, Phase 2 in progress (stopped at 99 % usage). Continue from "Phase 2: where it stopped".

## Phase 2: where it stopped
- Clean-up done (Sticky approved A, B, D, C): old builds, test lanes and old verify runs deleted (~9.4 GB); 44 clean worktrees removed; skipped: 22 agent-* worktrees (pre-rewrite history, 59-376 commits not on GitHub) and r5-diag (dropped diag commit).
- Decision 65 (Linux rows count after a quick Windows look) in CLAUDE.md + VIDEO_INDEX on redesign (8acefcb9187).
- Test branch wip/next-test = redesign + wip/web-fixes-1 (merged) + wip/web-fixes-2's own commits (cherry-picked; its Linux base and Linux CI left out). Build 39133249819 was running: download it, run the gate smoke, then retest the screens the fixes touched (Settings pages, sidebar Audio/Subtitles, queue/chapter/bookmark rows, Keyboard Shortcuts search, top bar title, seek bar on files with chapters, Add Subtitles, external subtitle names).
- Rows marked verified so far in this branch's VIDEO_INDEX (Linux pass + Windows look on 39125167074): main menu 9, library 22, bars / Hide UI 4, Open Network Stream 2, Customize 2, light theme 4, resume toast 1, music view 4; plus P4-03 and IB-35 from the video + Windows (50 rows).
- Still to mark after the new build's look: Linux rows of screens 1 (player 38), 3 (tracks 4), 4 (Add Subtitles 8), 5 (sidebar 43), 6 (Settings 18), 7 (queue 8), 9 (shortcuts 1). Settings pages looked identical to Figma on 39125167074 (all 13).
- Not marked: onboarding P8-29/30/31: the build shows the onboarding as a card over the player, Figma's frames fill the window: for the web session to judge.
- Drag tests (scratchpad drag_tests.ps1, not in the repo): Customize palette items are not in UI Automation, so drag by screen position: Stop sits at about (561, 103) in an 800 px wide copy of the 1600x900 window (logical about x 1122, y 206); drop on the control bar. Opening the library closes the queue panel, so drag to the queue needs another route (check the video P5-24 / Figma playlist.png for how both show).
- Video-only rows left: P4-12, P4-21 (sidebar footer over scrolled content), P8-45 (Subtitle page scroll), P8-47 (customize drag visuals), motion IA-19 / IB-05 / IB-21, context IB-28 / P8-52.
## Phase 2 results on 39133249819 (wip/next-test = redesign + web-fixes-1 + web-fixes-2's own fixes)
- Smoke: pass (play, pause, seek, volume, sidebar tabs, Ctrl+P Settings, Ctrl+Q 0.3 s, no crash event). Screens dark + light: all open / work / close except Escape on the library sidebar (known).
- Web fixes seen on screen: bookmarks rows start at the edge with hh:mm:ss:mmm; Subtitles tab without the "Applies from the next file" line; Privacy extra row at the end; Video deinterlacing "Automatic"; Keyboard Shortcuts search field full height. FAIL: the sidebar Audio tab still shows "Track and language apply from the next file" under Defaults (not in Figma; the fix covered the Subtitles tab only) -> bug for the web session (P4-15 left unmarked).
- Real-mouse drag and drop: Customize drag in (palette Stop -> control bar: ghost with icon and label follows the pointer, Stop appears on the bar, Save turns orange, Cancel restores) and drag out (queue button -> palette: palette shows a dashed drop box, Queue returns to the palette): pass. Drag from the compact library to the queue: ghost with thumbnail and file name, orange insertion line, queue 2 -> 3 items: pass (P5-24, as the video at 11:44). Finding: opening the queue and then the library closes the queue; library first, then queue keeps both open (check against the video / Figma). Mini player queue (P5-28): the queue opens stacked above the mini player as one card (as the video at 11:54); a real-mouse drag moves the whole card, it snaps to the bottom-left corner and back to the bottom-right: pass.
- IB-28 (menu re-order): the main menu has the Decision 2 final order (Figma menu.png, same as the video's last menu at 19:29); the 13:08 order and its shuffle are video steps: pass.
- P8-52 (montage close-ups): pause pill, seek bar (dark-orange fill, taller orange pill thumb) and the delay slider (vertical pill thumb, "0 s" below) match; not marked because the subtitle timeline on the seek bar is not built yet (P3-16 / IA-27 / P4-35 todo, no "Show Subtitle Timeline on Seekbar" row in the Playback tab).
- IB-21 (library navigation crossfade, shots every 60 ms): old and new rows overlap at the same place, no slide, done in about 120 ms: matches. Bug (low, web session): the breadcrumb title switches at once instead of crossfading with the rows (video 12:12 shows old and new breadcrumb overlapping). Row not marked.
- Not testable here: IB-05 (Add Folder transition needs the Windows folder dialog), IA-19 (bar icon slide when an icon is inserted).
- P8-25 / P8-26 (alternate layout by real-mouse drags in Customize, one run): dashed outlines on every top and bottom bar item; the seek bar ends up on its own full-width row (time left, total right) and the title moves from the top bar into the bottom bar; Save applies it: matches so far. Rows not marked: Favorite from the palette did not land in the bottom bar (drop spot may have missed), prev / play / next and the top-bar items were not moved, and the seek bar looked unchanged in the shot 1 s after its own drop (both changes showed after the title drag). Bug (medium, web session): after Save the title in the bottom bar is cut to "Bet..." with plenty of free space around it (in edit mode it showed the full file name).
- Video-only rows: P4-12 (Subtitles Defaults, video 8:35), P4-21 (sidebar footer stays while the content scrolls under it, 8:47), P8-45 (Settings Subtitles scrolls to Outline / Shadow / Background / Timing / On-Screen Messages, 18:10): pass. Settings Subtitles 'Size values' reads Relative / Precise, Figma Relative / Pixels: bug for the web session.
- Rows marked this session: 50 (first pass) + 108 + 8 (Add Subtitles) + 4 (P5-24, P8-47, P5-28, IB-28) + 3 (P4-12, P4-21, P8-45) = 173 verified. Not marked: P4-15 (Audio note), onboarding P8-29/30/31 (card vs full window), P8-25 (two-row seek bar part not tested), P8-26 / P8-48 / F-22 (alternate layout, timings).
## Lag / freeze check (Sticky: like the old subtitle timing lag), 2026-10-19, build 39133249819
- Method: while the video plays, every sidebar slider (Speed, Audio Track Delay, Subtitle Track Delay, Subtitle Speed, Subtitle Duration Factor) is dragged with the real mouse back and forth (166 steps each) and the subtitle delay, audio delay, speed, volume, seek, subtitle track (v x34) and audio track (b) keys are pressed rapidly; after every step the UI thread's reply time is measured (SendMessageTimeout) and the shown time must keep moving.
- Generated MKV and the real test film (<TEST_MOVIE>, 1080p x265, 16 subtitle tracks): UI reply avg 0 ms, max 8 ms, never above 100 ms; playback kept moving through every slider drag and key loop (subtitle track cycling: 00:00:14 -> 00:00:18 in 3 s); no hang, no crash events. No lag like the old subtitle timing one.
- BUG HIGH (for the web session): QUIT HANG, reproducible 4 of 4 on <TEST_MOVIE> after the full sequence (every sidebar slider dragged back and forth, then the subtitle delay, audio delay, speed, volume, seek, subtitle track and audio track key loops), then closing the player: the window goes, the process stays alive (70-71 threads, idle CPU, responding) and never exits; no crash event. Narrowed (one run each): sliders + track cycling keys (v, b): HANG; sliders + delay / speed keys: HANG; sliders only: clean; keys only: clean; so the trigger is the sidebar slider drags followed by any player key action. A single slider is enough: Speed alone + the key loops: HANG; Subtitle Track Delay alone + the key loops: HANG (8 hanging runs in total, every time 70-72 threads left). not with play + Ctrl+Q, not with subtitle cycling + Ctrl+Q (all quit in 0.3-0.6 s). Stacks saved locally per run (verifyruns gate-*-lag-real\quit-hang-<pid>.txt): threads waiting include vlc-player-end, vlc-qt, vlc-mmdevice, QQmlThread. Test scripts: session scratchpad lag_real_rep.ps1 / lag_bisect.ps1 (not in the repo).
## Light theme vs her design (bugs for the web session, 2026-10-19)
- 01 Player: surfaces use her light BG/A3 #D5D5D5 and the seek track BG/B2 #DEDEDE; her "Player - Light" frame is darker overall (bar about #ABABAB), possibly a dim overlay in that Figma frame: check before changing; a 2 px #ACACAC line (her Divider/Dim) runs along the top of the control bar, not in her frame; the volume ramp goes green-orange-grey, hers green-yellow-grey.
- 02 Settings sidebar: panel and fields on her light tokens; the selected segment (Flip "None") is solid orange with white text, where her design's selected style would be the accent-bright fill #D8BA9A with orange text; field labels are low contrast on #E7E7E7.
- 03 Queue: panel colours match; the active tab underline is a pale orange blend instead of a clear accent line; the active queue button shows a grey box around its icon.
- 04 Library sidebar: rail #B3B3B3 and panel #E7E7E7 match; a #A0A0A0 strip above the sidebar and a #CDCDCD header divider are not her palette colours.
- 05 Full library + mini player: the title bar is #DADADA (not a palette colour); the search box is a solid #888888 block without its "Search" placeholder; rail labels low contrast; the mini player's progress track is almost invisible.
- 06 Settings: the left navigation and the Advanced Options bar are #DADADA (not a palette colour, BG/A3 #D5D5D5 expected); the search field is a solid #888888 block; the selected Theme segment is solid orange instead of the accent-bright fill; disabled rows (Log file, Log details) are almost invisible.
- 07 Main menu: matches (her BG/A3 #D5D5D5, icons in her light Accent/Dim as Decision 16, items and order as Figma, Cone wording by design).
- 08 Right-click menu: matches (BG/A3 #D5D5D5, items and order as Figma; "Shift + R" for Record is VLC's own shortcut, Decision 22).
- Overall: the main surfaces are exactly her light colours (BG/B1 #E7E7E7, BG/A3 #D5D5D5, BG/B2 #DEDEDE, BG/A4 #B3B3B3, distance 0-3 in the strips); off-palette: #DADADA (title bar, Settings navigation), #A0A0A0 (library title strip), separator greys #CDCDCD / #C2C2C2 / #BABABA, the #888888 search fields, and selected segments in solid orange.

## GitHub housekeeping (2026-10-19)
| What | Items |
|---|---|
| Branches deleted (44, each fully merged into redesign, checked with rev-list before deleting) | redesign-addsubs, redesign-customize, redesign-library, redesign-presets, redesign-settings, redesign-waveform, wip/a1e06ae1c89fa4775, wip/a57816e7ded7d7265, wip/a84f3cfa07ac47ba6, wip/a9364ffaea8630df4, wip/aac3dd02cc9c78a37, wip/abd4353e9b2232c2f, wip/ad0e6eca4f1b46b4e, wip/af508acbb14fd9657, wip/afb881bd305ed7728, wip/beta, wip/beta-brand, wip/beta-fix-barzone, wip/beta-subs, wip/brand-layer, wip/cone-release, wip/customize, wip/endless-sliders, wip/fix-library-2, wip/fix-panels-2, wip/integ-addsubs, wip/integ-batch5, wip/music-player, wip/player-fixes, wip/slider-wheel, wip/sweep-fix-bar, wip/sweep-fix-customize, wip/sweep-fix-customize2, wip/sweep-fix-exit, wip/sweep-fix-toast, wip/sweep-fix-waveform, wip/sweep-fix-wheel, wip/sweep-fixes, wip/sweep-results, wip/verify-spec, wip/w43b-playback, wip/w52-folders, wip/waveform-fix, wip/wheel-bars |
| PRs closed (with a comment saying where the work went) | #18 wip/verify-linux (report applied, Decision 65), #13 wip/verify-sheets (sheets served the rounds), #12 wip/code-audit (report). Earlier: #7, #9, #14, #15 |
| PRs left open (unmerged work) | #19 web-fixes-2, #17 web-fixes-1 (both in wip/next-test, merge into redesign after its test), #16 linux-build, #11 readme-cone, #10 sidebar-musthaves, #8 ci-release |
| Branches remaining | master, redesign, wip/a839e9d9ddb97595a, wip/beta-gate, wip/ci-release, wip/code-audit, wip/fix-library, wip/fix-panels, wip/linux-build, wip/next-batch, wip/next-test, wip/readme-cone, wip/sidebar-musthaves, wip/verify-harness, wip/verify-linux, wip/verify-sheets, wip/web-fixes-1, wip/web-fixes-2, wip/web-fixes-3, wip/web-fixes-3-linux |
| Local clean-up | the 22 pre-rewrite agent-* worktrees and r5-diag removed with their local branches (that history is never pushed); worktrees left: r3-revert, r5-beta, r5-gate, r6-next |
## Beta v0.1.0-beta: where it stands
- wip/beta = 6f8db273af6: next-batch + cone-release + branding + bar wake fix + mini player fix + skins removal (Decision 63, wip/beta-brand, review in redesign/BETA_BRAND_REVIEW.md) + subtitles above the bar and External Tracks (wip/beta-subs, redesign/BETA_SUBS_NOTES.md; checked against the video: 6:33 subtitle line above the bar, 6:22-6:24 External Tracks list) + window size fix (074a7eb06d5, PC session, Sticky's go). Checkers: qmlcheck errors 1 / crashed 0, buildlists 0, privacycheck 0.
- Builds: core-change builds on their own branches: wip/beta-brand 39119928788 (skins start checks pass, smoke pass), wip/beta-subs 39119930398 (smoke pass, one rare silent crash, see known issues); full beta 39120703950 (smoke pass, Ctrl+P opens Settings); fixed beta 39125167074 running: gate runs on it.
- Gate (Sticky, shortened): playback matrix, 30 quits, portable footprint, branding in full; main screens dark + one light pass, 20 min playback last, one speed check; plus the bar wake retest, mini player over video, subtitles above the bar windowed and fullscreen, skins checks, window size stable over restarts.

## Beta gate on 39125167074 (#53, wip/beta 6f8db273af6), run verifyruns gate-20261018-142041-b53
- Smoke: pass (play, pause, seek, volume, every sidebar tab, Ctrl+P Settings + Escape, Ctrl+Q 0.4 s, no crash event).
- Window size over six restarts: 750x525 every time (fix 074a7eb06d5 works; before: about 17x9 px smaller per restart).
- Subtitles above the bar (continuous test line): windowed 1600x900 and 1920x1080, bars shown: line above the control bar; bars hidden after 4.5 s: line back down; fullscreen, pointer at the bottom edge: only the control bar, line above it; still: back down. Pass (screenshots gate-*-subs, gate-*-bigwin).
- Bars wake on a move over the middle of a 1920x1080 window (the old large-window bug): pass.
- Mini player over a playing video: hover shows the dimmed picture with Close, Open the player, previous, pause, next and the seek handle; away: hidden. Pass (gate-*-mini).
- Screens dark (purple accent) and light: everything opens, works and closes except Escape on the library sidebar (known issue); contact sheets looked at: About shows Cone 0.1.0, based on VLC 4.0.0-dev, Built by StickyGonzales; no update dialog or banner.
- Playback matrix: 9 files pass (MP4, MKV with audio / subtitle switching, AVI, AVI without index with the index question, MP3, FLAC, M4A, 4K60, MP4 + external .srt listed under External Tracks); contact sheet looked at.
- Quit: 30 of 30 clean (15 Ctrl+Q, 15 WM_CLOSE, slowest 0.69 s), 0 players left, 0 crash events.
- Branding: 3430 on-screen texts and window titles with no "VLC" except the allowed attribution; file-level hits accepted: exe LegalCopyright "VideoLAN and VLC Authors" (GPL notice, required), the CI artifact folder name (not in the release zip), vlc-cache-gen.exe and vlc-preparser.exe (engine helpers, not user-facing). README.txt in the zip is Cone's.
- Speed: the gate's perf part stopped on a tool bug (fixed in 277560ec9f7, wip/beta-gate) with the PC 31 % busy; per Sticky the last measured round is reused (PERF.md round 3: startup and CPU equal to stock, open file faster).
- 20 min continuous playback (rerun with the fixed tool): no crash, no freeze, window responding and time moving at every minute check over all seven files; private memory flat at 271-279 MB for 18 minutes over six files, then 401 MB when the 4K60 file started (4K decoder buffers) and 321 MB on the next file, threads +10 with the 4K file: no leak (the tool's growth number is the 4K file arriving at the end). Screenshots at 1 / 6 / 11 / 16 min looked at. Pass.
- Footprint: Cone's settings stay in portable (no %APPDATA%\Cone); %APPDATA%\vlc and the installed VLC untouched by Cone. Cone writes Qt's QML and graphics pipeline cache to %LOCALAPPDATA%\Cone\cache even in portable mode (as stock VLC does in %LOCALAPPDATA%\vlc\cache): known issue. The gate tool's perf part started stock VLC without a portable folder, which rewrote %APPDATA%\vlc\vlcrc with identical content (same SHA-1 before and after) and refreshed %LOCALAPPDATA%\vlc's pipeline cache: gate tool bug (the stock lane needs its own portable folder), nothing of the owner's changed.
- GATE PASSED (2026-10-19): publish v0.1.0-beta from 39125167074 (release zip = that build folder + an empty portable folder).
## Known issues for the beta release notes
- Rarely, Windows may log a background error after closing Settings; no visible effect (once in three smoke runs: access violation in libqt_plugin.dll +0x6ea1cd about 2 s after Settings closed; not investigated further, Sticky).
- Escape does not close the library sidebar in the player; use the library button.
- New Cone texts are English in every language; the app shows version 0.1.0 (-beta only in the file names).
- The installer is not part of the beta (portable zip only, Decision 61); its screens still need the VM test.
- Cone keeps Qt's QML and graphics cache in %LOCALAPPDATA%\Cone\cache, also in portable mode (like VLC).
- The About dialog still has the old light style in dark mode; light theme: a thin grey line at the top of the control bar; an external subtitle file is listed with its full file name.

## Bugs for the web session (found on the PC, 2026-10-19)
- Light theme: a 2 px darker grey line (#ACACAC on #D5D5D5) at the top edge of the control bar, across the full width including the frame margin (Sticky saw it; measured on 39079182201 light pass bars__open). Not in Figma Player - Light, not in dark. The earlier fix 2593350797 removed the dark line only.
- External Tracks names (wip/beta-subs): the video (6:22-6:24, row 81) shows "The_Wand_S01E04 [English]" (file name without extension + language in brackets); the branch shows the full file name with extension.
- About dialog: still VLC's white stock dialog in dark mode (fix list: stock dialog look); text check on the beta build pending ("Built by Sticky" on 39079182201 must read StickyGonzales).
- Ctrl+P: opens Settings on Windows (all smoke runs, screenshot smoke__settings.png); the Linux issue (core "previous title" binding) does not show here. Fix on wip/web-fixes-1 is the web session's; recheck it on Windows after it lands.

## Verification round on 39079182201 (2026-10-19, screens not touched by skins or subtitles)
One line per screen: controls used by the gate screens part (open, one action, every close variant) + screenshot next to the Figma frame by eye.
- Player bars (bars__open): bar and top bar layout match Player.png; bar right side fixed (volume no longer covers the track buttons). Pass (look); rows wait for the full bar retest on the beta build.
- Settings sidebar Playback / Video / Audio: items, order, icons and styling match Controls.png variants; the 900 px tall window cuts the lower rows (Video: Aspect Ratio, Crop, Render, Filters; Audio: delay slider, Filters) so those are not verified; Audio shows the extra "Track and language apply from the next file" note. Partial.
- Tracks popup Audio / Video / Subtitles: structure and look match; track names differ ("English - English"). Logged.
- Queue / Bookmarks / Chapters: structure and look match Controls.png (one queued file, one bookmark added, five chapters). Pass (look).
- Main menu and Profile submenu: items, order, icons, shortcuts, separators match menu.png and Profiles.png ("About Cone" by design). Verified: P2-21, IA-22, P6-11, F-21.
- Right-click menu and Playback submenu: matches right-click menu.png ("Quit Cone" by design). Verified: P2-23, IA-23, P2-24.
- Library sidebar Home / Videos / Music: matches sidebar.png variants (empty test library). Escape does not close it (known issue).
- Full library with the mini player: layout matches Player-3.png; mini player buttons over a playing video fixed on the beta (2ac34d227cb), retest there.
- Settings dialog, every page: opens, every page renders, closes with Escape; General compared closely with Settings - global.png: match (values from the test profile). The other pages are not compared closely yet.
- Keyboard Shortcuts (open, search): matches Keyboard Shortcuts.png (more of VLC's rows than the sample). Verified: P7-12.
- About: opens; still the stock white dialog (logged).
- Rows verified this round: 8 (P2-21, IA-22, P6-11, P2-23, IA-23, P2-24, F-21, P7-12) in about 45 minutes of PC time (screens run 6 min + side-by-side review). Last round: 10 rows over four testing windows on 38829058873 (about 1 row per hour). (see round 2 below for the totals)
- Round 2 on 39120703950 (#51, beta, 2026-10-19, screens part dark + light: 49 of 50 checks pass, only Escape on the library sidebar fails; no update dialog or banner any more):
  - Tracks popup Subtitles: switching to German works (OSD "Subtitle track: German"), External Tracks header with pencil and +; names read "<title> - <language>" like the video's "Track 1 - English" (4:36; Decision 11: the video's wording), so not a bug. Verified: P3-04, P2-17.
  - Top bar (every shot, "..." opened the main menu): single row, cone, "...", sidebar icon, folder chip, centred title, window buttons as Player.png. Verified: P2-06, P2-20, IA-21.
  - Settings > Interface: no Skin section (Decision 63, intended difference from Figma); the rest matches (values from the test profile).
  - Settings > Subtitles: the build adds an "OpenSubtitles" section (API key, username, password) between Loading Subtitles and Appearance that Figma's page doesn't have. Logged for the web session (move it or record a Decision).
  - Sidebar Subtitles: structure matches; extra "Applies from the next file" note; lower rows cut by the 900 px window.
  - Rows verified in round 2: 5, in about 20 minutes of PC time. Totals now: verified 82, coded but not verified 199.
## Rules added 2026-10-18 (Sticky)
- Never delete anything under the Desktop (project folders included) and never create files there outside the work folders; temporary files only in the session scratchpad; no robocopy /MIR into Desktop folders.
- GitHub handle is now StickyGonzales (repo StickyGonzales/vlc-redesign-juxtopposed; noreply 103277167+StickyGonzales@users.noreply.github.com); all links updated on every branch.
- Agents: set effort to the task; UI checks need viewed screenshots.
## Branch state (Decision 55: redesign only receives verified code)
- redesign = last verified state + docs: the unverified batch was reverted (725377056e5, [skip ci]); CLAUDE.md has Decision 55 / 58 and the StickyGonzales public-name rule.
- wip/next-batch = the batch under test: waveform full/sampled rule + Ctrl+B notification + bookmark titles, library fixes (Add Folder crash, folder contents after a scan, New Playlist dialog, narrow header, grid 5/4), Customize Player + profiles (Decisions 51-53), mouse wheel fine-tuning (Decision 54) + wheel never acts over the bars (Decision 54 updated), music player view + mini player. Test build of the first part: 38829058873 (= b525e444d84, before music / wheel-bars).
- wip/fix-panels-2 = panels / Settings fixes: reviewed (2 reviewers, fixes cc9458803b0) and MERGED into wip/next-batch. Retest list in BUILD_NOTES (Output device, Use the media library dimmed, Settings search, Disabled wording, queue drop, chapters hh:mm:ss, queue header, tracks popup gap, Stereo Mode + Test button, tooltips).
- wip/cone-release (PR #7) = Cone release gaps: REVIEWED and pushed (6a328a87a72): privacy clean; Decisions 56 / 57 / 58 and StickyGonzales in the code; core changes all public-profile-only (src/win32/dirs.c settings folder, src/win32/specific.c + modules/control/win_msg.c single-instance name, modules/audio_output/mmdevice.c + winstore.c audio session GUID); portable interface settings copied into builds\current-public\portable\Cone. Not built yet (next: its own manual build after the reset). Then its own manual build; installer side-by-side test BLOCKED: Windows Sandbox is not available (Windows 10 Home): Sticky decides (VM / other PC / Windows Pro), never install on his real Windows.
- wip/ci-release (PR #8, on top of cone-release): privacy check + safe tests after the reset: two manual build-windows runs with brand public (compare build times, cache hit rate), and one release-workflow run that must refuse. Merge order: cone-release, then ci-release, each only after it passes.

## Fix list additions (Sticky, 2026-10-16)
- The resume toast text must never be cut off ("You already watched t... 00:00:14" seen on 38829058873): it fits or wraps at every window size.
- VLC's built-in dialogs in the Cone build must say "Cone" (e.g. the AVI "Broken or missing Index" question still says "VLC won't repair..."): public profile only; core-side dialog texts are core changes (Cone release branch, own build).

## Priorities until the coded-but-unverified pile is under 50 (Sticky, 2026-10-16)
1. No new features except the 12 must-haves; bug fixes from testing come first.
2. Automated verification harness in redesign/tools/verify/: launches the test build in portable mode, drives each screen and state through Windows UI Automation and keyboard shortcuts, screenshots the player window only, pixel-diffs against the matching Figma frame at the same scale; rows within a small tolerance are marked auto-passed for review, only differences and behaviour checks need a manual look. Never commit desktop screenshots; close everything after each run.
3. Every idle window goes to verification, Player area first; rows verified per window are reported below so the pile visibly shrinks.

## Build cache (2026-10-16): verified and merged
- wip/ci-release privacy clean; two manual public runs: cold 38891929733 (ccache hit rate 2.5 %, build step 18.7 min, total 25.3 min), warm 38894781882 (hit rate 99.1 %, build step 9.6 min, total 16.9 min). Before the cache: 31-37 min per build (compile ~27 min). Same 531 files; binaries differ only in build-time stamps (PE time / checksum, debug id, container id in "compiled by", the About compile time); Cone.exe from the warm run starts, plays a file and exits cleanly.
- The cache-only part (no Cone installer / release steps) is on redesign (adc810f8a82, its first redesign build fills redesign's cache), wip/next-batch (d5e8bb9b957) and wip/cone-release (d64e548960c, keeps BRAND_VERSION). The release workflow stays on wip/ci-release.
- Found: Cone release builds reject --no-qt-updates-notif (no update checker): the test helper and both launchers now pass it to vlc.exe only.
- HIGH: on build 38829058873 several quits left Cone.exe processes stuck in termination (1 thread, no window, cannot be killed); cause and fix under "Now" above.

## Row count (VIDEO_INDEX, updated after every testing window)
Raw statuses: verified 69, coded but not verified 172, todo 120 (of 361). The verified rows include earlier test rounds: 59 from the round on build 38727073546 (before this sweep) and 10 from this sweep on 38829058873.
The todo rows split into: context only (old VLC shots, jokes, sponsor, surveys, montage: nothing to build), built but never moved off todo (counted as coded here, they wait for verification), still to build: must-have (part of what she shows and planned) and optional (postponed reverse playback, montage-only seek segments, polish motion).

| Area | Verified | Coded, not verified | To build: must-have | To build: optional | Context (nothing to build) | Rows |
|---|---|---|---|---|---|---|
| Player (bars, look, other) | 2 | 65 | 0 | 1 | 41 | 109 |
| Sidebars, menus and panels | 7 | 71 | 3 | 3 | 13 | 97 |
| Library and music | 20 | 24 | 0 | 0 | 6 | 50 |
| Settings and dialogs | 25 | 9 | 0 | 0 | 2 | 36 |
| Step 2 features | 9 | 31 | 9 | 1 | 0 | 50 |
| Customize and profiles | 6 | 12 | 0 | 0 | 1 | 19 |
| **Total** | **69** | **212** | **12** | **5** | **63** | **361** |
| Cone release | tracked in redesign/CONE_RELEASE_NOTES.md (no VIDEO_INDEX rows) | | | | | |

- Fix list (found by the toast fix review): RdProfileNotice has the same 552 px cap and elide the resume toast had: make it fit or wrap the same way.

## Verification sweep (build 38829058873)
- Window 1 done (2026-10-16): Customize Player and profiles. Verified: row 308 (profiles in the main menu, submenu, switching). Bugs: MED Customize preview loses the seek bar and time labels after a drop; LOW profile switch drops one frame (23 ms); LOW footer tabs not in Figma (to decide). Details in BUILD_NOTES and PERF.
- Count (all VIDEO_INDEX rows): verified 62, coded but not verified 177, todo 122.
- Window 7 partly done (2026-10-16): Add Folder picker cancel x5 without a crash (pass); folder contents after a scan, grid, Unknown Album and pin highlight still untested: needs the Test Show folder added once through Videos > + Add (Sticky, one click) because the picker's Select Folder cannot be reached by guarded test input.
- Window 6 done (2026-10-16): presets switching between shows: rows 105-110 verified.
- Window 4 done (2026-10-16): Ctrl+B and bookmarks: row 247 verified (title names, notification, duplicate skip); LOW stock notification look.
- Window 3 done (2026-10-16): waveform: audio formats, no-audio file and the AVI pass; 249 MiB MP4 fails (HIGH, fix running); a Cone process stuck in termination after one quit (MED, investigate). No rows marked verified (the waveform rows wait for the MP4 fix).
- Window 2 done (2026-10-16): library part 1: New Playlist (P6-16, IB-30) verified, narrow header fixed; LOW Continue Watching shows the file name. Library part 2 (needs folders in the Cone library: Add Folder cancel, folder contents after a scan, grid, Unknown Album, pin highlight) still open.
- Window 3 (waveform) partly done (2026-10-16): HIGH the 250 MiB MP4 takes 13.5-14.9 s (target 2 s; cause found: MP4 seeks land on the video keyframe and the scanner decodes the audio before each stretch; fix: drop those packets undecoded); MKV 4.8 s and 4K MKV 2.6 s pass; log lines exist but the log file is buffered; AVI index dialog shows once, MED quit with that dialog open took 8.8 s. Left: AVI second ask + result, no-audio MP4, MP3 / M4A / FLAC, responsiveness. Continue Watching file names reclassified: matches Figma and the video (no change). Details in BUILD_NOTES.
- Fix branches (sub-agents, not merged yet): wip/sweep-fix-customize (pushed, NOT reviewed: d978ec93f97 with center controls the seek row takes its own full-width row above the controls, live bar and preview alike, so Save keeps it too (two 54 px rows as Figma "Player - customize-1/-6/-7"); dfa0f7a3b4f notes; leftover LOW: RdProfileNotice sits one bar height up and can cover the two-row seek row; needs review of everything sized from the bar height. Decision 62 (Customize footer tabs as RdSegmented between Cancel and Save, 103.5 per segment) NOT started, not recorded in VIDEO_INDEX yet), wip/sweep-fix-wheel NOT created: the wheel agent stopped at the limit before coding (plan: RdSliderWheel gets `armed` + live `inScrollingView` from the ancestor Flickables, no timers; wheel taken when armed or not in a scrolling view; old 0.4 s latch removed; RdSlider arms on press and draws a 1 dp track border (rdAccentDim) while held; value rows (RdParamSlider, SettingsRow via SettingsOption, Interface sensitivity, Video picture rows, Equalizer bands) arm by tap and release on hover-out; open points: horizontal wheel, Equalizer's horizontal Flickable counts as scrolling in narrow windows). Clean worktree ready for the waveform fix: .claude/worktrees/r4-sweep-waveform (work/sweep-waveform). Next: waveform fix branch (wip/sweep-fix-waveform), review both branches, merge into wip/next-batch, one manual public build, record its run here.
- Next windows: finish window 3, then Ctrl+B / bookmarks, mouse wheel, presets between shows, library part 2;
- Earlier plan: library part 2, waveform (large files, AVI without index, no-audio), Ctrl+B message and bookmark titles, mouse wheel, presets switching between shows; then the music view and panels on the next-batch build.
- Queued for the next batch after this testing window (Sticky, 2026-10-16): Decision 54 change: in any panel / sidebar / popup / Settings page that can scroll, the wheel always scrolls the panel and never changes a slider by hovering (remove the 0.4 s pause); a slider there takes the wheel only after a click on it or its value row, releases it when the pointer leaves the slider or on a click elsewhere, with a subtle focus state while it holds the wheel; in panels that cannot scroll, hovering is still enough. Update Decision 54 and INTERACTIONS.md.

## After the reset, in order
1. Verification sweep on build 38829058873 (green, downloaded to builds8829058873; it is a public / Cone build): by screen, highest risk first: Customize + profiles (profile-switch frame time), library fixes, waveform (large files, AVI without index, no-audio file), Ctrl+B message and bookmark titles, mouse wheel, presets switching between shows. Mark rows verified only after Figma + video; log failures; keep a verified / coded-unverified count here.
2. Fixes for failures on wip/next-batch (+ panels after review), manual build of wip/next-batch, retest; when it passes: revert the revert on redesign, merge wip/next-batch, tell Sticky.
3. Cone release: manual build of wip/cone-release, test the portable build; ci-release tests; merges only after they pass; close PR #7 / #8 after merging.
4. README with StickyGonzales on the next verified merge.
5. Proposed core change for Sticky's approval: aout_PrepareStereoMode drops the requested stereo mode on output restart (src/audio_output/output.c).

## Checks only Sticky can do
Night mode listening test; Cone tray icon (Windows hidden icons); installer side-by-side test (needs a VM / other PC / Windows Pro); OpenSubtitles with his API key; Rescan plugins from Program Files (admin prompt, needs the installer); display scaling 100 / 150 %; touchpad feel of the wheel; firewall prompts for new exe paths. Open questions: speaker-button wheel now sets the volume and the speed button no longer reacts to the wheel (Decision 54 follow-ups): keep or revert?

## Last 10 commits
```
86d4e4df8f redesign: tests run from one fixed folder (builds/current) so the firewall asks once
9232549dce qt: light FG/A4 #8A8A8A (Decision 44)
20a212905c redesign: log hands-on findings on the light theme build
52f968b189 qt: no dim behind any dialog (Decision 41: as in the video and Figma)
229f40238c Merge visual audit fixes: sidebar pages, row widgets, volume cone, tabs, opaque tooltips (Decisions 39, 40, 43)
04f38a96f5 Merge redesign (settings integration) into the visual audit fixes
a66c6eec71 Merge the Settings dialog category pages (W6.2) with integration and review fixes
499558cbeb redesign: log the W6.2 review fixes
3f399ca9ec qt: settings: note why Maximum volume keeps the Figma range
87dedd7731 qt: MainCtx saves the accent and fullscreen sensitivity soon after a change
```

## Builds
- Latest green: 38727073546 (everything up to the no-dim change: library, settings pages, UX pass, onboarding, Customize Player, stall fixes, control bar, light theme, DM Mono). Hands-on tested 2026-10-15 (see BUILD_NOTES).
- Local and pushed after it: Decision 44 (light FG/A4 #8A8A8A), fixed test folder (launcher), docs. Pushing redesign starts the next build.
- Tests run from <TEST_MEDIA_DIR>/builds/current (firewall allowed once). Session helper vlctest.ps1 in the scratchpad has deploy / start current / dblclick / wheel / drag / graceful stop.

## Hands-on results of 38727073546
- Works: bars and 3 s fade, click outside closes panels (video keeps playing), Escape order, opaque tracks popup header and bar, right-click menu on the video, double-click fullscreen both ways, wheel volume, small window (no overlap), library compact, settings dialog pages, no dim behind dialogs, Customize Player overlay, Keyboard Shortcuts, onboarding (with --qt-privacy-ask), subtitle delay/speed drags do not freeze the video (frame difference measured on <TEST_MOVIE> and the test video), settings sidebar tabs match Figma closely (Q1 no footer on Playback).
- Bugs (sent to the UX agent, partly fixed on wip/a84f3cfa07ac47ba6): None + Track both checked in the subtitle list; tracks popup with 16 tracks grows past the window and clips its footer; "Disable" / "Best available" wording; right-click on the seek bar opens nothing; Ctrl+P with the main menu open leaves the menu open.
- Not bugs: --start-time ignored (stock VLC 4 does the same); the "closed abruptly" prompt after forced closes.

## Performance round 3 (perfruns/r3, back to back)
- Startup stock 927/1062/1112 ms vs redesign 1031/981/921: equal. Open file stock 1256/1130/1339 vs redesign 1671/1258/1230: equal except one slow first open. Playing CPU 0.1 % / RAM 310 vs 309 MB: equal. 4K fullscreen lost frames 23 vs 23: equal. Queue scroll p95 24 vs 20 ms.
- Redesign motion scenarios skipped (VLC lost the foreground); rerun when Sticky is away. Write into PERF.md.

## Open branches (all backed up on origin as wip/<id>, none merged)
1. wip/a84f3cfa07ac47ba6 UX leftovers: done except bug 4 (right-click on the seek bar: SliderBar.qml tap/drag handlers block the bar's right-click handler, Player.qml ~2042). Includes a C++ change (DialogsProvider dialogOpening signal, never compiled). Needs an independent review, then merge.
2. wip/a1e06ae1c89fa4775 W3.3b seek preview thumbnails: done, reviewed. Fix before merging: M1 (cancelled request clears the wanted bucket, rd_seek_thumbnailer.cpp:492-498: clear m_wanted only for non-cancelled results), M2 (length change resets cache and stops preview, :238 and :288-295: keep item/cache on same URI), LOWs L1-L9 in the review (stale threshold 600-1000 ms, re-check on throttle tick, timeouts count double, one image_handler per thread, setSupported(false) when the preparser fails, stop on SliderBar destruction, notes wording).
3. wip/a9364ffaea8630df4 Step 2 Settings rows S2-02..S2-10 and S2-03 (own tray popup): done, NOT reviewed. Needs an independent review (C++ never compiled), then merge and build. Night mode is ready for Sticky's listening test once built (Decision 38).

## Next, in order
1. Finish and merge the UX leftovers branch; fix M1/M2 (+ LOWs) on the seek thumbnail branch and merge; review and merge the Settings rows branch; one build; hands-on test with real screenshots vs Figma; perf motion rerun; PERF.md round 3.
2. Core build (Decision 27): 3553e146bc (subtitle rate change flushes only the subtitle slave) and later S2-01 / S2-11.
3. Remaining Step 2 items (BUILD_PLAN section 0).

## Rules added this session (see CLAUDE.md)
Max 4 agents in total, no sub-agents; UX pass on every package; identical to Figma, verified only by real-build screenshots; decision questions with side-by-side images in <TEST_MEDIA_DIR>/decisions; component motion from Figma/video; build list checker before pushes; fixed test folder; test media rules; never delete outside project paths.
