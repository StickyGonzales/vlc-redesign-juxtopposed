# Round 4 mockup sources

`OSD_round4_cone_style.jpg` (one level up) is made from these files.

**Inputs** (not committed). Put them in the folder above `round4/`, as `build.py` reads them:
- `dl/f_000310.png`: Sintel at 3:10, taken with `ffmpeg -ss 00:03:10 -i https://download.blender.org/durian/movies/Sintel.2010.1080p.mkv -frames:v 1 f_000310.png` (Blender Foundation, CC BY 3.0).
- `top_*.png`, `bar_*.png`: the top bar (rows 0-80) and the control bar (rows 2050-2160) of `redesign/reference/figma/Player.png` and `Player - Light.png`.
- The SVGs: `modules/gui/qt/pixmaps/redesign/{volume_value-high,speed,subtitles}.svg` and `pixmaps/brand/public/cone-logo.svg`.

**Steps**
1. `build.py` embeds the inputs into `page.html`.
2. `shoot.js` renders the 48 windows (3 variants x 4 messages x dark/light x bars shown/hidden) at 1920 x 1080 with the preinstalled Playwright Chromium.
3. A short compose page (variant text, the 4 x 4 grid at quarter size, 1:1 crops) is shot by `shot2.js`.
