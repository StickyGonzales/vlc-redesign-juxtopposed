# Storage cleanup and the background queue

Branch `wip/storage-cleanup`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-12. Cone's own data only (`modules/gui/qt`); nothing in VLC's core.

## 1. What Cone keeps per show and movie

| What | Where | Before | Now |
|---|---|---|---|
| A show's autoplay answer, credits point, track choice, credits scans | `rd-shows.json` | kept forever, by folder path | moved with the show (fingerprint); forgotten when the folder is gone 14 days, or its drive 1 year |
| Subtitle links (file and folder rules) | `rd-subtitles.json` | kept forever | moved with the show or movie; forgotten with it; links to deleted downloads removed |
| Up Next pictures | cache `up-next/*.png` | never deleted | named after their video and moved with it; deleted with the show, after 90 days of a drive gone, by Forget all; at most 300 |
| Waveforms | `waveforms/*.wf` | at most 2,000 | moved with the video; deleted with the show or after 90 days of a drive gone |
| Downloaded OpenSubtitles files | `subtitles/opensubtitles/` | never deleted | never selected: deleted when their video closes; unused for 30 days: deleted; at most 1,000; Forget all deletes them |
| The fingerprints, volumes and the registry of Cone's files | `rd-storage.json` (new) | | one small JSON file |

## 2. The rules
All rules are in `util/rd_storage_model.*`, which is pure QtCore and unit-tested. `util/rd_storage.*` applies them inside Cone.

1. **Fingerprints.**
   - Every show (its root folder) and movie (its file) Cone plays gets a fingerprint: the name and exact size of each episode, or of the movie file.
   - It also gets its volume ID.
   - **Matching:** when Cone detects a show or movie it has no data for, it compares the fingerprint with the saved entries, including entries whose folder is missing.
     - A show matches with at least **2 episodes** of the same name and exact size.
     - A movie matches by its file's name and size.
     - When several match, a missing one wins, then the most episodes in common.
   - **On a match:**
     - its data moves to the new place: Up Next's answer, credits and track choice, the credits scans, and the subtitle links and folder rules;
     - the pictures and waveforms are renamed for the new path.
     - This covers a rename, a move, and a copy to another drive.
2. **Deleted folders.**
   - **When:** at most once a day, and only for drives Cone read this session.
   - **The check:** each saved folder or movie file is looked at.
   - **Volume there, path gone:** marked missing. Still missing and not matched **14 days** later, everything tied to it is deleted:
     - the pictures, waveforms and downloaded subtitles of its videos;
     - the saved entry (Up Next's data);
     - its subtitle links.
   - **Volume not there:** that is, another volume at the drive letter, an empty mount folder, or a network share that does not answer within 2 s. This is "disconnected", never "missing".
   - **How drives are told apart:** by volume ID.
     - Windows: the volume GUID, else the serial number; a network share by its UNC name.
     - Linux: the filesystem UUID.
     - macOS: the volume UUID.
     - Never by drive letter or mount folder.
3. **Drives that never come back.**
   - Each volume's last connection is recorded (any day Cone read from it), and each show's last play.
   - **90 days** with the drive not connected and the show not played: its pictures and waveforms are deleted. Cone makes them again if the show comes back.
   - **1 year:** the saved entry and its subtitle links go too.
4. **Downloaded subtitles.**
   - **When a video closes:** its downloads that were never selected are deleted. A file the user selected (its track was selected at any time) stays.
   - **30 days unused:** deleted, wherever the video is. Selecting a file counts as a use.
5. **Caps (oldest first):** 300 Up Next pictures and 1,000 downloads. They are checked when a picture or a download is written, and by the daily check.
6. **Forget all** (Settings > Playback > Episodes): also deletes the Up Next pictures and the downloaded subtitles, and removes the subtitle links to them.
7. **Light:**
   - It only runs inside Cone while it is open: no service and no scheduled task.
   - The daily check waits on Windows' battery saver, like the credits scans.
   - The first check comes 65 s after the start, then the clock is looked at every hour.
   - Quitting stops it at once.
   - **Never wakes a drive:**
     - Only paths on the volumes Cone read this session are touched: the system drive (the home folder and Cone's data folder), and every drive a played file is on.
     - Other drives wait until they are used.
     - Every check that touches a drive gives up after 2 s.
8. **Entries from before the fingerprints:**
   - **Import:** Up Next's remembered shows are imported by their folder, with the answer's date as their last play when there is one, otherwise the date of the first start of this version.
   - **When the show plays:** its fingerprint and volume are recorded.
   - **Until then:**
     - If its folder is found on a drive Cone read this session, its volume is recorded. From then on the 14-day rule applies.
     - Otherwise only the 90-day and 1-year rules apply, counted from its last play.
   - **Older downloads:** files already in the downloads folder are registered with their video (from the subtitle links) and their last change as their last use.

## 3. The background queue
`util/rd_background_queue.*`, QtCore only, unit-tested.
- **What runs in it:** show detection with the fingerprint, credits scans, the credits subtitle read, waveforms, Up Next pictures, the update check, the storage load, save, cleanup and deletions.
- **One job at a time, at the lowest thread priority.**
  - A long job that can pause (a credits scan, a waveform) pauses when a more urgent one comes, such as show detection when a new episode starts.
  - It goes on afterwards. Nothing ever runs beside it.
- **Nothing heavy in the first minute** after Cone opens. "Heavy" means credits scans, waveforms, pictures and the cleanup.
  - Light jobs may run early: the update check (one small request), show detection (one folder listing, which the track choice of the first file needs), the storage load.
- **Paused** while the seek bar is hovered or dragged, during a seek (also a key's jump in time, at the playback's rate) and while a file opens (until it plays, at most 8 s). A running long job waits at its next packet. Only an urgent light job starts while paused: show detection for the file opening, so its saved tracks are applied before it plays.
- **Async jobs** (the update check, an Up Next picture) hold the slot against jobs of their priority or lower; a more urgent one (show detection) does not wait for their answer.
- **On quit:** every job is cancelled at once (the scanners' VLC interrupt), and the queue joins its threads before the interface goes.
- **Each job's own rules stay:** credits scans wait on battery saver; the update check keeps its retries.
- **Debug log:** `background: start <job> (#n)`, `background: end <job> (#n, <ms> ms)`, `paused (<reason>)`, `resumed`, `<job> pauses for <job>`, `goes on`.
- **Not in the queue:** what the user asks for and waits on: the seek bar's preview frames, the filter previews, an auto-sync the user started. These stay as they were.

## 4. Code
| File | Change |
|---|---|
| `util/rd_background_queue.*` (new) | The queue |
| `util/rd_storage_model.*` (new) | The rules: entries, fingerprints, matching, presence (`presenceOf`), the daily check, closing a video, caps, Forget all |
| `util/rd_storage.*` (new) | Applies the rules: `rd-storage.json`, the session's volumes, the daily check, deletions (only inside Cone's three folders), renames, selection of downloads (the track ID's MD5 of the file's address) |
| `util/rd_volume.*` (new) | Volume IDs and file checks with a timeout |
| `maininterface/mainui.cpp` | The queue (created first, so it goes first) and the storage. The queue's pauses come from the player's signals (opening, seeking). |
| `player/rd_up_next.*` | Show detection with the fingerprint, credits subtitles and pictures go through the queue. It also relocates and forgets on request, imports the old shows, and Forget all clears the pictures and downloads. |
| `player/rd_credits_scans.*`, `rd_credits_scanner.*` | Scans through the queue; its pause gate replaces the seek bar flag; relocate and forget a show |
| `player/rd_waveform*.*` | Through the queue, with the pause gate; the cache file name is shared with the storage |
| `util/rd_update_check.*` | The request is an async job of the queue (light, early) |
| `dialogs/redesign/addsubtitles/*` | Downloads registered; relocate, forget and unlink in the subtitle store |
| `tests/test_rd_storage_model.cpp`, `tests/test_rd_background_queue.cpp` (new), `.github/scripts/unit-tests.sh`, `.github/workflows/unit-tests.yml` (new) | Unit tests, and a workflow that runs all of Cone's QtCore tests |

## 5. Unit tests
`.github/scripts/unit-tests.sh` (CI: `unit-tests.yml`) builds and runs all of Cone's QtCore-only tests.
- **test_rd_storage_model, 52 checks:**
  - a renamed show folder (the entry, picture and waveform follow);
  - a show moved to another drive (2 of 3 episodes; 1 is not enough; a folder inside the show is not a move);
  - a renamed movie folder, and another size not matching;
  - a drive back under another letter (no drive or another volume at the old letter is not "missing"; the show at the new letter matches);
  - an empty mount folder (disconnected, kept 20 days; mounted with the folder gone: missing);
  - a slow network share (never missing);
  - a deleted show (missing from the first check, kept 13.9 days, forgotten at 14 days with its picture, waveform, download and link; another show "Show 2" untouched; one moved within 14 days kept);
  - a drive gone 89 / 90 days (pictures and waveforms; a subtitle used on day 80 stays) and a year (forgotten); counted from the last play; a legacy entry by its last play; a legacy entry seen on a read drive records its volume;
  - downloaded subtitles: the unselected one of a closed video goes, the selected one stays; 29 / 30 days unused; a use on day 20 keeps it;
  - the caps (300 / 1,000);
  - Forget all (pictures and downloads, not waveforms; shows forgotten, movies kept);
  - JSON round trip.
- **test_rd_background_queue, 28 checks:**
  - 30 jobs (pausable and not, urgent ones arriving while others run): never two at once, also by the queue's own count;
  - priority order;
  - the first-minute rule (a light job at once, a heavy one after the period);
  - a hold pauses a running job and starts nothing;
  - a hold that ends by itself;
  - a long job pausing for an urgent one;
  - an async request holding the slot, and its timeout;
  - a dropped waiting job's `done` runs;
  - show detection runs during a hold, other jobs wait;
  - shutdown at once, also with a paused job, and nothing after it;
  - the log lines.
- **Proved to fail when broken:**
  - The model with the "volume at the folder above" test removed and 13 days for 14: 8 failures.
  - The queue with its one-at-a-time rule disabled: 6 failures.
- Locally (Qt 6.4): all 7 test programs pass. The existing ones: show tracks 33, episode parser 514, credits audio 17, credits point 106, on-screen message parser 39.

## 6. Independent review
A fresh subagent reviewed the whole diff. Confirmed and fixed:
1. **A waiting credits scan that was cancelled** (Up Next off, Forget all) left the scans stopped for the rest of the session.
   - Its owner is now told it is over.
   - New test: a dropped waiting job's `done` runs, and the job never runs.
2. **The opening hold delayed show detection until the file played**, so the saved tracks switched audibly after the start.
   - Urgent light jobs now run during a hold.
   - Async jobs no longer block more urgent ones.
   - New test.
3. **A save could be lost on quit** when its job was still waiting. The last changes are now written on quit unless the save went through.
4. **Linux and macOS: `/` (the system drive) counted every path as "read this session"**, so legacy entries on other drives were looked at.
   - Fix: a path's mount point now comes from the mount table, with no access to the drive, and must be one of the session's.
5. **"credits subtitles" was light**, so it ran in the first minute. It is now heavy.
6. **Pause race:** a job resumed and paused again before it woke left the next job waiting. The queue now checks again.
7. **Async jobs' finish held raw pointers into the queue.** The queue's counters are now shared.
8. **A renamed picture or waveform whose new name existed** left the old file behind. The old file is now deleted.
9. **Fast playback (5× and more) and resuming after a pause** looked like seeks. The check now uses the playback rate and only counts while playing.
10. **Includes in mainui.cpp** are moved outside a Qt 6.9-only block.

Also taken from its "plausible" list:
- **Nested folders:** a show's root seen one folder lower (`Show/Season 1`) is never matched as a move. New test.
- **Older downloads:** files from before this version start their 30 days now, so a season downloaded long ago is not all deleted (and downloaded again) on the first check.
- **Startup order:** the storage is read before the first show is detected.
- **No disk access on the UI thread** when the credits data moves.
- **A mapped network drive with no UNC name known** gets its serial number, never its letter.

CI fix: `QStringBuilder` (on in VLC's build) needs an explicit `QString` before a `QJsonValue` (build-windows #237 and build-linux #125 stopped there).

## 7. Limits
- **"Last connected"** means the last day Cone read from the drive (a played file on it), not the last time it was plugged in. Cone never looks at drives it does not use.
- **A movie whose file was renamed** (not just its folder) is not matched: a name and size are the fingerprint, and a size alone could match another file.
- **Subtitle links of movies that never play again** after this version stay; they are a few hundred bytes each. Shows are imported from Up Next's store.
- **Network shares on Windows** are told apart by their UNC name. The same share mapped to another letter is the same volume.
- **macOS:** the volume UUID comes from `getattrlist`, else the device; not built on this branch (macOS builds run on `wip/macos-build`).

## 8. Runs
| Run | Result |
|---|---|
| unit-tests #1 (6149afd) | green |
| build-windows #237, build-linux #125 (6149afd) | compile error (`QStringBuilder` into a `QJsonValue`), fixed |
| unit-tests #2 (43283737270), b0d1950 | **green**: storage model 52, queue 28, and the 5 older test programs |
| build-windows #238 (43283746401), b0d1950 | **green**, every smoke check (show detection, credits, waveforms, the Up Next card and the update check now go through the queue) |
| build-linux #126 (43283754480), b0d1950 | **green**, every smoke check (Ubuntu 24.04 and 22.04, Debian 12, Wayland / X11 embed) |

## 9. Windows retest (PC session)
Build: build-windows on `wip/storage-cleanup`, Cone portable. In Settings, turn on "Save a log" (or start with `--file-logging --log-verbose=2`).

The data files are in `portable\Cone\`: `rd-storage.json`, `rd-shows.json`, `rd-subtitles.json`, `waveforms\`, `subtitles\opensubtitles\`; the pictures are in the cache folder's `up-next\`.

1. **The queue.**
   - Start Cone with an episode of a show (a few seasons). In the log:
     - `background: start show detection` then `end` within the first seconds;
     - no `credits scan`, `waveform` or `up next picture` before 60 s;
     - after 60 s they come, one at a time: each `start` follows the previous `end`, except `pauses for` / `goes on`.
   - Drag or hover the seek bar during a credits scan: `background: paused (seek bar)`, then `resumed`.
   - Quit during a scan: Cone ends at once, and the log shows `end credits scan (... cancelled)`.
2. **Renamed show.**
   - Play an episode of a show and pick an English audio track (track choice). Watch to the last minute so the Up Next card and its picture show. Quit.
   - Rename the show's folder in Explorer and start an episode from the renamed folder.
   - In the log: `storage: <old> found again at <new> (N files in common)` and `up next: ... found again`.
   - The English audio track is applied, the Up Next answer and the credits point are the same, and the card's picture shows at once (no new picture job).
3. **Moved to another drive.** Copy the show to a USB drive or another partition and play it from there: the same as step 2.
4. **Drive under another letter.**
   - Note the USB drive's letter, then give it another one (Disk Management > Change Drive Letter).
   - Play the show from the new letter: its data follows.
   - Before playing it, the daily check must not mark the old path missing. In `rd-storage.json` the entry has no `missing`.
5. **Deleted show (14 days).**
   - Delete a played show's folder.
   - To test without waiting: quit Cone, and in `rd-storage.json` set `lastDaily` to 0. Start Cone and wait 70 s: the entry gets `missing`.
   - Quit, set `missing` and `lastDaily` 15 days back (milliseconds), start and wait 70 s. The log shows `daily check: ... forgotten: <folder>`, and its pictures, waveforms, downloads and links are gone.
6. **Downloaded subtitles.**
   - With an OpenSubtitles key, download 3 subtitles for one video in Add Subtitles, select one in the tracks popup, then open another file.
   - The 2 never selected are deleted from `subtitles\opensubtitles\`; the selected one stays.
7. **Forget all:** Settings > Playback > Episodes > Remembered shows > Forget all. `up-next\` and `subtitles\opensubtitles\` are empty afterwards.
8. **Battery saver:** turn on Windows' battery saver and set `lastDaily` to 0. The log shows `storage: the daily check waits (battery saver)`.
9. **Regression:**
   - Up Next card, autoplay, credits point, track memory, waveform seek bar, seek previews.
   - Add Subtitles (file and folder, OpenSubtitles auto-download for the next episode).
   - The update notice (forced with `CONE_UPDATE_CHECK_TEST_FILE`).
   - Quit stays fast.
