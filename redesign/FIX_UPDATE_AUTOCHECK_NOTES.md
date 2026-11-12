# The update notice checks by itself again (1.4.0)

Branch `wip/fix-update-autocheck`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-11. Windows and Linux (the same code); macOS has no update notice.

## 1. The bug
- **The report:** a laptop on 1.1.2 never showed the notice for a new release on start. It was 30+ hours after the last check, on a new day. "Check now" found the release at once.
- **The cause** (`util/rd_update_check.cpp`, `startupCheck()`):
  - About 4 s after the start, the check wrote `CheckedOn = today` before the request went out.
  - When the request failed (Wi-Fi not up yet after waking the laptop, a stalled DNS lookup), `onReply()` stayed silent, which is right for an automatic check.
  - But the day already counted as checked, and there was no second try, so every later start that day skipped the request.
  - A laptop that is started once a day and is offline in its first seconds never saw the notice.

## 2. The fix
- **Only an answer counts:** `AnsweredAt` (UTC, ISO 8601, in `[RdUpdateCheck]` of `vlc-qt-interface.ini`) is written only when GitHub answered:
  - a release was read (newer or not), or
  - "no release yet" (404, or a Linux list without a Linux release).
  - A failed request writes nothing. The old `CheckedOn` is removed.
- **Every start** asks when the last answer is more than **6 hours** old, or when there is none.
- **Retries in the session:** a failed automatic check is tried again after **1, 5 and 15 minutes**, then not before the next start.
  - An answer (the automatic one or "Check now") ends the retries.
  - A retry stops if the option was turned off meanwhile.
  - An automatic check that joins a running "Check now" (or the reverse) keeps its retries when the shared request fails (found by the independent review).
  - Each step is in the log ("update check: no answer, trying again in 60 s").
- **Unchanged:**
  - "Later" (the day), "Skip this version", and "Check now" (asks at once and reports a failure).
  - Nothing goes out before the first-run question or with the option off.
- **The test hook** (`CONE_UPDATE_CHECK_TEST_FILE`, redesign/UPDATE_SKIP_NOTES.md section 3):
  - A missing file counts as a failed request. With the variable set, the retries are ten times shorter (6 s, 30 s, 90 s), so "offline at the start, then online" takes a minute.
  - Unset (normal use), the delays are 1, 5 and 15 minutes.

## 3. Windows retest (PC)
- **Setup:**
  - The build from this branch in its portable folder.
  - A manual build is Cone 0.1.0, so any 1.x answer is newer.
  - The settings file is `portable\Cone\vlc-qt-interface.ini`, group `[RdUpdateCheck]`.
  - "Log" means Tools > Messages (or `--file-logging --logfile=...`, verbose 2).
- **Answer file:** `<WORK_DIR>\answer.json` contains `{"tag_name": "v1.4.0", "html_url": "https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.4.0"}`.
- **Start Cone** in PowerShell: `$env:CONE_UPDATE_CHECK_TEST_FILE = '<WORK_DIR>\answer.json'; & '<build>\Cone.exe'`.
- **Before each step,** remove `AnsweredAt`, `DismissedOn` and `LatestVersion` from `[RdUpdateCheck]` (unless the step says otherwise).

1. **Offline at the start, then online.**
   - Rename `answer.json` to `answer.off` and start Cone.
   - About 4 s later: no notice. The log has "update check: no answer, trying again in 6 s", and the ini has no `AnsweredAt`.
   - Rename it back to `answer.json` within about 30 s: at the next retry the notice "Cone Player 1.4.0 is available" shows, and the ini has `AnsweredAt=` with the current UTC time.
2. **Every retry fails.**
   - Start with the file missing and leave it missing.
   - The log shows retries after 6 s, 30 s and 90 s, then "not tried again before the next start". No notice, nothing written.
   - Add the file and start again: the notice shows about 4 s after the start (a failed day does not block).
3. **Checked yesterday, new release today.**
   - Set `AnsweredAt=` to yesterday's date with any time (for example `2026-11-10T09:00:00Z`) and start with the answer file.
   - The notice shows about 4 s after the start.
4. **Answered less than 6 hours ago.**
   - Right after step 3, close Cone, remove only `DismissedOn`, and start again.
   - No request: the log has "GitHub answered N min ago, no request".
   - The notice still shows from the stored `LatestVersion`, without a request.
5. **More than 6 hours ago, same day.**
   - Set `AnsweredAt` to 7 hours before the current UTC time and start: the log has "answer read from … (test)".
6. **Check now still works.**
   - With the file missing: Settings > General > Check now says the check failed.
   - With the file present: it shows the notice, and the ini gets `AnsweredAt`.
7. **Real network (no variable).**
   - Unset the variable (`Remove-Item Env:CONE_UPDATE_CHECK_TEST_FILE`), remove `AnsweredAt`, and start Cone online.
   - The ini gets `AnsweredAt` within a few seconds: the release is newer than 0.1.0, so the notice shows.
