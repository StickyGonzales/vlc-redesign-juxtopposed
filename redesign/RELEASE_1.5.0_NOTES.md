# Release 1.5.0: release texts (ready to paste)

Three texts. Each one is the body of its GitHub release:

| Release | Tag | Title | Settings |
|---|---|---|---|
| Windows | `v1.5.0` (on `redesign`) | Cone Player 1.5.0 | full release, set as Latest |
| Linux | `linux-v1.5.0-beta6` (on `redesign`) | Cone Player 1.5.0 for Linux (beta 6) | pre-release, not Latest |
| macOS | `macos-v1.5.0` (the draft release-macos makes) | Cone Player 1.5.0 for macOS (preview) | pre-release, not Latest |

**Not published.** Waits for StickyGonzales's go and for the privacy audit (STATUS.md), which blocks 1.5.0.

Fill in when publishing: `<commit>` (the tagged commit) and the Linux and macOS checksums.
Cone's own extras come first, then OpenSubtitles (StickyGonzales, 2026-11-16).

---

## 1. Cone Player 1.5.0 (Windows)

**Cone Player 1.5.0** lets you choose what happens when an episode ends, brings back downloading several OpenSubtitles results at once with clean names, makes quitting instant and fixes YouTube links. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface. Linux and macOS versions of 1.5.0 come as their own releases.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## Cone extras

### Up Next and shows
- **Choose what happens when an episode ends.** Settings > Playback > Episodes > "When an episode ends" replaces "Play episodes in a row":
  - **Play the next episode:** the countdown on the Up Next card, as before.
  - **Show Up Next, I'll click:** the card offers the next episode and waits for your click, no countdown.
  - **Do nothing.**
  Your saved choice carries over. The card's "Turn off autoplay" now switches to "Show Up Next, I'll click".
- **Up Next no longer skips episodes you finished.** An episode you watched to the end before starts from the beginning when autoplay reaches it; one you stopped partway still continues where you left it.
- **Stopping an episode keeps the show's subtitles.** Stopping, quitting or opening another file no longer saves "subtitles off" for the show; only a subtitle or audio track you pick yourself carries over to the next episodes.

### OpenSubtitles
- **Tick one result or several.** The best match is ticked to start with; tick more to download several at once and try them one by one, or click a ticked one to untick it. Save downloads every ticked subtitle and shows the best ranked of them. A subtitle you downloaded before is reused, not downloaded twice.
- **The best match is in your language,** even when OpenSubtitles files an upload under the wrong language: a "sintel.he" file listed as English goes below the English ones. Nothing is hidden.
- **Clean names.** A download keeps its own name, such as "Sintel (2010).eng.srt", and the subtitle list shows "Sintel (2010) [English]", without the OpenSubtitles number in front. A second subtitle of the same name shows its number once, as "sintel (2) [English]".

### Housekeeping
- **Cone tidies up after itself.** Up Next pictures, waveforms and downloaded subtitles are cleaned up: a show you deleted is forgotten after 14 days, a drive you unplugged keeps its data, and a show you renamed or moved (also to another drive) keeps its track choices, Up Next answers and credits points. Downloaded subtitles you tried but never used are deleted when the video closes, also when you quit right away. Settings > Playback > Remembered shows > Forget all also clears the pictures and downloaded subtitles.
- **Background work waits its turn.** Show detection, credits scans, waveforms and Up Next pictures share one low-priority queue: one job at a time, nothing heavy in Cone Player's first minute, paused while you seek or hover the timeline.
- **A crash can restore your playlist.** Cone Player saves the playlist at most 10 seconds after it changes, also while a video plays, so after a crash the next start offers to restore it.

## Fixed

### Playing and quitting
- **Quitting is instant.** Ctrl+Q, the window's close button and Quit in the menu hide Cone Player at once and stop the sound; the rest of the shutdown happens in the background. If a shutdown ever gets stuck, Cone Player still ends itself within 5 seconds.
- **Notices no longer cover each other.** The "You already watched till ..." prompt, the update notice and the profile notice stack above the control bar, 10 px apart, and slide down when one closes, in a window, maximized and in fullscreen.
- **YouTube links play** (with your own yt-dlp, issue #143):
  - **no still image:** a link no longer shows a tiny preview picture for 10 seconds and stops;
  - **works from shortcuts and folders with spaces:** a link opened after starting Cone Player from its shortcut or the Start menu plays, and so does a yt-dlp kept in a folder with a space (such as `C:\Program Files`);
  - **the quality setting is respected:** Settings > Playback > Preferred video quality picks the highest quality at or below your choice (1080p gives 1080p, not 144p).
  - **YouTube plays without sound for now.** YouTube sends the sound of its HD videos as a separate stream, and the VLC 4 engine inside Cone Player can't play the two together yet. This is a VLC core limit; sound for YouTube comes in a later release.

### Library, music and look
- **The album cover stays square** in the music player at every window size, maximized, in fullscreen and next to the lyrics (issues #129 and #69).
- **Thumbnails appear in Recent and Videos right away,** instead of a grey square until you left the page.
- **Recent shows the latest first,** on the Recent page and in Open Recent.
- **The custom accent color shows a color wheel until you pick one,** in Settings > General > Accent color and on the first-start theme screen.
- **Less work in the background.** Cone Player no longer redraws its interface while the bars are hidden or the window is minimized, searches for cast devices only while a Render list is open, and keeps the home page smooth during a big library scan.

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.5.0-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have an earlier Cone Player installed? The installer upgrades it in place and keeps your settings and library (leave "Delete preferences and cache" unticked).

**Portable zip: `ConePlayer-1.5.0-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.5.0` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Tips

- **Updating:** run the new installer and keep **"Upgrade using previous settings"**: your settings, library and shows stay.
- **Binge or not:** Settings > Playback > Episodes > "When an episode ends" sets it for every show; the Up Next card's "Turn off autoplay" switches to "Show Up Next, I'll click".
- **Trying subtitles:** in Add Subtitles > OpenSubtitles, tick two or three results and Save; then switch between them in the subtitle list until one fits. The ones you didn't use are deleted when the video closes.
- **YouTube:** install [yt-dlp](https://github.com/yt-dlp/yt-dlp), set its path in All Cone Settings > Input / Codecs > Stream filters > YT-DL > Path to YT-DLP, then Media > Open Network Stream and paste the link.
- **Jumping around:** the mouse wheel on the timeline moves 10 seconds per notch. On the keyboard: Alt+Left / Right 10 seconds, Ctrl+Left / Right 1 minute, Ctrl+Alt+Left / Right 5 minutes.

## Known issues

- YouTube links play without sound (VLC core limit, see above).
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

## 2. Cone Player 1.5.0 for Linux (beta 6)

**Cone Player 1.5.0 for Linux (beta 6)**, x86_64: the same Cone Player as the Windows 1.5.0 release, built for Linux. It is experimental: based on the development version of VLC media player (VLC 4).

> **Beta:** checked automatically in a Linux environment on GitHub (with dummy audio and software video). Real sound output and GPU video decoding have not been tested on real Linux hardware yet. Please report what works and what doesn't in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues). Windows users: get [Cone Player 1.5.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.5.0).

**Fixed on Linux:**
- **A file you open right after quitting plays.** Quitting hides Cone Player at once while it finishes in the background; a video double-clicked in that moment used to be handed to the closing Cone Player and lost. It now opens in a new window. Opening a file while Cone Player runs normally still plays it in the same window.

**New and fixed, as on Windows:**
- **Choose what happens when an episode ends:** play the next episode, show Up Next and wait for your click, or do nothing (Settings > Playback > Episodes).
- **OpenSubtitles: tick one result or several,** the best match in your language, and clean names such as "Sintel (2010) [English]".
- **Quitting is instant,** notices no longer cover each other, Up Next no longer skips finished episodes, and stopping an episode keeps the show's subtitles.
- **YouTube links play** with your own yt-dlp: no still image, the quality setting respected, **without sound for now** (a VLC core limit; sound comes in a later release).
- The album cover stays square, thumbnails show in Recent and Videos at once, Recent lists the latest first, and the custom accent color shows a color wheel.

**Downloads:**
- **AppImage**: download, `chmod +x` it, start it. AppImageLauncher or Gear Lever add it to the menu with its icon. A folder named `portable` next to it keeps settings and library there.
- **Portable tarball**: unpack, start `./cone`, or run `./install.sh` to install it for your user (no sudo; menu entry, icons, "Open with"). `README-LINUX.txt` inside explains the rest.
- **Debian / Ubuntu package** (amd64): `sudo apt install ./cone-player_1.5.0-beta6_amd64.deb`. Installs into `/opt/cone-player` with the command `cone-player`, next to VLC without replacing it; remove it with `sudo apt remove cone-player`.
- Needs a 64-bit Linux desktop (X11 or Wayland) with glibc 2.35 or newer: Ubuntu 22.04, Linux Mint 21, Debian 12, Fedora 36 or newer.
- Cone keeps its own settings (`~/.config/Cone`, `~/.local/share/Cone`, `~/.cache/Cone`) and runs next to an installed VLC.
- Checked on GitHub before release: H.264 and HEVC playback with subtitles, the video inside Cone's window on Wayland and X11, seeking, Settings, the menu, quitting, a file opened right after quitting, the Up Next card's Next episode, opening a file in the running window, and installing and removing the tarball and the package.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.

SHA-256: (written by release-linux)

---

## 3. Cone Player 1.5.0 for macOS (preview)

**Cone Player 1.5.0 for macOS (preview)**: Cone Player for **Apple Silicon** (M1 and later) and **Intel** Macs, macOS 12 or later. It's a preview for testers, not a finished release. Windows users: get [Cone Player 1.5.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.5.0).

**Fixed on macOS:**
- **Double-clicking a file in Finder while Cone Player is closed plays it.** The same for Open With > Cone Player: Cone Player starts and plays the file in its window. This was the known issue of 1.4.0 (issue #69).
- **The album cover stays square** in the music player at every window size (issue #69).

It also has everything new in Cone Player 1.5.0 for Windows: the choice of what happens when an episode ends, several OpenSubtitles results at once with clean names, instant quitting, and YouTube links (without sound for now, a VLC core limit).

**Which file:** `Cone-1.5.0-macos-arm64.dmg` for Apple Silicon, `Cone-1.5.0-macos-x86_64.dmg` for Intel Macs.

**Install (the app is not signed by Apple):**
1. Open the `.dmg` and drag **Cone Player** onto **Applications**.
2. The app has no Apple Developer ID and isn't notarized, so macOS blocks the first start. Right-click **Cone Player** in Applications and choose **Open**, then **Open** again.
   - On macOS 15 (Sequoia) and later, if the warning only offers **Done** or **Move to Trash**: click **Done**, then go to **System Settings > Privacy & Security**, find "Cone Player was blocked" and click **Open Anyway**.
   - Or in Terminal: `xattr -dr com.apple.quarantine "/Applications/Cone Player.app"`
3. Each new version may ask again for folder access, because its signature changes.

**Tips:**
- Drag a video onto the window or the Dock icon to play it; Cmd+P opens Settings, Cmd+Q quits.
- If a playlist's songs on the Desktop won't play: System Settings > Privacy & Security > Files and Folders > Cone Player > Desktop Folder.

> **Testers wanted (about 10 minutes).** It hasn't been confirmed on a real Mac yet. Please tell us in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues) your Mac model and macOS version, and for each step "works" or what happened (a screenshot helps):
> 1. **Finder, Cone closed:** quit Cone Player, then double-click a video in Finder: Cone Player starts and plays it.
> 2. **Finder, Cone open:** with a video playing, open another one with Open With > Cone Player or drop it on the Dock icon: it plays in the same window.
> 3. **The picture:** play a 16:9 video in a window taller than the video: the whole picture with black bands. Resize, go fullscreen and back: the picture follows.
> 4. **The music player:** play an album with a cover and resize the window: the cover stays square.
> 5. **The basics:** pause, seek, volume, fullscreen (button, F, Escape), subtitles from an .srt of the same name, Cmd+P for Settings, Cmd+Q quits.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.
