# Cone Player on the AUR (cone-player-bin)

Branch `wip/aur-cone-player-bin`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-08. **Nothing is pushed to the AUR**: the steps below are for StickyGonzales's own account.

Arch Linux users (and Manjaro, EndeavourOS, CachyOS) install it with an AUR helper, for example `yay -S cone-player-bin` or `paru -S cone-player-bin`.

## 1. What is here
| File | What |
|---|---|
| `extras/package/aur/cone-player-bin/PKGBUILD` | the package: the official Linux release tarball into `/opt/cone-player`, the command `cone-player`, the menu entry (with every media and subtitle file type, for "Open with") and the icons |
| `extras/package/aur/cone-player-bin/.SRCINFO` | the package's metadata, which the AUR reads (`makepkg --printsrcinfo`) |
| `extras/package/aur/update-pkgbuild.sh` | sets the PKGBUILD to a release: `_tag`, `_filever`, `pkgver`, `pkgrel=1`, `sha256sums` |
| `.github/workflows/aur-cone-player-bin.yml` | on every published Linux release: updates, builds and checks the package in an Arch container, pushes it to the AUR |

**The package:**
- **Version:** the tag's version without its dash: `linux-v1.2.0-beta3` is `1.2.0beta3`. pacman sorts `1.2.0beta3` before `1.2.0` and after `1.2.0beta2` (checked with `vercmp`), so the final release upgrades a beta.
- **Next to VLC:** `provides`/`conflicts` name only `cone-player`, never `vlc`; Cone has its own name, menu entry (`cone-player.desktop`), icon and settings folder (`~/.config/Cone`), so both install side by side.
- **License:** `GPL-2.0-or-later` (Cone, VLC) and `LGPL-2.1-or-later` (libVLC), as SPDX names; both are in Arch's common licenses, so no license file needs installing.
- **Dependencies:** the libraries the tarball takes from the system (C and C++ runtime, OpenGL / EGL, Vulkan loader, X11, Wayland, DRM / GBM, ALSA, D-Bus, udev, ncurses, fontconfig). Optional: PulseAudio / PipeWire, JACK, the VA-API drivers (AMD, Intel), VDPAU (NVIDIA), SMB, SFTP, GTK (notifications), the desktop portal (file dialogs).
- **VLC's plugin cache:** makepkg sets every file's time to `SOURCE_DATE_EPOCH`, which made the cache stale ("stale plugins cache" at every start, and every plugin loaded each time). `package()` gives the plugins that time and makes the cache again with the bundled `vlc-cache-gen`.

## 2. Test (Arch container, `archlinux:base-devel`, with linux-v1.2.0-beta3)
- `makepkg` as an ordinary user: builds; `makepkg --printsrcinfo` writes `.SRCINFO`.
- `namcap PKGBUILD`: clean.
- `namcap` on the package, with its dependencies installed:
  - **1 error, expected for every prebuilt package in `/opt`:** "ELF files outside of a valid path ('opt/')". The AUR accepts `-bin` packages in `/opt` (the binaries are the release's own, with their bundled libraries).
  - **Warnings, all from the bundled release:** 539 "lacks FULL RELRO" (bundled libraries built by Debian / Ubuntu), 22 "Referenced QML module" (Qt's own QML styles in the bundle), a few "Unused shared library" (in bundled libraries), VLC's man pages under `/opt`, an empty Qt plugin folder, "detected but optional" for the optional dependencies above, and "may not be needed" for `gcc-libs`, `wayland` and `fontconfig` (linux-v1.2.0-beta3 bundles them; releases built on Ubuntu 22.04, PR #112, take them from the system).
  - `libtinfo.so.6` is not on Arch (it is part of `libncursesw` there): only the optional terminal interface (ncurses) and a bundled readline do not load. Cone's window does not use either.
- `pacman -U`: installs; `/usr/bin/cone-player` points to `/opt/cone-player/cone`; `desktop-file-validate` passes on the menu entry (`Exec=cone-player --started-from-file %U`); `cone-player --version` prints "Cone Player 1.2.0, based on VLC 4.0.0-dev" with no stale plugin cache line; `pacman -R` removes everything (`/opt/cone-player` gone).
- `update-pkgbuild.sh linux-v1.2.0-beta3 <tarball>` on a blank PKGBUILD gives exactly the PKGBUILD here; a Windows tag (`v1.2.0`) is refused.

## 3. What StickyGonzales does (once)
### 3.1 Create the AUR account
1. Open https://aur.archlinux.org/register
2. **User name:** `StickyGonzales`. **Email:** any address you read; tick **Hide Email Address**. Leave **SSH Public Key** empty for now (step 3.2). Fill in the captcha, then **Create**.
3. Set your password from the email the AUR sends, and log in.

### 3.2 Make an SSH key for the AUR and add it
An SSH key only for the AUR, without a passphrase (GitHub Actions uses it too). In PowerShell (Windows 10 has `ssh-keygen`):

```powershell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\aur" -N '""' -C "cone-player-bin AUR"; Get-Content "$env:USERPROFILE\.ssh\aur.pub" | Set-Clipboard; Write-Host "The public key is in the clipboard"
```

Then on the AUR: **My Account** (top right) > **SSH Public Key**: paste (Ctrl+V) > enter your password at the bottom > **Update**.

### 3.3 The first push (creates the package on the AUR)
The AUR creates a package the first time someone pushes it. With Git for Windows installed, this PowerShell block clones the (still empty) package, copies the PKGBUILD and .SRCINFO from this repository's `wip/next-test` (after this PR is merged into it) and pushes them:

```powershell
$k = "$env:USERPROFILE\.ssh\aur"; $env:GIT_SSH_COMMAND = "ssh -i `"$k`" -o IdentitiesOnly=yes"; ssh-keyscan -t ed25519 aur.archlinux.org | Out-File -Encoding ascii -Append "$env:USERPROFILE\.ssh\known_hosts"; $d = "$env:USERPROFILE\Downloads\cone-player-bin-aur"; git clone ssh://aur@aur.archlinux.org/cone-player-bin.git $d; $raw = "https://raw.githubusercontent.com/StickyGonzales/vlc-redesign-juxtopposed/wip/next-test/extras/package/aur/cone-player-bin"; Invoke-WebRequest "$raw/PKGBUILD" -OutFile "$d\PKGBUILD"; Invoke-WebRequest "$raw/.SRCINFO" -OutFile "$d\.SRCINFO"; cd $d; git config user.name "StickyGonzales"; git config user.email "103277167+StickyGonzales@users.noreply.github.com"; git add PKGBUILD .SRCINFO; git commit -m "Initial upload: cone-player-bin 1.2.0beta3"; git push origin HEAD:master
```

- `git clone` warns "You appear to have cloned an empty repository": expected for a new package.
- Before the push, check the AUR's key: `ssh-keyscan` printed the line it added to `known_hosts`; its fingerprint must be `SHA256:RFzBCUItH9LZS0cKB5UE6ceAYhBD5C8GeOBip8Z11+4` (the ED25519 key listed on https://aur.archlinux.org).
- Afterwards https://aur.archlinux.org/packages/cone-player-bin shows the package. The `Downloads\cone-player-bin-aur` folder can be deleted.

### 3.4 Add the key to GitHub for the automatic updates
1. In PowerShell, copy the private key: `Get-Content "$env:USERPROFILE\.ssh\aur" -Raw | Set-Clipboard`
2. GitHub: **StickyGonzales/vlc-redesign-juxtopposed** > **Settings** > **Secrets and variables** > **Actions** > **New repository secret**.
3. **Name:** `AUR_SSH_PRIVATE_KEY`. **Secret:** paste (the whole key, including the `-----BEGIN` and `-----END` lines). **Add secret**.

## 4. Every later release
- **Automatic:** when a Linux release (`linux-v...`) is **published** (pressing Publish on the draft that `release-linux.yml` makes), `aur-cone-player-bin.yml` sets the PKGBUILD to it, builds, installs, starts and removes the package in an Arch container, then pushes PKGBUILD and .SRCINFO to the AUR. Arch users get the update with their next `yay` / `paru` upgrade.
- **Needs:** the workflow on the default branch (`redesign`): GitHub runs release and manual workflows from it. Until this PR reaches `redesign`, use the manual push of 3.3 with the newer files.
- **By hand:** Actions > **aur-cone-player-bin** > **Run workflow**: leave **tag** empty for the newest Linux release (or type one, e.g. `linux-v1.3.0`), tick **push** to push it to the AUR; without the tick it is a dry run (build and checks only).
- **The PKGBUILD in this repository** is the template: the workflow changes only `_tag`, `_filever`, `pkgver`, `pkgrel` and the checksum. A change to the package itself (dependencies, files) goes here first, then out with the next release (or a manual run with push).
- **pkgrel:** a change to the package without a new release needs `pkgrel=2` (and so on) by hand; the workflow sets `pkgrel=1` for each new release.

## 5. Runs
| Run | Result |
|---|---|
| (filled in below the PR) | |

## 6. AUR rules checked
- The name ends in `-bin` (a prebuilt package), and no package in Arch's own repositories provides Cone.
- `# Maintainer:` line with the GitHub noreply address; `arch=('x86_64')`, `url`, SPDX `license`, `sha256sums` (not SKIP).
- `.SRCINFO` is pushed with every PKGBUILD change (the workflow regenerates it).
- `options=('!strip' '!debug')`: the release's binaries are stripped already and carry their own RUNPATHs.
