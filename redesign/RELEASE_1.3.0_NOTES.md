# Release 1.3.0: release texts (ready to paste)

Three texts. Each one is the body of its GitHub release:

| Release | Tag | Title | Settings |
|---|---|---|---|
| Windows | `v1.3.0` (on `redesign`) | Cone Player 1.3.0 | full release, set as Latest |
| Linux | `linux-v1.3.0-beta4` (on `redesign`) | Cone Player 1.3.0 for Linux (beta 4) | pre-release, not Latest |
| macOS | `macos-v1.3.0` (the draft release-macos makes) | Cone Player 1.3.0 for macOS (preview) | pre-release, not Latest |

Fill in when publishing: `<commit>` (the tagged commit) and the Linux and macOS checksums.

---

## 1. Cone Player 1.3.0 (Windows)

**Cone Player 1.3.0** brings four features of its own: the next episode when the credits start, subtitle auto-sync, track memory for shows and any accent color you like. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface. Linux and macOS versions of 1.3.0 come as their own releases.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## New in Cone

These four are Cone Player's own additions; they are not part of Juxtopposed's design.

- **Netflix-style next episode.** When the credits start, an Up Next card offers the next episode. Cone finds where the credits start by matching the credits music across the episodes of a show, so it works without chapters. If you'd rather choose, set a **Fixed** time for the show in the sidebar (Playback > Up Next for *your show*).
- **Subtitle auto-sync.** One **Auto-sync** button (sidebar > Subtitles > Synchronization) lines the subtitles up with the speech, and **Undo** puts them back as they were. It also fixes subtitles made for a different frame rate.
- **Track memory.** Pick your audio and subtitle language once in an episode, and the rest of the show follows, in every season. It goes by language, so it works when episodes list their tracks in a different order.
- **Custom accent color.** Next to the nine colors, **Custom** takes any color by its hex code and shows it on the whole player live as you type (Settings > General > Appearance, and in the first start).

## Fixes and smaller changes

- **New on-screen messages.** Volume, seeking, speed, subtitle delay and the other messages now show in a Cone-style box at the top, with the key you pressed. VLC's position bar no longer stays over the video after a seek.
- **Up Next card fixes.** Clicking **Next episode** now always plays the next episode; on Windows it could stop and show the home page instead. A click on the card no longer brings up the control bar or moves the card, and in the last 10 seconds the button fills up as it counts down. The card also has cleaner proportions.
- **First start.** A file you open with Cone Player's very first start now waits until the welcome screens are closed, then plays from the beginning.
- **Open with while playing.** A file you open with "Open with" or a double-click while Cone Player plays now plays right away in the open window, instead of only being added to the queue.
- **F always leaves fullscreen,** however you entered it (the top bar's button, F11, the menu, a double-click).
- **Auto-sync messages** say what happened, like "Auto-sync  Moved -2.3 s" and "Auto-sync  Undone".

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.3.0-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have an earlier Cone Player installed? The installer upgrades it in place and keeps your settings and library.

**Portable zip: `ConePlayer-1.3.0-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.3.0` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Known issues

- On a few HEVC files with many B-frames, switching the audio track can still stall the video, and quitting can then take 5 seconds before Cone Player ends itself. Settings and the resume position are kept.
- Closing Cone Player sometimes takes up to 5 seconds after its window disappears, until it ends itself. Settings and the resume position are kept.
- Auto-sync moves the whole subtitle track by one amount, so it can't fix subtitles that drift apart only after an ad break or a cut scene. With little speech or loud music it may find no match. It works with text subtitles (not DVD or Blu-ray picture subtitles).
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

## 2. Cone Player 1.3.0 for Linux (beta 4)

**Cone Player 1.3.0 for Linux (beta 4)**, x86_64: the same Cone Player as the Windows 1.3.0 release, built for Linux. It is experimental: based on the development version of VLC media player (VLC 4).

> **Beta:** checked automatically in a Linux environment on GitHub (with dummy audio and software video). Real sound output and GPU video decoding have not been tested on real Linux hardware yet. Please report what works and what doesn't in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues). Windows users: get [Cone Player 1.3.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.3.0).

**Runs on more distributions.** Cone Player now needs glibc 2.35 instead of 2.39: **Ubuntu 22.04, Linux Mint 21, Debian 12, Fedora 36 and newer** (beta 3 needed Ubuntu 24.04 or Debian 13).

**New in Cone, as on Windows** (Cone Player's own additions, not part of Juxtopposed's design):
- **Netflix-style next episode:** the Up Next card appears when the credits start, found by matching the credits music across episodes, with a per-show Fixed time in the sidebar.
- **Subtitle auto-sync:** one button lines the subtitles up with the speech, with Undo.
- **Track memory:** pick your audio and subtitle language once and the rest of the show follows.
- **Custom accent color:** any color by its hex code, with a live preview.

**Fixes and smaller changes:** Cone-style on-screen messages (and no VLC position bar after a seek), Up Next card fixes (a click shows no control bar and the card holds still; cleaner proportions), a first start that waits for the welcome screens, F always leaves fullscreen, and clearer Auto-sync messages.

**On older systems:** sound goes through PulseAudio (or PipeWire's PulseAudio service), not straight to PipeWire, and very new formats such as VVC aren't supported.

**Downloads:**
- **AppImage**: download, `chmod +x` it, start it. AppImageLauncher or Gear Lever add it to the menu with its icon. A folder named `portable` next to it keeps settings and library there.
- **Portable tarball**: unpack, start `./cone`, or run `./install.sh` to install it for your user (no sudo; menu entry, icons, "Open with"). `README-LINUX.txt` inside explains the rest.
- **Debian / Ubuntu package** (amd64): `sudo apt install ./cone-player_1.3.0-beta4_amd64.deb`. Installs into `/opt/cone-player` with the command `cone-player`, next to VLC without replacing it; remove it with `sudo apt remove cone-player`.
- Cone keeps its own settings (`~/.config/Cone`, `~/.local/share/Cone`, `~/.cache/Cone`) and runs next to an installed VLC.
- Checked on GitHub before release: H.264 and HEVC playback with subtitles, seeking, Settings, the menu, quitting, the Up Next card's Next episode, opening a file in the running window, and installing and removing the tarball and the package.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.

SHA-256: (written by release-linux)

---

## 3. Cone Player 1.3.0 for macOS (preview)

**Cone Player 1.3.0 for macOS (preview)**: Cone Player for **Apple Silicon** (M1 and later) and **Intel** Macs, macOS 12 or later. It's a preview for testers, not a finished release. Windows users: get [Cone Player 1.3.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.3.0).

> **Testers wanted:** it hasn't been tried on a real Mac yet. It is only checked automatically on GitHub's test Macs, where the video area stayed black, probably because of their virtual graphics (not confirmed). If you have a Mac, please try it and tell us in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues) what works and what doesn't, with your macOS version and Mac model.

**Which file:** `Cone-1.3.0-macos-arm64.dmg` for Apple Silicon, `Cone-1.3.0-macos-x86_64.dmg` for Intel Macs.

**Install:**
1. Open the `.dmg` and drag **Cone Player** onto **Applications**.
2. The app is not signed with an Apple Developer ID or notarized by Apple, so macOS blocks the first start. Right-click **Cone Player** in Applications and choose **Open**, then **Open** again.
   - On macOS 15 (Sequoia) and later, if the warning only offers **Done** or **Move to Trash**: click **Done**, then go to **System Settings > Privacy & Security**, find "Cone Player was blocked" and click **Open Anyway**.

It has the same features as Cone Player 1.3.0 for Windows. Cone keeps its own settings and runs next to an installed VLC. The update notice doesn't offer Mac versions yet: check the Releases page.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.
