# Release 1.2.0: release texts (ready to paste)

Three texts. Each one is the body of its GitHub release:

| Release | Tag | Title | Settings |
|---|---|---|---|
| Windows | `v1.2.0` (on `redesign`) | Cone Player 1.2.0 | full release, set as Latest |
| Linux | `linux-v1.2.0-beta3` (on `redesign`) | Cone Player 1.2.0 for Linux (beta 3) | pre-release, not Latest |
| macOS | only if the Mac build is green and a tester confirms it plays | Cone Player for macOS (experimental preview) | pre-release, not Latest |

Fill in when publishing:
- `<commit>`: the tagged commit.
- The Linux checksums and run link: written by release-linux.
- The macOS file name.

---

## 1. Cone Player 1.2.0 (Windows)

**Cone Player 1.2.0** fixes a freeze while changing the playback speed and brings Netflix-style Up Next for shows. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface. A Linux beta of the same version comes as its own release.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## Fixed

- **No more freeze when you drag the playback speed slider.** On HEVC (x265) films, dragging the speed slider could freeze Cone Player until it was ended in Task Manager. 1.1.2 listed this as a known issue; it is fixed.

## New: Up Next for shows

- **The card comes when the credits start**, not in the last seconds. It shows the next episode with **Next episode** and **Cancel**, and the countdown only runs in the last 10 seconds, so a scene after the credits still plays.
- **Cone finds the credits** from a chapter named like "End Credits". Otherwise it uses the point you taught it: press Next during the credits of an episode once, and the next episodes of that show (all its seasons) show the card at that point. Otherwise it uses the new setting **Settings > Playback > Episodes > Show Up Next** (last 30 s, 1 min or 2 min; 1 min by default). The card never shows in the middle of an episode.
- **No more "Looks like a show. Play episodes in a row?" question.** Episodes named like `S01E02` or `1x02` play in a row by themselves. Files only numbered (`01`, `Part 2`, `Episode 2`) show the card too, but only play when you click Next episode.
- **"Turn off autoplay"** on the card switches autoplay off. Turn it on again in Settings > Playback > Episodes > **Play episodes in a row** (now a simple On / Off, On by default).
- If autoplay was off in 1.1, it stays off. A folder you answered "No" for stays off.
- Seeking back hides the card until the credits point comes again. Pausing pauses the countdown. **Forget all** (Settings > Playback > Episodes) also forgets the learned credits points.

## Also new

- **"Skip this version" on the update notice.** That version is never offered again; a newer one still is. Settings > General shows the skipped version and can undo it.
- **Upgrades keep your desktop shortcut as it is.** If you deleted the Cone Player shortcut, an upgrade (also a silent one) no longer brings it back. If it is on the desktop, the upgrade keeps it.

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.2.0-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have an earlier Cone Player installed? The installer upgrades it in place and keeps your settings and library.

**Portable zip: `ConePlayer-1.2.0-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.2.0` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Known issues

- The mouse pointer stays visible over the video during playback, also in fullscreen (the bars do hide). This will be fixed.
- On a few HEVC files with many B-frames, switching the audio track can still stall the video, and quitting can then take 5 seconds before Cone Player ends itself. Settings and the resume position are kept.
- Closing Cone Player sometimes takes up to 5 seconds after its window disappears, until it ends itself. Settings and the resume position are kept.
- The Subtitle Duration Factor slider is still hidden: in this VLC 4 engine it made ASS / SSA subtitles disappear.
- New Cone Player texts are in English in every language for now.
- The portable zip doesn't show up in Windows' "Open with" menu. Use the installer for that, or drag files onto Cone Player.
- The Linux version is a beta with its own release (see the README).

## Credits and license

- Design: "VLC Redesign" by **Juxtopposed**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): [Figma file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and [video](https://youtu.be/ERFeOgqk324). Changes were made to fit it to VLC.
- Engine: [VLC media player](https://www.videolan.org/vlc/) by VideoLAN and its contributors.
- Fonts: Inter and DM Mono, SIL Open Font License.
- Built by [StickyGonzales](https://github.com/StickyGonzales).
- License: Cone Player is free software under the GNU GPL, version 2 or later. The libVLC engine is under the GNU LGPL, version 2.1 or later. Source code: this repository, commit [`<commit>`](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/tree/<commit>).

Cone Player is not affiliated with or endorsed by VideoLAN or Juxtopposed. VLC, VLC media player and VideoLAN are trademarks of the VideoLAN non-profit organization.

---

## 2. Cone Player 1.2.0 for Linux (beta 3)

**Cone Player 1.2.0 for Linux (beta 3)**, x86_64: the same Cone Player as the Windows 1.2.0 release, built for Linux. It is experimental: based on the development version of VLC media player (VLC 4).

> **Beta:** checked automatically in a Linux environment on GitHub (with dummy audio and software video). Real sound output and GPU video decoding have not been tested on real Linux hardware yet. Please report what works and what doesn't in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues). Windows users: get [Cone Player 1.2.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.2.0).

**Fixed:** no more freeze when you drag the playback speed slider on HEVC (x265) films.

**New, as on Windows:**
- **Up Next for shows.** The card comes when the credits start, and the countdown only runs in the last 10 s. There's no more "Play episodes in a row?" question, and a "Turn off autoplay" link is on the card. Episodes only numbered play when you choose.
- **"Skip this version"** on the update notice.

**New on Linux:**
- **Files you open from the file manager or "Open with" play in the Cone Player window that is already open**, instead of starting a second Cone Player.
- **Cone Player shows with its own name and icon** in the dock, the window switcher, the desktop's media controls and the sound mixer.
- **Hardware video decoding finds your system's drivers on more distributions** (Fedora, Arch, openSUSE and others, not only Debian and Ubuntu).
- **The update notice offers the newest Linux release**, not the Windows one.
- The Debian package's file name now matches `SHA256SUMS`, so `sha256sum -c` passes.

**Downloads:**
- **AppImage**: download, `chmod +x` it, start it. AppImageLauncher or Gear Lever add it to the menu with its icon. A folder named `portable` next to it keeps settings and library there.
- **Portable tarball**: unpack, start `./cone`, or run `./install.sh` to install it for your user (no sudo; menu entry, icons, "Open with"). `README-LINUX.txt` inside explains the rest.
- **Debian / Ubuntu package** (amd64): `sudo apt install ./cone-player_1.2.0-beta3_amd64.deb`. Installs into `/opt/cone-player` with the command `cone-player`, next to VLC without replacing it; remove it with `sudo apt remove cone-player`.
- Needs a 64-bit Linux desktop (X11 or Wayland) with glibc 2.39 or newer.
- Cone keeps its own settings (`~/.config/Cone`, `~/.local/share/Cone`, `~/.cache/Cone`) and runs next to an installed VLC.
- Checked on GitHub before release: H.264 and HEVC playback with subtitles, seeking, Settings, the menu, quitting, opening a file in the running window, the media controls' name, and installing and removing the tarball and the package (Ubuntu 24.04).

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.

SHA-256: (written by release-linux)

---

## 3. Cone Player for macOS (experimental preview)

Use only if the Mac build is green and a tester confirmed it plays.

**Cone Player for macOS, experimental preview**: a first build of Cone Player for **Apple Silicon** Macs (M1 and later), macOS 12 or later. It's a preview for testers, not a finished release. Windows users: get [Cone Player 1.2.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.2.0).

> **Preview:** checked automatically on GitHub's Macs (playback, subtitles, quitting), and tested by hand on one Mac. Sound, Retina scaling and everyday use have hardly been tried yet. Please report what works and what doesn't in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues), with your macOS version and Mac model.

**Install:**
1. Open the `.dmg` and drag **Cone Player** onto **Applications**.
2. The app isn't notarized by Apple, so macOS blocks the first start. Right-click **Cone Player** in Applications and choose **Open**, then **Open** again.
   - On macOS 15 (Sequoia) and later, if the warning only offers **Done** or **Move to Trash**: click **Done**, then go to **System Settings > Privacy & Security**, find "Cone Player was blocked" and click **Open Anyway**.

There's no Intel build yet. Cone keeps its own settings and runs next to an installed VLC.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.
