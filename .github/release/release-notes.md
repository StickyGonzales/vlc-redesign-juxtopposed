# Cone Player {{VERSION}}: Juxtopposed's redesign on a real VLC 4 fork, not a skin

**Cone** is a media player for Windows: the playback engine of VLC media player with a new interface built from Juxtopposed's VLC Redesign.

> **Experimental build.** Cone follows the development branch of VLC 4 (VLC version {{VLC_VERSION}} inside), so expect rough edges and bugs. Keep your normal VLC installed: Cone installs next to it with its own settings, file associations and data folder, and never changes VLC's.

## Downloads

| File | What it is | SHA-256 |
|---|---|---|
| `{{EXE}}` | Installer for Windows 10 and 11 (64-bit) | `{{EXE_SHA256}}` |
| `{{ZIP}}` | Zip: unpack anywhere and run `Cone.exe`, no installation (settings go to `%APPDATA%\Cone`; create an empty folder named `portable` next to `Cone.exe` to keep them there instead) | `{{ZIP_SHA256}}` |

`SHA256SUMS.txt` holds both checksums. To check a download in PowerShell, run `Get-FileHash .\{{EXE}} -Algorithm SHA256` and compare the result with the table above.

The files are not code-signed yet, so Windows SmartScreen may warn the first time: choose "More info", then "Run anyway".

## Cone extras (not part of Juxtopposed's design)

Features Cone adds beyond Juxtopposed's design are listed here, each marked as a Cone extra (Decision 71). Cone extras are not part of beta 2 or 1.0; they arrive after 1.0, starting with 1.1 ("Autoplay next episode" is the first). When a release has none, this section says so.

## Credits

- **Based on [VLC media player](https://www.videolan.org/vlc/) by [VideoLAN](https://www.videolan.org/)**. All of the playback, codecs and streaming are VLC's work.
- **Design by Juxtopposed**: the [VLC Redesign Figma file](https://www.figma.com/community/file/1691465999134370980/vlc-redesign) and [video](https://youtu.be/ERFeOgqk324), used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- Cone is an independent project. It is **not affiliated with, endorsed by or supported by VideoLAN or Juxtopposed**. VLC, VLC media player and VideoLAN are trademarks of VideoLAN.

## License and source code

Cone is free software under the [GNU General Public License, version 2 or later](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html), like VLC. The complete source code of this release is the commit [{{COMMIT}}]({{REPO_URL}}/tree/{{COMMIT}}); the "Source code" archives below hold the same tree.

Built by GitHub Actions: [build log]({{RUN_URL}}).
