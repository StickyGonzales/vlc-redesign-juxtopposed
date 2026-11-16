# Draft: VideoLAN bug report and fix (not posted)

Ready to paste into a new issue (and a merge request with the patch of wip/fix-ytdl-formats) at
https://code.videolan.org/videolan/vlc/-/issues once StickyGonzales says so. It describes VLC's
own code only (no Cone code in it), written for upstream readers. Cone carries the fix
(redesign/ISSUE_143_YTDLP_NOTES.md).

---

**Title:** ytdl: YouTube plays a 10 s storyboard still, or silent video; yt-dlp cannot start from a GUI start on Windows

**Version:** VLC 4.0.0-dev (master, November 2026), Windows 10 x64 (for 3) and every platform
(for 1 and 2); yt-dlp stable 2026.10.26 and nightly 2026.11.14.

**1. Any `--preferred-resolution` picks a storyboard.** `CompareFormats()` in
`modules/demux/ytdl.c` keeps, among the formats at or below the preferred height, the lowest
one (`if (h_a > h_b) return -1;`), and YouTube's storyboard formats (`sb0`-`sb3`,
`format_note` "storyboard", protocol `mhtml`, `vcodec` and `acodec` "none", 48x27 to 320x180)
count as video. With `--preferred-resolution=240` (or 360, 720, 1080) the pick is `sb3`, a 48x27
JPEG on i.ytimg.com; the image demux shows it for `image-duration` (10 s) and the input ends:

```
ytdl debug: redirecting to: https://i.ytimg.com/sb/<id>/storyboard3_L0/default.jpg?...
main debug: using demux module "image"
main debug: EOF reached
```

**2. Without a preferred resolution the pick is silent.** "Prefer non-mute formats" tests
`!isnan(abr)`: yt-dlp gives video-only formats `abr: 0`, while the one muxed YouTube format
(`18`, 360p, AAC) has no `abr` at all. So the pick is a video-only format (itag 270, 1080p HLS):
picture, no audio track.

**3. On Windows, yt-dlp cannot start when VLC has no stderr.** `ytdl_popen()` passes
`STDERR_FILENO` to `vlc_spawnp()`. A GUI process started from Explorer or a shortcut has no
stderr handle, so `dup_handle_from_fd(2)` fails in `src/win32/spawn.c` and the spawn returns an
error before `CreateProcess` (`ytdl debug: cannot start ...yt-dlp.exe: Unknown error`).
`src/win32/process.c` already checks `_get_osfhandle(STDERR_FILENO)` for this case.

**Steps:** `vlc --preferred-resolution=240 https://www.youtube.com/watch?v=z-g2huBo9qY` (with
stderr redirected on Windows, see 3): the still for 10 s. Without the option: video, no sound.
From a shortcut on Windows: nothing plays.

**Proposed fix** (patch attached; format choice moved to `ytdl_formats.c` with a unit test
`test/modules/demux/ytdl_formats.c` on saved yt-dlp format lists):
- skip formats with no audio and no video (storyboards: `format_note` "storyboard", `mhtml`,
  or `vcodec` and `acodec` both "none");
- read audio and video from `acodec` / `vcodec` ("none" = absent), with `height` and `abr > 0`
  only as a fallback when an extractor gives no codec names;
- prefer formats with both, then unknown, then audio only, then video only; within a kind the
  highest height at or below the preferred one (else the lowest above it; the highest without a
  preference), then the highest `tbr` / `abr`;
- on Windows pass the null device as the child's stderr when `_get_osfhandle(STDERR_FILENO)`
  is -1 or -2.

**Limit (not in this fix):** YouTube muxes video and audio only at 360p (18), so YouTube plays at
360p with sound. Higher qualities need the separate video and audio URLs played together
(yt-dlp's `requested_formats`, e.g. through an input slave); worth discussing separately.
