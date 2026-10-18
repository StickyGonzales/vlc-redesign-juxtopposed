# BUILD_PLAN: VLC redesign build plan

Written 2026-10-12 from a read-only study of VLC master (HEAD a5538c557d276378d5ba0f8f8010a8b87eaa6f78) and the reference files. Read with `CLAUDE.md` (rules, decisions), `redesign/VIDEO_INDEX.md` (what to build, status), `redesign/FIGMA_FLOWS.md` (prototype behavior and exact specs).

Paths below are relative to the repo root; `Q/` = `modules/gui/qt/`.

## 0. Build order in two steps (Sticky, 2026-10-13)

The work packages below stay as defined in section 7; this section sets the order. Packages that mix both kinds of work are split into a Step 1 part (restyle / move what VLC already does) and a Step 2 part (functionality VLC does not have). Phase 1 (W1.1, CI build) is done.

### STEP 1, UI ONLY: the app looks and is laid out exactly like the video
Order (dependencies respected; lanes from section 4 still apply inside each group):
1. Foundation: W2.1 palette + Inter font + tokens, W2.2 accent color (VLC already has `qt-accent-color`; Step 1 = live recolor + the 9 options), W2.3 icons (Figma SVG export, accent-colorable), W2.5 component kit.
2. Player chrome: W3.1 top bar, W3.2 control bar, W3.3a thick seek bar, W3.4 cone volume (0-200%), W3.5 time labels (remaining time exists; click-to-type jump reuses VLC's seek), W3.6 per-bar show/hide, W3.7 inset video frame, W3.8 resume toast.
3. Panels and menus: W4.1 panel framework, W4.2 tracks popup, W4.3a Playback tab with existing options (speed, audio visualizer), W4.4 Video tab (existing transform / adjust / zoom / aspect / crop / HDR mode / renderer), W4.5 Audio tab (existing EQ + presets with curve icons, compressor, spatializer, widener, pitch, delay, stereo mode), W4.6 Subtitles tab (existing delay / fps / text scale / freetype options), W4.8 Queue / Bookmarks / Chapters sidebar (existing playlist, bookmarks, chapters), W4.9 main menu, W4.10 right-click menu incl. Hide UI (Ctrl+\) and wiring of the prototype placeholder links to real actions.
4. Library: W5.1 library shell (rail, compact panel, full window, back/forward, breadcrumb), W5.3a music views (songs / albums / artists / genres, music player view with cover), W5.4a network streams list + Open Network Stream dialog restyle, W5.5a playlists list + New Playlist dialog restyle + add to playlist, W5.6a Home and Recent (existing ML history), W5.7a sort / view mode / search / row and grid states / file and folder menus, W5.8a mini player restyle, W5.9 drag from library to queue (existing drag and drop).
5. Settings and dialogs: W6.1 settings dialog shell, W6.2 settings pages mapped to existing options, W6.3 Keyboard Shortcuts dialog, W6.4 open dialogs split and restyled.
6. Customization and onboarding: W8.1a Customize Player restyle of the existing toolbar editor, W8.3 onboarding (replaces the existing first-run wizard), W8.4 light theme (last).

### STEP 2, NEW FEATURES: everything VLC does not have today
1. W3.3b seek preview thumbnails (thumbnailer).
2. W4.3b Playback tab new items: sleep timer, Show Statistics, Show Metadata panel, Show Subtitle Timeline / Show Waveform toggles (reverse playback postponed, Decision 29).
3. W4.7 per-show presets across all tabs.
4. W4.8b Ctrl+B creates a bookmark instantly.
5. W5.2 folder-based Videos / Music categories with user folders.
6. W5.4b pasted m3u link saved as a named stream playlist.
7. W5.5b New Playlist thumbnail picker.
8. W5.6b pins in the library rail, Latest Streams.
9. W5.7b Unwatched First / Watched First sorting, Mark as Watched.
10. W5.8b mini player with attached queue, draggable to corners.
11. W6.5 Add Subtitles dialog (folder / playlist targets, auto-matching, manual re-match, OpenSubtitles needs Sticky's API key, From Link).
12. W7.1 subtitle timeline on the seek bar (external files first; core cue export later, Decision 27).
13. W7.2 waveform seek bar.
14. W7.3 OSD shows the pressed shortcut (core change, Decision 27).
15. W8.1b new Customize controls (File / Folder / Playlist / Artist name, Favorite, Thumbnail, Bookmarks, Right Sidebar, Go Home ...) and editable top bar.
16. W8.2 profiles (layout + settings, restart notice).
17. The 12 Settings rows without a VLC option (VIDEO_INDEX rows 350-361, S2-01..S2-12; Sticky 2026-10-14: build everything she shows): each names the VLC mechanism to build on; S2-01 (additional command line options) and S2-11 (ignore ASS styling) need core changes (Decision 27, own build).
18. Then W9.1 release (needs Sticky's go).

Status of Step 1 work coded before this split: W2.1, W2.2, W2.5, W3.1-W3.8 (W3.5 click-to-jump included), W4.1/W4.2 part 1 are coded and in verification (run 38317777499). The restoreTime property (resume toast time) and AudioDeviceModel.refresh() expose data VLC already has.

## 1. How the VLC 4 Qt interface is built (what we work with)

- **One Qt module, mostly QML.** C++ models and controllers in `Q/`, QML views in `Q/*/qml/`. Every new QML file or C++ class must be added to BOTH `Q/meson.build` (QML in `qml_modules += {...}` blocks around lines 605-858, sources around line 350, moc headers line 31) AND `Q/Makefile.am` (`libqml_module_<mod>_a_QML`, `_SOURCES`, `nodist_..._SOURCES` for `.moc.cpp`). C++ types are registered for QML in `Q/maininterface/mainui.cpp` (lines 230-490) or with `QML_ELEMENT`. The Windows CI build uses autotools (`build.sh` without `-m`), so `Makefile.am` is the one that must be right first.
- **Theme.** `Q/style/systempalette.cpp` builds the palette from theme providers (`qtthemeprovider.hpp`, `windowsthemeprovider.cpp`); QML reads colors through `ColorContext` (`Q/style/colorcontext.hpp`) and sizes/fonts from the `VLCStyle.qml` singleton. Scheme (System/Day/Night) is `MainCtx.colorScheme` (`Q/util/color_scheme_model.cpp`, QSettings `MainWindow/color-scheme-index`). Icons are an icon font (`Q/pixmaps/VLCIcons.json` -> `makeIconFont.py` -> `VLCIcons.ttf`, drawn as text) plus colorized SVGs (`svgcolor` image provider, `Q/util/colorizedsvgicon.cpp`). A font glyph has one color, so the two-tone icons need SVGs.
- **Player view.** `Q/player/qml/Player.qml` (top bar `TopBar.qml`, control bar `ControlBar.qml`, auto-hide via `PlayerToolbarVisibilityFSM.qml` + `interactiveAutoHideTimer`, OSD `Q/widgets/qml/FloatingNotification.qml`, resume `ResumeDialog.qml`). Window buttons: `Q/widgets/qml/CSDWindowButtonSet.qml` + `Q/util/csdbuttonmodel.cpp`.
- **Control bar.** Layout model `Q/player/player_controlbar_model.cpp`, control enum `Q/player/control_list_model.hpp` (`ControlType`), one QML file per control in `Q/player/qml/controlbarcontrols/`, mapped in `PlayerControlbarControls.qml`. Seek bar `SliderBar.qml`, volume `VolumeWidget.qml`, tracks menu `TracksMenu.qml` / `TracksPage*.qml`. Remaining-time toggle exists (`MainCtx.showRemainingTime`). Toolbar editor in `Q/dialogs/toolbar/` (QML `ToolbarEditor*.qml`, profiles in `controlbar_profile*.cpp`).
- **Queue.** `Q/playlist/` (`PlaylistListModel`, `PlaylistController` = `MainPlaylistController` singleton, `PlaylistPane.qml`), wrapping `vlc_playlist`.
- **Library.** `Q/maininterface/qml/MainDisplay.qml` + `SideNavigationPane.qml`, ML views in `Q/medialibrary/qml/`, models `Q/medialibrary/ml*model.cpp` (folders, video, audio, album, artist, genre, playlists, recent, bookmarks), browse/network in `Q/network/`, history `Q/util/navigation_history.cpp`, sort/search `MainCtx.sort` / `MainCtx.search`, mini player `Q/player/qml/MiniPlayer.qml` / `PIPPlayer.qml`.
- **Menus.** Native `QMenu`s built in `Q/menus/menus.cpp` (`VLCMenuBar`, `PopupMenu` = right-click) and bridged to QML in `Q/menus/qml_menu_wrapper.cpp` (`QmlGlobalMenu`, `QmlMenuBar`, sort menus, playlist/network context menus). Native menus can't take the Figma style, so the redesigned menus are QML panels (`MenuPanel`) that call the same actions.
- **Dialogs.** Hub `Q/dialogs/dialogs_provider.cpp` (`DialogsProvider` singleton). Open/network/convert/stream, bookmarks, extended effects (EQ, compressor, spatializer, widener, video effects, sync), media info, about and preferences are QtWidgets (`Q/dialogs/*`). Redesigned dialogs become QML that reuses the C++ logic.
- **Preferences.** QtWidgets in `Q/dialogs/preferences/` (simple pages `sprefs_*.ui`, tree `complete_preferences.cpp`, `KeySelectorControl` in `preferences_widgets.cpp`). Values go through `config_GetInt/PutInt/PutPsz` and `config_SaveConfigFile`.
- **Hotkeys.** QML key handlers -> `MainCtx::sendHotkey` (`Q/maininterface/mainctx.cpp:543`) -> core variable `key-pressed` -> core maps it to `key-action` -> `modules/control/hotkeys.c`. OSD text comes from `src/player/osd.c` (`vlc_player_osd_Message`, `vlc_player_vout_OSDCallback`). `vlc_keycode2str()` names keys.
- **First run.** `Q/dialogs/firstrun/firstrunwizard.cpp` (QWizard), `MainCtx.hasFirstrun`.

What already exists in VLC and gets reused:

| Need | Existing VLC piece |
|---|---|
| Remaining time, jump to time | `MainCtx.showRemainingTime`, `PlayerController.time` (writable), `Q/dialogs/gototime/` |
| Volume to 200% | `qt-max-volume` (default 125, range 60-300), `vlc_player_aout_SetVolume` up to 2.0 |
| Seek thumbnails | `vlc_preparser_req_NewThumbnail` (`include/vlc_preparser.h`) |
| Bookmarks, chapters | `MLBookmarkModel` (media library media only), `ChapterListModel` / `TitleListModel` (`Q/player/input_models.cpp`) |
| Cast / "Render" | `RendererManager` (`Q/util/renderer_manager.cpp`) |
| Statistics, metadata | `PlayerController::statisticsUpdated`, `Q/dialogs/mediainfo/info_panels.cpp`, `PlayerController` title/artist/artwork |
| Sleep timer | none; QTimer + `vlc_playlist_SetMediaStoppedAction` for "End of current file" |
| Audio filters | `audio-filter` string + aout variables (`Q/dialogs/extended/extended_panels.cpp`), `equalizer_presets.h` (18 presets), `compressor-*`, `spatializer-*`, `stereowiden-*`, `pitch-shift` (-12..12 semitones) |
| Video filters | `video-filter` string, `transform-type`, `adjust` options, `PlayerController` zoom / aspectRatio / crop, `d3d11-hdr-mode` (auto/never/always/fake) |
| Subtitles | `subtitleDelay`, `subtitleFPS`, `sub-text-scale` (live), `freetype-*` (outline 0/2/4/6), `sub-autodetect-fuzzy`, `sub-language`, `sub-track` |
| Library data | `f_progress`, `i_playcount`, `i_last_played_date`, history lists, entry points, playlists (`include/vlc_media_library.h`) |
| Reverse playback | not possible (rate clamped at 0.03125 in `src/input/input.c`); postponed |

## 2. Architecture map (area -> files, modify vs create)

| Area | Modify | Create |
|---|---|---|
| Theme | `Q/style/systempalette.cpp`, `colorcontext.*`, `VLCStyle.qml`, `Q/util/color_scheme_model.cpp`, `assets.qrc` (Inter font) | palette tokens from `figma/styles.txt`, accent manager, SVG icon set `Q/pixmaps/redesign/*.svg` (mono, two-tone, active) |
| Control bar | `ControlBar.qml`, `PlayerControlLayout.qml`, `SliderBar.qml`, `controlbarcontrols/PlayButton.qml`, `VolumeWidget.qml`, `player_controlbar_model.cpp` | `ConeSlider.qml`, `EditableTime.qml`, `SeekPreview.qml` + `seek_thumbnailer.cpp`, tracks / gear / queue buttons |
| Top bar | `TopBar.qml`, `CSDWindowButtonSet.qml`, `csdbuttonmodel.cpp` | `FolderChip.qml` |
| Sidebars | `Player.qml` (panel host), `PlaylistPane.qml` | `RightPanel.qml`, tab pages (`PlaybackTab`, `VideoTab`, `AudioTab`, `SubtitlesTab`, `QueueTab`, `BookmarksTab`, `ChaptersTab`), `audio_filters_model.cpp`, `video_filters_model.cpp`, `preset_manager.cpp`, `sleep_timer.cpp` |
| Tracks popup | `TracksMenu.qml`, `TracksPage*.qml` | `TracksPopup.qml` |
| Menus | `menus.cpp`, `qml_menu_wrapper.cpp`, `MenuTopbar.qml`, `GlobalShortcuts.qml` | QML `MenuPanel.qml`, main menu, right-click menu, library menus |
| Library | `MainDisplay.qml`, `SideNavigationPane.qml`, `LocalTopbar.qml`, `HomePage.qml`, `Music*.qml`, `NetworkAddressbar.qml`, ML models | `LibraryPanel.qml`, `LibraryRail.qml`, `category_folders.cpp`, `pins_model.cpp`, `watched_sort_proxy.cpp`, `NewPlaylistDialog.qml` |
| Mini player | `PIPPlayer.qml`, `MiniPlayer.qml` | queue card, corner snapping |
| Settings | `dialogs_provider.cpp` (route prefs to the new dialog; keep the old dialog reachable from Advanced) | `SettingsDialog.qml`, `settings_model.cpp`, `settings_schema.json`, 13 page QML files |
| Hotkeys | `GlobalShortcuts.qml`, `mainctx.cpp` (Ctrl+\ Hide UI, Ctrl+B bookmark) | `KeyboardShortcutsDialog.qml`, `hotkeys_model.cpp`; core: `src/player/osd.c` (+ maybe `modules/control/hotkeys.c`) for the key name in the OSD |
| Customization | `Q/dialogs/toolbar/*`, `control_list_model.hpp`, `player_controlbar_model.cpp` | new control types, editable top bar model, `profile_manager.cpp` |
| Onboarding | `firstrunwizard.cpp` (replaced, not deleted) | `Onboarding.qml` |
| Subtitles extras | - | `AddSubtitlesDialog.qml`, `subtitle_matcher.cpp`, `opensubtitles_client.cpp`, `subtitle_cue_parser.cpp`, `SubtitleTimeline.qml` |
| Waveform | `SliderBar.qml` | `waveform_extractor.cpp` |

Principle: create new files and keep edits to existing VLC files small and well-marked, so upstream syncs stay easy.

## 3. Phase 1 in full detail: Windows build on GitHub Actions

Based on VideoLAN's own `win64` job in `extras/ci/gitlab-ci.yml` (image variable `VLC_WIN64_IMAGE`, the `.win-common` script and `default.before_script`) and `extras/package/win32/build.sh` + `extras/package/win32/package.mak`.

Facts checked on 2026-10-12:
- Image `registry.videolan.org/vlc-debian-win64-posix:20260611225331` (mingw-w64 gcc posix toolchain, Qt build tools, wine, meson, nasm, zip, 7z) is public. The registry and the manifest answer HTTP 200 without login.
- Prebuilt contribs (Qt included) for the current contrib SHA exist: `https://artifacts.videolan.org/vlc/win64/vlc-contrib-x86_64-w64-mingw32-a5538c557d276378d5ba0f8f8010a8b87eaa6f78.tar.zst` -> HTTP 200. They match only this gcc image, not the llvm images. The `win64-llvm` path and the `make prebuilt` default "latest" URL return 404.
- The contrib SHA comes from `extras/ci/get-contrib-sha.sh win64` = last commit touching `extras/tools contrib extras/ci extras/package/win32`, so the checkout needs full history (`fetch-depth: 0`). Our redesign commits don't touch those paths, so the SHA (and the prebuilt) stay valid until we sync with upstream.
- Repo `StickyGonzales/vlc-redesign-juxtopposed` is public, Actions enabled (`allowed_actions: all`). Public repo = free minutes; a job may run up to 6 hours.

File: `.github/workflows/build-windows.yml`
```yaml
name: build-windows
on:
  push: { branches: [redesign] }
  workflow_dispatch: {}
concurrency: { group: build-windows-${{ github.ref }}, cancel-in-progress: true }
env:
  VLC_IMAGE: registry.videolan.org/vlc-debian-win64-posix:20260611225331
jobs:
  win64:
    runs-on: ubuntu-latest
    timeout-minutes: 350
    steps:
      - name: Free disk space   # runner has ~14 GB free; image + contribs + build need more
        run: |
          sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc /opt/hostedtoolcache/CodeQL
          sudo docker image prune -af
          df -h /
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Contrib SHA and prebuilt URL
        id: sha
        run: |
          SHA=$(extras/ci/get-contrib-sha.sh win64)
          URL="https://artifacts.videolan.org/vlc/win64/vlc-contrib-x86_64-w64-mingw32-${SHA}.tar.zst"
          echo "sha=$SHA" >> $GITHUB_OUTPUT
          if extras/ci/check-url.sh "$URL"; then echo "url=$URL" >> $GITHUB_OUTPUT; fi
      - name: Cache contribs built from source (only used when no prebuilt exists)
        if: steps.sha.outputs.url == ''
        uses: actions/cache@v4
        with:
          path: |
            contrib/x86_64-w64-mingw32
            contrib/tarballs
          key: contrib-win64-${{ steps.sha.outputs.sha }}
      - name: Cache tools and compiler cache
        uses: actions/cache@v4
        with:
          path: |
            extras/tools/build
            .ccache
          key: tools-ccache-${{ steps.sha.outputs.sha }}-${{ github.sha }}
          restore-keys: tools-ccache-${{ steps.sha.outputs.sha }}-
      - name: Build in VideoLAN's image
        run: |
          docker run --rm -v "$PWD:/build" -w /build \
            -e VLC_PREBUILT_CONTRIBS_URL="${{ steps.sha.outputs.url }}" \
            -e CCACHE_DIR=/build/.ccache \
            "$VLC_IMAGE" bash -ec '
              git config --global --add safe.directory /build
              P=""; [ -n "$VLC_PREBUILT_CONTRIBS_URL" ] && P="-p" || unset VLC_PREBUILT_CONTRIBS_URL
              extras/package/win32/build.sh -r -a x86_64 $P
              cd win64 && make package-win32-zip'
          sudo chown -R "$(id -u):$(id -g)" .
      - name: Unpack zip so the artifact is a single zip
        run: |
          mkdir dist && unzip -q win64/vlc-*-win64.zip -d dist
          ls dist
      - uses: actions/upload-artifact@v4
        with:
          name: vlc-redesign-win64
          path: dist/
          retention-days: 14
```
Notes and fallbacks (log every problem and fix in `redesign/BUILD_NOTES.md`):
- `-r` = release build (no `--enable-debug`); no `-i` (NSIS / WiX installers come in the release phase); no `-x` (extra checks, not needed for a runnable zip); `-l` (translations) can be added later.
- If the image has no `ccache`, drop the ccache lines (check `which ccache` in the first run). If the build directory cache helps more, also cache `win64/` keyed on the branch (incremental builds; first run will show the timings).
- If the prebuilt URL ever 404s (after an upstream sync), `build.sh -p` falls back to building contribs from source (1-2 h per `doc/BUILD-win32.md`); the source-contrib cache then saves that time on later runs. If even that exceeds the 6 h limit, split contribs into a separate job that uploads `make package` output (`build.sh -c`) as a cache.
- If disk still runs out: also remove `/usr/local/share/boost` and `/usr/local/.ghcup`, and delete `contrib/tarballs` after unpacking.
- Done when: the run is green, the artifact `vlc-redesign-win64` contains `vlc-<version>/vlc.exe`, `libvlc.dll`, `libvlccore.dll`, `plugins/`, and Sticky (or the test loop on this PC) can unzip it, start `vlc.exe` and play a local video.
- Download from this PC: `gh run download <run-id> -R StickyGonzales/vlc-redesign-juxtopposed -n vlc-redesign-win64 -D "$env:USERPROFILE\Desktop\vlc-redesign\builds\<run-id>"`.

## 4. Build order (phases; superseded in order by section 0, lanes still apply)

Dependency order of phases; inside a phase, packages with different lane letters can run in parallel (one subagent per lane, each in its own git worktree, merged back by the main session before the next CI run). Same lane = sequential.

| Phase | Goal | Work packages (lane) | Parallel? |
|---|---|---|---|
| 1 | Green Windows build of stock VLC | W1.1 (A) | no |
| 2 | Look and feel foundation (dark) | W2.1 (A) first, then W2.2 (B), W2.3 (B), W2.5 (C) | after W2.1: B and C in parallel |
| 3 | Player chrome | W3.1, W3.2 (A) first; then W3.3 (B), W3.4 + W3.5 (C), W3.6 + W3.7 + W3.8 (D) | after A: B, C, D in parallel |
| 4 | Panels and menus | W4.1 (A) first; then W4.2 + W4.8 (B), W4.3 (B), W4.4 + W4.5 (C), W4.6 (D), W4.9 + W4.10 (C); W4.7 (E) last | after W4.1: B, C, D in parallel; W4.7 after the four tabs |
| 5 | Library | W5.1 + W5.2 (A) first; then W5.3 + W5.7 (B), W5.4 + W5.5 (C), W5.6 + W5.8 (D); W5.9 (E) last | after A: B, C, D in parallel |
| 6 | Settings and dialogs | W6.1 + W6.2 (A), W6.3 (B), W6.4 (C), W6.5 (B after W6.3) | A, B, C in parallel (W6.1 can start any time after Phase 2) |
| 7 | New engine-side features | W7.1 (A), W7.2 (B), W7.3 (C, core change) | all three in parallel |
| 8 | Customization, profiles, onboarding, light theme | W8.1 (A) then W8.2 (B); W8.3 (C); W8.4 (A) last | W8.1 and W8.3 in parallel |
| 9 | Public release (CLAUDE.md Phase 6) | W9.1 | no |

CI note: parallel lanes only speed up writing code. Every merge to `redesign` triggers one CI build, so merge lanes in batches (one push per batch) and keep `cancel-in-progress`.

## 5. Test loop (every work package)

1. **Before coding:** list the package's VIDEO_INDEX rows; for each, check what she says at those timestamps and pull dense frames from the local copy of the video (`ffmpeg -ss <t> -t <d> -i <local video> -vf fps=6 <local frames folder>/<WP>/f_%03d.jpg`; the video, its transcript and all frames are local only, never committed); open the matching Figma PNGs and the FIGMA_FLOWS.md rows/specs.
2. **Code** in `modules/gui/qt` (core only where the plan says so), register new files in both `meson.build` and `Makefile.am`.
3. **Push** to `redesign`; `gh run watch` until done. On failure: `gh run view --log-failed`, fix the cause, log it in `redesign/BUILD_NOTES.md`, push again. No blind retries.
4. **Download** the artifact with `gh run download` into `builds/<run-id>/` (outside the repo, git-ignored by location).
5. **Run on this PC** with a real test video (<TEST_VIDEO> or another short test clip, never the designer's video): `vlc.exe --no-qt-privacy-ask <file>`. Use a separate config dir so tests don't touch Sticky's real VLC settings: set `APPDATA` to `builds/<run-id>/appdata` before starting.
6. **Screenshot every state** the rows describe (default, hover, open panel, each tab, menus, dialogs): PowerShell `System.Drawing` `CopyFromScreen` of the VLC window, with mouse moves and clicks scripted via `user32` `SetCursorPos` / `mouse_event` and keys via `SendKeys`. Save to `redesign/reference/frames_work/test/<WP>/` (local only).
7. **Compare** each screenshot side by side with the video frame at the matching timestamp and the Figma PNG (crop both to the same region, check layout, sizes, colors from styles.txt, labels, order). List every difference; fix or record it under "Decisions (Claude)" with the reason.
8. **Regression check** of normal VLC functions: open file, play/pause, seek, volume, fullscreen, subtitles on/off, audio track switch, playlist next/previous, preferences save and reload, quit without crash.
9. **Mark done**: set the rows' Status in VIDEO_INDEX.md to `done (<commit hash>)`, update "Current phase" in CLAUDE.md, commit, push.

If scripted interaction can't reach a state (for example a hover inside the video surface), add a hidden debug option in our own UI code (environment variable `VLC_REDESIGN_DEBUG_STATE=<panel>`) that opens that state on start, used only for screenshots.

## 6. Risks and unknowns

| # | Risk | Plan |
|---|---|---|
| 1 | Slow feedback: no local build, each CI run takes a long time (first run several hours, later runs hopefully under an hour with caches). | Phase 1 measures timings first. Cache tools and ccache (and the build dir if it helps). Batch several rows per push. Use parallel lanes for coding while CI runs. Check QML syntax before pushing (`qmllint` from the downloaded build's Qt if available). |
| 2 | Video surface on Windows (DirectComposition / d3d11): rounded inset video, panels and drag ghosts over video, mouse hover zones in fullscreen may not behave like normal QML. | Prototype early in W3.6 / W3.7 with the debug state option; fallback for rounded corners = chrome-colored corner masks drawn above the video; fallback for hover = window-level mouse tracking in C++ (`interface_window_handler.cpp`). |
| 3 | Size of the job (45 packages, about 200 agent-days) and upstream VLC master moving underneath. | Strict phase order, new files instead of large edits, small marked edits in existing files; sync with upstream only between phases; after a sync check that the contrib prebuilt still exists. |
| 4 | Features needing real engine work: subtitle timeline for embedded tracks, waveform extraction, OSD key name (core), per-show presets applying options that only take effect on the next file / vout (freetype, HDR mode), profiles that switch every setting. | External subtitles first (parser in the GUI); waveform via a separate background decode with cache; minimal isolated core patch in `src/player/osd.c` (approved); presets apply live where VLC allows and on next file otherwise, with a notice; profiles show a restart notice (Decision 29). |
| 5 | External dependency: OpenSubtitles needs an API key and user login; bookmarks only work for media in the media library. | Build "From Computer" and "From Link" first; OpenSubtitles behind a setting, ask Sticky for a key when W6.5 starts. Add a file to the media library automatically when the user creates a bookmark. |
| 6 | Two build systems (autotools for CI, meson) must both list every new file. | Rule in the test loop step 2; CI uses autotools, so a missing Makefile.am entry fails fast. |
| 7 | The CI image tag gets old (VideoLAN updates it in gitlab-ci.yml). | Keep the tag from our checked-out `extras/ci/gitlab-ci.yml`; update it when syncing with upstream. |
| 8 | GUI test automation on Windows from the shell is fragile. | Debug state option, fixed window size (`--qt-...` window geometry via QSettings in the test APPDATA), screenshots by window handle. |

## 7. Work packages

Size = estimated agent working days (S under 1, M 1-3, L 3-7, XL over 7). Lane = packages in the same phase with different letters can run in parallel (subagents in separate worktrees); same letter = run in order.

| WP | Phase | Lane | Name | Rows | Modified files | New files | Reuses | Depends on | Core change | Size |
|---|---|---|---|---|---|---|---|---|---|---|
| W1.1 | 1 | A | Windows CI build (GitHub Actions) | 0 | .github/workflows/build-windows.yml (new) | redesign/BUILD_NOTES.md | extras/package/win32/build.sh, extras/ci/get-contrib-sha.sh, check-url.sh, package.mak (package-win32-zip) | - | no | M (2 d) |
| W2.1 | 2 | A | Dark palette, fonts, radii, spacing tokens | 7 | modules/gui/qt/style/systempalette.cpp, style/colorcontext.hpp/.cpp, style/VLCStyle.qml, util/color_scheme_model.cpp | modules/gui/qt/style/RedesignTokens (palette values from figma/styles.txt), bundled Inter font in assets.qrc | ColorContext / SystemPalette / VLCStyle | W1.1 | no | M (1.75 d) |
| W2.2 | 2 | B | Accent color system (9 accents, derived shades, live recolor, cone tint) | 6 | modules/gui/qt/style/systempalette.cpp, maininterface/mainctx.cpp (accent setting in QSettings) | modules/gui/qt/cone SVG recolored via util/color_svg_image_provider.cpp | svgcolor image provider, ColorContext.accent | W2.1 | no | L (7 d) |
| W2.3 | 2 | B | Icon set: SVG icons in mono / two-tone (Accent/DIm) / solid-active states | 5 | modules/gui/qt/widgets/qml/IconLabel.qml (or new IconImage use), pixmaps/ + assets.qrc | modules/gui/qt/pixmaps/redesign/*.svg, widgets/qml/RIcon.qml | util/colorizedsvgicon.cpp, svgcolor provider | W2.1 | no | M (1.25 d) |
| W2.5 | 2 | C | Component kit: toggle, dropdown, segmented, 3 slider kinds, expander card, buttons, fields, option row, menu panel, tooltip, dialog frame | 7 | modules/gui/qt/widgets/qml/* (restyle where reused) | modules/gui/qt/widgets/qml/redesign/*.qml registered in meson.build + Makefile.am | existing widgets/qml controls as base | W2.1, W2.3 | no | L (3.25 d) |
| W3.1 | 3 | A | Top bar: cone, '...', sidebar toggle, folder chip, centered title, min/max/fullscreen/close | 10 | modules/gui/qt/player/qml/TopBar.qml, widgets/qml/CSDWindowButtonSet.qml, util/csdbuttonmodel.cpp | modules/gui/qt/widgets/qml/FolderChip.qml | CSD buttons, MainCtx fullscreen | W2.5 | no | L (4 d) |
| W3.2 | 3 | A | Control bar layout: thin 54 px row, prev/play/next, track buttons, gear, queue, hover states | 15 | modules/gui/qt/player/qml/ControlBar.qml, PlayerControlLayout.qml, controlbarcontrols/PlayButton.qml, player/player_controlbar_model.cpp (default layout) | modules/gui/qt/controlbarcontrols/TracksButton*.qml, GearButton.qml, QueueButton.qml | PlayerControlLayout, ControlListModel | W2.5 | no | L (3.75 d) |
| W3.3 | 3 | B | Thick seek bar + hover thumbnail preview | 7 | modules/gui/qt/player/qml/SliderBar.qml | modules/gui/qt/player/seek_thumbnailer.cpp/.hpp (vlc_preparser_req_NewThumbnail -> QImage provider), player/qml/SeekPreview.qml | vlc_preparser thumbnail API | W3.2 | no | M (2.5 d) |
| W3.4 | 3 | C | Cone volume 0-200% + % tooltip | 5 | modules/gui/qt/player/qml/controlbarcontrols/VolumeWidget.qml, qt.cpp (qt-max-volume default 200) | modules/gui/qt/widgets/qml/ConeSlider.qml | vlc_player_aout_SetVolume (max 2.0) | W3.2 | no | M (1.25 d) |
| W3.5 | 3 | C | Time labels: remaining-time toggle, click-to-edit jump | 2 | modules/gui/qt/player/qml/ControlBar.qml (time labels) | modules/gui/qt/widgets/qml/EditableTime.qml | MainCtx.showRemainingTime, PlayerController.time, gototime | W3.2 | no | M (1.25 d) |
| W3.6 | 3 | D | Per-bar proximity show/hide (instant), Hide UI mode (Ctrl+\) | 3 | modules/gui/qt/player/qml/Player.qml, PlayerToolbarVisibilityFSM.qml, maininterface/mainctx.cpp | - | interactiveAutoHideTimer, FSM | W3.1, W3.2 | no | M (1.5 d) |
| W3.7 | 3 | D | Inset rounded video area / chrome frame | 1 | modules/gui/qt/player/qml/Player.qml, maininterface/videosurface.cpp | modules/gui/qt/corner mask overlay item | - | W3.1 | maybe (video surface clipping) | S (0.25 d) |
| W3.8 | 3 | D | Resume toast near the controls | 2 | modules/gui/qt/player/qml/ResumeDialog.qml | - | ResumeDialog logic | W3.2 | no | S (0.5 d) |
| W4.1 | 4 | A | Right panel framework: 400 px docked panel, tabs, open/close/switch logic, sticky footer | 11 | modules/gui/qt/player/qml/Player.qml (panel host) | modules/gui/qt/player/qml/RightPanel.qml, RightPanelTabs.qml | MainCtx.playqueuePanel state | W3.2, W2.5 | no | L (4.25 d) |
| W4.2 | 4 | B | Tracks popup: Video/Audio/Subtitles tabs, embedded/external tracks, output devices, Show Preferences | 7 | modules/gui/qt/player/qml/TracksMenu.qml, TracksPage*.qml, TracksListPage.qml | modules/gui/qt/player/qml/TracksPopup.qml | TrackListModel, aout device list | W4.1 | no | M (1.75 d) |
| W4.3 | 4 | B | Settings sidebar - Playback tab (speed, sleep timer, visualizer, toggles, show metadata, statistics) | 8 | modules/gui/qt/player/qml/PlaybackSpeed.qml | modules/gui/qt/player/qml/sidebar/PlaybackTab.qml, player/sleep_timer.cpp, MetadataPanel.qml | PlayerController rate, statistics, vlc_playlist_SetMediaStoppedAction | W4.1 | no | L (5 d) |
| W4.4 | 4 | C | Settings sidebar - Video tab (flip, rotate, zoom, HDR, resolution, aspect, crop, render, filter groups) | 4 | modules/gui/qt/dialogs/extended/extended_panels.cpp (logic reuse) | modules/gui/qt/player/qml/sidebar/VideoTab.qml, player/video_filters_model.cpp | video-filter string, transform/adjust options, PlayerController zoom/aspectRatio/crop, RendererManager | W4.1 | no | L (3.75 d) |
| W4.5 | 4 | C | Settings sidebar - Audio tab (defaults, stereo mode, delay, EQ + presets with curve icons, compressor, spatializer, widener, pitch) | 11 | modules/gui/qt/dialogs/extended/extended_panels.cpp (logic reuse) | modules/gui/qt/player/qml/sidebar/AudioTab.qml, player/audio_filters_model.cpp | audio-filter string, equalizer_presets.h, scaletempo pitch-shift | W4.1 | no | L (3.5 d) |
| W4.6 | 4 | D | Settings sidebar - Subtitles tab (defaults, sync sliders, appearance, relative/pixels) | 8 | - | modules/gui/qt/player/qml/sidebar/SubtitlesTab.qml | subtitleDelay, subtitleFPS, sub-text-scale, freetype-* options | W4.1 | no | M (2.75 d) |
| W4.7 | 4 | E | Per-show presets covering all tabs (footer, menu, rename/duplicate/delete) | 6 | - | modules/gui/qt/player/preset_manager.cpp (QSettings/JSON store keyed by show folder), player/qml/sidebar/PresetFooter.qml | - | W4.3, W4.4, W4.5, W4.6 | no | XL (7.75 d) |
| W4.8 | 4 | B | Queue / Bookmarks / Chapters sidebar + Ctrl+B | 15 | modules/gui/qt/playlist/qml/PlaylistPane.qml, PlaylistDelegate.qml, menus/qml/GlobalShortcuts.qml | modules/gui/qt/player/qml/sidebar/QueueTab.qml, BookmarksTab.qml, ChaptersTab.qml | PlaylistListModel, MLBookmarkModel, ChapterListModel | W4.1 | no | L (6 d) |
| W4.9 | 4 | C | Main '...' menu (final Figma version) + Profile submenu entry | 9 | modules/gui/qt/menus/menus.cpp, menus/qml_menu_wrapper.cpp, maininterface/qml/MenuTopbar.qml | modules/gui/qt/widgets/qml/redesign/MenuPanel.qml (QML menu) | VLCMenuBar actions, DialogsProvider slots | W2.5, W3.1 | no | M (2.25 d) |
| W4.10 | 4 | C | Right-click menu restyle + Hide UI item + real wiring | 4 | modules/gui/qt/menus/menus.cpp (PopupMenu), menus/qml_menu_wrapper.cpp (QmlGlobalMenu) | - | PopupMenu actions | W4.9 | no | M (2.5 d) |
| W5.1 | 5 | A | Library shell: icon rail, compact panel over video, full-window mode, back/forward, breadcrumb, crossfade | 13 | modules/gui/qt/maininterface/qml/MainDisplay.qml, SideNavigationPane.qml, network/qml/NetworkAddressbar.qml, util/navigation_history.cpp | modules/gui/qt/medialibrary/qml/redesign/LibraryPanel.qml, LibraryRail.qml | History singleton, NavigationModel | W3.1, W2.5 | no | L (6 d) |
| W5.2 | 5 | A | Folder-based Videos/Music categories (user folders, Add, drill-down) | 3 | modules/gui/qt/medialibrary/mlfoldersmodel.cpp, mlvideofoldersmodel.cpp | modules/gui/qt/medialibrary/category_folders.cpp (folders per category in QSettings) | vlc_ml_add_folder, entry points, NetworkMediaModel browsing | W5.1 | no | L (5 d) |
| W5.3 | 5 | B | Music: categories + music player view (cover, blurred bg, +/-15 s) | 9 | modules/gui/qt/medialibrary/qml/Music*.qml, player/qml/Player.qml (audio mode) | - | MLAudioModel, MLAlbumModel, MLArtistModel, MLGenreModel, artwork blur | W5.1 | no | L (3.75 d) |
| W5.4 | 5 | C | Network streams list + saving pasted m3u as a named stream playlist | 3 | modules/gui/qt/network/qml/*.qml | modules/gui/qt/medialibrary/qml/redesign/NetworkCategory.qml | UrlListDisplay, ML playlists | W5.1, W6.4 | no | M (1.5 d) |
| W5.5 | 5 | C | Playlists list, New Playlist dialog, add-to-playlist, playlist menu | 6 | modules/gui/qt/medialibrary/qml/PlaylistMedia*.qml, menus/qml_menu_wrapper.cpp (PlaylistListContextMenu) | modules/gui/qt/dialogs/redesign/NewPlaylistDialog.qml | MLPlaylistListModel, VLC_ML_PLAYLIST_CREATE | W5.1 | no | M (3 d) |
| W5.6 | 5 | D | Home page (incl. Latest Streams), Recent, pins | 12 | modules/gui/qt/medialibrary/qml/HomePage.qml, HomeDisplay.qml | modules/gui/qt/medialibrary/pins_model.cpp | MLRecentMediaModel, VLC_ML_LIST_HISTORY | W5.1, W5.2, W5.4 | no | XL (8.75 d) |
| W5.7 | 5 | B | Toolbar: sort (incl. watched/unwatched), view options, search, row/grid states, file/folder menus | 16 | modules/gui/qt/maininterface/qml/LocalTopbar.qml, widgets/qml/SortControl.qml, SearchBox.qml, medialibrary/qml/MLContextMenu.qml | modules/gui/qt/medialibrary/watched_sort_proxy.cpp | SortCtx, SearchCtx, f_progress / i_playcount | W5.1 | no | L (7 d) |
| W5.8 | 5 | D | Mini player + attached queue, draggable to corners | 4 | modules/gui/qt/player/qml/PIPPlayer.qml, MiniPlayer.qml | - | PIP player | W5.1, W4.8 | no | L (4.5 d) |
| W5.9 | 5 | E | Drag from library to queue over video | 2 | modules/gui/qt/medialibrary/qml/MLDragItem.qml, playlist/qml/PlaylistPane.qml | - | DragItem, PlaylistController insert | W4.8, W5.1 | no | L (3.25 d) |
| W6.1 | 6 | A | Settings dialog shell: category nav, search, info popovers, Advanced Options expander | 14 | modules/gui/qt/dialogs/dialogs_provider.cpp (prefsDialog) | modules/gui/qt/dialogs/redesign/settings/SettingsDialog.qml, settings_model.cpp (option schema) | config_GetInt/PutInt, module option longtext | W2.5 | no | L (3.5 d) |
| W6.2 | 6 | A | Settings pages: 13 categories mapped to VLC options, human-worded values | 15 | - | modules/gui/qt/dialogs/redesign/settings/pages/*.qml, settings_schema.json | existing option names (sub-autodetect-fuzzy, freetype-*, d3d11-hdr-mode ...) | W6.1 | no | L (3.75 d) |
| W6.3 | 6 | B | Keyboard Shortcuts dialog | 5 | modules/gui/qt/dialogs/preferences/preferences_widgets.cpp (KeySelectorControl logic) | modules/gui/qt/dialogs/redesign/KeyboardShortcutsDialog.qml, hotkeys_model.cpp | key-* / global-key-* options, vlc_keycode2str | W2.5 | no | M (1.25 d) |
| W6.4 | 6 | C | Open dialogs split and restyled (file(s), folder, disc, network, capture, convert) | 3 | modules/gui/qt/dialogs/open/*, dialogs/sout/* | modules/gui/qt/dialogs/redesign/OpenNetworkStreamDialog.qml | OpenDialog tabs, DialogsProvider | W2.5 | no | M (2.25 d) |
| W6.5 | 6 | B | Add Subtitles dialog (target/source, folder auto-match, manual re-match, OpenSubtitles, link) + persistent mapping | 9 | - | modules/gui/qt/dialogs/redesign/AddSubtitlesDialog.qml, util/subtitle_matcher.cpp, util/opensubtitles_client.cpp | vlc_player_AddAssociatedMedia, sub-autodetect | W4.2, W5.2 | no (OpenSubtitles needs an API key from Sticky) | XL (13.25 d) |
| W7.1 | 7 | A | Subtitle timeline on the seek bar (external SRT/VTT first) | 3 | modules/gui/qt/player/qml/SliderBar.qml | modules/gui/qt/util/subtitle_cue_parser.cpp, player/qml/SubtitleTimeline.qml | subtitleDelay | W3.3, W4.3 | later: modules/demux/subtitle.c cue export (approved, Decision 27) | XL (18 d) |
| W7.2 | 7 | B | Waveform seek bar | 2 | modules/gui/qt/player/qml/SliderBar.qml | modules/gui/qt/util/waveform_extractor.cpp (separate decode pass, cached) | libvlc/preparser decode | W3.3 | no (heavy) | XL (9 d) |
| W7.3 | 7 | C | OSD shows the pressed shortcut | 3 | src/player/osd.c (prefix with last key), modules/control/hotkeys.c or Qt sendHotkey | - | vlc_player_osd_Message, vlc_keycode2str | W2.1 | YES (approved, minimal) | M (2.25 d) |
| W8.1 | 8 | A | Customize Player: palette, drag in/out of both bars, new control types | 7 | modules/gui/qt/dialogs/toolbar/qml/*, player/control_list_model.hpp, player/player_controlbar_model.cpp, dialogs/toolbar/controlbar_profile*.cpp | modules/gui/qt/controlbarcontrols/* (FileName, FolderName, Favorite, Bookmarks ...), top bar model | ToolbarEditor DnD, controlbar profiles | W3.1, W3.2 | no | XL (17.5 d) |
| W8.2 | 8 | B | Profiles: layout + settings sets, restart notice | 1 | modules/gui/qt/dialogs/toolbar/controlbar_profile_model.cpp, maininterface/mainctx.cpp | modules/gui/qt/util/profile_manager.cpp | controlbar profiles, config_SaveConfigFile | W8.1, W6.2 | maybe (config reload) | L (6 d) |
| W8.3 | 8 | C | Onboarding: welcome + folder, theme + accent (live), shortcuts | 4 | modules/gui/qt/dialogs/firstrun/firstrunwizard.cpp (replace) | modules/gui/qt/dialogs/redesign/Onboarding.qml | MainCtx.hasFirstrun, colorScheme, accent | W2.2, W5.2 | no | L (5.25 d) |
| W8.4 | 8 | A | Light theme (corrected FG/1, FG/2) | 3 | modules/gui/qt/style/systempalette.cpp | - | ColorSchemeModel Day | all UI | no | S (0.75 d) |
| W9.1 | 9 | A | Release: name, icon, README, installer workflow (CLAUDE.md Phase 6) | 0 | extras/package/win32/*, share/icons | .github/workflows/release.yml, README | NSIS packaging | all | no | M (3 d) |

Totals by phase: Phase 1: 1 WPs, about 2 agent-days; Phase 2: 4 WPs, about 13.25 agent-days; Phase 3: 8 WPs, about 15 agent-days; Phase 4: 10 WPs, about 39.5 agent-days; Phase 5: 9 WPs, about 42.75 agent-days; Phase 6: 5 WPs, about 24 agent-days; Phase 7: 3 WPs, about 29.25 agent-days; Phase 8: 4 WPs, about 29.5 agent-days; Phase 9: 1 WPs, about 3 agent-days. Overall: 45 work packages, about 198.25 agent-days.

## 8. Every buildable row (290)

Each row inherits the files, reused VLC functions and dependencies of its work package (table above). Size is per row. Core = needs a change outside modules/gui/qt.

| Row | Time | Area | Item | WP | Size | Type | Core |
|---|---|---|---|---|---|---|---|
| IA-01 | 0:52-0:59 | visual style | Flat cone logo geometry | W2.1 | S | UI | no |
| IA-02 | 0:52-0:59 | visual style | Palette swatch shapes (video only reference) | W2.1 | S | UI | no |
| IA-04 | 1:13-1:15 | visual style | Monochrome (clickable) set differs in shape, not just color | W2.1 | S | UI | no |
| IA-25 | 5:39-6:34 | subtitles | Default subtitle rendering look | W2.1 | S | UI | no |
| P1-04 | 0:39-0:55 | visual style | Keep the cone and orange | W2.1 | S | UI | no |
| P1-05 | 0:52-0:59 | visual style | Color palette | W2.1 | S | UI | no |
| P1-09 | 1:15-1:32 | visual style | Corner radius: rectangular but less sharp | W2.1 | S | UI | no |
| F-20 | Figma only (related 17:44, 19:49) | visual style | Exact accent color values | W2.2 | S | NEW | no |
| F-21 | Figma only | menus | Menu icon accent color | W2.2 | S | UI | no |
| IA-38 | 8:40-8:47 | sidebar | Accent ghost button "Test" | W2.2 | S | NEW? | no |
| IB-43 | 17:36-18:27 | settings | Accent swatches: square in Settings, round in Onboarding | W2.2 | S | NEW | no |
| P8-05 | 17:44-17:49 | visual style | Accent color setting | W2.2 | L | NEW | no |
| P8-42 | 17:44-17:49 | visual style | Accent change is live and instant | W2.2 | L | NEW | no |
| IA-03 | 1:07-1:15 | visual style | Two-tone (decorative) set, exact orange placement per icon | W2.3 | S | UI | no |
| IA-05 | 1:15-4:44 (seen) | visual style | Third icon state: solid orange = active/toggled | W2.3 | S | UI | no |
| IB-48 | 10:30-20:59 | visual style | Global type and icon conventions observed | W2.3 | S | UI | no |
| P1-07 | 1:07-1:13 | visual style | Decorative (two-tone) icon set | W2.3 | S | UI | no |
| P1-08 | 1:13-1:15 | visual style | Clickable (monochrome) icon set | W2.3 | S | UI | no |
| IA-30 | 7:20-7:30 | sidebar | Slider styles (three kinds) | W2.5 | M | NEW | no |
| IA-31 | 7:23-7:30 | sidebar | Toggle (OFF) appearance | W2.5 | S | UI | no |
| IA-32 | 7:40-7:51 | sidebar | Segmented control style | W2.5 | S | UI | no |
| IA-39 | 8:44-8:52 | sidebar | Dropdown vs input vs expander styles in sidebar | W2.5 | S | UI | no |
| IB-41 | 17:03-17:33 | settings | Dropdown list styling (fuzziness) | W2.5 | S | UI | no |
| IB-45 | 18:06-18:08 | settings | Slider variants | W2.5 | S | UI | no |
| P8-43 | 17:39-18:27 | settings | Settings control styles | W2.5 | M | UI | no |
| IA-16 | 3:56-4:03 | top bar | Window control glyphs | W3.1 | S | UI | no |
| IA-21 | 4:56-5:05 | top bar | New single-row top bar typography | W3.1 | S | UI | no |
| IB-10 | 11:24-11:31 | top bar | Folder chip glyph and typography | W3.1 | S | UI | no |
| IB-11 | 11:37-11:59 | top bar | Sidebar-toggle icon states | W3.1 | S | UI | no |
| P2-06 | 3:35-3:39 | top bar | Restyled single-row top bar | W3.1 | S | UI | no |
| P2-09 | 3:55-4:03 | top bar | Fullscreen and Picture-in-Picture icons in the top bar | W3.1 | M | NEW (PiP) / UI (fullscreen) | no |
| P2-10 | 4:01-4:07 | top bar | Top or bottom choice for fullscreen/PiP | W3.1 | S | UI? | no |
| P5-20 | 11:24-11:31 | top bar | Show / folder name in top bar opens the library | W3.1 | M | NEW? | no |
| P5-22 | 11:37-11:40 | top bar | Sidebar (panel) icon next to folder name | W3.1 | S | UI | no |
| P5-30 | 11:41-11:59 | top bar | Top bar state with library open | W3.1 | S | UI | no |
| F-05 | Figma only | control bar | Hover state on every icon button | W3.2 | S | UI | no |
| IA-06 | 1:16-1:32 | control bar | Play button morph and glyph | W3.2 | S | UI | no |
| IA-08 | 2:12-2:15 | control bar | Prev / Next glyphs | W3.2 | S | UI | no |
| IA-10 | 2:46-2:47 | control bar | Gear-with-play icon geometry | W3.2 | S | UI | no |
| IA-17 | 4:07, 6:25, 9:18 | control bar | Play/pause button colors | W3.2 | S | UI | no |
| IA-19 | 4:35-4:44 | audio/video | Bar icons slide when a new icon is inserted | W3.2 | S | UI | no |
| IB-16 | 11:41-11:59 | control bar | Control bar glyph details (video bar) | W3.2 | S | UI | no |
| P1-12 | 1:33-1:46 | control bar | Problem statement: quiet bar that does its job | W3.2 | S | UI | no |
| P1-14 | 2:09-2:15 | control bar | Play button bigger, prev/next around it, stop removed | W3.2 | S | UI | no |
| P1-15 | 2:15-2:22 | control bar | Fullscreen and settings move to the right | W3.2 | S | UI | no |
| P2-03 | 3:16-3:24 | control bar | Thin single-row control bar layout | W3.2 | S | UI | no |
| P2-12 | 4:07-4:08 | control bar | Play/pause button states | W3.2 | S | UI | no |
| P3-13 | 6:32-6:40 | control bar | Gear-with-play icon (catch-all settings button) = old Adjustments | W3.2 | S | UI | no |
| P4-03 | 7:52-8:03 | control bar | Gear (settings) button icon, active state | W3.2 | S | UI | no |
| P4-38 | 9:18-9:20 | control bar | Play/pause button states (context) | W3.2 | S | UI | no |
| IA-13 | 3:16-3:30 | control bar | Thick seek bar construction | W3.3 | S | UI | no |
| IA-14 | 3:28-3:30 | control bar | Seek preview card proportions | W3.3 | S | NEW | no |
| IB-17 | 14:10-17:35 | control bar | Seek bar played-fill color | W3.3 | S | UI | no |
| IB-46 | 20:23-20:31 | control bar | Seek bar with segments in the montage | W3.3 | S | NEW? | no |
| P2-02 | 3:10-3:20 | control bar | Thick seek bar moved into the bottom row | W3.3 | S | UI | no |
| P2-04 | 3:24-3:31 | control bar | Seek preview thumbnail on hover | W3.3 | M | NEW | no |
| P8-52 | 20:24-20:31 | control bar | Montage close-ups of control shapes | W3.3 | S | UI | no |
| F-03 | Figma only (volume from 3:04) | control bar | Volume percentage tooltip on hover | W3.4 | S | UI | no |
| F-04 | Figma only (volume from 3:04) | control bar | Volume range 0 to 200% | W3.4 | S | UI | no |
| IA-12 | 3:04-3:10 | control bar | New speaker icon and cone slider details | W3.4 | S | UI | no |
| P1-19 | 2:55-3:03 | control bar | Volume slider kept as cone (start) | W3.4 | S | UI | no |
| P2-01 | 3:04-3:10 | control bar | Cone volume slider (finish of volume topic from part 1) | W3.4 | S | UI | no |
| F-01 | Figma only (bar from 3:16) | control bar | Click total time to show remaining time | W3.5 | S | UI | no |
| F-02 | Figma only (bar from 3:16) | control bar | Current time: hover and click-to-edit | W3.5 | M | NEW? | no |
| IA-15 | 3:48-3:55 | top bar | Bars appear and disappear instantly | W3.6 | S | NEW? | no |
| P2-08 | 3:46-3:55 | top bar | Hover show/hide of top and bottom bars (fullscreen/video) | W3.6 | M | NEW? | no |
| P3-11 | 6:24-6:28 | control bar | Popup closes, controls auto-hide while playing | W3.6 | S | UI | no |
| IB-08 | 11:00-11:05 | top bar | Player chrome geometry: inset rounded video area | W3.7 | S | UI | no |
| IB-35 | 14:00-14:10 | control bar | Resume toast styling | W3.8 | S | NEW | no |
| P6-23 | 14:00-14:10 | control bar | New "continue where you left off" toast near center controls | W3.8 | S | UI | no |
| F-06 | Figma only (buttons from 4:30) | control bar | Panel buttons open, close and switch panels | W4.1 | S | UI | no |
| IA-28 | 7:11-7:16 | sidebar | Right sidebar placement and tab label transition | W4.1 | S | NEW | no |
| IA-36 | 8:29-8:38 | sidebar | Section dividers inside the sidebar | W4.1 | S | UI | no |
| IA-37 | 8:40-8:47 | sidebar | Tab switch animation | W4.1 | S | UI | no |
| IB-36 | 15:08-15:16 | sidebar | Right sidebar tab glyphs and states | W4.1 | S | NEW | no |
| P3-17 | 7:04-7:12 | sidebar | Merge Adjustments + tracks popup into a right sidebar | W4.1 | M | NEW | no |
| P3-18 | 7:12-7:16 | sidebar | Right sidebar with four tabs | W4.1 | M | NEW | no |
| P4-13 | 8:30-8:41 | subtitles | Sidebar tab bar style while it is being built | W4.1 | S | UI | no |
| P4-16 | 8:40-8:42 | audio/video | Tab switch transition (crossfade) | W4.1 | S | UI? | no |
| P4-21 | 8:44-8:52 | audio/video | Sticky footer overlaps the scrolling content | W4.1 | S | UI | no |
| P4-29 | 8:57-9:06 | audio/video | Rows appear one by one (build-up animation) | W4.1 | S | UI? | no |
| F-07 | Figma only (popup from 4:30) | sidebar | "Show Preferences" jumps to the matching settings tab | W4.2 | S | UI | no |
| IA-18 | 4:30-4:44 | audio/video | Tracks popup tab bar style | W4.2 | S | UI | no |
| IA-20 | 4:30-4:56 | audio/video | Audio and video glyphs | W4.2 | S | UI | no |
| P2-16 | 4:30-4:35 | control bar | Subtitle icon on bottom right, opens subtitle track popup | W4.2 | S | UI | no |
| P2-17 | 4:35-4:44 | audio/video | Audio icon on bottom right with tracks and output devices | W4.2 | S | UI | no |
| P2-18 | 4:44-4:56 | audio/video | Video tracks tab (no bar icon) | W4.2 | S | UI | no |
| P3-04 | 5:59-6:02 | subtitles | Subtitle tracks popup opened from control bar subtitle button | W4.2 | S | UI | no |
| F-23 | Figma only (related 9:13-9:19) | audio/video | "Show Statistics" toggle in the Playback tab | W4.3 | M | NEW? | no |
| IA-41 | 8:56-9:08 | sidebar | Playback tab icon | W4.3 | S | UI | no |
| IA-42 | 9:08-9:19 | sidebar | Stepped speed slider with numeric tick labels | W4.3 | S | NEW | no |
| P4-31 | 9:06-9:10 | audio/video | Playback tab: Speed | W4.3 | S | UI | no |
| P4-32 | 9:06-9:10 | audio/video | Playback tab icon and speed slider style | W4.3 | S | UI | no |
| P4-33 | 9:10-9:11 | audio/video | Playback tab: Reverse toggle | W4.3 | M | NEW | postponed |
| P4-34 | 9:11-9:13 | audio/video | Playback tab: Sleep Timer | W4.3 | M | NEW | no |
| P4-37 | 9:17-9:19 | audio/video | Playback tab: Show Metadata, Audio Visualizer, final order | W4.3 | M | NEW? | no |
| F-18 | Figma only (related 8:56) | audio/video | Crop link toggle | W4.4 | S | UI? | no |
| P4-27 | 8:56-9:00 | audio/video | Video tab: Defaults section | W4.4 | S | UI? | no |
| P4-28 | 8:56-9:00 | audio/video | Video tab icon and segmented control style | W4.4 | S | UI | no |
| P4-30 | 8:57-9:06 | audio/video | Video tab: Filters with preview presets (mentioned) | W4.4 | L | NEW? | no |
| IA-40 | 8:48-8:55 | audio/video | EQ preset mini curve icons | W4.5 | S | NEW | no |
| P4-15 | 8:41-8:44 | audio/video | Audio tab: Defaults section | W4.5 | S | UI? | no |
| P4-17 | 8:41-8:44 | audio/video | Audio tab icon and "Test" button style | W4.5 | S | UI | no |
| P4-18 | 8:41-8:44 | audio/video | Audio tab: Synchronization | W4.5 | S | UI | no |
| P4-19 | 8:44-8:51 | audio/video | Audio tab: Filters list (expandable) | W4.5 | S | UI | no |
| P4-20 | 8:44-8:52 | audio/video | Toggle and "Expand Settings" bar styles | W4.5 | S | UI | no |
| P4-22 | 8:46-8:48 | audio/video | Compressor expanded | W4.5 | S | UI | no |
| P4-23 | 8:46-8:52 | audio/video | Filter parameter slider style (value on the label row) | W4.5 | S | UI | no |
| P4-24 | 8:48-8:52 | audio/video | Equalizer expanded (horizontal band sliders) | W4.5 | S | UI | no |
| P4-25 | 8:51-8:56 | audio/video | Equalizer preset dropdown with preview icons | W4.5 | M | UI | no |
| P4-26 | 8:51-8:56 | audio/video | EQ preset preview icons (shape detail) | W4.5 | S | UI | no |
| IA-29 | 7:16-7:30 | sidebar | Sidebar typography and input style | W4.6 | S | UI | no |
| P3-19 | 7:16-7:23 | subtitles | Subtitles tab: Synchronization section, three timing values | W4.6 | S | UI | no |
| P3-20 | 7:20-7:23 | subtitles | Timing sliders under each value | W4.6 | M | NEW | no |
| P3-21 | 7:23-7:29 | subtitles | Subtitles tab: Appearance section | W4.6 | S | UI | no |
| P3-23 | 7:40-7:51 | subtitles | Size Values: Relative / Pixels segmented control | W4.6 | S | UI? | no |
| P4-02 | 7:52-8:03 | subtitles | Subtitle panel state before the preset is applied (context) | W4.6 | S | UI | no |
| P4-12 | 8:30-8:41 | subtitles | Subtitles tab: new "Defaults" section (default subtitle track / language) | W4.6 | S | UI? | no |
| P4-14 | 8:30-8:41 | subtitles | Delay slider: fill starts at zero (bipolar) | W4.6 | S | UI | no |
| IA-34 | 7:53-8:02 | sidebar | Preset selector footer | W4.7 | S | NEW | no |
| IA-35 | 7:57-8:02 | sidebar | Preset dropdown list style | W4.7 | S | NEW | no |
| P4-04 | 7:53-8:02 | subtitles | Per-show settings preset selector (sticky footer of the sidebar) | W4.7 | L | NEW | no |
| P4-05 | 7:58-8:01 | subtitles | Preset dropdown menu (open state) | W4.7 | M | NEW | no |
| P4-06 | 7:58-8:01 | subtitles | Preset menu row icons and styling | W4.7 | S | UI | no |
| P4-07 | 8:01-8:03 | subtitles | Applying a preset changes all values at once | W4.7 | L | NEW | no |
| IA-09 | 2:40-2:44 | playlists/queue | Queue vs Playlist icon geometry | W4.8 | S | UI | no |
| IA-11 | 2:48-2:55 | playlists/queue | Queue panel typography and icon style | W4.8 | S | UI | no |
| IA-43 | 9:29-9:34 | playlists/queue | Queue panel inside the player | W4.8 | S | UI | no |
| IB-19 | 11:52-11:56 | playlists/queue | Queue card header glyphs | W4.8 | S | UI | no |
| IB-37 | 15:08-15:16 | sidebar | Bookmark and chapter list typography | W4.8 | S | NEW | no |
| P1-16 | 2:23-2:45 | playlists/queue | Toggle playlist becomes Queue (playlist vs queue concept) | W4.8 | M | NEW? | no |
| P1-17 | 2:45-2:48 | control bar | Queue button on the right, settings icon becomes gear-with-play | W4.8 | S | UI | no |
| P1-18 | 2:48-2:54 | playlists/queue | Queue popup panel | W4.8 | S | UI? | no |
| P5-01 | 9:24-9:28 | control bar | Next episode problem (end of episode) | W4.8 | S | UI | no |
| P5-02 | 9:29-9:34 | playlists/queue | Queue panel over video (right side) | W4.8 | S | UI | no |
| P5-18 | 11:00-11:03 | playlists/queue | Next episode now plays | W4.8 | S | UI | no |
| P6-09 | 12:48-12:50 | playlists/queue | Queue panel shown as the reason Enqueue is redundant | W4.8 | S | UI | no |
| P7-04 | 15:03-15:08 | control bar | Ctrl+B creates a bookmark instantly | W4.8 | M | NEW | no |
| P7-05 | 15:08-15:14 | sidebar | Bookmarks tab in right sidebar | W4.8 | M | NEW | no |
| P7-06 | 15:13-15:16 | sidebar | Chapters tab in right sidebar | W4.8 | S | UI? | no |
| IA-22 | 5:08-5:16 | menus | "..." main menu icon set (two-tone, per item) | W4.9 | S | UI | no |
| IB-26 | 12:56-13:07 | menus | Main menu two-tone icon set (exact glyphs) | W4.9 | S | UI | no |
| IB-27 | 12:56-13:07 | menus | Main menu typography, spacing, states | W4.9 | S | UI | no |
| IB-28 | 13:07-13:08 | menus | Menu re-order transition | W4.9 | S | UI | no |
| P2-20 | 5:05-5:14 | top bar | Single menu icon replaces the menu bar | W4.9 | S | UI | no |
| P2-21 | 5:08-5:16 | menus | "..." main menu contents (video version, provisional) | W4.9 | S | UI (Customize Player screen and Plugins & Extensions submenu are NEW?) | no |
| P6-11 | 13:07-13:09 | menus | Cleaned-up menu (final order) | W4.9 | S | UI | no |
| P7-09 | 15:28-15:33 | menus | Main "..." menu, Settings item | W4.9 | S | UI | no |
| P8-49 | 19:29-19:36 | menus | Main menu icon details | W4.9 | S | UI | no |
| IA-23 | 5:21-5:27 | menus | Right-click menu icon colors and sizes | W4.10 | S | UI | no |
| P2-23 | 5:21-5:25 | menus | Cleaned and restyled right-click menu | W4.10 | S | UI | no |
| P2-24 | 5:25-5:30 | menus | "Hide UI" item with shortcut Ctrl + \ | W4.10 | M | NEW? | no |
| P2-25 | 5:28-5:30 | control bar | Hide UI state and Ctrl+\ keyboard shortcut | W4.10 | M | NEW? | no |
| F-16 | Figma only (related 11:37) | library | Compact library open/close animation | W5.1 | S | UI | no |
| IA-44 | 10:16-10:22 | library | Library sidebar icons and entrance animation | W5.1 | S | UI | no |
| IA-45 | 10:22-10:27 | library | Back/forward and breadcrumb style | W5.1 | S | UI | no |
| IB-01 | 10:28-10:43 | library | Transitional "cleaned VLC 3" library mock (before final style) | W5.1 | S | UI? | no |
| IB-05 | 10:56-10:59 | library | Add Folder transition | W5.1 | S | UI | no |
| IB-07 | 10:58-11:00 | library | Full-library sidebar icon states | W5.1 | S | UI | no |
| IB-13 | 11:40-11:59 | library | Compact library icon rail states (video only nuance) | W5.1 | S | UI | no |
| IB-21 | 12:12-12:14 | library | Navigation crossfade | W5.1 | S | UI | no |
| P5-06 | 10:12-10:19 | library | New library: built by cleaning up the current (VLC 3 style) library | W5.1 | S | UI | no |
| P5-07 | 10:16-10:22 | library | Library sidebar categories, in order | W5.1 | S | UI | no |
| P5-08 | 10:22-10:27 | library | Back and forward buttons + clickable address line (breadcrumb) | W5.1 | S | UI | no |
| P5-23 | 11:40-11:47 | library | Compact library sidebar over the video | W5.1 | L | NEW? | no |
| P5-25 | 11:47-11:48 | library | Open compact library in full screen | W5.1 | S | UI? | no |
| F-14 | Figma only (related 11:40-12:14) | library | Drill-down levels and going back up | W5.2 | M | NEW | no |
| P5-16 | 10:56-10:59 | library | Add Folder result and folder navigation | W5.2 | L | NEW | no |
| P5-29 | 11:57-11:59 | library | Compact library at Videos root | W5.2 | M | NEW | no |
| IB-20 | 12:07-12:12 | library | Music sub-category icons | W5.3 | S | UI | no |
| IB-22 | 12:00-12:14 | library | Song cover thumbnails | W5.3 | S | UI | no |
| IB-23 | 12:14-12:21 | audio/video | Music view cover and background treatment | W5.3 | S | NEW? | no |
| IB-24 | 12:14-12:23 | control bar | Music bar extra glyphs | W5.3 | S | NEW | no |
| P6-01 | 12:00-12:07 | library | Music folder listing in compact library sidebar | W5.3 | S | UI | no |
| P6-02 | 12:07-12:12 | library | Music section root: Songs, Albums, Artists, Genres | W5.3 | S | UI | no |
| P6-03 | 12:12-12:14 | library | Artist view | W5.3 | S | UI | no |
| P6-04 | 12:14-12:21 | audio/video | Music player view (big cover art) | W5.3 | M | NEW? | no |
| P6-05 | 12:14-12:23 | control bar | Music control bar layout | W5.3 | M | NEW | no |
| IB-25 | 12:23-12:28 | library | Network rows and TV channel icon | W5.4 | S | UI | no |
| P6-07 | 12:23-12:28 | library | Network streams list | W5.4 | S | UI? | no |
| P6-14 | 13:13-13:20 | library | Paste IPTV m3u link -> automatic playlist | W5.4 | M | NEW | no |
| F-11 | Figma only (related 13:20) | library | Playlist "..." menu | W5.5 | M | NEW? | no |
| IB-30 | 13:25-13:30 | playlists/queue | New Playlist thumbnail picker and drop zone | W5.5 | S | NEW? | no |
| P6-15 | 13:20-13:25 | playlists/queue | Playlists list | W5.5 | S | UI | no |
| P6-16 | 13:25-13:30 | playlists/queue | New Playlist dialog flow | W5.5 | M | NEW? | no |
| P6-17 | 13:30-13:33 | library | Add to playlist from elsewhere (file "..." menu) | W5.5 | S | UI? | no |
| P8-34 | 20:20-20:23 | playlists/queue | Closing montage: playlists and queue | W5.5 | S | UI | no |
| F-15 | Figma only (related 13:44) | library | Home "Latest Streams" section | W5.6 | M | NEW | no |
| IB-32 | 13:33-13:44 | sidebar | Rail pins and extra rail items appearance | W5.6 | S | NEW | no |
| IB-33 | 13:44-13:48 | library | Home section headers and compact list visuals | W5.6 | S | NEW | no |
| IB-34 | 13:48-13:55 | library | Full-library Home cards | W5.6 | S | NEW | no |
| IB-47 | 20:52-20:59 | library | Full library sidebar spacing at the end | W5.6 | S | UI | no |
| P6-18 | 13:33-13:40 | sidebar | Sidebar pins | W5.6 | M | NEW | no |
| P6-19 | 13:42-13:44 | sidebar | Recent files tab | W5.6 | M | NEW? | no |
| P6-20 | 13:44-13:48 | library | Home page (compact sidebar version) | W5.6 | L | NEW | no |
| P6-21 | 13:48-13:55 | library | Full library home vs old blank cone | W5.6 | M | NEW | no |
| P8-33 | 20:08-20:19 | library | Closing montage: library | W5.6 | S | UI | no |
| P8-38 | 20:52-20:59 | library | Post-credits Home page, empty state | W5.6 | S | UI | no |
| P8-53 | 20:52-20:59 | library | Post-credits Home icon details | W5.6 | S | UI | no |
| F-12 | Figma only (related 13:30) | library | File "..." menu, full list | W5.7 | M | NEW? | no |
| F-13 | Figma only (rows from 11:40) | library | Library row states | W5.7 | S | UI | no |
| IB-02 | 10:44-10:59 | library | Full-library toolbar glyph details | W5.7 | S | UI | no |
| IB-03 | 10:45-10:51 | library | Sort dropdown menu styling | W5.7 | S | UI | no |
| IB-04 | 10:52-10:57 | menus | Library "..." menu icons (two-tone set) | W5.7 | S | UI | no |
| IB-06 | 10:57-10:59 | library | Grid thumbnail treatment | W5.7 | S | UI | no |
| IB-12 | 11:40-11:59 | library | Compact library header glyphs | W5.7 | S | UI | no |
| IB-14 | 11:40-11:59 | library | Compact list row styles | W5.7 | S | UI | no |
| IB-31 | 13:30-13:33 | library | File row "..." menu icons | W5.7 | S | UI | no |
| P5-11 | 10:44-10:46 | library | New library toolbar (right side of address row) | W5.7 | S | UI | no |
| P5-12 | 10:44-11:59 | library | View mode button (grid / list) | W5.7 | S | UI | no |
| P5-13 | 10:45-10:51 | library | Sorting menu with Unwatched First / Watched First | W5.7 | M | NEW | no |
| P5-14 | 10:44-10:59 | library | Search field in library toolbar | W5.7 | S | UI | no |
| P5-15 | 10:52-10:57 | library | Library "..." more menu | W5.7 | M | NEW? | no |
| P5-17 | 10:57-10:59 | library | Grid view items with real thumbnails and watched state | W5.7 | M | NEW? | no |
| P5-26 | 11:48-11:51 | library | Full-window library in list view | W5.7 | S | UI | no |
| F-17 | Figma only (related 11:48-11:56) | library | Mini player timings and sizes | W5.8 | M | NEW? | no |
| IB-18 | 11:48-11:59 | library | Mini player glyph details | W5.8 | S | UI | no |
| P5-27 | 11:48-11:59 | library | Mini player in the full library | W5.8 | S | UI | no |
| P5-28 | 11:52-11:56 | playlists/queue | Queue attached above mini player, draggable | W5.8 | L | NEW? | no |
| IB-15 | 11:44-11:47 | playlists/queue | Drag ghost style | W5.9 | S | NEW? | no |
| P5-24 | 11:44-11:49 | playlists/queue | Drag from library to queue | W5.9 | L | NEW? | no |
| F-08 | Figma only (footer from 7:53) | sidebar | "Open Advanced Settings" opens the Settings dialog on the matching category | W6.1 | S | UI | no |
| F-19 | Figma only (related 17:36-18:27) | settings | Settings dialog switching | W6.1 | S | UI | no |
| IB-42 | 17:33-17:35 | settings | Settings category nav in the zoom | W6.1 | S | UI | no |
| P7-14 | 16:03-16:30 | settings | Current flow vs desired flow (one settings page with basic then advanced) | W6.1 | S | UI | no |
| P7-16 | 16:57-17:03 | settings | Setting explanations visible via info icon | W6.1 | S | UI | no |
| P7-17 | 17:03-17:33 | settings | Subtitle autodetection fuzziness as human-worded dropdown | W6.1 | S | UI | no |
| P7-18 | 17:33-17:35 | settings | New settings category list (start) | W6.1 | S | UI | no |
| P8-01 | 17:31-17:35 | settings | Use words, not numbers, in dropdowns (tail of part 7) | W6.1 | S | UI | no |
| P8-02 | 17:36-17:40 | settings | Settings window layout and category list | W6.1 | S | UI | no |
| P8-21 | 18:48-18:55 | settings | Info icon on every setting | W6.1 | S | UI | no |
| P8-22 | 18:48-18:55 | settings | "Advanced Options" expander | W6.1 | S | UI | no |
| P8-39 | 17:36-17:39 | settings | Settings nav icons (exact shapes) | W6.1 | S | UI | no |
| P8-40 | 17:39-17:40 | settings | Settings open transition | W6.1 | S | UI | no |
| P8-45 | 18:09-18:14 | settings | Subtitle page scroll behavior | W6.1 | S | UI | no |
| P8-03 | 17:39-17:43 | settings | General page ("Global Settings") | W6.2 | S | UI | no |
| P8-06 | 17:50-17:51 | settings | Interface page ("Interface Settings") | W6.2 | S | UI | no |
| P8-07 | 17:52-17:55 | settings | Privacy page ("Privacy Settings") | W6.2 | S | UI | no |
| P8-08 | 17:56-17:58 | settings | Controls page ("Mouse, Keyboard & Remote Controls") | W6.2 | S | UI? | no |
| P8-09 | 17:59-18:01 | settings | Playback page ("Playback Preferences") | W6.2 | S | UI? | no |
| P8-10 | 18:02-18:05 | settings | Video page ("Video Defaults") | W6.2 | S | UI | no |
| P8-11 | 18:06-18:08 | settings | Audio page ("Audio Defaults") | W6.2 | S | UI? | no |
| P8-12 | 18:09-18:14 | settings | Subtitles page ("Subtitle Defaults") | W6.2 | S | UI? | no |
| P8-14 | 18:15-18:17 | settings | Library page ("Playlists, Folders & Files") | W6.2 | S | UI | no |
| P8-15 | 18:18-18:19 | settings | Network page ("Network Connections & Security") | W6.2 | S | UI | no |
| P8-16 | 18:20-18:22 | settings | Performance page ("Performance Settings") | W6.2 | S | UI | no |
| P8-17 | 18:23-18:25 | settings | Recording page ("Recording, Casting & Streaming Out") | W6.2 | S | UI? | no |
| P8-18 | 18:26-18:27 | settings | Extensions page ("Extensions & Scripts") | W6.2 | S | UI | no |
| P8-20 | 18:28-18:47 | settings | Add-ons vs plugins split | W6.2 | S | UI? | no |
| P8-44 | 18:06-18:08 | audio/video | Inline equalizer panel | W6.2 | S | UI | no |
| IB-39 | 16:01-16:03 | menus | Keyboard Shortcuts menu icon | W6.3 | S | UI | no |
| IB-40 | 15:57-16:01 | settings | Keyboard Shortcuts dialog fine styling | W6.3 | S | UI | no |
| P3-15 | 6:48-6:52 | subtitles | Keyboard shortcut mention for subtitle delay | W6.3 | S | UI? | no |
| P7-12 | 15:57-16:01 | settings | Hotkeys moved into own "Keyboard Shortcuts" dialog | W6.3 | S | UI | no |
| P7-13 | 16:01-16:03 | menus | Direct "Keyboard Shortcuts" item in the main menu | W6.3 | S | UI | no |
| IB-29 | 13:09-13:20 | other | Dialog styling (Open Network Stream, New Playlist) | W6.4 | S | UI | no |
| P6-12 | 13:07-13:10 | menus | Each menu item opens its own dialog | W6.4 | M | NEW? | no |
| P6-13 | 13:09-13:20 | other | "Open Network Stream" dialog | W6.4 | M | NEW | no |
| F-09 | Figma only (related 6:22) | subtitles | Pencil on External Tracks | W6.5 | M | NEW | no |
| F-10 | Figma only (related 6:04-6:20) | subtitles | Add Subtitles "To This File": multi-select subtitle files | W6.5 | M | NEW | no |
| IA-26 | 6:01-6:24 | subtitles | Add Subtitles modal visual details | W6.5 | S | NEW | no |
| P3-05 | 6:02-6:04 | subtitles | "+" on External Tracks opens "Add Subtitles" modal | W6.5 | M | NEW | no |
| P3-06 | 6:04-6:10 | subtitles | Add Subtitles: target dropdown (first dropdown) | W6.5 | M | NEW | no |
| P3-07 | 6:08-6:14 | subtitles | Add Subtitles: source dropdown (second dropdown) | W6.5 | M | NEW | no |
| P3-08 | 6:12-6:20 | subtitles | Add Subtitles, To This Folder + From OpenSubtitles: search, language, auto-matched list | W6.5 | XL | NEW | no |
| P3-09 | 6:16-6:22 | subtitles | Manual re-match per episode (swap icon on hover) | W6.5 | M | NEW | no |
| P3-10 | 6:22-6:24 | subtitles | Save adds the external track | W6.5 | M | NEW | no |
| IA-27 | 6:52-7:04 | control bar | Subtitle timeline cue blocks and buttons | W7.1 | XL | NEW | yes |
| P3-16 | 6:52-7:04 | control bar | Subtitle timeline in the seek bar | W7.1 | XL | NEW | yes |
| P4-35 | 9:13-9:15 | audio/video | Playback tab: Show Subtitle Timeline on Seekbar | W7.1 | XL | NEW | yes |
| P4-36 | 9:15-9:17 | audio/video | Playback tab: Show Waveform on Seekbar | W7.2 | L | NEW | no |
| P6-06 | 12:19-12:23 | control bar | Waveform seek bar | W7.2 | XL | NEW | no |
| IB-38 | 15:16-15:28 | other | OSD typography | W7.3 | S | NEW | yes |
| P7-08 | 15:23-15:28 | other | OSD message also shows the pressed shortcut | W7.3 | M | NEW | yes |
| P8-13 | 18:12-18:14 | subtitles | OSD shows the shortcut being pressed | W7.3 | M | NEW | yes |
| F-22 | Figma only (related 19:20-19:27) | control bar | Customize drag timings | W8.1 | S | NEW | no |
| P8-24 | 19:12-19:19 | control bar | Customize Player dialog | W8.1 | XL | NEW | no |
| P8-25 | 19:20-19:27 | control bar | Drag items in/out of the player bars | W8.1 | XL | NEW | no |
| P8-26 | 19:28 | control bar | Alternate layout result | W8.1 | M | NEW | no |
| P8-46 | 19:12-19:19 | control bar | Customize palette icons (exact shapes) | W8.1 | M | NEW | no |
| P8-47 | 19:20-19:27 | control bar | Customize mode drag visuals | W8.1 | L | NEW | no |
| P8-48 | 19:28 | control bar | Alternate layout icon details | W8.1 | S | NEW | no |
| P8-27 | 19:29-19:36 | menus | Profiles in the main "..." menu | W8.2 | XL | NEW | no |
| P8-29 | 19:47-19:48 | other | Onboarding screen 1: Welcome | W8.3 | M | NEW | no |
| P8-30 | 19:49 | other | Onboarding screen 2: theme and color | W8.3 | L | NEW | no |
| P8-31 | 19:50-19:54 | other | Onboarding screen 3: shortcuts | W8.3 | M | NEW | no |
| P8-50 | 19:47-19:54 | other | Onboarding transitions and details | W8.3 | S | NEW | no |
| IB-44 | 17:43-17:44 | visual style | Light theme control bar look | W8.4 | S | NEW | no |
| P8-04 | 17:43-17:44 | visual style | Light theme | W8.4 | S | UI | no |
| P8-41 | 17:43-17:44 | visual style | Theme switch is instant | W8.4 | S | UI | no |
