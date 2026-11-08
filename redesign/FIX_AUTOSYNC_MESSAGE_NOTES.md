# Auto-sync shows "Moved -2.3 s" in the on-screen message (#106 follow-up)

Branch `wip/fix-autosync-message`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone build only (Cone's on-screen message exists only there, `RdOsd.active`); interface only (`modules/gui/qt`), no core change.

## 1. The bug
Reported by StickyGonzales at the Windows retest of PR #106 (STATUS.md, 2026-11-08). Auto-sync on a film with its .srt 2.4 s late set the delay to -2.340 s, but the on-screen message box showed VLC's **"Subtitle delay -2340 ms"**. The auto-sync notes promise the result **"Moved -2.3 s"**.

**Reference** (Cone extra, CLAUDE.md "User reports and issues"): `redesign/SUBTITLE_AUTO_SYNC_NOTES.md`, sections 1 and the retest steps: the result reads "Moved -2.4 s" (the move, signed, one decimal). So this is a bug: Cone does not match its reference.

**Cause:** Auto-sync sets the delay through the player (`vlc_player_SetSubtitleDelay`). The core then posts its own message "Subtitle delay: -2340 ms" (`src/player/player.c`), which Cone's on-screen message (PR #104, `RdOsd`) shows. Auto-sync itself only wrote its result to the sidebar's accessible text, and, for a download, to a notification that the core's message then replaced.

## 2. The fix
- **`RdSubSync`** (`player/rd_sub_sync.cpp`): after a move it emits `synced(label, value, delayMs, notice)`:
  - label "Auto-sync" (a click on the sidebar's button) or "Subtitles auto-synced" (a download from OpenSubtitles);
  - value: the move with its sign and one decimal, "Moved -2.3 s", or "Moved +0.1 s · fps fixed" when the frame rate was corrected too;
  - the new delay in ms, and the notification line for builds without Cone's message.
- **`RdOsd`** (`player/rd_osd.cpp`): `showSubtitleSync()` shows that message (subtitles icon, label, value) and drops the core's "Subtitle delay" message for exactly that delay, once, if it arrives within 1.5 s. The core hands it over synchronously while the delay is set and the interface receives it queued, so it always arrives after this.
  - Any other message, a later delay change by the user (another value, or after 1.5 s), and "Subtitle delay" messages of other changes still show as before.
- **The parser** (`player/rd_osd_parse.cpp`) marks a subtitle delay message and keeps its value in ms; unit test `test_rd_osd_parse` has two new checks (39 of 39).
- **`Player.qml`**: connects `RdSubSync.synced` to the message (or, without Cone's message, to the notification for a download as before).
- **Unchanged:** "Already in sync", "No match found" and the reasons still show on the sidebar's row and, for a download, as the notification.
- **Undo** shows **"Auto-sync  Undone"** in place of the core's "Subtitle delay 0 ms" (follow-up branch `wip/autosync-undo-message`, StickyGonzales 2026-11-08: `RdSubSync::undo()` emits the same `synced()` with "Undone" and the delay it puts back).

## 3. Checks
- `test_rd_osd_parse`: 39 of 39 (compiled and run against Qt 6 in the sandbox).
- `rd_osd.cpp`: compiles with `-Wall -Wextra`, no warnings.
- qmlcheck: errors 1 (the known stub limit), crashed 0. buildlists: 0 problems. privacycheck: 0 problems.

## 4. Runs
| Run | Result |
|---|---|
| build-linux #99 (42435721439), 87098e9 | green, every Linux smoke check passes |
| build-windows #203 (42435723820), 87098e9 | green, every Windows smoke check passes |
| build-linux #100 (42477594969), f3a0f1a (Undo follow-up, PR #110) | green, every Linux smoke check passes |
| build-windows #204 (42477597600), f3a0f1a (Undo follow-up, PR #110) | green, every Windows smoke check passes |

**Sandbox, build-linux #99's tarball** (Xvfb, 150 %; a generated 60 s test pattern MKV with an in-sync embedded English subtitle track, and the same lines in an external .srt 2.34 s late; picture `redesign/fix-shots/autosync_message.jpg`):
- Sync to "Track 1 - [English]", Auto-sync: log "subtitle sync: match, delay -2320 ms"; the message reads **"Auto-sync  Moved -2.3 s"** with the subtitles icon; screenshots every 0.5 s show no "Subtitle delay" message after it; the delay box -2.320 s, the button Undo.
- H right after: "Subtitle delay  -2270 ms  [H]", as before.
- Undo: "Subtitle delay  0 ms", the delay back to 0.000 s (this build, before the Undo follow-up).

## 5. Windows retest (PC session)
Use this branch's build-windows zip (portable). The same media as PR #106's retest: a film with its .srt shifted 2.4 s late.
1. **Auto-sync.** Play it, open the sidebar > Subtitles, click Auto-sync. When it is done, the message at the top center reads **"Auto-sync  Moved -2.3 s"** (or -2.4 s, the move it found) with the subtitles icon; no "Subtitle delay -2340 ms" message appears, also not a moment later. The delay box shows -2.340 s.
2. **A key after it.** Right after, press H / G (subtitle delay keys): the message shows "Subtitle delay" with the new value as usual.
3. **Undo.** Click Undo: the message shows **"Auto-sync  Undone"** (no "Subtitle delay 0 ms" after it) and the delay is back to 0.000 s. A key (H) right after shows "Subtitle delay" as usual.
4. **Auto-sync again** (Already in sync): no message box; the sidebar row says "Already in sync".
5. **Download (optional, needs the OpenSubtitles key).** With "Auto-sync downloaded subtitles" on, download subtitles that are out of sync: the message reads "Subtitles auto-synced  Moved ..." and no "Subtitle delay" message follows.
