**Juxtopposed's VLC Redesign, fully working on real VLC 4.** Not a skin: a new player, sidebars, library and settings, on the same VLC engine.

![VLC Redesign: the library with the mini player (Figma design by Juxtopposed)](docs/images/hero.png)

<sub>Images on this page are frames of Juxtopposed's Figma design, which this build implements. Screenshots of the build itself are added next to them as each area is verified.</sub>

> **About this fork:** this is an unofficial redesign of VLC's interface based on
> ["VLC Redesign" by Juxtopposed](https://www.figma.com/community/file/1691465999134370980/vlc-redesign)
> ([video](https://youtu.be/ERFeOgqk324)); the Figma design is used under
> [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). This project is not affiliated with
> VideoLAN or with Juxtopposed. See [CREDITS.md](CREDITS.md).

## What's built

Built on VLC master (VLC 4, Qt 6 / QML). Everything below runs on VLC's real data and engine; nothing is a mockup.

| Area | Status | What it covers |
|---|---|---|
| Player | Done | Thin control bar, thick seek bar, cone volume 0-200 %, click-to-type time, bars that fade in a window and show per edge in fullscreen, Hide UI, inset video frame, resume prompt |
| Tracks popup | Done | Subtitles / Audio / Video tabs with embedded and external tracks and output devices |
| Settings sidebar | Done | Playback, Video, Audio and Subtitles tabs: speed, flip / rotate / zoom / crop, equalizer and filters, subtitle sync sliders and appearance |
| Queue sidebar | Done | Queue, Bookmarks and Chapters tabs |
| Menus | Done | Main "..." menu and right-click menu, final Figma versions, wired to real actions |
| Library | Done | Icon rail, compact panel over the video and full window, Home with Continue Watching and Latest Streams, Videos, Music (songs, albums, artists, genres, music player view), Network streams, Playlists, Recent, pins, watched / unwatched sorting |
| Mini player | Done | Mini player with its attached queue, draggable to the corners |
| Settings dialog | Done | All 13 categories mapped to VLC's own options, search, info popovers, Advanced Options |
| Dialogs | Done | Keyboard Shortcuts, Open Network Stream, open dialogs split and restyled |
| Customize Player | Done | Restyled toolbar editor |
| Onboarding | Done | Welcome and media folder, theme and accent color with live recolor, shortcuts |
| Themes | Done | Dark, Light, 9 accent colors |
| Seek preview thumbnails | In progress | Thumbnail above the seek bar while hovering |
| Settings rows VLC has no option for | In progress | Night mode, own tray popup and the other rows shown in the design |
| Subtitle sync without stalls | In progress | Changing subtitle speed or delay no longer freezes the video (small core change, own build) |
| Playback tab extras | Planned | Sleep timer, Show Statistics, Show Metadata panel |
| Per-show presets | Planned | One preset per show across all tabs |
| Add Subtitles dialog | Planned | File, folder or playlist targets, episode auto-matching, from link or OpenSubtitles |
| Subtitle timeline, waveform seek bar | Planned | On the seek bar |
| Profiles, new Customize controls | Planned | Layouts and settings per profile |
| Release | Planned | Installer and portable zip on GitHub Releases |

## The design being built

Every screen below exists in this build and runs on VLC's real data. Side by side screenshots of the build are added here as each area is verified.

| | |
|---|---|
| **Player**<br><img src="docs/images/figma-player.png" alt="Player"> | **Home**<br><img src="docs/images/figma-home.png" alt="Home"> |
| **Library and mini player**<br><img src="docs/images/figma-library.png" alt="Library and mini player"> | **Compact library**<br><img src="docs/images/figma-sidebar.png" alt="Compact library"> |
| **Settings**<br><img src="docs/images/figma-settings.png" alt="Settings"> | **Customize Player**<br><img src="docs/images/figma-customize.png" alt="Customize Player"> |
| **Onboarding**<br><img src="docs/images/figma-onboarding.png" alt="Onboarding"> | **Keyboard Shortcuts**<br><img src="docs/images/figma-shortcuts.png" alt="Keyboard Shortcuts"> |
| **Light theme**<br><img src="docs/images/figma-light.png" alt="Light theme"> | |

## Design system

The icons and colors come straight from the Figma file. In the Light theme, FG/1, FG/2 and FG/A4 are
corrected here (the Figma file repeats the dark values there).

<p align="center"><img src="docs/images/figma-palette.png" width="49%" alt="Color palette"> <img src="docs/images/figma-icons.png" width="35%" alt="Icon set"></p>

## Roadmap

- [x] Windows build on GitHub Actions
- [x] Colors, fonts, icons and component kit
- [x] Player: top bar, control bar, seek bar, cone volume, bars show / hide
- [x] Tracks popup, settings sidebar, queue / bookmarks / chapters sidebar
- [x] Main menu and right-click menu
- [x] Library: home, videos, music, network streams, playlists, recent, pins, mini player
- [x] Settings dialog, Keyboard Shortcuts, Open Network Stream
- [x] Customize Player, onboarding, light theme and accent colors
- [ ] Seek preview thumbnails
- [ ] Settings rows VLC has no option for (night mode and the rest)
- [ ] Sleep timer, statistics, metadata panel, Ctrl+B bookmarks
- [ ] Per-show presets
- [ ] Add Subtitles dialog with episode auto-matching
- [ ] Subtitle timeline and waveform seek bar
- [ ] On-screen messages show the pressed shortcut
- [ ] Profiles and new Customize controls
- [ ] Installer and portable zip on GitHub Releases

## Cone extras (not part of Juxtopposed's design)

Features Cone adds beyond Juxtopposed's design (in neither her video nor her Figma file) are listed here, each marked as a Cone extra. They are not part of beta 2 or 1.0: each is built on its own branch and arrives after 1.0, starting with 1.1.

| Cone extra | Status | What it does |
|---|---|---|
| Autoplay next episode ("Up Next") | Planned for 1.1 | When an episode of a show folder ends, an "Up next" card counts down to the next episode. Off / Ask for each show / Always in Settings > Playback; single videos, recordings, clips and music are never treated as shows. Plan and designs: [redesign/UP_NEXT_PLAN.md](redesign/UP_NEXT_PLAN.md) |

## FAQ

**Can I download it?**
Not as a release yet. Every push builds a Windows 64-bit package on GitHub Actions: open the
[build-windows workflow](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/actions/workflows/build-windows.yml),
pick the latest green run and download the `vlc-redesign-win64` artifact (needs a GitHub login).
It tracks VLC 4 development code, so treat it as experimental. An installer and a portable zip
will come on the Releases page.

**Is this official?**
No. It is an independent, unofficial project, not affiliated with, endorsed or sponsored by
VideoLAN or by Juxtopposed. The design is Juxtopposed's, used under CC BY 4.0.

**Does it change how VLC plays media?**
No. Playback, codecs and the engine are VLC's own. The work is in VLC's Qt interface
(`modules/gui/qt`); the few small core changes a feature truly needs are kept separate and listed
in `redesign/VIDEO_INDEX.md`.

**How was it built?**
With Claude Code, working from the Figma file (every size, color and spacing taken from its node
values) and the designer's video for behavior. Each change is checked with real screenshots of the
build side by side with the Figma frames, plus a usability pass.

**Is it as fast as stock VLC?**
That is the first rule of the project, measured every round against stock VLC 4 on the same PC
([redesign/PERF.md](redesign/PERF.md)). Latest round: startup about 1 s for both, playing at
0.1 % CPU and about 310 MB RAM for both, 4K60 at 80 Mbit/s with the same dropped frames as stock,
and a 520-item queue that scrolls at least as smoothly as stock.

## How to build

The build runs on GitHub Actions with VideoLAN's own Windows toolchain image and build script
(`extras/package/win32/build.sh`), the same as VLC's official win64 CI job. To build your own:
fork this repository, enable Actions on the fork and run the **build-windows** workflow
(`.github/workflows/build-windows.yml`); the artifact is a ready-to-run VLC folder. Building
VLC itself is documented on the [VideoLAN wiki](https://wiki.videolan.org/Win32Compile/).

## Credits

- Design: ["VLC Redesign" by Juxtopposed](https://www.figma.com/community/file/1691465999134370980/vlc-redesign)
  ([video](https://youtu.be/ERFeOgqk324)), CC BY 4.0.
- VLC media player by VideoLAN and its contributors, GPLv2 or later (libVLC LGPLv2 or later).
- Fonts: Inter and DM Mono, SIL Open Font License.
- Built by [StickyGonzales](https://github.com/StickyGonzales). Details in [CREDITS.md](CREDITS.md).

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
