# 1.5.0 test pass, Linux and macOS side (branch wip/test-pass-1.5.0, test-only)

StickyGonzales, 2026-11-14, before the 1.5.0 release on 11/19; the PC does Windows. Nothing was fixed, nothing released.

**Code under test:** `wip/next-test` at `4f600610da`, whose code is that of the #137 merge `42269edc66` (later commits are notes only). The branch adds only Mac smoke screenshot steps and these notes.

**Builds:**
- build-linux 149: green, its own smoke 74/74 on Ubuntu 22.04 and on 24.04, plus Debian 12 and the Wayland embed;
- build-macos 33: green on Apple Silicon and Intel, with smoke.

## Summary
- **2 bugs of ours** (both Cone extras, in the Up Next code), reproduced on X11 and Wayland, platform-independent logic:
  1. **Episodes are skipped:** an episode watched to its end, played again by autoplay, starts at its last frame and ends at once, so autoplay runs through the show (**high**).
  2. **A stop turns subtitles off for the show:** stopping an episode saves "subtitles off" though nothing was picked; the next episodes start without their default subtitles (**medium**).
- **1 VLC core finding, Wayland without a GPU only:** the software video output (`wl_shm`) draws the video at its native size in the corner of the video area; the rest is see-through (**low**, to confirm on a real Wayland desktop).
- **2 low items:** the settings sidebar's controls have no position in the accessibility tree (ours); the restore question is VLC's plain dialog, and the restored queue shows one item named after the backup file until it plays (VLC's code).
- **Everything else asked for works on X11, Wayland and both Macs**, with screenshots below.

## Linux, in the sandbox (Ubuntu 24.04, build-linux 149's tarball)
- **How:** `redesign/tools/testpass/`:
  - `genmedia.py` makes the media: "Pass Show", 5 episodes of 7:00 with English and French audio and subtitles, and a sync clip with speech-like audio and subtitles 2.4 s late;
  - `tp.py` runs the tests, a fresh Cone profile per test;
  - `run-x11.sh` / `run-wayland.sh` start the sessions.
- **X11:** Xvfb, openbox, real input (xdotool).
- **Wayland:** headless Weston 13 (GL renderer, Mesa software), Cone as a native Wayland client. Headless Weston has no input device, so buttons are pressed through AT-SPI actions; the wheel and right-click cannot be tested there.
- **Playback state:** from VLC's cli on a Unix socket. Sound: VLC's dummy output.

| Test | X11 | Wayland | Details |
|---|---|---|---|
| Up Next: Play the next episode | pass | pass | card at 6:10 of 7:00 (thumbnail, S01E02, Next episode, Cancel, Turn off autoplay); E02 starts by itself after the 5 s countdown |
| Up Next: Show Up Next, I'll click | pass | pass | card "Plays when you choose", no countdown; at the end nothing plays and Cone stops (as specified, UP_NEXT_CLICK_MODE_NOTES.md); Next episode on the card starts E02 |
| Up Next: Do nothing | pass | pass | no card, nothing starts after the end |
| "Still watching?" after 3 episodes | pass | pass | E02, E03, E04 start by autoplay; at E04's countdown point the card asks "Still watching? S01E05 is paused after 3 episodes in a row"; after the end E05 waits paused (UP_NEXT_PLAN.md 2.4: the count is autoplayed episodes) |
| Popups stacking | pass | pass | an episode watched to 2:00 opened again with an update offered: the update notice sits 10 px above the resume toast, same center line, no overlap |
| Instant quit, 10 times | pass | see note | X11 Ctrl+Q: 0.22 to 0.62 s, median 0.39 s, never the watchdog. The right-click menu's "Quit Cone", 5 times: at most 0.43 s. Wayland: no keyboard or pointer under headless Weston; the cli's quit takes 0.40 s on both, also with the "..." menu open |
| Track memory | pass | pass | French audio and subtitles picked in E01: E02 starts with French audio and French subtitles ("Ligne 0 (episode 2)") |
| Auto-sync and Undo | pass | pass | subtitles 2.4 s late: "Moved -2.3 s" (log: delay -2340 ms, confidence 14.0); Undo brings back the Auto-sync button and the delay |
| Square album covers | pass | pass | square and wide covers stay square: 1280x720 491x491, 1040x570 388x388 (#129's size), 800x600 409x409, 1600x900 614x614, 640x480 327x327 (X11); default window 286x286 and 368x368 (Wayland: the window cannot be resized from outside) |
| Restore question after a killed Cone | pass | pass | a queue of 3 episodes, Cone killed (SIGKILL) 15 s later: the next start asks "Do you want to restore the playlist model from …?"; Yes restores the 3 episodes (see the low finding about how the queue looks) |
| Wheel seeking | pass | not testable | horizontal wheel (VLC's default seek axis): +7 s for 2 notches; vertical wheel with Settings > Controls > Scroll wheel = seek: up +5 s, down −3 s; the time pill shows. The vertical wheel's default (volume, VLC's default) cannot be measured with the dummy audio output |
| **Bug 1:** an episode watched to its end, autoplayed again | **fail** | **fail** | see below |
| **Bug 2:** a stop saves "subtitles off" | **fail** | **fail** | see below |

### Bug 1 (ours, Up Next, high): episodes watched to their end are skipped by autoplay
1. Fresh profile. Open `Pass Show S01E02.mkv` on its own (any show folder, files opened directly, not added to the library). Let it play to its end (or seek to 6:54 of 7:00 and let it end).
2. Open `Pass Show S01E01.mkv` with "When an episode ends: Play the next episode" and let it reach its end.
3. **Seen:** E02 starts and at once seeks to 99.98 % (log `mkv debug: seek request to 99.98%`), ends, and E03 starts within seconds. With several watched episodes, autoplay runs straight through them.
4. **Expected:** an episode watched to its end starts again at its start (or at most asks, as VLC's resume toast does).
- **Why:**
  - `modules/gui/qt/player/rd_up_next.cpp:1595` gives every autoplay item `:restore-playback-pos=2` ("always continue where you left off", no question).
  - VLC's media library keeps the position at which a file stopped. For a file opened outside the library, it keeps that position as it is (here 0.9998) instead of treating the end as finished.
  - Opened by hand, the same file only offers the resume toast ("You already watched till …").
- **Screenshot:** `test-pass-1.5.0/x11-resume-end.jpg`, `wayland-resume-end-autoplay.jpg`.
- **Not tried:** files added to the library (the media library may treat the end as finished there).

### Bug 2 (ours, track memory, medium): a stop saves "subtitles off" for the show
1. Fresh profile. Open `Pass Show S01E01.mkv`: VLC selects its default subtitle track (English). Touch no track.
2. Stop playback (the Stop entry, or the cli's `stop`).
3. **Seen:** the log says `up next: tracks for the show saved: subtitles off`. Open `Pass Show S01E02.mkv`: `tracks for the show applied: subtitles off`, and it plays without subtitles.
4. **Expected:** nothing is saved without a pick (SHOW_TRACKS_NOTES.md: "Records the pick").
- **Why:**
  - `RdUpNext::onTrackSelectionChanged` / `recordTrackChoice` (`rd_up_next.cpp` about lines 799 to 865) count any change of the selected subtitle track as a pick.
  - At a stop VLC removes the tracks, the selection becomes empty, and that is saved as "subtitles off".
  - The same line appears at the end of an episode in click mode ("Show Up Next, I'll click" ends with a stop).
- **Screenshot:** `test-pass-1.5.0/x11-track-stop-e2.jpg`.

### VLC core, Wayland without a GPU (low): the software video output is not scaled
- **Seen:** under headless Weston with Mesa's software GL, Cone's EGL video output fails ("egl: failed to create dri2 screen"), and VLC falls back to its `wl_shm` output. The picture is drawn at the video's own size (320x180) in the top-left of the video area; the rest of the video area shows the desktop through.
- **Fine elsewhere:** the picture updates normally, and under X11 it fills the area.
- **Whose:** `modules/video_output/wayland/shm.c` (VLC's, unchanged by Cone; it scales through `wp_viewporter`). Likely only on a Wayland session without GPU acceleration (a VM).
- **To confirm** on a real Wayland desktop and a VM.
- **Screenshot:** `test-pass-1.5.0/wayland-still-watching-end.jpg`, `wayland-track-memory-e2.jpg`.

### Low items
- **Accessibility (ours):** the settings sidebar's tabs, toggles, sliders and buttons (Auto-sync included) are in the AT-SPI tree but report no position or size (`(no geometry)`). Screen readers can read and press them but not locate them. The control bar's buttons have positions.
- **The restore question (VLC's code):**
  - On Linux it is VLC's plain light Qt dialog, titled "The application closed abruptly. — Cone Player" (on macOS a native-looking dialog). Its text is VLC's: "restore the playlist model from …".
  - After Yes, the queue holds one item named after the backup file (e.g. `Cone.mUiEvB`) until it plays; then it expands into the 3 episodes (`util/model_recovery_agent.hpp` appends the backup file).

### Checked and as designed (no change)
- Click mode stops at the end of the episode (UP_NEXT_CLICK_MODE_NOTES.md).
- "Still watching?" comes at episode 4's countdown point (UP_NEXT_PLAN.md 2.4, `kStillWatchingAfter`).
- The vertical wheel over the video changes the volume by default (VLC's `hotkeys-y-wheel-mode`); the horizontal wheel seeks.
- The "..." menu has no Quit; the right-click menu does (Figma "right-click menu").
- The Up Next card shows as the compact pill in a 600x420 window (Wayland's default size).

## macOS, on GitHub's runners (build-macos 33)
| Check | Apple Silicon | Intel |
|---|---|---|
| Build and .dmg | pass | pass |
| dmg opens, app copies out, ad-hoc signature, name and identifier | pass | pass |
| H.264: window, picture (colour 130), time advances, subtitle file, Settings opens, Cmd+Q 0.33 s, plug-ins load | pass | pass (colour 222, Cmd+Q 0.26 s) |
| HEVC: window, picture, time advances, quit | pass (0.20 s) | pass; quit 3.23 s (the known slow-HEVC-quit warning on this runner) |
| Finder: a file opened while Cone runs plays; a start from Finder plays the file | pass | pass |
| Settings in its own folders | pass | pass |
| Escape closes Settings | warning (known runner limit: the key does not reach the dialog) | warning (same) |

- **Screenshots (`test-pass-1.5.0/mac-*`):**
  - **Player and Settings:** `mac-<arch>-h264-start`, `mac-<arch>-h264-settings`.
  - **Music view, square and wide cover:** `mac-<arch>-music-song-square`, `mac-<arch>-music-song-wide`; the covers show as square tiles.
- **Not obtained by my screenshot step (harness, not Cone):**
  - **The Up Next card:** the Mac smoke starts Cone with `--input-repeat=50`, and a repeat option turns autoplay off by design (UP_NEXT_PLAN.md section 8), so `mac-<arch>-upnext-card` shows no card. The Up Next card itself is checked above on Linux (same code), and the Linux smoke's own Up Next check passes.
  - **The music screenshots** show the restore question in front: the step before ended Cone with a kill, and the Mac smoke, unlike the Linux one, does not clear the backup between starts.

## Screenshots (`redesign/test-pass-1.5.0/`, generated media only)
| Group | Files |
|---|---|
| X11 | `x11-upnext-card`, `x11-upnext-click-card`, `x11-upnext-click-end`, `x11-upnext-off`, `x11-still-watching`, `x11-track-memory-e2`, `x11-autosync-after`, `x11-cover-square-1040x570`, `x11-cover-wide-640x480`, `x11-popups`, `x11-rightclick-quit`, `x11-restore-question`, `x11-wheel-seek`, `x11-resume-end`, `x11-track-stop-e2` |
| Wayland | `wayland-upnext-click-card`, `wayland-still-watching-end`, `wayland-track-memory-e2`, `wayland-autosync-after`, `wayland-cover-song-square-default`, `wayland-popups-two`, `wayland-restore-question`, `wayland-resume-end-autoplay` |
| macOS | `mac-arm64-*`, `mac-x86_64-*` |
