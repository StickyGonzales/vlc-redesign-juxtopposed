# The audio and subtitle track per show (branch wip/show-tracks)

Branch `wip/show-tracks`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. Cone extra (Decision 71, part of Up Next), **Cone build only** (`VLC_BRAND_PUBLIC`; the vlc profile is unchanged). Interface only: `modules/gui/qt`.

## What it does
- **Records the pick.** The user picks an audio track or a subtitle track, or turns subtitles off, while watching an episode of a detected show. Cone keeps that choice for the show.
- **What counts as one show:** the show's root folder, as for the learned credits point, so `Show/Season 1` and `Show/Season 2` count as one show.
- **Applies it to the next episodes** of the show as they start.
- **By language, not by track position:**
  - the track's **language tag**: `en`, `eng`, `English` and `en-US` are one language;
  - when it has none, a **language name that is a whole word of the track's title**, e.g. "1Vegamovies.tw - English";
  - a short code in a title is not taken for a language: ".tw" of a web address is not Twi.
- **No matching track** in an episode: that episode keeps its default.
- **Subtitles off** is remembered too.
- **Replacing:** a later pick in another episode replaces the saved choice.
- **Plain films** (no detected show) are never touched.
- **Autoplay off:** the show is detected and its tracks applied with "Play episodes in a row" Off too.
- **Forget all** (Settings > Playback > Episodes > Remembered shows) also forgets the tracks.
  - The row says e.g. "1 show: 1 autoplay, 0 never; tracks for 1 show".
  - It stays usable with autoplay off when tracks are remembered.

## Decision: built on Up Next, not on the per-show presets
- **What the presets store** (`RdPresets`, PRESETS_NOTES.md): VLC's track options, `sub-track` / `audio-track` (by position) and `sub-language` / `audio-language` (language codes).
- **Why they don't fit:**
  - those only change when the user edits them, and only for a preset linked to a folder;
  - they do not record the pick in the tracks popup;
  - a position is wrong when the next episode's tracks come in another order;
  - VLC's language option does not read a language out of a track name, and has no "subtitles off".
- **Used instead:** Up Next's show detection, which already treats season folders as one show and has the show store and Forget all.
- **Together:** a folder-linked preset's track options still set VLC's default at the start; the remembered pick is applied after it, so the pick wins.

## How it works
| Part | File |
|---|---|
| Language keys and matching (a table of about 55 languages with codes and English / native names) | `player/rd_show_tracks.*`, QtCore, unit test `tests/test_rd_show_tracks.cpp` (33 checks) |
| The track lists' language and VLC name as roles (`language`, `title`) | `player/input_models.*` |
| Recording, applying, storing | `player/rd_up_next.*` |
| The Forget all row | `dialogs/redesign/settings/pages/SettingsPlaybackPage.qml` |

- **Applying:** when a file starts, the saved choice is applied 0.4 s after its track lists stop changing, and once the show is known. It is applied again for tracks that arrive while the file starts (an external subtitle file VLC selects by itself), changing only what differs.
- **Recording:** a change of the selection counts as the user's only after the selection has settled (1.5 s after the apply). That covers the tracks popup, its "None", and the hotkeys (V, B). It never covers VLC's own choice at the start or Cone's own apply. A list update that leaves the same track selected is not a pick.
- **Stored** in `rd-shows.json` (the Up Next store), under `"tracks"`: `{ "<show root>": { "audio": "eng", "subtitles": "eng" | "off", "name": "…" } }`.
- **The log** (with "Save a log" on) says what happened:
  - `up next: tracks for the show saved: audio eng`
  - `up next: tracks for the show applied: audio eng (track 3), subtitles off`
  - `… audio eng not in this episode`

## Checks
- **Unit test** `test_rd_show_tracks`: 33 of 33 (tags, names in titles, ".tw" not Twi, tag over title, track orders, a missing language).
- **Static checks:** `qmlcheck.py` errors 0 on the changed page; `buildlists.py` 0 problems; `privacycheck.py` 0 problems.

## Runs
| Run | Head | Result |
|---|---|---|
| build-linux #77 | 10cf1a2b6c | green, smoke included |
| build-windows #174 (run 41527348895) | 10cf1a2b6c | green, smoke included |

**Linux sandbox on build-linux #77** (generated 40 s MKV episodes, the first audio and subtitle track the default in each, picks made through VLC's cli interface like a hotkey): **21 of 21**.
| Episode | Tracks | Result |
|---|---|---|
| S01E01 | audio Hindi, English; subtitles Hindi, English | defaults Hindi; English audio and subtitles picked → saved `audio eng`, `subtitles eng` |
| S01E02 | audio Tamil, Hindi, **English**; subtitles Tamil, **English** | English audio (track 3) and English subtitles (track 2) applied |
| S01E03 | no language tags; "1Vegamovies.tw - Hindi / - English" | English audio and subtitles found by their names |
| S01E04 | no English (Hindi + an untagged track) | the defaults stay (Hindi), logged "not in this episode"; subtitles turned off → saved `subtitles off` |
| Season 2 / S02E01 | audio Spanish, **English**; subtitles English (on by default) | the same show: English audio applied, subtitles off applied |
| a plain film | Hindi, English | its defaults stay; a pick there is not saved |
| restart | — | `rd-shows.json` holds one show (`audio eng`, `subtitles off`); after a new start S01E02 gets them; picking English subtitles there replaces "off" |
| autoplay off | `--no-qt-autoplay-next` | S01E03 still gets English audio and subtitles |

Not run in the sandbox: Forget all in Settings (retest step 6).

## Windows retest (PC session)
Build: build-windows #174 (or `gh workflow run build-windows.yml --ref wip/show-tracks`), Cone (portable).
- **Test folder:** `Show/Season 1/Show S01E01.mkv` … `S01E03`, `Show/Season 2/Show S02E01.mkv`, with Hindi and English audio and subtitles in different orders. The dual-audio files from the report do: "1Vegamovies.tw - Hindi / - English".
- **A plain film** with two audio tracks.

1. **Pick.** In S01E01, open the audio tracks popup, pick English; open the subtitle tracks popup, pick English.
2. **Next episode.** Play S01E02, in another track order: English audio and English subtitles are already checked in the popups.
3. **Names only.** An episode whose tracks have no language, only names ("1Vegamovies.tw - English"): English is checked.
4. **Off.** In S01E02, subtitles > None. Play S01E03: no subtitles. Play S02E01 (Season 2): English audio, no subtitles.
5. **Missing language.** An episode without English audio: its default audio plays, nothing breaks.
6. **Forget all.** Settings > Playback > Episodes > Remembered shows shows "tracks for 1 show"; Forget all. The next episode starts with its own defaults again.
7. **A plain film.** Pick its second audio track, then open another episode of the show: the show's choice is unchanged. Open the film again: its own default plays.
8. **Hotkeys.** In an episode press V (next subtitle) and B (next audio): the next episode gets those languages.
9. **Restart.** Quit Cone, start it, open an episode: the choice is still applied.
