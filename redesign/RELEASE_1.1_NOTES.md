# Release 1.1.0: release text

Published as the body of the GitHub release v1.1.0 (title "Cone Player 1.1.0"). The commit is filled in when the tag is pushed.

## Release text

**Cone Player 1.1.0** brings autoplay for shows, an update notice and a portable zip that keeps its settings with it. Cone Player is a media player for Windows based on VLC media player, with Juxtopposed's "VLC Redesign" as its interface.

> Cone Player follows the development branch of VLC 4, so a rough edge may still show up now and then. It runs next to an installed VLC with its own settings and data folder and never changes VLC's. Please report problems in [Issues](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).

## New in 1.1

- **Update notice.** Once a day Cone Player asks GitHub for the latest release and shows a small notice when a newer one is out, with **Download** (opens the release page) and **Later**. Settings > General has "Check for updates" (on by default) and **Check Now**. It sends nothing but that one request, and nothing at all when switched off.
- **The portable zip keeps its settings in its own folder** again: the `portable` folder next to `Cone.exe`, as in the betas, so the zip never mixes its settings with an installed Cone Player. Coming from the 1.0 zip? Delete the new zip's `portable` folder before the first start to keep using your settings in `%APPDATA%\Cone`.
- **Password and key fields** (the OpenSubtitles API key in Settings > Subtitles) have an eye button to show the key, and say "Saved" once it is stored.

## Fixed

- A file double-clicked while Cone Player is still closing now opens in a new window instead of being lost.
- In fullscreen, the control bar no longer hides while the settings sidebar (or the queue) is open and the mouse is over it.
- Since 1.0.0: the seek bar preview shows the right picture on files with few keyframes (1.0.2), and dragging the seek bar no longer flickers (1.0.1).

## Cone extras (not part of Juxtopposed's design)

Cone extras are features Cone Player adds beyond Juxtopposed's design (in neither her video nor her Figma file).

- **Autoplay next episode ("Up Next").** Open an episode of a show folder (names like `S01E01`, `1x01` or `Episode 1`) and Cone Player asks once: "Looks like a show. Play episodes in a row?" Say yes, and near the end of each episode an Up Next card counts down to the next one, with **Play now** and **Cancel**. Settings > Playback > Episodes: Off, Ask for each show (the default) or Always, the countdown length, when the card shows, and "Ask if I'm still watching after 3 episodes". Single videos, clips, music and movies never trigger it.

## Download

Two downloads, both for Windows 10 / 11, 64-bit. Their checksums are in `SHA256SUMS.txt`.

**Installer (recommended): `coneplayer-1.1.0-win64.exe`**
1. Run it. The files are not code-signed yet, so Windows SmartScreen may warn: choose **More info**, then **Run anyway**.
2. Follow the pages. Cone Player installs to `C:\Program Files\Cone`. Already have 1.0.x installed? The installer upgrades it in place and keeps your settings and library.

**Portable zip: `ConePlayer-1.1.0-win64.zip`**
1. Unzip it anywhere and run `Cone.exe` in the `ConePlayer-1.1.0` folder. Nothing gets installed.
2. Settings stay in the `portable` folder next to `Cone.exe`. Delete that folder to use `%APPDATA%\Cone` instead (shared with an installed Cone Player).

## Known issues

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
