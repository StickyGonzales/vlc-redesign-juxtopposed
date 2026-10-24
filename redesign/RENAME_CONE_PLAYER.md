# Rename plan: Cone → Cone Player

Status: **plan only, no code changed.** Nothing here is applied until StickyGonzales answers the decisions in section 1. The plan was written against `wip/next-test` at f14c4303f4 (2026-10-25).

Scope: the **public** brand profile only. The vlc profile (VLC's name and cone) stays as it is.

## 0. How the name is built today

The public name "Cone" comes from four places:

| Source | What it sets | File |
|---|---|---|
| Build values | `BRAND_PRODUCT_NAME` "Cone", `BRAND_EXE` "Cone.exe", `BRAND_INTERNAL_NAME` "cone", `BRAND_REGKEY` `Software\Cone`, `BRAND_INSTALL_DIR` "Cone", `BRAND_PROGID` "Cone" | `configure.ac` (public block, about line 5315), `meson.build` `brand_profiles` (about line 66) |
| Interface texts | `BRAND_NAME`, `BRAND_SHORT_NAME`, `BRAND_TITLE`, tray, About, Quit, welcome, About text and title, `BRAND_CONFIG_DIR`, `BRAND_REGISTRY_KEY`, `BRAND_PROGID`, `BRAND_INSTALL_REGKEY` | `modules/gui/qt/util/brand.hpp` |
| Written-out texts | About 40 sentences that say "Cone" in core and Qt dialogs (section 3) | the files in section 3 |
| Images | Installer bitmaps, the old preferences' layout previews | `extras/package/win32/brand/public/installer-art.js`, `redesign/tools/make_prefs_samples.sh` |

VLC itself uses two names: **"VLC media player"** (`BRAND_NAME`: window title, About, Apps list, installer) and **"VLC"** (`BRAND_SHORT_NAME`: menus and sentences such as "About VLC", "VLC could not ..."). In the public profile both are "Cone" today. That split is the natural place for "Cone Player".

## 1. Decisions for StickyGonzales

| # | Question | Options | Recommendation |
|---|---|---|---|
| R1 | Where does the full name show? | **A:** "Cone Player" where VLC shows "VLC media player" (window and taskbar title, top bar without media, About title, tray tooltip, welcome, Settings > Apps, installer, Start menu, Default apps, Open with, exe details, volume mixer). "Cone" stays in menus and sentences where VLC says "VLC" ("About Cone", "Quit Cone", "Cone could not open ..."). **B:** "Cone Player" everywhere, including the ~40 sentences | **A**. It follows VLC's own pattern, keeps short menu items short, and leaves the core sentences untouched (no core change) |
| R2 | File names of the packages | `ConePlayer-0.3.0-win64.zip` / `coneplayer-0.3.0-win64.exe` / `ConePlayer-0.3.0-x86_64.AppImage`, or keep `Cone-...` | `ConePlayer-...`. Never a space: the zip name and its folder come from `BRAND_PRODUCT_NAME` today (`package.mak` WINPACKAGE), so a space would put "Cone Player-0.3.0-win64" on disk. A separate `BRAND_PACKAGE_NAME` is needed either way |
| R3 | Exe name | Keep `Cone.exe`, or `ConePlayer.exe` | **Keep `Cone.exe`**. Shortcuts, App Paths, `Applications\Cone.exe` and "Open with" choices that people already made point to it. Windows shows the exe's FileDescription ("Cone Player") in Task Manager, the volume mixer and Open with, so the name people see changes anyway |
| R4 | Identity names (settings folder, registry keys, ProgIDs) | Keep "Cone", or rename with migration code | **Keep "Cone"** (section 2). Renaming them loses every tester's settings (the zip keeps its Qt settings in `portable\Cone\`), or needs migration code for no visible gain |
| R5 | Logo text in images | Re-render with "Cone Player", or show the logo only | Re-render. The 150 x 57 installer header has 88 px right of the logo: "Cone Player" at today's 20 px semibold is about 115 px wide, so the header needs about 15 px text or two lines. The 164 px welcome image at 26 px is about 140 px: it fits, but tightly |
| R6 | Version and release title | Ship the rename as 0.3.0; Decision 68's release title becomes "Cone Player <version>: Juxtopposed's redesign on a real VLC 4 fork, not a skin" | Yes, as its own release |
| R7 | Repo name and URLs | Keep `vlc-redesign-juxtopposed` (BRAND_WEBSITE links to it) | Keep. Renaming the repo is separate from the app name |

## 2. Names that stay "Cone" (identity, never shown as the product name)

Changing any of these needs migration code, or leaves duplicates behind. The plan keeps them all:

| Name | Where | Why it stays |
|---|---|---|
| `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone` | `src/win32/dirs.c` APP_DIR_NAME, `brand.hpp` BRAND_CONFIG_DIR | Settings, media library, presets, profiles |
| `portable\Cone\vlc-qt-interface.ini` | `brand.hpp` BRAND_CONFIG_DIR (Qt organization) | Zip users' interface settings |
| `HKCU\Software\Cone` (Lang) | `bin/winvlc.c`, `brand.hpp` BRAND_REGISTRY_KEY | Interface language |
| `HKLM\Software\Cone` | `BRAND_REGKEY` | The installer finds an earlier install with it |
| `Uninstall\Cone` key **name** | NSIS `PRODUCT_UNINST_KEY` (built from `PRODUCT_NAME` today, see section 4) | An upgrade must find and replace it, not add a second Apps entry |
| ProgIDs `Cone.<ext>`, `Cone.DVDMovie`..., verbs `PlayWithCone` / `AddToPlaylistCone`, `ConePlay*OnArrival`, `Clients\Media\Cone`, RegisteredApplications value `Cone` | `BRAND_PROGID` | People's default app choices point to `Cone.<ext>` |
| Product GUID `{f00e45bf-...}`, MSI UpgradeCode | `BRAND_PRODUCT_ID`, `msi/config.wxi.in` | Upgrade identity |
| Mutex / IPC window "Cone ipc <version>", audio session GUID | `src/win32/specific.c`, `modules/control/win_msg.c`, `modules/audio_output/mmdevice.c`, `winstore.c` | Internal; the mixer shows the display name |
| `cone` internal name, `cone.desktop`, `StartupWMClass=cone`, `~/.config/Cone` | `BRAND_INTERNAL_NAME`, `modules/video_output/xcb/window.c`, wip/linux-build `linux-package.sh` | Linux taskbar grouping and settings |
| HTTP realm "Cone", log lines ("quit watchdog: Cone ...") | `src/network/httpd.c`, `modules/gui/qt/util/quit_watchdog.cpp` | Not user-facing (R1 A) |
| `Cone.exe` | `BRAND_EXE` | R3 |

## 3. What changes (option A)

**Build values**

| Value | Now | After | File |
|---|---|---|---|
| `BRAND_PRODUCT_NAME` | Cone | Cone Player | `configure.ac`, `meson.build` (`product_name`) |
| `BRAND_PACKAGE_NAME` (new) | (none: the zip uses BRAND_PRODUCT_NAME) | ConePlayer | `configure.ac`, `meson.build`; used by `extras/package/win32/package.mak` WINPACKAGE, `.github/workflows/build-windows.yml` (unzip glob `win64/*-win64.zip`, already generic), wip/linux-build `linux-package.sh` PKG |
| `BRAND_INTERNAL_NAME` | cone | cone (R2: installer file name `cone-...exe` → `coneplayer-...exe` needs its own value, e.g. `BRAND_PACKAGE_LOWER`, because the Linux side uses `cone` for the desktop file) | `configure.ac`, NSIS `OutFile`, `msi.mak` |

The exe's version info follows automatically (`bin/vlc_win32_rc.rc.in`: ProductName and FileDescription = BRAND_PRODUCT_NAME). This is what Task Manager, the volume mixer, Open with and the exe's Properties > Details show.

**brand.hpp (public block)**

| Macro | Now | After |
|---|---|---|
| BRAND_NAME | Cone | Cone Player |
| BRAND_SHORT_NAME | Cone | Cone (unchanged) |
| BRAND_TITLE (top bar without media, window title) | Cone | Cone Player |
| BRAND_TRAY_HIDE / SHOW | &Hide Cone in taskbar / Sho&w Cone | &Hide Cone Player in taskbar / Sho&w Cone Player |
| BRAND_MENU_ABOUT / QUIT | About Cone / Quit Cone | unchanged (R1 A; B: About Cone Player / Quit Cone Player) |
| BRAND_CORE_GROUP | Cone | Cone Player |
| BRAND_WELCOME_TITLE | Welcome to Cone! | Welcome to Cone Player! |
| BRAND_WELCOME_TEXT | Cone is a free and open source media player ... | Cone Player is a free and open source media player ... |
| BRAND_ABOUT_TEXT | Cone, based on VLC media player ... Cone is not affiliated ... | Cone Player, based on ... Cone Player is not affiliated ... |
| BRAND_ABOUT_TITLE | "Cone " BRAND_VERSION | "Cone Player " BRAND_VERSION |
| BRAND_CONFIG_DIR, BRAND_REGISTRY_KEY, BRAND_PROGID, BRAND_INSTALL_REGKEY | Cone | unchanged (section 2) |

Uses today: BRAND_NAME is the tray tooltip, tray menu and notification title (`dialogs/systray/systray.cpp`), Qt's application display name (`qt.cpp`, which Qt appends to window titles) and `BrandInfo::name()`; BRAND_TITLE is `BrandInfo::title()`, the top bar title without media (`MainDisplay.qml`). None is an identity. Before editing, check every use of BRAND_NAME and BRAND_TITLE again (`git grep -n "BRAND_NAME\|BRAND_TITLE" modules/gui/qt`): a use that is really an identity (a settings key, a file name) must move to BRAND_CONFIG_DIR first.

**Other window titles**

| Place | Now | After | File |
|---|---|---|---|
| Video and visualizer window title (Windows, X11, Wayland) | Cone | Cone Player | `include/vlc_config.h` VOUT_TITLE, `modules/video_output/xcb/window.c`, `modules/video_output/wayland/xdg-shell.c` (core: own build) |
| Startup error box | "Cone could not start." / title "Cone" | title "Cone Player" (the sentence stays, R1 A) | `bin/winvlc.c` START_ERROR_TITLE |
| `--version` / help header | Cone %s, based on VLC %s | Cone Player %s, based on VLC %s | `src/config/help.c` (core) |
| Lua HTTP interface page title | Cone | Cone Player | `modules/lua/libs/httpd.c`, `extras/package/win32/brand/public/brand-webintf.sh` |
| Audio session display name | USER_AGENT_NAME "Cone" | Cone Player (only the user-agent name; the HTTP user agent stays) | `bin/winvlc.c` |

**Sentences (R1 B only, about 40)**: `src/input/decoder.c`, `src/input/input.c`, `modules/access/{dshow/dshow.cpp,dvdnav.c,vdr.c,ftp.c}`, `modules/codec/{fluidsynth.c,avcodec/encoder.c}`, `modules/demux/{avi/avi.c,mp4/mp4.c}`, `modules/misc/audioscrobbler.c`, `modules/gui/qt/dialogs/firstrun/firstrunwizard.cpp` (8), `dialogs/preferences/{preferences.cpp,simple_preferences.cpp}`, `dialogs/open/{open.cpp,open_panels.cpp}`, `dialogs/sout/profile_selector.cpp`, `dialogs/extended/extended_panels.cpp`, `network/addonsmodel.cpp`. With option A these stay "Cone".

**Installer (NSIS, public)**

| Place | Now | After |
|---|---|---|
| Every page title, "Run ...", "Visit the ... Website", component texts | Cone | Cone Player (automatic from PRODUCT_NAME, plus `brand-languages.sh`, which gets the name from `package.mak`) |
| Settings > Apps DisplayName | Cone | Cone Player (automatic: `PRODUCT_DISPLAY_NAME` is `PRODUCT_NAME`; the key name must not follow, section 4) |
| Start menu `StickyGonzales\Cone.lnk`, "Cone - reset preferences ...", "Cone Website", desktop `Cone.lnk` | Cone | Cone Player (plus removing the old names on upgrade, section 4) |
| `Applications\Cone.exe` FriendlyAppName, `Clients\Media\Cone` (Default) and ApplicationName, ApplicationDescription | Cone | Cone Player |
| File type names "MP4 Video File (Cone)" | PRODUCT_SHORT_NAME | "(Cone Player)": set PRODUCT_SHORT_NAME to the full name in the public block (it is only used for these names and two error boxes) |
| Context menus "Play with Cone", "Add to Cone's Playlist" | Cone | Cone Player / Add to Cone Player's Playlist (check the language files after `brand-languages.sh`) |
| Bitmaps | "Cone" | "Cone Player" (R5; re-run `installer-art.js`) |
| MSI (`msi/config.wxi.in`, not built by CI) | ProductName from BRAND_PRODUCT_NAME | follows; folder `Program Files\StickyGonzales\Cone Player` (WiX company\product) |

**Images and docs**

| Place | File |
|---|---|
| Old preferences' layout previews: window title "Cone" | `redesign/tools/make_prefs_samples.sh` → `pixmaps/brand/public/prefs-sample-{modern,classic}.png` |
| README, CREDITS, release notes template, release title (Decision 68) | `README.md`, `CREDITS.md`, wip/ci-release `.github/workflows/release.yml` (title line), release-notes template |
| Linux: desktop file Name=, AppImage / tarball names, README-LINUX title | wip/linux-build `.github/scripts/linux-package.sh` (TITLE, PKG), `build-linux.yml` artifact names (may stay `cone-...`) |
| CLAUDE.md, VIDEO_INDEX "Decisions (Sticky)" | a new Decision line for the rename (next free number) |

## 4. Traps (must be handled, or the rename breaks things)

1. **`PRODUCT_UNINST_KEY` is `Uninstall\${PRODUCT_NAME}`.** With "Cone Player", an upgrade would not find the old `Uninstall\Cone` key: no previous-version detection, no saved component choices (Memento), and two entries in Settings > Apps. Fix: build the key name from `BRAND_PROGID` ("Cone"), and set the displayed name with `DisplayName` = "Cone Player".
2. **`PRODUCT_APPDATA_DIR` is `${PRODUCT_NAME}` in the public block.** "Delete preferences and cache" and the "reset preferences" shortcut would look for `%APPDATA%\Cone Player` and leave `%APPDATA%\Cone`. Fix: pin it to "Cone" (the same value as BRAND_CONFIG_DIR).
3. **Shortcuts are named after `PRODUCT_NAME`.** An upgrade from a Cone installer leaves `Cone.lnk`, `Cone Website.lnk`, `Cone - reset ....lnk` and the desktop `Cone.lnk`. Fix: in the install section (public only), delete the old names before creating the new ones; the uninstaller deletes both.
4. **The zip name comes from `BRAND_PRODUCT_NAME`** (`package.mak` WINPACKAGE, and the folder inside the zip). Fix: the new `BRAND_PACKAGE_NAME` (R2).
5. **`brand-languages.sh` replaces "VLC" with the product name in ~45 language files.** Check that "Cone Player" reads right where VLC's text had "VLC media player" (it would become "Cone Player media player"): run it and grep the output for "Player media player".
6. **Translations of the Qt texts:** the public texts are new msgids that show in English in every language (CONE_RELEASE_NOTES "Dialog texts"); changing them makes new msgids again. No translation is lost, because none exists yet.
7. **The top bar title width** (`BRAND_TITLE` in `MainDisplay.qml` without media) and the About title: "Cone Player" is 2.6 times longer. Check both at the smallest window width.

## 5. Order of work (when R1 to R7 are answered)

1. **Build values and brand.hpp** (section 3), plus traps 1 to 4 in NSIS. Qt-side and packaging only, no core: one branch, `wip/rename-cone-player`.
2. **Core texts** (VOUT_TITLE, help.c, and the sentences if R1 is B): a separate branch and build (CLAUDE.md core rule).
3. **Images:** `installer-art.js` and `make_prefs_samples.sh` re-run, the PNG / BMP outputs committed.
4. **Docs:** README, CREDITS, release workflow title (wip/ci-release), Linux package names (wip/linux-build), CLAUDE.md / VIDEO_INDEX Decision line.
5. **Checks:** `privacycheck.py`, `buildlists.py`, `qmlcheck.py` (if QML changes), makensis of both profiles (warning count unchanged), the vlc profile's preprocessed NSIS script identical apart from line labels, Wine install / upgrade / uninstall like `redesign/INSTALLER_NOTES.md` section 5, with an upgrade from a Cone 0.2.0 installer.

## 6. Test on Windows (PC session)

- Zip: an existing `portable` folder from 0.2.0 still has its settings after the update (Qt settings in `portable\Cone\`).
- About, tray, top bar without media, window and taskbar title, video window title, exe Properties > Details, volume mixer, Task Manager: "Cone Player".
- Installer: every page and bitmap; Settings > Apps shows one entry "Cone Player" after an upgrade from a Cone installer (no leftover "Cone"); the Start menu has only the new shortcuts; Open with and Default apps show "Cone Player"; a type already set to Cone still opens in Cone Player.
- Uninstall: nothing named Cone or Cone Player left (INSTALLER_NOTES.md section 6), and "Delete preferences and cache" removes `%APPDATA%\Cone`.
