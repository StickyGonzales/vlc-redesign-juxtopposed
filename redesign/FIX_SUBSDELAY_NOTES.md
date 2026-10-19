# Subtitle freeze and quit hang (branch wip/fix-subsdelay)

Branch `wip/fix-subsdelay`, made from `origin/wip/next-test` (eec9d03828), pull request into `wip/next-test`. **Core change** (`modules/spu/subsdelay.c`, a non-GUI module): build this branch on its own (Decision 55, build rounds rule), test, then merge. Nothing here is verified on Windows.

## Cause
The bug in STATUS.md on wip/next-test (picking an embedded subtitle track freezes the picture, no subtitle line is drawn, audio and the clock go on, quitting then hangs) is not in web-fixes-1 / web-fixes-2. It comes from VLC's "subsdelay" subtitle filter, which Cone switches on for the sidebar's **Subtitle Duration Factor** (RdEffects: the filter runs while the factor is above 0, 1.0 included):

- `SubpicClone()` in `modules/spu/subsdelay.c` copied the whole subtitle (`memcpy`), including its list of regions. In VLC 4 that list is a `vlc_list`: the copied head points at the regions, but the regions still point back at the source's head. Walking the clone's list runs past its regions into the source, which is read as a region. `SubpicUpdateWrapper()` swapped the lists by copying heads the same way.
- With assertions on (the Linux build), the first subtitle aborts Cone: `spu_PutSubpicture: Assertion '!subpicture_region_cache_IsValid(r)' failed`, from the subtitle decoder thread, while the video output waits in `spu_Render` for the subtitle prerender thread. Without them (the Windows build), the subtitle renderer reads garbage: the picture stops, no line is drawn, and the video output never stops, so the core teardown waits for it at quit (the PC's stack: vlc-player-end waiting, main thread in vlc_player_Delete).
- Upstream VLC master has the same code (checked 2026-10-19): this is an upstream VLC 4 bug that Cone exposes through the duration factor control.
- Why the beta looked fine and wip/next-test did not (inferred, please confirm on the PC): the filter is a setting (`sub-filter=subsdelay` in vlcrc, and the factor in the "Default Preset", which keeps it for every file), not code that changed between the builds (the code paths are the same in the beta). The PC's lag test of 2026-10-19 dragged the Subtitle Duration Factor slider in the test folder, which switched the filter on for every later run with that portable folder. Check: the portable vlcrc of the runs that froze has `sub-filter=subsdelay`; the beta and stock runs' had not. The "quit hang after slider drags and keys" of the same day is the same bug: the drags turned the filter on, the key loops picked a subtitle (v).

## Fix
- `SubpicClone()` gives the clone an empty list of its own and moves the regions into it. A helper, `SubpicMoveRegions()`, moves the nodes; ownership is unchanged (the regions belong to the clone the subtitle renderer shows; `SubpicDestroyClone()` frees the source without regions).
- `SubpicUpdateWrapper()` no longer clears the regions before the source's update: it moves them to the source, lets the source's updater keep or rebuild them, and moves them back. In VLC 4 a text updater returns early and keeps its regions when nothing changed; cleared first, a subtitle showed for one frame at most (found on the first test build: no freeze, but no subtitle either).

## Sandbox test (Linux)
Generated MKV, stereo AAC, two embedded SubRip tracks, a cue every 3 s, every other one on two lines; fresh profile, `v` picks the track, screenshots every 0.8 s looked at. Builds: before = build 11 of wip/linux-recheck (39274608830), after = build-linux 39299659350 of the test-only branch `wip/fix-subs-linux` (wip/next-test + this branch + wip/fix-subtitle-lift + the Linux build job).

| Run | Before | After |
|---|---|---|
| No filter, `v` | picture moves, subtitles shown | same |
| `--sub-filter=subsdelay`, `v` | abort on the first subtitle (assertion above), picture frozen | no abort, picture moves, one- and two-line cues show and change on time (a cue that the filter lengthens over the next one is drawn fainter: the filter's own overlap fading, `subsdelay-min-alpha`) |
| Profile with the duration factor in the "Default Preset" (vlcrc `sub-filter=subsdelay`), `v` | abort | (first test build, regions not yet kept) no abort, picture moves, Cone quits with exit 0 in about 1.5 s with the window's close button |

## Retest on Windows
1. Use the test folder that froze (its vlcrc has `sub-filter=subsdelay`): open the test film, seek to 0:55, pick "Track 2 - English" in the tracks popup: the picture keeps moving and the subtitle line shows. Press v twice: same.
2. Sidebar > Subtitles > Subtitle Duration Factor: drag it to 2 and back to 1 while a line shows: lines stay longer / shorter, the picture keeps moving.
3. Quit with the window's close button and with Ctrl+Q after 1 and 2: Cone exits within a second, every time (also the old recipe: drag Speed or Subtitle Track Delay, then the delay, speed, volume, seek, v and b key loops, then close).
4. A fresh portable folder: subtitles as before (filter off).
