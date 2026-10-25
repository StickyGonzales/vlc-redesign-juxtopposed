# Rename plan: Cone → Cone Player

Status: **built on `wip/cone-player`, tested under Wine only, not merged** (section 7). StickyGonzales answered R1 to R7 on 2026-10-25 (section 1, Decision 73). The rename ships with **Cone Player 1.0**, the release where Cone leaves beta; nothing of it goes into a 0.x beta, so the branch waits for 1.0. The plan was written against `wip/next-test` at f14c4303f4 (2026-10-25).

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

## 1. Decisions (StickyGonzales, 2026-10-25)

| # | Decided |
|---|---|
| R1 | **A:** "Cone Player" where VLC shows "VLC media player"; "Cone" stays in menus and sentences where VLC says "VLC" ("About Cone", "Quit Cone", "Cone could not open ..."). No core sentences change |
| R2 | Package names `ConePlayer-1.0.0-win64.zip`, `coneplayer-1.0.0-win64.exe`, `ConePlayer-1.0.0-x86_64.AppImage`; never a space (a new `BRAND_PACKAGE_NAME`) |
| R3 | The exe stays `Cone.exe` |
| R4 | Every identity name in section 2 stays "Cone" (no migration code) |
| R5 | The images are re-rendered with "Cone Player" (installer header with smaller text or two lines) |
| R6 | **Changed from the recommendation:** the rename ships with **1.0**, when Cone leaves beta, not as 0.3.0. The 0.x betas keep the name Cone. Decision 68's release title becomes "Cone Player 1.0.0: Juxtopposed's redesign on a real VLC 4 fork, not a skin" from 1.0 on |
| R7 | The repo name and URLs stay (`vlc-redesign-juxtopposed`) |

The table below is the question as it was asked, kept for the reasons behind each answer.


| # | Question | Options | Recommendation |
|---|---|---|---|
| R1 | Where does the full name show? | **A:** "Cone Player" where VLC shows "VLC media player" (window and taskbar title, top bar without media, About title, tray tooltip, welcome, Settings > Apps, installer, Start menu, Default apps, Open with, exe details, volume mixer). "Cone" stays in menus and sentences where VLC says "VLC" ("About Cone", "Quit Cone", "Cone could not open ..."). **B:** "Cone Player" everywhere, including the ~40 sentences | **A**. It follows VLC's own pattern, keeps short menu items short, and leaves the core sentences untouched (no core change) |
| R2 | File names of the packages | `ConePlayer-1.0.0-win64.zip` / `coneplayer-1.0.0-win64.exe` / `ConePlayer-1.0.0-x86_64.AppImage`, or keep `Cone-...` | `ConePlayer-...`. Never a space: the zip name and its folder come from `BRAND_PRODUCT_NAME` today (`package.mak` WINPACKAGE), so a space would put "Cone Player-1.0.0-win64" on disk. A separate `BRAND_PACKAGE_NAME` is needed either way |
| R3 | Exe name | Keep `Cone.exe`, or `ConePlayer.exe` | **Keep `Cone.exe`**. Shortcuts, App Paths, `Applications\Cone.exe` and "Open with" choices that people already made point to it. Windows shows the exe's FileDescription ("Cone Player") in Task Manager, the volume mixer and Open with, so the name people see changes anyway |
| R4 | Identity names (settings folder, registry keys, ProgIDs) | Keep "Cone", or rename with migration code | **Keep "Cone"** (section 2). Renaming them loses every tester's settings (the zip keeps its Qt settings in `portable\Cone\`), or needs migration code for no visible gain |
| R5 | Logo text in images | Re-render with "Cone Player", or show the logo only | Re-render. The 150 x 57 installer header has 88 px right of the logo: "Cone Player" at today's 20 px semibold is about 115 px wide, so the header needs about 15 px text or two lines. The 164 px welcome image at 26 px is about 140 px: it fits, but tightly |
| R6 | Version and release title | Ship the rename as 0.3.0; Decision 68's release title becomes "Cone Player <version>: Juxtopposed's redesign on a real VLC 4 fork, not a skin" | Yes, as its own release (decided otherwise: with 1.0) |
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

## 5. Order of work (for 1.0)

The work lives on its own branch until 1.0 and is merged only for the 1.0 release (R6): betas before it keep shipping as Cone.

1. **Build values and brand.hpp** (section 3), plus traps 1 to 4 in NSIS. Qt-side and packaging only, no core: branch `wip/cone-player`.
2. **Core texts** (VOUT_TITLE, help.c; no sentences, R1 is A): a separate branch and build (CLAUDE.md core rule).
3. **Images:** `installer-art.js` and `make_prefs_samples.sh` re-run, the PNG / BMP outputs committed.
4. **Docs:** README, CREDITS, release workflow title (wip/ci-release), Linux package names (wip/linux-build), CLAUDE.md / VIDEO_INDEX Decision line.
5. **Checks:** `privacycheck.py`, `buildlists.py`, `qmlcheck.py` (if QML changes), makensis of both profiles (warning count unchanged), the vlc profile's preprocessed NSIS script identical apart from line labels, Wine install / upgrade / uninstall like `redesign/INSTALLER_NOTES.md` section 5, with an upgrade from the last Cone 0.x installer.

## 6. Test on Windows (PC session)

Needs a Windows build of `wip/cone-player` (Actions, build-windows, Run workflow, branch `wip/cone-player`, brand public; the core commit is part of it, so it is a core build) and, for the upgrade, a Cone 0.2.0-style installer: the same workflow on `wip/next-test` (its `cone-installer-win64` artifact, `cone-0.1.0-win64.exe`), and the 0.2.0 beta zip for the portable part. The new installer is the `cone-installer-win64` artifact, now named `coneplayer-0.1.0-win64.exe`; the zip is `ConePlayer-0.1.0-win64.zip`. A manual run takes the default version 0.1.0 (only a vX.Y.Z tag sets it), so both installers have the same version (step 8). Use a throwaway Windows (Windows Sandbox or a VM), as in `redesign/INSTALLER_NOTES.md` section 6.

**A. Portable zip (an existing beta folder)**
1. Copy a 0.2.0 beta folder that has a `portable` folder with settings (a changed hotkey, a preset, the library) into the Sandbox and run it once.
2. Unzip `ConePlayer-0.1.0-win64.zip`; its top folder is `ConePlayer-0.1.0`. Copy its contents over the beta folder (keep `portable`), start `Cone.exe`: the settings, presets and library are still there (Qt settings in `portable\Cone\vlc-qt-interface.ini`).

**B. Names in the app**
3. The top bar without media, the window and taskbar title, About (title "Cone Player <version>", "based on VLC <version>" under it, the About text), the welcome / onboarding title, the tray tooltip and its "Hide Cone Player in taskbar" / "Show Cone Player" items: "Cone Player". The "..." menu still says "About Cone" and "Quit Cone", and error dialogs say "Cone could not ..." (R1).
4. Smallest window width: the top bar title without media and the About title fit (trap 7).
5. Settings: a setting whose VLC text says "VLC media player" shows "Cone Player"; one that says "VLC" shows "Cone".
6. Audio visualizer (or `--no-embedded-video`): the separate video window's title is "Cone Player". `Cone.exe --version` in a console: "Cone Player <version>, based on VLC ...". Task Manager, the volume mixer and `Cone.exe` Properties > Details (Product name, File description): "Cone Player".

**C. Upgrade from a Cone beta (installer)**
7. Install VLC from videolan.org, then `cone-0.1.0-win64.exe` (the wip/next-test build, still named Cone) with the desktop shortcut ticked. Start Cone, change a setting, close it.
8. Run `coneplayer-0.1.0-win64.exe`. Every page shows "Cone Player" and the new images (welcome side image "Cone Player / based on VLC", header logo with "Cone Player"). With two 0.1.0 builds the second page says Cone Player of this version is already installed: pick "Add/Remove/Reinstall components", Next, keep the components, finish. (With a newer version, as 1.0.0 over a 0.x beta, it says "An older version of Cone Player is installed" with the upgrade selected; checked under Wine, section 8. The reinstall choice does not clear the old file list, like the silent install tested there, and the old shortcuts go either way.)
9. Settings > Apps: **one** entry, "Cone Player", version <version>, publisher StickyGonzales; no "Cone" entry. VLC media player is still listed.
10. Start menu, StickyGonzales folder: "Cone Player", "Cone Player Website", "Cone Player - reset preferences and cache files", Documentation, Release Notes; **no** "Cone", "Cone Website" or "Cone - reset ...". Desktop: "Cone Player" only, no "Cone". `C:\Program Files\Cone` still holds `Cone.exe` and has "Cone Player Website.url", no "Cone Website.url".
11. Start Cone Player: the setting from step 7 is still there (`%APPDATA%\Cone`).
12. Open with on an `.mp4`: "Cone Player" with its logo; Settings > Apps > Default apps lists "Cone Player"; a type that was set to Cone before opens in Cone Player. Right click a folder: "Play with Cone Player", "Add to Cone Player's Playlist".
13. VLC still opens its files with its own settings; `C:\Program Files\VideoLAN\VLC` untouched.

**D. Uninstall**
14. Settings > Apps > Cone Player > Uninstall, tick "Delete preferences and cache": `C:\Program Files\Cone`, the StickyGonzales Start menu folder, the desktop shortcut and every Cone / Cone Player entry in Apps, Default apps and Open with are gone; `%APPDATA%\Cone` is gone (with PR #33 merged also `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone`); regedit finds no `Cone` key under HKLM. VLC still works with its settings.

## 7. Implementation (wip/cone-player, 2026-10-25)

Branch from `wip/next-test` (82bde58b00) with this plan (PR #45) merged in. Not merged anywhere: it waits for 1.0 (R6).

| Commit | What | Build |
|---|---|---|
| 3370583821 | Build values (`BRAND_PRODUCT_NAME` "Cone Player", new `BRAND_INSTALLER_NAME` coneplayer and `BRAND_PACKAGE_NAME` ConePlayer in configure.ac; meson has `installer_name` only, it builds no zip), brand.hpp (full name, short name, tray, welcome, About), `engineText()` (VLC's full name → the full name, "VLC" → "Cone"), the zip's README.txt, the CI installer artifact path | non-core |
| fc1c8ea281 | NSIS upgrade path: `Uninstall\Cone` key kept, `PRODUCT_APPDATA_DIR` pinned to "Cone", the beta's shortcuts and website link removed on install, a leftover desktop shortcut removed on uninstall | non-core |
| 14e5c149a8 | Installer images and the old preferences' layout previews re-rendered | non-core |
| 480528344e | VOUT_TITLE, `--version` and help console title, start error box title and audio session name (`bin/winvlc.c`), web interface page title | **core: its own build** |

Differences from section 3, decided while building:
- `engineText()` also changed (section 3 only listed brand.hpp): it maps "VLC media player" to the full name, like the installer's `brand-languages.sh` already did, and "VLC" to the short name.
- The side images' second line was "Media player", which repeats the new name; it reads "based on VLC" now. The header and MSI banner moved the logo 12 px left and use 16 px text, because "Cone Player" at 20 px does not fit the 150 px header (R5).
- The zip's `README.txt` names Cone Player (it is the first thing a zip user reads).
- `BRAND_INTERNAL_NAME` stays "cone" (the exe's InternalName); the installer files take the new `BRAND_INSTALLER_NAME`. The CI artifact keeps its name `cone-installer-win64`, but the files inside it are named `coneplayer-*`: wip/ci-release's patterns need the update listed below.

Left for the 1.0 release work (other branches, not on this one):
- wip/ci-release: `release.yml`'s release title (Decision 68 → "Cone Player <version>: ..."), `.github/scripts/release-package.sh` (`cone-*-win64.exe` → `coneplayer-*-win64.exe`, and its zip pattern) and its `build-windows.yml` `cone-release-files` paths, which will also conflict with this branch's artifact path line.
- wip/linux-build: `linux-package.sh` package names (`ConePlayer-<version>-linux-x86_64`, AppImage), the desktop file's `Name=` and README-LINUX title; `cone.desktop`, `StartupWMClass=cone` and `~/.config/Cone` stay (R4).
- README.md and CREDITS.md: written with the 1.0 download links.
- Linux: `bin/vlc.c` sets VLC's user agent name, so the PulseAudio / PipeWire mixer shows VLC's name for Cone on Linux (before and after the rename; Windows uses `bin/winvlc.c`, changed here).
- PR #33 (installer) merges cleanly with this branch (checked: only `redesign/VIDEO_INDEX.md` conflicts, between #33 and wip/next-test); together they were tested (section 8).

Independent review (fresh agent, no HIGH findings), fixed on this branch:
- MED: `redesign/tools/test-latest.bat` looks for the zip folder `ConePlayer-*` first, then `Cone-*`.
- MED: the MSI (not built by CI) keeps the identity name: `NsisUninstallName` "Cone" for its search for an NSIS install (it looked for `Uninstall\Cone Player`), and `ShortProductName` "Cone" (its folder `StickyGonzales\Cone`, Start menu folder and RegisteredApplications value, like the NSIS installer).
- LOW: the web interface's "VLC can ..." sentence takes the short name (`brand-webintf.sh` gets it as a fifth argument); `BRAND_CORE_GROUP` (the Settings group of the core options) is "Cone", as VLC uses "VLC" there; the X11 / Wayland comments name VOUT_TITLE.
- Left as is (LOW): the uninstaller's `DeleteRegKey ... Uninstall\${PRODUCT_NAME}` now aims at a key that never exists (harmless, the real key is deleted right after); X11's WM_ICON_NAME is the full name (VLC uses "VLC" there; it is rarely shown).

## 8. Wine test (done here)

Stub payload installers from the real scripts (as in `redesign/INSTALLER_NOTES.md` section 5): VLC (vlc profile of this branch), a Cone 0.2.0 beta from `wip/next-test`'s unchanged installer, and Cone Player 1.0.0 from this branch.
- makensis: all three compile with 68 warnings (missing translations, the count before the rename). The vlc profile's filled-in script differs from `wip/next-test`'s only inside public-only blocks; its helpers and language files are identical.
- **Silent upgrade** (VLC, beta, settings in `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone`, `HKCU\Software\Cone`, then Cone Player `/S`): one Settings > Apps key, `Uninstall\Cone`, with DisplayName "Cone Player" and version 1.0.0 (no other Cone key in either registry view); Start menu and desktop hold only the Cone Player names; "Cone Website.url" replaced by "Cone Player Website.url"; the settings unchanged; no line of the VLC-only registry state changed or removed; VLC's files untouched. After a silent uninstall, HKLM (64 and 32-bit views) is byte-identical to the VLC-only state and the settings are kept ("Delete preferences and cache" starts unticked).
- **GUI upgrade**: the installer shows "An older version of Cone Player is installed" with the upgrade selected; afterwards the same single entry and new shortcuts. GUI uninstall with "Delete preferences and cache" ticked removes `%APPDATA%\Cone`; `HKCU\Software\Cone` stays on this branch alone (its removal and `%LOCALAPPDATA%\Cone` come from PR #33).
- **With PR #33 merged on top** (throwaway merge): the same upgrade results, the beta's file type choices kept (`.mp4` stays VLC's), and the GUI uninstall with "Delete preferences and cache" removes `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone`, HKLM byte-identical to the VLC-only state.
- Installer language strings: no "Player media player"; "Play with Cone Player", "Add to Cone Player's Playlist".

Not testable here: the real app (names in the interface, window titles, Settings texts), the real Windows shell (Apps list icons, Open with, Default apps) and the Windows build itself: section 6.
