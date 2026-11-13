# Code signing policy

Free code signing provided by [SignPath.io](https://about.signpath.io), certificate by [SignPath Foundation](https://signpath.org).

**Status:** Cone Player has applied to the SignPath Foundation for an open source code signing certificate.
Until the first signed release is out, the Windows downloads are unsigned and Windows SmartScreen may warn the
first time you run them (choose **More info**, then **Run anyway**). Every release lists the SHA-256 of its files.

## What is signed

Only the Windows release files of Cone Player, built from this repository:

- `Cone.exe`, the program, inside the installer and the portable zip;
- the installer, `coneplayer-<version>-win64.exe`.

Not signed with this certificate:

- the libraries and plugins of VLC media player that Cone Player ships (`libvlc.dll`, `libvlccore.dll`, `plugins\`):
  they are VideoLAN's software, built unchanged or nearly unchanged from VLC's own source in this fork;
- the uninstaller the installer writes on your PC, and VLC's `spad-setup.exe` helper in the zip;
- test builds, Linux and macOS builds.

Every signed file carries the product name "Cone Player" and the version of its release. The certificate is
issued to SignPath Foundation, so Windows names "SignPath Foundation" as the verified publisher.

## How a signed release is made

1. All source code, build scripts and CI settings are in this public repository, a visible
   [fork of VLC media player](https://github.com/videolan/vlc). VLC's own changes come in by merging VLC's
   `master` branch.
2. A release is built only from a version tag on the `redesign` branch, which receives only code that passed
   the automated checks and a test on Windows (`.github/workflows/release.yml`).
3. The build runs on GitHub-hosted runners in VideoLAN's own Windows build image. The workflow sends the
   unsigned `Cone.exe`, and then the installer built with the signed `Cone.exe`, to SignPath.
4. An approver checks each signing request in SignPath and approves it by hand. Nothing is signed without that
   approval.
5. The release is published on GitHub with the SHA-256 of every file.

## Team roles

| Role | Members |
|---|---|
| Committers and reviewers | [StickyGonzales](https://github.com/StickyGonzales) |
| Approvers | [StickyGonzales](https://github.com/StickyGonzales) |

Cone Player is developed by StickyGonzales with the AI coding assistant [Claude](https://claude.ai/code). Only
StickyGonzales can push to this repository; outside contributions come as pull requests and are reviewed before
they are merged. Every team member uses multi-factor authentication for GitHub and SignPath.

## Privacy policy

Cone Player does not collect, store or send any personal data, and it has no telemetry or analytics. It connects
to other systems only in these cases:

- **Update check** (on by default): at most once a day, when it starts, Cone Player asks GitHub
  (`api.github.com`) for the latest release of Cone Player, to show a notice when a newer one is out. Nothing is
  downloaded or installed. Turn it off in Settings > General > Check for updates.
- **Subtitles from OpenSubtitles** (off until you add your own OpenSubtitles.com API key): when you search for
  or download subtitles in Add Subtitles, or when you turned on the automatic download for the next episode,
  Cone Player sends the search (the show or movie name, the language, the season and episode) to
  `api.opensubtitles.com`, with your OpenSubtitles username and password only if you entered them.
  [OpenSubtitles' privacy policy](https://www.opensubtitles.com/en/privacy) applies.
- **Cast devices** (on by default, VLC's feature): Cone Player looks for Chromecast and other cast devices on
  your local network. Nothing leaves your network. Turn it off in Settings > Recording > Discover cast devices.
- **Media information and artwork** (off by default, VLC's feature): only if you allow it on the first start or
  in Settings > Privacy, VLC looks up artwork and information for your media on the internet.
- **What you open yourself**: network streams, URLs and network shares you open are played from where they are.

## Uninstalling

Settings > Apps > Cone Player > Uninstall removes the installed Cone Player; it asks before deleting your
settings. For the portable zip, delete its folder.

## Reporting

To report a problem with a signed file, open an [issue](https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues).
