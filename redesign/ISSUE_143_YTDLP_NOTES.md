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

## The fix (branch wip/fix-ytdl-formats, PR #147; core change approved by StickyGonzales, Decision 27)

**Round 1 (3d30b1d017, build-windows 279), retest failed on the PC (2026-11-16, STATUS.md #147 row):**
- worked: the storyboard skip and the null-device stderr (no `cannot start` from a no-stderr start);
- (a) a ytdl-path with a space failed: src/win32/spawn.c joined argv with plain spaces, so yt-dlp
  got its own path split at the space as the URL (`ytdl error: syntax error`, `cannot extract
  infos`); plain VLC 4 the same;
- (b) "prefer a format with video and audio" made YouTube's only muxed format the default (18,
  360p progressive MP4). VLC plays it over HTTP far faster than real time: thousands of `clock
  gap, unexpected stream discontinuity`, the clock reaches the end within 25-30 s, then EOF
  (1977 s and 634 s videos). Plain VLC 4 with the format 18 URL opened directly does the same; the
  same file played from disk is fine. So that rule was taken out again.

**Round 2 (StickyGonzales, 2026-11-16): what the branch does now.** All VLC core, upstream code,
minimal. Nothing in Cone's interface changes.
1. **Storyboards are never picked** (kept from round 1). `modules/demux/ytdl_formats.c` skips a
   format whose `format_note` is "storyboard", whose protocol or extension is `mhtml`, or whose
   `vcodec` and `acodec` are both "none". A video that lists nothing else fails instead of
   showing a still for 10 s.
2. **Otherwise the choice is plain VLC 4's**, copied unchanged (`CompareFormats`):
   - formats with an `abr` field first (YouTube's video-only formats have `abr: 0`, the muxed
     18 none), then formats with a height;
   - with a Preferred video quality, the **lowest** height at or below it, or the highest when
     none fits (round 3: the highest at or below it, see below);
   - Best available: the highest height.
   - On YouTube today:
     - **Best available:** itag 270, 1080p HLS, video only, **no sound**: the known VLC 4 limit,
       as plain VLC 4 with a working yt-dlp start.
     - **Any set quality (144p to 1080p):** VLC 4's rule gives itag **269, 144p** HLS, video
       only, no sound. VLC 4 itself never reached this: it picked the storyboard, which sorts
       lower still. Noted in the upstream draft (report 1).
3. **A start without a standard error runs yt-dlp** (kept from round 1). On Windows, when Cone
   has no stderr handle (`_get_osfhandle(2)` is -1 or -2: Explorer, the Start menu, a
   shortcut), yt-dlp gets the null device as its stderr (`modules/demux/ytdl.c`), so vlc_spawnp
   no longer fails with `cannot start ...: Unknown error`.
4. **New: arguments with a space or a quote are quoted** (`src/win32/spawn.c`, the quoting in the
   new `src/win32/cmdline.c` / `.h`; round 3: only yt-dlp's, in `modules/demux/ytdl_cmdline.c`).
   - **The rules:** the Windows command-line rules (CommandLineToArgvW and the Microsoft C
     start-up code).
   - **When an argument gets quotes:** when it is empty or holds a space, tab, new line,
     vertical tab or `"`.
   - **Inside the quotes:** a `"` becomes `\"`, and backslashes in front of a quote or of the
     closing quote are doubled.
   - **Other arguments:** copied as before.
   - **Result:** a yt-dlp in `C:\Program Files\...` (or any folder with a space) starts with
     the right arguments. This is for every vlc_spawn / vlc_spawnp user on Windows, not only ytdl.
- **Debug line** for the retest: `ytdl debug: format 270 picked (270 - 1920x1080)`.
- **Not fixed (a later release, upstream report 3):** YouTube's progressive MP4 over HTTP races to
  its end (round 1, (b)).

**Round 3 (PC, 2026-11-16, 1336dabc1c, StickyGonzales: #147 must not change normal playback).**
Items 2 and 4 of round 2 changed as follows; items 1 and 3 stay.

*Regression proof, from the code (step 1 a and b):*
- **Every caller of the spawn code.** `vlc_spawn` / `vlc_spawnp` / `vlc_process_Spawn` in the tree:
  - `modules/demux/ytdl.c` (yt-dlp);
  - `src/win32/process.c` `vlc_process_Spawn`, used by `src/preparser/external.c`: the external
    preparser, `vlc-preparser.exe --timeout-tick <n> --types <n> --daemon`, started for normal
    files (thumbnails, durations, metadata). Its argv[0] is its own full path, which has a space
    when Cone is installed in `C:\Program Files`;
  - `modules/stream_filter/decomp.c` and `modules/misc/inhibit/xdg.c`: not built on Windows
    (`if !HAVE_WIN32` in modules/stream_filter/Makefile.am; xdg is Linux only);
  - `src/posix/netconf.c`, `src/posix/*`: other systems, other spawn code (posix_spawn).
  - So on Windows the shared quoting of round 2 would have changed how vlc-preparser.exe gets its
    command line for every normal file. **Round 3 takes it out of the core:** `src/win32/spawn.c`,
    `src/Makefile.am` and `src/meson.build` are byte for byte those of wip/next-test, and
    `git diff wip/next-test` touches nothing under `src/` or `include/`. The quoting moved to
    `modules/demux/ytdl_cmdline.c` / `.h` (the same rules), and `ytdl_popen()` quotes yt-dlp's
    arguments one by one (`ytdl_QuoteArg`) before `vlc_spawnp()` joins them with spaces, on
    Windows only; the program path it searches for stays unquoted. Its test moved to
    `test/modules/demux/ytdl_cmdline.c`, plus a check of the one-argument quote.
- **When the ytdl module runs at all** (`modules/demux/ytdl.c`, unchanged by #147: `OpenFilter`,
  the module block):
  - it is a demux of priority 7, so VLC tries it only after every demux of a higher priority
    (mp4 240, es 155, mkv 50, adaptive 12, ts 10, ...) has refused the stream (avformat, 5,
    comes after it);
  - `OpenFilter` refuses at once unless the URL starts with `http:` or `https:` and the `ytdl`
    option is on: a local file (`file://`), a disc, a network share never reach it;
  - a direct media link (`https://.../video.mp4`) is taken by its real demux (mp4 at 240) before
    ytdl is tried, so yt-dlp is not started; only a link no real demux accepts (a web page such as
    youtube.com/watch) reaches ytdl. The `ytdl://` access is used only when typed on purpose.
  - All of this is plain VLC 4 behaviour; #147 changes only what happens after yt-dlp has run (the
    format choice) and how yt-dlp is started (stderr, quoting).

*Height choice (step 2).* The option's help text (`src/libvlc-module.c`,
INPUT_PREFERREDRESOLUTION_LONGTEXT): "select one whose resolution is closest to (but not higher
than) this setting". So among the heights at or below the setting the **highest** now wins
(`modules/demux/ytdl_formats.c`); VLC 4 took the lowest, so 1080p set gave 144p. Unchanged: Best
available (the highest), and the highest when nothing fits. On YouTube today (`--dump-single-json`
of the test video, 2026-11-16): every height has a video-only HLS format with `abr: 0` listed
first (602/269 144p, 229 240p, 230 360p, 231 480p, 232 720p, 270 1080p), so 1080p set gives
**270, 1080p HLS** like Best available, 720p gives 232, still without sound. Unit tests: youtube
240 -> 229, 360 and 720 -> 230 (the saved list has no 720p HLS), 1080 -> 270; muxed HLS 1080 ->
96, 720 -> 95, 240 -> 92.

### Unit tests
- `.github/scripts/ytdl-tests.sh` runs both on CI in `unit-tests.yml` (no VLC build), also with
  ASan and UBSan.
- **Format choice:** `test/modules/demux/ytdl_formats.c`, also in VLC's `make check` /
  `meson test` (test_modules_demux_ytdl_formats).
  - The format lists use the layout of `yt-dlp --dump-single-json`, written from yt-dlp's field
    layout and the itags the triage saw. The sandbox cannot reach YouTube.
  - The lists: a YouTube video (storyboards sb0-sb3, audio only, video only DASH and HLS up to
    1080p, the muxed 18), muxed HLS 91-96 next to a storyboard, storyboards only, split audio and
    video, video only next to a storyboard, a generic site with a no-codec preview, and a single
    format.
  - **23 checks pass.** The old code fails 10 of them, exactly the ones where it picked a
    storyboard or the no-codec preview (every set quality on the YouTube list gave `sb3`). The
    other 13 are identical to VLC 4: the choice is VLC 4's apart from the skip.
- **Spawn quoting:** `test/src/win32/cmdline.c`, plain C, so it runs on Linux too.
  - **11 command lines:** the yt-dlp case in `C:\Program Files\...`, a path without a space
    (unchanged), an empty argument, quotes, backslashes before a quote and at the end, tab and
    new line, UTF-8.
  - **Each line is checked twice:** against the expected text, and split back with the
    CommandLineToArgvW rules into the same arguments.
  - **On the old join:** 8 of the 11 fail.
  - **Not yet tested on real Windows:** the test cannot call the real CommandLineToArgvW here. The
    real check is the retest step with a space in the path.

### Windows retest (the PC; nothing of this could run in the sandbox)
Build from this branch (build-windows, portable zip). Use stable yt-dlp.exe.
- **Logs:** Tools > Messages at debug level (or the log file) shows the `ytdl` lines.
- **Starting Cone:** for steps 1 to 3, start Cone from PowerShell or a shortcut, either is fine.
  Step 4 must be a shortcut start.
1. **yt-dlp in a folder with a space.**
   - **Do:** copy yt-dlp.exe into a folder with a space (for example
     `<TEST_MEDIA_DIR>\builds\yt dlp\yt-dlp.exe`) and set it as Path to YT-DLP (All Cone
     Settings > Input / Codecs > Stream filters > YT-DL, as in the triage). Media > Open Network
     Stream, https://www.youtube.com/watch?v=z-g2huBo9qY, Play.
   - **Expect:**
     - it plays;
     - no `ytdl error: syntax error`, no `cannot extract infos`;
     - `ytdl debug: format 270 picked`.
2. **Best available, real time.**
   - **Do:** Settings > Playback > Preferred video quality "Best available", the same link; watch
     1 min.
   - **Expect:**
     - 1080p picture, **no sound** (the known VLC 4 limit, as plain VLC 4);
     - the time advances in real time (after 1 min the clock shows about 1:00, not the end);
     - no still picture, no `EOF reached` at 10 s, no flood of `clock gap` warnings.
3. **1080p set.**
   - **Do:** Preferred video quality 1080p, the same link (or the 634 s test video); watch 1 min.
   - **Expect:**
     - real time, no still picture, **no sound**;
     - `format 269 picked`, so a **144p** picture: VLC 4's own rule (the lowest height at or
       below the setting), kept as asked.
   - **Before:** the storyboard still for 10 s.
4. **A link after a shortcut start.**
   - **Do:** close Cone, start it from its Start menu or desktop shortcut, open the link of
     step 1 (yt-dlp in the folder with a space), let it play 30 s, quit with Ctrl+Q.
   - **Expect:**
     - it plays (no `cannot start ... Unknown error`), as in step 2;
     - Cone closes normally.

### Runs
| Run | Head | Result |
|---|---|---|
| unit-tests 21, build-windows 279 (attempt 2), build-linux 158 | 3d30b1d017 (round 1) | green; the PC retest of 279 failed, see round 1 above |
| unit-tests 22 | 3c76ef5e86 (round 2) | green: 23 format checks and 11 quoting checks, also with ASan and UBSan |
| build-windows 280 | 3c76ef5e86 | green with smoke, first attempt (spawn.c and cmdline.c build for Windows) |
| build-linux 159 | 3c76ef5e86 | green with smoke |
