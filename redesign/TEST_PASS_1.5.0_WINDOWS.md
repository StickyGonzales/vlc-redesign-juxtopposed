# 1.5.0 test pass, Windows side (PC session, 2026-11-15)

One full pass of the wip/next-test Windows build with #126, #127, #128, #131, #134, #135, #136, #137 and
#139 together. The Linux and macOS side is in redesign/TEST_PASS_1.5.0_LINUX_MAC.md (web session).

**Build.** build-windows #261 (29f417f9ee0, wip/next-test after the #139 merge; build and Windows smoke
green). For comparisons: the vlc profile build of wip/next-test (build-windows #262, f8316e2f564) and
stock VLC 4 from Phase 1 (run 38315049322).

**Profiles**, both in test folders, never StickyGonzales's real profile:
- **Fresh:** a new portable profile, update check on (so the update notice shows), the OpenSubtitles test key.
- **Upgrade:** a verified copy of StickyGonzales's 1.4.0 settings (vlcrc, Qt settings, presets, shows, media
  library, Up Next pictures) plus the OpenSubtitles test key. On its first start: no onboarding, the green
  accent and the library kept, the update notice shown.

**Media.**
- Generated: "Pass Show" S01E01-E05 (130 s each: Cone counts files of 120 s or more as episodes), each
  with English and German audio and English and French subtitles.
- From the CI smoke media: the square and wide album covers, the 1080p episodes of #139.
- Open movies: Tears of Steel with its subtitles moved 5 s late, Sintel and Big Buck Bunny.

## Results

| Check | Fresh | Upgrade | Notes |
|---|---|---|---|
| Up Next "Play the next episode" | pass | pass | Countdown card, the next episode plays by itself (but see bug 1) |
| Up Next "Show Up Next, I'll click" | pass | pass | "Plays when you choose", Next episode and Cancel, no countdown; nothing plays at the end |
| Up Next "Do nothing" | pass | pass | No card; Home at the end |
| "Still watching?" after 3 episodes | pass | pass | Five episodes at 2x (`--rate=2`, no input): the card shows at the end of E04, after 3 episodes started by autoplay; E05 loads paused under it; Keep watching plays it |
| Popups stacking | pass | pass | The resume prompt sits above the control bar, the update notice above it, both centred, 10 px apart. In a window and maximized. The profile notice was not shown (no profile switch in this pass) |
| Instant quit, 10 times | pass | pass | Window gone in 55-185 ms, process ended in 0.36-0.6 s, every time; no crash records |
| Track memory | pass | pass | German audio and French subtitles picked in one episode; the next one starts with "audio deu (track 2), subtitles fra (track 2)" |
| Auto-sync and Undo | pass | pass | Subtitles 5 s late: Auto-sync sets -4.940 s in about 4 s; Undo puts back 0.000 s |
| OpenSubtitles download | pass | pass | Search, Save, the file is downloaded and loaded (see note 3) |
| Square album covers | pass | pass | 388x388 at 1041x570 and 408x408 at 1500x600, square and wide cover |
| Thumbnails in Recent | pass | pass | Every new card has its thumbnail (see item 2 for the order) |
| The restore question after a killed Cone | pass | pass | "The application closed abruptly ... restore the playlist?"; Yes restores the queue |
| Volume keys maximized | pass | pass | Up / Down and the wheel over the video change the volume (140 -> 145 -> 140 %) with only the volume message; Ctrl+Up shows the bars |
| Wheel seeking | pass | pass | 10 s per notch on the timeline (paused: 2:29 -> 2:49 -> 2:39); nothing elsewhere on the bar |
| #137: a start with a file, Cone closed | pass | pass | Explorer's command (`--started-from-file`): the window in 1.0-1.4 s, the file plays |
| #137: Open with while playing | pass | pass | The file goes to the same window; one Cone |
| #137: a file dropped on the window | pass | pass | Intermittent drops: item 5 |
| #137: a start from the shortcut, no file | pass | pass | Home |
| A video dropped on Home right after another ended | see item 5 | see item 5 | Not tied to the end of a video |

## Failures and findings

1. **BUG, ours (high): autoplay skips an episode watched to its end.** Also found on Linux
   (TEST_PASS_1.5.0_LINUX_MAC.md). Present since Up Next (2026-10-25), so in 1.4.0 too: not a regression
   of this round.
   - **Steps:**
     1. Watch S01E03 and S01E04 of a show to the end.
     2. Later, play S01E02 and let it end in "Play the next episode" mode.
   - **What happens:** the card says "Up next: S01E03, playing in 1 s". S01E03 and S01E04 open and are
     skipped within about 2 s each, and S01E05 plays.
   - **Why:**
     - The autoplay item gets `:restore-playback-pos=2` (rd_up_next.cpp, itemOptions), so it always
       resumes at the saved spot.
     - For these files the media library saves 0.999 when an episode ends ("last_position", duration -1,
       play_count 0), so the resume jumps to the end. Seen in the log: `mkv debug: seek request to 99.90%`.
     - The resume prompt already ignores a spot in the last 20 s (ResumeDialog.qml, `_watchedToEnd`); the
       autoplay path does not.
2. **NEEDS A REFERENCE CHECK: Recent lists the oldest first.** On both profiles the Recent page shows the
   media in play order, oldest at the top. The videos just played are at the bottom of the list.
   - RdLibraryPage.qml's Recent model (MLRecentMediaModel) sets no sort order; the media library's history
     query then gives the oldest first.
   - The usual meaning of "Recent" is newest first. Bug or as designed depends on the Figma Recent frame
     and the video (not checked in this pass).
3. **NEEDS A REFERENCE CHECK: OpenSubtitles pre-ticks the first result.**
   - In Add Subtitles > From OpenSubtitles the first result is ticked when the list opens. Clicking it
     unticks it, so Save then downloads nothing.
   - Ticking another result downloads both. Sintel: the Hebrew file came along with the English one, and
     the Hebrew one ended up showing.
   - Check against the Figma Add Subtitles frames.
4. **Cosmetic, origin to check: a downloaded subtitle's track name.**
   - The file "67399-Sintel (2010).eng.srt" is listed as "67399-Sintel (2010 [English]".
   - The closing parenthesis is lost and the OpenSubtitles id stays in front.
5. **VLC, not ours: a dropped file does not always play.**
   - **The pattern:** a video dropped on the window sometimes does nothing. The drag source reports the
     drop accepted ("Copy"), but no input is created. It is not tied to a video having just ended, to the
     cards, or to the update notice.
   - **Comparison:** the same six drops in a row (drop, play, stop, drop again), run back to back:
     - stock VLC 4: 5 of 6 played;
     - the vlc profile build: 5 of 6;
     - Cone: 4 of 6.
     Other runs ranged from 1 of 5 (vlc profile) to 6 of 6 (Cone fresh window).
   - **Conclusion:** stock VLC 4 misses too, so it is not a Cone change. The drop code is upstream's
     (MainInterface.qml DropArea). The test uses a synthetic OLE drag, so the drag timing may play a part.
6. **Small, ours: the update notice can cover a subtitle line.** Maximized with the bars hidden, the update
   notice (above the control bar's place) overlaps the bottom subtitle line.

## Harness notes (not Cone)

- Two test Cones were open at once in one run: a screenshot then showed the other window (Home). A Ctrl+Q
  went to the wrong one. Cone itself quit at once every time.
- A pointer moved to the spot where it already was does not count as movement, so the bars stay hidden;
  the script now wiggles the pointer first.
- ffmpeg cannot write a USLT lyrics frame (it writes a TXXX tag named "USLT"); the lyrics test files were
  made with a small script instead (#136 retest).
