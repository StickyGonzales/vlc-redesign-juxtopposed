# VLC Redesign Fork

## Project context
- Goal: a downloadable Windows app that is VLC media player with EVERYTHING the designer Juxtopposed shows in her "VLC Redesign" video implemented for real (Figma community file, CC BY 4.0). Same playback engine as VLC, her full redesign on top.
- Scope: match the video. Every screen, control, menu, behavior and feature she shows should exist in the real app and work the way she shows it. Nothing she shows is skipped or simplified without Sticky's approval.
- The design is a mockup only. No code for it exists. Everything gets built by us on top of upstream VLC.
- The playback engine, codecs and core stay as they are wherever possible. Most of her ideas are UI work on top of features VLC already has. Where a feature truly needs core changes, explain why and get Sticky's approval first.
- Base: VLC master (VLC 4 development branch), which has the QML interface in `modules/gui/qt`. Do NOT use the 3.0.x branch, its UI is QtWidgets and cannot be restyled the same way.
- This repo: Sticky's GitHub fork https://github.com/StickyGonzales/vlc-redesign-juxtopposed of the official mirror https://github.com/videolan/vlc (official upstream: https://code.videolan.org/videolan/vlc).
- Owner: Sticky (GitHub: StickyGonzales; the account was called Pyr0zen until 2026-10-18, so older commits carry that name). Windows 10 PC, PowerShell, a local Windows user.

## How we work
- **Division of work (Decision 64, Sticky, 2026-10-19):** the web session codes, fixes, reviews and writes docs; this PC session only checks against the video and transcript, builds and tests Cone on Windows, answers the web session's video questions and does the final merge into `redesign` after a passing test. No features or fixes from the PC session except one-line fixes found during a test. On-PC tests run once each when needed: no rapid open-close loops of test players on Sticky's screen.
- You run on Sticky's PC (native Windows Claude Code) inside this local clone, so you have the designer's full video locally.
- You write the code here, commit, and push to the `redesign` branch on GitHub.
- GitHub Actions compiles the Windows build. Sticky has NO local build environment, never try to compile VLC on this PC.
- Use the GitHub CLI (`gh`, already logged in) to watch runs and read failed logs: `gh run watch`, `gh run view --log-failed`.
- Sticky downloads the build artifact from the Actions tab and tests it on Windows.

## Design reference (in `redesign/reference/`)
- The designer's video (https://youtu.be/ERFeOgqk324), its transcript and every frame extracted from it are LOCAL ONLY (gitignored, never committed: her copyrighted content). Their file names are in CLAUDE.local.md: `vlc_redesign.mp4`, `vlc_redesign.en.srt` (her reasoning for every change), `frames/` (scene-change frames), `frames_library/`, `frames_settings/`, `frames_work/`.
- `figma/figma_file.json` full Figma file from the API (committed 2026-10-13 at Sticky's request so other sessions have the exact specs; the Figma file is a public Community file); `redesign/FIGMA_FLOWS.md` summarizes its prototype interactions and exact specs.
- `redesign/BUILD_PLAN.md` architecture map, work packages (Step 1 UI only, then Step 2 new features), Phase 1 workflow, test loop, risks.
- `redesign/RESIDUAL_AUDIT.md` every element of VLC's current interface marked KEEP / MOVE / NOT IN VIDEO. Remove nothing until Sticky decides.
- `redesign/STATUS.md` latest status (see Status file rule).
- `figma/` 105 PNG exports from her Figma file (68 screen frames, 35 component sets, 2 labels). Source of truth for how things LOOK (the final UIs).
- `figma/styles.txt` exact color and effect values. Always use these, never sample colors from PNGs.

The video is the primary source for what to build and how it works. Sticky wants the real app to look and work exactly like what she shows. Watch it carefully, not loosely.

Figma holds every FINAL UI (Sticky, 2026-10-13): the final look of every screen, component and state is in the Figma file; the video shows iterations on the way there (old VLC, rejected ideas, intermediate versions), so never copy a look from a video frame when Figma has it. The video plus its transcript is the key to understanding functionality, behavior and how features relate to each other: she explains all of it there. Sticky's numbered decisions below still win over both (e.g. Decision 11: the video's wording).

First task in this project, before Phase 1 code: a full careful watch-through.
- Extract frames from the WHOLE video at 1 frame per second into `redesign/reference/frames_work/full/` and go through all of them alongside the full transcript, start to finish.
- Write `redesign/VIDEO_INDEX.md`: every single change, screen, control, menu, behavior and feature she shows or mentions, in video order, each with its timestamp range, the matching figma/ PNG filenames, and a status column (todo / in progress / done / blocked). This is an index for not missing anything, NOT a replacement for the video: whenever you build an item, go back to its timestamps in the video.
- Include small details too: icon styles, hover behavior, what hides when, wording of labels, order of menu items, sidebar tabs and their contents, settings categories, dialogs.

For every element, every time:
1. Before building or changing any element, find every part of the transcript that covers it.
2. Extract frames at those timestamps with ffmpeg (on PATH), as dense as needed to see hovers, menus opening, sidebars sliding and transitions. Save them in `redesign/reference/frames_work/` (also local only, do not commit).
3. Look at those frames AND the matching figma/ PNGs, then build.
4. After building, compare the result against the same frames and PNGs and list any differences for Sticky.

## Branches and git
- Work only on the branch `redesign`. Never push to `master`. Never open pull requests to upstream videolan repos.
- Never commit build outputs, the mp4, or frames_work/.
- figma/ and styles.txt may be committed (her Figma file is CC BY 4.0, credited in CREDITS.md). Never commit the video, the transcript, video frames or quotes from her narration.

## Parallel work (Sticky, 2026-10-13)
- Agent pacing (Sticky, 2026-10-16, current): up to 5 top-level agents alive at once; each may start up to 2 sub-agents of its own (Opus), and sub-agents may not start further agents (best use: the independent review of the agent's own diff). Sticky raises or lowers this with the credit level: when he reports low credits, start nothing new. Every agent prompt states its sub-agent allowance. Earlier history: 10 parallel agents and nested sub-agents (19 tasks) once burned the 5-hour limit in minutes, which pauses everything for hours; so queue the rest by priority in redesign/STATUS.md (library and settings integrations, then UX and playback-stall fixes, then the rest), Opus for all agents, tight prompts with the exact files and VIDEO_INDEX rows, and running agents finish their current step.
- **Phase 5 belongs to the web session:** a second Claude Code session on the web builds Phase 5 (library shell, music, playlists, network streams, home, recent, pins, mini player, drag to queue: W5.1-W5.9, Step 1 and Step 2 parts), fully wired to VLC's real data, on branch `redesign-library`. The local session does not touch Phase 5 files (modules/gui/qt/medialibrary/qml, network/qml, maininterface/qml/MainDisplay.qml, LocalTopbar.qml, MainViewLoader.qml, NoMedialibHome.qml, playlist/qml/PlaylistDetachedWindow.qml, player/qml/MiniPlayer.qml / PIPPlayer.qml). Shared files (Player.qml, palette, MainCtx, meson.build, Makefile.am, widgets) are edited by both only where needed and merged carefully.
- **Settings pages belong to a web session too (Sticky, 2026-10-14):** the web session builds the Settings dialog category pages (W6.2 and the related rows, everything except the Add Subtitles dialog W6.5) on branch `redesign-settings`, branched from `redesign`, using `reference/frames_settings/` (506 frames at 2 fps, see its README). The local session does not touch `modules/gui/qt/dialogs/redesign/settings/pages/*`. When Sticky says it pushed: review, merge, build and test it like the library.
- **Merging redesign-library:** when Sticky says it pushed: independent review of the whole branch diff, `redesign/tools/qmlcheck.py`, merge into `redesign`, one build, full test round on this PC against the video like everything else.
- **Web session notes:** web sessions only have the committed material (the Figma PNGs and `figma/figma_file.json`, VIDEO_INDEX.md and FIGMA_FLOWS.md); the video, transcript and frames are local to the PC session only. CI builds only `redesign`, so it verifies with qmlcheck; the on-PC test happens after the merge.
- **Local session:** while a build is tested, subagents code the next independent work packages in separate git worktrees (one package or tightly coupled pair per agent, never two agents on the same files), each following every rule in this file; then independent review, qmlcheck, merge into `redesign` as the next batch. The 5-packages-per-build rule and the full test loop stay.

## Current phase
- 2026-10-15 night: merged batch pushed to redesign (seek thumbnails, Settings rows, UX leftovers, W5.2 folders, W4.3b / W4.8b Playback extras and Ctrl+B, W6.5 Add Subtitles, landing page); one build running. Next: test it on the PC, then endless sliders (wip/endless-sliders), then the verification round bug fixes. Details and order in redesign/STATUS.md.
READY TO BUILD. Next session: read CLAUDE.md, VIDEO_INDEX.md, FIGMA_FLOWS.md and BUILD_PLAN.md, then run the build from Phase 1 through all phases continuously, following the test loop, without stopping unless truly blocked.

- Sunday plan (2026-10-14), done so far: (1) no open bug issues; (2) build 38441433330 tested, Figma side-by-sides match for menu, Settings, Keyboard Shortcuts, Open Network Stream; fixes a2d7d5ef7c (opaque popups, Controls imports, Customize Player loads again: verified on build 38595146574); (3) performance round 1 in redesign/PERF.md: open file ~+300 ms vs stock (stop-everything, expected fix: lazy panels), 4K fullscreen and the motion method need a clean re-run (harness fix by an agent, offline).
- Figma detail fixes: control bar gaps/time labels e0cc6dd1f3, top bar spacing d8c80e720f, no control bar top line 2593350797.
- Merged (step 5): event-driven cursor branch cbb2f4c2f5 (no 100 ms poll; video frame as two fixed halves; no hidden top bar acrylic) and lazy panels + RdListView queue/chapters/bookmarks 94a35ce7b0 (with review fixes: RdSidePanelPage.active, settings pages refresh on creation, Enter acts on the Tab-focused row). Review leftovers, LOW: queue drag image and empty-queue drop indicator are stock-styled: restyle per IB-15 (ghost = row content only, semi-transparent, no card background or shadow) after the library merge (it touches QueueSidebar). Equalizer preset cache item fixed in 2a6d81b939 (local). RdExpander now takes a single content child. Low item: update the equalizer preset cache immediately in setAudioFilterEnabled("equalizer").
- Build 38600975461 (94a35ce7b0) running: test on the PC: bars over the video (windowed with another app active, fullscreen edge zones, leaving the window from the video, F keeps both bars), right-click menu at the cursor, video frame look and fade and minimal window, panels and tabs open instantly, queue/chapters/bookmarks lists, Settings pages refresh, control/top bar vs Figma; then perf round 2 (open file, startup, 4K fullscreen, queue RAM, motion).
- Step 4 running in agents: redesign-library review + integration (merge + LIBRARY_NOTES.md section 5 hookups); then merge, qmlcheck, build, test the library vs video and Figma.
- Step 6 running in agents (worktrees): W8.1a Customize Player restyle, W8.3 onboarding. W8.4 light theme (Decision 33: FG/1 #111111, FG/2 #222222). W6.2 belongs to the redesign-settings web session (review, merge, build, test when Sticky says it pushed).
- Settings branch (Sticky, 2026-10-14): when the web session's final commit on redesign-settings lands and redesign/SETTINGS_NOTES.md says it is done (all 13 pages), read the notes, then review, merge, build and test it like the library, with the full test loop and the performance rule.
  - Settings branch status: finished (web session stopped, PR #2 ready); independent review running. Merge right after the library. Known from the rows research: its "Fullscreen controls sensitivity" row writes qt-fs-sensitivity which nothing reads (wire it to Player.qml _barHoverZone, row 361), and "Give VLC high priority" does nothing when saved (high-priority is read before vlcrc loads; row 356 can apply it at startup).
- Decisions waiting for Sticky: pixel subtitle size / live style (core); DM Mono font.
- After verification: rest of Step 1 (BUILD_PLAN.md section 0) in build rounds of 5 work packages, then Step 2.
- Test media: <TEST_MEDIA_DIR>\<TEST_VIDEO> (landscape) and <TEST_VIDEO_PORTRAIT> (portrait). Never test with the designer's video. Screenshots of them stay local (they show Sticky's screen).
- Update this section after every item: last completed row/WP with commit hash, next WP, latest green run.

## Working rules for the build
- **Plan:** `redesign/BUILD_PLAN.md` holds the architecture map, the work packages (W1.1 to W9.1) in dependency order with parallel lanes, the Phase 1 workflow, the test loop and the risks. Follow it; record deviations under "Decisions (Claude)" in VIDEO_INDEX.md.
- **Continuity rule:** keep VIDEO_INDEX.md Status (`todo` / `in progress` / `done (<commit>)` / `blocked (<reason>)`) and the "Current phase" section above updated after every item, so any new session can resume from the files alone.
- **Stop rule:** only stop if truly blocked or something only Sticky can do is needed (login, payment, an API key like OpenSubtitles). Otherwise keep going to the next work package. Publishing a public GitHub Release (W9.1) needs Sticky's go first.
- **Decisions:** Sticky's decisions below are final. Anything not covered: the look comes from the final UIs in the Figma file, the functionality and relations from the video and its transcript; where the video shows something Figma does not have, build it from the video in the Figma style (Decision 21). Every extra decision goes under "Decisions (Claude)" in VIDEO_INDEX.md, one line each.
- **Verification:** screenshot every state of every built element and compare with the video frames at the matching timestamps and the Figma PNGs before marking it done (BUILD_PLAN.md section 5). The video is the main guide: look at its frames BEFORE building each element, and always crop and zoom into the detail (icons, edges, spacing, text) instead of judging full frames. Always read the transcript lines at the same timestamps with the frames: many frames show how something USED to look (old VLC, rejected options, intermediate states) before she redesigns it later; only her final version is built. For every element, after each build, take screenshots of our build and make side-by-side images of our crop next to BOTH the matching Figma frame (figma/ PNGs or a crop of the component in Controls.png) and the matching video frame (her final version), same scale, zoomed in; only mark it done when they match; list remaining differences (for the look, the Figma final UI wins over a video frame, which may be an iteration; for behavior, the video and transcript).
- **Verified-only redesign (Sticky, 2026-10-16, Decision 55, permanent):** `redesign` only receives verified code. Every batch lives on its own branch (e.g. wip/next-batch) and is built from that branch with a manual workflow run (`gh workflow run build-windows.yml --ref <branch>`, like the brand-layer builds), tested on Sticky's PC, and merged into `redesign` only after it passes. Failures are fixed on the branch and rebuilt before merging. Core changes (anything outside modules/gui/qt) are built and tested on their own branch the same way. Never push unverified code to `redesign`; doc-only commits to redesign carry [skip ci].
- **Build rounds (Sticky, 2026-10-13):** bundle 5 work packages per build: code them, run the independent review on all of them, then push once and do one full test round covering all of them. Do not push after every small fix. Only exception: any change to VLC's core (anything outside modules/gui/qt) goes in its own build, never mixed with other changes. If a build breaks at runtime, look for the cause in the riskiest change of the batch first (shared files such as Player.qml, the palette, MainCtx). Doc-only pushes stay as they are (they do not trigger a build).
- **Clean stop:** when Sticky writes "stopping for today": finish the edit in progress, commit everything, push so a build runs while he is away, update and push STATUS.md with exactly where you are and what is next, then stop. When he writes "Read CLAUDE.md and continue": first test the build that ran while he was away, then continue.
- **Status file (permanent):** keep `redesign/STATUS.md` updated and push it after every finished work package, every phase, and whenever you stop or get blocked. It holds, at the top, the date and time, the current work package and the last 10 commits (hash + message), then the latest PROGRESS REPORT. Overwrite it each time.

## Privacy and copyright (Sticky, 2026-10-15, permanent)
- The repo is public. Never commit anything personal or from Sticky's PC: no real names, Windows user name, PC paths, e-mail addresses (commits use the noreply identity), personal files or their names, his music, his test videos or screenshots of his screen. Committed files use neutral placeholders (<TEST_MEDIA_DIR>, <WORK_DIR>, <TEST_VIDEO>, ...); the real values live only in the gitignored CLAUDE.local.md and *.local.* settings files.
- Never commit the designer's video content (frames, transcript, the video, quotes from it); her Figma file (CC BY 4.0) may be committed, with credit (CREDITS.md).
- The owner's public name is **StickyGonzales** (Sticky, 2026-10-16): every place people see his name uses it (About "Built by StickyGonzales", installer publisher, exe company / publisher info, CREDITS.md, README, release notes, the Windows Apps list), and committed files name the owner StickyGonzales from now on (older notes may still say Sticky; GitHub handle StickyGonzales). His real name never appears anywhere; the private word list catches it.
- Before every commit and push run `python redesign/tools/privacycheck.py` (generic checks plus the private word list in the gitignored redesign/tools/privacy.local.txt); it must print `privacycheck: 0 problem(s)`. Public screenshots show only the VLC window with generated or public test media.

## Decision questions to Sticky (Sticky, 2026-10-15, permanent)
- Every question about how something looks or behaves comes with a side-by-side image, so Sticky decides by looking, not by reading. One image per question: "Now" = a real screenshot of our build (test VLC), "Figma" = the Figma frame cropped to the same element at the same scale, and "Video mm:ss" = the matching video frame when the video shows it; when there are several options (e.g. two colors), each option is its own labelled panel. Put the question number and short title on the image. Save as `<TEST_MEDIA_DIR>/decisions/Q<n>-<short-name>.png` (the only folder written inside Sticky's folder) and open them or list the paths in the message. Applies to every open visual question, including ones still waiting.

## Using Sticky's PC (Sticky, 2026-10-14)
- On-PC tests (Sticky, 2026-10-14): mouse, keyboard and windows may be used anytime, no need to wait. Requirement: when a test is done, close every window and process it opened (test VLC, scripts, captures, command windows) so nothing is left running or open. Keep the safety guard: input only goes to VLC while it is the window in front (vlcperf.ps1 Guard, vlctest.ps1 Require-Focus).
- Fixed test folder (Sticky, 2026-10-15): every build under test is copied into `<TEST_MEDIA_DIR>/builds/current/` (robocopy /MIR keeping its `portable` folder) and run from there, so Windows Firewall asks only once and the portable settings stay in one place; the session test helper (`vlctest.ps1 deploy <build dir>`, then `start current`) and redesign/tools/test-latest.bat (and its Desktop copy) do this. For a first-run test (onboarding) use `--qt-privacy-ask`, not a new folder.
- Never delete or overwrite anything of Sticky's (Sticky, 2026-10-14). Deleting is allowed only inside paths this project created: the session scratchpad, `<WORK_DIR>\builds\<run>`, perfruns, perfmedia, agentwork, qttools, the agent worktrees under `vlc\.claude\worktrees`, and files the repo itself generates. No recursive deletes or wildcards outside those paths; never touch his Desktop items, Downloads, documents, other projects or the installed VLC. Check the exact target path before any delete.
- Hands-on tests (Sticky, 2026-10-14): VLC cannot take the front window while Sticky is active, so batch every test that needs input; when he writes "I'm away", run all waiting tests and the performance baseline, then close everything.
- Test media (Sticky, 2026-10-14): "<TEST_MEDIA_DIR>/<TEST_MUSIC_DIR>" holds his real music: read-only. Never edit, rename, move, retag or delete anything in it; only add it to the test VLC's library in portable mode. Generated performance media lives in "<TEST_MEDIA_DIR>/builds/test-media" (made by a script: "Many Folders" 520 subfolders x 2 files, "Many Files" 3000 short mp3, "Test Show" Season 1-2 x 6 short episodes). Only that test-media folder may be deleted if it needs cleaning.

## Quality rules (mandatory for every work package; a package is NOT done until all pass)
- **Performance first (Sticky, 2026-10-13, top priority):** the redesign must feel at least as snappy as stock VLC. If it feels sluggish it has failed, no matter how close it looks to the video. Responsiveness wins over visual effects every time. Hard targets, measured on this PC every build round against stock VLC 4 (the green stock build from Phase 1, run 38315049322, in builds\38315049322), both in portable mode, same test videos:
  - The UI never drops below 60 fps during any interaction: hovering, opening and closing panels and popups, dragging the seek bar or volume, scrolling lists. Measured with Qt's render timing (QSG_RENDER_TIMING=1) or the QML profiler; log the worst frame times.
  - Clicks and key presses react instantly: panels and popups start opening within one frame, no visible delay.
  - Animations stay short: the Figma durations where they exist, otherwise 150 to 200 ms maximum. Nothing animates in a way that makes the user wait.
  - Startup time and time to open a file: no worse than stock VLC.
  - CPU, GPU and RAM while playing, idle on the player, with panels open and while seeking: close to stock VLC. Any big gap is a bug.
  - A 4K or high-bitrate file, windowed and fullscreen: zero extra dropped frames versus stock VLC (VLC's statistics).
  - A queue of 500+ items opens and scrolls smoothly.
  - Every round's numbers go into `redesign/PERF.md` next to the stock VLC numbers. A regression on any target is a stop-everything bug, same as a crash.
  - Heavy-feature design rules are in `redesign/INTERACTIONS.md` (Performance rules): blur only if it holds 60 fps, background low-priority scanning, lazy lists, no idle timers.
- **Component motion (Sticky, 2026-10-15):** for every control (buttons, tabs, toggles, dropdowns, rows), look at the Figma prototype and the video frames to see how it moves and changes between states (hover, press, selection, tab switch, open/close) and replicate it; a static match is not enough.
- **Motion check (Sticky, 2026-10-13):** every animation must feel smooth, modern and polished, as in the video. Frames alone do not show motion, so for every animated element: extract the video at its full 60 fps around the transition, track the element (position, size or opacity) frame by frame and derive the real duration and easing curve; use the Figma prototype duration/easing where it exists, otherwise the measured one, capped by the performance rule (150 to 200 ms unless Sticky agrees otherwise). After the build, record our window at 60 fps (ffmpeg gdigrab, region of the VLC window only, recordings stay local), track the same element, and compare: same curve shape, no stalls, no uneven frame steps, no jump at the start or end. Plot both curves side by side in the verification images and log the numbers in PERF.md. Careful: the video is edited, and many of its moves are editing (cross-dissolves between the old and new UI, camera zooms and pans, the cursor sticker), not UI motion (example: 7:10-7:13 dissolves the old Effects window into the sidebar, then zooms the camera). Only motion inside an unedited stretch of her prototype demo counts (check with the transcript and a contact sheet of the frames: if the whole frame scales or every pixel changes, it is the camera). The Figma prototype transitions in FIGMA_FLOWS.md are the primary source: smart animate "slow" 208 ms (library open), 300 ms ease-in-out (Hide UI, volume), 300 ms ease-out (mini player), 50 ms (Customize drags).
- **Identical to Figma (Sticky, 2026-10-14):** every UI feature must be IDENTICAL to the Figma file, not similar: every size, gap, padding, radius, stroke, font size/weight, color/opacity and icon taken from the node values in figma_file.json and checked in side-by-side crops at the same scale against the Figma PNG. Any remaining difference is a bug unless a Decision covers it. Measuring numbers or rendering offline is NOT verification (Sticky, 2026-10-15, repeated): every UI change is verified with real screenshots of the built VLC on the PC, cropped side by side with the Figma PNG crop of the same element at the same scale (and the video frame where it shows it), viewed and compared before the change is marked done; agents' offline renders only help while coding.
- **UX pass on every package (Sticky, 2026-10-14, permanent):** every package gets a UX pass, not just a visual check. Think like a demanding user and hunt for quality-of-life bugs yourself; Sticky should never have to find them. At minimum check: clicking outside any popup, menu or panel closes it; Escape closes it; focus returns where it was; nothing freezes or desyncs (video and audio stay in sync during every setting change, also while dragging); every popup and panel is opaque; proportions, spacing and sizes match Figma exactly (measured from figma_file.json) at every window size; every mouse action and hotkey she shows or VLC users expect works (double click, right-click menu, scroll wheel on volume and seek, middle click, drag and drop) in windowed and fullscreen and with panels open; hover, pressed and disabled states exist everywhere; no layout jumps or flicker. Log every UX bug in redesign/BUILD_NOTES.md like any other bug. Walk this list on the real build before marking a package done.
- **Big picture first:** before starting a work package, read `redesign/INTERACTIONS.md` and plan the package against every feature it will interact with later (live theme and accent, panels and bar locks, Customize Player, presets and profiles, seek bar modes, keyboard, scaling), as the video shows them by its end. Check the package against it again before marking it done; add new interactions to that file when found.
- **Code quality:** follow VLC's existing code style and patterns in `modules/gui/qt`. Reuse existing VLC components and APIs. No hacks, no hardcoded values that belong in the theme (use `palette.rd*` / `VLCStyle.rd_*`), no commented-out code, no TODOs left behind. New code in new files where possible.
- **Zero new warnings:** no new compiler warnings and no new QML warnings (qmllint where available, plus the runtime console output). Fix, never suppress.
- **QML compile check before every push (2026-10-13):** run `redesign/tools/qmlcheck.py` (setup and expected output in its header) on the whole tree before pushing any QML change. It compiles every QML file with Qt 6.8.3, the version VLC bundles, against stubs of VLC's C++ types, and flags Qt features VLC's Qt lacks (Canvas, Shapes, ...). One bad file makes VLC refuse the whole player page (build 38390848560: a read-only `implicitHeight` on a Text root). Only push when it reports `errors: 1` (the known HighResolutionTimeWidget stub limit) and `crashed: 0`. Every new or changed shader (`modules/gui/qt/shaders/*.frag`/`.vert`) is compiled first with Qt 6.8.3's qsb, installed outside the repo in `<WORK_DIR>\qttools\6.8.3\msvc2022_64\bin\qsb.exe` (aqtinstall: qtbase + qtshadertools): `qsb --glsl "300 es,130,150" --hlsl 50 --msl 12 --batchable -o <out>.qsb <shader>` must exit 0 (the optimizer spirv-opt and fxc are not installed locally; their absence only prints warnings).
- **Build list check before every push (2026-10-14):** `python redesign/tools/buildlists.py` from the repo root must print `buildlists: 0 problem(s)`: every continued list line in modules/gui/qt/Makefile.am ends with a backslash, and Makefile.am and meson.build list the same QML/JS files (a lost backslash in a merge would break the autotools build CI uses).
- **Independent review:** after each package, a fresh subagent that did not write the code reviews the full diff, hunting for bugs: null/undefined access, missing bindings, broken signal connections, leaks, race conditions, wrong state after open/close cycles, missing qtr/qsTr translations, keyboard focus and tab order. Fix, review again until clean.
- **Behavior tests on the real build:** every state of the package's features plus edge cases: window very small to maximized, fullscreen, Windows scaling 100/125/150 percent, no media, no subtitles, several audio and subtitle tracks, very long file names, audio-only files, keyboard-only use, rapid repeated clicking, opening and closing panels many times.
- **Regression checklist after every package:** open file, play, pause, seek, volume, mute, next/previous, fullscreen in and out, subtitle on/off and track switching, audio track switching, queue add/remove, drag and drop a file, keyboard shortcuts, settings survive a restart, app closes cleanly.
- **Visual check:** crop and zoom against the video frames and the Figma PNGs.
- **Crashes:** any crash or freeze stops everything until fixed.
- **Small commits:** one logical change each. Never more than one build round (see Build rounds) unverified at a time.
- **Bug log:** log every bug found and fixed in `redesign/BUILD_NOTES.md`.

## Decisions (Sticky, 2026-10-12)
General rule for anything not listed (updated by Sticky 2026-10-13): the final UIs are in the Figma file; the video and transcript explain functionality and relations; the video's iterations are not the final look.
1. Fullscreen button in the top bar. Picture-in-Picture skipped for now.
2. Main "..." menu: her last version, matching Figma menu.png.
3. Queue: tabbed sidebar with Queue / Bookmarks / Chapters, everywhere.
4. Bars show on hover near them and hide instantly when the mouse moves away.
5. Gear opens the settings sidebar on the Playback tab. Subtitle and audio buttons open the tracks popup on their tab.
6. Seek thumbnail shows anywhere along the seek bar while hovering.
7. Volume range 0 to 200%.
8. Home page includes "Latest Streams".
9. Onboarding: picking a theme or accent color recolors the app live.
10. Mini player queue header: the video's 5 icons.
11. Wording: the video's wording where it differs from Figma.
12. External Tracks "+": Figma's "To This File / From Computer" flow with the language list.
13. Playback tab: the video's items (including Show Waveform on Seekbar and Show Metadata) plus Figma's Show Statistics.
14. Prototype placeholder links (About VLC, Quit VLC, More Settings, Open Media, right-click Playlist): wire each to its real action.
15. Accent color options: #D37918, #E15032, #C49E23, #19A234, #18AAD3, #185DD3, #8E42FF, #F052B3, #AFAFAF (in figma/styles.txt).
16. Menu icons use Accent/DIm #AB6314.
17. Fix the design typos.
18. Presets: one preset per show covering all tabs (subtitles, audio, video, playback).
19. Gear icon: the Figma version.
20. Dark theme first. Light theme last: propose corrected Light/FG/1 and FG/2 values (settled by Decision 33 in VIDEO_INDEX.md: #111111 and #222222).
21. Features with no Figma frame: build from the video, styled to match the Figma components.
22. Keep all VLC default shortcuts. F = fullscreen, V = cycle subtitle track. Hide UI = Ctrl+\. Add Ctrl+B = create bookmark. Ignore the prototype's F and V bindings.
23. Sleep Timer: Off / 15 / 30 / 45 / 60 min / End of current file.
24. Show Metadata opens a file info panel. "Render: Local" is VLC's existing renderer/cast picker.
25. Per-preset "..." menu: Rename, Duplicate, Delete. Profile "+ New": enter a name, copy current settings.
26. Info icon: click shows the setting's description in a popover.
27. Core changes approved wherever a feature truly needs them, minimal and isolated. Examples: OSD showing the pressed shortcut, subtitle timeline (external files first, embedded later if feasible).
28. Accepted limit: subtitle outline uses VLC's existing outline sizes.
29. Postponed: reverse playback. Profiles may need a restart for some settings; show a notice when that happens.
30. (2026-10-13, updated) Windowed: both bars float over the video, appear whenever the mouse moves over the window and fade out about 3 s after it stops (with the cursor), like modern players. Fullscreen: each bar appears when the mouse is near its edge and fades out smoothly when it leaves. VLC's own "pin video controls" option still pins both bars in a window.
31. (2026-10-13) The final UIs are in the Figma file; the video shows iterations on the way. Look: Figma. Functionality and relations: the video and its transcript.
32. (2026-10-13) Dialogs open and close instantly, like the Figma prototype and the Settings dialog, so all dialogs behave the same (Open Network Stream, Settings, Keyboard Shortcuts and later ones); the video's dialog fades are editing dissolves. Menus keep the 120 ms fade in measured from her unedited demo (5:08).
55. (2026-10-16) `redesign` only receives verified code: every batch is built from its own branch with a manual workflow run (`gh workflow run build-windows.yml --ref <branch>`), tested on Sticky's PC and merged into `redesign` only after it passes; failures are fixed on the branch and rebuilt before merging (details: Working rules, "Verified-only redesign"). Decisions 33-54 and 56+ are in redesign/VIDEO_INDEX.md "Decisions (Sticky)".
58. (2026-10-16) Cone has its own version number: About and the installer show "Cone 0.1.0" with "based on VLC 4.0.0-dev" underneath, the Windows Apps list shows Cone 0.1.0, and the release workflow's version tag sets it.
64. (2026-10-19) Division of work: the web session does all coding, fixes, code reviews and docs. The PC session only does what needs this PC: checking against her video and transcript, building and testing Cone on Windows, answering the video questions the web session leaves in its notes, and the final merge into `redesign` after a passing test. The PC session writes no features or fixes itself, except a one-line fix found during a test; failures go into STATUS.md as bugs for the web session. wip/linux-build belongs to the web session.

## Report format (use for every progress report to Sticky; plain text, no em dashes)
PROGRESS REPORT
- Phase and status
- What was built since the last report
- Latest green build: run number, artifact name, exact click path to download it
- VIDEO_INDEX.md: items done / total, by area
- Decisions (Claude) added since the last report
- Remaining differences from the video, with timestamps
- Core changes made so far and which files they touch
- Warnings: new compiler / QML warnings count (must be 0)
- Review findings fixed (independent subagent review)
- Edge cases tested
- Regression checklist result
- Known bugs remaining
- Blocked on: what exactly, or "nothing"

## Public release rules (apply from day one)
- GPL: VLC is GPLv2 or later. Keep `COPYING` and all copyright notices untouched. All our changes stay public under the same license.
- Trademarks: "VideoLAN", "VLC" and "VLC media player" are registered trademarks of the VideoLAN non-profit, and the cone is VLC's official icon. Public builds ship under Sticky's own project name and icon, described only as "based on VLC media player". Never imply it is an official VideoLAN product.
- The design is CC BY 4.0: the README must credit Juxtopposed and link the Figma file (https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and her video (https://youtu.be/ERFeOgqk324).
- Where the design shows the VLC cone or the name "VLC", public builds use Sticky's name and icon instead. Colors, layout and controls are fine to use.

## Rules
- Core (`src/`, `include/`, non-GUI modules): only where a feature truly needs it, minimal and isolated (approved by Decision 27). List every core change in VIDEO_INDEX.md "Core changes (status)".
- Commands Sticky runs himself: PowerShell, ONE copy-paste block chained with `;`, real paths filled in (`$env:USERPROFILE`). Explanation above the block, never after.
- Communication: direct and short, bold step headers, no walls of text, no em dashes. For GitHub web steps give exact click paths.

## Roadmap (high level; the detailed order is BUILD_PLAN.md, run continuously)
- Phase 2, colors: apply the palette via `modules/gui/qt/style` using `figma/styles.txt`. Dark theme is primary. Light theme second (its FG/1 and FG/2 equal the Dark values in Figma; Sticky set them to #111111 and #222222, Decision 33).
- Phase 3, control bar: everything she shows for it (thin bottom bar, thick seek bar, play button with prev/next around it, cone-shaped volume slider, fullscreen and settings on the right, queue button, subtitle and audio track buttons on the bottom right, hover show/hide). One element at a time, video and PNGs checked before and after.
- Phase 4, layouts: top bar that shows title on hover in fullscreen, right sidebar (subtitles, audio, video, playback tabs), compact library sidebar, full library, network streams, playlists, home page, recent files, pins, menus, right-click menu, settings screen with her categories, hotkeys dialog, customization screen, onboarding.
- Phase 5, her new features: everything she shows that VLC does not do today, built to work for real. Examples from the video: subtitle add dialog (file/folder/playlist, from PC or OpenSubtitles, auto-matching per episode), subtitle timeline for syncing, sliders for subtitle timing, precise font sizes, per-show presets, default subtitle and audio track per show, audio and video filter presets with previews, reverse playback, sleep timer, waveform seek bar, seek thumbnails, unwatched/watched sorting, bookmarks sidebar with Ctrl+B, chapters, shortcut shown in on-screen messages, accent color setting, profiles with layouts. Use VIDEO_INDEX.md as the full list. Build one at a time, check each against the video, tell Sticky if one is technically impossible and why.
- Phase 6, public release: Sticky's project name and icon everywhere user-facing (window title, about dialog, executable name, installer, file associations), README (what it is, screenshots, "based on VLC media player", design credit with CC BY 4.0, GPL notice, how to download), and a workflow that publishes to GitHub Releases on version tags: a Windows installer (.exe, reuse VLC's own packaging in `extras/package/win32/` with our name and icon) plus a portable zip. Label builds as experimental, since they track VLC 4 development code.
- Ongoing: sync with upstream VLC master regularly, resolve conflicts in our UI changes, rebuild.
