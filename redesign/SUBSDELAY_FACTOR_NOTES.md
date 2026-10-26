# Subtitle Duration Factor: why no cap fixes "factor 10 hides every subtitle" (2026-10-25)

Asked: find the highest Subtitle Duration Factor that still shows subtitles correctly and cap the slider there (UI only). Result: **there is no such value**. With ASS / SSA subtitles every value above 0 hides them; with SRT and other text subtitles no value changes anything. The cause is in VLC's `subsdelay` filter (`modules/spu/subsdelay.c`, a core module) under VLC 4's subtitle timing, so a cap in the slider would not help. Decided (StickyGonzales, 2026-10-25): option B for 1.0, the real fix (A) after 1.0; the change is on `wip/hide-subsdelay-factor` (below).

## Sandbox test (Linux)
The sandbox's Linux build of `wip/next-test` (7e88341685; the subtitle code is the same at 1dd1c90d8a), a libvlc program drawing the video into memory and checking every frame for subtitle pixels; generated black 640x360 video, 16 dialogue-like cues of 1.2 to 4 s with gaps of 0.3 to 2.5 s (the first 8 measured). "Inside" = frames with text during a cue's own time; "outside" = frames with text in the gaps (a working factor above 1 fills them).

| Subtitles | Filter | Inside the cues | Outside (gaps) |
|---|---|---|---|
| SRT, external file | off | 100 % | 2 % |
| SRT, external file | factor 2 / 10 | 100 % / 100 % | 2 % / 2 % |
| SRT, embedded in MKV | off | 100 % | 3 % |
| SRT, embedded in MKV | factor 2 / 10 | 100 % / 100 % | 3 % / 3 % |
| SRT, embedded | absolute mode +2 s / +5 s | 100 % / 100 % | 3 % / 3 % |
| ASS, embedded in MKV | off | 100 % | 3 % |
| ASS, embedded in MKV | factor 0.2 / 1 / 2 / 10 | **0 %** at each | 0 % |
| ASS, embedded in MKV | absolute mode +0 s | **0 %** | 0 % |

So with the filter running:
- **ASS / SSA: nothing shows**, at any value, even at factor 1.0 and at "+0 s" (values that should change nothing). Many MKV releases carry ASS tracks, which fits the PC finding "no subtitle at all"; in the test lane the Default Preset kept the factor, so it hid them in every file.
- **SRT and other text subtitles: no change** at any value: a line never stays longer than its own time, so the slider does nothing.

## Cause (two separate problems, both in the filter)
1. **Lines are never lengthened.** In VLC 4 the subtitle renderer sets every subtitle's start and stop back to the times it converted when the subtitle arrived, before each frame (`src/video_output/vout_subpictures.c`, "Update time to clock", around line 2349), and it picks what to show from those stored times. The filter writes the longer stop time later, from the subtitle's update callback, so the renderer overwrites it on the next frame.
2. **ASS disappears.** The filter shows a copy of each subtitle and calls the original's update with a time it computes from the original's start. The renderer has moved the copy to system time, but the original still carries stream time, so libass gets a time far from the subtitle's own (`modules/codec/libass.c:470`, `i_pts + (cfg->pts - p_subpic->i_start)`) and draws nothing. SRT's text renderer does not use that time, so SRT still shows.

The core and the filter code here are VLC 4's own (the subtitle renderer is identical to upstream VLC master; the filter only has Cone's fixes for its region list and for bitmap subtitles, FIX_SUBSDELAY_NOTES.md, without which upstream aborts or freezes on the first subtitle). This is an upstream VLC 4 bug.

## Options
- **A. Fix the filter (core change, own build, Decision 27 approval):** compute the longer stop when the subtitle enters the filter, so the renderer stores it; call the original's update with a time taken from the copy's own start, so libass gets a correct time. Shortening an earlier line when a new one arrives would still not reach the renderer, so overlapping lines stack and fade instead of being cut.
- **B. Hide the slider until A lands (UI only):** nothing a user can switch on hides subtitles; her sidebar loses one row she shows (P3-19 / P3-20), so it needs StickyGonzales's OK.
- **C. Keep it as it is, with a known issue in the release notes:** the default is 0 (off), but one drag turns it on, and the Default Preset carries it to every file.
- A cap at any value (the request) leaves ASS hidden at every value and SRT unchanged: not useful.

Recommendation: **B for 1.0** (with a release note line that it comes back once it works), **A after 1.0** on its own core branch. A also needs a test of the max-overlap and fade rules, which this sandbox cannot judge by eye, and 1.0 should not wait on it.

## Decision and change (branch `wip/hide-subsdelay-factor`)
StickyGonzales, 2026-10-25: hide the Subtitle Duration Factor slider for 1.0; at start, reset any saved factor (presets and settings) to 0 so the `subsdelay` filter is off and ASS subtitles show again; one line in the release notes; the real fix after 1.0. Interface only (`modules/gui/qt`), no core change:
- `player/qml/SubtitleSettingsPage.qml`: the slider row is hidden (`visible: false`, kept for the real fix).
- `player/rd_effects.cpp` + `qt.cpp`: when the interface opens, before VLC can start playback (`RdEffects::resetSavedSubtitleDurationFactor`, called from `OpenInternal`), `subsdelay` is taken out of the saved `sub-filter` and out of the player's dummy video output, and a `subsdelay-factor` other than 0 goes to 0 (saved to vlcrc when Cone quits). VLC's own default factor is 2 (the filter off), so a fresh settings file gets 0 once. The log says "subtitle duration factor hidden: ..." when it reset something.
- `player/rd_presets.cpp`: when the presets load, every preset (the Default Preset and each show's) with a factor other than 0 gets 0, and the file is saved.
- `dialogs/toolbar/rd_profile_settings.cpp`: a profile's settings are written without `subsdelay` in `sub-filter` and with factor 0, so switching to a profile saved before cannot turn it on again.
- `dialogs/extended/extended_panels.cpp`: VLC's old Adjustments and Effects dialog (Ctrl+E, and "..." > More Settings > Effects and Filters / Track Synchronization) had its own "Subtitle duration factor" box on the Synchronization tab, a second way to switch the filter on (found by the review): hidden too, both profiles, like the sidebar row.
- Still possible on purpose, not reset during the session: `--sub-filter=subsdelay` on the command line (a libvlc variable, which the reset does not read), or typing `subsdelay` into a filter list in All Cone Settings; the next start resets a saved one. A chain entry written with inline options (`subsdelay{...}`) is not matched (only typed by hand).

## Sandbox test of the change (Linux, real interface)
`wip/next-test` d7c237307a + this branch, built in the sandbox (no warnings in the changed files), Cone's window on Xvfb, the same generated black clip with an **ASS** track (`black-ass.mkv`), V to pick the track, a screenshot every 2 s for 26 s (13 shots), subtitle pixels counted and one shot looked at:

| Run | Saved state at start | Subtitle in the shots | Files after quitting |
|---|---|---|---|
| This build | the PC's: vlcrc `sub-filter=subsdelay`, `subsdelay-factor=10`; rd-presets.json factor 10 in the Default Preset and in a show preset for the clip's folder | **10 of 13** (the other 3 fall in gaps between cues); the line reads "Line number 5 of the test" | vlcrc `sub-filter` empty, `subsdelay-factor=0`; both presets factor 0 |
| Control: this build, clean settings, `--sub-filter=subsdelay --subsdelay-factor=10` on the command line (the reset does not touch the command line) | clean | **0 of 13** | |

The control shows the measurement sees the bug when the filter runs, so the 10 of 13 is the reset at work. Settings sidebar > Subtitles: Synchronization lists Subtitle Track Delay and Subtitle Speed, then Appearance follows with no gap (screenshot looked at). Ctrl+E > Synchronization: Audio track synchronization, the two subtitle track delays and Subtitle speed, no Subtitle duration factor and no gap (screenshot looked at). Not run in the sandbox: switching to a profile saved with the factor (the profile switch is menu driven; Windows step 5).

Factor 0 in vlcrc (the review asked whether it is a trap: with the filter's default mode a factor of 0 would end every line at its start if the filter were switched on some other way): measured with the filter forced on at factor 0, SRT external and embedded: 100 % of the cue frames show their line, as with the filter off (the renderer ignores the filter's stop times, cause 1 above). So 0 stays, as decided; ASS is hidden by the filter at any factor anyway.

Independent review (fresh agent, the whole diff): construction order, the one apply per change, the saves, the presets' load path and the profile write checked, no HIGH. Its two MED: the old dialog's box (fixed above) and the factor 0 trap (measured above, does not happen). LOW, left as is: the command-line chain and `subsdelay{...}` (above); a config chain naming subsdelay while the module is missing logs "Unable to find filter module" at start (noise only).

## First start after upgrading (PC 2026-10-26, build 40316779162)
The PC test of the first version: on the first start with the bad state the ASS line stayed hidden for the whole session ("using sub filter module subsdelay ... appended to chain" in the log); from the second start on it showed. The first version reset the settings from `RdEffects`, which lives in the main view. Two things made that too late:
- **The dummy video output.** The player makes a dummy video output when it is created, before any interface opens (`src/input/resource.c`, `input_resource_New`), and that output reads `sub-filter` from the settings then. The first real output is created as its child and inherits its variables ("pre-configured on this dummy vout"), so it got `subsdelay` whatever the settings said later.
- **Windows builds the main view later.** Its compositor (`compositor_dcomp.cpp`) sets the main view up after the interface has told VLC it is ready, so the first file can start before `RdEffects` exists; on Linux the main view, and the first version's reset, came first, which is why the sandbox passed.

Fix: the reset moved to the interface's `OpenInternal()`, which runs before VLC may start playback (it waits for the interface to be ready). It cleans the saved settings and the dummy output's `sub-filter` (`vlc_player_vout_Hold()` returns the dummy while no real output exists). The dummy is only cleaned when the saved settings had the filter, so `--sub-filter=subsdelay` given on purpose on the command line still applies.

Sandbox (same bad state, verbose log):

| Build | First start: ASS line in the shots | `subsdelay` in the log |
|---|---|---|
| Settings reset in `OpenInternal()` only (an intermediate version, not pushed) | 0 of 13 | loads when the subtitle track starts, after "subtitle duration factor hidden" (line 38) and the first video output (line 421): the dummy output's inherited value (the PC's failure, reproduced) |
| This version (settings + dummy output) | **10 of 13** (the other 3 in gaps) | never loads; the reset lines (38-39) come before the input (50) and the first video output (421) |
| Clean settings, `--sub-filter=subsdelay` on the command line | 0 of 13 | loads, as asked on the command line (left alone on purpose) |

## Retest on Windows (PC task 4a)
Build this branch on its own (`gh workflow run build-windows.yml --ref wip/hide-subsdelay-factor`), deploy to the test folder. Test files: an MKV with an ASS / SSA track (the test film, or a generated one) and an MP4 with an external SRT.
1. The bad state: in the test folder's portable vlcrc set `sub-filter=subsdelay` and `subsdelay-factor=10.000000`; in rd-presets.json set `"subDuration:sub-duration-factor": 10` in the Default Preset. (Before the fix, 0.2.0 or the last `wip/next-test` build shows no ASS line with this state, optional.)
2. **The first start** of this build with that state (double-click the ASS file, or open it): pick its subtitle track; the lines show and change on time in this first session. With a log (`--file-logging --logfile=<TEST_MEDIA_DIR>\cone-4a.log --log-verbose=2`): "subtitle duration factor hidden: subsdelay taken out of the saved sub-filter" near the start, and no "using sub filter module \"subsdelay\"".
3. Quit, open vlcrc and rd-presets.json: `sub-filter` without `subsdelay`, `subsdelay-factor=0`, every preset's factor 0.
4. Settings sidebar > Subtitles: no Subtitle Duration Factor row, no gap under Subtitle Speed; Tab moves from the Subtitle Speed slider to the next control without stopping on a hidden one. Ctrl+E > Synchronization (and "..." > More Settings > Track Synchronization): no "Subtitle duration factor" box; the delays and Subtitle speed still work.
5. Profiles: with the previous build (0.2.0 or the last `wip/next-test` build) and the bad state of step 1, make a profile ("..." menu > Profile > + New): it keeps `sub-filter=subsdelay` and factor 10 in rd-profiles.json. Then start this build, switch to that profile and back: the ASS line still shows, and vlcrc has no `subsdelay` afterwards.
6. The SRT file: lines show as before (the filter never changed SRT).
7. Regression: subtitle delay and subtitle speed sliders still work; a show preset still applies its delay to its folder's files.
