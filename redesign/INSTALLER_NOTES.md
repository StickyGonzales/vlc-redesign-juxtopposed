# Cone installer (branch wip/installer)

Status: built and tested under **Wine only** (stub payload, see section 5). **Nothing verified on Windows yet**: section 6 has the steps for a throwaway Windows (Windows Sandbox or a VM).

Everything here applies to the **public** brand profile (`--with-brand=public`, Cone). The **vlc** profile's installer is unchanged: every change sits inside `!if "${PRODUCT_PROGID}" != "VLC"`, and the old code is kept in the `!else` branch.

Base: VLC's own NSIS installer, `extras/package/win32/NSIS/vlc.win32.nsi.in`, with the brand layer from `wip/cone-release` (own ProgIDs, verbs, autoplay handlers, Cone images and texts, `redesign/CONE_RELEASE_NOTES.md`).

## 1. What Cone's installer does

| Requirement | How |
|---|---|
| Installs to `Program Files\Cone` | `PRODUCT_INSTALL_DIR` = `Cone` (64-bit `Program Files`) |
| Own registry keys, never VLC's | Every key is named `Cone`, `Cone.<ext>`, `PlayWithCone`, `ConePlay*`. The installer and uninstaller never read, write or remove a VideoLAN / VLC key or value (section 2) |
| Start menu shortcut | `Start Menu\Programs\StickyGonzales\Cone.lnk` (on by default) |
| Optional desktop shortcut | Component "Desktop Shortcut" (`%PUBLIC%\Desktop\Cone.lnk`) |
| Settings > Apps entry | `Uninstall\Cone`: name Cone, Cone icon (`Cone.exe`), version 0.1.0, publisher StickyGonzales, size (new: `EstimatedSize`) |
| Working uninstaller | `Program Files\Cone\uninstall.exe`, also from Settings > Apps |
| Open with and Default apps | ProgIDs `Cone.<ext>`, `Capabilities\FileAssociations`, `RegisteredApplications`, `Applications\Cone.exe\SupportedTypes`, and `OpenWithProgids` for every ticked type (new, section 2) |
| Never forces itself as default | New: Cone never writes the default value of `HKCR\.<ext>`; the user picks Cone in Windows |
| Settings in `AppData\Cone` | Done by the app (wip/cone-release): `%APPDATA%\Cone` (vlcrc, media library, Qt settings), `%LOCALAPPDATA%\Cone` (Qt cache), `HKCU\Software\Cone` (interface language). The portable zip keeps its `portable` folder as before |
| Uninstall asks before deleting settings | Uninstall component "Delete preferences and cache", **unticked** by default |
| Cone branding on every screen | Cone images (`brand/public/nsis-*.bmp`), titles and texts (`brand-languages.sh`); the only VLC mentions are the footer "based on VLC 4.0.0-dev", the GPL license page and the Default apps description "a media player based on VLC media player" |
| Built in CI next to the zip | `build-windows.yml` step "Cone installer", artifact **cone-installer-win64** |

## 2. Changes on this branch

| # | Change | Why | File |
|---|---|---|---|
| 1 | Ticked file types add `HKCR\.<ext>\OpenWithProgids\Cone.<ext>` instead of setting `HKCR\.<ext>` (default) to `Cone.<ext>` with a `Cone.backup` value | This is how Windows wants an app to offer a type: Cone shows in Open with and Default apps, the user's current default stays. Since Windows 8 an installer can not set the default anyway; writing the default only confused Explorer next to VLC | `NSIS/helpers/extensions.nsh` (AssociateExtension) |
| 2 | Uninstall removes that value, then `OpenWithProgids` and `.<ext>` only when they are empty (no value, no subkey, empty default) | Leaves other apps' entries alone (`DeleteRegKey /ifempty` ignores values, so a small helper `un.DeleteClassesKeyIfEmpty` does it). The old restore code for a `Cone.backup` value stays, for an install that an older Cone build made | `extensions.nsh` (un.RegisterExtension) |
| 3 | `Applications\Cone.exe\SupportedTypes` lists every extension | VLC's script writes `$0` (one stray value) instead of the extension, so Open with did not know Cone's types | `extensions.nsh` (RegisterExtension) |
| 4 | The "VLC is installed" check (Decision 56) is removed | It read VLC's install key, uninstall key and App Paths entry, and the new rule is "never reads VLC's keys". With item 1 it is not needed: ticked types no longer take anything away from VLC, so they start ticked like in VLC's installer | `vlc.win32.nsi.in` |
| 5 | No `Clients\Media\Cone\InstallInfo` | Those commands point at `spad-setup.exe`, which the installer does not install (same in VLC's) | `vlc.win32.nsi.in` |
| 6 | `EstimatedSize` in `Uninstall\Cone` | Settings > Apps shows a size | `vlc.win32.nsi.in` (Section -Post) |
| 7 | Component description for "File type associations": "Lists Cone in Open with and Default apps for these file types; your default app stays." (English in every language) | VLC's text says it makes VLC the default player | `vlc.win32.nsi.in` |
| 8 | "Delete preferences and cache" also removes `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone` | VLC's only removes `%APPDATA%\vlc`; Cone also keeps Qt's cache and its interface language | `NSIS/helpers/utils.nsh` (delprefs) |
| 9a | `Applications\Cone.exe\SupportedTypes` is deleted and written anew on every install | An upgrade from an installer before item 3 kept that installer's one stray value (found with the real Cone 0.2.0 beta installer, wip/test-installer-1.0) | `vlc.win32.nsi.in` |
| 9 | The CI installer step can fail the run (no more `continue-on-error`) | The installer is a real package now. The zip is uploaded before it, so a failing installer still leaves the zip | `.github/workflows/build-windows.yml` |

Not changed: the **MSI** (`extras/package/win32/msi/`). CI does not build it, and it still holds Decision 56's read of `Software\VideoLAN\VLC` and sets the default of each type. If it ever ships, it needs the same rework as items 1, 2 and 4.

## 3. Registry keys it writes

All under `HKLM` (all-users install), 64-bit view. `<ext>` = each file type (134 in total: 130 ticked by default, `.iso .mid .rar .zip` unticked, like VLC). Values captured from the Wine run.

**App and uninstall**

| Key | Values |
|---|---|
| `Software\Cone` | (Default) `C:\Program Files\Cone\Cone.exe`, `InstallDir` `C:\Program Files\Cone`, `Version` `0.1.0`; `Language` (the language picked on the installer's first page, not written by a silent install) |
| `Software\Microsoft\Windows\CurrentVersion\Uninstall\Cone` | `DisplayName` Cone, `DisplayIcon` `...\Cone.exe`, `DisplayVersion` 0.1.0, `VersionMajor` 0, `VersionMinor` 1, `Publisher` StickyGonzales, `URLInfoAbout` (project page), `InstallLocation`, `UninstallString` `...\uninstall.exe`, `EstimatedSize` (KB), `MementoSectionUsed` and one `MementoSection_*` per component (the saved choices for a reinstall) |
| `Software\Microsoft\Windows\CurrentVersion\App Paths\Cone.exe` | (Default) `...\Cone.exe`, `Path` `C:\Program Files\Cone` |

**Default apps and Open with**

| Key | Values |
|---|---|
| `Software\RegisteredApplications` | value `Cone` = `Software\Clients\Media\Cone\Capabilities` |
| `Software\Clients\Media\Cone` | (Default) Cone |
| `...\Cone\Capabilities` | `ApplicationName` Cone, `ApplicationDescription` "Cone, a media player based on VLC media player" |
| `...\Cone\Capabilities\FileAssociations` | one value per type: `.<ext>` = `Cone.<ext>` |
| `Software\Classes\Applications\Cone.exe` | `FriendlyAppName` Cone; `shell\Open\command` = `"C:\Program Files\Cone\Cone.exe" --started-from-file "%1"`; `SupportedTypes` one empty value per `.<ext>` |
| `Software\Classes\Cone.<ext>` | (Default) e.g. "MP4 Video File (Cone)"; `DefaultIcon` `"...\Cone.exe",0`; `shell\Open` (Default) Play, `MultiSelectModel` Player, `command` as above |
| `Software\Classes\.<ext>\OpenWithProgids` | value `Cone.<ext>` (empty), ticked types only |

**Context menus** (component "Context Menus")

| Key | Command |
|---|---|
| `Classes\Cone.<ext>\shell\PlayWithCone` | "Play with Cone": `--started-from-file --no-playlist-enqueue "%1"` |
| `Classes\Cone.<ext>\shell\AddToPlaylistCone` | "Add to Cone's Playlist": `--started-from-file --playlist-enqueue "%1"` |
| `Classes\Directory\shell\PlayWithCone`, `...\AddToPlaylistCone` | the same for folders |

**Discs** (component "Discs Playback")

| Key | What |
|---|---|
| `Classes\AudioCD\shell\PlayWithCone`, `Classes\DVD\shell\PlayWithCone` | disc context menu |
| `Classes\Cone.DVDMovie`, `.CDAudio`, `.VCDMovie`, `.SVCDMovie`, `.OPENFolder`, `.Bluray` | AutoPlay ProgIDs |
| `...\Explorer\AutoplayHandlers\Handlers\ConePlay{DVDMovie,CDAudio,VCDMovie,SVCDMovie,DVDAudio,VideoFiles,MusicFiles,Bluray}OnArrival` | AutoPlay handlers |
| `...\Explorer\AutoplayHandlers\EventHandlers\Play*OnArrival` | one value `ConePlay*OnArrival` each, next to VLC's `VLCPlay*OnArrival` |

Wine also shows copies of `Clients\Media\Cone`, `App Paths\Cone.exe` and the AutoPlay values under `Wow6432Node`: Windows shares those keys between the 64-bit and 32-bit views. They go with the uninstall like the rest.

**Per user, written by Cone itself (not the installer)**: `HKCU\Software\Cone` (`Lang`). Removed only when "Delete preferences and cache" is ticked.

## 4. Files it writes

| Where | What |
|---|---|
| `C:\Program Files\Cone\` | `Cone.exe`, `vlc-cache-gen.exe`, `vlc-preparser.exe`, `libvlc.dll`, `libvlccore.dll` and the other DLLs, `plugins\` (+ `plugins.dat` made by the cache generator at install), `locale\` (only when the build has translations: the CI build has none, so the real installer writes no `locale\`), `hrtfs\`, `lua\`, `COPYING.txt`, `NEWS.txt`, `README.txt` and the other text files, `Cone Website.url`, `Documentation.url`, `uninstall.exe`, `uninstall.log` (hidden; the list the uninstaller removes) |
| `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StickyGonzales\` | `Cone.lnk`, `Cone - reset preferences and cache files.lnk`, `Cone Website.lnk`, `Documentation.lnk`, `Release Notes.lnk` |
| `%PUBLIC%\Desktop\Cone.lnk` | only with "Desktop Shortcut" |

**Written by Cone itself when it runs**: `%APPDATA%\Cone\` (vlcrc, `vlc-qt-interface.ini`, media library, art cache, crash dumps), `%LOCALAPPDATA%\Cone\` (Qt cache). Both stay on uninstall unless "Delete preferences and cache" is ticked.

## 5. Wine test (done here)

Method: VideoLAN's win64 build image (makensis 3.11) plus 64-bit Wine; both installers compiled from this branch with a stub payload (a `Cone.exe` / `vlc.exe` that logs its command line, stub DLLs and folders). The **vlc**-profile installer stands in for a real installed VLC. Registry snapshots with `reg query /s` in both views (`/reg:64`, `/reg:32`) and a file list after each step: clean, VLC installed, Cone installed, Cone's settings planted, Cone uninstalled.

Results:
- makensis: both profiles compile, 68 warnings each (missing translations, the same count as before this branch).
- Installing Cone next to VLC changed or removed **no existing registry line**; it only added Cone's keys. `HKCR\.mp4` still says `VLC.mp4`; Cone appears only in `.mp4\OpenWithProgids`.
- The Open command of `Cone.mp4` and of `Applications\Cone.exe` both started `Cone.exe` with the right file path: `"C:\Program Files\Cone\Cone.exe" --started-from-file "C:\users\Public\test video.mp4"`.
- After Cone's silent uninstall: `HKLM\Software` (64-bit and 32-bit views) is **byte-identical** to the VLC-only state; `Program Files\Cone`, the Start menu folder and the desktop link are gone; `Program Files\VideoLAN` untouched. Left over: only the planted user settings (`%APPDATA%\Cone`, `HKCU\Software\Cone`, kept because "Delete preferences and cache" starts unticked) and NSIS's own temp file `~nsu*.tmp`.
- Uninstall with "Delete preferences and cache" ticked: `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone` removed; VLC's `%APPDATA%\vlc` and `HKCU\Software\VideoLAN\VLC` untouched.
- Screens (install: language, welcome, license, components, folder, progress, finish; uninstall: components, finish): Cone logo and name on every page, no VLC cone. The new component description fits its box.

Not testable under Wine: the real Windows shell (Open with list, Default apps page, icons in Settings > Apps, AutoPlay), and the real Cone and VLC programs.

## 6. Windows test steps (throwaway Windows)

Use **Windows Sandbox** (Windows 10/11 Pro: Control Panel > Programs > Turn Windows features on or off > Windows Sandbox) or a VM. Everything inside is thrown away when it closes.

**Get the files**
1. GitHub, Actions, "build-windows", the green run of `wip/installer`: download **cone-installer-win64** and unzip it (`cone-0.1.0-win64.exe`).
2. Download the normal VLC installer from videolan.org.
3. Copy both, plus one short `.mp4` and one `.mp3` (generated or public test media), into the Sandbox (copy and paste works).

**VLC first**
4. Install VLC with its defaults. Double click the `.mp4`: it opens in VLC. Close VLC.

**Install Cone**
5. Run `cone-0.1.0-win64.exe`. On every page: Cone logo and name, no VLC cone; the footer says "based on VLC 4.0.0-dev". Components: Start Menu Shortcut, File type associations, Context Menus and Discs Playback ticked; tick **Desktop Shortcut**. Hover "File type associations": the description says Cone is listed in Open with, your default stays. Install, then Finish with "Run Cone" ticked: Cone starts. Close it.
6. Check: `C:\Program Files\Cone` exists, `C:\Program Files\VideoLAN\VLC` untouched; the desktop has a Cone icon.

**Start menu**
7. Start menu: "StickyGonzales" folder with Cone (Cone logo); "Cone" also comes up when you type it. VLC's "VideoLAN" folder is still there.

**Settings > Apps**
8. Settings > Apps > Installed apps (Windows 10: Apps & features): "Cone", Cone logo, version 0.1.0, publisher StickyGonzales, a size. "VLC media player" is still listed.

**Open with**
9. Double click the `.mp4`: it still opens in **VLC** (Cone did not take it over).
10. Right click the `.mp4` > Open with: **Cone** is in the list, with its logo. Pick it once (without "Always"): the file plays in Cone. Same for the `.mp3`.

**Default apps**
11. Settings > Apps > Default apps: **Cone** is listed (with VLC). Open it: it lists Cone's file types. Set `.mp4` to Cone (Windows 11: the `.mp4` row > Cone > Set default; Windows 10: "Choose default apps by file type" or the Open with dialog with "Always use this app").
12. Double click the `.mp4`: it now opens in **Cone**. Right click it: "Play with Cone" and "Add to Cone's Playlist" are there.
13. Right click a folder: "Play with Cone" and "Add to Cone's Playlist" next to VLC's entries.

**Settings folder**
14. In Cone change one visible setting (e.g. a hotkey), close it. `%APPDATA%\Cone` exists (Win+R, `%APPDATA%\Cone`), with `vlcrc`. `%APPDATA%\vlc` (VLC's) has no Cone setting. Start VLC: its own settings, not Cone's.

**Uninstall**
15. Export the registry before: Win+R, `cmd`, then `reg export HKLM\SOFTWARE before.reg /reg:64`.
16. Settings > Apps > Cone > Uninstall. The uninstaller shows Cone's pages; "Delete preferences and cache" is **unticked**: leave it, finish.
17. Check nothing is left: `C:\Program Files\Cone` gone; the StickyGonzales Start menu folder and the desktop icon gone; Cone gone from Settings > Apps and Default apps; Open with on the `.mp4` no longer lists Cone. In `regedit` (search "Cone", Find next until the end): no `HKLM\SOFTWARE\Cone`, `Uninstall\Cone`, `Clients\Media\Cone`, `RegisteredApplications` value `Cone`, `Classes\Cone.*`, `Classes\Applications\Cone.exe`, `PlayWithCone`, `ConePlay*`. Only `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone` remain (the settings you chose to keep).
18. Optional: install Cone again, uninstall with "Delete preferences and cache" **ticked**: `%APPDATA%\Cone`, `%LOCALAPPDATA%\Cone` and `HKCU\Software\Cone` are gone too; `%APPDATA%\vlc` and `HKCU\Software\VideoLAN\VLC` are still there.

**VLC still works**
19. Double click the `.mp4`: Windows opens VLC (or asks which app, if Cone was the default: pick VLC). VLC plays it with its own settings; its Start menu entry, Default apps entry and context menus are all still there.

Report any step that differs, with a screenshot of the Sandbox window.
