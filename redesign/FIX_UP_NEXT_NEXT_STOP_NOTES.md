# Up Next: "Next episode" stopped the next episode at once (branch wip/up-next-card-click-fill)

Cone extra (Up Next). PC test of #101, 2026-11-08, also in the released 1.2.0, high priority.

## Report
A click on the card's **Next episode** (or its thumbnail) started the next episode, which stopped at once, and Cone showed the home page. Letting the countdown run out played it fine.

## What was checked
| Check | Result |
|---|---|
| Linux sandbox (build-linux #92, a 3-episode show of 55 min) | Next episode at 54:15: S01E02 starts and is still playing 22 s later. Not reproduced. |
| Windows runner (build-windows #198, branch `wip/diag-up-next-next`: the new smoke check, no fix) | 1 -> 2, still playing 5 s later. Not reproduced. The runner has no hardware decoding and an empty media library. |
| Click-path code | `RdUpNext::playNow()`: the card hides, the episode is marked watched, `PlaylistController::next()`. No stop and no player-view change in it. |
| Everything that can send Cone to the home page | `MainInterface.qml` leaves the player when the player reports STOPPED; the home page (`MainDisplay.qml`) then stops playback, because a video cannot play on without picture-in-picture. Others (Back, the library toggle without a media library, the 2-finger swipe) need input the click does not give. |

## The likely cause
When **Next** is pressed during playback, VLC's playlist gives the player the next file as its *next media*. The current file stops first (`vlc_player_SetCurrentMedia`). Once it has stopped, the player opens that next media.

**Any queue change in between** (an add, a remove, a move) makes the playlist hand the player a new next media (`vlc_playlist_UpdateNextMedia`). That is the file *after* the current index, or nothing at the end of the queue. It replaces the chosen episode. The player then has nothing to open and stops (STOPPED), so Cone goes to the home page, and the home page's start stops playback.

The window for this is the time the old episode takes to stop. On Windows with hardware decoding it is far longer than on the runners, which is why only the PC sees it. The countdown path ends the episode naturally: no pending next media can be replaced.

## The fix
1. **No queue change while the player switches (`RdUpNext::switchGuarded`):** after Next episode, Up Next makes no queue change until the player is on the next episode, for at most 3 s. It neither removes nor adds an autoplay item.
2. **Safety net:** if the episode Next episode chose stops within 3 s of the click while it is the current queue item, it is started again. The log says "the next episode stopped right after Next episode; starting it again".
3. **The player is left only for a stop that lasts:** `MainInterface.qml` leaves the player view only when the player is still stopped 500 ms later. A brief stop between two files no longer loads the home page, which would stop playback.

## Smoke check (new, Windows and Linux)
"upnext: the card's Next episode keeps the next episode playing" uses a generated show of three 7-minute episodes (`smoke-media.sh`). It seeks to 6:10, clicks the card's Next episode, and checks 5 s later that the next episode is current and still playing (`is_playing`, time advancing).

## If it still happens on the PC
Turn on Settings > General > "Save a log", reproduce it and send the log. These "up next:" lines tell the paths apart:
- "Next episode, moving on to the autoplay item";
- "queue left as it is while the player switches";
- "starting it again".
