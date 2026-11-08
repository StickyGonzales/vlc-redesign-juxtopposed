# Submitting Cone Player to Flathub

Branch `wip/flathub-prep` (on top of `wip/linux-flatpak`, the Flatpak build). StickyGonzales, 2026-11-08. **Nothing is submitted.** These are the steps for StickyGonzales's GitHub account, and what to expect from Flathub's reviewers.

Once on Flathub, every Linux user with Flatpak (and the app stores built on it: GNOME Software, KDE Discover, the Linux Mint and Fedora stores) installs Cone Player with one click, and updates come by themselves.

## 1. Where things stand
| Check | Result |
|---|---|
| Builds in Flathub's build image (KDE 6.10 runtime) and runs in the sandbox | `build-flatpak.yml`: see the runs in redesign/FLATPAK_NOTES.md |
| `flatpak-builder-lint manifest` | **1 error: `appid-url-not-reachable`** (section 2, needs StickyGonzales); 1 warning: KDE runtime 6.11 is available (section 6) |
| `flatpak-builder-lint repo` (the built repository, screenshots mirrored as Flathub does) | in the build-flatpak runs |
| `appstreamcli validate` on the metainfo | passes (one pedantic note: the ID has capital letters, which Flathub accepts) |
| Sandbox permissions | minimal, each one explained in the manifest (section 4) |
| App ID, name, trademarks | section 3 |

## 2. Before submitting: the app ID needs a GitHub repository named ConePlayer (StickyGonzales decides)
The app ID is **`io.github.StickyGonzales.ConePlayer`**. For an `io.github.<user>.<name>` ID, Flathub requires the repository **https://github.com/StickyGonzales/ConePlayer** to exist; its linter stops a submission without it (`appid-url-not-reachable`, the only linter error left). The project lives at `StickyGonzales/vlc-redesign-juxtopposed`. Two ways:

- **A. Rename this repository to `ConePlayer` (recommended).**
  - GitHub: the repository > **Settings** > **General** > **Repository name** > `ConePlayer` > **Rename**.
  - GitHub keeps redirecting the old address (web pages, `git clone`, release download links, the update check), so nothing breaks. The README, release notes and AppStream links can move to the new name afterwards.
  - The public address then carries the app's own name instead of "vlc".
- **B. Create a new repository `StickyGonzales/ConePlayer`** (for example with a README that points to the main one). Flathub's linter only checks that it exists, but a reviewer may ask why the source lives elsewhere.

The other choice would be an app ID derived from this repository's name (`io.github.StickyGonzales.vlc_redesign_juxtopposed`): long, and it puts "vlc" in the app ID, which section 3 avoids.

## 3. Name, app ID and trademarks (what a reviewer may ask)
- **App ID** `io.github.StickyGonzales.ConePlayer`: Flathub's form for a project hosted on GitHub (the account name keeps its capitals; app IDs may contain them). **It can never change after the first release on Flathub.** After acceptance Flathub verifies it through StickyGonzales's GitHub login (the app page then shows a "verified" check).
- **Name** "Cone Player", **icon** Cone's own (no VLC cone, no "VLC" in the name, app ID, icon or command).
- **"VLC"** appears only to say what the app is built on ("the engine of VLC media player", nominative use), with the trademark sentence: "not affiliated with or endorsed by VideoLAN or Juxtopposed; VLC is a trademark of the VideoLAN non-profit organization". This follows the project's rule (CLAUDE.md, "Public release rules"). A reviewer may still ask about it; the answer is that Cone is its own app with its own name and icon, and credits VLC as its engine.
- **Juxtopposed's design** (CC BY 4.0) is credited in the AppStream description, as the license asks.
- **Beta versions:** Flathub's stable channel expects stable releases. The Linux releases are still called "beta"; either submit once a Linux release is not a beta, or ask the reviewers for the **beta** channel (Flathub Beta) first. The AppStream file marks 1.2.0 beta 3 as `type="development"`.
- **License:** `GPL-2.0-or-later AND LGPL-2.1-or-later` (Cone and VLC; libVLC).

## 4. Sandbox permissions (finish-args) and why
| Permission | Why |
|---|---|
| `--socket=wayland`, `--socket=fallback-x11`, `--share=ipc` | the window: Wayland, X11 only where there is no Wayland |
| `--device=dri` | OpenGL / Vulkan video output and VA-API / VDPAU hardware decoding |
| `--socket=pulseaudio` | sound (PipeWire answers it) |
| `--share=network` | network streams, podcasts, OpenSubtitles downloads |
| `--filesystem=xdg-videos`, `xdg-download` | the media library scans them; downloaded subtitles are saved next to the video |
| `--filesystem=xdg-pictures` | snapshots |
| `--filesystem=xdg-music:ro` | the music library, read only |
| `--filesystem=/media:ro`, `/run/media:ro` | USB drives and discs, read only |
| `--own-name=org.mpris.MediaPlayer2.cone` | media keys and the desktop's media controls (MPRIS); a second start hands its file to the open window through it. VLC's own Flathub package does the same (`org.mpris.MediaPlayer2.vlc`) |
| `--talk-name=org.freedesktop.ScreenSaver` | no screen saver or lock while a video plays |

Not asked for: home or host file access (any other file comes through the file chooser portal, "Open with" or drag and drop), session bus access beyond the two names, devices other than the GPU.

**Updates:** the Flatpak's launcher starts Cone with `--no-qt-cone-update-check`: Flathub updates the app, and Flathub apps must not offer their own updates.

## 5. Submitting (StickyGonzales, after section 2)
Flathub reviews a pull request to its `flathub/flathub` repository; after it is accepted, Flathub makes a repository just for the app.

1. **A release with the Flatpak files.** The Flathub manifest builds a tagged Linux release, and that release must contain `extras/package/flatpak` and the desktop ID change (PRs of `wip/linux-flatpak` and `wip/flathub-prep`). So: merge them, then make the next Linux release (e.g. `linux-v1.2.0` or `linux-v1.3.0-beta1`), and add its `<release>` entry to `extras/package/flatpak/io.github.StickyGonzales.ConePlayer.metainfo.xml` before tagging (section 7).
2. **Fork Flathub's repository:** open https://github.com/flathub/flathub > **Fork** > untick **Copy the master branch only** > **Create fork**.
3. **A branch from `new-pr`:** in your fork, open the branch selector (top left), pick `new-pr`; open it again, type `add-cone-player` and click **Create branch: add-cone-player from new-pr**.
4. **Add the files** to that branch (**Add file** > **Upload files**):
   - `io.github.StickyGonzales.ConePlayer.yml`: the manifest from this repository, with two changes for Flathub:
     - the `cone` module's source becomes the release tag instead of the local folder:
       ```yaml
       - type: git
         url: https://github.com/StickyGonzales/ConePlayer.git
         tag: linux-v1.2.0
         commit: <the tag's full commit SHA, from the release page>
         x-checker-data:
           type: git
           tag-pattern: ^linux-v([\d.]+)$
       ```
       (`x-checker-data` lets Flathub's bot open an update pull request on every new Linux release, section 7.)
     - the `libdvbpsi` patches: change `../../../contrib/src/dvbpsi/` to nothing in the seven `paths` lines, and upload those seven `.patch` files from `contrib/src/dvbpsi/` next to the manifest.
   - **Commit changes**.
5. **Open the pull request:** your fork > **Contribute** > **Open pull request**, with **base: `new-pr`** (not `master`), title **Add io.github.StickyGonzales.ConePlayer**. Fill in Flathub's checklist in the description (you are the developer, the license, the app ID's repository).
6. **Review:** reviewers comment in the pull request; write `bot, build` in a comment to make Flathub build it (a test build with a link to install it). Answer their questions (section 3 and 4 have the answers to the usual ones).
7. **After acceptance:** Flathub creates `github.com/flathub/io.github.StickyGonzales.ConePlayer` and invites you as its maintainer (accept the invitation in the email or at https://github.com/flathub). The app appears on https://flathub.org/apps/io.github.StickyGonzales.ConePlayer within a few hours. Then log in on flathub.org with GitHub and verify the app (**Developer portal** > the app > **Verification**).

## 6. Runtime
The manifest uses the KDE 6.10 runtime (Qt 6.10, the Qt the other Linux builds use). The linter notes that 6.11 exists: a warning, not an error. Moving to 6.11 is one line (`runtime-version: '6.11'`) after a build-flatpak run and a short test.

## 7. Every later release
- **In this repository, before tagging a Linux release:** add a `<release version="..." date="...">` entry with a few lines of notes at the top of `<releases>` in the metainfo (Flathub and the app stores show it), and keep `--with-brand-version` in the manifest at the new version.
- **On Flathub:** within a day of the new tag, Flathub's bot (flatpak-external-data-checker, from `x-checker-data`) opens a pull request in `flathub/io.github.StickyGonzales.ConePlayer` that moves the tag and commit; Flathub builds it and posts a test link. Merge it (button on GitHub): the update goes out to every user within hours.
- **By hand** (if the bot did not): in that repository edit the manifest's `tag` and `commit`, commit to a branch, open a pull request, wait for the test build, merge.
- **Changes to the manifest itself** (permissions, modules) go into this repository's `extras/package/flatpak` first (checked by `build-flatpak.yml`), then the same change in the Flathub repository.
