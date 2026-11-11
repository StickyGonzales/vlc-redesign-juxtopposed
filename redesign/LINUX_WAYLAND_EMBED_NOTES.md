# #116: the video plays inside Cone's window on Wayland again

Branch `wip/fix-linux-wayland-embed` (on top of `wip/fix-linux-jammy-image`, the image fix it needs to build). Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-11. Linux only.

## 1. The report and the cause
- **#116 (1.3.0 beta 4, KDE Plasma on Wayland):**
  - The video opens in a separate window, while Cone's own window shows its placeholder.
  - Fullscreen shows the picture with no controls.
  - Beta 3 was fine.
- **Reproduced** (redesign/ISSUE_TRIAGE.md, and again here with `linux-embed-check.sh`):
  - Under a headless Weston session, the released beta 4 logs `using vout window module "wdummy"` and crashes on exit.
  - Under Xvfb it logs `using vout window module "qt"` and the `xcb_render` video output.
- **Cause:**
  - The package has no `plugins/gui/libqt_wayland_plugin.so`, the Qt interface's Wayland compositor. Without it there is no Wayland support in Cone at all.
  - Since the packages moved to the Ubuntu 22.04 image (`be9479502b`), VLC's configure printed `checking for wayland-scanner >= 1.23... no` (build-linux #105) and went on without Wayland, because a missing Wayland is only a warning.
  - The image does build wayland-scanner 1.23.1 from source. But Wayland's meson put its `wayland-scanner.pc` into `/usr/local/lib64/pkgconfig`, which is not on the image's `PKG_CONFIG_PATH`, so pkg-config found Ubuntu's scanner 1.20 instead.
- **The Flatpak is not affected.** It is built against the KDE SDK, whose scanner is new enough, and its configure says `wayland-scanner >= 1.23... yes` and compiles the compositor (build-flatpak #11).

## 2. The fix
| File | Change |
|---|---|
| `.github/linux/jammy.Dockerfile` | Wayland's meson installs with `--libdir=lib/x86_64-linux-gnu`, so `wayland-scanner.pc` lands in a folder `PKG_CONFIG_PATH` lists (checked: pkg-config then reports 1.23.1 at `/usr/local/bin/wayland-scanner`). The image build fails unless pkg-config sees scanner 1.23.1 and protocols 1.41. |
| `.github/scripts/linux-build.sh` | `--enable-wayland`: a missing Wayland requirement now stops configure instead of a warning. |
| `.github/scripts/linux-package.sh` | The package step fails if `plugins/gui/libqt_wayland_plugin.so` is missing. |
| `.github/scripts/linux-embed-check.sh` | New: starts a headless Weston session (Cone as a native Wayland client, no X) or Xvfb, plays a clip and reads Cone's log. Pass: the `qt` video window, a video output, and no `wdummy`. |
| `.github/workflows/smoke-linux.yml` | New job `embed` (Ubuntu 24.04): the check on Wayland and X11 for the tarball, the AppImage (unpacked by its runtime, no FUSE on the runner) and the installed .deb. |

The tarball, the AppImage and the .deb are made from the same build, so they all get the plugin. The Qt Wayland platform plugins were already bundled (`platforms/libqwayland-*.so`, `wayland-shell-integration`, …), and the system's `libwayland-client` stays a dependency (the .deb's Depends).

## 3. Checks
- **Released beta 4** (local, Ubuntu 24.04 container):
  - tarball, Weston: **FAIL**, `wdummy` and exit 139
  - tarball, X11: pass (`qt`, `xcb_render`)
  - AppImage (`APPIMAGE_EXTRACT_AND_RUN=1`), X11: pass
- **CI on this branch:** see the runs below.

## 4. Runs
| Run | Result |
|---|---|
| build-linux #117 (43063926222), 21153af | **green**. Configure finds the scanner and builds the compositor. The package step's check passes. The new `embed` job passes all six cases. **Wayland** (headless Weston): tarball, AppImage and .deb each use `qtwayland module "qt_wayland_plugin_la_qt_wayland"`, `vout window module "qt"` and `vout display module "wl_shm"`. **X11** (Xvfb): `"qt"` and `xcb_render`. The other smoke checks are green too (Ubuntu 24.04 and 22.04 runners, Debian 12). |
| build-linux #116 (43063041270), the image fix alone | for comparison: `checking for wayland-scanner >= 1.23... no`, so without this fix the packages still lack Wayland |
| build-flatpak #20 (43057704114), `wip/linux-flatpak` (PR #114) | **green**, the same check on the installed Flatpak. Wayland: the compositor, `qt` and `wl_shm`. X11: `qt` and `gl`. |

## 5. Retest on a real Linux desktop (StickyGonzales or a tester, after the build is green)
1. A Wayland session (KDE Plasma 6 or GNOME, the default login). In a terminal, `echo $XDG_SESSION_TYPE` prints `wayland`.
2. Download the build's tarball (or AppImage), unpack it and start `./cone` with a video.
3. The picture plays **inside** Cone's window, with the top bar and control bar over it; there is no second window.
4. Press F: fullscreen shows the picture with the bars when the mouse moves to the edges; F again leaves fullscreen.
5. The same with the .deb (`sudo apt install ./cone-player_*.deb`, then Cone from the menu).
6. In an X11 session ("Plasma (X11)" at the login screen), the same steps give the same result.
