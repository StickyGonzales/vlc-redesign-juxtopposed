# Verification spec (format 1)

Machine-readable design spec for the verification harness (redesign/STATUS.md, priority 2). It is
generated from the Figma file. **Don't edit these files by hand**: change
`redesign/tools/verify/make_spec.py` (or its inputs) and run it again from the repo root:

    python redesign/tools/verify/make_spec.py

Inputs:
- `redesign/reference/figma/figma_file.json` (the Figma file)
- `redesign/reference/figma/styles.txt` (colour values)
- `redesign/FIGMA_FLOWS.md` ("Frame to PNG map": node id to PNG name)
- `redesign/VIDEO_INDEX.md` (the rows and the Figma PNGs each one cites)

The output is sorted and has no timestamps, so a rerun with the same inputs gives the same files.

## Files

- `index.json`: tokens, the list of frames, the rows they map to, and what could not be mapped.
- `<png-name>.json`: one file per Figma frame or component set that at least one VIDEO_INDEX row
  cites. The file name is the PNG name in lower case, with every run of characters other than
  `a-z0-9` replaced by `-` (`Player - customize-3.png` becomes `player-customize-3.json`, and
  `Add Subtitles to Playlist/Folder-2.png` becomes `add-subtitles-to-playlist-folder-2.json`).

## index.json

| Key | Meaning |
|---|---|
| `format` | 1 |
| `source` | the input files and the Figma file's name, version and last-modified time |
| `png_dir`, `png_scale` | where the Figma PNG exports are, and their scale (2: a 1920x1080 frame is a 3840x2160 PNG) |
| `tokens` | every colour token: `{"FG/1": {"dark": "#EAEAEA", "light": "#111111", "light_figma": "#EAEAEA", "light_source": "Decision 33"}}`. `dark_alpha` / `light_alpha` are given for the "Transparent" tokens. `Accent/Option/*` are the accent choices of Decision 15 (one value for both themes). |
| `frames` | `[{file, node, name, png, kind, size, theme, rows, elements, masked}]`. `kind` is `frame` (a screen) or `component_set` (component states). `rows` lists the VIDEO_INDEX row numbers that cite the PNG. |
| `unmapped_frames` | top-level Figma layers that no row cites, so they have no spec file |
| `rows` | `{"<row number>": {id, area, item}}` for every row in a spec |
| `rows_without_figma_frame` | rows that cite no Figma PNG ("none (video only)" and similar), so the spec can't check them |
| `unknown_png_references` | PNG names in VIDEO_INDEX that match no export (empty when clean) |

## Frame file

```json
{
 "format": 1, "node": "187:328", "name": "Player", "png": "Player.png", "png_scale": 2,
 "kind": "frame", "size": [1920, 1080], "theme": "dark", "rows": [20, 21, 31],
 "background": [{"color": "#000000"}, {"type": "image"}], "background_mask": "image",
 "elements": [ ... ]
}
```

A `component_set` file has `variants` instead of `background` / `elements`:
`[{node, name, props, bounds, fills, radius, elements}]`. `props` are the variant's properties (`{"Property 1": "queue"}`), and `bounds` is the variant's place in the set's PNG. The bounds of its elements are relative to the variant.

`theme` is `light` when at least a fifth of the frame's colour styles are Light ones (only
`Player - Light`), `dark` otherwise.

## Element

| Key | Meaning |
|---|---|
| `id`, `name`, `type` | Figma node id, layer name, node type (`frame`, `instance`, `text`, `rectangle`, `vector`, ...) |
| `path` | meaningful ancestor names, joined with ` / `. Generic layer names ("Frame 12", "Group 3") are left out; icons show as `Icon:<name>`, e.g. `Controls / Icon Wrapper / Icon:subtitles`. |
| `bounds` | `[x, y, w, h]` in Figma units (1 unit = 1 px at 100 % scale), relative to the frame's top-left (or to the variant's in a component set). Multiply by `png_scale` for the PNG. |
| `clipped` | `true` when the element sticks out of the frame: `bounds` are not clipped, only the part inside the frame is visible |
| `component`, `variant` | for component instances: the component set and its variant properties |
| `icon` | for `Icon` instances: the icon name. Icons are leaves: their inner vectors are not listed. |
| `radius` | corner radius; a list `[top-left, top-right, bottom-right, bottom-left]` when the corners differ |
| `fills` | list of paints. `{"token": "BG/A3", "dark": "#1B1B1B", "light": "#D5D5D5"}` when the file uses a colour style. `{"color": "#262626"}` when it doesn't, with `same_as_token` when the colour equals a token's dark value. `alpha` when the paint is translucent. `{"type": "image"}` for picture fills. `{"type": "gradient_linear", "stops": [...]}` for gradients. `style_theme` appears when the style is from the other theme than the frame. |
| `strokes`, `stroke_weight`, `stroke_align` | the border, same paint format |
| `effects` | `{"style": "bg blur"}` for a named effect style (values in styles.txt), otherwise a list of `{type, radius, color, alpha, offset, spread}` |
| `opacity` | layer opacity when below 1 |
| `translucent` | `true` when the element shows the video or the UI behind it (alpha fill, "Transparent" token, blur): compare its colour with a wider tolerance, or after compositing |
| `text` | `{content, font, weight, size, line_height, letter_spacing, align, case, color}`. `color` uses the paint format. |
| `mask` | the element shows sample content: compare its position and size, not its pixels. Reasons: `image` (video frame, thumbnails, cover art), `time`, `file name`, `count` ("15 items", "2 Bookmarks"), `sample name` (the design's example shows, songs, playlists, folders, chapters, tracks, presets, profiles), `seek bar content` (elapsed fill, handle, waveform and subtitle-timeline marks inside the seek track) |
| `brand` | `true` for texts and icons that name the app ("VLC Media Player", the VLC icon): the public profile shows Cone there (Decision 48). Compare against a vlc-profile build or mask them. |
| `rows` | suggested VIDEO_INDEX rows for this element (see below); missing when nothing matched, in which case use the frame's `rows` |

### How `rows` is suggested

The candidates are the rows that cite the frame's PNG, plus the rows that cite the PNG of a component set the element is an instance of, or sits inside (an icon inside `Controls` also gets the `Controls.png` rows as candidates).

Each candidate is scored by the words it shares with the element, each word weighted by how rare it is across all rows (idf):
- on the element side: name, path, component, variant, icon name, and the text when it isn't masked;
- on the row side: area, Item, and the note in brackets next to the PNG name.

The element keeps the best candidates that score at least 1.5 and at least 60 % of the best, at most 5.

This is a **suggestion** for the harness report: a person still confirms which row an element difference belongs to.
