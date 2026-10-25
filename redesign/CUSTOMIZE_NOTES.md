# Customize Player, editable top bar, profiles (W8.1b, W8.2): notes for the PC session

Branch `redesign-customize`, from `origin/redesign` b39b9aba9e (2026-10-15). Web session, no VLC build here: nothing in this file is verified on the PC. Every item still needs the build, real screenshots side by side with the Figma PNGs, the UX pass, the performance round and the regression checklist.

## 1. Status

- **Built:**
  1. the Customize Player items Figma shows and VLC had no control for, as real controls of both bars;
  2. the editable top bar (layout per profile, edited in Customize Player);
  3. profiles in the main menu, each with its layouts and its settings, and the restart notice.
- **Not hooked up:** nothing shows until the PC session applies `redesign/CUSTOMIZE_HOOKUP.patch` (section 5). It touches the shared files `mainui.cpp`, `MainInterface.qml`, `Player.qml` and `TopBar.qml`. Without it, the new controls cannot read `RdNowPlaying` / `RdProfiles`, the top bar keeps its fixed layout, and the main menu's Profile entries do nothing.
- **Checks on the last commit:**
  - qmlcheck: `errors: 1 files: 396 crashed: 0` (the known HighResolutionTimeWidget stub), with and without the patch applied. A deliberately wrong property is caught for the new files too.
  - buildlists: `0 problem(s)`.
  - privacycheck: `0 problem(s)`. Only the generic checks ran: the web session has no privacy.local.txt, so run it again on the PC.
  - C++ syntax check of every new or changed C++ file (and of `mainui.cpp` with the patch), against Qt 6.4 headers with `-Wall -Wextra -Wconversion`: no warnings in the new code.
  - The moc output of `RdNowPlaying` and `RdProfiles` compiles.
- **Ran here (not verification):** `RdProfileSettings` (the profile settings logic), linked against VLC's core built from this tree. Results in section 7.
- **Not run here:** the full compile and link of the Qt module, the runtime QML console, anything on Windows. No screenshot exists: the look is only checked against Figma's node values.

## 2. What was built

### 2.1 New controls (Figma "Player - customize" palette)

Each control is a `ControlListModel` type in the redesign's own id range (0x80 on, append only, `player/control_list_model.hpp`), so VLC's reserved ids stay free for upstream. Each is a file in `player/qml/controlbarcontrols/`, listed in `PlayerControlbarControls.qml`. Every control works in the control bar, the top bar and the mini player layout.

| Figma item | Control | What it does |
|---|---|---|
| Divider | `DividerWidget` | The top bar's divider: a 24x28 cell, 18 px line, Divider/Bright. Can be used many times, like the spacers. |
| Forward 10s / Backward 10s | `SkipForward10Button` / `SkipBack10Button` | 10 s relative jumps. The 15 s items are VLC's skip buttons, which already jump 15 s. |
| HDR | `HdrButton` | A list of the video tab's HDR modes (`d3d11-hdr-mode`, through RdEffects). Greyed out where the option does not exist (outside Windows / D3D11). |
| Zoom | `ZoomButton` | A list of VLC's zoom values (`Player.zoom`, as the video tab). |
| Right Sidebar | `RightSidebarButton` | Opens or closes the settings sidebar on Playback (as the gear, Decision 5). |
| VLC Settings | `SettingsButton` | The Settings dialog. |
| Go Home / Playlists | `HomeButton` / `PlaylistsButton` | `RdLibraryNav.openRoot("home" / "playlists")`. In the player they also open the compact library. |
| Thumbnail | `ThumbnailWidget` | The media's cover, 28x28, radius 4, with a BG/A4 placeholder. |
| File Name | `FileNameWidget` | The last part of the media's location. |
| Artist Name | `ArtistNameWidget` | `Player.artist`. |
| Folder Name | `FolderNameWidget` | The folder that holds the file. |
| Playlist Name | `PlaylistNameWidget` | The first media library playlist, by name, that holds the media. |
| Properties | VLC's Information button | Unchanged. |
| Replay | `ReplayButton` | Back to 00:00:00, and playback starts if it was paused. |
| Chapters | `ChaptersButton` | The queue sidebar on Chapters. |
| Favorite | `FavoriteButton` | The media library's favorite flag of the media: the filled heart when set. Greyed out for media outside the library. |
| Bookmark | `AddBookmarkButton` | Adds a bookmark at the current time, as Ctrl + B. |
| Bookmarks | VLC's bookmark button | In the player it now opens the sidebar's Bookmarks tab (Decision 3). Elsewhere it keeps VLC's menu. |
| (top bar) "..." | `MainMenuButton` | The main menu: below the button in the top bar, above it in a bar at the bottom. |
| (top bar) library toggle | `LibraryButton` | The compact library (`RdPanels.libraryRequested(false)`). |
| (top bar) folder chip | `FolderChipWidget` | The compact library on the file's folder (`RdPanels.libraryRequested(true)`). |
| (top bar) title | `MediaTitleWidget` | The media's title or name, centered, elided. |

- **Text items** share `TextInfoWidget`: Inter 14, FG/A2. They shrink and elide when the bar is short of room. Empty, they take no room; in Customize Player they then show their name in FG/A3, so they can still be moved.
- **Choice lists** (HDR, Zoom) share `ChoiceMenuButton`: an RdMenuPanel with the accent check on the current value, above the button in the lower half of the window. The bars stay shown while the list is open.
- **`RdNowPlaying`** (C++, `player/rd_now_playing.*`) gives the file and folder names, the library flag and the playlist name. It asks the media library on the library thread, and only while a Favorite or Playlist Name control is on screen (`watch()` / `unwatch()`).
- **Palette** (`CustomizePalette.qml`):
  - Figma's order: Spacer, Divider, Playback Speed, Forward / Backward 10s and 15s, Stop ... Favorite, Bookmark, Bookmarks, Playlists. Then the top bar's items once removed from it, then VLC's other controls.
  - Figma's icons, and Figma's outline per item: 24x32 spacers and divider, 32x32 Right Sidebar, 28x28 for the items Figma outlines on the Icon itself, 30x32 for the others.
  - Figma's names, with the "Forward \n15s" / "Backward15s" typos fixed (Decision 17).

### 2.2 Editable top bar

- **Storage.** Every profile holds the player's top bar as one more layout record in VLC's profile storage, identifier 3. It uses the same `$id|left|center|right` text as the video, audio and mini player layouts.
  - Stock VLC keeps such a record and ignores it, so stock profiles still load. Profiles saved by stock VLC, and VLC's default styles, simply have no top bar record.
  - `RdProfiles` gives such a profile the design's top bar: "...", library toggle, divider, folder chip | title | fullscreen. Fullscreen is left out when the profile's control bar already has one (VLC's other styles).
  - Adding this default does not count as an edit.
- **Live bar** (`TopBar.qml` with the patch, `player/qml/RdTopBarZone.qml`):
  - The cone and the window buttons stay where they are.
  - The left zone follows the cone.
  - The center zone is centered on the window and kept between the other zones.
  - The right zone sits between the window's maximize and close buttons, where Figma's top bar has its fullscreen button. `CSDWindowButtonSet` gets a middle slot for it, and tells the window's hit test where the close button moved.
  - Without the window buttons of a client side decoration, the right zone is at the right end. With a themed button set, it sits just before the set.
  - Top bar sizes:
    - icon buttons 28x32 in the left and center zones, 36 wide between the window buttons;
    - 10 px between controls, none next to a divider.
  - The bars stay shown while the pointer is over a zone, as they did over the top bar's buttons.
  - The library's own top bar (`MainDisplay.qml`, a Phase 5 file, untouched) keeps its fixed "...", title and fullscreen.
- **Customize Player** (`CustomizeTopBar.qml`): the edited top bar is drawn over the live one, as the edited control bar is drawn over the control bar.
  - Every movable item has Figma's dashed outline: the icons 28x28, the divider 24x28, the folder chip and title on themselves, the right zone's cells 36x24.
  - The window buttons keep Figma's dashed 36x24 outline but cannot be moved.
  - Items move between the top bar, the control bar and the box. The box no longer lists what either bar holds.
  - Save and Cancel cover the top bar like the other layouts: VLC's own save, and reload.
- **Title row of the dialog.** It is Figma's: title and X. VLC's profile dropdown and "..." menu are gone (INTERACTIONS: they make way for the main menu with W8.2). The video / audio / mini player layout tabs stay in the footer (W8.1a decision).

### 2.3 Profiles

- **Main menu** (`menus/rd_menu_model.cpp`, `RdMainMenu.qml`): "Profile (name)" after the divider below Open Recent (Figma "Profiles").
  - The submenu: the profiles with the selected one checked, a divider, and "+ New".
  - Then "Rename Profile" and "Delete Profile" (the last one is greyed out when only one profile is left). Figma has no place to rename or delete a profile; see the decisions in section 4.
- **Selecting a profile** (`RdProfiles.select`):
  1. The bars switch at once.
  2. On a worker thread, the current settings are kept in the profile being left, and the selected profile's settings are written to VLC's configuration, which is saved.
  3. Then MainCtx reads its options again (accent, fullscreen bars, pinned controls ...).
  4. The color scheme follows.
  5. RdEffects re-reads every value, so the sidebar and the Settings pages show the profile's values.
  - A profile that has no settings yet (VLC's own profiles) keeps the current ones and is given them.
- **"+ New"** asks for a name ("Profile", or "Profile (2)" ... by default). It copies the current layouts and the current settings into a new profile, and selects it (Decision 25).
- **Rename / Delete** act on the selected profile. Delete asks first. The profile that takes the deleted one's place is applied.
- **What a profile's settings are** (`dialogs/toolbar/rd_profile_settings.*`):
  - Every module's options whose value differs from VLC's default, plus the color scheme.
  - Left out: passwords, the first-run question, and the audio outputs' last volume.
  - Kept in `<VLC user data folder>/rd-profiles.json`, by profile name.
- **Notice** (`RdProfileNotice.qml`, Decision 29), in the resume toast's style, over every view:
  - When some changed options only apply after a restart, it says so, with "Restart Now" and a close button. Restart Now starts VLC again with `--no-one-instance` and quits, as the Performance page does.
  - When options changed that apply from the next file while one plays, it says that for 6 s.
  - Which options are which:
    - **Apply at once:** the interface's live options (qt-accent-color, qt-fs-sensitivity, qt-pin-controls, qt-fs-opacity, qt-smooth-scrolling, qt-max-volume, qt-safe-area, qt-video-double-click, qt-cast-discovery, qt-seek-thumbnails, qt-seek-waveform, mouse-hide-timeout).
    - **After a restart:** hotkeys; the Interface subcategories; Advanced > Misc; the play queue and service discovery options; interface and logger plugins.
    - **From the next file:** everything else.

## 3. VIDEO_INDEX rows covered

Please update their Status after the PC test. Suggested: `in progress (redesign-customize <hash>, not verified)`.

| Row | Id | What | State |
|---|---|---|---|
| 302 | P8-24 | Customize Player palette, every Figma item | built, except Picture in Picture (Decision 1) |
| 303 | P8-46 | Palette icons | built (Figma icons, outlines per item) |
| 304 | P8-25 | Drag items in and out of both bars | built for the top bar, the control bar and the box; the seek row is not movable (section 8) |
| 305 | P8-47 | Drag visuals: dashed outlines on both bars, live re-layout | built (top bar added) |
| 306 / 307 | P8-26 / P8-48 | The alternate layout | possible except the seek row on its own row (section 8) |
| 308 | P8-27 | Profiles in the main menu, every setting changes with the profile | built |
| 309 | P8-49 | The Profile entry's icon and submenu details | built (profile_two-tone-yes, accent check, divider before "+ New") |
| 322 | P8-36 | Favorite dragged into the bar (closing montage) | built |
| 348 | F-22 | Drag timings | the 50 ms shifts as before; the 600 ms drop of Favorite is not built |

Also: the W4.9 decision (row 107: "Profile (Movies)" left out until W8.2) and the W8.1a profile decision (row 186) are replaced by section 4.

## 4. Decisions (Claude) to add to VIDEO_INDEX.md

One line each:
- W8.1b: the new controls use their own id range (0x80 on, append only). Stock VLC shows its fallback control for them.
- W8.1b: the top bar layout is identifier 3 of VLC's profile record. A profile without one gets the design's top bar, without fullscreen when its control bar has one.
- W8.1b: the top bar's right zone sits between maximize and close (where Figma has fullscreen); without client side window buttons, at the right end.
- W8.1b: in Customize Player the window buttons keep Figma's dashed outline but cannot be moved; the cone is not movable.
- W8.1b: the divider can be used many times, like the spacers.
- W8.1b: HDR and Zoom open short lists of the video tab's values (redesign menu style). Right Sidebar toggles the settings sidebar on Playback. Go Home and Playlists open the compact library on that page in the player.
- W8.1b: VLC's bookmark button (the Figma "Bookmarks" item) opens the sidebar's Bookmarks tab in the player.
- W8.1b: File Name is the location's last part; Folder Name its folder; Playlist Name the first library playlist (by name) holding the media; Thumbnail the cover, 28x28 radius 4.
- W8.1b: Favorite is the media library's favorite flag of the media.
- W8.1b: Picture in Picture is not in the palette (Decision 1).
- W8.2: Customize Player's title row is Figma's (title and X). The profiles moved to the main menu's "Profile (name)" submenu, which adds Rename Profile and Delete Profile under "+ New" (not in Figma: Decision 21).
- W8.2: "+ New" asks for a name in the redesign prompt ("Profile", "Profile (2)" ...); Delete asks first.
- W8.2: a profile's settings are every option that differs from VLC's default (no passwords, first-run question or audio outputs' last volume) plus the color scheme, in rd-profiles.json by name. A profile without stored settings takes the current ones.
- W8.2: the notice uses the resume toast's style: Restart Now and a close button for restart options, and 6 s for options that apply from the next file while one plays.

## 5. PC session hookups

### 5.1 Apply the patch

Run from the repo root:
```
git apply redesign/CUSTOMIZE_HOOKUP.patch
```
- It applies cleanly on this branch.
- `redesign/WAVEFORM_HOOKUP.patch` (branch redesign-waveform) adds lines at the same place in `mainui.cpp`. If that one is in first, use `git apply -3`, or add the two registrations below by hand.
- Then delete the patch file in the same commit.

### 5.2 `modules/gui/qt/maininterface/mainui.cpp`

Includes, after `player/rd_seek_thumbnailer.hpp`:
```
#include "player/rd_now_playing.hpp"
#include "dialogs/toolbar/rd_profiles.hpp"
```
In the `VLC.Player` block, after the RdSeekThumbnailer registration:
```
        // redesign (W8.1b / W8.2): what the Customize Player items show about the playing
        // media, and the profiles (top bar layout, settings)
        qmlRegisterSingletonInstance<RdNowPlaying>(uri, versionMajor, versionMinor, "RdNowPlaying",
                                                   new RdNowPlaying(m_mainCtx, m_intf->p_mainPlayerController, this));
        qmlRegisterSingletonInstance<RdProfiles>(uri, versionMajor, versionMinor, "RdProfiles",
                                                 new RdProfiles(m_intf, m_mainCtx, this));
```

### 5.3 `modules/gui/qt/maininterface/qml/MainInterface.qml`

Before the Customize Player loader:
```
        // redesign (W8.2, Decision 29): tells when a profile's settings apply only from the next
        // file or after a restart, over every view
        RdProfileNotice { }
```

### 5.4 `modules/gui/qt/player/qml/Player.qml` (the TopBar instance)

- Remove `title: ...` and `libraryOpen: rootPlayer._libraryShown`. The title, library toggle and folder chip are now controls.
- Replace `onLibraryToggleRequested` / `onFolderRequested` with:
  ```
        Connections {
            target: RdPanels

            function onLibraryRequested(reveal) {
                rootPlayer.toggleLibrary(reveal)
            }
        }
  ```

### 5.5 `modules/gui/qt/player/qml/TopBar.qml`

- **Player mode** (`showLibraryButtons` and `RdProfiles.topBarModel` set): the cone stays, and three `RdTopBarZone`s take the place of the fixed items. Left after the cone, center on the window, right in the window buttons' middle slot (`middleItem`) or at the right end.
- **Removed:** the fixed library toggle, divider and folder chip; the `folderName` and `libraryOpen` properties; and the `libraryToggleRequested` / `folderRequested` signals.
- **Library mode** (MainDisplay): unchanged. The "..." menu button, the title and the fullscreen button show only there.
- **CSD set:** `showFullscreenButton` is now bound to `!root._editable`.

### 5.6 Nothing else

The build lists already have every new file.

## 6. Files changed

**New:**
- `modules/gui/qt/player/rd_now_playing.hpp`, `.cpp`
- `modules/gui/qt/dialogs/toolbar/rd_profiles.hpp`, `.cpp`
- `modules/gui/qt/dialogs/toolbar/rd_profile_settings.hpp`, `.cpp`
- `modules/gui/qt/player/qml/RdTopBarZone.qml`
- `modules/gui/qt/dialogs/toolbar/qml/CustomizeTopBar.qml`, `RdProfileNotice.qml`
- `modules/gui/qt/player/qml/controlbarcontrols/`:
  - shared bases: `ChoiceMenuButton`, `TextInfoWidget`;
  - `AddBookmarkButton`, `ArtistNameWidget`, `ChaptersButton`, `DividerWidget`, `FavoriteButton`, `FileNameWidget`, `FolderChipWidget`, `FolderNameWidget`;
  - `HdrButton`, `HomeButton`, `LibraryButton`, `MainMenuButton`, `MediaTitleWidget`, `PlaylistNameWidget`, `PlaylistsButton`;
  - `ReplayButton`, `RightSidebarButton`, `SettingsButton`, `SkipBack10Button`, `SkipForward10Button`, `ThumbnailWidget`, `ZoomButton` (all `.qml`).
- `redesign/CUSTOMIZE_HOOKUP.patch`, `redesign/CUSTOMIZE_NOTES.md`

**Changed:**
- `modules/gui/qt/player/control_list_model.hpp`: the new ids.
- `modules/gui/qt/player/qml/PlayerControlbarControls.qml`: the new controls.
- `modules/gui/qt/player/qml/RdPanels.qml`: `libraryRequested`.
- `modules/gui/qt/player/qml/controlbarcontrols/BookmarkButton.qml`: the Bookmarks tab in the player.
- `modules/gui/qt/dialogs/toolbar/qml/`:
  - `CustomizePlayerDialog.qml`: the top bar; profile UI removed.
  - `CustomizePalette.qml`: order, icons, names, outlines; the top bar's items.
  - `CustomizeZone.qml`, `CustomizeZoneItem.qml`: top bar sizes.
  - `CustomizeNamePrompt.qml`: confirm mode, key capture, focus restore.
- `modules/gui/qt/widgets/qml/CSDWindowButtonSet.qml`: the middle slot.
- `modules/gui/qt/menus/rd_menu_model.cpp`, `.hpp`: the Profile submenu.
- `modules/gui/qt/menus/qml/RdMainMenu.qml`: profile actions, prompt, `popupAbove`.
- `modules/gui/qt/meson.build`, `modules/gui/qt/Makefile.am`.
- `redesign/INTERACTIONS.md`: section 3.

## 7. Tests run here

`RdProfileSettings` was linked against VLC's core built from this tree, with a throwaway configuration folder, and run under AddressSanitizer with leak detection. No errors.

| Step | Result |
|---|---|
| capture, fresh configuration | 0 options differ from the defaults |
| set loop, key-play, rate 1.5, deinterlace-mode yadif; capture | those 4 |
| write the empty profile | all 4 back to their defaults; "from the next file": yes; "after a restart": loop, key-play |
| write the 4-option profile as read back from JSON (numbers as doubles) | same values as captured |
| write the same profile again | nothing changed, no notice |
| configuration file | saved (`vlcrc` written) |

Nothing else ran: the QML and the other C++ were only compiled.

## 8. Not done, or limits

- **The seek row is not movable.** Figma customize-1 and the alternate layout (customize-7) put the seek row on its own full-width row above the controls. That is a two-row control bar layout (a seek row item in the layout model, and ControlBar / PlayerControlLayout changes in shared files); it was not part of this task's three points. Everything else of the alternate layout can be made: the top bar's items, the title, fullscreen and Favorite in the bottom bar, the transport in the center.
- **Picture in Picture** is not in the palette (Decision 1).
- **Favorite's 600 ms drop** (F-22) is not animated differently from the 50 ms shifts.
- **The favorite state** comes from the library when the media changes or the heart first appears. A change made in the library meanwhile shows after the next media change.
- **Keyboard order in the top bar:** left and right go along each zone's controls, and from zone to zone, by the top bar's Navigation items. Tab order is the items' creation order. Check it on the PC.
- **Profiles switched while a media plays:** the input, decoders and outputs keep their values until the next file (the notice says so). Options applied live by the sidebar (RdEffects' audio and video filters) take the profile's values on the next file too.
- **Hotkeys of a profile** apply after a restart (the notice says so). This is the same limit as the Keyboard Shortcuts dialog.
- **Not verified on the PC, nothing.** No runtime QML console here.

## 9. Performance risks to measure first (PERF.md)

1. **A profile switch:** the bars switch in the same frame. The settings are read and written on a worker thread: the first switch walks every plugin's options once (a few ms), then about 3000 option reads, the changed writes, and one configuration save. Measure the frame time of the click and the time until the notice.
2. **The top bar:** its controls are created at once, as before; a few more objects (the zones' layouts). Measure startup and opening a file against stock VLC.
3. **RdNowPlaying with Favorite or Playlist Name in a bar:** one library query per media change, with up to 200 playlists listed for the name. Measure with a large library and a quick next / next / next.
4. **Customize Player:** with the top bar in it, about 10 more outlined items. Check 60 fps while dragging.

## 10. UX pass and tests for the PC

- **Customize Player:**
  - Drag every new item into the top bar and the control bar and back. Check that each works in both bars and in the mini player layout.
  - Drag the top bar's items down and the control bar's items up.
  - Save survives a restart. Cancel, X and Escape put both bars back.
  - Compare against Player - customize.png ... customize-6.png and Controls.png, at the same scale.
- **Live top bar:**
  - Figma "topbar" spacing: cone, "..." 7 px after it, the library toggle 10 px later, divider, chip, title centered on the window.
  - The window buttons and fullscreen at 36 px.
  - Narrow window: the title elides, nothing overlaps.
  - Native decorations (CSD off).
  - Fullscreen: the right zone without window buttons.
  - The library's top bar is unchanged.
- **New controls:**
  - every function above;
  - HDR on Windows / D3D11 and greyed elsewhere;
  - Zoom without video greyed;
  - Favorite on a library file and on a file outside it;
  - Playlist Name on a file in a playlist;
  - Replay while paused;
  - the choice lists close on an outside click and on Escape, and keep the bars shown.
- **Profiles:**
  - New, select, rename, delete, from the main menu in the player and in the library.
  - A theme, accent or fullscreen-bar setting changes with the profile at once.
  - A hotkey change shows the restart notice, and Restart Now restarts.
  - A deinterlace change while playing shows the next-file notice.
  - Profiles and their settings survive a restart.
  - Stock profiles load. A profile saved by this build loads in stock VLC (the extra record is ignored).
- **Regression checklist,** with the top bar's main menu, library toggle and folder chip (the library opens on the file's folder).
