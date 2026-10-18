# Cone on Linux (branch wip/linux-build)

Branch `wip/linux-build`, made from `origin/wip/beta` (90f90b5a7a). Status: written; built and started in this sandbox (section 5). **Not verified**: nothing here is marked done in VIDEO_INDEX, and no CI run of the new workflow has happened yet.

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
  usr/lib/           libvlc, libvlccore, vlc/plugins (+ plugins.dat)
  usr/lib/deps/      the image's libraries Cone needs (Qt, FFmpeg, codecs, ...)
  usr/lib/qt6/       Qt plugins (xcb, Wayland, image formats, SVG icons, TLS, input, portal theme) and QML modules (QtQml, QtQuick)
  usr/share/         VLC's data (Lua scripts, translations, icons)
```

- Every program and library finds the bundled libraries through its own RUNPATH (`$ORIGIN/...`, set with a pinned `patchelf` 0.18.0), not `LD_LIBRARY_PATH`, so the bundled libraries never leak into programs Cone starts (file manager, browser). The plugin cache is rebuilt after that (RUNPATH changes the plugin files).
- Not bundled, taken from the system: the C library, graphics drivers and loaders (GL, EGL, Vulkan, VA-API, VDPAU, DRM, GBM), libX11 / libxcb, ALSA, JACK, PipeWire, fontconfig, freetype, harfbuzz, expat, zlib, D-Bus, udev, systemd (the same idea as AppImage's exclude list). Everything else is copied from the image.
- `usr/bin/qt.conf` points Qt at the bundled plugins and QML modules, so a system Qt never mixes in.
- **Requirement:** the image is Debian unstable, so the package needs a recent glibc; the package script prints the exact minimum and writes it into `README-LINUX.txt` (section 5 has the number of the sandbox build).
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
| 7 | Window identity on the desktop | taskbar icon from the exe | `setDesktopFileName("cone")` (Wayland app id, X11 class) and `cone.desktop` / `cone.png` in the package, so docks group Cone under its own name and icon, not VLC's. MPRIS identity "Cone", desktop entry "cone". | `qt.cpp`, `brand.hpp`, `modules/control/dbus/dbus_root.c` |
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
| `modules/gui/qt/util/brand.hpp`, `modules/gui/qt/qt.cpp` | `BRAND_DESKTOP_FILE` ("cone" / `PACKAGE`), `setDesktopFileName`. |
| `modules/gui/qt/medialibrary/qml/RdLibraryItemMenu.qml` | "Show in File Manager" off Windows. |
| `modules/gui/qt/dialogs/redesign/settings/pages/SettingsPerformancePage.qml` | Rescan plugins description without Windows off Windows. |
| `redesign/VIDEO_INDEX.md` | Core changes line, Decisions (Claude) lines. |

## 5. Tested here (sandbox, not verification)

(in progress: filled in after the local build in the sandbox finishes)

## 6. What's left, risks, questions

(in progress: filled in after the local build in the sandbox finishes)

## 7. How to test it (the sandbox, or a Linux PC)

(in progress: filled in after the local build in the sandbox finishes)
