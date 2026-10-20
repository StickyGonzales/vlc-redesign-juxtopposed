# Autoplay next episode ("Up Next"): plan and design (step 1 of 2)

> **Cone extra (not part of Juxtopposed's design), Decision 71.** This feature is in neither her video nor her Figma file. It is not part of beta 2 or 1.0: it is built on its own branch and merged only after 1.0 is released, for 1.1. It is listed under "Cone extras (not part of Juxtopposed's design)" in the README and in the release notes.

Design and plan only, no feature code. Branch `wip/up-next-plan` (from `wip/next-test`), docs and design images only.

Designs: `redesign/up-next-design/` (index in section 9). Not in her Figma file, so everything is built from Cone's own Figma tokens, components and panel look (Decision 21 style).

---

## 0. Summary

| | |
|---|---|
| **What** | When an episode of a show ends, Cone offers the next one with an "Up next" card and a short countdown, like Netflix. |
| **Why** | Her video, 9:24-9:28 (P5-01, row 150): an episode ends and the next one does not play because the folder was not queued. Her fix (P5-20 to P5-23, 11:24-11:47; drag to the queue W5.9) is manual: the show's folder in the top bar opens the compact library next to the video, and you drag the next episode into the queue. |
| **How it fits her design** | It complements that design and replaces nothing. The compact library, "Unwatched First" (P5-13, 10:45) and the per-show presets (P4-04 / IA-34, 7:53) stay exactly as they are. The library marks the next episode, the queue shows it, and the folder preset follows it. |
| **Setting** | Settings > Playback > Episodes > "Autoplay next episode": **Off / Ask for each show (default) / Always**. Off = Cone behaves exactly as today. |
| **Per show** | Remembered per show folder. "Ask" asks once with a small prompt; a No is never asked again. The sidebar Playback tab has an on/off toggle for the show playing (under Sleep Timer). |
| **Recommended card** | Variant A (panel card, 400 wide), `01`/`02`/`05` images. |
| **Core changes** | None expected; everything fits in `modules/gui/qt` (section 6.6). |
| **Open decisions** | 9 items marked **needs Sticky**, collected in section 10. |
| **Release** | Cone extra (Decision 71): not in beta 2 or 1.0; built on its own branch, merged after 1.0 is released, for 1.1. |

---

## 1. What Cone does today when one file is opened on its own and ends

**It stops. Nothing in VLC 4 or Cone continues with the other files of the folder.**

- Every open path appends to the queue and starts the first new item (`PlaylistController::append`, `modules/gui/qt/playlist/playlist_controller.cpp:445-470`). A file opened on its own is therefore the last item in the queue.
- At the end of a media the playlist hands the player the next queue item, or none (`vlc_playlist_UpdateNextMedia`, `src/playlist/control.c:431-455`). With no next item the player stops.
- On stop, Cone leaves the player and shows the library Home (`MainInterface.qml:252-258`, upstream). That is exactly her 9:24 problem.
- There is no "play the rest of the folder" option anywhere. A grep for sibling/autoload/"same folder" in `src/` and the Qt code finds nothing; the only folder option is `mkv-preload-local-dir`, which is about MKV segments.

| How the file was opened | Queue afterwards | When it ends |
|---|---|---|
| Open File(s) (Ctrl+O, "..." menu), the Open dialog | the picked file(s) appended | stops after the last one |
| Explorer double-click / command line | the argument(s) | stops |
| Second instance (one-instance mode, Windows) | appended to the running queue | stops (unless items follow) |
| Drag and drop on the window | appended (a single file dropped while playing is tried as a subtitle first) | stops |
| Library: Play / click on one file | only that file (comment "11:44 only the clicked file joins the queue", `RdLibraryActions.qml:55-73`) | stops |
| Library: Play on a folder, playlist or album; Open Folder | the whole container | plays all of it in order, then stops |
| Repeat All on | as above | wraps to the oldest queue item |

---

## 2. Behaviour

### 2.1 The three modes

| Mode | First episode of a show Cone has not seen | A show answered "Yes" | A show answered "No" |
|---|---|---|---|
| **Off** | nothing | nothing | nothing |
| **Ask for each show** (default) | the "Looks like a show" prompt (section 2.3) | autoplay | nothing, never asked again |
| **Always** | autoplay, no prompt (stored as "Yes") | autoplay | nothing |

- A per-folder "No" wins over "Always": the sidebar toggle switched off for a show keeps it off under every mode.
- The sidebar toggle writes the same per-folder answer as the prompt.
- Off is a hard switch: the scanner does not run, and there is no card, no tag and no sidebar row. Cone behaves byte for byte as today.

### 2.2 Timeline of one episode (autoplay on for this show)

1. **The episode starts.** On a worker thread Cone checks whether the file is an episode of a show (section 3). If it is, it works out the next episode and appends it to the queue as an **autoplay item** (section 4.2). The Next button now opens episode 2, the queue shows it, and the library tags it "Up next".
2. **The Up Next point.** The card appears at one of two points:
   - **"At the end of the episode"** (default): the last *countdown* seconds before the end.
   - **"When the credits start"**: at the start of a chapter named Credits / End Credits / Ending / ED / Outro, falling back to the end when there is none.
3. **The countdown** (5 / 10 / 15 s, default 10) runs in wall-clock seconds.
   - It pauses while the player is paused.
   - It runs at real speed when the playback speed is not 1x.
4. **At 0, or on Play now,** the next episode starts:
   - At 0 in "end" mode this is the normal end-of-file move to the next queue item, so no frame is skipped.
   - In "credits" mode, or on Play now, Cone calls `next()` and marks the episode watched in the library (it may not have reached the library's own "watched" threshold).
5. **Cancel** closes the card and removes the autoplay item from the queue. The episode ends as it does today (stop, back to Home). Cancel only affects this episode.
6. **Seeking:**
   - Seeking back before the Up Next point hides the card; it comes back when the point is reached again.
   - Seeking into the last seconds shows it with the time that is left.

### 2.3 The "Looks like a show" prompt (mode "Ask")

- **Wording:** "Looks like a show. Play episodes in a row?" with **Yes** (primary) and **No**. A second line, "&lt;Show&gt; · you can change this in the Playback tab", names the show.
- **When:** 10 s into the first episode of a show without an answer, and only after the resume toast has closed. It never overlaps the resume toast.
- **Where:** centred like the resume toast, above the subtitle band (section 7.1).
- **No answer:**
  - It hides after 20 s, and no answer is stored, so the next episode of that show asks again.
  - Until there is an answer the show behaves as Off: no card, no queue item.
  - Alternative timing: ask at the Up Next point instead. This is **needs Sticky** (Q2).
- **Keyboard:** the prompt does not steal keyboard focus (Space must still pause). Tab reaches it.

### 2.4 "Are you still watching?" (setting on by default, after 3 episodes)

- **The count:** episodes started by autoplay with no user input in between. Any key, click or wheel on Cone resets it; the countdown does not.
- **At 3:** at the next Up Next point the card shows "Still watching?" with **Keep watching** and **Stop**, and no countdown.
- **At the end of the episode:** the next episode is loaded **paused at its start** (item option `:start-paused`). The player view and the card stay up (a stop would send the window Home).
  - **Keep watching** plays it.
  - **Stop** stops (Home, as today).

---

## 3. Show detection (strict)

**Goal:** no false positives. A single video, a recording, a clip, a movie with a sequel or music never get the prompt, the card or the tag. A real show that is missed only costs what Cone does today.

### 3.1 Preconditions (all must hold)

1. The media is a **local file** (`file://`, including UNC paths). Streams, discs, capture devices and network services never count.
2. The media is **video**: library media type video, or a video track once playing. Audio-only files never count, even when named S01E02 (podcasts, audiobooks).
3. The folder is **not a music folder**:
   - not inside one of the library's music roots (`RdLibrary/musicFolders`);
   - not a folder whose files are mostly audio.
4. The file and its folder are not excluded (section 3.4).
5. Autoplay is not Off, and no blocking condition from the matrix is active (shuffle, repeat one, A-B loop, command-line flow options, and so on).

### 3.2 Episode patterns

The file name, without its extension, is parsed into **(stem, season, episode[, last episode])**. This reuses and extends `SubtitleMatcher::parse` (`dialogs/redesign/addsubtitles/subtitle_matcher.cpp:204-260`), which already reads SxxEyy, NxNN and E/EP.

| Strength | Pattern (case-insensitive, word boundaries) | Example | Rules |
|---|---|---|---|
| strong | `S(\d{1,2})\s?[._ -]?E(\d{1,3})(?:-?E?(\d{1,3}))?` | `The.Wand.S01E02.1080p.mkv`, `S01E01-E02` | a range = a multi-episode file, next = last + 1 |
| strong | `(?<!\d)(\d{1,2})x(\d{2,3})(?!\d)` | `The Wand 1x02.mp4` | not `1920x1080`/`720x480` (first part 3+ digits), not `x264`/`x265` (no digit before the x) |
| strong | `Season\s?(\d+)\s?Ep(?:isode)?\.?\s?(\d+)`, `S(\d+)\s?Ep\.?\s?(\d+)` | `Season 1 Episode 2` | |
| medium | `Ep(?:isode)?\.?\s?(\d{1,3})`, standalone `E(\d{2,3})` | `The Wand - Episode 2.mkv`, `Ep.02` | season from the season folder (3.5), else 1 |
| medium | `Part\s?(\d{1,2})`, `Pt\.?\s?(\d{1,2})` | `Documentary Part 3.mkv` | counts only with **3 or more** parts (Kill Bill Vol 1/2, Dune Part 1/2 stay movies) |
| weak | a plain number: `^(\d{1,3})\b`, `[ ._-](\d{1,3})$`, `[ ._-](\d{1,3})[ ._-]` | `The Wand 02.mkv`, `02 - Title.mkv` | never 4 digits; never a year (19xx/20xx), a resolution (480/720/1080/2160 + p), a codec (264/265), bit depth (8/10bit) or audio (5.1/7.1) |

**The stem** is what is left when the episode token and the noise are removed: release tags (resolution, codec, source, group in brackets), dots and underscores turned into spaces, lower case. "The.Wand.S01E02.1080p.WEB" and "The Wand - S01E03" both give "the wand".

### 3.3 When a folder is a show (all must hold)

1. **Same stem and pattern class.** At least **3** video files in the show (season folders included) parse with the same stem and the same class:
   - Strong patterns: **2** files are enough (S01E01 + S01E02 is unambiguous).
   - Weak plain numbers: the stem must not be empty, so `01.mkv … 12.mkv` only counts when the folder name supplies the title and there are **4 or more** numbers.
2. **Distinct numbers.** The numbers are distinct and form a sequence with gaps of at most 3 (E01, E02, E05 is a show; 1, 47, 300 is not).
3. **Similar lengths.** Where the durations are known (library, or after preparsing), every episode lasts between 50 % and 200 % of the median, and at least 2 minutes (weak patterns: 10 minutes). This drops clip folders and trailers.
4. **The current file is one of them.**
5. **Not a recording or clip folder.** Names that match camera, phone and recording conventions never count, even when numbered:
   - `IMG_`, `VID_`, `MVI_`, `DSC`, `GOPR`/`GX`/`GH`, `PXL_`, `DJI_`;
   - `Screen Recording`, `Screencast`, `Recording`, `Capture`;
   - OBS's `YYYY-MM-DD HH-MM-SS`, and date-only names.

### 3.4 Exclusions (Extras, samples)

**Folders** named (whole word, case-insensitive) Extras, Featurettes, Behind The Scenes, Deleted Scenes, Interviews, Trailers, Samples, Sample, Bonus, Shorts, Other, Scenes are skipped for detection and as next episodes.

**Files** are skipped when:
- the name has a token from that same list, or `sample`, `trailer`, `teaser`, `promo`, `NCOP`, `NCED` or `creditless`;
- the name ends with a Plex/Jellyfin suffix: `-behindthescenes`, `-deleted`, `-featurette`, `-interview`, `-scene`, `-short`, `-trailer`, `-other`, `-sample`;
- the extension is not a video extension: `.part`, `.!qB` and `.crdownload` (unfinished downloads) never count.

### 3.5 Season folders

- **Season folder names:** `Season 1`, `Season 01`, `S01`, `S1`, `Series 2`, `Staffel 1`, `Saison 1`, `Temporada 1`.
- **Show root:** the parent of a season folder. With no season folder, the episode's own folder.
- **Order:** (season, episode). Ties and missing numbers fall back to natural file-name order (`SubtitleMatcher::naturalSort`).
- **After a season's last episode:** the first episode of the next season folder by number. The card says "Up next · Season 2".
- **Specials:** `Season 0`, `Specials` and `S00` are never chosen as the next episode. Inside them the specials play in order and stop at their end.
- **Missing episode:** when E05 is missing, the next existing number is chosen (E06), and the card shows "S01E06".
- **The last episode of the show:** no card and no queue item; it ends as today.

### 3.6 Names shown

- **Show name:** the folder name, as in the top bar (`RdNowPlaying.folderName`). When that folder is a season folder, the show root's name is used instead ("The Wand", not "Season 1"). The top bar itself keeps showing the immediate folder, as today.
- **Episode line:** "S01E02 · &lt;title&gt;".
  - **Title:** the library's title metadata when it differs from the file name; otherwise the file name with the stem, the episode token and the release noise removed.
  - **With nothing left:** "S01E02".
  - **Without a season:** "Episode 2".

### 3.7 Detection test set (becomes unit tests in step 2)

| Folder / files | Expected |
|---|---|
| `The Wand/Season 1/The.Wand.S01E01..E09.mkv` | show "The Wand", next of E04 = E05 |
| `The Wand/S01/…S01E15.mkv` + `The Wand/S02/…S02E01.mkv` | after S01E15, next = S02E01 ("Season 2") |
| `Show/Show 1x01.mp4 … 1x08.mp4` | show |
| `Doc/Doc - Episode 1..6.mkv` | show (medium) |
| `Dune Part One (2021).mkv`, `Dune Part Two (2024).mkv` | **not** a show (2 parts, years) |
| `Kill Bill Vol 1.mkv`, `Kill Bill Vol 2.mkv` | **not** a show |
| `Movies/Inception (2010).mkv` alone | **not** a show |
| `DCIM/VID_20240101_101010.mp4 …` | **not** a show (camera names) |
| `Videos/2024-05-01 18-22-10.mkv …` (OBS) | **not** a show |
| `Clips/clip 1.mp4 … clip 40.mp4`, 30 s each | **not** a show (under 2 min / weak under 10 min) |
| `Music/Album/01 - Song.flac …` | **not** a show (audio, music root) |
| `Podcast/S01E01.mp3 …` | **not** a show (audio only) |
| `The Wand/Extras/Making of.mkv` playing | **not** a show; never chosen as next |
| `The Wand/S01/The.Wand.S01E03.sample.mkv` | skipped as next |
| `Anime/01.mkv … 12.mkv` (folder "Anime") | show (title from the folder, 4+ numbers) |
| `Movies/1917 (2019).mkv`, `Movies/2012 (2009).mkv` | **not** a show (years) |

---

## 4. Storage, queue, resume, presets, library

### 4.1 Where the per-show choice is stored

- **File:** `<user data dir>/rd-shows.json`, next to `rd-presets.json` and `rd-subtitles.json`. It is read on the thread pool at start and written asynchronously, like `RdPresets`.
- **Shape:**
  ```json
  { "version": 1,
    "shows": { "<show root, normalised path>": { "choice": "yes" | "no", "name": "The Wand", "updated": "2026-10-20T12:00:00Z" } } }
  ```
- **Key:** the show root path. Case-insensitive on Windows (the same rule as `RdPresets::linkedPreset`), and it covers all season folders.
- **Not in the library database:** shows outside the library folders must work too.
- **Settings > Playback > Episodes > "Remembered shows":** shows the count ("4 shows: 3 autoplay, 1 never") and a **Forget all** button. A per-show list is a later option.
- **Global settings:** new Qt options declared in `qt.cpp`, read and written through `RdEffects`, so they work with `SettingsOption`:

  | Option | Values | Default |
  |---|---|---|
  | `qt-autoplay-next` | 0 Off / 1 Ask / 2 Always | 1 |
  | `qt-autoplay-countdown` | 5 / 10 / 15 | 10 |
  | `qt-autoplay-card-point` | 0 end / 1 credits | 0 |
  | `qt-autoplay-still-watching` | bool | true |

  They take effect live, with no restart.

### 4.2 How the queue is filled

- **The autoplay item.** One next episode at a time is appended to the queue as an **autoplay item**. Cone keeps the list of playlist items it added; nothing is added to the media itself.
  - It is appended when detection finishes, so Next, the queue and the mini queue show it at once.
  - When it starts playing, the episode after it is appended. There is never more than one autoplay item waiting.
- **Only a Cone-made queue is ever filled.** Autoplay acts only while the queue holds just the single file the user opened plus autoplay items. The single-file opens are listed in section 1.
- **A user-built queue is followed and never auto-filled.** The queue counts as user-built as soon as the user:
  - adds anything (the queue's "+", drag to the queue, library "Add to Queue", Open Folder, a multi-file open);
  - removes an item, reorders, sorts or clears the queue.

  From then on autoplay removes its own waiting item, shows no card, and Cone plays the queue as VLC does. Her 11:44 flow (drag the next episode in by hand) still works. When she drags in the episode autoplay already queued, her copy wins and autoplay's copy is removed.
- **The queue row** of an autoplay item shows a small dim "Autoplay" label on the right. Removing it is the same as Cancel.
- **The end-of-file action** (`mediaStopAction`) is never touched. Autoplay never changes CONTINUE/STOP/EXIT, because the sleep timer's "End of current file" uses it and cancels itself when anything else changes it (`RdSleepTimer.qml:58-62, 117-127`).

### 4.3 Resume position of the next episode

- **The rule:** the next episode starts from its saved spot, **without the resume prompt**, when "Continue where you left off" (`restore-playback-pos`) is Ask or Always.
- **How:** the autoplay item carries the item option `:restore-playback-pos=2`. Qt items take options as trusted (`playlist/media.hpp:80`), and the core reads the option per input (`src/player/input.c:1321`). This is inferred from the code and must be checked in step 2.
  - Fallback: `ResumeDialog` skips the prompt for autoplay items and calls `Player.restorePlaybackPos()` itself.
- **Never** is respected: the episode starts at 0.
- **The existing "watched to the last 20 s" rule** (`ResumeDialog._watchedToEnd`, `player_controller.cpp:1047-1052`) still applies, so a finished episode starts over.
- **Which episode is "next":** the following episode in (season, episode) order, whether watched or not, as on streaming services. The library's Unwatched First sort does not change this order.

### 4.4 Show presets

- **Folder-linked presets apply on every media change by themselves** (`RdPresets::onInputChanged`, `rd_presets.cpp:836-916`). The next episode gets the show's preset with no new code.
- **Season folders:** `linkedPreset` checks parent folders too (`:974-990`), so a preset linked at the show root covers every season. Step 2 checks this; if it is linked at a season folder, the next season falls back to Default.
- **Per-file values** (delays, zoom, crop, aspect) come from the linked preset when there is one, and otherwise reset as in VLC today.
- **Speed, subtitle speed, stereo mode and visualizer** carry from file to file (VLC's `keptFromFileToFile`, `rd_presets.cpp:272-282`).

### 4.5 Subtitle and audio track choices

- The **language** the user picked in the episode carries to the next one (not the track number). The autoplay item gets `:sub-language=<lang of the current SPU track>` and `:audio-language=<lang of the current audio track>`; "off" carries as `:sub-track=-1` (no subtitles).
- A show preset's own track or language settings win over this.
- Without a language tag, VLC's defaults apply (Settings > Playback > Tracks).

### 4.6 Continue Watching and the library

- **Continue Watching** (Home, `RdCollectionModel` "continueWatching", `0 < progress < 1`) needs nothing new. The next episode joins it once started, and an episode that was finished or skipped by Play now (marked watched) leaves it.
- **"Unwatched first" (P5-13):**
  - The compact and full library tag the next episode "Up next" (`08-…`). The tag is shown only while autoplay is on for that show.
  - With Unwatched First the next episode is usually the first row, so the manual way (her 11:44 drag) and the automatic way point at the same row.
  - The tag uses BG/Accent Bright with Accent/Main text, radius 4, Inter 600 12.
- **Playing row:** orange as today (IB-14).
- **Home "Watch Next":** today it is only an empty state (`RdLibraryHome.qml:244-266`). A real "Up next in your shows" row is a possible later step; it is not part of this feature.

### 4.7 Thumbnail of the next episode

- **In the library:** the library thumbnail, which is generated on the library thread when missing (`vlc_ml_media_generate_thumbnail`, as `rdlibrarymodel.cpp:444-462`).
- **Outside the library:** a one-shot preparser thumbnail at 15 %, the same machinery as `RdSeekThumbnailer` (`vlc_preparser` + thumbnailer), for one media only, made when the autoplay item is queued.
- **Placeholder:** BG/A1 with the "videos" icon.

---

## 5. Settings and sidebar

### 5.1 Settings > Playback, new section "Episodes" (after "Order")

| Row | Control | Values | Notes |
|---|---|---|---|
| Autoplay next episode (i) | dropdown 320x36 | Off / Ask for each show / Always | description under the label: "Plays the next episode of a show folder when one ends. Single videos, clips and music are never treated as shows." |
| Countdown (i) | dropdown | 5 seconds / 10 seconds / 15 seconds | dimmed (0.3, `rd_disabledRowOpacity`) when Off |
| Show Up Next (i) | dropdown | At the end of the episode / When the credits start | dimmed when Off |
| Ask if I'm still watching after 3 episodes (i) | toggle 68x32 | on / off | dimmed when Off |
| Remembered shows (i) | text + "Forget all" button | "N shows: X autoplay, Y never" | dimmed when Off |

- All rows go into the settings search keywords (autoplay, next episode, binge, up next, countdown, show, series).
- Images: `10-settings-playback-dark.png`, `-menu-`, `-off-`, `-light`.

### 5.2 Sidebar Playback tab: "Autoplay this show"

- **Place:** directly under Sleep Timer, as asked. Both rows decide what happens when the episode ends.
- **Label:** "Autoplay this show", Inter 14 FG/A3. Under it, the show name with the tv icon, Inter 12 FG/A4.
- **Control:** the Figma toggle, 68x32 at x 312. Row height 62.
- **Behaviour:**
  - The toggle writes the remembered answer for that show ("yes"/"no"), the same as the prompt.
  - It is shown only while a detected show is playing and autoplay is not Off. Otherwise the row is not there, and nothing moves on the tab for non-shows.
  - When a guard from section 8 blocks autoplay (repeat one, shuffle, stop after each item, an A-B loop, a command-line option), the row stays, dimmed (`rd_disabledRowOpacity`), with the reason under the label instead of the show name ("Repeat one is on").
- **Images:** `09-sidebar-playback-dark/light.png` (ON, OFF, no row).
- **The sidebar's own header comment** still lists "Subtitle Timeline" and "Reverse" rows that do not exist (`PlaybackSettingsPage.qml:19-23`). Step 2 fixes the comment while editing the file.

---

## 6. Implementation outline (for step 2)

### 6.1 Files

| New / changed | What |
|---|---|
| `player/rd_up_next.{hpp,cpp}` (new) | `RdUpNext` singleton: detection (worker thread), the show store (`rd-shows.json`), autoplay items, the countdown, the Up Next point, the still-watching count, guards (section 8). Properties: `active`, `isShow`, `showName`, `showFolder`, `choice`, `nextCode`, `nextTitle`, `nextMrl`, `nextThumbnail`, `cardVisible`, `cardMode` (next / season / still), `secondsLeft`, `countdownTotal`, `promptVisible`. Methods: `playNow()`, `cancel()`, `answer(bool)`, `setShowEnabled(bool)`, `forgetAll()`. |
| `player/rd_episode_parser.{hpp,cpp}` (new, or extend `SubtitleMatcher`) | patterns, stems, exclusions, season folders; pure functions with unit tests (section 3.7) |
| `player/qml/RdUpNextCard.qml` (new) | Variant A, with states next / season / still; compact layout below 900 px of video width |
| `player/qml/RdShowPrompt.qml` (new) | the prompt |
| `player/qml/Player.qml` | places the card and the prompt (section 7.1), keyboard (Tab order), lock of the bars' auto-hide while the card shows (like the resume toast) |
| `player/qml/RdMiniPlayer.qml` | compact Up Next strip on the picture's foot (`06-…`) |
| `player/qml/PlaybackSettingsPage.qml` | "Autoplay this show" row |
| `dialogs/redesign/settings/pages/SettingsPlaybackPage.qml` | "Episodes" section |
| `medialibrary/qml/RdLibraryPage.qml` / row delegate | "Up next" tag (compares the row MRL with `RdUpNext.nextMrl`) |
| `player/qml/QueueSidebar.qml` | "Autoplay" label on the autoplay item's row |
| `qt.cpp`, `settings_catalog.cpp`, `rd_profile_settings.cpp` | the four options; curated list; profiles (Q5) |
| `Makefile.am`, `meson.build` | new files (buildlists check) |

### 6.2 Signals used

- `PlayerController`: input changed, `positionChanged`/`timeChanged` (the Up Next point is a threshold check on the existing position updates, not a polling timer), `playingState`, `chapters`.
- `PlaylistController`: count, items, current index changes (user-built detection), `random`, `repeatMode`, `mediaStopAction`.
- The countdown uses one 1 s `Timer`, running only while the card is visible.

### 6.3 Performance

- **Folder scan:** once per show per session, on the thread pool. It is a `QDir` listing of the folder and the season siblings, never recursive beyond the show root.
- **Start of playback:** nothing blocks it.
- **Idle:** no timer while no card shows.
- **Thumbnail:** generated once per next episode.

### 6.4 Translations, accessibility, scaling

- All text in `qsTr`.
- The card has `Accessible.role: Dialog` with the full sentence.
- Sizes through `VLCStyle.dp`.
- Colours from the palette, so the light theme and the accent follow live.

### 6.5 Both profiles

The code is shared by the vlc and Cone profiles. The default per profile is Q6.

### 6.6 Core

- No core change is needed. Everything uses existing APIs:
  - playlist insert/remove;
  - per-item options (`:restore-playback-pos`, `:start-paused`, `:sub-language`, `:audio-language`);
  - `vlc_ml_media_set_played`;
  - preparser thumbnails.
- If per-item `:restore-playback-pos=2` does not work as read from the code, the fallback is in the QML (section 4.3). It still needs no core change.

---

## 7. Design rules (Cone style)

### 7.1 Placement: never over subtitles

Subtitles sit right on top of the control bar: Cone lifts them by the bar's height (`sub-ui-margin`, `rd_subtitle_lift.cpp:51`, added to `sub-margin`). A card in the band just above the bar would cover them. So:

- **Card:**
  - **Horizontal:** 24 px from the right edge of the video area, left of an open side panel (the same inset rule as the resume toast, `Player.qml:2259-2264`).
  - **With subtitles on:** the card's bottom sits 16 px above the **subtitle band**. The band is the lift + `sub-margin` + 2 lines at the current subtitle text size (`sub-text-scale`), and it is computed whether or not a line is on screen right now, so the card does not jump. See `01-card-A-recommended-dark.png`.
  - **With subtitles off:** 24 px above the control bar, like the resume toast (`02-…`, `03-…`, `04-…`).
  - **Bars hidden** (windowed after 3 s, or fullscreen): the same positions measured from the bottom edge. The card stays and does not bring the bars back.
- **Prompt:** centred like the resume toast, under the same subtitle-band rule (`07-…`).
  - The existing resume toast has the same overlap with lifted subtitles. Fixing it is noted as a follow-up, outside this feature.
- **Narrow video area** (under 900 px, e.g. a side panel open in a small window): the card switches to the compact pill (Variant C layout).
- **Very small window** (under the pill's minimum): the card hides and the countdown keeps running. The queue and the mini player still show what comes next.
- **On-screen messages** (FloatingNotification, centred over the bar) keep their place. The card is on the right, so they do not overlap at normal sizes; in the compact case the message wins and the pill moves up by the message height.

### 7.2 Look

| | |
|---|---|
| Card | opaque BG/A3 (no blur over the native video, Decision: opaque popups), radius 14 (`rd_radius_large`, like the mini player and the thumbnail card) |
| Shadow | effect "bg blur + shadow" without the blur: #000 46 %, y 8, blur 15 |
| Text | Inter: "Up next" 600 12 Accent/Main; show name 400 14 FG/A2; episode 500 16 FG/2 (two lines max); "Playing in 8 s" 400 13 FG/A3 |
| Thumbnail | 160x90, radius 6, a 36 px round play mark |
| Buttons | `RdButton`: Play now = Primary with the play icon; Cancel = BG/A1 (the resume toast's close button colour) |
| Countdown line | 3 px, BG/B2 track, accent part = time left, along the bottom inside the 12 px padding |
| Motion | fades in 150 ms ease-out (the rule for elements without a Figma duration); no movement; follows Windows "Animation effects" (off = instant), like the tab crossfades (MainCtx.systemAnimations) |

**Keyboard:**
- The card never takes focus by itself, so Space still pauses and the arrows still seek. Tab reaches Play now and Cancel.
- N (next) acts as Play now.
- Escape cancels only while the card has focus; otherwise Escape keeps its fullscreen meaning.
- The wheel over the card is swallowed (`RdWheelSink`, Decision 54).
- A right-click on the card does nothing.

### 7.3 Variants

| | A (recommended) | B | C |
|---|---|---|---|
| Shape | panel card 400 wide (the side panel width) | thumbnail first, 320 wide | the resume toast's pill, 60 high |
| Pros | readable, all parts visible, matches the side panels and the mini player | big picture | smallest, matches the resume toast |
| Cons | tallest | covers more video | small thumbnail; the episode name can get long |
| Used for | default | - | compact case (narrow video area) |

---

## 8. Conflict matrix

Starting rules (from the request):

| | |
|---|---|
| **R1** | A queue the user built is followed and never auto-filled. |
| **R2** | Autoplay is off while shuffle or repeat one is on. |
| **R3** | The sleep timer always wins. |
| **R4** | The card and the prompt never cover subtitles. |
| **R5** | Command-line options are respected. |
| **R6** | Per-episode settings (A-B loop, bookmarks) don't carry over. |
| **R7** | Show presets do carry over. |

**Columns:** "When an episode ends / while the card shows" describes behaviour with autoplay on for the show. "Clash" says whether there is a conflict. "Rule" is what prevents it. Every row is also a Windows test step: the Test column says what to do and what to expect.

**Shortcuts used in the table:**
- *AP-on show* = a detected show with autoplay on (Always, or Ask answered Yes).
- *card point* = the Up Next point.

### 8.1 Settings > Playback

| # | Setting / feature | When an episode ends / while the card shows | Clash | Rule | Test |
|---|---|---|---|---|---|
| 1 | Continue where you left off = Ask | the next episode would show the resume prompt | yes | the autoplay item starts at its saved spot without the prompt (4.3) | Watch E02 to 10:00, play E01 to its end with AP on. Expect: E02 starts at 10:00, no resume toast. |
| 2 | Continue where you left off = Always | starts at the saved spot | no | as VLC | Same as 1. Expect: E02 at 10:00. |
| 3 | Continue where you left off = Never | | no | starts at 0 | Same as 1 with Never. Expect: E02 at 0:00. |
| 4 | Privacy > Remember the playback position off | same as Never | no | as 3 | Toggle off, repeat 1. Expect: 0:00. |
| 5 | Start playing as soon as a file opens (`playlist-autostart`) off | the user opened a file without playing it | no | autoplay acts only once playback has started; the autoplay item is queued then | Turn off, open E01 (no start), press Play, run to the end. Expect: E02 follows. |
| 6 | Default playback speed | | no | speed carries file to file as today; the countdown is in real seconds | Speed 1.5x, reach the card. Expect: "Playing in 10 s" counts in real seconds. |
| 7 | Pause when another app uses audio | the player pauses during the card | no | the countdown pauses while paused | Card showing, start audio in another app. Expect: Cone pauses, the countdown freezes, resumes with playback. |
| 8 | Preferred video quality / menu language | per file | no | apply per file as today | Smoke test: E02 plays with the same preference. |
| 9 | Default audio track / Default subtitle track | the next episode gets VLC's default | partial | the language picked in the episode carries (4.5); the show preset wins; otherwise these defaults | Pick Japanese audio + English subs in E01, let E02 start. Expect: Japanese + English. |
| 10 | Repeat = One (Settings, saved) | VLC repeats the episode | yes | **R2**: autoplay off while repeat one is on (no item, no card, sidebar toggle shown but inactive with "Repeat one is on") | Repeat One, play E01. Expect: no card, E01 starts again. |
| 11 | Repeat = All | the queue wraps to its first item | partial | the autoplay item is always next, so the show goes on; after the show's last episode the queue wraps to the first item, as VLC does (**needs Sticky**, Q1) | Repeat All, play the last episode of a 2-episode test show. Expect: as decided in Q1. |
| 12 | Shuffle on | random order | yes | **R2**: autoplay off while shuffle is on; turning shuffle on removes the waiting autoplay item | Shuffle on, play E01 to the end. Expect: no card, behaves as today. |
| 13 | Stop after each item (`play-and-stop`) | VLC stops after each item | yes | autoplay off (it is the user's explicit "stop after each"); the sidebar row shows "Stop after each item is on" | Turn on (restart), play E01. Expect: no card, stops. |
| 14 | When playback finishes = Pause on the last frame (`play-and-pause`) | VLC pauses at the end of every item (`input.c:1023-1027`), so the next item never starts | yes | autoplay off while it is on (**needs Sticky**, Q3, option: treat it as "stop at the queue's end" and keep autoplay) | Set, restart, play E01. Expect: per Q3. |
| 15 | When playback finishes = Quit Cone (`play-and-exit`) | autoplay keeps the queue from ending, so Cone never quits | yes | **R5**: autoplay off while `play-and-exit` is on (saved or command line) | Set, restart, play E01. Expect: no card, Cone quits at the end. |
| 16 | Seek precisely / thumbnails while scrubbing | | no | - | Seek into the last seconds. Expect: the card shows with the time left. |
| 17 | Load matching .mkv files from the same folder | segment preloading only | no | - | Smoke test. |
| 18 | More playback options: `start-paused` | | yes | autoplay off when it is on (**R5**); the still-watching pause uses a per-item option, not this one | `--start-paused` on the command line. Expect: no card. |
| 19 | `input-repeat` (repeat N times) | VLC repeats the item | yes | autoplay off while `input-repeat` > 0 | `--input-repeat=1`. Expect: the episode repeats, no card. |
| 20 | `start-time` / `stop-time` / `run-time` | they apply to **every** input, so they would apply to the next episode too | yes | **R5**: autoplay off when any of them is set | `--start-time=60 E01.mkv`. Expect: no card, no autoplay item. |
| 21 | `restore-playback-states` (speed, tracks per media) | per media | no | VLC's per-media states win for the media they belong to | Smoke test with it on. |

### 8.2 Other Settings pages

| # | Setting | When an episode ends / while the card shows | Clash | Rule | Test |
|---|---|---|---|---|---|
| 22 | General: Theme / Accent | | no | the card and prompt follow both live | Switch theme while the card shows. Expect: it recolours. |
| 23 | General: Show confirmation and error dialogs | an error on the next file | no | an unreadable next file is skipped to the one after it, else no card | Rename E02 to `.part`, play E01. Expect: the card offers E03. |
| 24 | Interface: Play video inside main window off | a separate video window | no | the card shows in the main window over its player view | Turn off (restart), play E01. Expect: the card is in the main window. |
| 25 | Interface: Resize window to fit video | may resize between episodes | no | as today | Smoke test. |
| 26 | Interface: Auto-hide the controls / Hide after / fullscreen controls | bars hidden while the card shows | no | the card stays, does not bring the bars back, and locks nothing; the resume-toast rule (`lockUnlockAutoHide`) applies only while the card has focus | Fullscreen, mouse still. Expect: the card shows with the bars hidden. |
| 27 | Interface: Start in compact mode / minimal view | | no | the card shows in the minimal view too (compact layout) | Minimal view, reach the card. |
| 28 | Interface: Show a system tray icon / popup when the track changes | the track-change popup fires for E02 | no | as today | Smoke test. |
| 29 | Interface: Pause video when window is minimized | paused while minimized, so the countdown pauses | no | countdown pauses | Minimize during the card. Expect: on restore the countdown continues. |
| 30 | Privacy: Save recently played items off | the library does not store progress | partial | detection still works (file names); resume and Continue Watching don't, as today | Turn off, run 1. Expect: E02 at 0:00. |
| 31 | Privacy: Never remember items matching | filtered from history | no | as today | Smoke test. |
| 32 | Controls: shortcuts | N, P, Space, arrows, Escape | partial | N = Play now; P = previous (goes to the previous episode as today); Space pauses (the card never takes focus); Escape cancels only with the card focused | During the card: Space (pause), N (next now), Tab to Cancel + Enter. |
| 33 | Controls: single / double click on the video | pause / fullscreen | no | clicks on the card stay on the card | Click Cancel. Expect: no pause toggle. |
| 34 | Controls: scroll wheel | volume / seek | no | the wheel over the card is swallowed (Decision 54) | Wheel over the card. Expect: no volume change. |
| 35 | Controls: Web remote control | | no | the remote can press Next (= Play now) | Smoke test. |
| 36 | Video: Start videos in fullscreen | | no | the next episode keeps the current fullscreen state | Fullscreen at the card, let it advance. Expect: stays fullscreen, no flash to Home. |
| 37 | Video: aspect, crop, zoom, deinterlace (settings defaults) | per file | no | **R6/R7**: per-file values reset unless the show preset sets them | Set crop in E01 without a preset. Expect: E02 not cropped. With a folder preset that crops: cropped. |
| 38 | Audio: device, volume, night mode, normalisation, equalizer | global | no | carry as today | Smoke test. |
| 39 | Audio: Visualizer | (video files only) | no | - | - |
| 40 | Subtitles: Enable subtitles / language / size / position (`sub-margin`) | | partial | **R4**: the card band is computed from `sub-margin` + lift + 2 lines at the current size | Subtitle position "high" and size large: the card sits above them. |
| 41 | Subtitles: Show feedback for shortcuts (`osd`) | OSD on N | no | as today | Smoke test. |
| 42 | Subtitles: Show filename when a video starts | shows E02's name | no | as today (Decision 69: off by default in Cone) | Smoke test. |
| 43 | Subtitles: OpenSubtitles / Add Subtitles rules | per-video and per-folder subtitle rules (`rd-subtitles.json`) | no | per-folder rules apply to E02 by themselves | Folder subtitle rule set: E02 gets its subtitle. |
| 44 | Library: Only allow one Cone window / Add to the playlist instead of replacing | a second file opened from Explorer joins the queue | yes | **R1**: a second file added while an AP-on show plays makes the queue user-built (no more auto-filling; the waiting autoplay item is removed) | Play E01 (AP on), double-click another video in Explorer. Expect: the autoplay item is gone and the other video plays next. |
| 45 | Library: When opening a folder | Open Folder queues the folder | no | user-built, followed (R1) | Open Folder on the show. Expect: no card; all episodes play as today. |
| 46 | Library: Use the media library (always on) | | no | detection works without the library (file names); thumbnails and resume need the library | Play a show outside the library folders. Expect: card with a generated thumbnail. |
| 47 | Network: caching, proxy | streams are never shows | no | precondition 1 | Play an HTTP stream named S01E01. Expect: no card. |
| 48 | Performance: hardware decoding, threads, priority | | no | - | Smoke test. |
| 49 | Recording: recording at an episode end | the recording is per input and ends with it | no | autoplay proceeds; the next episode is not recorded unless the user starts again | Record in E01 until the end. Expect: one file for E01, E02 plays unrecorded. |
| 50 | Recording: cast / renderer | casting to a device | partial | the card shows locally, the next item is cast as VLC does (**needs Sticky**, Q7) | Cast E01, reach the card. |
| 51 | Extensions | | no | - | - |

### 8.3 Sidebar tabs

| # | Control | When an episode ends / while the card shows | Clash | Rule | Test |
|---|---|---|---|---|---|
| 52 | Playback: Show Waveform / Metadata / Statistics | panels follow the new media | no | - | Statistics open across the switch. |
| 53 | Playback: **Sleep Timer** 15-60 min | the timer may fire during the card | yes | **R3**: the sleep timer wins; when it fires, Cone stops and the card closes | 15 min timer timed to fire during the card. Expect: stop, no next episode. |
| 54 | Playback: **Sleep Timer = End of current file** | sets STOP at the end | yes | **R3**: no card, the autoplay item is removed while it is set; it comes back if the timer is turned Off before the end | Set it, reach the end. Expect: no card, stop. Set, then back to Off. Expect: the card appears. |
| 55 | Playback: Audio Visualizer | | no | - | - |
| 56 | Playback: Speed | carries | no | countdown in real seconds | As 6. |
| 57 | Playback: **Autoplay this show** (new) | | - | writes the per-show answer; off removes the waiting item and hides the card at once | Toggle off during the card. Expect: the card closes, nothing queued. Toggle on again. Expect: item and card back. |
| 58 | Video tab: Flip, Rotate, Zoom, Aspect, Crop, filters | per file or global | no | **R6/R7**: per-file values reset, preset values apply, global filters stay | Rotate 90° in E01 without a preset. Expect: E02 not rotated. |
| 59 | Audio tab: track, language, stereo mode, delay, EQ, filters | delay per file; stereo mode carries | no | **R6/R7** + 4.5 (language carries) | Audio delay +200 ms in E01, no preset. Expect: E02 at 0 ms. With preset: the preset's delay. |
| 60 | Subtitles tab: track, delay, speed, duration factor, style | delay per file | no | as 59; the subtitle language carries | Sub delay in E01. Expect: E02 at 0 (or the preset's). |
| 61 | Preset selector: Use for This Folder | | no | **R7**: the folder preset applies to the next episode by itself; linked at the show root it covers all seasons | Link a preset at "The Wand" root, let S01E15 → S02E01 run. Expect: the preset is still active. |

### 8.4 Queue, playlists and the playback flow

| # | Feature | When an episode ends / while the card shows | Clash | Rule | Test |
|---|---|---|---|---|---|
| 62 | Queue panel: "+" / drag to the queue (W5.9) / library Add to Queue | the user builds a queue | yes | **R1**: the queue becomes user-built; the waiting autoplay item is removed; no card | AP on, drag E05 into the queue during E01. Expect: E05 plays next, no card. |
| 63 | Queue: remove (−), reorder, sort, clear | | yes | **R1** as 62; removing the autoplay item = Cancel | Remove the "Autoplay" row. Expect: no card at the end. |
| 64 | Queue: the autoplay item's row | | - | dim "Autoplay" label; double-clicking it plays it now (= Play now) | Double-click the row. Expect: E02 plays. |
| 65 | Queue: Repeat button (None → All → One) | | yes | as 10/11 live; switching to One during the card closes it | Click Repeat to One during the card. Expect: the card closes. |
| 66 | Queue: Shuffle button | | yes | as 12 live | Shuffle during the card. Expect: the card closes, the item is removed. |
| 67 | Library playlists: Play | user-built | no | **R1** followed | Play a playlist of episodes. Expect: no card. |
| 68 | Library: Play on one episode / click a row | single file | - | eligible | Click E03 in the compact library. Expect: autoplay item E04. |
| 69 | Library: Play on a folder / Shuffle | user-built / shuffle | no | R1 / R2 | Play on S01. Expect: all play, no card. |
| 70 | Library: Continue Watching card | single file | - | eligible; starts at the saved spot as today | Continue E03 from Home. Expect: E04 queued. |
| 71 | Library: Recent | single file | - | eligible | Play E03 from Recent. |
| 72 | Library: mark watched / unwatched | | no | changes the tags only, never the order | Mark E05 watched. Expect: still next after E04. |
| 73 | Library: Unwatched First sorting | | no | the tag follows the next episode wherever the sort puts it | Unwatched First on. Expect: the tagged row is first (`08-…`). |
| 74 | Library / compact library open during the card | | no | the card shows on the video area right of the library | Open the compact library at the card point. Expect: the card is fully visible. |
| 75 | Previous / Next buttons | | - | Next = Play now (the autoplay item is the next item); Previous as today | Press Next during E01. Expect: E02 plays. |
| 76 | Stop button / press-and-hold Play | | no | stop as today; the card closes and the waiting autoplay item is removed (as Cancel) | Stop during the card. Expect: Home, no next episode, the queue holds only E01. |
| 77 | A-B loop active at the end | the loop never reaches the end | yes | **R6**: no card while an A-B loop is active (the loop wins); the loop resets for the next file anyway | Set A-B around the last minute. Expect: it loops, no card. |
| 78 | Bookmarks | per file (library) | no | **R6**: nothing carries; Ctrl+B in E02 makes E02's bookmark | Bookmark in E01, play E02. Expect: E02's tab is empty. |
| 79 | Chapters | per file | no | the credits chapter can be the card point (5.1) | Show Up Next = credits, a file with a "Credits" chapter. Expect: the card at that chapter, Play now skips the rest and E01 counts as watched. |
| 80 | Speed (sidebar slider / Faster / Slower) | carries | no | as 6 | - |
| 81 | Frame step / Trickplay reverse | | no | Reverse is postponed (Decision 29) | - |
| 82 | Subtitle timeline (P3-16 / P4-35) | per file | no | rebuilt for E02 | Timeline on, E02 starts. Expect: E02's cues. |
| 83 | On-screen messages | | no | 7.1: they keep their place; compact case: the pill moves up | Press N at the card. Expect: no overlap. |
| 84 | The resume toast | could overlap the prompt | yes | the prompt waits for the toast to close; the next episode via autoplay never shows the toast (1) | Open E01 with a saved spot (Ask). Expect: toast first, prompt after. |
| 85 | Mini player (library full view) | the player is small | - | compact strip on the picture (`06-…`): Play now, close, countdown line | Open the full library during the card. Expect: the strip in the mini player. |
| 86 | Mini queue | | - | shows the autoplay item with the label | Open the mini queue. Expect: E02 "Autoplay". |
| 87 | Fullscreen | | no | the card in fullscreen at the same rules (7.1); no exit to Home between episodes (it's a queue move, not a stop) | As 36. |
| 88 | Hide UI (Ctrl+\\) | every overlay hidden | yes | **needs Sticky** (Q4): show the card anyway, or autoplay silently | Hide UI, reach the card. Expect: per Q4. |
| 89 | Customize Player: Next / Previous / A-B / Bookmark / Chapters buttons | | no | as the matching rows | - |
| 90 | Profiles (main "..." menu) | switching applies saved settings, except random/loop/repeat | partial | the four new options are part of profiles (**needs Sticky**, Q5); the per-show answers are not (they belong to the folders) | Switch profile with autoplay Off in it. Expect: per Q5. |
| 91 | Right-click > Playlist > Shuffle / Repeat | runtime only | yes | as 12 / 10 / 11 | Right-click Repeat One during the card. Expect: the card closes. |
| 92 | Right-click > Playlist > **Quit at the end of play queue** | EXIT at runtime | yes | autoplay stops adding (removes the waiting item), so the queue ends and Cone quits as asked | Turn it on during E01. Expect: no card, Cone quits after E01. |
| 93 | Right-click > Playback > Title / Chapter / Program | | no | - | - |

### 8.5 Process, command line, profiles

| # | Item | When an episode ends / while the card shows | Clash | Rule | Test |
|---|---|---|---|---|---|
| 94 | Quit watchdog (PR #34) | closing during the card | no | quit as usual; the current episode's position is saved by the watchdog; nothing autoplay needs saving except `rd-shows.json` (written on answer) | Close Cone at the card. Expect: quits in under 5 s, E01's position saved. |
| 95 | Command line `--play-and-exit` | | yes | **R5** (row 15) | `cone --play-and-exit E01.mkv`. Expect: quits after E01, no card. |
| 96 | Command line `--play-and-stop`, `--play-and-pause`, `--random`, `--loop`, `--repeat`, `--start-paused`, `--input-repeat`, `--start-time`, `--stop-time`, `--run-time`, `--no-playlist-autostart` | | yes | **R5**: any of these set (saved or command line) turns autoplay off for the session, except `--no-playlist-autostart` (row 5) and `--loop` (row 11) | Each option once with E01. Expect: no card (`--loop`: per Q1). |
| 97 | Command line: several files | | no | **R1**: user-built | `cone E01.mkv E03.mkv`. Expect: E01, E03, no card. |
| 98 | Command line / Explorer: one file | | - | eligible (the main case) | Double-click E01 in Explorer. Expect: E02 queued, card at the end. |
| 99 | vlc profile (non-public build) | | - | same code; default value **needs Sticky** (Q6) | Run the vlc build. Expect: per Q6. |
| 100 | First run / onboarding (`--qt-privacy-ask`) | | no | the prompt waits until onboarding is closed | First run with E01 on the command line. Expect: onboarding first, prompt after. |

### 8.6 Detection edge cases (each a test)

| # | Case | Expected | Test |
|---|---|---|---|
| 101 | Single movie | no prompt, card, tag or row | Play `Inception (2010).mkv`. |
| 102 | Two-part movie | no | `Dune Part One/Two`. |
| 103 | Phone videos | no | `VID_2024…mp4` × 5. |
| 104 | OBS recordings | no | 3 OBS-named files. |
| 105 | Short clips | no | 5 numbered 30 s clips. |
| 106 | Music | no | an album folder. |
| 107 | Podcast mp3 with S01E01 names | no | 3 mp3 files. |
| 108 | Extras folder | no; never next | Play `Extras/Making of.mkv`; from E15 the next is never in Extras. |
| 109 | Sample file | skipped | `…S01E03.sample.mkv` next to E03. |
| 110 | Missing episode | E06 after E04 when E05 is missing | Delete E05 (test copy). |
| 111 | Season jump | S02E01 after S01E15, "Season 2" | 2 season folders. |
| 112 | Last episode | no card | Play the last one. |
| 113 | Multi-episode file | next = last + 1 | `S01E01-E02.mkv` then E03. |
| 114 | Unfinished download | skipped | `E02.mkv.part`. |
| 115 | Very long names | card text wraps to 2 lines then elides | A 120-character title. |
| 116 | Plain-number folder | show when the folder supplies the title | `Anime/01..12.mkv`. |
| 117 | Same folder, two shows | each its own sequence (by stem) | `A S01E01..3` + `B S01E01..3` in one folder. |

---

## 9. Design images (`redesign/up-next-design/`)

Rendered offscreen with Qt 6.8 Quick (VLC's Qt version), Inter, the redesign's own SVG icons and the Figma tokens. Sources are in `src/` (`batch.sh`, `render.py`, QML). The pictures are generated landscapes, not real media.

| File | What |
|---|---|
| `01-card-A-recommended-dark.png` | Variant A over the player, a subtitle on screen: the card sits above the subtitle band (7.1) |
| `02-card-A-recommended-light.png` | Variant A, light theme, no subtitle: 24 px above the control bar |
| `03-card-B-dark.png` | Variant B over the player |
| `04-card-C-dark.png` | Variant C over the player |
| `05-card-states-dark.png`, `05-card-states-light.png` | all variants side by side + A's states: hover and focus, next season, still watching |
| `06-mini-player-dark.png`, `-light` | the compact Up Next strip in the mini player |
| `07-show-prompt-dark.png`, `-light` | the one-time prompt, above the subtitle band |
| `08-compact-library-dark.png`, `-light` | the "Up next" tag, by name and with Unwatched First |
| `09-sidebar-playback-dark.png`, `-light` | sidebar Playback tab: ON, OFF, not a show (no row) |
| `10-settings-playback-dark.png`, `-menu-`, `-off-`, `-light` | Settings > Playback > Episodes: default, the mode menu open, Off (dependent rows dimmed), light |

---

## 10. Open decisions (needs Sticky)

| Q | Question | Options | Recommendation |
|---|---|---|---|
| Q1 | Repeat All + autoplay, after the show's last episode | a) VLC wraps to the queue's first item (the episode first opened); b) autoplay goes back to the show's first episode; c) stop | a) (VLC's meaning of Repeat All, nothing new) |
| Q2 | When the "Looks like a show" prompt appears | a) early in the first episode (10 s in); b) at the Up Next point, in place of the card | a) (the answer is known before the end, the end stays calm) |
| Q3 | "When playback finishes = Pause on the last frame" (pauses after **every** item in VLC) | a) autoplay off while set; b) autoplay on, and the pause only applies at the real end of the queue (needs a core-free workaround) | a) |
| Q4 | Hide UI (Ctrl+\\) at the card point | a) show the card anyway; b) no card, autoplay silently after the countdown | a) (the user should know something will change) |
| Q5 | The four new options in profiles | a) yes, like other playback options; b) no | a) |
| Q6 | Default in the vlc profile | a) Ask, as in Cone; b) Off | a) |
| Q7 | Casting (renderer) at the card point | a) card locally, VLC casts the next item; b) autoplay off while casting | a) |
| Q8 | Variant | A / B / C | A, with C's layout as the compact fallback |
| Q9 | "Still watching?" behaviour | a) next episode loaded paused at 0 under the card (keeps the player view); b) stop at the end and go Home | a) |

---

## 11. Found on the way (not part of this feature)

- **Repeat is saved inconsistently.**
  - The Repeat buttons (queue, mini queue, Customize) save `repeat` as the enum (0/1/2) and never `loop` (`playlist_controller.cpp:703-725`). After "Repeat All" from a button, the next start reads `repeat=true` and comes up as Repeat **One**; the Settings dropdown then also shows "One".
  - The right-click menu's Shuffle and Repeat save nothing (`setRandom`/`setRepeatMode`).
  - Worth a separate fix.
- **The Settings > Playback "Order" rows only change the saved config** (`RdEffects::setOption` → `putConfig`), so they take effect at the next start. The live state is the queue's buttons. Worth a hint or a live link.
- **The resume toast and lifted subtitles share the same band above the control bar** (7.1). The toast can cover a subtitle line.
- **`PlaybackSettingsPage.qml:19-23`** lists rows (Subtitle Timeline, Reverse) that do not exist.

---

## 12. Work packages (step 2)

| WP | What | Depends on |
|---|---|---|
| U1 | Episode parser + detection rules + unit tests (3.7, 8.6) | - |
| U2 | `RdUpNext`: show store, autoplay item, user-built queue detection, guards (section 8), resume / language options | U1 |
| U3 | Card (A + compact), prompt, placement rules (7.1), keyboard | U2 |
| U4 | Settings "Episodes" section, sidebar row, options, profiles | U2 |
| U5 | Library tag, queue label, mini player strip, thumbnail | U2 |
| U6 | Still watching, credits chapter point | U3 |

Then the independent review, qmlcheck and buildlists, one Linux sandbox run (every test in section 8 that Linux can do), and the Windows test of every row of section 8.

**Branch and release (Decision 71):** all of U1 to U6 live on one feature branch of their own (`wip/up-next`), not merged into `wip/next-test` or `redesign` before 1.0 is released. After 1.0 the branch is brought up to date with `redesign`, built and tested on its own, and merged for 1.1. The 1.1 release notes and the README list it under "Cone extras (not part of Juxtopposed's design)".
