# Up Next: the card when the credits start, no start prompt (branch wip/up-next-credits)

Branch `wip/up-next-credits`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone extra (Decision 71, part of Autoplay next episode), Cone build only (Up Next is off in the vlc profile). Interface only: `modules/gui/qt` and `redesign/UP_NEXT_PLAN.md` (the decisions are its sections 2.3 and 5.4). Both decisions of the first part were confirmed by StickyGonzales on 2026-11-01: the new Show Up Next setting replaces the old one, and Forget all also clears the learned credits points.

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

## Part 2: no start prompt, strong and weak names (UP_NEXT_PLAN.md 2.3)
1. **No "Looks like a show. Play episodes in a row?" prompt** at the start of episodes, like Netflix.
   - The setting Settings > Playback > Episodes > **Play episodes in a row** is On / Off, default On; "Ask for each show" is gone.
   - `qt-autoplay-next` becomes a bool. `RdShowPrompt.qml` and the prompt code are removed.
2. **Strong names autoplay** (S01E02, 1x02, "Season 1 Episode 2"): the countdown runs at the end, as before.
   **Weak names** (01 02 03, "Part 2", "Episode 2", "E02"):
   - no autoplay item;
   - the card shows Next episode and Cancel with "Plays when you choose", never a countdown;
   - nothing plays unless the user clicks.
3. **"Turn off autoplay"**, a small link on the card, switches the setting off: the card goes and the autoplay item leaves the queue.
   - Decision (Claude): the full card only. The compact pill (narrow windows) leaves it out, since a wider pill would hide in more windows.
4. **Migration:**
   - a saved Off (0) stays off;
   - Ask (1) reads as On;
   - Always (2) falls back to the default On;
   - a folder answered No to the old prompt, or turned off in the sidebar, keeps autoplay off (its "no" in `rd-shows.json`).
5. **Season folders share a show:** the show root is the parent of the season folders, so Season 2 uses the credits point learned in Season 1.
6. **Seeking back** before the credits point hides the card; it comes back when playback reaches the point again, unless Cancel was pressed. **Pausing** pauses the countdown, which follows the playback time.

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
| Run | Head | Result |
|---|---|---|
| build-windows #160 | first part | failed: `char[]` to `QByteArrayView` in rd_up_next.cpp (Qt 6.8 only; the local Qt 6.4 accepted it), fixed in 5fd8617721 |
| build-windows #161 (41315444738) | 5fd8617721 | green, Windows smoke included |
| build-linux #62 (41315441762) | 5fd8617721 | green, Linux smoke included |
| unit test `test_rd_credits_point` | 5fd8617721 | 69 of 69 |

**Sandbox (Linux build #62, Xvfb, 14 cases, 51 of 51 checks pass):**

| Case | Checks | What it shows |
|---|---|---|
| chap | 4/4 | card at an "End Credits" chapter; an "Ending" chapter mid-episode ignored |
| learn | 7/7 | Next mid-episode never learned; a press in the window learned (lead 72988 ms), a later one updated it (76980 ms) |
| subs | 2/2 | SRT in `Subs/` with ♪ and "Subtitles by" lines: point 520000 ms "(setting, tuned by the subtitles)" |
| embedded | 2/2 | the same subtitles inside an MKV |
| post | 5/5 | post-credits scene: card without a countdown, countdown only in the last seconds |
| plain | 7/7 | no chapters, no subtitles: card at the 1 min setting, none earlier |
| noprompt | 1/1 | no start prompt |
| weak | 5/5 | `Show 01 02 …`: "Episode 2. Plays when you choose", no countdown, nothing plays |
| turnoff | 5/5 | "Turn off autoplay": card gone, setting Off, logged |
| answeredno | 3/3 | a folder answered No before stays off |
| vlcrc0 / vlcrc2 | 1/1, 1/1 | old Off stays off; old Always reads as On |
| seasons | 2/2 | Season 2 uses the point learned in Season 1 |
| seek | 6/6 | seek back hides the card, forward brings it back, Cancel keeps it away; pause stops the countdown |

Picture: `redesign/fix-shots/up_next_credits_card.jpg` (left: the credits-phase card with subtitles; right: the weak-name card).

## Windows retest (PC session)
Build: `gh workflow run build-windows.yml --ref wip/up-next-credits`. Test with a show folder of 3+ episodes (`Show S01E01.mkv` …), with Settings > Playback > Episodes > Play episodes in a row **On** (the default). With "Log to file" on, the log lines above show where each point came from.
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
9. **No start prompt.** A fresh portable Cone, a show episode: no "Looks like a show" question at the start, in the first minute or later. Settings > Playback > Episodes shows "Play episodes in a row" as a toggle, On.
10. **Strong vs weak.**
    - `Show S01E01.mkv` … autoplays at the end with the 10 s countdown.
    - A folder of `Show 01.mkv`, `Show 02.mkv` … (each over 10 minutes): the card shows near the end with Next episode and "Plays when you choose", no countdown, and nothing plays at the end. Next episode plays 02.
11. **Turn off autoplay.** On the card, click "Turn off autoplay": the card goes, nothing plays at the end, and the setting is Off. Turn it on again in Settings.
12. **Migration.** Before installing this build, set the old setting to Off in 1.1.x: it stays off after the update. A folder answered No to the old prompt in 1.1.x stays off; another folder autoplays.
13. **Seasons.** `Show/Season 1/…S01E01` and `Show/Season 2/…S02E01`. Press Next during the credits of S01E01 (1 min 15 s before the end), then open S02E01: its card comes 1 min 15 s before the end.
14. **Seek and pause.** With the card up, seek back to the middle: it goes; seek forward past the point: it comes back. After Cancel it stays away. Pause during the countdown: the number stands still and goes on when playing again.
