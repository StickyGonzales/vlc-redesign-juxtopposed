# Draft: three VideoLAN bug reports from issue #143 (not posted)

Ready to paste into new issues at https://code.videolan.org/videolan/vlc/-/issues, each its own
issue, once StickyGonzales says so. They describe VLC's own code only (no Cone code in them),
written for upstream readers.
- **Reports 1 and 2:** Cone carries the fix for both (PR #147, redesign/ISSUE_143_YTDLP_NOTES.md).
  A merge request with that patch can follow each.
- **Report 3:** not fixed in Cone. It is for a later release.

---

## Report 1

**Title:** ytdl: a preferred resolution plays YouTube's storyboard picture for 10 s; yt-dlp cannot start from a GUI start on Windows

**Version:** VLC 4.0.0-dev (master, November 2026). Windows 10 x64 for (b); every platform for
(a). yt-dlp stable 2026.10.26 and nightly 2026.11.14.

**(a) Any `--preferred-resolution` picks a storyboard.** `PickFormat()` / `CompareFormats()` in
`modules/demux/ytdl.c` consider every entry of yt-dlp's `formats`.
- **The storyboards count as video:** YouTube's storyboard formats (`sb0`-`sb3`, `format_note`
  "storyboard", protocol and ext `mhtml`, `vcodec` and `acodec` "none", 48x27 to 320x180,
  `abr: 0`).
- **The choice keeps the lowest fit:** among the formats at or below the preferred height,
  `CompareFormats()` keeps the lowest one (`if (h_a > h_b) return -1;`).
- **Result:** with `--preferred-resolution=240` (or 360, 720, 1080) the pick is `sb3`, a 48x27
  JPEG on i.ytimg.com. The image demux shows it for `image-duration` (10 s), then the input ends:

```
ytdl debug: redirecting to: https://i.ytimg.com/sb/<id>/storyboard3_L0/default.jpg?...
main debug: using demux module "image"
main debug: EOF reached
```

**(b) On Windows, yt-dlp cannot start when VLC has no stderr.** `ytdl_popen()` passes
`STDERR_FILENO` to `vlc_spawnp()`.
- A GUI process started from Explorer or a shortcut has no stderr handle.
- So `dup_handle_from_fd(2)` fails in `src/win32/spawn.c`, and the spawn returns an error before
  `CreateProcess` (`ytdl debug: cannot start ...yt-dlp.exe: Unknown error`).
- `src/win32/process.c` already checks `_get_osfhandle(STDERR_FILENO)` for this case.

**Steps:**
- **(a):** `vlc --preferred-resolution=240 https://www.youtube.com/watch?v=z-g2huBo9qY`, with
  stderr redirected on Windows (see b). A still for 10 s.
- **(b):** the same link from a Windows shortcut start: nothing plays.

**Proposed fix** (the format choice moved to `ytdl_formats.c`, with a unit test
`test/modules/demux/ytdl_formats.c` on saved yt-dlp format lists):
- skip formats with no audio and no video: `format_note` "storyboard", `mhtml`, or `vcodec` and
  `acodec` both "none". The rest of the choice is unchanged;
- on Windows, pass the null device as the child's stderr when `_get_osfhandle(STDERR_FILENO)`
  is -1 or -2.

**Left as it is, for discussion:**
- **Video-only formats count as having sound.** "Prefer non-mute formats" tests `!isnan(abr)`.
  yt-dlp gives video-only formats `abr: 0`, while the muxed YouTube format 18 has no `abr` at
  all. So the choice is always video-only on YouTube:
  - without a preference: itag 270, 1080p HLS, no sound;
  - with any preference: itag 269, 144p, the lowest at or below it. The inverted comparison
    above, which the storyboard hid until now.
- **Picking 18 is no fix either.** Picking the muxed 18 instead runs into report 3. Sound in HD
  needs the separate video and audio URLs played together (yt-dlp's `requested_formats`, for
  example through an input slave).

---

## Report 2

**Title:** win32: vlc_spawn() does not quote arguments, so a program path with a space gets split (ytdl-path in "Program Files")

**Version:** VLC 4.0.0-dev (master, November 2026), Windows.

**What happens:** `vlc_spawn_inner()` in `src/win32/spawn.c` builds the command line for
`CreateProcessW` by joining `argv` with plain spaces.
- **Where it breaks:** `lpApplicationName` is resolved separately, so the program starts. But
  the child splits its command line again (CommandLineToArgvW / the C start-up code), so any
  argument with a space or a `"` arrives as several arguments, or changed.
- **Example:** `--ytdl-path="C:\Program Files\yt-dlp\yt-dlp.exe"` gives yt-dlp the arguments
  `Files\yt-dlp\yt-dlp.exe --flat-playlist ...`.
  - yt-dlp takes the first piece as a URL: `ytdl error: syntax error`, then `cannot extract
    infos`, and nothing plays.
  - The same with any folder that has a space (a user name with a space, "Program Files").

**Steps:** put yt-dlp.exe in `C:\Program Files\yt-dlp\`, set "Path to YT-DLP" to it, open a
YouTube link.

**Proposed fix:**
- **Quote each argument** that is empty or contains a space, tab, new line, vertical tab or `"`.
  This follows the documented Windows rules: inside the quotes `"` becomes `\"`, and the
  backslashes in front of a `"` or of the closing quote are doubled. Other arguments are
  unchanged.
- **Where it lives:** the quoting is a small pure function (`src/win32/cmdline.c`).
- **Its unit test** (`test/src/win32/cmdline.c`) checks the expected command lines and splits
  them back with the CommandLineToArgvW rules into the original arguments.

---

## Report 3 (for a later release; not fixed)

**Title:** YouTube's progressive MP4 (itag 18) over HTTP plays far faster than real time and ends in about 30 s

**Version:** VLC 4.0.0-dev (master, November 2026), Windows 10 x64. Seen through ytdl, and also
with the format 18 URL (rr*.googlevideo.com/videoplayback?...itag=18...) opened directly.

**What happens:**
- **Too fast:** the 360p progressive MP4 (H.264 + AAC, one file over HTTPS) starts, but VLC
  plays it far faster than real time.
- **The log:** thousands of `clock gap, unexpected stream discontinuity` warnings (8506 in one
  run).
- **Then it ends:** the clock reaches the end of the film within 25-30 s and the input ends (EOF).
  Seen on a 1977 s video and on a 634 s video.
- **From disk it is fine:** the same file downloaded and played from disk plays normally.
- **Other formats are fine:** the HLS formats (video only) of the same videos play in real time.

**Steps:** `yt-dlp -g -f 18 https://www.youtube.com/watch?v=z-g2huBo9qY`, then open the printed
URL in VLC. Watch the time and the messages (verbosity 2).

**Not known yet:** whether it is the HTTP access (Google's server may serve the file in throttled
chunks or ranges), the MP4 demux's timestamps across those reads, or the clock. Worth a trace
with the HTTP access and clock debug messages. Cone does not work around it. That is why
its format choice does not prefer format 18.
