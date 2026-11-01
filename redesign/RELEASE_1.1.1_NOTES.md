# Release 1.1.1: release text

Published as the body of the GitHub release v1.1.1 (title "Cone Player 1.1.1"). The commit is filled in when the tag is pushed.

## Release text

**Cone Player 1.1.1** is a bug fix update of Cone Player 1.1. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## Fixed in 1.1.1

- **SRT streams, game music files and converting to HEVC (x265) work.** Four of the player's plug-ins (SRT input and output, the game-music player and the x265 encoder used by Convert / Stream) could not start, because two small Windows runtime files were missing from the download. They are included now. Playing HEVC videos was never affected.
- **No "restore the playlist?" question after a slow close.** When Cone Player needed a few extra seconds to close, the next start asked whether to restore the playlist as if it had crashed. It only asks after a real crash now.
- **In fullscreen the top bar stays** while the mouse is on its buttons (the logo and the "..." menu), instead of hiding as soon as the mouse reaches it.
- **Customize Player:** minimize, maximize, close and the logo no longer look movable (they have no dashed outline), and when Fullscreen is dragged out of the top bar the gap closes at once.

## Changed in 1.1.1

- **The installer** opens on the recommended setup and skips the components page unless you tick "Customize the installation". A "Create a desktop shortcut" box sits on the welcome page.

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.1.1-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have 1.0.x or 1.1.0 installed? The installer upgrades it in place and keeps your settings and library.

**Portable zip: `ConePlayer-1.1.1-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.1.1` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Known issues

- Dragging the playback speed slider quickly on some HEVC (x265) films can freeze Cone Player; it then has to be ended in Task Manager. Change the speed in steps (the - and = keys) on those films until this is fixed.

- On a few HEVC files with many B-frames, switching the audio track can still stall the video, and quitting can then take 5 seconds before Cone Player ends itself. Settings and the resume position are kept.
- Closing Cone Player sometimes takes up to 5 seconds after its window disappears, until it ends itself. Settings and the resume position are kept.
- Pressing M (mute) shows only the mute icon, without "Pressed M".
- The Subtitle Duration Factor slider is still hidden: in this VLC 4 engine it made ASS / SSA subtitles disappear.
- New Cone Player texts are in English in every language for now.
- The portable zip doesn't show up in Windows' "Open with" menu. Use the installer for that, or drag files onto Cone Player.
- A Linux build follows as its own beta release.

## Credits and license

- Design: "VLC Redesign" by **Juxtopposed**, [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/): [Figma file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and [video](https://youtu.be/ERFeOgqk324). Changes were made to fit it to VLC.
- Engine: [VLC media player](https://www.videolan.org/vlc/) by VideoLAN and its contributors.
- Fonts: Inter and DM Mono, SIL Open Font License.
- Built by [StickyGonzales](https://github.com/StickyGonzales).
- License: Cone Player is free software under the GNU GPL, version 2 or later. The libVLC engine is under the GNU LGPL, version 2.1 or later. Source code: this repository, commit [`<commit>`](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/tree/<commit>).

Cone Player is not affiliated with or endorsed by VideoLAN or Juxtopposed. VLC, VLC media player and VideoLAN are trademarks of the VideoLAN non-profit organization.
