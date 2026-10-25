# Verification spec (branch wip/verify-spec)

Status: generated data. **Nothing is verified**, and no VIDEO_INDEX status was changed.

Base: `origin/wip/next-batch` (514a7c399e). Only new files were added under `redesign/tools/verify/` and in this note. No QML, player code or harness code was changed (the harness doesn't exist yet).

## 1. What was made

| File | What |
|---|---|
| `redesign/tools/verify/make_spec.py` | Generator (Python 3, standard library only). It reads `figma_file.json`, `styles.txt`, the "Frame to PNG map" in `FIGMA_FLOWS.md` and `VIDEO_INDEX.md`, and writes `spec/`. Same inputs, same output (checked by running it twice and diffing). |
| `redesign/tools/verify/spec/index.json` | Colour tokens (dark and light), the list of frames with their rows, the rows table, and what couldn't be mapped. |
| `redesign/tools/verify/spec/<png>.json` | One spec per mapped Figma frame or component set (99 files). |
| `redesign/tools/verify/spec/README.md` | The format. |

Regenerate after any change to the Figma file, `styles.txt`, `FIGMA_FLOWS.md` or the Figma PNGs column of VIDEO_INDEX:
`python redesign/tools/verify/make_spec.py` (from the repo root).

Each element lists:
- **Where:** Figma id, layer name, readable path (e.g. `Controls / Icon Wrapper / Icon:subtitles`), bounds relative to the frame, corner radius.
- **Colours:** fills, strokes and effects; text colour too. A colour is given as a token when the file uses a colour style (`{"token": "BG/A3", "dark": "#1B1B1B", "light": "#D5D5D5"}`), otherwise as a raw colour, with the matching token when one exists. Light uses Decision 33 for FG/1 and FG/2.
- **Text:** content, font, weight, size, line height, letter spacing and alignment.
- **Component:** component set and variant; the icon name for icons.
- **Flags:** `mask` (sample content), `translucent` (shows what's behind), `brand` (names the app).
- **`rows`:** suggested VIDEO_INDEX rows.

## 2. Coverage

- **99 specs:** 67 screen frames and 32 component sets, 8,909 elements in total. 1,699 elements carry `mask`:
  - 1,074 seek bar content: the elapsed fill, waveform bars and subtitle-timeline marks;
  - 365 file names;
  - 98 sample names;
  - 92 times;
  - 51 images;
  - 19 counts.
- **250 of the 361 VIDEO_INDEX rows** are in a spec:
  - 137 cite a screen frame;
  - 113 only cite a component set (states of controls, menus, dropdowns, icons).
- **Elements with suggested rows:** 5,544 of the 8,909. The others fall back to their frame's rows.

| Area | Rows in a spec | Rows |
|---|---|---|
| library | 44 | 58 |
| control bar | 40 | 52 |
| settings | 40 | 50 |
| other | 10 | 39 |
| audio/video | 25 | 35 |
| subtitles | 15 | 28 |
| sidebar | 17 | 24 |
| menus | 17 | 22 |
| top bar | 14 | 19 |
| visual style | 14 | 18 |
| playlists/queue | 14 | 16 |

Screens covered:
- **Player:** the 7 Player frames, Player - Music (2), Player - hide UI, Player - Light, Player - customize (9).
- **Settings and dialogs:** the 19 Settings frames, Add Subtitles (4), Keyboard Shortcuts, Open network stream, new playlist.
- **Onboarding:** 11 frames.
- **Component sets:** Icon, Icon Wrapper, Controls, sidebar, Miniplayer, menu, right-click menu, Profiles, the context menus, Sorting and View Options, the Audio / Video filter cards, the dropdowns and others.

## 3. Not mapped

**Figma layers without a spec** (`unmapped_frames` in index.json):

| Layer | Node | Why |
|---|---|---|
| context menu | 2107:5903 | No row cites `context menu.png`. The rows cite the other context menus (folder, file, playlist) and the right-click menu. |
| target | 1959:5325 | Component set, no row cites it; it's the "To This File / To This Folder" switch inside Add Subtitles, so it's checked there. |
| origin | 1963:5465 | Same for "From Computer / From OpenSubtitles". |
| option | 2107:5935 | The menu row component; the menus that use it have specs. |
| Components | 6841:16196 | Text label of the Figma page. |
| Designs | 6841:16197 | Text label of the Figma page. Rows 237 (P6-21) and 238 (IB-34) cite it as "Designs.png?": the full-library home has no Figma frame. |

**Rows without a Figma frame:** 111 (`rows_without_figma_frame`). About 40 of them are context rows: old VLC, B-roll, sponsor, memes, survey. The rest are things the video shows that Figma doesn't have (Decision 21): the full library pages, the notifications, the sleep timer and most Step 2 behaviour. The spec can't check those; they stay manual or need their own reference crops from the video, which stay local only.

**Not in the spec at all:**
- Behaviour (hover, open/close, animation timing): the harness drives that itself.
- The insides of icons: an icon is one leaf element; compare it as a crop.
- Prototype interactions: they are in FIGMA_FLOWS.md.

## 4. How the harness should use it

1. **Pick the frame.** For each screen or state the harness drives, take its spec file from `index.json` (`frames[].png` matches the Figma PNG name; FIGMA_FLOWS.md says which prototype state each PNG is). A component state uses the component set file, picking the variant by `props` (e.g. `Controls` with `{"Property 1": "queue"}` for the queue panel).
2. **Same scale.**
   - Grab the window at 100 % Windows scaling and the frame's size (1920x1080 for the player screens). Scale the Figma PNG by 1 / `png_scale`. Or grab at 200 % and compare with the PNG as is.
   - For dialogs (Settings 1048x865 and the others), grab only the dialog and line it up by its top-left corner.
3. **Compare element by element**, not the whole frame:
   - crop each element's `bounds` from both images;
   - skip the pixel comparison for `mask` elements, but still check their position and size where the app exposes them;
   - wider colour tolerance, or compare after compositing, for `translucent` ones;
   - compare `brand` elements only on a vlc-profile build;
   - the frame `background` with `background_mask: image` is the video: never compare it.
4. **Check the numbers too:** radius, text size and weight, and the token colours (for the light theme, compare with the `light` value). Where the app lets UI Automation read sizes and positions, compare those with `bounds` directly; that is exact where pixels are not (font hinting, antialiasing).
5. **Report by row:**
   - a difference is reported under the element's `rows` (or the frame's `rows` when the element has none);
   - rows whose elements all pass within tolerance go on the "auto-passed for review" list (STATUS.md priority 2);
   - nothing is marked verified automatically: a person confirms.
6. **Privacy:** screenshots stay local and are never committed (CLAUDE.md privacy rule); the spec itself holds only Figma data (CC BY 4.0).

## 5. Limits

- **Row suggestions are guesses.** They come from word matching between the element and the row text (README, "How `rows` is suggested"). Container elements often get the rows of the whole area; icons and labelled controls get specific rows. Treat them as hints.
- **Hand-kept sample list:** the "sample name" list (shows, songs, playlists, chapters, tracks, presets, profiles) is written in the generator from the strings the design uses. A new sample string added to Figma needs a line there.
- **Values not masked:** setting values the design shows in a demo state (for example `-4.000 s` delay, `1x` speed, slider values) are not masked. The harness must set the same state before comparing, or mask them in its own run config.
- **Bounds are Figma layout boxes:** for text they are the text box, not the ink, so compare text crops with some tolerance.
- **Theme:** one frame is light (`Player - Light`). For every other frame the light values in the spec are the token's light value, not something drawn in Figma.
