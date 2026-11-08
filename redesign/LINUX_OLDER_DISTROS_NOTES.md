# Cone for Linux on older systems: built on Ubuntu 22.04 (glibc 2.35)

Branch `wip/linux-glibc-235`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-08: "build the Linux packages on an Ubuntu 22.04 base (glibc 2.35) so they also run on Ubuntu 22.04, Linux Mint 21 and Debian 12, still working on newer ones; update the README and release notes requirements."

## 1. Before and after
| | Before (up to linux-v1.2.0-beta3) | Now |
|---|---|---|
| Build image | VideoLAN's `vlc-debian-unstable` (Debian unstable) | `.github/linux/jammy.Dockerfile`: Ubuntu 22.04, built by the workflow (about 5 min) |
| Qt | Debian's Qt 6.10 | the official Qt 6.8.3 for Linux (aqtinstall), the same Qt version as the Windows build; needs glibc 2.28 itself |
| Oldest C library | glibc 2.39 (Ubuntu 24.04, Mint 22, Debian 13, Fedora 40) | **glibc 2.35: Ubuntu 22.04, Linux Mint 21, Debian 12, Fedora 36 and newer** |
| FFmpeg | Debian's 8.x | Ubuntu 22.04's 4.4 (VLC 4's minimum: libavcodec 58.134, libavformat 58.76) |
| libplacebo | Debian's | Ubuntu 22.04's 4.192 (VLC 4's minimum) |
| libpostproc | built from VLC's contrib (FFmpeg 8 dropped it) | FFmpeg 4.4's own |
| Qt's SVG plugins | Debian's `qt6-svg-plugins` downloaded by the workflow | part of the official Qt |

## 2. What changed
- **`.github/linux/jammy.Dockerfile`** (new): Ubuntu 22.04 with VLC's build tools and libraries; `wayland-scanner` 1.23 and `wayland-protocols` 1.41 from source (VLC's Wayland code needs scanner 1.23 and protocols 1.33; Ubuntu 22.04 has 1.20 and 1.25). Only the scanner and the protocol files: VLC still links Ubuntu 22.04's `libwayland-client` 1.20, so it uses nothing older systems lack. The official Qt 6.8.3 into `/opt/qt` (essentials plus qtshadertools and qtimageformats).
- **`build-linux.yml`**: builds that image instead of pulling VideoLAN's; the media library and postproc caches are keyed on the Dockerfile; the Debian Qt SVG download is gone.
- **`linux-build.sh`**: takes the system's libpostproc when there is one.
- **`linux-package.sh`**:
  - takes Qt's libraries, plugins and QML modules from the official Qt (`QT_DIR`);
  - **leaves the C++ runtime (`libstdc++`, `libgcc_s`) and Wayland's client libraries to the system.** Copies from Ubuntu 22.04 would be older than what a newer system's graphics drivers (loaded into the same process) need: an old bundled `libstdc++` makes Mesa fail with "GLIBCXX_3.4.3x not found" on new systems. Every desktop system has them; the .deb now depends on them;
  - writes the systems next to the glibc version in `README-LINUX.txt` ("glibc 2.35 or newer (Ubuntu 22.04, Linux Mint 21, Debian 12, Fedora 36 or newer)").
- **`linux-deb.sh`**: Depends adds `libstdc++6`, `libgcc-s1`, `libwayland-client0`, `libwayland-cursor0`, `libwayland-egl1`.
- **`release-linux.yml`**: the release notes name the same systems, and the checks list both Ubuntu versions.
- **`smoke-linux.yml`**:
  - the smoke checks run on **Ubuntu 24.04 and Ubuntu 22.04** runners (22.04 is also Linux Mint 21's base);
  - a new **Debian 12** job: the tarball in a `debian:12` container under Xvfb plays a clip with its .srt in the Qt interface; its log must show the Qt video window, a video output, the FFmpeg decoder and the subtitle decoder.
- **`README.md`**: the Linux requirements (1.2.0 beta 3 still needs 2.39; from the next Linux release, 2.35).
- **A real portability fix:** `modules/gui/qt/player/rd_sync_math.hpp` used `size_t` without `<cstddef>`; GCC 11 (Ubuntu 22.04) does not include it indirectly as newer GCC does, so the subtitle auto-sync did not compile there.

## 3. What older systems lose (accepted)
- **PipeWire as a direct sound output:** VLC needs libpipewire 0.3.64, Ubuntu 22.04 has 0.3.48, so the PipeWire output plugin is not built. Sound goes through PulseAudio, which PipeWire systems answer (pipewire-pulse) and which Ubuntu 22.04, Mint 21 and Debian 12 use themselves.
- **Newer FFmpeg features:** FFmpeg 4.4 decodes H.264, HEVC, VP9, AV1 (through dav1d), AAC, Opus and the rest Cone plays; formats newer than 2021 (e.g. VVC) are not decoded.
- **libsmb2** (SMB 2/3 shares): Ubuntu 22.04 has no package of it; Samba's libsmbclient (taken from the system) still opens SMB shares.

## 4. Local test (sandbox, before CI)
- The image built here; `qmake6 -query QT_VERSION` 6.8.3, `ldd --version` 2.35.
- VLC configured and compiled in it: configure found Qt 6.8.3, libavcodec 58.134.100, libplacebo 4.192.1, libpostproc 55.9.100, VA-API; the only compile error was the `size_t` one above.
- The package step: "needs glibc 2.35 or newer", 233 bundled libraries, no `libstdc++` / `libgcc_s` / `libwayland-*` among them.
- **Debian 12 (glibc 2.36) in a container, the CI job's own commands:** Cone started, played the clip with its .srt (avcodec, subsdec, the xcb_render video output) and ended with exit code 0. The Qt interface started (Mesa llvmpipe OpenGL context), but the video opened in a separate X11 window: that first build came from an image without `libxcb-damage0-dev`, so VLC's X11 compositor was not built (configure: "Qt X11 composition disabled"). The image now has it; the Debian 12 job's "using vout window module "qt"" line is the check that caught it.

## 5. Runs
| Run | Result |
|---|---|
| build-linux #101 (42480429567), be94795 | **green**: the image built (glibc 2.35, Qt 6.8.3), Cone built and packaged ("needs glibc 2.35 or newer"); every Linux smoke check passes on the **Ubuntu 24.04** and the **Ubuntu 22.04** runner (tarball, AppImage-free checks, the .deb next to Ubuntu's VLC); **Debian 12** (glibc 2.36): exit code 0, "using vout window module "qt"" (the video in Cone's window: the X11 compositor is back with `libxcb-damage0-dev`), a video output, avcodec, subsdec |

## 6. Retest
- **Windows:** nothing changes for Windows (one header include in shared code).
- **Linux (a live USB, redesign/LINUX_UX_NOTES.md section 8):** the same checklist on **Ubuntu 22.04** or **Linux Mint 21** (needs this branch's build: the tarball or the .deb of its build-linux run, or the `wip-linux-glibc-235--*` files on the test-builds draft pre-release), and once on a newer system (Ubuntu 24.04) to confirm nothing regressed there: video in the main window (not a separate window), sound, hardware decoding.
