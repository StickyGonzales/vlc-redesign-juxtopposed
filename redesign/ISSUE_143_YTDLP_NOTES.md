# Issue #143: YouTube links play only 10 seconds (yt-dlp)

PC triage, 2026-11-15. Read-only on GitHub, nothing fixed, nothing posted.

Report (Cone 1.4.0): yt-dlp path set to the stable `yt-dlp.exe`, network cache at its maximum,
Preferred video quality 240p, GnuTLS priorities "fastest"; every YouTube video stops after 10 s.
Test link: https://www.youtube.com/watch?v=z-g2huBo9qY (a 33 min video, 1977 s).

## Verdict

**VLC core (the upstream `ytdl` module, modules/demux/ytdl.c), not Cone, not YouTube, not yt-dlp.**
Cone has no code of its own in this path: every commit on ytdl.c is upstream (VLC 4 master,
Nov 2025), and Cone only shows VLC's own `preferred-resolution` option as "Preferred video quality"
(SettingsPlaybackPage.qml, VideoSettingsPage.qml). Plain VLC 4 (stock build 38315049322 and the vlc
profile build of wip/next-test) behaves exactly the same. Current upstream master (the
wip/upstream-sync branch, PR #138) has the same ytdl.c and src/win32/spawn.c, so nothing is
fixed upstream yet.

Severity for users: high for anyone who sets a video quality (YouTube is unusable), medium for the
default (video plays, no sound). A fix would be a core change (Decision 27: minimal and isolated,
StickyGonzales decides); it also belongs upstream (code.videolan.org, ytdl module).

## What happens at the 10 s mark

ytdl.c asks yt-dlp for `--flat-playlist --dump-single-json` and picks one entry from `formats`
itself (PickFormat / CompareFormats, ytdl.c:128-202); yt-dlp's own format choice is not used.

1. **Any Preferred video quality (240p, 360p, 720p ...): the storyboard picture is picked.**
   CompareFormats keeps, among the formats at or below the preferred height, the *lowest* one
   (`if (h_a > h_b) return -1;`, inverted), and YouTube's storyboard entries (`sb0`-`sb3`,
   `mhtml`, height 27-180, `abr` 0) count as video formats. The winner is `sb3`, a 48x27
   storyboard JPEG/WebP on i.ytimg.com. VLC opens it with the image demux, which shows a still
   for `image-duration`, default 10 s (modules/demux/image.c:89), then ends:

   ```
   ytdl debug: redirecting to: https://i.ytimg.com/sb/z-g2huBo9qY/storyboard3_L0/default.jpg?...
   main debug: using demux module "ytdl"
   image debug: Detected image: WebP Image
   main debug: using demux module "image"
   main debug: ES track added: 'video/auto/0' (fourcc: 'I420')
   main debug: EOF reached
   ```

   Proof of the cause: the same run with `--image-duration=-1` (show a still forever) has no
   `EOF reached` in 40 s. Network cache and GnuTLS priorities play no part (PickFormat reads only
   `preferred-resolution`).

2. **Best available (the default): video without sound.** With no preferred height the highest
   format wins, and the "prefer non-mute formats" test treats `abr: 0` (video-only) as having
   audio while the one muxed format (`18`, 360p with AAC) has no `abr` field at all. The pick is
   itag 270, 1080p HLS H.264, video only: it plays past 60 s, one `video/auto/0` track, no audio
   track.

3. **A normal start on Windows cannot run yt-dlp at all.** ytdl_popen passes `STDERR_FILENO` as
   the child's stderr (ytdl.c:81); a GUI process started from Explorer (or ShellExecute) has no
   stderr, so `dup_handle_from_fd(2)` fails in src/win32/spawn.c and vlc_spawnp returns -1
   before CreateProcess (`ytdl debug: cannot start ...yt-dlp.exe: Unknown error`). VLC's own
   vlc_process code checks for a missing stderr first (src/win32/process.c:196); ytdl does not.
   Not the space in the path: a path without spaces fails the same way. With stderr redirected
   (Start-Process -RedirectStandardError), yt-dlp runs and cases 1 and 2 follow. How the
   reporter's start gets a stderr handle is not known (they clearly reach case 1).
   Side effect: after the failed start VLC keeps probing the YouTube web page with every demux and
   Lua playlist script; a quit after it did not end within 20 s in 4 of 5 no-stderr runs here
   (stopped once each; the first 1.4.0 run closed normally), on stock VLC 4, the vlc profile and
   Cone alike. Not looked into further.

## Runs (one at a time, portable profiles in verify-lane-yt143-* lanes, logs local only)

yt-dlp from the official GitHub releases, SHA2-256SUMS checked: stable 2026.10.26, nightly
2026.11.14.232655 (yt-dlp/yt-dlp-nightly-builds). "stderr" = started with stderr redirected to a
file, so yt-dlp can start; "no stderr" = a normal start. Reporter settings =
`--preferred-resolution=240 --network-caching=60000 --gnutls-priorities=PERFORMANCE`.

| Build | Settings | yt-dlp | Start | Result |
|---|---|---|---|---|
| Cone 1.4.0 (release zip) | default | stable | no stderr | `cannot start ... Unknown error`, nothing plays (path with and without spaces) |
| Cone 1.4.0 | default | stable | stderr | itag 270 1080p HLS, video only, plays on (no audio track) |
| Cone 1.4.0 | default | nightly | stderr | same as stable |
| Cone 1.4.0 | reporter | stable | stderr | storyboard `sb3` image, `EOF reached` (10 s) |
| Cone 1.4.0 | reporter | nightly | stderr | same as stable |
| Cone 1.4.0 | reporter + `--image-duration=-1` | stable | stderr | storyboard image, no EOF in 40 s |
| wip/next-test public, build-windows 269 (80682ac6242, #142 included) | default | stable | no stderr | `cannot start ... Unknown error` |
| wip/next-test public 269 | default | stable / nightly | stderr | itag 270, video only |
| wip/next-test public 269 | reporter | stable / nightly | stderr | storyboard image, `EOF reached` |
| wip/next-test vlc profile, build-windows 270 | default | stable | no stderr | `cannot start ... Unknown error` |
| wip/next-test vlc profile 270 | default | stable | stderr | itag 270, video only |
| wip/next-test vlc profile 270 | reporter | stable / nightly | stderr | storyboard image, `EOF reached` |
| stock VLC 4 (38315049322) | default | stable | no stderr | `cannot start ... Unknown error` |
| stock VLC 4 | reporter | stable | stderr | storyboard image, `EOF reached` |

The format pick was also replayed offline from yt-dlp's JSON (same rules as CompareFormats):
stable and nightly give the same 55 formats; preferred 240, 360 or 720 all pick `sb3`, none picks
`270`. `-f 18` in a yt-dlp config does not help: the JSON still lists all formats and VLC ignores
yt-dlp's choice.

## What a fix would touch (triage, 2026-11-15; done on wip/fix-ytdl-formats, see "The fix" below)

All in VLC core, upstream code, so ideally reported or sent upstream first:
- ytdl.c CompareFormats: skip storyboards (`format_note` "storyboard" / protocol `mhtml` /
  `vcodec` and `acodec` both "none"), prefer the *highest* height at or below the preferred one,
  and treat a format as having audio only when `acodec` is not "none" (not by `abr`).
- ytdl.c ytdl_popen: pass `-1` for stderr when `_get_osfhandle(STDERR_FILENO)` is invalid (as
  src/win32/process.c does), so a normal Windows start can run yt-dlp.
- Longer term, sound at 240p needs separate audio and video streams (VLC's ytdl picks one URL);
  that is a bigger change than a format fix.

## Reply draft (not posted)

> Hi, thank you for the kind words and for the very clear report, the test link made this easy to
> check.
>
> We could reproduce it, and it isn't your yt-dlp version or your connection: the nightly yt-dlp
> behaves the same. Cone uses the YouTube support built into VLC 4 itself, and plain VLC 4 does
> exactly the same thing. When "Preferred video quality" is set (240p in your case), VLC picks
> YouTube's tiny preview picture (the storyboard used for seek thumbnails) instead of the video,
> and VLC shows a still picture for 10 seconds by default. That's the 10 seconds you see. Network
> cache and GnuTLS settings have nothing to do with it.
>
> For now you can set Settings > Playback > Preferred video quality back to "Best available".
> YouTube videos then play to the end, but VLC 4 currently picks a video-only stream there, so
> there's no sound and it uses the highest quality, which won't help on a slow connection. Sorry
> there's no better workaround yet.
>
> Since this lives in VLC's own code, we've noted what a fix needs (skip the preview picture, pick
> the right quality, keep the sound) and will update this issue when there's news.

## The fix (branch wip/fix-ytdl-formats, 2026-11-16, core change approved by StickyGonzales, Decision 27)

VLC core, upstream code, minimal: `modules/demux/ytdl.c` plus the format choice moved to
`modules/demux/ytdl_formats.c` / `.h` so it can be unit tested. Nothing in Cone's interface changes.

1. **Storyboards are never picked.** A format whose `format_note` is "storyboard", whose
   protocol or extension is `mhtml`, or whose `vcodec` and `acodec` are both "none" is skipped.
   If a video lists nothing else, the link fails instead of showing a still for 10 s.
2. **A format with both video and audio wins, for every quality, Best available included.**
   Audio and video are read from `acodec` / `vcodec` ("none" = absent), no longer from `abr`
   (a video-only format with `abr: 0` counted as having sound). The order is: video and audio,
   then formats with no codec information (generic sites), then audio only, then video only.
   Within a kind: the highest height at or below the chosen quality, or the lowest above it when
   none fits (the old code took the *lowest* at or below); Best available takes the highest;
   then the highest bit rate (`tbr`, then `abr`); on a full tie yt-dlp's later (better) entry.
3. **A start without a standard error can run yt-dlp.** On Windows, when Cone has no stderr
   handle (`_get_osfhandle(2)` returns -1 or -2: a start from Explorer, the Start menu or a
   shortcut), yt-dlp gets the null device as its stderr instead of our missing one, so
   vlc_spawnp no longer fails with `cannot start ...: Unknown error`. The null device rather than
   no handle at all, so yt-dlp (Python) still has a working stderr for its warnings.
- **New debug line** for the retest: `ytdl debug: format 18 picked (18 - 640x360 (360p))`.

**What it means on YouTube today:** YouTube offers video and audio together in one format only
at 360p (itag 18); every higher quality is video-only, with the sound in a separate stream. So
YouTube links now play **at 360p with sound** whatever the Preferred video quality, instead of
a 10 s still (any quality set) or a silent 1080p (Best available). Sites and streams that offer
muxed formats at several heights (YouTube live: HLS 91-96) get the chosen quality. HD with sound
on YouTube needs VLC to play a separate video and audio URL together: a larger change, not in
this fix (noted in the upstream draft).

### Unit tests
- `test/modules/demux/ytdl_formats.c`, in VLC's own `make check` / `meson test`
  (test_modules_demux_ytdl_formats), and on CI in `unit-tests.yml` through
  `.github/scripts/ytdl-format-tests.sh` (VLC's JSON parser built with bison and flex, no VLC
  build; also with ASan and UBSan).
- Format lists in the layout of `yt-dlp --dump-single-json` (the sandbox cannot reach YouTube,
  so they were written from yt-dlp's field layout and the itags the triage saw, not captured):
  a regular YouTube video (storyboards sb0-sb3, audio only 233/139/140/251, video only DASH and
  HLS up to 1080p with `abr: 0`, the one combined 18); HLS with video and audio at every
  height (91-96) next to video-only 1080p; storyboards only; video and audio only, split; video
  only; a generic site without codec names; a single format without a list.
- **25 checks.** All pass on the new code (also with ASan and UBSan). On the old code 20 fail, among them exactly the
  triage's picks: 144p to 1080p give `sb3`, Best available gives `270`.

### Windows retest (the PC; nothing of this could run in the sandbox)
Build from this branch (build-windows, portable zip). yt-dlp.exe (stable) set as in the triage
(the same way as in the triage: All Cone Settings > Input / Codecs > Stream filters > YT-DL > Path to YT-DLP). The log as in the triage (Tools > Messages
at debug level, or the log file) shows the `ytdl` lines. Start Cone **by double-clicking Cone.exe in
Explorer or its shortcut**, not from PowerShell, for every step (that is the no-stderr start).
1. **A normal video, Best available (the default).**
   - **Do:** Media > Open Network Stream, paste https://www.youtube.com/watch?v=z-g2huBo9qY, Play.
   - **Expect:** it plays with sound past 10 s and past 1 min; Messages: `format 18 picked`, no
     `cannot start`, no `i.ytimg.com/sb/` redirect, no `EOF reached` at 10 s. Before the fix: no
     playback at all from a shortcut (`cannot start ... Unknown error`), or 1080p without sound.
2. **The reporter's settings (240p).**
   - **Do:** Settings > Playback > Preferred video quality 240p (network cache at its maximum,
     GnuTLS "fastest" if you want the full recipe), the same link.
   - **Expect:** plays with sound past 10 s; `format 18 picked`. Before: a still picture, 10 s.
3. **A 1080p video, 1080p chosen.**
   - **Do:** Preferred video quality 1080p, a 1080p YouTube video (any HD upload).
   - **Expect:** plays with sound (360p, format 18, see above); no still, no silence.
4. **Best available with that 1080p video.**
   - **Do:** back to Best available, the same 1080p video.
   - **Expect:** plays with sound, `format 18 picked`.
5. **Started from a shortcut, then quit.**
   - **Do:** with Cone started from its Start menu or desktop shortcut, open the link of step 1,
     let it play 30 s, quit with Ctrl+Q.
   - **Expect:** it plays (the stderr fix), and Cone closes normally.
- Optional: `yt-dlp -J <link> > list.json` for the two videos, kept local, to compare the
  `format_id` VLC logs with the list (18 must be the only entry with both `vcodec` and
  `acodec` not "none").


### Runs
| Run | Head | Result |
|---|---|---|
| unit-tests 21 | 3d30b1d017 | green: the 25 ytdl format checks pass, also with ASan and UBSan |
| build-windows 279 | 3d30b1d017 | green on attempt 2 (build and smoke). Attempt 1 built (ytdl.c with the stderr change compiles for Windows); its smoke failed one check, `installed-h264: quit: took 4.76 s (limit 3 s)` (a local H.264 file: ytdl only opens http / https links, so not this change); the one re-run of the smoke job passed |
| build-linux 158 | 3d30b1d017 | green with smoke |
