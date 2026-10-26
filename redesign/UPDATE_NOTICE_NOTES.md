# Update notice (branch wip/update-notice)

Branch `wip/update-notice`, made from `origin/wip/next-test` (31d95eff96). Draft pull request into `wip/next-test`, for the next update. Interface only (`modules/gui/qt`), no core change.

## 1. What Cone does today (before this branch)

**VLC's own update checker is not in the Cone build, and cannot be put back by accident.**

| Where | What it does |
|---|---|
| `extras/package/win32/build.sh` | passes `--enable-update-check` only when the brand is not `public` |
| `configure.ac` | `--with-brand=public` together with `--enable-update-check` stops configure with an error |
| `meson.build` | the same for `-Dbrand=public` with `-Dupdate-check` |

Without `UPDATE_CHECK`, none of VLC's update code is compiled:
- the core (`src/misc/update.c`, which asks `update.videolan.org` and downloads VLC installers),
- the `qt-updates-notif` / `qt-updates-days` options,
- the start-up check in `mainctx.cpp`,
- the "Check for Updates..." entry of the Help menu (`menus.cpp`),
- VLC's update dialog and `UpdatePane.qml` (the bar "A new version of VLC is available").

The Settings row "Check for updates automatically" (`qt-updates-notif`) hides itself in Cone because the option does not exist there.

So Cone 1.0.x **checks nothing and shows nothing** about updates. VLC's checker can never offer a VLC download in Cone: its code is not in the program, and the three build paths refuse to add it. This branch keeps all of that as it is.

## 2. What this branch adds (public brand only)

**The check**
- At most once a day, 4 s after Cone starts, Cone asks GitHub for its latest release:
  `GET https://api.github.com/repos/StickyGonzales/vlc-redesign-juxtopposed/releases/latest`.
- The request carries only `Host`, `User-Agent: Cone-Player`, `Accept: application/vnd.github+json` and `Connection: close` (nothing else: no version, language, cookies or IDs; checked in the sandbox, section 4).
- It goes through the interface's own HTTPS helper (`SubtitleWeb::request`, VLC's TLS sockets, the same code as OpenSubtitles), on a worker thread. It gives up after 15 s, and a quit stops it at once.
- It runs only while "Check for updates" is on, and never before the first-run privacy question has been answered (VLC's rule for its own checker).
- "Once a day" counts attempts: a failed check (offline) is not retried until the next day.
- GitHub's "latest" is the newest release that is not a draft and **not a pre-release**. Pre-releases are never offered.
- The version is the `X.Y.Z` in the tag (`v1.0.2`, `v1.1.0-beta`); it is compared with this build's Cone version (`BRAND_VERSION`).

**The notice** (`maininterface/qml/RdUpdateNotice.qml`)
- "Cone Player X.Y.Z is available", with **Download** and **Later**.
- Style: the profile notice's (Figma "continue" toast: 52 px pill, radius 16, BG/A3, Inter 16 FG/2, primary button). Centered, 18 px above the control bar, over every view. It never takes the keyboard focus.
- **Download** opens the release page in the browser (only a `https://github.com/` address from GitHub's answer, otherwise the project's releases page) and hides the notice until the next day.
- **Later** and **Escape** hide it until the next day.
- A newer version found once is remembered: the next start shows the notice again without a new request, until Later or Download that day. Updating Cone makes it disappear for good (the remembered version is no longer newer).
- Nothing is downloaded or installed.

**Settings > General > Startup**
- **Check for updates** (`qt-cone-update-check`, on by default).
- **Check now** row with a "Check Now" button. It asks at once, whatever the switch and the day, and says under the button:
  - "Checking…"
  - "Cone Player X.Y.Z is the latest version."
  - "Cone Player X.Y.Z is available." (the notice opens too, even after Later)
  - "Could not reach GitHub. Try again later."

**vlc profile:** unchanged. The checker object stays idle, the notice is not created, both new rows hide themselves, and VLC's own checker works as before.

**Files:**
- New: `util/rd_update_check.cpp/.hpp`, `maininterface/qml/RdUpdateNotice.qml`
- Changed: `qt.cpp` (the option), `mainui.cpp` (registration), `MainInterface.qml`, `SettingsGeneralPage.qml`, `settings_catalog.cpp`, `Makefile.am`, `meson.build`
- Changed: `subtitle_web.cpp/.hpp`. A caller's own `User-Agent` / `Accept` header now replaces the default one. OpenSubtitles sends neither, so its requests are unchanged.

**Limits:**
- Like OpenSubtitles, the request does not use a proxy. Behind a proxy-only network the check fails silently.
- A release published as a pre-release (like v1.0.2 today) is not offered: GitHub's "latest" skips it. Today the API answers v1.0.1. To offer an update, publish it as a full release.

## 3. Checks
(filled in below)

## 4. Sandbox test (Linux)
(filled in below)

## 5. Windows retest (PC session)
(filled in below)
