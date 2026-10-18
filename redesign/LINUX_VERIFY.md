# Linux verification (branch wip/verify-linux)

Screen-by-screen check of Cone on Linux: the GitHub-built AppImage of `wip/verify-linux` (= `wip/linux-build` + `wip/beta` + `wip/web-fixes-1`), run in the cloud sandbox. **Nothing here changes VIDEO_INDEX** and nothing is marked verified there: this is a Linux pass of the same QML the Windows build runs; the PC test stays the reference.

## How it was run
- Build: build-linux run RUN_PLACEHOLDER, artifact `cone-linux-appimage-x86_64` (AppImage unpacked once with `--appimage-extract`, then `AppRun`, as the sandbox has no FUSE).
- Display: Xvfb 1920x1080, 24 bit, 96 dpi (100 % scaling), openbox, software rendering (llvmpipe), test user in a D-Bus session, `--aout=dummy` (no sound card).
- Media (generated, no personal files): "Test Show/Season 1" with 3 episodes (1280x720, two audio tracks eng/jpn, two subtitle tracks eng/fre, chapters Winter / Spring / Summer), an external `.srt` per episode in another folder, 6 tagged songs with cover art (2 artists, 2 albums, 2 genres), a portrait clip, a letterboxed film with a very long name, an IPTV `.m3u`.
- Figma: the 2x PNG exports scaled to 1x, compared at the same scale with a screenshot of the same element.
- Each row: **Function** = used the controls and checked what the VIDEO_INDEX row says; **Looks** = compared with its Figma frame for layout, colours, fonts, icons, wording and spacing. Font smoothing differences between Linux and Windows are not counted.

Results: **pass**, **fail** (what is wrong, what Figma shows, likely file), **skip** (Windows only, needs her video, or a context row with nothing to build).

## Summary (one line per screen)

| Screen | Rows passed | Rows failed | Rows skipped |
|---|---|---|---|

## Results by screen
