<!--
DRAFT, not published. Everything above the line "Release text" is for StickyGonzales and the PC
session only and is not part of the release. The release title (Decision 68 with the 1.0 name,
RENAME_CONE_PLAYER.md R6) is:

    Cone Player 1.0.0: Juxtopposed's redesign on a real VLC 4 fork, not a skin
-->

# Release 1.0.0: draft notes

## Before publishing (not part of the release text)

- [ ] PR #33 (installer) and PR #46 (Cone Player rename, Decision 73) merged into `wip/next-test`, tested together on Windows (test build: `wip/test-installer-1.0`, run #102; Wine results in `redesign/INSTALLER_TEST_1.0.md`; Windows steps in `redesign/INSTALLER_NOTES.md` section 6 and `redesign/RENAME_CONE_PLAYER.md` section 6), then merged into `redesign`.
- [ ] wip/ci-release updated for the new names (release title, `coneplayer-*` / `ConePlayer-*` patterns in `release-package.sh`; RENAME_CONE_PLAYER.md section 7) and merged, so the release workflow attaches both files and their checksums.
- [ ] Smoke, screens and quit checks on the build from the `v1.0.0` tag.
- [ ] Known issues below rechecked on that build: drop any that are fixed (the background error after closing Settings is carried over from 0.2.0 unchecked), add any new ones.
- [ ] README from `wip/readme-1.0` merged (download links point to the `v1.0.0` release).
- [ ] Not a pre-release this time (it leaves beta); the commit in the license line filled in.

---

## Release text

# Cone Player 1.0.0: Juxtopposed's redesign on a real VLC 4 fork, not a skin

**Cone Player 1.0.0** is the first full release of Cone Player, a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface. It was called **Cone** during the betas.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Each comes with a `.sha256` checksum file.

**Installer (recommended): `coneplayer-1.0.0-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`, with a Start menu entry and, if you tick it, a desktop shortcut.
3. To open your videos with Cone Player by default: right click a file, **Open with**, **Choose another app**, **Cone Player**, **Always**. Or use Settings > Apps > Default apps > Cone Player. The installer lists Cone Player for VLC's video, audio and playlist types, but never takes a file type away from another player.

Uninstall it from Settings > Apps like any app. It asks before deleting your settings.

**Portable zip: `ConePlayer-1.0.0-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.0.0` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. SmartScreen may warn the same way: **More info**, **Run anyway**.

## New since 0.2.0 beta

- **A new name: Cone Player.** The window, About, the tray, Settings > Apps and the installer all say Cone Player. Menus and messages keep the short name "Cone" ("About Cone", "Quit Cone").
- **An installer** that sets Cone Player up like a normal Windows app:
  - Start menu, optional desktop shortcut, an entry in Settings > Apps with its size and an uninstaller;
  - Cone Player listed in Open with and Default apps for the same file types as VLC, plus "Play with Cone Player" and "Add to Cone Player's Playlist" on files and folders, and AutoPlay for discs;
  - an installed VLC keeps its default apps and settings, and both run side by side.
- **Default subtitles look like the design:** system sans-serif font, a size relative to the video and VLC's normal outline.
- **"Ignore styling in ASS and SSA subtitles"** (Settings > Subtitles > Advanced Options) draws styled anime and fansub dialogue in your own subtitle style. Signs and positioned text keep their place. It takes effect after a restart.
- **The settings sidebar's tabs cross-fade** as in the video. With Windows' animation effects turned off, they switch at once.
- **Open Network Stream:** a playlist link (for example an `.m3u` file) fills in the playlist name, and **Save** keeps it as a playlist under Network.

## Fixed since 0.2.0 beta

- With an audio visualizer on (for example Spectrometer), switching the audio track no longer turns the visualizer window white on HEVC (x265) videos.
- Picking the Spectrometer visualizer could, rarely, crash Cone.
- Quitting after a long session on HEVC videos gets stuck far less often. A quit that still gets stuck ends by itself after 5 seconds, with your settings and resume position saved.
- In Settings, the Advanced Options bar at the bottom of a page was cut off, and a click on its lower edge closed Settings.
- The New Playlist dialog listed a library file as "Library item" instead of its name.

## Known issues

- On a few HEVC files with many B-frames, switching the audio track can still stall the video, and quitting can then take 5 seconds before Cone Player ends itself. Settings and the resume position are kept.
- Pressing M (mute) shows only the mute icon, without "Pressed M".
- Rarely, Windows may log a background error after closing Settings; nothing visible happens.
- New Cone Player texts are in English in every language for now.
- The portable zip doesn't show up in Windows' "Open with" menu. Use the installer for that, or drag files onto Cone Player.
- Like VLC, Cone Player keeps a small graphics cache in `%LOCALAPPDATA%\Cone\cache`, also when run from the zip.
- Windows only for now. A Linux build follows as its own release.

## Cone extras (not part of Juxtopposed's design)

Cone extras are features Cone Player adds beyond Juxtopposed's design (in neither her video nor her Figma file). None is in 1.0.

- **Autoplay next episode ("Up Next")** comes in **1.1**. When an episode of a show folder ends, an "Up next" card counts down to the next one. It can be set to Off, Ask for each show, or Always in Settings > Playback.

## Credits and license

- Design: "VLC Redesign" by **Juxtopposed**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): [Figma file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and [video](https://youtu.be/ERFeOgqk324). Changes were made to fit it to VLC.
- Engine: [VLC media player](https://www.videolan.org/vlc/) by VideoLAN and its contributors.
- Fonts: Inter and DM Mono, SIL Open Font License.
- Built by [StickyGonzales](https://github.com/StickyGonzales).
- License: Cone Player is free software under the GNU GPL, version 2 or later. The libVLC engine is under the GNU LGPL, version 2.1 or later. Source code: this repository, commit [`<commit>`](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/tree/<commit>).

Cone Player is not affiliated with or endorsed by VideoLAN or Juxtopposed. VLC, VLC media player and VideoLAN are trademarks of the VideoLAN non-profit organization.
