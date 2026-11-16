# Up Next: automatic or click-to-play (branch wip/up-next-click-mode)

Cone extra (Decision 71). Approved by StickyGonzales on 2026-11-13 from the mockup Q10 (the decisions folder,
`Q10-up-next-autoplay-choice.png`). Built by the PC session at StickyGonzales's request.

## 1. What changes
- **Settings > Playback > Episodes:** the switch "Play episodes in a row" becomes the dropdown **"When an episode
  ends"**:
  - **Play the next episode** (default): today's On. The card counts down on the Next episode button, then the
    next episode plays.
  - **Show Up Next, I'll click:** the card appears at the same point, without a countdown, and waits for a click
    ("Plays when you choose"). Nothing is added to the queue until the click. Countdown and "Ask if I'm still
    watching after 3 episodes" are hidden (`shown: false`, so the Settings search still works).
  - **Do nothing:** today's Off. No card; the rows under it wait at 30 %, as before.
- **The card's "Turn off autoplay"** now switches to "Show Up Next, I'll click" instead of turning everything off:
  the countdown goes and the card comes back as the waiting one. It only shows on a card that counts down.
- **Weak names** (plain numbers, "Part 2", "Episode 2") wait for a click in every mode, as before.

## 2. How (no new paths)
- `player/rd_up_next_mode.hpp`: the three modes, the saved value to mode (`modeFromOption`), which episodes play by
  themselves (`autoplays`) and the link (`afterTurnOff`). No Qt, no VLC; `tests/test_rd_up_next_mode.cpp`.
- `RdUpNext::autoplays()` asks it. Click mode therefore takes the path weak names have always taken: no autoplay
  item, the card waits, Next episode queues and plays.
- `qt-autoplay-next` is an integer with a list (1, 3, 0). A saved switch keeps its meaning (On = 1, Off = 0), an
  old pre-1.0 "Always" (2) reads as Play the next episode, click mode is 3 (a value the option never had). Profiles
  saved with the old bool are written back by type (true = 1, false = 0).
- Unchanged: the per-show toggle in the sidebar, the guards of the conflict matrix (repeat one, shuffle, stop or
  pause at the end, a user-built queue), Show Up Next (when the card appears), track memory.

## 3. Windows test (PC session)
1. **Default:** a fresh profile: Settings > Playback > Episodes shows "When an episode ends: Play the next episode",
   Countdown, Show Up Next, "Ask if I'm still watching". An episode (S01E01 of a 3-episode folder) near its end: the
   card counts down and E02 plays.
2. **Click mode:** choose "Show Up Next, I'll click": Countdown and "still watching" disappear. The same episode: the
   card shows "Plays when you choose" with no fill and no "Turn off autoplay"; at the end of E01 nothing plays and
   Cone stops as today; Next episode on the card plays E02.
3. **Do nothing:** no card; the rows under it are dimmed.
4. **The link:** back to Play the next episode; on the counting card press "Turn off autoplay": the countdown stops,
   the card comes back waiting, and Settings shows "Show Up Next, I'll click".
5. **Saved settings carry over:** a profile whose vlcrc has `qt-autoplay-next=0` shows Do nothing; `=1` shows Play the
   next episode; `=2` plays on.
6. **Search:** Settings search "countdown" in click mode shows nothing hidden by mistake (the row stays hidden), in
   Play the next episode mode it finds the row.
7. **Regression:** weak names (Demo Show Episode 1) still wait for a click with Play the next episode; still watching
   after 3 episodes in Play the next episode mode; quit stays fast.

## 4. PC test (2026-11-13, build-windows 43463372294 on 79bf187d597, green with smoke; build-linux 43463378029 and unit-tests 43463387286 green, test_rd_up_next_mode 17 checks)
- **Default (Play the next episode):** a fresh profile shows "When an episode ends: Play the next episode" with Countdown, Show Up Next and "Ask if I'm still watching". Strong Show S01E01 at 2:55: the card counts down with "Turn off autoplay"; S01E02 plays by itself.
- **Show Up Next, I'll click:** Countdown and "still watching" are hidden. The card shows "Plays when you choose", no fill, no link; after the end nothing plays (only S01E01 in the log). Next episode on the card plays S01E02.
- **Do nothing:** no card, nothing plays; the rows under it are dimmed.
- **The link:** on the counting card "Turn off autoplay" turns it into the waiting card at once; nothing plays at the end; saved `qt-autoplay-next=3`.
- **Saved values:** `0` shows Do nothing, `3` click mode, the old `2` reads as Play the next episode and is saved back as the default `1`.
- **Search:** "countdown" in click mode finds no row (the hidden one stays hidden).
- **The dropdown:** it lists the three choices with a tick on the current one; choosing Play the next episode brings Countdown back and saves `1`.
- **Weak names** (Weak Show Episode 1) with Play the next episode: the waiting card, nothing plays, as before.
- **Independent review:** 3 findings fixed in 79bf187d597 (an old saved 2 is saved back as 1 so the dropdown never shows "2"; a change to a mode without autoplay drops "Still watching?" and the countdown; the page reads unknown values like RdUpNext).