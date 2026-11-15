# Up Next: finished episodes are not skipped; a stop saves no track choice (branch wip/fix-upnext-resume-tracks)

StickyGonzales, 2026-11-15, for the 1.5.0 release on 11/19. Draft pull request into `wip/next-test`.

**Scope:** the two bugs of ours that the 1.5.0 test pass found (`redesign/TEST_PASS_1.5.0_LINUX_MAC.md` on wip/test-pass-1.5.0, bugs 1 and 2). Both are in the Up Next code, a Cone extra: `modules/gui/qt/player/rd_up_next.*`, interface only.

## 1. Autoplay skipped episodes already watched to their end
- **Bug:**
  - Up Next gave every autoplayed episode `:restore-playback-pos=2` ("always continue where you left off", no question).
  - VLC's media library keeps the position at which a file stopped. A file opened outside the library and watched to its end keeps a position of about 99.98 %.
  - So that episode, played again by autoplay, began at its last frame, ended at once, and autoplay went on to the next one. With several watched episodes it ran through the show.
- **Fix:** when Up Next knows the next episode, it reads that episode's saved position and length from the media library, in the background (`RdUpNext::requestNextProgress`).
  - **Already watched:** an episode 95 % or more in, or with no more left than where the Up Next card appears (the "Show Up Next" setting, 1 minute by default: the credits), counts as watched, as on Netflix. Its autoplay item gets `:restore-playback-pos=0` and it starts from the beginning.
  - **Partway:** an episode stopped partway still resumes at its spot without the question, as before.
  - **"Continue where you left off: Never"** stays as it is.
  - **Timing:** the answer arrives in the background. An autoplay item queued before it is queued again with the new option (`refreshQueued`), and the read happens again for every new file (the episode may have been watched since).
- **Log:** `up next: the next episode was watched to its end (99.9 %): it starts from the beginning`.

## 2. A stop saved "subtitles off" for the show
- **Bug:** track memory saved any change of the selected subtitle (or audio) track as the user's pick. A stop, the end of an episode, a quit or a switch to another file empties the track lists, and that empty selection was saved as "subtitles off". The next episodes then started without their default subtitles.
- **Fix:** a change counts as a pick only when all of these hold (`RdUpNext::recordTrackChoice`):
  - **the same file:** it was seen on the file that still plays (Up Next's input generation);
  - **the player is going:** playing or paused, not stopping or stopped;
  - **the same list:** the track list holds the same tracks, and is not empty; only the selection changed. A list that changed (emptied by a stop or a quit, or a subtitle file added) only becomes the new reference.
- **Still a pick:** a track chosen in the tracks popup, with the V / B keys or through the cli; subtitles turned off by the user (the same list, nothing selected).

## Smoke checks (Linux and Windows)
| Check | Linux (`linux-smoke.py`) | Windows (`win64-smoke.ps1`) | What it does |
|---|---|---|---|
| Up Next starts an episode watched to its end from the beginning | `check_upnext_watched` | `Check-UpNextWatched` | Smoke Show S01E02 played to its end and quit; then S01E01 to its end: S01E02 must play and be under 60 s 4 s later (not skipped to S01E03) |
| A stop saves no track choice for the show | `check_track_stop` | `Check-TrackStop` | Smoke Show S01E01 with the external subtitle file selected, nothing picked, stopped and quit: no `tracks for the show saved` line in its log |

- **On the old code**, both fail (build-linux 149's tarball in the sandbox, the two checks on their own):
  - "S01E02, watched to its end, was skipped: S01E03 plays already";
  - "a stop saved a track choice nobody picked: qt debug: up next: tracks for the show saved: subtitles off".
- **Linux:** each check uses a fresh profile.
- **Windows:** the checks run on the portable zip's profile, after the other Up Next check. They play S01E02 to its end first, so the earlier checks cannot change the result, and the track check reads only its own session's log.

## Windows retest (the PC)
Build from this branch, portable zip. Use a show folder with episodes named `S01E01`, `S01E02`, `S01E03` (or the smoke media's "Smoke Show"), and episodes with a subtitle track that plays by default (or an `.srt` next to each episode).

1. **A finished episode is not skipped.**
   - **Do:** open S01E02 on its own, seek near its end (the last 10 s) and let it end. Then open S01E01 and seek near its end with "When an episode ends: Play the next episode".
   - **Expect:** S01E02 starts at 0:00 and keeps playing. Before the fix, it flashed and S01E03 started.
2. **A half-watched episode still resumes.**
   - **Do:** open S01E03, watch to about half, quit with Ctrl+Q. Open S01E02 and let it reach its end.
   - **Expect:** S01E03 starts where you left it, without the "You already watched till …" question.
3. **A stop does not turn subtitles off.**
   - **Do:** open S01E01 (its subtitles show), press Stop, open S01E02.
   - **Expect:** S01E02 shows its subtitles. Before the fix, it started without them.
4. **A real pick is still remembered.**
   - **Do:** in S01E01 open the subtitles popup and choose Off (or another language). Let S01E01 end so S01E02 plays.
   - **Expect:** S01E02 starts with subtitles off (or in that language). The same goes for an audio language.
5. **Quit and file switch.**
   - **Do:** in S01E01 with subtitles on, quit with Ctrl+Q; start again on S01E02. Then open another file while S01E02 plays, and come back to the show.
   - **Expect:** subtitles stay on in the show.

## Runs
| Run | Head | Result |
|---|---|---|
| build-windows 263 | f97cb675dd | green with smoke: "upnext-watched" pass (S01E02 at 6 s, 4 s after it began), "track-stop" pass (nothing saved) |
| build-linux 150 | f97cb675dd | green with smoke on Ubuntu 22.04 and 24.04 (both new checks pass: S01E02 at 4 s; nothing saved), Debian 12 and the Wayland embed |
| build-macos 34 | f97cb675dd | green on Apple Silicon and Intel with smoke (16 checks pass on each); only the known runner warnings: Escape in Settings (both), a slow HEVC quit on Intel (3.41 s) |
