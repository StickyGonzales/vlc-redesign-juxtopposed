# Linux: Debian package (branch wip/linux-deb)

Branch `wip/linux-deb`, on top of `wip/linux-install` (it uses that branch's menu entry and icons). Draft pull request into `wip/next-test`. CI and packaging only, Cone build only.

## The package
`cone-player_<version>_amd64.deb`, built by `.github/scripts/linux-deb.sh` from the portable folder:
- in **every Linux build** (artifact `cone-linux-deb-amd64`, and on the test-builds draft);
- and in **release-linux.yml**, which adds it to the draft release next to the AppImage and the tarball, with its SHA-256.

| Path | What it is |
|---|---|
| `/opt/cone-player/` | the portable folder, as it is (without install.sh / uninstall.sh) |
| `/usr/bin/cone-player` | the command (`exec /opt/cone-player/cone "$@"`) |
| `/usr/share/applications/cone-player.desktop` | the menu entry (`Exec=cone-player %U`), video, audio and subtitle types for Open with |
| `/usr/share/icons/hicolor/*/apps/cone-player.png` | the icon, 16 to 256 px |
| `/usr/share/doc/cone-player/copyright` | GPL-2+, the design's CC BY 4.0, not affiliated with VideoLAN |

**Next to VLC:**
- Every path is Cone Player's own. There is no Conflicts, Replaces, Provides or diversion.
- The package installs next to Debian's or Ubuntu's `vlc` and leaves it alone.
- Cone keeps its own settings (`~/.config/Cone`).

**Version:** from the tarball's name; a pre-release label sorts first (`1.2.0-beta` → `1.2.0~beta`).

**Dependencies:**

| Field | Packages |
|---|---|
| Depends | the system libraries the portable package leaves to the system: `libc6 (>= the glibc the build needs)`, `libgl1`, `libopengl0`, `libegl1`, `libx11-6`, `libx11-xcb1`, `libxcb1`, `libdrm2`, `libgbm1`, `libexpat1`, `zlib1g`, `libdbus-1-3`, `libudev1`, `libasound2t64 \| libasound2` |
| Recommends | the sound servers: `libpulse0 \| pipewire-pulse`, `libpipewire-0.3-0t64 \| libpipewire-0.3-0` |
| Suggests | the libraries only optional plug-ins need: JACK, SFTP (`libssh-4`), SMB shares, the GTK theme |

**Found in the clean-container test:** without `libopengl0` the interface itself did not load ("cannot load plug-in libqt_plugin.so: libOpenGL.so.0"). A minimal Ubuntu does not have it, so it is now a dependency.

## Test: clean Ubuntu 24.04 container (docker `ubuntu:24.04`)
The .deb from build-linux #52's tarball, rebuilt with the fixed dependencies:

| Step | Result |
|---|---|
| Ubuntu's VLC first (`vlc-bin` 3.0.20-3build6) | installed |
| `apt-get install ./cone-player_0.1.0_amd64.deb` | installs with its dependencies; dpkg's triggers refresh the menu and icon caches |
| `desktop-file-validate` | no errors; `mimeinfo.cache`: `video/mp4=cone-player.desktop;` |
| `cone-player --version` (as a user) | "Cone Player 0.1.0, based on VLC 4.0.0-dev …" |
| start under Xvfb with the test video and its .srt | the Cone window, "Received first picture", the subtitle file loaded, **no "cannot load plug-in"** (picture: `redesign/fix-shots/linux_deb_play.jpg`) |
| `vlc-bin` after installing Cone | unchanged, `/usr/bin/vlc` there |
| `apt-get remove cone-player` | `/opt/cone-player`, the command, the entry, the icons and the `mimeinfo.cache` lines are gone; VLC is still installed |

The same steps run on a runner after every Linux build (LINUX_SMOKE_NOTES.md).

## Runs
| Run | Result |
|---|---|
| build-linux #55 (41256439073), this branch | build, tarball, AppImage and **cone-player_0.1.0_amd64.deb green** |
| Clean Ubuntu 24.04 container (docker, build #55's .deb) | `apt install ./cone-player_0.1.0_amd64.deb` next to Ubuntu's vlc-bin 3.0.20; desktop file valid; mimeinfo.cache lists Cone for video/mp4; `cone-player --version` prints Cone Player 0.1.0; the Qt interface plays an H.264 file with its .srt, no "cannot load plug-in"; `apt remove cone-player` leaves no file in /opt/cone-player, /usr/bin or the icon theme; VLC still installed and starts |
| CI smoke checks (wip/linux-smoke) | `deb: install`, `deb-h264` (window, playback, quit 0.26 s, every plug-in loads) and `deb: remove` **pass** on GitHub (run 41256425136) |

First container try without `libopengl0`: the Qt plug-in could not load (libOpenGL.so.0 missing on a minimal system). Fixed in 57a3bedf: Depends lists it.

## Retest (a Debian or Ubuntu desktop)
1. `sudo apt install ./cone-player_*_amd64.deb`. Cone Player is in the applications menu; with VLC installed, both are there.
2. Open with on a video, a song and a `.srt`: Cone Player is listed, and the default player is unchanged.
3. `cone-player <file>` plays it. VLC still starts as before.
4. `sudo apt remove cone-player`: the entry goes, and VLC stays.
