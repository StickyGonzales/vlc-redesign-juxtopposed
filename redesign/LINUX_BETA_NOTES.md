# Cone for Linux, beta: release notes (draft)

**Draft only, nothing is published.** These are the notes for Cone's first Linux beta (Decision (Sticky) 3 in LINUX_NOTES.md: Linux ships as its own beta once it passes testing). They become the release text when StickyGonzales tags a `redesign` commit `linux-v<version>-beta` and publishes the draft release that `release-linux.yml` creates. Before that: the Linux fix branches below must be merged into `redesign` through `wip/next-test` / `wip/linux-build`, and one real Linux PC should run the "Not tested in the sandbox" list.

Version placeholder: `<version>` = the Windows beta it follows (e.g. 0.2.0), so both platforms carry the same Cone version and the same design state.

---

## Cone <version> beta for Linux

Cone is a media player based on VLC media player, with the full "VLC Redesign" by Juxtopposed built on top: the same playback engine, codecs and formats as VLC 4, and her new interface for everything around them. This is the first Linux build. It is a **beta**: it tracks VLC 4 development code, and some parts have only been tested on a virtual display (list below).

Cone is not an official VideoLAN product. "VLC" and "VLC media player" are trademarks of the VideoLAN non-profit.

### Download

| File | What it is |
|---|---|
| `Cone-<version>-beta-x86_64.AppImage` | One file. Make it executable and start it: `chmod +x Cone-*.AppImage && ./Cone-*.AppImage`. |
| `Cone-<version>-beta-linux-x86_64.tar.xz` | The same app as a folder: unpack it anywhere and start `./cone`. `README-LINUX.txt` inside explains the menu entry and portable mode. |
| `SHA256SUMS.txt` | Checksums of both files. |

**Requirements:** 64-bit x86 Linux with **glibc 2.39 or newer** (Ubuntu 24.04, Debian 13, Fedora 40, Linux Mint 22, current Arch and newer). Older systems, such as Ubuntu 22.04, cannot start it. X11 or Wayland, PulseAudio, PipeWire (through its PulseAudio service) or ALSA.

**Portable mode:** a folder named `portable` next to the `.AppImage` file (or next to `cone` in the folder version) keeps all settings, the media library and caches in that folder. Without it Cone uses `~/.config/Cone`, `~/.local/share/Cone` and `~/.cache/Cone`, apart from any VLC you have installed.

**No FUSE?** `./Cone-*.AppImage --appimage-extract-and-run` starts it without mounting (slower start).

### What is in it

Everything from Cone <version> beta for Windows: her player (thin control bar, thick seek bar, cone volume slider up to 200 %, bars that show on hover and fade out), the top bar, the tracks popup, the settings sidebar (Playback, Video, Audio, Subtitles tabs, presets per show), the queue with Bookmarks and Chapters, the Add Subtitles dialog, the Settings dialog with her categories, Keyboard Shortcuts, Customize Player, the library (Home, Videos, Music, Network, Playlists, Recent, pins), the music view, the mini player, onboarding, dark and light themes and the accent colours.

Linux specifics:
- Cone draws its own window buttons, as in the design; the system title bar is a setting (Settings > Interface, "Show window decorations").
- Cone has its own name and icon on the desktop (dock, task switcher, sound settings, media keys through MPRIS), its own settings folders and its own single instance, so it never mixes with an installed VLC.
- Settings > General > Interface language works on Linux (Cone remembers it and starts in that language).
- Settings > Audio > Output device lists the sound server's devices (PulseAudio / PipeWire keep the choice for Cone, as they do the volume).
- Settings > Performance > Video post-processing is available (libpostproc is built in).
- The audio visualizer list has one Linux-only entry, "3D OpenGL spectrum".

### Fixed since the Windows <version> beta, on both platforms where it applies

- Picking the Spectrometer (or any visualizer) while a song played could end Cone on Linux (a check in the subtitle placement code). Fixed in the player core; the Windows build was not affected in practice.
- (the rest of the Windows changelog of <version> applies as is)

### Known limits of this beta

- **Tested on a virtual display only** (software rendering, no GPU, no sound card, X11 with openbox, 100 % scaling). Not yet tested on a real Linux PC: sound output, GPU video output and hardware decoding (VA-API / VDPAU), Wayland (window placement, fullscreen), display scaling (125 / 150 / 200 %), real mouse drag and drop (Customize Player, drag to the queue).
- Wayland: the tray popup may not appear in the bottom-right corner, and "Keep window above other windows" is ignored by most Wayland desktops (both are the compositor's choice).
- Settings > Network has no proxy rows: on Linux VLC takes the proxy from the system (libproxy's `proxy` tool when it is installed, otherwise the `http_proxy` environment variable); the rows exist only on Windows.
- Settings > Audio: "Always starts at" (start volume) is Windows only; PulseAudio and PipeWire remember Cone's volume themselves.
- After Cone was ended by force (or by its quit watchdog, which ends a quit that hangs for more than 5 seconds), the next start asks whether to restore the queue. That is VLC's own crash recovery; answer No to start empty.
- The ncurses, SFTP, SMB and desktop-notification plugins load only if the system has their libraries (they are not bundled).

### Credits and licence

- Design: "VLC Redesign" by **Juxtopposed**, [Figma Community file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) (CC BY 4.0) and her [video](https://youtu.be/ERFeOgqk324).
- Built by **StickyGonzales**, based on **VLC media player** by VideoLAN and the VLC contributors.
- Licence: GNU GPL version 2 or later, like VLC. The source code is the `redesign` branch of this repository at the release tag.

---

## For the release (not part of the public text)

- Tag: `linux-v<version>-beta` on a `redesign` commit that contains the Linux fixes below; `release-linux.yml` builds, checks the tag is on `redesign`, writes `SHA256SUMS.txt` and creates a **draft** pre-release. Publishing is a manual click after StickyGonzales's OK.
- Linux fixes that must be merged first (each its own branch and draft PR):

| Fix | Branch | Into | Kind |
|---|---|---|---|
| Interface language on Linux (P8-03) | `wip/fix-linux-language` (PR #48) | `wip/next-test` | Qt (shared code, Linux path) |
| Audio Output device on Linux (P8-11) | `wip/fix-linux-audio-device` (PR #49) | `wip/next-test` | QML (shared code, Linux path) |
| sub-ui-margin on the dummy output (Spectrometer abort) | `wip/fix-sub-ui-margin-dummy` (PR #51) | `wip/next-test` | core: its own Windows build and test |
| libpostproc in the Linux build (P8-16) | `wip/fix-linux-postproc` (PR #50) | `wip/linux-build` | CI script (exists only there) |
| Release build without assertions, as Windows | `wip/fix-linux-release-build` | `wip/linux-build` | CI script (exists only there) |

- `build-linux.yml` and the Linux scripts reach `redesign` with `wip/linux-build`; until then a Linux release cannot be built from `redesign`.
- Verification state: redesign/LINUX_VERIFY.md (sandbox rerun of 2026-10-25).
