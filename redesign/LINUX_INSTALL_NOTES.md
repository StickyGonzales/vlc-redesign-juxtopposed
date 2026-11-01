# Linux: per-user install, menu entry and icons (branch wip/linux-install)

Branch `wip/linux-install`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. CI and packaging only; Cone build only (the vlc profile's Linux package is unchanged).

## What the tarball gets
| File | What it is |
|---|---|
| `install.sh` | installs Cone Player **for the current user, without sudo** |
| `uninstall.sh` | removes it again (also copied into the installed folder) |
| `cone-player.desktop`, `cone-player.png` | the menu entry and the 256 px icon (top level, for the AppImage) |
| `usr/share/applications/cone-player.desktop` | the same entry, inside |
| `usr/share/icons/hicolor/{16,24,32,48,64,128,256}x…/apps/cone-player.png` | the icon at every size, from the brand's PNGs |

**install.sh** puts:
- the program into `~/.local/share/cone-player/` (a copy of the folder, without a `portable` folder);
- the command `~/.local/bin/cone-player` (a link to the launcher);
- the menu entry `~/.local/share/applications/cone-player.desktop`, with `Exec=` set to the full path;
- the icons into `~/.local/share/icons/hicolor/<size>/apps/`.

Then it refreshes the desktop's caches (`update-desktop-database`, `gtk-update-icon-cache`) when they exist. It refuses to run as root, and run again from a newer folder it updates.

**uninstall.sh** removes exactly those files. The command is removed only if it links into the installed folder. Settings, media library and caches (`~/.config/Cone`, `~/.local/share/Cone`, `~/.cache/Cone`) stay, unless `--purge` is given. Run from the installed folder, it continues from a temporary copy of itself.

**The menu entry** (desktop ID `cone-player`, VLC's is `vlc`):
- `MimeType=` lists VLC's own video and audio types (`share/vlc.desktop.mimetypes`, without its URL schemes), plus the subtitle formats: `application/x-subrip`, `text/x-ssa`, `text/vtt`, `text/x-microdvd`, `text/x-mpsub`, `text/x-subviewer`, `application/x-sami`.
- So Cone Player shows in **Open with** for those files. Nothing sets it as the **default**: no `mimeapps.list` entry, no `xdg-mime default`.

**The AppImage:**
- It carries the same entry and icons, at the top level (where AppImageLauncher, appimaged and Gear Lever look) and under `usr/share`.
- `linux-appimage.sh` now reads the launcher (`Exec=`) and the icon (`Icon=`) from the top-level `.desktop`.

VLC's own desktop files, icons and AppStream file are left out of the Cone package, so no integration tool shows a second "VLC" entry.

## Tests
- **Local, with stand-in files:** `install.sh` and `uninstall.sh` in a home folder whose path has a space. The `Exec=` path is quoted, `portable` is left out, and nothing is left after the uninstall.
- **Real build** (build-linux #52, run 41252263765, which includes this branch), in the Linux sandbox with the smoke script (`wip/linux-smoke`, see LINUX_SMOKE_NOTES.md):
  - **install.sh:** program, command, menu entry (`desktop-file-validate`: no errors) and icons 16 to 256 px.
  - **Open with:** `mimeinfo.cache` lists `cone-player.desktop` for `video/mp4`, `video/x-matroska`, `audio/mpeg` and `application/x-subrip`; no `mimeapps.list` entry.
  - **The installed copy:** `~/.local/bin/cone-player` plays the H.264 test video, the time advances, the quit takes 0.16 s, and no plug-in fails to load.
  - **uninstall.sh:** nothing named `cone-player` left in the home folder.

## Runs
| Run | Result |
|---|---|
| build-linux #51 (41252146116), this branch | build and tarball **green**; the tarball holds install.sh, uninstall.sh, cone-player.desktop and the icons |
| Linux sandbox (build #51's tarball, user without root) | install.sh: menu entry valid (desktop-file-validate), icons 16 to 256 px, offered for video/mp4, audio/mpeg and application/x-subrip, no default changed; Cone starts from `~/.local/bin/cone-player` and plays; uninstall.sh leaves nothing named cone-player |
| CI smoke checks (wip/linux-smoke, smoke-linux.yml) | `tarball: install.sh for the current user` and `tarball: uninstall.sh` **pass** on GitHub (run 41256425136) |

## Retest (PC session or a Linux desktop)
1. Unpack the tarball and run `./install.sh` (no sudo). Cone Player shows in the applications menu with its icon.
2. Right-click a video, a song and an `.srt` file > Open with: Cone Player is listed. The default player is unchanged.
3. `cone-player <file>` in a terminal (with `~/.local/bin` on the PATH) plays it.
4. `~/.local/share/cone-player/uninstall.sh`: the entry and the icons go, and the settings stay. With `--purge` the settings go too.
5. **AppImage:** with AppImageLauncher (or Gear Lever), integrate the AppImage. The menu entry is "Cone Player" with the Cone icon.
