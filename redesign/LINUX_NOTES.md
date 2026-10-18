# Cone on Linux (branch wip/linux-build)

Branch `wip/linux-build`, made from `origin/wip/beta` (90f90b5a7a). Status: written; built, packaged and started in this sandbox (section 5). **Not verified**: nothing here is marked done in VIDEO_INDEX, and no CI run of the new workflow has happened yet.

## 1. Can the sandbox test builds? (step 1)

| Check | Result | How |
|---|---|---|
| Download a GitHub Actions artifact of this repo | **Yes** | The GitHub MCP tools list the runs and artifacts and hand out a short-lived download link; `curl` fetches it. Tested on run 39079182201 (`vlc-redesign-win64-public`, 98 MB, 531 files). `gh` itself has no token here, so it is MCP only. |
| Run a Linux Qt app on a virtual display and screenshot it | **Yes** | `Xvfb :91 -screen 0 1280x720x24`, a small Qt Quick window (PySide6 6.8.3, `QT_QPA_PLATFORM=xcb`, Mesa software OpenGL), `import -window root` (ImageMagick). Needed one package: `libxcb-cursor0` (Qt 6.5+ xcb plugin). `xdotool` is there for clicks and keys. |
| Docker, VideoLAN's registry | **Yes** | `dockerd` starts in the sandbox; `registry.videolan.org/vlc-debian-unstable:20260611225331` pulls (5.5 GB); containers reach the network through the sandbox proxy (`--network host`, proxy variables, the proxy's CA file). |
| Run the Windows build | No | No Wine. The Windows zip can be downloaded and inspected, not started. |

So the sandbox can test Cone for Linux end to end: download the artifact, unpack, start it on Xvfb, drive it with `xdotool`, take screenshots. Section 5 does exactly that with a local build.

## 2. The Linux build (step 2)

**Workflow:** `.github/workflows/build-linux.yml`, **manual runs only** (workflow_dispatch), brand **public** (Cone). `build-windows.yml` is unchanged.

**Approach (VideoLAN's own):** the image of VideoLAN's `debian` CI job (`VLC_DEBIAN_IMAGE` in `extras/ci/gitlab-ci.yml`, Debian unstable, Qt 6.10.2), VLC built with autotools against the image's system libraries, as that job does. Two additions:
- The image has no media library package, and without it Cone has no library. `linux-build.sh` builds it with VLC's own contrib recipe (`contrib/src/medialibrary`, 0.13.2, static, sqlite from the image) into `contrib/linux-ml`, cached by the workflow.
- `--with-brand=public`, `--disable-skins2` (Cone has no skins interface; the update checker is off on Linux by default).

**Package:** `linux-package.sh` turns the installed tree into one portable folder and its tarball, `Cone-<version><suffix>-linux-x86_64.tar.xz`, uploaded as the artifact `cone-linux-x86_64` (the tarball itself, because an artifact zip drops execute permissions):

```
Cone-0.1.0-linux-x86_64/
  cone               launcher (portable mode, then usr/bin/vlc)
  cone.desktop       menu entry template
  cone.png           256 px logo
  README-LINUX.txt   start, requirements (oldest glibc), folders, portable mode
  usr/bin/vlc, usr/bin/qt.conf
  usr/libexec/vlc/   vlc-cache-gen, vlc-qt-check (+ its own qt.conf)
  usr/lib/           libvlc, libvlccore, vlc/ (helper libraries, plugins, plugins.dat)
  usr/lib/deps/      the image's libraries Cone needs (Qt, FFmpeg, codecs, fonts, VA-API loader, ...)
  usr/lib/qt6/       Qt plugins (xcb, Wayland, image formats incl. SVG, SVG icons, TLS, input, portal theme) and QML modules (QtQml, QtQuick)
  usr/share/         VLC's data (Lua scripts, translations, icons)
```

- Every program and library finds the bundled libraries through its own RUNPATH (`$ORIGIN/...`, set with a pinned `patchelf` 0.18.0), not `LD_LIBRARY_PATH`, so the bundled libraries never leak into programs Cone starts (file manager, browser). The plugin cache is rebuilt after that (RUNPATH changes the plugin files).
- Libraries are collected from each file's direct dependencies (NEEDED entries), so a library left to the system never drags its own dependency tree in. VLC's own files are stripped (837 MB unpacked before, 384 MB after; tarball about 106 MB, the Windows zip is 98 MB).
- Not bundled, taken from the system: the C library, graphics drivers and their loaders (OpenGL, EGL, Vulkan, DRM, GBM), libX11 / libxcb, ALSA, JACK, PipeWire, expat, zlib, D-Bus, udev, systemd (the same idea as AppImage's exclude list); also the terminal (ncurses), SSH, Samba and GTK libraries: Debian's builds of the first three need glibc 2.42, Samba and GTK would add about a hundred libraries; without them on a system only their plugin (ncurses interface, SFTP, SMB shares, desktop notifications) does not load.
- Bundled although AppImages often leave them out: fontconfig, freetype, harfbuzz (the image's pango, which FFmpeg's SVG support loads, needs its newer fontconfig: with the system's, the FFmpeg plugin did not load at all) and the VA-API / VDPAU loaders (the image's FFmpeg needs a newer libva; the loaders still use the system's GPU drivers).
- Qt's SVG plugins (`imageformats/libqsvg.so`, `iconengines/libqsvgicon.so`): the image lacks them, and without them every interface icon is a placeholder square. The workflow downloads Debian's `qt6-svg-plugins` of the image's exact Qt SVG version (6.10.2-8) from snapshot.debian.org, pinned by SHA-256; the package step stops with an error without them. A new `VLC_IMAGE` needs the matching version there.
- `usr/bin/qt.conf` and `usr/libexec/vlc/qt.conf` point Qt at the bundled plugins and QML modules, so a system Qt never mixes in. The second one matters: VLC runs `vlc-qt-check` before it loads the Qt interface, and without it that check failed and VLC fell back to its text interface.
- **Requirement: glibc 2.39 or newer** (Ubuntu 24.04, Debian 13, Fedora 40, Linux Mint 22, current Arch), printed by the package step and written into `README-LINUX.txt`; older systems (Ubuntu 22.04: glibc 2.35) cannot start it.
- AppImage: not made. The folder is already AppImage-shaped (launcher, desktop file, icon); `appimagetool` could wrap it later.

**Start a Linux build:**
- Web: Actions > build-linux > Run workflow > branch `wip/linux-build` (later `redesign`) > optional package suffix (e.g. `-beta`) > Run workflow.
- PowerShell: `gh workflow run build-linux.yml --ref wip/linux-build`
- The artifact `cone-linux-x86_64` holds `Cone-0.1.0-linux-x86_64.tar.xz`.

## 3. Windows-only parts and their Linux side (step 3)

Windows behavior is unchanged in every row: every new branch is either `#ifdef VLC_BRAND_PUBLIC` on a file Windows does not compile, or a QML `Qt.platform.os === "windows"` test that keeps the Windows text.

| # | Windows part | What it does on Windows | Linux | Change |
|---|---|---|---|---|
| 1 | Settings folder (`src/win32/dirs.c`) | `%APPDATA%\Cone` | **Own folders:** `~/.config/Cone` (vlcrc), `~/.local/share/Cone` (media library, presets, waveforms, subtitles store, profiles), `~/.cache/Cone` (art, thumbnails). Follows `XDG_*_HOME`. Before: `~/.config/vlc` etc., shared with VLC. | `src/posix/dirs.c` (core, public only) |
| 2 | Qt interface settings (`qt.cpp`) | `%APPDATA%\Cone\vlc-qt-interface.ini` | `~/.config/Cone/vlc-qt-interface.conf` (QSettings organization "Cone" already); same folder as vlcrc. | none needed |
| 3 | Single instance (`src/win32/specific.c`, `win_msg.c`) | mutex / IPC window "Cone ipc" | D-Bus name `org.mpris.MediaPlayer2.cone`: "allow only one instance" hands files to a running Cone, never to VLC; Cone and VLC both get their own MPRIS name (media keys, desktop media controls). | `src/posix/specific.c` (core), `modules/control/dbus/dbus.c` (public only) |
| 4 | Audio session name (`mmdevice.c`, `winvlc.c`) | volume mixer entry "Cone" | PulseAudio / PipeWire application name "Cone", id and icon "cone" (sound settings show Cone, not "VLC media player"). | `bin/vlc.c` (public only) |
| 5 | Startup file (`bin/winvlc.c`) | language from the registry, crash dumps, start error box | `bin/vlc.c` is VLC's Linux starter: brand texts as row 4 plus the start banner on a terminal. The `cone` launcher script adds portable mode (row 11). Language: Linux uses the system's `LANG` / `LANGUAGE`, as VLC on Linux; the Settings language row is already hidden off Windows (`SettingsCatalog.languageSupported`). | `bin/vlc.c`, launcher in `linux-package.sh` |
| 6 | Window frame (`mainctx_win32`, `compositor_dcomp/win7`, `csdmenu_win32`) | Cone draws its own title bar (CSD, `qt-titlebar` off by default on Windows) | Not compiled on Linux (meson / Makefile.am `HAVE_WIN32`). VLC's own X11 / Wayland code is used; the redesign's top bar uses VLC's cross-platform CSD buttons. **Default kept as VLC's on Linux: the system title bar** (`qt-titlebar` on), with Cone's top bar under it; CSD is one click (Settings > Interface, "Use system title bar" off, or `--no-qt-titlebar`). Open question in section 6. | none (default kept) |
| 7 | Window identity on the desktop | taskbar icon from the exe | `setDesktopFileName("cone")` (Wayland app id), program name `cone` (X11 window class) and `cone.desktop` / `cone.png` in the package, so docks group Cone under its own name and icon, not VLC's. MPRIS identity "Cone", desktop entry "cone". Qt's own caches (QML, graphics pipelines) were in `~/.cache/vlc` (Qt names them after the program): the application name `Cone` puts them in `~/.cache/Cone`. Public profile, not on Windows. | `qt.cpp`, `brand.hpp`, `modules/control/dbus/dbus_root.c` |
| 8 | Installer (NSIS, MSI, `extras/package/win32`) | install, file associations, Start menu | Skipped: the portable folder is the Linux package. `cone.desktop` + `cone.png` give a menu entry by hand (README-LINUX.txt); file associations come from its `MimeType=` line once installed. No system-wide install. | package only |
| 9 | File associations dialog (`simple_preferences.cpp`, registry) | Windows file types | Already Windows-only upstream (`#ifdef _WIN32`), not shown on Linux. | none |
| 10 | Process priority (Settings > Performance) | priority classes | Already has a Linux branch (nice values; raising needs privileges, a refusal is logged). | none |
| 11 | Portable folder (`portable\` next to Cone.exe) | settings in the zip's folder | The `cone` launcher: a `portable` folder next to it puts settings, library and caches there (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`). | launcher |
| 12 | "Show in File Explorer" (`rdlibrarystore.cpp`: `explorer.exe /select`) | opens Explorer on the file | Already opens the folder with the desktop's file manager (`QDesktopServices`); the menu entry now reads **"Show in File Manager"** off Windows. | `RdLibraryItemMenu.qml` |
| 13 | Rescan plugins (`settings_catalog.cpp`, UAC elevation) | asks for admin rights in Program Files | Already has a Linux branch (runs `vlc-cache-gen` when the folder is writable, reports a failure otherwise); the description no longer mentions Windows / Program Files off Windows. In the portable folder the plugin folder is writable. | `SettingsPerformancePage.qml` |
| 14 | Drive list (Settings, discs) | drive letters | Already lists `/dev/sr*`, `/dev/cdrom`, `/dev/dvd`. | none |
| 15 | Path case (`subtitle_store.cpp`, `rd_presets.cpp`, `rdlibrarymodel.cpp`, `RdLibraryNav.qml`) | case-insensitive paths, drive letters | Already case-sensitive off Windows. | none |
| 16 | Thread exit fix (`util/rd_thread_exit_win32.cpp`) | MinGW TLS destructor order | Windows-only bug (GCC 80816, MinGW), file not compiled on Linux. | none |
| 17 | Skins | removed from Cone (beta brand review) | `--disable-skins2` in the Linux build: no skins module in the package. | `linux-build.sh` |
| 18 | Update checker | off in the public profile | Off on Linux by default (configure). | none |
| 19 | Tray popup (`TrayPopup.qml`, bottom-right of the screen) | own frameless tool window | Works on X11. On Wayland the compositor places windows itself, so the popup may not sit bottom-right; "Use the system's notification" (desktop notifications) is the fallback. Not changed. | none (risk) |
| 20 | "Keep window above other windows" | always on top | Works on X11; most Wayland compositors ignore it. Not changed. | none (risk) |
| 21 | Version / help texts (`src/config/help.c`) | "Cone 0.1.0, based on VLC" | Same code on Linux (already brand-aware); `config.h.meson` was missing `BRAND_VERSION`, so a **meson** public build could not compile it on any OS: added. | `config.h.meson` |

Not changed, VLC upstream behavior on Linux: video output (OpenGL / Vulkan / VA-API through VLC's own modules), Wayland and X11 video embedding (`compositor_x11`, `compositor_wayland`), the system tray, media keys (MPRIS, row 3).

## 4. Files

| File | Change |
|---|---|
| `.github/workflows/build-linux.yml` | New: manual Linux build, public brand, ccache, cached media library, pinned ccache and patchelf, tarball artifact. |
| `.github/scripts/linux-build.sh` | New: media library from contrib, configure / make / install in the image. |
| `.github/scripts/linux-package.sh` | New: portable folder, bundled libraries, RUNPATHs, plugin cache, launcher, desktop file, readme, tarball. |
| `src/posix/dirs.c` | Core, public only: `Cone` instead of `vlc` in the XDG folders. |
| `src/posix/specific.c`, `modules/control/dbus/dbus.c` | Core / module, public only: D-Bus name `org.mpris.MediaPlayer2.cone`. |
| `modules/control/dbus/dbus_root.c` | Module, public only: MPRIS identity "Cone", desktop entry "cone". |
| `bin/vlc.c` | Starter, public only: application name, id, icon, start banner. |
| `config.h.meson` | `#mesondefine BRAND_VERSION` (meson builds only). |
| `modules/gui/qt/util/brand.hpp`, `modules/gui/qt/qt.cpp` | `BRAND_DESKTOP_FILE` ("cone" / `PACKAGE`), `setDesktopFileName`; Linux public: program name `cone`, application name `Cone`. |
| `modules/gui/qt/player/rd_seek_thumbnailer.cpp` | `QImage::mirrored()` is deprecated in Qt 6.9+ (four warnings with the image's Qt 6.10): `flipped()` there, `mirrored()` before, so Windows (Qt 6.8) compiles the same calls. |
| `modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml` | "Show in File Manager" off Windows. |
| `modules/gui/qt/dialogs/redesign/settings/pages/SettingsPerformancePage.qml` | Rescan plugins description without Windows off Windows. |
| `redesign/VIDEO_INDEX.md` | Core changes line, Decisions (Claude) lines. |
| `redesign/linux-shots/` | Five screenshots of the sandbox run (section 5), generated test media only. |

## 5. Tested here (sandbox, not verification)

Built here with the same scripts as the workflow (Docker, VideoLAN's image, `linux-build.sh build` then `package`), then started on Ubuntu 24.04 (the sandbox, glibc 2.39) under Xvfb 1920x1200, Mesa software OpenGL, as an ordinary user (VLC refuses root), in a D-Bus session, with a generated 720p test video and an .srt. Screenshots in `redesign/linux-shots/` (generated test media only). **Not verification**: a virtual display without GPU, window manager, sound or keyboard focus.

| Check | Result |
|---|---|
| Build | configure finds Qt 6.10.2 and every QML module, medialibrary (contrib), D-Bus, `VLC_BRAND_PUBLIC`, `BRAND_VERSION 0.1.0`; compiles and installs, about 15 minutes on 4 cores without ccache |
| Warnings | none left in the fork's own files; four were `QImage::mirrored()` (Qt 6.9+ deprecation), fixed. The rest are upstream VLC's (deprecated FFmpeg / fluidsynth / V4L2 calls, unused parameters, libtool notes), the same as without the fork |
| Package | 384 MB folder, 106 MB tarball, 266 bundled libraries, needs glibc 2.39 |
| Start | the interface comes up (after the qt.conf fix for `vlc-qt-check`), Cone logo and every SVG icon drawn (after the SVG plugin fix) |
| Playback | the video plays with FFmpeg (after the font and libva fixes), the `.srt` next to it loads by itself and shows (`02-player-subtitle.png`) |
| Bars | the mouse over the window shows both bars over the video, they fade after a few seconds (`01-player-bars.png`); with the bars shown, the subtitle at the bottom is hidden behind the control bar: the beta blocker that `wip/beta-subs` fixes, same on Linux |
| Menus | the redesign's right-click menu (`03-right-click-menu.png`) and the "..." menu (`04-main-menu.png`) open where they should |
| Library | after the video ends: Home with "Continue Watching" and the file's thumbnail (`05-library-home.png`), so the contrib media library works |
| Folders | a fresh profile gets only `~/.config/Cone` (`vlc-qt-interface.conf`), `~/.local/share/Cone` (`ml/`, `rd-presets.json`), `~/.cache/Cone` (Qt's QML and pipeline caches); no `vlc` folder anywhere. The other caches are system-wide (fontconfig, Mesa, Qt's shared shader cache) |
| D-Bus | `listening on dbus as: org.mpris.MediaPlayer2.cone` |
| One instance | a second `cone --one-instance <file>` prints "running VLC instance - exiting" and the first Cone plays the file |
| Quit | SIGINT quits cleanly within a few seconds |
| Not tested here | keyboard (xdotool's keys did not reach the window without a window manager, so Ctrl+P / Ctrl+Q / Escape are untested), sound, GPU video output and VA-API (no GPU: VLC's OpenGL output refuses a software renderer and falls back), Wayland, fullscreen, the Settings dialog, portable mode, the desktop file, a real CI run |

Found and fixed on the way (all in the package script, plus the Qt cache folder):
1. VLC's helper libraries in `usr/lib/vlc` were not on the RUNPATH: no PulseAudio, PipeWire, XCB video or VDPAU plugins.
2. Debian's ncurses, libssh and Samba builds need glibc 2.42: left to the system, the package needs 2.39.
3. `ldd` lists whole dependency trees, so excluded libraries' dependencies were still copied (367 libraries): direct dependencies only now (266).
4. `vlc-qt-check` (run before the interface loads) had no qt.conf: the Qt interface never started and VLC fell back to its text interface.
5. The system's older fontconfig broke the image's pango, so the FFmpeg plugin did not load (no video): fonts bundled.
6. The image's FFmpeg needs `vaMapBuffer2` (newer libva): VA-API / VDPAU loaders bundled.
7. No Qt SVG plugins in the image: every icon was a placeholder square. Debian's matching package added by the workflow.
8. Qt's caches went to `~/.cache/vlc`: now `~/.cache/Cone` (`qt.cpp`, public profile, not on Windows).
9. Seen only because of the test folder's name: the media library could not create its folder when the same folder name appears twice in the path (`/home/x/t/home/...`). An upstream medialibrary quirk; real home folders (`/home/<user>`) are not affected.


## 6. What's left, risks, questions

**Left to do**
- A first real CI run of `build-linux.yml` (it has never run on GitHub): check the time, the ccache and media library caches, and that the artifact is the tarball.
- Test on a real Linux PC (section 7), especially keyboard, sound, GPU video output, Wayland and fullscreen, which the sandbox cannot cover.
- `README.md` and release notes do not mention Linux yet; `release.yml` (wip/ci-release) does not build Linux.
- Small window: on the default 600x420 window, the right-click menu is cut off at the window's bottom edge (the redesign draws menus inside the window). Probably the same on Windows; not Linux-specific.

**Risks**
- **glibc 2.39 or newer only.** The image is Debian unstable, so a newer image raises the minimum again. An older base would need its own image with Qt 6.8+ (Ubuntu 24.04's Qt is 6.4).
- **The Qt SVG package is pinned** to the image's Qt SVG version; a new `VLC_IMAGE` needs the matching `qt6-svg-plugins` hash in the workflow, or the package step stops with an error.
- **Libraries left to the system** (GPU drivers, X11, ALSA, PipeWire, ncurses, libssh, Samba, GTK): a system without one loses only that plugin. PipeWire as the sound output needs the system's libpipewire; PulseAudio and ALSA work otherwise.
- **Bundled fonts libraries** use the system's fontconfig configuration; very old configurations may print warnings.
- **Core changes** (`src/posix/dirs.c`, `src/posix/specific.c`, `modules/control/dbus/*`, `bin/vlc.c`): public profile only, no effect on the Windows build (not compiled there), but per Decision 27 / 55 they are their own build.
- An old `~/.config/vlc` is never read by Cone: Linux users start fresh.

**Questions for StickyGonzales**
1. Window frame on Linux: keep VLC's system title bar (now), or Cone's own window buttons like on Windows (`qt-titlebar` off by default in the public profile on Linux)?
2. Linux package format for the public release: this tarball, an AppImage made from it, or a Flatpak?
3. Should the release workflow publish the Linux tarball next to the Windows zip?


## 7. How to test it (the sandbox, or a Linux PC)

**In the sandbox (any session can do this):**
1. Run the workflow (section 2), then in the session: list the run's artifacts with the GitHub MCP tools (`actions_list` with `list_workflow_run_artifacts`), get the link (`actions_get` with `download_workflow_run_artifact`), download it with `curl`, unzip it (the artifact zip holds the `.tar.xz`).
2. Start `dockerd` only if a local build is needed; for testing the artifact it is not.
3. As a non-root user (`useradd -m conetest`), in a home whose path does not repeat a folder name: `Xvfb :93 -screen 0 1920x1200x24 &`, then `DISPLAY=:93 dbus-run-session -- ./cone --no-qt-privacy-ask --no-qt-video-autoresize --aout=dummy -vv <video>` (needs `libxcb-cursor0` on the sandbox: `apt-get install libxcb-cursor0`).
4. Screenshots with `import -window root shot.png`; mouse with `xdotool mousemove` / `click` (keyboard did not work without a window manager; a small window manager such as `openbox` might fix that).
5. Check the log for `cannot load plug-in`, `error`, `qml` warnings; check `~/.config/Cone`, `~/.local/share/Cone`, `~/.cache/Cone` and that no `vlc` folder appears.
6. Close everything: SIGINT to `usr/bin/vlc`, stop Xvfb and dbus.

**On a Linux PC (Ubuntu 24.04 or newer, Fedora 40+, Debian 13, Arch):**
1. Download `cone-linux-x86_64` from the run, unzip, `tar -xJf Cone-0.1.0-linux-x86_64.tar.xz`, `cd Cone-0.1.0-linux-x86_64`, `./cone`.
2. With VLC installed too: both open side by side; Cone's settings land in `~/.config/Cone`, VLC's `~/.config/vlc` is untouched; the dock shows Cone with its own icon (after copying `cone.desktop` and `cone.png` as `README-LINUX.txt` says); the sound settings list "Cone".
3. Playback with sound, subtitles, seek, volume, fullscreen in and out (F, double click), the bars in windowed and fullscreen, keyboard shortcuts, the Settings dialog, Customize Player, the library (add a folder), drag and drop a file, "Show in File Manager".
4. Media keys and the desktop's media controls (MPRIS) show "Cone"; Settings "Allow only one instance" opening a second file hands it to the running Cone.
5. Portable mode: `mkdir portable` next to `cone`, start: everything goes into `portable/`.
6. Both X11 and Wayland sessions if possible; a GPU for VA-API decoding (`-vv` log: `vaapi`).

