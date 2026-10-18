# Sidebar must-haves (wip/sidebar-musthaves)

Base: wip/next-batch 514a7c399e. Nothing here is verified: no build was run and there are no screenshots. Offline compile checks only.

## What was built
1. **EQ preset curve icons** (rows 132, 133, 134). `widgets/native/rd_eq_curve_item.{hpp,cpp}` (RdEqCurveItem, a QQuickPaintedItem) draws the Figma "name=EQ" geometry: a 24x24 box, an FG/A2 baseline from x 1 to x 23 on y 12 (2 px, round caps), and Accent/Main lobes standing on y 10 (boost) or hanging from y 14 (cut), at most 6 px, about 0.6 px per dB. The curve is a monotone cubic through VLC's real band gains (`RdEffects.equalizerPresetBands`). Colours are palette bindings, so the accent colour and the light theme apply live. The `RdEqCurve.qml` rewrite (in the patch) wraps the item at 24x24.
2. **Video filter preset previews** (row 139, VIDEO_INDEX line 853). Engine only:
   - `player/rd_filter_math.{hpp,cpp}`: VLC's adjust, sepia, invert, posterize, transform and rotate math, run on a still RGBA frame.
   - `player/rd_filter_preview.{hpp,cpp}`: RdFilterPreview.
     - Grabs the frame on screen with VLC's thumbnailer, using its own input item copy, software decode, 2 decoder threads, local files only.
     - Applies the filter values on one lowest-priority worker thread, keeps an LRU cache of 32 previews and serves them through the `image://rdfilterpreview` provider.
     - Playback is never blocked.
   - `player/qml/RdFilterPreviewImage.qml`: one preview, 16:9 and 24 px tall, BG/B2 placeholder. It goes in an RdOptionRow `leading` slot.
3. **Crop link toggle** (row 344). `player/qml/VideoSettingsPage.qml`:
   - Figma active icon `link_state-active` (Accent/Main 2 px with the bar), default FG/A2, hover with the ToolButton colour set (6 % white, radius 4).
   - While linked, an edit keeps the ratio the two sides had when the link was turned on. If one side was 0, both stay equal.
   - The state is saved per row (`rd/cropLinked/0|1`).
   - Values go to VLC's real `crop-top/bottom/left/right` vout variables through `RdEffects.setVideoValue`.

## Hookups for the PC session
`git apply redesign/SIDEBAR_MUSTHAVES_HOOKUP.patch` (it applies cleanly on this branch):
- Makefile.am and meson.build: sources, moc entries and the QML file.
- mainui.cpp/.hpp: the RdEqCurveItem registration in VLC.Widgets, the RdFilterPreview singleton in VLC.Player and its image provider.
- The `widgets/qml/RdEqCurve.qml` rewrite.

Checks with the patch applied: buildlists 0, qmlcheck errors 1 / crashed 0 (401 files). Without the patch: the same results (400 files). privacycheck 0.

## Not done / open
- **Filter preview placement:** neither Figma nor the video shows a video filter preset list or its previews (line 853). No list exists in the Video tab, so the previews are not placed anywhere yet. This needs StickyGonzales's decision, with a Q image from the PC session. Usage: `RdFilterPreviewImage { values: ({ adjust: true, hue: 90 }) }` as an RdOptionRow `leading`.
- **Filters the previews leave unchanged:** sharpen, gradfun, grain, extract, colorthres and gradient. The previews also apply filters in one fixed order, while VLC uses the order they were turned on.
- **EQ shapes:** our shapes come from the real gains, so they differ in detail from Figma's hand-drawn icons. Compare them on the build.
- **Still to do on the build:** the video is not used here; the PC session checks rows 132-134 and 139 against it. Also to do: screenshots against Figma 2372:8487 and 543:995, the UX pass, 60 fps, the independent review and the VIDEO_INDEX status updates.

## Review

This is an independent review of the branch (commits d86caafb90 to 85a4d4e6e6) against CLAUDE.md, the Figma file and `redesign/tools/verify/spec/` (taken from wip/verify-spec: `eq-presets.json`, `eq.json`, `video-crop.json`, `icon-wrapper.json`). The review is offline only. Nothing is verified yet: there was no build and there are no screenshots.

### What was checked
- **EQ icons against Figma**
  - Geometry matches all 18 "name=EQ" icon variants: baseline x 1-23 on y 12, boost lobes ending on y 10, cut lobes starting on y 14, lobes up to 6 px tall.
  - Row layout matches the open "EQ presets" frame (2372:8490): icon at x 16 centred in the 44 px row, text at x 50, check at x 322. "None" has no icon and its text sits at x 16.
  - The colours are live palette bindings: FG/A2 (light theme #2E2E2E) and Accent/Main, which follows the accent setting through `orange500`.
  - Painting happens only when the gains, colours or size change, and each icon is one small texture. RdEqCurve is used in a single place (AudioSettingsPage).
- **Crop link against `video-crop.json`**
  - Layout matches: 141x33 boxes 8 px apart, button 30x32 at x 314 vertically centred, rows 16 px apart, paddings 6 and 16.
  - Icon colours match: default link FG/A2 at 1.5 px, hover 6 % white with radius 4 (the ToolButton colour set), active `link_state-active` in the live accent.
  - The ratio logic is safe: no division by 0, values clamped to 0 or more, the link state is remembered, and values go to VLC's real `crop-*` variables.
- **Filter math against the VLC sources**
  - `adjust`: the luma table and the U/V hue and saturation formulas match adjust.c and adjust_sat_hue.c exactly.
  - `sepia`, `invert`, `posterize`, `transform` and `rotate` use VLC's default values.
  - The value names match what RdPresets stores.
- **Preview engine**
  - Thumbnailer lifetime: the request is released on every path and the preparser is deleted before the in-flight request is released, as in the seek preview.
  - The worker-thread results are posted to the UI thread. The worker thread runs at the lowest priority. Decoding is software-only on the file's own input. Local files only.
  - The cache is mutex-guarded, and the image provider only copies small images from it.
- **Hookup patch**: it applies cleanly. Registrations go into the right modules, the image provider is added in the same place as the seek preview's, and both build lists contain all files.

### What was fixed (pushed)
- **b38bf8e296 Fast seek for the capture:** the preview now takes the keyframe at or before the current time instead of the exact frame. A precise seek decodes every frame from the previous keyframe in software, which costs seconds of CPU next to the playback on 4K or long-GOP files and can hit the 3 s timeout. That breaks the snappiness rule. A 24 px preview doesn't need the exact frame.
- **fde98a5d7c Cache size 32 to 256:** with more than 32 previews on screen, an evicted preview was asked for again and evicted another one, an endless loop of filter runs and binding updates. Each new frame empties the cache, so it only has to hold one frame's previews: about 4 MB at most.
- **721ee3898d Retake only after a size change:** a capture that ended after a media change (its cancel came too late) started an unrequested capture of the new file. Now only a preview size change during a capture retakes the frame.

Checks after the fixes:
- Offline compile with moc: 0 warnings.
- buildlists: 0 problems, with and without the patch.
- qmlcheck: errors 1 / crashed 0 (401 files with the patch, 400 without).
- privacycheck: 0 problems.

### What is left
- **Everything on the real build**:
  - side-by-side screenshots against "EQ presets" and "Video - Crop" (default, hover and linked);
  - the UX pass (keyboard toggling of the link, Tab order, tooltips);
  - the light theme and an accent change while the dropdown is open;
  - a 60 fps check while the EQ dropdown scrolls.
- **Filter preview placement** is still StickyGonzales's decision; there is no Figma or video reference. Until it is placed, the engine and RdFilterPreviewImage are unused.
- **Behaviours to know when placing the previews** (none of them are bugs right now):
  - All previews share one size: previews of two different sizes on screen at once would keep resetting each other's frame.
  - After a media change the previews show the placeholder until the list opens again.
  - A newer frame briefly shows the placeholder while its previews are made.
  - The fast seek can show a frame up to one keyframe interval before the playing position.
- **Small known differences, accepted:**
  - A row whose two crop values are both 0 links as equal, not by ratio.
  - A linked edit sets the two crop variables one after the other, so one frame may show only one side changed.
  - The EQ curve shapes come from the real gains and differ in detail from Figma's hand-drawn ones.
