# Up Next: Windows test steps (Cone extra)

**Cone extra (Decision 71):** "Autoplay next episode" is not part of Juxtopposed's design and is not part of beta 2 or 1.0. It lives on `wip/up-next` and is merged only after 1.0, for 1.1. The spec is `redesign/UP_NEXT_PLAN.md` (decisions in its section 10).

This file turns every row of the plan's conflict matrix (section 8, rows 1 to 117) into a test step for the Windows build. The **Linux** column holds the result of the same step in the Linux sandbox (`wip/up-next-linux`, a test-only branch that is never merged): `pass`, `fail` (with the bug), or `not run` with the reason.

## Setup

1. **Test media.** Generate it with ffmpeg (on PATH on the PC):
   `python redesign/tools/upnext_media.py <TEST_MEDIA_DIR>\builds\upnext-media`
   It makes, all generated (colour bars and a tone):

   | Folder | What it tests |
   |---|---|
   | `The Wand\Season 1`, `Season 2` | SxxEyy names, a season jump (S01E03 then S02E01), a "Credits" chapter at 2:45 of each 3:00 episode |
   | `The Wand\Extras` | an Extras folder: never a show, never next |
   | `Harbor Lights` | `1x01 - Pilot` names |
   | `Cartoon Time` | `Episode 1` names |
   | `Night Garden` | plain numbers `01.mkv` to `04.mkv` (10 min each: a weak pattern needs 10 min) |
   | `Music\Paper Moon\Second Album` | a music album: never a show |
   | `Podcasts\Talk Hour` | mp3 files named `S01E01`: audio never counts |
   | `Movies\Starfall (2010).mkv` | a single movie: never a show |

   The test show episodes are 3 minutes long, so the steps say 1:30 where the plan says 10:00. **E01, E02 ...** below are `The Wand S01E01 ...` unless a step names another folder.
2. **Build.** The build under test in `<TEST_MEDIA_DIR>\builds\current\` (portable), as usual.
3. **Both profiles.** The Cone build starts in "Ask for each show". The vlc profile (non-public build) starts Off (Q6); row 99 checks it.
4. **Fresh answers.** Settings > Playback > Episodes > Remembered shows > **Forget all** before each group, so the prompt shows again.
5. **Reaching the card fast:** click the seek bar near the end (2:45 for The Wand), or press Ctrl+Right (long jump) a few times.

## Quick look first (the main flow)

| Step | Expected |
|---|---|
| Open `The Wand S01E01` (double-click in Explorer). | Plays. After 10 s: the prompt "Looks like a show. Play episodes in a row?" with "The Wand · you can change this in the Playback tab", bottom centre. |
| Click **Yes**. | The prompt goes. The queue (and mini queue) shows E02 with "Autoplay" next to its duration. Sidebar > Playback shows "Autoplay this show" ON with the tv icon and "The Wand". |
| Seek to 2:48. | The Up Next card at the bottom right, 24 px above the control bar: thumbnail of E02, "Up next", "The Wand", "S01E02 · The Second Spark", "Playing in N s", Play now, Cancel, the countdown line. |
| Wait. | E02 starts by itself, at 0:00, no resume toast. |
| Seek E02 to 2:48 and click **Play now**. | E03 starts at once; E02 counts as watched in the library. |
| At E03's end. | The card says "Up next · Season 2", S02E01. |
| Open the library (compact) during E03. | E03's row is the playing one, S02E01 carries the "Up next" tag. |
| Make the window narrow (video area under 900 px) at the card. | The card becomes the 60 px pill: small thumbnail, "Up next in N s", the episode, Play now and the dark close button. |
| Open the full library at the card. | The mini player shows the Up Next strip on the picture: Play now, close, countdown line. |
| Settings > Playback > Episodes. | Autoplay next episode (Ask for each show), Countdown, Show Up Next, Ask if I'm still watching after 3 episodes, Remembered shows "1 show: 1 autoplay, 0 never" + Forget all. Off dims the four rows under it. |

## Conflict matrix

### 8.1 Settings > Playback

| # | What | Steps | Expected | Linux |
|---|---|---|---|---|
| 1 | Continue where you left off = Ask | Watch E02 to 1:30, play E01 to its end with AP on. | E02 starts at 1:30, no resume toast. | @1@ |
| 2 | Continue where you left off = Always | Same as 1. | E02 at 1:30. | @2@ |
| 3 | Continue where you left off = Never | Same as 1 with Never. | E02 at 0:00. | @3@ |
| 4 | Privacy > Remember the playback position off | Toggle off, repeat 1. | 0:00. | @4@ |
| 5 | Start playing as soon as a file opens (`playlist-autostart`) off | Turn off, open E01 (no start), press Play, run to the end. | E02 follows. | @5@ |
| 6 | Default playback speed | Speed 1.5x, reach the card. | "Playing in 10 s" counts in real seconds. | @6@ |
| 7 | Pause when another app uses audio | Card showing, start audio in another app. | Cone pauses, the countdown freezes, resumes with playback. | @7@ |
| 8 | Preferred video quality / menu language | Smoke test: E02 plays with the same preference. | As the rule: apply per file as today | @8@ |
| 9 | Default audio track / Default subtitle track | Pick Japanese audio + English subs in E01, let E02 start. | Japanese + English. | @9@ |
| 10 | Repeat = One (Settings, saved) | Repeat One, play E01. | no card, E01 starts again. | @10@ |
| 11 | Repeat = All | Repeat All, play the last episode of a 2-episode test show. | after the last episode, the queue's first item (the episode first opened) plays. | @11@ |
| 12 | Shuffle on | Shuffle on, play E01 to the end. | no card, behaves as today. | @12@ |
| 13 | Stop after each item (`play-and-stop`) | Turn on (restart), play E01. | no card, stops. | @13@ |
| 14 | When playback finishes = Pause on the last frame (`play-and-pause`) | Set, restart, play E01. | no card, no autoplay item; VLC pauses on the last frame. | @14@ |
| 15 | When playback finishes = Quit Cone (`play-and-exit`) | Set, restart, play E01. | no card, Cone quits at the end. | @15@ |
| 16 | Seek precisely / thumbnails while scrubbing | Seek into the last seconds. | the card shows with the time left. | @16@ |
| 17 | Load matching .mkv files from the same folder | Smoke test. | Nothing changes for autoplay. | @17@ |
| 18 | More playback options: `start-paused` | `--start-paused` on the command line. | no card. | @18@ |
| 19 | `input-repeat` (repeat N times) | `--input-repeat=1`. | the episode repeats, no card. | @19@ |
| 20 | `start-time` / `stop-time` / `run-time` | `--start-time=60 E01.mkv`. | no card, no autoplay item. | @20@ |
| 21 | `restore-playback-states` (speed, tracks per media) | Smoke test with it on. | As the rule: VLC's per-media states win for the media they belong to | @21@ |

### 8.2 Other Settings pages

| # | What | Steps | Expected | Linux |
|---|---|---|---|---|
| 22 | General: Theme / Accent | Switch theme while the card shows. | it recolours. | @22@ |
| 23 | General: Show confirmation and error dialogs | Rename E02 to `.part`, play E01. | the card offers E03. | @23@ |
| 24 | Interface: Play video inside main window off | Turn off (restart), play E01. | the card is in the main window. | @24@ |
| 25 | Interface: Resize window to fit video | Smoke test. | As the rule: as today | @25@ |
| 26 | Interface: Auto-hide the controls / Hide after / fullscreen controls | Fullscreen, mouse still. | the card shows with the bars hidden. | @26@ |
| 27 | Interface: Start in compact mode / minimal view | Minimal view, reach the card. | As the rule: the card shows in the minimal view too (compact layout) | @27@ |
| 28 | Interface: Show a system tray icon / popup when the track changes | Smoke test. | As the rule: as today | @28@ |
| 29 | Interface: Pause video when window is minimized | Minimize during the card. | on restore the countdown continues. | @29@ |
| 30 | Privacy: Save recently played items off | Turn off, run 1. | E02 at 0:00. | @30@ |
| 31 | Privacy: Never remember items matching | Smoke test. | As the rule: as today | @31@ |
| 32 | Controls: shortcuts | During the card: Space (pause), N (next now), Tab to Cancel + Enter. | As the rule: N = Play now; P = previous (goes to the previous episode as today); Space pauses (the card never takes focus); Escape cancels only with the card focused | @32@ |
| 33 | Controls: single / double click on the video | Click Cancel. | no pause toggle. | @33@ |
| 34 | Controls: scroll wheel | Wheel over the card. | no volume change. | @34@ |
| 35 | Controls: Web remote control | Smoke test. | As the rule: the remote can press Next (= Play now) | @35@ |
| 36 | Video: Start videos in fullscreen | Fullscreen at the card, let it advance. | stays fullscreen, no flash to Home. | @36@ |
| 37 | Video: aspect, crop, zoom, deinterlace (settings defaults) | Set crop in E01 without a preset. | E02 not cropped. With a folder preset that crops: cropped. | @37@ |
| 38 | Audio: device, volume, night mode, normalisation, equalizer | Smoke test. | As the rule: carry as today | @38@ |
| 39 | Audio: Visualizer | No step of its own. | Nothing changes for autoplay. | @39@ |
| 40 | Subtitles: Enable subtitles / language / size / position (`sub-margin`) | Subtitle position "high" and size large: the card sits above them. | As the rule: **R4**: the card band is computed from `sub-margin` + lift + 2 lines at the current size | @40@ |
| 41 | Subtitles: Show feedback for shortcuts (`osd`) | Smoke test. | As the rule: as today | @41@ |
| 42 | Subtitles: Show filename when a video starts | Smoke test. | As the rule: as today (Decision 69: off by default in Cone) | @42@ |
| 43 | Subtitles: OpenSubtitles / Add Subtitles rules | Folder subtitle rule set: E02 gets its subtitle. | As the rule: per-folder rules apply to E02 by themselves | @43@ |
| 44 | Library: Only allow one Cone window / Add to the playlist instead of replacing | Play E01 (AP on), double-click another video in Explorer. | the autoplay item is gone and the other video plays next. | @44@ |
| 45 | Library: When opening a folder | Open Folder on the show. | no card; all episodes play as today. | @45@ |
| 46 | Library: Use the media library (always on) | Play a show outside the library folders. | card with a generated thumbnail. | @46@ |
| 47 | Network: caching, proxy | Play an HTTP stream named S01E01. | no card. | @47@ |
| 48 | Performance: hardware decoding, threads, priority | Smoke test. | Nothing changes for autoplay. | @48@ |
| 49 | Recording: recording at an episode end | Record in E01 until the end. | one file for E01, E02 plays unrecorded. | @49@ |
| 50 | Recording: cast / renderer | Cast E01, reach the card. | the card on the computer, E02 plays on the cast device. | @50@ |
| 51 | Extensions | No step of its own. | Nothing changes for autoplay. | @51@ |

### 8.3 Sidebar tabs

| # | What | Steps | Expected | Linux |
|---|---|---|---|---|
| 52 | Playback: Show Waveform / Metadata / Statistics | Statistics open across the switch. | Nothing changes for autoplay. | @52@ |
| 53 | Playback: **Sleep Timer** 15-60 min | 15 min timer timed to fire during the card. | stop, no next episode. | @53@ |
| 54 | Playback: **Sleep Timer = End of current file** | Set it, reach the end. | no card, stop. Set, then back to Off. Expect: the card appears. | @54@ |
| 55 | Playback: Audio Visualizer | No step of its own. | Nothing changes for autoplay. | @55@ |
| 56 | Playback: Speed | As 6. | As the rule: countdown in real seconds | @56@ |
| 57 | Playback: **Autoplay this show** (new) | Toggle off during the card. | the card closes, nothing queued. Toggle on again. Expect: item and card back. | @57@ |
| 58 | Video tab: Flip, Rotate, Zoom, Aspect, Crop, filters | Rotate 90° in E01 without a preset. | E02 not rotated. | @58@ |
| 59 | Audio tab: track, language, stereo mode, delay, EQ, filters | Audio delay +200 ms in E01, no preset. | E02 at 0 ms. With preset: the preset's delay. | @59@ |
| 60 | Subtitles tab: track, delay, speed, duration factor, style | Sub delay in E01. | E02 at 0 (or the preset's). | @60@ |
| 61 | Preset selector: Use for This Folder | Link a preset at "The Wand" root, let S01E15 → S02E01 run. | the preset is still active. | @61@ |

### 8.4 Queue, playlists and the playback flow

| # | What | Steps | Expected | Linux |
|---|---|---|---|---|
| 62 | Queue panel: "+" / drag to the queue (W5.9) / library Add to Queue | AP on, drag E05 into the queue during E01. | E05 plays next, no card. | @62@ |
| 63 | Queue: remove (−), reorder, sort, clear | Remove the "Autoplay" row. | no card at the end. | @63@ |
| 64 | Queue: the autoplay item's row | Double-click the row. | E02 plays. | @64@ |
| 65 | Queue: Repeat button (None → All → One) | Click Repeat to One during the card. | the card closes. | @65@ |
| 66 | Queue: Shuffle button | Shuffle during the card. | the card closes, the item is removed. | @66@ |
| 67 | Library playlists: Play | Play a playlist of episodes. | no card. | @67@ |
| 68 | Library: Play on one episode / click a row | Click E03 in the compact library. | autoplay item E04. | @68@ |
| 69 | Library: Play on a folder / Shuffle | Play on S01. | all play, no card. | @69@ |
| 70 | Library: Continue Watching card | Continue E03 from Home. | E04 queued. | @70@ |
| 71 | Library: Recent | Play E03 from Recent. | As the rule: eligible | @71@ |
| 72 | Library: mark watched / unwatched | Mark E05 watched. | still next after E04. | @72@ |
| 73 | Library: Unwatched First sorting | Unwatched First on. | the tagged row is first (`08-…`). | @73@ |
| 74 | Library / compact library open during the card | Open the compact library at the card point. | the card is fully visible. | @74@ |
| 75 | Previous / Next buttons | Press Next during E01. | E02 plays. | @75@ |
| 76 | Stop button / press-and-hold Play | Stop during the card. | Home, no next episode, the queue holds only E01. | @76@ |
| 77 | A-B loop active at the end | Set A-B around the last minute. | it loops, no card. | @77@ |
| 78 | Bookmarks | Bookmark in E01, play E02. | E02's tab is empty. | @78@ |
| 79 | Chapters | Show Up Next = credits, a file with a "Credits" chapter. | the card at that chapter, Play now skips the rest and E01 counts as watched. | @79@ |
| 80 | Speed (sidebar slider / Faster / Slower) | No step of its own. | As the rule: as 6 | @80@ |
| 81 | Frame step / Trickplay reverse | No step of its own. | As the rule: Reverse is postponed (Decision 29) | @81@ |
| 82 | Subtitle timeline (P3-16 / P4-35) | Timeline on, E02 starts. | E02's cues. | @82@ |
| 83 | On-screen messages | Press N at the card. | no overlap. | @83@ |
| 84 | The resume toast | Open E01 with a saved spot (Ask). | toast first, prompt after. | @84@ |
| 85 | Mini player (library full view) | Open the full library during the card. | the strip in the mini player. | @85@ |
| 86 | Mini queue | Open the mini queue. | E02 "Autoplay". | @86@ |
| 87 | Fullscreen | As 36. | As the rule: the card in fullscreen at the same rules (7.1); no exit to Home between episodes (it's a queue move, not a stop) | @87@ |
| 88 | Hide UI (Ctrl+\\) | Hide UI, reach the card. | only the card appears; Play now and Cancel work; after it, the UI stays hidden. | @88@ |
| 89 | Customize Player: Next / Previous / A-B / Bookmark / Chapters buttons | No step of its own. | As the rule: as the matching rows | @89@ |
| 90 | Profiles (main "..." menu) | Switch profile with autoplay Off in it. | autoplay switches to Off with that profile, and back with the other. | @90@ |
| 91 | Right-click > Playlist > Shuffle / Repeat | Right-click Repeat One during the card. | the card closes. | @91@ |
| 92 | Right-click > Playlist > **Quit at the end of play queue** | Turn it on during E01. | no card, Cone quits after E01. | @92@ |
| 93 | Right-click > Playback > Title / Chapter / Program | No step of its own. | Nothing changes for autoplay. | @93@ |

### 8.5 Process, command line, profiles

| # | What | Steps | Expected | Linux |
|---|---|---|---|---|
| 94 | Quit watchdog (PR #34) | Close Cone at the card. | quits in under 5 s, E01's position saved. | @94@ |
| 95 | Command line `--play-and-exit` | `cone --play-and-exit E01.mkv`. | quits after E01, no card. | @95@ |
| 96 | Command line `--play-and-stop`, `--play-and-pause`, `--random`, `--loop`, `--repeat`, `--start-paused`, `--input-repeat`, `--start-time`, `--stop-time`, `--run-time`, `--no-playlist-autostart` | Each option once with E01. | no card (`--loop`: as row 11). | @96@ |
| 97 | Command line: several files | `cone E01.mkv E03.mkv`. | E01, E03, no card. | @97@ |
| 98 | Command line / Explorer: one file | Double-click E01 in Explorer. | E02 queued, card at the end. | @98@ |
| 99 | vlc profile (non-public build) | Run the vlc build on a fresh profile. | Settings > Playback > Autoplay next episode = Off, no prompt, no card. | @99@ |
| 100 | First run / onboarding (`--qt-privacy-ask`) | First run with E01 on the command line. | onboarding first, prompt after. | @100@ |

### 8.6 Detection edge cases (each a test)

| # | What | Steps | Expected | Linux |
|---|---|---|---|---|
| 101 | Single movie | Play `Inception (2010).mkv`. | no prompt, card, tag or row | @101@ |
| 102 | Two-part movie | `Dune Part One/Two`. | no | @102@ |
| 103 | Phone videos | `VID_2024…mp4` × 5. | no | @103@ |
| 104 | OBS recordings | 3 OBS-named files. | no | @104@ |
| 105 | Short clips | 5 numbered 30 s clips. | no | @105@ |
| 106 | Music | an album folder. | no | @106@ |
| 107 | Podcast mp3 with S01E01 names | 3 mp3 files. | no | @107@ |
| 108 | Extras folder | Play `Extras/Making of.mkv`; from E15 the next is never in Extras. | no; never next | @108@ |
| 109 | Sample file | `…S01E03.sample.mkv` next to E03. | skipped | @109@ |
| 110 | Missing episode | Delete E05 (test copy). | E06 after E04 when E05 is missing | @110@ |
| 111 | Season jump | 2 season folders. | S02E01 after S01E15, "Season 2" | @111@ |
| 112 | Last episode | Play the last one. | no card | @112@ |
| 113 | Multi-episode file | `S01E01-E02.mkv` then E03. | next = last + 1 | @113@ |
| 114 | Unfinished download | `E02.mkv.part`. | skipped | @114@ |
| 115 | Very long names | A 120-character title. | card text wraps to 2 lines then elides | @115@ |
| 116 | Plain-number folder | `Anime/01..12.mkv`. | show when the folder supplies the title | @116@ |
| 117 | Same folder, two shows | `A S01E01..3` + `B S01E01..3` in one folder. | each its own sequence (by stem) | @117@ |
