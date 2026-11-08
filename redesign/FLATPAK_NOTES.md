# Cone Player as a Flatpak (first step toward Flathub)

Branch `wip/linux-flatpak`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-08: "Prepare a Flatpak build (a manifest that builds and runs in the sandbox) as a first step toward Flathub; submit nothing." **Nothing is submitted or published.**

## 1. What is here
| File | What |
|---|---|
| `extras/package/flatpak/io.github.StickyGonzales.ConePlayer.yml` | the manifest |
| `extras/package/flatpak/install-desktop.sh` | menu entry (the same file types as the other Linux packages), icons, AppStream file, launcher |
| `extras/package/flatpak/io.github.StickyGonzales.ConePlayer.metainfo.xml` | the AppStream file Flathub reads (name, summary, description, license, links) |
| `extras/package/flatpak/cone` | the launcher (`/app/bin/cone`) |
| `.github/workflows/build-flatpak.yml` | builds it in Flathub's KDE 6.10 build image, installs the bundle and starts Cone in the sandbox |

**App ID:** `io.github.StickyGonzales.ConePlayer` (Flathub's form for a GitHub project; the app ID cannot change after a Flathub release).

**Runtime:** `org.kde.Platform` 6.10 (Qt 6.10, the Qt the other Linux builds use from Debian; freedesktop 25.08 underneath). KDE 6.11 also exists; 6.10 was kept because Cone is tested with Qt 6.10.

**Built in the manifest** (the runtime lacks them or has a reduced build): Lua 5.4.4 (VLC's scripts; the same version as VLC's contrib, checksum from contrib), FFmpeg 7.1.2 (the runtime's FFmpeg leaves out most video decoders), libebml / libmatroska (MKV, WebM), libdvbpsi (MPEG-TS), libass (styled subtitles), the media library 0.13.2 (VLC's contrib version and tarball), then Cone itself from the checkout (`type: dir`).

**Sandbox permissions (finish-args):** minimal, each with its reason, in the manifest and in redesign/SUBMIT_TO_FLATHUB.md section 4 (Wayland / X11 fallback, GPU, sound, network, the Videos / Downloads / Pictures folders, Music and removable drives read only, the MPRIS name, the screen saver inhibit). The launcher turns Cone's own update check off: Flathub updates the app.

**AppStream:** summary, description with Juxtopposed's credit and the VLC trademark note, four screenshots from generated media (`extras/package/flatpak/screenshots`, linked by commit), release notes of 1.2.0 beta 3, OARS rating, license, links, branding colors. `appstreamcli validate` passes.

**Desktop ID:** a Flatpak's windows, media controls and sound mixer entry must carry its app ID, not `cone-player`. A new build-time define, `CONE_DESKTOP_ID`, replaces it where Cone names it (`modules/gui/qt/util/brand.hpp`, `modules/control/dbus/dbus_root.c`, `bin/vlc.c`); the manifest sets it, every other build keeps `cone-player`. Two of the files are outside `modules/gui/qt`: a small core change (Decision 27), inert unless the define is set.

## 2. What the workflow checks
1. flatpak-builder builds every module and Cone in the sandboxed build environment.
2. In a second job on a plain Ubuntu runner (an ordinary user, as VLC refuses root), the bundle is installed with `flatpak install --user`, like a user would; the KDE runtime comes from Flathub.
3. Cone starts in its sandbox (`flatpak run`) on Xvfb with a generated 12 s H.264 clip and its .srt, plays it to the end (`--play-and-exit`) and must end with exit code 0. Its log must show the Qt interface's video window, a video output, the FFmpeg decoder and the subtitle decoder. A screenshot at 6 s and the log are kept as the `flatpak-run` artifact.

## 3. Runs
| Run | Result |
|---|---|
| #1-#4 | failed, fixed one by one: CMake 4 refuses libebml's old minimum (policy 3.5), libdvbpsi's git tree needs a newer automake check (release tarball + VLC's contrib patches), VLC's configure needs `BUILDCC=gcc` (the SDK has no `c99`), the quoted `CONE_DESKTOP_ID` broke VLC's embedded configure line (now unquoted, made a string in the code) |
| #5 (42485320021), f6cf333 | failed in `modules/gui/qt`: moc "Undefined interface" (`QQmlParserStatus`, navigationmodel.hpp). VLC's `static_dirs.py --moc_include_dirs` read a leftover variable instead of its match and printed a bare `-I`, so moc never got the compiler's default include dirs. In the KDE SDK Qt's headers sit in `/usr/include`, which qmake leaves out as a default dir, so moc could not find `<QtQml/...>` (Ubuntu's Qt is in its own folder, so the bug never showed there). Fixed in the script: locally it now prints `-I/usr/include/c++/13 ... -I/usr/include`, before only `-I` |
| #8 (42488340355), 7ae2c4a | Cone compiled and installed (`make install`, plugin cache); the last step failed: `extras/package/flatpak/install-desktop.sh` was never committed (the root `.gitignore` pattern `install-*` caught it). Now added with `git add -f`; the manifest also brings the script, the launcher and the AppStream file in as `type: file` sources (`cone-flatpak/`), which the Flathub manifest can keep as they are (d4277b4; the commit message of ec12cb7 says it was reverted, it was not) |
| #11 (42491774284), ec12cb7 | **build green** (every module and Cone, about 34 min); the sandbox step stopped at its first line: Flathub's build image has no `dnf` any more. It already has Xvfb (`/app/bin`), so the step now only checks for it, and takes the screenshot when ImageMagick is there |
| #13 (42503775546), 73d3c1e | build green, the bundle installs; `flatpak run` ended at once with "VLC is not supposed to be run as root" (the CI container runs as root; no user ever does). The step now installs and runs Cone as an ordinary user, whose installation gets the KDE runtime from Flathub, and prints Cone's output when it fails |
| #16 (42505457823), 6d4e477 | the build image has no `useradd` (nor `dnf`): the sandbox run moved to its own job, `sandbox`, on a plain Ubuntu runner, which runs as an ordinary user: apt installs flatpak and Xvfb, the bundle is installed with `--user` (the KDE runtime from Flathub), then Cone runs as before |
| #18 (42506366616), de9bef5 | **green**: built (cached, 8 min), the bundle installed on a plain Ubuntu runner with the KDE runtime from Flathub, Cone started in its sandbox on Xvfb, played the 12 s clip and its .srt to the end and exited with code 0 after 14 s; its log has the Qt video window, a video output, avcodec and subsdec. The screenshot at 6 s shows the clip in Cone's window with the subtitle "Cone in its Flatpak". Expected messages on a runner without a GPU: no VA-API / VDPAU driver, no DRI3 |
| #8 (42488340355), 7ae2c4a | Cone compiled and installed (`make install`, plugin cache); the last step failed: flatpak-builder's copy of the tree leaves out the manifest's own folder, so `extras/package/flatpak/install-desktop.sh` was missing. The launcher, the script and the AppStream file now come in as `type: file` sources (`cone-flatpak/`) |

## 4. Flathub
The submission steps, the open question about the app ID's GitHub repository, and how releases reach Flathub: redesign/SUBMIT_TO_FLATHUB.md.

## 5. Retest (Linux, PC session or a Linux user)
1. Download the `cone-player` artifact of a green build-flatpak run (a zip with `cone-player.flatpak`).
2. `flatpak install --user cone-player.flatpak` (Flathub must be set up as a remote for the KDE runtime: `flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo`).
3. Start Cone Player from the menu: the window shows Cone's icon (not a generic one) in the dock, also on Wayland.
4. Play a video from the Videos folder and one from a USB stick; open a file in another folder through Open File(s).
5. Media keys and the desktop's media controls show "Cone Player"; a second file opened from the file manager plays in the same window.
6. `flatpak uninstall --user io.github.StickyGonzales.ConePlayer` removes it.
