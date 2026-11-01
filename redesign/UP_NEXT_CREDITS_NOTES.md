# Up Next card when the credits start (branch wip/up-next-credits)

Branch `wip/up-next-credits`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone extra (Decision 71, part of Autoplay next episode), Cone build only (Up Next is off in the vlc profile). Interface only: `modules/gui/qt` and `redesign/UP_NEXT_PLAN.md` (the decision is its section 5.4).

## What changed
Before, the card showed in the last seconds only (10 s by default). On a 56-minute episode with 2 minutes of credits it never showed while the credits rolled.

**Hard rule.** The card can only appear inside the credits window: the last 8 minutes, or the last 15 % of an episode shorter than about 53 minutes, whichever is shorter. Any signal pointing earlier is ignored, so the card never shows in the middle of an episode.

**Inside the window, in this order:**
1. **Chapters.** A chapter whose name contains "credits", "end credits", "outro" or "ending", or is "ED", and that starts inside the window. "Pre-/mid-/post-credits" scenes don't count.
2. **Learned per show.** Going on to the next episode inside the credits window of an earlier one (Next, the card, the queue), before the countdown, teaches the point. One press is enough, and a later one updates it.
   - Never learned: a press outside the window (skipping mid-way), a Play now during the countdown, Previous, or another episode picked in the library.
   - Stored in `rd-shows.json` ("credits"). Settings > Playback > Episodes > Forget all clears it.
3. **The setting** Settings > Playback > Episodes > **Show Up Next**: Last 30 s / Last 1 min / Last 2 min, default 1 min.
   - New option `qt-autoplay-credits-lead`. It replaces `qt-autoplay-card-point` ("At the end / When the credits start"); chapters are now always used.
   - A user who had chosen "When the credits start" gets the 1 min default.

**Subtitles, a helper only.**
- **Which:** an external SRT/ASS/SSA/VTT, or an embedded text track (SubRip, ASS, tx3g).
- **What it does:** the end of the last real dialogue line in the window, before a gap of 60 s or more or before only music lines (♪, #), moves the point from 2 or 3 by at most 2 minutes. It is never the only reason, and never moves the point out of the window.
- **Skipped:** lines like "subtitles by", "synced by", "translated by", "downloaded from" and web addresses. Picture subtitles (PGS, VobSub) are never read, and nothing reads the picture.
- **When:** the embedded track is read in the background, 2 minutes before the window, and only the window part of the file.

**The card during the credits:** "Up next", the episode, **Next episode** and **Cancel**, and "Plays at the end of the episode".
- No countdown yet: it still only runs in the last seconds, so a post-credits scene is never skipped by itself.
- Cancel hides the card for the rest of the episode (and takes the autoplay item out, as before).

**Files:**
- `player/rd_credits_point.*`: the decision, QtCore only, unit tested by `tests/test_rd_credits_point.cpp` (69 checks).
- `player/rd_credits_subtitles.*`: the subtitle scan.
- `player/rd_up_next.*`: the integration.
- `player/qml/RdUpNextCard.qml`: the credits phase.
- The option in `qt.cpp`, the settings row, the catalog and profile lists, and both build lists.

The log says where the point comes from: `up next: credits point <ms> of <length> (chapter|learned|setting[, tuned by the subtitles])`, `up next: subtitles for the credits: ...`, `up next: credits point learned for the show: ...`.

## Review
An independent review of the first commit found 8 points:
- **Fixed in the second commit:**
  - learning from the countdown or the natural end;
  - learning from Previous or another episode;
  - Forget all unavailable in Always mode;
  - the embedded scan reading at the start of the episode and from unseekable files;
  - pre-/mid-/post-credits chapter names, and "ED";
  - a mode change dropping the subtitle scan.
- **Left as is:** smoothing several learns (one press is enough, as decided) and caching the chapter list (cheap).

## Runs
Builds and sandbox tests running (filled in when done).

## Windows retest (PC session)
Build: `gh workflow run build-windows.yml --ref wip/up-next-credits`. Test with a show folder of 3+ episodes (`Show S01E01.mkv` …), with Settings > Playback > Episodes > Autoplay next episode set to **Always** (or answer Yes). With "Log to file" on, the log lines above show where each point came from.
1. **No chapters, no subtitles.** Seek to the middle: no card. Seek to 2 minutes before the end: no card. At 1 minute before the end the card shows "Up next … Next episode / Cancel" and "Plays at the end of the episode", without a countdown; in the last 10 s it counts down as before.
2. **Setting.** Show Up Next = Last 2 min: the card comes at 2 minutes before the end; Last 30 s: at 30 s.
3. **Credits chapter.** An episode with an "End Credits" chapter in its last minutes: the card at that chapter. A chapter named "Ending" in the middle of the episode: no card there.
4. **Learning.**
   - In E01, press Next in the middle: nothing is learned, and E02 shows no card in the middle.
   - In E02, press Next 1 min 30 s before the end, during the credits. In E03 the card comes 1 min 30 s before the end.
   - Press Next in E03 2 min before the end. In E04 the card comes 2 min before the end.
   - Settings > Playback > Episodes > Forget all, then E05: back to the 1 min setting.
5. **Subtitles.** An episode with an SRT whose dialogue ends 1 min 40 s before the end, followed by "♪" lines and a "Subtitles by …" line: the card at the end of the dialogue (not at 1 min). The same with the subtitles inside an MKV.
6. **Post-credits scene.** The card shows at the credits and stays without a countdown during the scene after them; the scene plays to its last 10 s.
7. **Cancel / Next episode.** Cancel hides the card for the rest of the episode, with no countdown at the end. Next episode starts the next episode at once.
8. **A 56-minute episode with 2 minutes of credits** (the report): the card while the credits roll.
