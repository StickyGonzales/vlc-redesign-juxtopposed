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
| 1 | Installer (PR #33, `wip/installer`): merge into `wip/next-test` | PC session | not done | Tested on this PC 2026-10-25: install and uninstall next to VLC 3.0.21 pass (build 40214644177); uninstaller only removes its own keys: passed the before / after comparison (build 40230455256), merged into `wip/installer` (a05689aeff); known limits accepted for 1.0 (INSTALLER_NOTES.md, 0946594714) |
| 2 | Cone Player rename (PR #46, `wip/cone-player`, Decision 73) and its plan (PR #45): merge into `wip/next-test` | PC session | not done | Conflict with `wip/next-test` resolved 2026-10-25 (4ebdbc9259); merges cleanly with #33 (RENAME_CONE_PLAYER.md section 7) |
| 3 | Installer + rename retest on Windows, on the merged code | PC session | not done | INSTALLER_NOTES.md section 6 and RENAME_CONE_PLAYER.md section 6 (portable zip, names in the app, install next to VLC, uninstall); the earlier pass was the test branch `wip/test-installer-1.0`, not the merged code |
| 4 | Issue #52 fix (PR #55, `wip/fix-pause-rate`, core): its own Windows build and retest, then merge into `wip/next-test` | PC session | not done | FIX_PAUSE_RATE_NOTES.md "Retest on Windows"; reproduced on this PC 2026-10-25 (STATUS.md 22:20); whether it ships in 1.0: section 2b |
| 5 | Final `wip/next-test` check: one build of the merged state, smoke + screens (dark, light) + quit recipe | PC session | not done | Last run 40218059072: smoke and screens pass, quit recipe stopped by the start-up hang, since fixed and merged (20 of 20 starts) |
| 6 | Merge `wip/next-test` into `redesign` | PC session | not done | On hold since 2026-10-25 20:05 until the uninstaller bug and the start-up hang were understood; both are fixed now |
| 7 | Release workflow (PR #8, `wip/ci-release`): merge into `redesign` | PC session | not done | 1.0 file names and the "Cone Player <version>: ..." title done 2026-10-25 (d8fa02d1d0); needs #2 in `redesign` first, or its build step stops on the old names (CI_RELEASE_NOTES.md) |
| 8 | Homepage screenshots: retake `docs/images/cone-player.png`, `cone-settings-sidebar.png`, `cone-library.png`, `cone-settings.png` on the 1.0 build | PC session | not done | Only the Cone Player window, generated or public media (privacy rules); the Figma images stay |
| 9 | README and release notes (PR #54, `wip/readme-1.0`): final pass and merge | PC session | not done | RELEASE_1.0_NOTES_DRAFT.md "Before publishing": known issues rechecked on the 1.0 build, download links to the `v1.0.0` release, the commit in the license line, the new screenshots (#8) |
| 10 | Go for the public release | StickyGonzales | not done | Publishing a public release needs StickyGonzales's go (CLAUDE.md, W9.1) |
| 11 | Release: `v1.0.0` tag on `redesign`, release workflow, not a pre-release; smoke, screens and quit checks on the tag's build | PC session | not done | release.yml from `redesign`; files `ConePlayer-1.0.0-win64.zip`, `coneplayer-1.0.0-win64.exe`, SHA256SUMS.txt |

### 2a. StickyGonzales's own checks

| # | Check | Owner | State | Notes |
|---|---|---|---|---|
| 12 | Night mode listening test | StickyGonzales | not done | STATUS.md "Checks only Sticky can do" |
| 13 | OpenSubtitles with your own API key | StickyGonzales | not done | Add Subtitles dialog, From OpenSubtitles |
| 14 | Display scaling 150 % (and back to 100 %) | StickyGonzales | not done | Every screen readable, nothing cut or overlapping |
| 15 | Touchpad: feel of the wheel scrolling | StickyGonzales | not done | Volume over the video and the volume control, lists (Decision 54) |
| 16 | The other lines of that STATUS list: Cone tray icon in the hidden icons, Rescan plugins from Program Files (admin prompt, needs the installer), firewall prompts for the new exe path | StickyGonzales | not done | Keep or drop each for 1.0; the installer test saw the firewall alert (its Cancel left 2 Allow rules, STATUS.md 19:45) |

### 2b. Decisions for StickyGonzales before 1.0

| # | Question | Owner | State | Notes |
|---|---|---|---|---|
| 17 | Issue #52 fix (PR #55) in 1.0? | StickyGonzales | open | A user-reported HIGH; core change, own build (Decision 55) |
| 18 | Subtitle Duration Factor at 10 shows no subtitle at all (STATUS.md 22:20, found in the quit recipe's preset): fix for 1.0 or a known issue? | StickyGonzales | open | No fix branch yet |
| 19 | The LOWs with no fix: Brightness slider reports a 0 to 0 range to screen readers; M (mute) shows no "Pressed M" line | StickyGonzales | open | 1.0 or later |
| 20 | Waiting from CLAUDE.md: pixel subtitle size / live style (core); message position clear of the top bar (#22, MUSTHAVES_2_NOTES.md section 9.5) | StickyGonzales | open | |
| 21 | Decision 54 follow-up: the speaker button's wheel sets the volume and the speed button no longer reacts to the wheel: keep or revert? | StickyGonzales | open | STATUS.md "Checks only Sticky can do" |

## 3. Not part of 1.0 (listed so nothing is lost)

| What | Where | Why not 1.0 |
|---|---|---|
| Up Next / Autoplay next episode | PR #47 (`wip/up-next`), plan PR #44 | Cone extra (Decision 71): 1.1 |
| P4-33 Reverse toggle, P4-30 filter preset previews | VIDEO_INDEX | Decision 29 (postponed), Decision 67 (dropped) |
| Linux build and its fixes | `wip/linux-build`; PRs #48 (Interface language), #49 (Output device), #50 (post-processing), #51 (Spectrometer abort, core), #53 (release build) | Linux gets its own release later (README draft); the web session's branch |
| HEVC clip with 16 B-frames stalls after an audio track switch; the x265 film's quit stalls about 1 in 5 (the watchdog ends it after 5 s, settings saved) | PR #38 (analysis), PR #36 (rest of the visualizer work) | Known issues, revisit after 1.0 (StickyGonzales 2026-10-25); listed in the release notes |
| WASAPI may log "stream failed to start: 0x88890005" on a pause / resume | STATUS.md 17:45 | LOW, harmless, upstream timing |
| Windows checklist | PR #29 (`wip/windows-checklist`) | Its rows are sorted in section 1 of this file; it can be closed |
