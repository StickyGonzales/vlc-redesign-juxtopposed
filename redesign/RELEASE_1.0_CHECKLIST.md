# Cone Player 1.0: release checklist

The single list that 1.0 is counted against. Everything that must happen before the `v1.0.0` release is a line in section 2, with its owner and state. When a line is done, its owner sets it to **done** with the commit, build or date in Notes. Anything new that turns up for 1.0 goes in here too, not only in STATUS.md.

Made 2026-10-25 from `wip/next-test` 079b8b59cf: every VIDEO_INDEX.md row that was not verified, checked against STATUS.md, WINDOWS_CHECKLIST.md (`wip/windows-checklist`), LINUX_VERIFY.md (`wip/verify-linux`) and the merged and open pull requests.

Owners: **PC session** (tests on Windows, merges into `wip/next-test` and `redesign`, the release run) or **StickyGonzales**. Code fixes stay with the web session (Decision 64): when a test fails, the PC session logs the bug in STATUS.md and the line stays not done.

## 1. VIDEO_INDEX rows

361 rows. Before this pass: 295 verified, 66 not (59 todo, 4 in progress, 1 done, 1 dropped, 1 postponed). Sorted:

| Category | Rows | Which |
|---|---|---|
| Already verified, stale status (fixed in VIDEO_INDEX) | 3 | P7-06 (PR #39), F-11 (PR #41), IA-01 (the Cone icon and the visualizer window title): all tested on Windows in round 5, 2026-10-20 (STATUS.md) |
| Context, nothing to build (status now `context (nothing to build)`) | 61 | old VLC, problem, B-roll, sponsor, meme, survey and chapter card rows, the same 61 as WINDOWS_CHECKLIST.md "none (context row)"; including P3-02, P4-02 and P4-08, which read "in progress (merged, not built)" though they are problem statements, not features |
| Optional | 0 | |
| Postponed or dropped, by Decision | 2 | P4-33 Reverse toggle (Decision 29, postponed: VLC's engine has no reverse playback); P4-30 video filter preset previews (Decision 67, dropped) |
| Cone extra for 1.1 | 0 | no VIDEO_INDEX row; Up Next is listed in section 3 |
| Linux only | 0 | no VIDEO_INDEX row; the Linux branches are listed in section 3 |
| **Required for 1.0, not yet verified** | **0** | |

Now: 298 verified, 61 context, 1 postponed, 1 dropped. Every buildable row is verified, so what is left for 1.0 is the work in section 2.

## 2. Before the 1.0 release

| # | Task | Owner | State | Notes |
|---|---|---|---|---|
| 1 | Installer (PR #33, `wip/installer`): merge into `wip/next-test` | PC session | done | Merged into `wip/next-test` 2026-10-26 (1d6765d551); retested in line 3. |
| 2 | Cone Player rename (PR #46, `wip/cone-player`, Decision 73) and its plan (PR #45): merge into `wip/next-test` | PC session | done | Merged into `wip/next-test` 2026-10-26 (#45 13fb7686a2, #46 a5aacbe668; doc conflicts only). |
| 3 | Installer + rename retest on Windows, on the merged code | PC session | done | Passed 2026-10-26 on `wip/next-test` build 40321389086 (restore point first, no beta upgrade): portable setting kept; names in the app; install next to VLC 3.0.21 (Apps, Start menu, desktop, folder menu, Open with, HKCU untouched, setting kept); uninstall back to the before snapshot apart from Windows caches and the kept preferences; VLC still plays; smoke + screens pass. Not checked: tray tooltip, Task Manager / volume mixer names, the installer pages (needs "I Agree" on the license page). STATUS.md 2026-10-26. |
| 4 | Issue #52 fix (PR #55, `wip/fix-pause-rate`, core): its own Windows build and retest, then merge into `wip/next-test` | PC session | done | Every retest step passed on build 40235578425, merged into `wip/next-test` (STATUS.md 2026-10-25 23:45); in 1.0 (StickyGonzales, 2026-10-25) |
| 4a | Subtitle Duration Factor hidden for 1.0, saved factor reset (PR #56, `wip/hide-subsdelay-factor`): its own Windows build and retest, then merge into `wip/next-test` | PC session | done | Passed 2026-10-26 on build 40329370093 (first start with a saved factor 10: the ASS line shows), merged into `wip/next-test` (9b885509e4). |
| 5 | Final `wip/next-test` check: one build of the merged state, smoke + screens (dark, light) + quit recipe | PC session | done | Merged state checked 2026-10-26 on 40321389086 (smoke, screens, quit recipe); #56 then tested on its own build; the v1.0.0 release build smoke-tested (line 11). |
| 6 | Merge `wip/next-test` into `redesign` | PC session | done | 2026-10-26: 64cdc21d81 (with #56, #54). |
| 7 | Release workflow (PR #8, `wip/ci-release`): merge into `redesign` | PC session | done | 2026-10-26: d5a466e7f3 (conflict in build-windows.yml resolved, the release run passed). |
| 8 | Homepage screenshots: retake `docs/images/cone-player.png`, `cone-settings-sidebar.png`, `cone-library.png`, `cone-settings.png` on the 1.0 build | PC session | done | Retaken 2026-10-26 on `wip/next-test` build 40321389086 (gate dark screens, accent #8E42FF, 1600 x 900): 40ab5aa1bc. |
| 8a | Homepage images: the README has no hero for now (her Figma frame showed VLC's cone and name, removed 2026-10-26). The Blender renders replace `docs/images/cone-player.png`, `cone-settings-sidebar.png`, `cone-library.png` and `cone-settings.png` under the same names; a hero can come back as `docs/images/hero.png` (one centered image under the badges in README.md). Then rerun `python3 redesign/brand/make_social_preview.py` | PC session | done | 2026-10-26 (PC session, StickyGonzales's list): Blender open movies Sintel, Big Buck Bunny and Tears of Steel (1080p from download.blender.org, CC BY 3.0 checked on durian / peach / mango.blender.org; Sintel MD5 checked) in a library of only those films, dark theme, default orange accent, Cone Player 1.0.0 zip: hero.png (Sintel 5:40), cone-player.png (Tears of Steel with its official English subtitles), cone-settings-sidebar.png (Big Buck Bunny), cone-library.png (Home with Continue Watching and the mini player), cone-settings.png; new cone-accents.png (the nine accents, redesign/brand/make_accents_image.py) in a "Themes and accent colors" section; social preview rerun with hero.png; film credits in the README. Spring and Charge left out: no public download from an official source (Blender Studio needs an account). |
| 8b | GitHub settings: upload `redesign/brand/social-preview.png` (Settings > General > Social preview) and paste the About box text (description, website, topics) from the README pull request | StickyGonzales | not done | Repository settings need the owner |
| 9 | README and release notes (PR #54, `wip/readme-1.0`): final pass and merge | PC session | done | Merged 2026-10-26 (ba0f3aa4da); known issues updated (closing-time double-click, #57 left out); the zip line corrected (settings go to %APPDATA%\Cone). |
| 10 | Go for the public release | StickyGonzales | done | Go 2026-10-26 14:30. |
| 11 | Release: `v1.0.0` tag on `redesign`, release workflow, not a pre-release; smoke, screens and quit checks on the tag's build | PC session | done | v1.0.0 on d5a466e7f3, release run 40334057134 green; installer and zip from the release: SHA256SUMS match, both start and play a file; published as the latest full release: https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.0.0 |

### 2a. StickyGonzales's own checks

| # | Check | Owner | State | Notes |
|---|---|---|---|---|
| 12 | Night mode listening test | StickyGonzales | not done | STATUS.md "Checks only Sticky can do" |
| 13 | OpenSubtitles with your own API key | StickyGonzales | not done | Add Subtitles dialog, From OpenSubtitles |
| 14 | Display scaling 150 % (and back to 100 %) | StickyGonzales | not done | Every screen readable, nothing cut or overlapping |
| 15 | Touchpad: feel of the wheel scrolling | StickyGonzales | not done | Volume over the video and the volume control, lists (Decision 54) |
| 16 | Cone tray icon in the Windows hidden icons | StickyGonzales | not done | STATUS.md "Checks only Sticky can do" |
| 16a | Firewall prompt for the new exe path | PC session | done | Seen during the installer test 2026-10-25 (STATUS.md 19:45: the alert's Cancel left 2 Allow rules named "Cone Player") |

Dropped (StickyGonzales, 2026-10-25): Rescan plugins from Program Files.

### 2b. Decisions for StickyGonzales before 1.0

| # | Question | Owner | State | Notes |
|---|---|---|---|---|
| 17 | Issue #52 fix (PR #55) in 1.0? | StickyGonzales | decided | Yes, if its Windows test passes (line 4) |
| 18 | Subtitle Duration Factor: no value works (ASS / SSA hidden at every value above 0, SRT never lengthened; an upstream VLC 4 filter bug) | StickyGonzales | decided | Hide it for 1.0 and reset any saved factor (presets and settings) to 0 at start, so the filter is off and ASS shows again (line 4a); one line in the release notes (`wip/readme-1.0`, b533a6202d); the real fix after 1.0 (section 3) |
| 19 | The LOWs with no fix: Brightness slider reports a 0 to 0 range to screen readers; M (mute) shows no "Pressed M" line | StickyGonzales | decided | After 1.0 (section 3); "Pressed M" stays in the release notes' known issues |
| 20 | Waiting from CLAUDE.md: pixel subtitle size / live style (core); message position clear of the top bar (#22, MUSTHAVES_2_NOTES.md section 9.5) | StickyGonzales | decided | Both after 1.0 (section 3) |
| 21 | Decision 54 follow-up: the speaker button's wheel sets the volume and the speed button no longer reacts to the wheel: keep or revert? | StickyGonzales | decided | Keep |

## 3. Not part of 1.0 (listed so nothing is lost)

| What | Where | Why not 1.0 |
|---|---|---|
| Up Next / Autoplay next episode | PR #47 (`wip/up-next`), plan PR #44 | Cone extra (Decision 71): 1.1 |
| P4-33 Reverse toggle, P4-30 filter preset previews | VIDEO_INDEX | Decision 29 (postponed), Decision 67 (dropped) |
| Linux build and its fixes | `wip/linux-build`; PRs #48 (Interface language), #49 (Output device), #50 (post-processing), #51 (Spectrometer abort, core), #53 (release build) | Linux gets its own release later (README draft); the web session's branch |
| HEVC clip with 16 B-frames stalls after an audio track switch; the x265 film's quit stalls about 1 in 5 (the watchdog ends it after 5 s, settings saved) | PR #38 (analysis), PR #36 (rest of the visualizer work) | Known issues, revisit after 1.0 (StickyGonzales 2026-10-25); listed in the release notes |
| Subtitle Duration Factor, the real fix: the `subsdelay` filter under VLC 4's timing (core module), then the slider back | `modules/spu/subsdelay.c`; SUBSDELAY_FACTOR_NOTES.md option A | After 1.0 (StickyGonzales, 2026-10-25); hidden for 1.0 (line 4a) |
| Brightness slider's range for screen readers (0 to 0); "Pressed M" for mute | STATUS.md 2026-10-25 | LOWs, after 1.0 (StickyGonzales, 2026-10-25) |
| Pixel subtitle sizes with live style changes (P3-23); on-screen messages clear of the top bar (#22) | MUSTHAVES_2_NOTES.md section 9.5, VIDEO_INDEX | Core changes, after 1.0 (StickyGonzales, 2026-10-25) |
| `Cone.exe --version` prints no version and does not exit (with its output redirected; the same before the Cone Player rename) | STATUS.md 2026-10-26 | LOW, known issue (StickyGonzales, 2026-10-26) |
| WASAPI may log "stream failed to start: 0x88890005" on a pause / resume | STATUS.md 17:45 | LOW, harmless, upstream timing |
| Windows checklist | PR #29 (`wip/windows-checklist`) | Its rows are sorted in section 1 of this file; it can be closed |
