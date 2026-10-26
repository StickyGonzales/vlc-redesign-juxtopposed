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

Also: a stalled DNS lookup cannot be interrupted on Windows (VLC's `vlc_getaddrinfo_i11e` falls back to plain `getaddrinfo` there). A quit that lands in such a lookup waits for the system's DNS timeout; the quit watchdog (#34) still ends it after 5 s. Connect, TLS and reads are interruptible, so a stalled server or connection does not delay the quit (section 4).

## 3. Checks
- qmlcheck: errors 1 (the known HighResolutionTimeWidget), crashed 0. buildlists 0, privacycheck 0.
- C++ syntax check of `rd_update_check.cpp`, `subtitle_web.cpp`, `mainui.cpp`, `qt.cpp`, in both profiles (`VLC_BRAND_PUBLIC` on and off), with g++ (`-Wall -Wextra -Wconversion`) and clang (`-Wunused-private-field -Wunused-function`): no warnings in our code.
- Windows names: the same check with Windows' header macros defined (`far`, `near`, `small`, `interface`, `pascal`): no errors.
- Independent review (a fresh agent that did not write the code) of the whole diff. Fixed after it:
  - GitHub's 404 (only pre-releases, no full release yet) now reads "the latest version", not "Could not reach GitHub".
  - The notice no longer takes Escape window-wide. It used to, so Escape in fullscreen would close the notice instead of leaving fullscreen. Now Escape works only on its focused buttons.
  - A quit can no longer count as "Later".
  - No unused helpers in the vlc profile.

## 4. Sandbox test (Linux)
Build: build-linux #43 (run 40383196557), test-only branch `wip/update-notice-linux` = wip/linux-build + this branch. A Linux push build is **Cone 0.1.0**, the fake older version.

Setup:
- Xvfb with openbox, window 1440x900, a fresh profile.
- `api.github.com` pointed at a local HTTPS server (its own test CA added to the sandbox's trust store). The server logs each request exactly as received and answers like GitHub: a release (`v1.0.1` / `v1.0.2` / `v0.1.0`), 404, 500, or no answer.
- `xdg-open` replaced by a stub that records the address.

| Test | Result |
|---|---|
| Start, switch on (default) | 4 s after the start one GET, the notice "Cone Player 1.0.1 is available" (picture) |
| What the request carries | `GET /repos/StickyGonzales/vlc-redesign-juxtopposed/releases/latest`, headers `Host`, `Connection: close`, `User-Agent: Cone-Player`, `Accept: application/vnd.github+json`, nothing else |
| Later | the notice closes; a restart the same day sends no request and shows nothing |
| The next day (stored dates cleared) | the notice is back at once (remembered version) and one new request goes out |
| Download | the notice closes, `xdg-open https://github.com/StickyGonzales/vlc-redesign-juxtopposed/releases/tag/v1.0.1` |
| Check Now, server 500 | "Checking…" (button disabled), then "Could not reach GitHub. Try again later." |
| Check Now, 404 | "Cone Player 0.1.0 is the latest version." |
| Check Now, latest v0.1.0 | "Cone Player 0.1.0 is the latest version." |
| Check Now, no answer | "Checking…" for 15 s, then "Could not reach GitHub. Try again later." |
| Check Now, v1.0.2, after Download the same day | "Cone Player 1.0.2 is available." and the notice opens again |
| Fullscreen with the notice shown, Escape | fullscreen ends, the notice stays |
| Quit (Ctrl+Q) while the request hangs (twice) | 0.16 s, the same as without a request (0.16 s) |
| Switch off (`--no-qt-cone-update-check`), next day | no request, no notice |
| First run (`--qt-privacy-ask`, onboarding) | no request |
| Settings > General | "Check for updates" (ON) and "Check now"; VLC's "Check for updates automatically" row stays hidden |

Found and fixed in the sandbox (commit dd96095f8a):
- The sentence was cut ("Cone Player 1.0.2 is availa..."): the layout rounded the label's fractional width down. It now rounds it up.
- In the library, which has no control bar, the notice floated a bar's height above the bottom. It now sits 18 px above the window's bottom there.

Checked on the rebuild, build-linux #44 (run 40388540602):
- "Cone Player 1.0.2 is available" is whole.
- In the library the pill takes rows 830 to 881 of the 900 px window, 18 px above its bottom.
- In the player it sits above the control bar.

Picture: `redesign/fix-shots/update_notice.jpg` (library, player, Settings rows, the Check Now answers).

Not testable in the sandbox: the real GitHub API (the sandbox reaches GitHub only through its proxy, which this request, like OpenSubtitles', does not use), a real browser, Windows.

## 5. Windows retest (PC session)
Build this branch: `gh workflow run build-windows.yml --ref wip/update-notice`, then the asset `wip-update-notice--win64-public.zip` from the `test-builds` draft (redesign/TEST_BUILDS.md). A manual Windows build is **Cone 0.1.0** (no version tag), so it is older than every release: the real GitHub answer is the test.

1. **First start on the test folder** (portable, the usual `builds/current`). Answer the onboarding. Close Cone and start it again.
   - Expected: about 4 s after the start, "Cone Player 1.0.1 is available" (or whatever the newest full release is then), bottom centre of the library, 18 px above the window's bottom, the whole sentence visible.
   - Pre-releases (v1.0.2 today) are never offered.
2. **Download.** The release page opens in the default browser, the notice closes.
3. **Restart the same day.** No notice. (Settings > General > Check now shows the result.)
4. **Later.** Settings > General > **Check Now**: "Checking…", then "Cone Player 1.0.1 is available." and the notice again. Click **Later**: it closes, a restart the same day shows nothing.
5. **Player and fullscreen.** Clear the day (delete the `[RdUpdateCheck]` lines `CheckedOn` and `DismissedOn` from `portable\Cone\vlc-qt-interface.ini`, or wait a day), open a video and press F at once.
   - The notice shows above the control bar.
   - Escape leaves fullscreen and the notice stays.
   - Tab to its buttons, then Escape on a button = Later.
6. **Offline.** Unplug or disable the network, Check Now: "Could not reach GitHub. Try again later." within 15 s. Quit while it checks: Cone closes at once (the 5 s quit watchdog must not be needed).
7. **Switch off.** Settings > General > Check for updates OFF. The next day's start sends nothing (Windows Resource Monitor > Network, or no notice with a remembered version).
8. **vlc profile** (`build-windows.yml` with brand vlc): VLC's own "Check for updates automatically" row and Help > Check for Updates are there as before; Cone's two rows and the notice are not.
