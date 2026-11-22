# Release 1.5.1: release texts (ready to paste)

Three texts. Each one is the body of its GitHub release:

| Release | Tag | Title | Settings |
|---|---|---|---|
| Windows | `v1.5.1` (on `redesign`) | Cone Player 1.5.1 | full release, set as Latest |
| Linux | `linux-v1.5.1-beta7` (on `redesign`) | Cone Player 1.5.1 for Linux (beta 7) | pre-release, not Latest |
| macOS | `macos-v1.5.1` (the draft release-macos makes) | Cone Player 1.5.1 for macOS (preview) | pre-release, not Latest |

Fill in when publishing: `<commit>` (the tagged commit) and the Linux and macOS checksums.

---

## 1. Cone Player 1.5.1 (Windows)

**Cone Player 1.5.1** fixes crackling 5.1 sound on stereo speakers, adds an optional close button in fullscreen and fixes Ctrl+1 to Ctrl+0. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface. Linux and macOS versions of 1.5.1 come as their own releases.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## New

- **A close button in fullscreen, if you want one** (issue #98). Settings > Interface > Playback Controls > "Show a close button in fullscreen". When it's on, the top bar in fullscreen ends with the same close button as in a window. It's off by default, as in VLC.

## Fixed

- **5.1 sound no longer crackles on stereo speakers.** On some laptops, a movie with 5.1 sound played with heavy crackling through the built-in speakers. Cone Player now mixes 5.1 down to stereo itself when your speakers or headphones are stereo. Real surround systems still get all the channels.
- **Ctrl+1 to Ctrl+0 open your recent files again.** They used to try to open the file's path as a web address, so nothing played.

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.5.1-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have an earlier Cone Player installed? The installer upgrades it in place and keeps your settings and library (leave "Delete preferences and cache" unticked).

**Portable zip: `ConePlayer-1.5.1-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.5.1` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Tips

- **Updating:** run the new installer and keep **"Upgrade using previous settings"**: your settings, library and shows stay.
- **Closing in fullscreen:** Escape leaves fullscreen and Ctrl+Q quits at any time; the new close button is for the mouse.
- **Speaker setup:** Settings > Audio > "Speaker setup" stays on Automatic. Pick Stereo or 5.1 there only to force a layout.

## Known issues

- YouTube links play without sound: YouTube sends HD sound as a separate stream that the VLC 4 engine can't play together with the picture yet. Sound for YouTube comes in a later release.
- On a few HEVC files with many B-frames, switching the audio track can still stall the video; Cone Player then ends itself within 5 seconds of quitting. Settings and the resume position are kept.
- Clean show names drop a year at the end of a name: a folder "Class.of.2009" shows as "Class of".
- Auto-sync moves the whole subtitle track by one amount, so it can't fix subtitles that drift apart only after an ad break or a cut scene. It works with text subtitles (not DVD or Blu-ray picture subtitles).
- Finding the credits needs a folder of 3 or more episodes on your computer, and takes a minute in the background the first time.
- The Subtitle Duration Factor slider is still hidden: in this VLC 4 engine it made ASS / SSA subtitles disappear.
- New Cone Player texts are in English in every language for now.
- The portable zip doesn't show up in Windows' "Open with" menu. Use the installer for that, or drag files onto Cone Player.
- The Linux version is a beta and the macOS version a preview, each with its own release.

## Credits and license

- Design: "VLC Redesign" by **Juxtopposed**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): [Figma file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and [video](https://youtu.be/ERFeOgqk324). Changes were made to fit it to VLC.
- Engine: [VLC media player](https://www.videolan.org/vlc/) by VideoLAN and its contributors.
- Fonts: Inter and DM Mono, SIL Open Font License.
- Built by [StickyGonzales](https://github.com/StickyGonzales).
- License: Cone Player is free software under the GNU GPL, version 2 or later. The libVLC engine is under the GNU LGPL, version 2.1 or later. Source code: this repository, commit [`<commit>`](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/tree/<commit>).

Cone Player is not affiliated with or endorsed by VideoLAN or Juxtopposed. VLC, VLC media player and VideoLAN are trademarks of the VideoLAN non-profit organization.


---

## 2. Cone Player 1.5.1 for Linux (beta 7)

**Cone Player 1.5.1 for Linux (beta 7)**, x86_64: the same Cone Player as the Windows 1.5.1 release, built for Linux. It is experimental: based on the development version of VLC media player (VLC 4).

> **Beta:** checked automatically in a Linux environment on GitHub (with dummy audio and software video). Real sound output and GPU video decoding have not been tested on real Linux hardware yet. Please report what works and what doesn't in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues). Windows users: get [Cone Player 1.5.1](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.5.1).

**New and fixed, as on Windows:**
- **A close button in fullscreen, if you want one:** Settings > Interface > Playback Controls (off by default, issue #98).
- **Ctrl+1 to Ctrl+0 open your recent files again.**
- (The 5.1 sound fix is for Windows' audio output and changes nothing on Linux.)

**Downloads:**
- **AppImage**: download, `chmod +x` it, start it. AppImageLauncher or Gear Lever add it to the menu with its icon. A folder named `portable` next to it keeps settings and library there.
- **Portable tarball**: unpack, start `./cone`, or run `./install.sh` to install it for your user (no sudo; menu entry, icons, "Open with"). `README-LINUX.txt` inside explains the rest.
- **Debian / Ubuntu package** (amd64): `sudo apt install ./cone-player_1.5.1-beta7_amd64.deb`. Installs into `/opt/cone-player` with the command `cone-player`, next to VLC without replacing it; remove it with `sudo apt remove cone-player`.
- Needs a 64-bit Linux desktop (X11 or Wayland) with glibc 2.35 or newer: Ubuntu 22.04, Linux Mint 21, Debian 12, Fedora 36 or newer.
- Cone keeps its own settings (`~/.config/Cone`, `~/.local/share/Cone`, `~/.cache/Cone`) and runs next to an installed VLC.
- Checked on GitHub before release: H.264 and HEVC playback with subtitles, the video inside Cone's window on Wayland and X11, seeking, Settings, the menu, quitting, a file opened right after quitting, the Up Next card's Next episode, opening a file in the running window, and installing and removing the tarball and the package.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.

SHA-256: (written by release-linux)

---

## 3. Cone Player 1.5.1 for macOS (preview)

**Cone Player 1.5.1 for macOS (preview)**: Cone Player for **Apple Silicon** (M1 and later) and **Intel** Macs, macOS 12 or later. It's a preview for testers, not a finished release. Windows users: get [Cone Player 1.5.1](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.5.1).

**New and fixed, as on Windows:**
- **A close button in fullscreen, if you want one:** Settings > Interface > Playback Controls (off by default, issue #98).
- **Ctrl+1 to Ctrl+0 open your recent files again.**
- (The 5.1 sound fix is for Windows' audio output and changes nothing on macOS.)

**Which file:** `Cone-1.5.1-macos-arm64.dmg` for Apple Silicon, `Cone-1.5.1-macos-x86_64.dmg` for Intel Macs.

**Install (the app is not signed by Apple):**
1. Open the `.dmg` and drag **Cone Player** onto **Applications**.
2. The app has no Apple Developer ID and isn't notarized, so macOS blocks the first start. Right-click **Cone Player** in Applications and choose **Open**, then **Open** again.
   - On macOS 15 (Sequoia) and later, if the warning only offers **Done** or **Move to Trash**: click **Done**, then go to **System Settings > Privacy & Security**, find "Cone Player was blocked" and click **Open Anyway**.
   - Or in Terminal: `xattr -dr com.apple.quarantine "/Applications/Cone Player.app"`
3. Each new version may ask again for folder access, because its signature changes.

**Tips:**
- Drag a video onto the window or the Dock icon to play it; Cmd+P opens Settings, Cmd+Q quits.
- If a playlist's songs on the Desktop won't play: System Settings > Privacy & Security > Files and Folders > Cone Player > Desktop Folder.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.
