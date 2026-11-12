# Release 1.4.0: release texts (ready to paste)

Three texts. Each one is the body of its GitHub release:

| Release | Tag | Title | Settings |
|---|---|---|---|
| Windows | `v1.4.0` (on `redesign`) | Cone Player 1.4.0 | full release, set as Latest |
| Linux | `linux-v1.4.0-beta5` (on `redesign`) | Cone Player 1.4.0 for Linux (beta 5) | pre-release, not Latest |
| macOS | `macos-v1.4.0` (the draft release-macos makes) | Cone Player 1.4.0 for macOS (preview) | pre-release, not Latest |

Fill in when publishing: `<commit>` (the tagged commit) and the Linux and macOS checksums.
The fixes list leads with the settings fix (StickyGonzales, 2026-11-11).

---

## 1. Cone Player 1.4.0 (Windows)

**Cone Player 1.4.0** stops updates from deleting your settings, adds seeking with the mouse wheel, and fixes the update notice, show names, Ctrl+Q and the pointer. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface. Linux and macOS versions of 1.4.0 come as their own releases.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## Fixed and new

### Your settings
- **Updating no longer deletes your settings.** The installer has an option "Delete preferences and cache", unticked by default. Earlier installers remembered it: if it had been ticked once, every later update deleted Cone Player's settings again, so the first-start screens came back and the OpenSubtitles API key, accent color, shows and library choices were gone. **If that happened to you with the 1.3.0 update, it won't happen again:** from 1.4.0 the option starts unticked on every install, and an update keeps your settings unless you tick it yourself. Lost settings can't be brought back, so please enter your OpenSubtitles API key once more.
- **The OpenSubtitles account is saved as you type** (Settings > Subtitles > OpenSubtitles): the API key, username and password are on disk the moment you type them, even if Cone Player closes while Settings is open.

### Playing
- **Seek with the mouse wheel.** With the pointer on the timeline, each wheel notch jumps 10 seconds, forward when you scroll up, back when you scroll down. A touchpad's scrolling adds up the same way. Elsewhere on the control bar the wheel still does nothing, and over the video it still changes the volume.
- **Volume without the bars when maximized.** When Cone Player is maximized or fullscreen ("movie mode"), the Up / Down keys and the mouse wheel over the video change the volume and show only the volume message; the top bar and the control bar stay hidden. In a normal window they show as before, and Ctrl+Up / Ctrl+Down still show them.
- **The pointer hides again about 3 seconds after Space resumes playback** (it took about 6 seconds). With pinned bars (Settings > Interface), the pointer now stays after a key press too, as it does after a mouse move.
- **Ctrl+Q always quits,** the same way as the window's close button: playback stops first, then Cone Player closes, which can take up to about 3 seconds. Before, right after Settings had been closed, Ctrl+Q could leave Cone Player running.

### Up Next and shows
- **Clean show names.** A show in a folder named like a download ("Some.Show.S01.1080p.WEBRip.x265-GROUP", "Doctor.Who.2005.1080p.BluRay") is now called "Some Show" or "Doctor Who" on the Up Next card and in the sidebar's Playback tab, instead of the whole folder name. Words like "Season" are only removed before a number, so a show called "Season of the Witch" keeps its name. Your answers for shows you already set up (autoplay, Fixed time, tracks) are kept: they belong to the folder, not to the name.

### Update notice
- **The update notice works again.** Cone Player checks GitHub for a new version on its own, a few seconds after it starts. Only a real answer from GitHub counts: if you're offline at first, it tries again after 6 seconds, 30 seconds and 90 seconds, and on the next start. It checks at most every 6 hours, so a new release shows the same day. Pressing **Check now** (Settings > General) while it is still retrying keeps those retries going.

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.4.0-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have an earlier Cone Player installed? The installer upgrades it in place and keeps your settings and library (leave "Delete preferences and cache" unticked).

**Portable zip: `ConePlayer-1.4.0-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.4.0` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Tips

- **Updating:** run the new installer and keep **"Upgrade using previous settings"**: your settings, library and shows stay. Only choose the advanced option and tick "Delete preferences and cache" if you want a clean start.
- **Jumping around:** the mouse wheel on the timeline moves 10 seconds per notch. On the keyboard: Alt+Left / Right 10 seconds, Ctrl+Left / Right 1 minute, Ctrl+Alt+Left / Right 5 minutes.
- **Movie mode:** maximize the window or press F for fullscreen, and change the volume with Up / Down or the mouse wheel without bringing up the bars.
- **Up Next at the wrong moment?** Sidebar > Playback > "Up Next for <your show>": switch to **Fixed** and type how long before the end the card should show (for example 1:30). **Reset** goes back to Automatic.
- **Subtitles out of sync?** Sidebar > Subtitles > Synchronization > **Auto-sync**; **Undo** puts them back.
- **OpenSubtitles:** a free account on opensubtitles.com gives you an API key (your profile > API consumers). Paste it in Settings > Subtitles > OpenSubtitles.
- **A different color:** Settings > General > Accent color > **Custom** takes any hex code.
## Known issues

- On a few HEVC files with many B-frames, switching the audio track can still stall the video, and quitting can then take 5 seconds before Cone Player ends itself. Settings and the resume position are kept.
- Closing Cone Player sometimes takes up to 5 seconds after its window disappears, until it ends itself. Settings and the resume position are kept.
- Clean show names drop a year at the end of a name: a folder "Class.of.2009" shows as "Class of".
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

## 2. Cone Player 1.4.0 for Linux (beta 5)

**Cone Player 1.4.0 for Linux (beta 5)**, x86_64: the same Cone Player as the Windows 1.4.0 release, built for Linux. It is experimental: based on the development version of VLC media player (VLC 4).

> **Beta:** checked automatically in a Linux environment on GitHub (with dummy audio and software video). Real sound output and GPU video decoding have not been tested on real Linux hardware yet. Please report what works and what doesn't in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues). Windows users: get [Cone Player 1.4.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.4.0).

**Fixed on Linux:**
- **On Wayland the video plays inside Cone Player's window again, and fullscreen has its bars (issue #116).** In 1.3.0 beta 4 on Wayland desktops it opened in a separate window with no controls; X11 was not affected. Every Linux build now checks this on Wayland and on X11.

**New and fixed, as on Windows:**
- **Seek with the mouse wheel** on the timeline: 10 seconds per notch.
- **Volume without the bars when maximized:** the Up / Down keys and the mouse wheel over the video change only the volume.
- **The OpenSubtitles account is saved as you type.**
- **The update notice works again,** with retries when you're offline at first.
- **Clean show names:** "Some.Show.S01.1080p.WEBRip.x265-GROUP" shows as "Some Show" (a year at the end of a name is dropped: "Class.of.2009" shows as "Class of").
- **Ctrl+Q always quits** (playback stops first, then Cone Player closes), and **the pointer hides about 3 seconds after Space resumes playback**; with pinned bars it stays after a key press.

**Under the hood:**
- The Linux packages are built on Ubuntu 22.04 again after the build image broke (it now gets its packages from the runner's own Ubuntu mirror and stops loudly if a package is missing), and every build checks on Wayland and X11 that the video plays inside Cone's window.
- **Flatpak and AUR packages are prepared but not published yet:** a Flatpak build (io.github.StickyGonzales.ConePlayer) runs and plays in the sandbox on GitHub, and an AUR package (cone-player-bin) is ready. They come with a later release.

**Tips:**
- On Wayland, check that the video now plays inside the window; if it doesn't, please tell us your desktop (GNOME, KDE, ...) and distribution in Issues.
- The mouse wheel on the timeline jumps 10 seconds per notch; Up / Down or the wheel over the video change the volume without the bars when maximized or fullscreen.

**Downloads:**
- **AppImage**: download, `chmod +x` it, start it. AppImageLauncher or Gear Lever add it to the menu with its icon. A folder named `portable` next to it keeps settings and library there.
- **Portable tarball**: unpack, start `./cone`, or run `./install.sh` to install it for your user (no sudo; menu entry, icons, "Open with"). `README-LINUX.txt` inside explains the rest.
- **Debian / Ubuntu package** (amd64): `sudo apt install ./cone-player_1.4.0-beta5_amd64.deb`. Installs into `/opt/cone-player` with the command `cone-player`, next to VLC without replacing it; remove it with `sudo apt remove cone-player`.
- Needs a 64-bit Linux desktop (X11 or Wayland) with glibc 2.35 or newer: Ubuntu 22.04, Linux Mint 21, Debian 12, Fedora 36 or newer.
- On older systems, sound goes through PulseAudio (or PipeWire's PulseAudio service), and very new formats such as VVC aren't supported.
- Cone keeps its own settings (`~/.config/Cone`, `~/.local/share/Cone`, `~/.cache/Cone`) and runs next to an installed VLC.
- Checked on GitHub before release: H.264 and HEVC playback with subtitles, the video inside Cone's window on Wayland and X11, seeking, Settings, the menu, quitting, the Up Next card's Next episode, opening a file in the running window, and installing and removing the tarball and the package.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.

SHA-256: (written by release-linux)

---

## 3. Cone Player 1.4.0 for macOS (preview)

**Cone Player 1.4.0 for macOS (preview)**: Cone Player for **Apple Silicon** (M1 and later) and **Intel** Macs, macOS 12 or later. It's a preview for testers, not a finished release. Windows users: get [Cone Player 1.4.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.4.0).

**Fixed on macOS** (from a tester's report, issue #69):
- **The picture is drawn correctly.** The video area was see-through or only partly drawn, and after the first file often black. It now shows the whole picture with black bands, and the desktop no longer shows through.
- **Opening files from Finder while Cone Player runs:** a double-click, Open With > Cone Player or a drop on the Dock icon plays the file in the open window; several files go into the queue. Cone Player is now listed under Open With for video, audio and playlist files, without becoming your default player.
- **Mac key symbols on the first start's shortcuts page** (âŒƒ âŒ¥ â‡§ âŒ˜), and the page fits its window.
- **Desktop access for playlists:** a playlist with songs on the Desktop, in Documents or Downloads now makes macOS ask for access, instead of failing. If you refused once: System Settings > Privacy & Security > Files and Folders > Cone Player > Desktop Folder.

It also has everything new in Cone Player 1.4.0 for Windows (wheel seeking, clean show names, the update check, Ctrl+Q / Cmd+Q, the pointer).

**Which file:** `Cone-1.4.0-macos-arm64.dmg` for Apple Silicon, `Cone-1.4.0-macos-x86_64.dmg` for Intel Macs.

**Install (the app is not signed by Apple):**
1. Open the `.dmg` and drag **Cone Player** onto **Applications**.
2. The app has no Apple Developer ID and isn't notarized, so macOS blocks the first start. Right-click **Cone Player** in Applications and choose **Open**, then **Open** again.
   - On macOS 15 (Sequoia) and later, if the warning only offers **Done** or **Move to Trash**: click **Done**, then go to **System Settings > Privacy & Security**, find "Cone Player was blocked" and click **Open Anyway**.
   - Or in Terminal: `xattr -dr com.apple.quarantine "/Applications/Cone Player.app"`
3. Each new version may ask again for folder access, because its signature changes.

**Tips:**
- Drag a video onto the window or the Dock icon to play it; Cmd+P opens Settings, Cmd+Q quits.
- If a playlist's songs on the Desktop won't play: System Settings > Privacy & Security > Files and Folders > Cone Player > Desktop Folder.

**Known issue:** double-clicking a file in Finder while Cone Player is closed opens Cone without playing the file; open it again or drag it onto the window. Opening files while Cone is already running works.

> **Testers wanted (about 10 minutes).** It hasn't been confirmed on a real Mac yet. Please tell us in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues) your Mac model and macOS version, and for each step "works" or what happened (a screenshot helps):
> 1. **The picture:** play a 16:9 video in a window taller than the video, then a second video: the whole picture with black bands, nothing showing through. Resize, go fullscreen and back: the picture follows.
> 2. **Finder, Cone open:** with a video playing, open another one with Open With > Cone Player or drop it on the Dock icon: it plays in the same window. Three files at once: all in the queue, the first plays.
> 3. **The shortcuts page:** start Cone once with `open -a "Cone Player" --args --qt-privacy-ask` and go to "Learn the basic keyboard shortcuts": every key cap fits, the modifiers show as âŒƒ âŒ¥ â‡§ âŒ˜, and Show / Hide Queue reads âŒ˜ L.
> 4. **A playlist with songs on the Desktop:** open it: macOS asks for Desktop access; after Allow, the songs play.
> 5. **The basics:** pause, seek, volume, fullscreen (button, F, Escape), subtitles from an .srt of the same name, Cmd+P for Settings, Cmd+Q quits.

Design by Juxtopposed (CC BY 4.0), built by StickyGonzales. Not affiliated with VideoLAN.
