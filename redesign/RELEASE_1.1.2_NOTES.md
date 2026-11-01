# Release 1.1.2: release text

Published as the body of the GitHub release v1.1.2 (title "Cone Player 1.1.2"). The commit is filled in when the tag is pushed.

## Release text

**Cone Player 1.1.2** is a bug fix update of Cone Player 1.1. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface. A Linux beta of the same version comes as its own release.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## Fixed in 1.1.2

- **The "..." menu opens in fullscreen.** In fullscreen, a click on "..." in the top bar did nothing: a hidden part of the window took the click. It opens the main menu now.
- **Pressing M names the key** like every other shortcut: the message reads "Muted" with "Pressed M".
- **No "Looks like a show" question for short clips.** Files too short to autoplay as episodes no longer ask whether to play episodes in a row.
- **Screen readers read short values** on the video filter sliders (for example Brightness 1.05 instead of 1.0499999523162842).
- **`Cone.exe --version` and `--help` print into the terminal** they were typed in (Command Prompt, PowerShell, Windows Terminal), instead of nothing.

Also since 1.1.0 (in 1.1.1): SRT streams, game music files and converting to HEVC work; no "restore the playlist?" question after a slow close; the fullscreen top bar stays while the mouse is on its buttons; Customize Player shows only movable items as movable; the installer opens on the recommended setup with a desktop shortcut box.
## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.1.2-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have an earlier Cone Player installed? The installer upgrades it in place and keeps your settings and library.

**Portable zip: `ConePlayer-1.1.2-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.1.2` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Known issues

- Dragging the playback speed slider quickly on some HEVC (x265) films can freeze Cone Player; it then has to be ended in Task Manager. Change the speed in steps (the - and = keys) on those films until this is fixed.

- On a few HEVC files with many B-frames, switching the audio track can still stall the video, and quitting can then take 5 seconds before Cone Player ends itself. Settings and the resume position are kept.
- Closing Cone Player sometimes takes up to 5 seconds after its window disappears, until it ends itself. Settings and the resume position are kept.
- The Subtitle Duration Factor slider is still hidden: in this VLC 4 engine it made ASS / SSA subtitles disappear.
- New Cone Player texts are in English in every language for now.
- Upgrading with the installer adds the desktop shortcut again, also if you deleted it. Delete it once more after the upgrade; this will be fixed.
- The portable zip doesn't show up in Windows' "Open with" menu. Use the installer for that, or drag files onto Cone Player.
- The Linux version is a beta with its own release (see the README).

## Credits and license

- Design: "VLC Redesign" by **Juxtopposed**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): [Figma file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and [video](https://youtu.be/ERFeOgqk324). Changes were made to fit it to VLC.
- Engine: [VLC media player](https://www.videolan.org/vlc/) by VideoLAN and its contributors.
- Fonts: Inter and DM Mono, SIL Open Font License.
- Built by [StickyGonzales](https://github.com/StickyGonzales).
- License: Cone Player is free software under the GNU GPL, version 2 or later. The libVLC engine is under the GNU LGPL, version 2.1 or later. Source code: this repository, commit [`<commit>`](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/tree/<commit>).

Cone Player is not affiliated with or endorsed by VideoLAN or Juxtopposed. VLC, VLC media player and VideoLAN are trademarks of the VideoLAN non-profit organization.
