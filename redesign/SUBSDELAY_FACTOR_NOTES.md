# Subtitle Duration Factor: why no cap fixes "factor 10 hides every subtitle" (2026-10-25)

Asked: find the highest Subtitle Duration Factor that still shows subtitles correctly and cap the slider there (UI only). Result: **there is no such value**. With ASS / SSA subtitles every value above 0 hides them; with SRT and other text subtitles no value changes anything. The cause is in VLC's `subsdelay` filter (`modules/spu/subsdelay.c`, a core module) under VLC 4's subtitle timing, so a cap in the slider would not help. No code changed; the decision is RELEASE_1.0_CHECKLIST.md line 18.

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

## Windows check (PC session)
Confirms the sandbox result on Cone's real path (the sidebar slider switches the filter on through the video output, not the command line). Use a fresh portable folder, and reset the factor to 0 at the end (the Default Preset keeps it).
1. An MKV with an ASS / SSA subtitle track: pick the track, then Settings sidebar > Subtitles > Subtitle Duration Factor 1, then 2, then 10. Expected from the sandbox: the subtitle disappears at each value above 0 and comes back at 0.
2. An MP4 with an external SRT: factor 0, then 5. Expected: no difference; a line does not stay past its end time.
3. Note in STATUS.md whether Windows matches. If SRT also disappears there, that is a second problem the sandbox does not show.
