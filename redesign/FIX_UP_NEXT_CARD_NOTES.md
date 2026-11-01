# Up Next card: two LOW fixes from the #87 retest (branch wip/fix-up-next-card)

Branch `wip/fix-up-next-card`, made from `origin/wip/next-test` (with #87 merged). Draft pull request into `wip/next-test`. Cone extra (Decision 71), Cone build only. Interface only: `modules/gui/qt/player/qml/RdUpNextCard.qml`, `modules/gui/qt/player/rd_up_next.cpp`.

## 1. "Turn off autoplay" did not react to the screen reader's activate action
**Seen (PC session, build-windows #161):** a mouse click works; UI Automation's Invoke (Narrator, keyboard-less accessibility) does nothing.

**Cause:** the link was a bare `T.AbstractButton` with the role `Link` and no press action. Cone's other buttons (`RdButton`, `TextToolButton`, ...) answer the activate action with `Accessible.onPressAction: control.clicked()`; this one had none.

**Fix:**
- role **Button** (the card's other two are buttons too), with a description ("Turns off Play episodes in a row");
- `Accessible.onPressAction` presses it as a click does (UIA Invoke on Windows, AT-SPI "press" on Linux);
- keyboard: Tab reaches it after Cancel (unchanged); **Space** presses it (AbstractButton), and now **Enter / Return** as well.
- Its look is unchanged (the underlined link text).

## 2. The card showed the wrong or an empty episode name as the next episode started
**Seen:** for about 0.6 s as the next episode starts, the card shows the episode after it ("S01E03. Playing in 1 seconds") or an empty name ("Strong Show, . Plays when you choose") before it hides.

**Cause (found with a 20 fps screen recording in the Linux sandbox, build-linux #63):** the card did not just keep its old text while fading: it came back at full opacity for the new episode, with the episode after it ("S01E03, Playing in 1 s"; "Episode 3" for weak names), and only then faded.
- After the input changes, the player keeps reporting the previous episode's time until the new episode sends its first position.
- RdUpNext checked the card right away with that time (about 9:59 of 10:00): for the new episode it is inside the credits window, so the card of its next episode showed until the real time (0:00) arrived.
- The same stale time was also recorded as the new episode's "last position" (used for learning the credits point).

**Fix:**
- **No stale time:** after an input change, RdUpNext ignores the player's time until it differs from the previous episode's last time (the new episode's first position). Until then the card stays hidden and nothing is recorded for learning.
- **Frozen texts:** what the card shows (mode, show name, episode line, seconds, countdown line, thumbnail, season, waiting/counting, autoplays) is held while it fades out, so the fade itself never shows a changed episode. Shown, or fully hidden, the card follows RdUpNext as before (its next showing and the compact-pill width check use current values).
- **Hide first:** Next episode / Play now hides the card before it queues the next episode (weak names queue it only on that click).

## Checks
- `qmlcheck.py`: errors 1 (the known HighResolutionTimeWidget stub), crashed 0; `buildlists.py`: 0 problems; `privacycheck.py`: 0 problems.

## Runs
| Run | Head | Result |
|---|---|---|
| build-windows #162, build-linux #63 | 6f2ffad23b (button, frozen texts) | green; the recording showed the card coming back with the episode after it (the real cause) |
| build-windows #165, build-linux #65 | 16085f3c6c (no stale time) | green; one frame of "Plays at the end of the episode" at full opacity before the fade |
| **build-windows #167, build-linux #70** | **2ab12be858** (hide before the countdown stops) | **green, smoke included** |

**Linux sandbox on build-linux #70** (Xvfb, AT-SPI, 10-minute generated episodes):
| Check | Result |
|---|---|
| invoke: "Turn off autoplay" is a push button with a Press action; the activate action hides the card, logs "autoplay turned off from the card", no countdown afterwards | 5 of 5 |
| keyboard: Tab reaches "Turn off autoplay" (11 presses from the video), Return turns autoplay off and hides the card | 4 of 4 |
| strong names, countdown end, 20 fps recording | the card keeps "S01E02, Playing in 1 s" through its fade; S01E02 starts; no other text at any frame |
| weak names, Next episode, 20 fps recording | the card keeps "Episode 2, Plays when you choose" through its fade; Weak Show 02 starts |

Picture: `redesign/fix-shots/up_next_card_hide.jpg` (the frames around the fade, both cases). The Windows-only part (UI Automation's Invoke and Narrator) is retest step 1 below.

## Windows retest (PC session)
Build: build-windows #167 (or `gh workflow run build-windows.yml --ref wip/fix-up-next-card`). A show folder with 3+ strong episodes (`Show S01E01.mkv` …) and one with 4 weak ones (`Show 01.mkv` …), each over 10 minutes; Play episodes in a row On.
1. **Invoke.** Seek to 1 min before the end of S01E01: the card shows. With Accessibility Insights (or Narrator: move to "Turn off autoplay", Caps Lock+Enter), invoke **Turn off autoplay**: the card goes, nothing plays at the end, Settings > Playback > Episodes > Play episodes in a row is Off. Turn it On again.
2. **Keyboard.** Card up again: Tab to Next episode, Tab to Cancel, Tab to Turn off autoplay (its text lights up): **Enter** turns it off. Again with **Space**.
3. **Inspect.** Accessibility Insights shows "Turn off autoplay" as a **Button** with the Invoke pattern.
4. **Strong names, countdown end.** Let S01E01 count down to the end (record the screen, or watch closely): the card fades with "S01E02" and its last number, never "S01E03" or an empty name; S01E02 starts.
5. **Play now.** In S01E02's countdown, click Play now: the same, the card fades with "S01E03".
6. **Weak names.** In `Show 01`, 1 min before the end, click Next episode: the card fades with "Episode 2" and "Plays when you choose", never an empty name; Show 02 starts.
7. **Cancel / Escape** still hide the card as before; the card comes back on the next episode's credits.
