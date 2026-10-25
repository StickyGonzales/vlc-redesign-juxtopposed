# Cone Player

**Juxtopposed's redesign on a real VLC 4 fork, not a skin.** Cone Player is VLC media player with her whole redesign on top: new player, sidebars, library, settings and onboarding. Same VLC engine underneath, under its own name so it can sit next to your regular VLC. (During the betas it was called Cone.)

![Cone Player: the library with the mini player (Figma design by Juxtopposed)](docs/images/hero.png)

<sub>This image is a frame of Juxtopposed's Figma design, which Cone Player implements. Screenshots of the app itself are below.</sub>

## Download

**[Cone Player 1.0.0](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.0.0)** for Windows 10 / 11, 64-bit. Pick one of the two downloads:

- **Installer (recommended): `coneplayer-1.0.0-win64.exe`.** Run it and follow the pages. Cone Player gets a Start menu entry, an optional desktop shortcut, an entry in Settings > Apps with an uninstaller, and shows up in "Open with" and Default apps for your videos and music. It never takes a file type away from VLC or another player: you choose.
- **Portable zip: `ConePlayer-1.0.0-win64.zip`.** Unzip it anywhere and run `Cone.exe`. Nothing gets installed; settings stay in the `portable` folder next to it.

The files are not code-signed yet, so Windows SmartScreen may warn the first time: choose **More info**, then **Run anyway**.

**Coming from a beta zip?** Copy its `portable` folder next to the new `Cone.exe` to keep your settings. The installed app keeps its own settings in `%APPDATA%\Cone`, so moving from the zip to the installer starts fresh. Your installed VLC isn't touched either way, and both run side by side.

Found a bug? Open an [issue](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues). **Linux:** a build follows as its own release.

## What's in it

- The redesigned player: floating control bar and top bar, seek bar with thumbnails and a subtitle timeline, cone volume up to 200 %, tracks popup with embedded and external tracks
- A settings sidebar (Playback, Video, Audio, Subtitles) with per-show presets, sleep timer, speed and subtitle sync sliders
- Queue, bookmarks (Ctrl+B) and chapters, the new main and right-click menus, Keyboard Shortcuts and the new Settings
- A library with Home, Videos, Music, Playlists, Network and Recent, a music view and a mini player
- Customize Player and profiles, onboarding, dark and light themes, 9 accent colors
- On-screen messages that name the key you pressed, and subtitles that move above the control bar while it shows
- Its own settings folder, its own entry in the Windows volume mixer and its own single-instance name, so it never takes over an installed VLC

## New in 1.0.0

- The new name, **Cone Player**, and an **installer** that sets it up like any Windows app, side by side with VLC
- Default subtitles in the design's look, and an option to show styled ASS / SSA dialogue in your own subtitle style
- The settings sidebar's tabs cross-fade as in the video
- Fixed: the white audio visualizer window after an audio track switch, a rare crash when picking Spectrometer, slow quits on HEVC videos, and the cut-off Advanced Options bar in Settings

Full list: [release notes](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.0.0). Earlier: [0.2.0 beta](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v0.2.0-beta).

## Known issues (1.0.0)

- On a few HEVC files with many B-frames, switching the audio track can still stall the video, and quitting can then take 5 seconds before Cone Player ends itself. Settings and the resume position are kept.
- Pressing M (mute) shows only the mute icon, without "Pressed M".
- New Cone Player texts are in English in every language for now.
- The portable zip doesn't show up in Windows' "Open with" menu: use the installer for that, or drag files onto Cone Player.
- Like VLC, Cone Player keeps a small graphics cache in `%LOCALAPPDATA%\Cone\cache`, also when run from the zip.

## Screenshots

Cone 0.1.0 beta on Windows, with generated test media and the purple accent.

| | |
|---|---|
| **Player**<br><img src="docs/images/cone-player.png" alt="Cone Player: the player"> | **Settings sidebar**<br><img src="docs/images/cone-settings-sidebar.png" alt="Cone Player: the settings sidebar"> |
| **Library and mini player**<br><img src="docs/images/cone-library.png" alt="Cone Player: the library and mini player"> | **Settings**<br><img src="docs/images/cone-settings.png" alt="Cone Player: Settings"> |

### The design being built

Juxtopposed's Figma frames, the source for every size, color and spacing in Cone Player.

| | |
|---|---|
| **Player**<br><img src="docs/images/figma-player.png" alt="Player"> | **Home**<br><img src="docs/images/figma-home.png" alt="Home"> |
| **Library and mini player**<br><img src="docs/images/figma-library.png" alt="Library and mini player"> | **Compact library**<br><img src="docs/images/figma-sidebar.png" alt="Compact library"> |
| **Settings**<br><img src="docs/images/figma-settings.png" alt="Settings"> | **Customize Player**<br><img src="docs/images/figma-customize.png" alt="Customize Player"> |
| **Onboarding**<br><img src="docs/images/figma-onboarding.png" alt="Onboarding"> | **Keyboard Shortcuts**<br><img src="docs/images/figma-shortcuts.png" alt="Keyboard Shortcuts"> |
| **Light theme**<br><img src="docs/images/figma-light.png" alt="Light theme"> | |

## Cone extras (not part of Juxtopposed's design)

Features Cone Player adds beyond Juxtopposed's design (in neither her video nor her Figma file) are listed here, each marked as a Cone extra. None is in 1.0: each is built on its own branch and arrives after 1.0, starting with 1.1.

| Cone extra | Status | What it does |
|---|---|---|
| Autoplay next episode ("Up Next") | Coming in 1.1 | When an episode of a show folder ends, an "Up next" card counts down to the next episode. Off / Ask for each show / Always in Settings > Playback; single videos, recordings, clips and music are never treated as shows. Plan and designs: [UP_NEXT_PLAN.md](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/blob/wip/up-next-plan/redesign/UP_NEXT_PLAN.md) (branch wip/up-next-plan) |

## FAQ

**Why "Cone Player" and not VLC?** "VLC" and the traffic cone icon are VideoLAN's trademarks, so this app has its own name and icon. Under the hood it's VLC.

**Does it change how media plays?** No. Playback, codecs and the engine are VLC's own; the work is in VLC's Qt interface, plus a few small, separate core changes where a feature needs them.

**Does it update itself?** No. New versions show up on the [Releases page](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases). Running a newer installer updates an installed Cone Player and keeps its settings.

**How do I remove it?** Settings > Apps > Cone Player > Uninstall. It asks before deleting your settings. For the zip, delete its folder.

**How do I build it?** Fork this repository, enable Actions and run the **build-windows** workflow with the brand set to `public`. It uses VideoLAN's own Windows toolchain image and build script.

## Credits

- **Design:** ["VLC Redesign" by Juxtopposed](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) ([video](https://youtu.be/ERFeOgqk324)), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Changes were made to fit it to VLC.
- **Based on [VLC media player](https://www.videolan.org/vlc/)** by VideoLAN and its contributors. Cone Player is GPLv2 or later like VLC (libVLC LGPLv2.1 or later), and all its source is here.
- **Fonts:** Inter and DM Mono, SIL Open Font License.
- **Built by [StickyGonzales](https://github.com/StickyGonzales)** with [Claude](https://claude.ai/code).

Cone Player is an independent project, not affiliated with or endorsed by VideoLAN or Juxtopposed. VLC, VLC media player and VideoLAN are trademarks of the VideoLAN non-profit. Details in [CREDITS.md](CREDITS.md).

---

# About VLC

*VideoLAN's original README follows.*

# VLC media player

**VLC** is a libre and open source **media player** and **multimedia engine**,
focused on **playing everything**, and **running everywhere**.

**VLC** can play most multimedia files, discs, streams, devices and is also able to
convert, encode, **stream** and manipulate streams into numerous formats.

VLC is used by many over the world, on numerous platforms, for very different use cases.

The **engine of VLC** can be embedded into 3rd party applications, and is called *libVLC*.

**VLC** is part of the [VideoLAN project](https://videolan.org) and
is developed and supported by a community of volunteers.

The VideoLAN project was started at the university [École Centrale Paris](https://www.centralesupelec.fr/) who
relicensed VLC under the GPLv2 license in February 2001. Since then, VLC has
been downloaded **billions** of times.

## License

**VLC** is released under the GPLv2 *(or later)* license.
*On some platforms, it is de facto GPLv3, because of the licenses of dependencies*.

**libVLC**, the engine is released under the LGPLv2 *(or later)* license. \
This allows embedding the engine in 3rd party applications, while letting them to be licensed under other licenses.

# Platforms

VLC is available for the following platforms:
- [Windows] *(from 7 and later, including UWP platforms and all versions of Windows 10)*
- [macOS] *(10.10 and later)*
- [GNU/Linux] and affiliated
- [BSD] and affiliated
- [Android] *(4.2 and later)*, including Android TV and Android Auto
- [iOS] *(9 and later)*, including AppleTV and iPadOS
- Haiku, OS/2 and a few others.

[Windows]: https://www.videolan.org/vlc/download-windows.html
[macOS]: https://www.videolan.org/vlc/download-macosx.html
[GNU/Linux]: https://www.videolan.org/vlc/#download
[BSD]: https://www.videolan.org/vlc/download-freebsd.html
[Android]: https://www.videolan.org/vlc/download-android.html
[iOS]: https://www.videolan.org/vlc/download-ios.html

Not all platforms receive the same amount of care, due to our limited resources.

**Nota Bene**: The [Android app](https://code.videolan.org/videolan/vlc-android/) and
the [iOS app](https://code.videolan.org/videolan/vlc-ios/) are located in different repositories
than the main one.

# Contributing & Community

**VLC** is maintained by a community of people, and VideoLAN is not paying any of them.\
The community is composed of developers, helpers, maintainers, designers and writers that want
this open source project to thrive.

The main development of VLC is done in the C language, but this repository also contains
plenty of C++, Obj-C, asm and Rust.

Other repositories linked to vlc are done in languages including Kotlin/Java [(Android)](https://code.videolan.org/videolan/vlc-android/),
Swift [(iOS)](https://code.videolan.org/videolan/vlc-ios/), and C# [(libVLCSharp)](https://code.videolan.org/videolan/libvlcsharp/).

We need help with the following tasks:
- Coding
- Packaging for Windows, macOS and Linux distributions
- Technical writing for the documentation
- Design
- Support
- Community management and communication.

Please contribute :)

We are on IRC. You can find us on the **#videolan** channel on *[Libera.chat]*.

[Libera.chat]: https://libera.chat

## Contributions

Contributions are now done through Merge Requests on our [GitLab repository](https://code.videolan.org/videolan/vlc/).

CI and discussions should be resolved before a Merge Request can be merged.

# libVLC

**libVLC** is an embeddable engine for 3rd party applications and frameworks.

It runs on the same platforms as VLC *(and sometimes on more)* and can provide playback,
streaming and conversion of multimedia files and streams.


**libVLC** has numerous bindings for other languages, such as C++, Python and C#.

# Support

## Links

Some useful links that might help you:

- [VLC web site](https://www.videolan.org/vlc/)
- [Support](https://www.videolan.org/support/)
- [Forums](https://forum.videolan.org/)
- [Wiki](https://wiki.videolan.org/)
- [Developer's Corner](https://wiki.videolan.org/Developers_Corner)
- [VLC hacking guide](https://wiki.videolan.org/Hacker_Guide)
- [Bugtracker](https://code.videolan.org/videolan/vlc/-/issues)
- [VideoLAN web site](https://www.videolan.org/)

## Source Code sitemap
```
ABOUT-NLS          - Notes on the Free Translation Project.
AUTHORS            - VLC authors.
COPYING            - The GPL license.
COPYING.LIB        - The LGPL license.
INSTALL            - Installation and building instructions.
NEWS               - Important modifications between the releases.
README             - Project summary.
THANKS             - VLC contributors.

bin/               - VLC binaries.
bindings/          - libVLC bindings to other languages.
compat/            - compatibility library for operating systems missing
                     essential functionalities.
contrib/           - Facilities for retrieving external libraries and building
                     them for systems that don't have the right versions.
doc/               - Miscellaneous documentation.
extras/analyser    - Code analyser and editor specific files.
extras/buildsystem - Different build system specific files.
extras/misc        - Files that don't fit in the other extras/ categories.
extras/package     - VLC packaging specific files such as spec files.
extras/tools/      - Facilities for retrieving external building tools needed
                     for systems that don't have the right versions.
include/           - Header files.
lib/               - libVLC source code.
modules/           - VLC plugins and modules. Most of the code is here.
po/                - VLC translations.
share/             - Common resource files.
src/               - libvlccore source code.
test/              - Testing system.
```
