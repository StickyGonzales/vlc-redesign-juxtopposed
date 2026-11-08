# Cone for macOS (branch wip/macos-build)

Branch `wip/macos-build`, kept up to date with `origin/wip/next-test` (merged 2026-11-08, no conflicts). Draft pull request into `wip/next-test`. CI only: no change to Cone's code. Nothing is released by this branch. Every release tag prepares a macOS **draft** that StickyGonzales publishes by hand, or never.

## What it is
- **Cone Player.app** (the public profile, Cone's redesign) in a `.dmg`, for **Apple Silicon** Macs (M1 and later) and **Intel** Macs, macOS 12 or later.
- Two .dmg files, `Cone-<version>-macos-arm64.dmg` and `Cone-<version>-macos-x86_64.dmg`.
  - Both are built on GitHub's macOS runners by `build-macos.yml` on every run: `macos-15` for Apple Silicon, `macos-15-intel` for Intel.
  - A manual run can leave Intel out.
  - Intel's first build had no compiler cache and took about 2 h 40 min; later builds reuse the cache.
- **Signed ad hoc** (no Apple developer account): it runs, but macOS asks once before opening it (see "Opening an unsigned app").

## How it is built
| File | What it does |
|---|---|
| `.github/workflows/build-macos.yml` | the build: contribs, Qt, ccache, build, package, artifact, test-builds asset; then the smoke checks |
| `.github/scripts/macos-build.sh` | VLC's own macOS steps (`extras/package/macosx/build.sh`): extra tools, contribs, configure, make, make install |
| `.github/scripts/macos-package.sh` | `Cone Player.app` and the `.dmg` |
| `.github/workflows/smoke-macos.yml` | the smoke checks on a second, clean macOS runner |
| `.github/scripts/macos-smoke.py` | the checks |

**Contribs.** VideoLAN's prebuilt macOS contribs of exactly this source (`artifacts.videolan.org/vlc/macos-arm64/vlc-contrib-aarch64-apple-darwin19-<sha>.tar.zst`), found the same way the Windows build finds its own (`extras/ci/get-contrib-sha.sh`). They hold FFmpeg, the media library, libass, x264/x265, dav1d and the rest. Without a prebuilt set (a contrib change of our own), they are built from source and cached.

**Qt.** VideoLAN's macOS contribs build no Qt (VLC's own macOS app has a native interface), so Qt **6.8.3** (the version Cone bundles on Windows) comes from Qt's own macOS binaries (`aqtinstall`, with Qt Shader Tools for the interface's shaders), cached between runs.

**The interface.** VLC's macOS configure options (`extras/package/macosx/configure.sh`) with `--disable-macosx` (no native interface: Cone's design is its only interface, Decision 63), `--enable-qt`, `--disable-sparkle` (no VLC updater; Cone has its own update notice), `--disable-debug`, `--with-brand=public`. Upstream VLC already runs the Qt interface on macOS (on the main thread, as Cocoa requires: `modules/gui/qt/qt.cpp`) and embeds the video with the "platform" compositor. No core change was needed.

**The app** (VLC.app's layout from `extras/package/macosx/package.mak`, without the native interface):
- `Contents/MacOS/Cone Player` (VLC's macOS binary, `bin/darwinvlc.m`), `vlc-preparser`, `vlc-qt-check`;
- `Contents/Frameworks/`: `libvlc*.dylib`, `plugins/` (every plug-in, flat), the Qt frameworks;
- `Contents/PlugIns/`: Qt's own plugins (Cocoa platform, macOS style, image formats, SVG icons);
- `Contents/Resources/`: `qt.conf`, `qml/` (the Qt Quick modules the interface imports), `share/` (Lua scripts, HRTFs, translations), `cone.icns` (Cone's logo);
- `macdeployqt` copies Qt into the app and rewrites the load paths; the package step fails if anything still loads Qt from the build machine;
- the plug-in cache is generated (`vlc-cache-gen`);
- every binary is signed ad hoc, then the frameworks, then the app; `codesign --verify --deep --strict` must pass.

**Its own settings.** Bundle identifier `io.github.stickygonzales.coneplayer`: VLC's core keeps its files in `~/Library/Preferences/io.github.stickygonzales.coneplayer/` and `~/Library/Application Support/io.github.stickygonzales.coneplayer/` (`src/darwin/dirs.m` names them after the bundle), the interface in `~/Library/Preferences/com.cone.vlc-qt-interface.plist`. An installed VLC is never touched.

**The .dmg:** `Cone-<version>-macos-arm64.dmg`, with `Cone Player.app`, a link to Applications and `COPYING.txt` (the GPL). Plain, without VLC's background picture (it shows VLC's cone).

**Where to download a test build:** the run's artifact `cone-macos-arm64` (one day), or the asset `wip-macos-build--macos-arm64.dmg` on the draft pre-release `test-builds` (redesign/TEST_BUILDS.md). Never a release.

## Releases: a Mac .dmg with every release
`release-macos.yml` runs on every release tag:
- `vX.Y.Z` (the Windows release);
- `linux-vX.Y.Z[-label]` (the Linux release);
- `macos-vX.Y.Z[-label]` (macOS alone).

What it does:
- **Guard.** Only commits on `redesign` (verified code), as the Windows and Linux releases.
- **Build.** It builds both .dmg files with `build-macos.yml`, smoke checks included. A release build never touches the test-builds draft.
- **Draft.** It prepares a **draft pre-release** `macos-v<version>`, "Cone <version> for macOS (experimental preview)", with both .dmg files and `SHA256SUMS.txt`. The notes say which file is for which Mac and how to open an app without a Developer ID.
- **Shared draft.** The Windows and the Linux tag of one version refresh the same draft. A published release is never changed.
- **Never published.** Nothing is public until someone presses Publish on the Releases page. The draft's tag is created only then.

## Smoke checks (after every macOS build)
On a second, clean runner of each architecture (`macos-15`, `macos-15-intel`), with the Windows and Linux checks' test media (`smoke-media.sh`: 30 s H.264 and HEVC MP4, an SRT file). Each failed check runs once more. Results artifacts: `cone-macos-smoke-results-arm64` and `-x86_64` (summary, log, each Cone start's own log, screenshots, VLC's snapshots).

What the runner cannot always confirm is a **warning**, not a failure, so the run stays green on runner quirks:
- **"Settings opens" and "Escape closes Settings":** synthetic keys reach Qt's window unreliably there. Both are on the tester list.
- **A slow HEVC quit on the Intel runner:** 3.2 to 3.5 s, while Cone still quits by itself (as the HEVC quit on Windows and Linux).

A Cone that exits by itself is reported as such, with its own log. Its retry starts a fresh session.
- **dmg:** it opens, holds the app and the Applications link; the app copies out (`ditto`, as a Finder drag).
- **Signature:** `codesign --verify --deep --strict` passes; the name and the bundle identifier are Cone's.
- **Gatekeeper** (information only): `spctl` rejects it, as every app without a Developer ID; the reason testers open it once with right-click > Open.
- **Two sessions (H.264, HEVC):**
  - the main window appears (CoreGraphics' window list);
  - the playback time advances (VLC's cli interface on a Unix socket);
  - H.264 only: the subtitle file loads (`strack`); **Cmd+P** opens Settings and **Escape** closes it (real key events; the dialog is looked for in the app's accessibility tree when the runner allows this process to read it, otherwise the middle of the window must change and change back);
  - **Cmd+Q** quits in under 3 s (HEVC: a quit the watchdog ends is a warning, as on Windows and Linux);
  - no "cannot load plug-in" line in Cone's log.
- **Settings folders:** Cone's own, VLC's untouched.

What a runner cannot check: picture quality, sound (VLC's dummy audio output), real mouse use of the controls (there is no accessibility access to drive the interface the way the Windows and Linux checks do), Retina scaling on a real display, and Gatekeeper's first-open prompt.

## Results
Smoke checks on GitHub's `macos-15` runner (Apple Silicon, macOS 15.8, a virtual machine), the last runs:

| Check | Result |
|---|---|
| dmg opens, holds the app, the Applications link and COPYING.txt; the app copies out | pass |
| ad-hoc signature verifies (`codesign --verify --deep --strict`); bundle `io.github.stickygonzales.coneplayer`, "Cone Player" | pass |
| Gatekeeper | rejected, as expected for an app without a Developer ID (information) |
| main window | pass, 1.1 to 2.3 s |
| H.264 and HEVC: the playback time advances | pass, both |
| subtitle file loads | pass |
| Cmd+P opens Settings | the dialog opened in runs 6 and 7 (screenshots); see "Runs" for the check itself |
| Cmd+Q | pass, under 3 s |
| every plug-in loads (388) | pass; the plug-in cache is current (no "stale plugins cache" line since run 7) |
| own settings folders, VLC's untouched | pass |
| picture (information) | black in the middle of the video, with hardware **and** software decoding; the subtitles and the interface draw |

![Cone on the macOS runner](fix-shots/macos-runner.png)

## What works, what doesn't
**Works (on the runner):**
- Cone's redesign as the interface: top bar, control bar with the seek bar, the subtitle, Settings (Global Settings: theme, accent, startup, diagnostics), the library's Home page.
- Playback of H.264 and HEVC (time advances), external subtitles, quitting, every plug-in, Cone's own settings folders next to an installed VLC.
- The .dmg, the app bundle, its ad-hoc signature and its Cone icon.

**Not known yet / to check on a real Mac:**
1. **The video picture.** On the runner it stays black (VLC's macOS video output `samplebufferdisplay`, embedded by the Qt interface's "platform" compositor), also with software decoding, while the subtitles drawn into the same video show. The runner is a virtual machine with a paravirtual GPU (Qt also could not create an OpenGL context there), so this is most likely the runner. **The first thing a tester checks.**
2. **Escape in Settings** and keyboard shortcuts in general: the runner delivers synthetic keys unreliably to Qt's window (the first Cmd+P after the local network prompt was lost; Escape did not close Settings in one run).
3. **The local network prompt:** macOS asks once whether Cone may find devices on the local network (VLC's UPnP / Bonjour discovery for the Network view); Info.plist now gives the reason. Declining it only empties the Network view.
4. **The update notice:** Settings shows "Check for updates" On. Cone's checker looks at the Windows / Linux releases; there is no macOS release, so a Mac build should not point to one. Left as is in this experimental build (a code change, not CI); to be decided before any macOS release.
5. **Not built:** Sparkle (VLC's macOS updater), VLC's native macOS interface (Cone's design is the only interface), the fancy .dmg background (VLC's shows VLC's cone). Intel is built on every run since 2026-11-08.

## The black picture: the runner, not Cone (run 10, both architectures)
On both runners the video area stays black while Cone's interface and the subtitles draw:

![Cone on the runner, run 10](fix-shots/macos-runner-run10.png)

Each of VLC's macOS video outputs was tried on the same H.264 file, with a screenshot of the window and VLC's own snapshot of the decoded picture. Colour is the mean spread between red, green and blue in the middle (the test pattern: far above 40; black: 0).

| Setup | Video output | Screen | Decoded picture (VLC snapshot) |
|---|---|---|---|
| Default (hardware decoding) | `samplebufferdisplay` (AVSampleBufferDisplayLayer, Metal) | black (0) | **colourful** (238 Intel; arm64 not saved) |
| Software decoding | `samplebufferdisplay` | black (0) | **colourful** (239 arm64, 237 Intel) |
| `--vout=samplebufferdisplay --force-darwin-legacy-display` | none: "no vout display modules matched" | black | none |
| `--vout=caopengllayer` | none: "Failure to create CGL context!" | black | none |
| `--vout=macosx` | none: "Initialization of open gl view failed" | black | none |
| `--vout=gl` | none: no OpenGL display module | black | none |
| `-I dummy` (no Qt, VLC's own window) | none: macOS's video window needs an application object, which the dummy interface does not create (`wdummy`: nothing to see) | black | none |

**What it shows.**
- **Decoding is fine.** VLC's snapshots of the decoded frames are the full test pattern, with hardware and with software decoding.
- **Only the display is black.** The one video output that opens on the runner is `samplebufferdisplay`, Apple's AVSampleBufferDisplayLayer on Metal.
- **No OpenGL on the runner.** The runners are virtual machines with Apple's paravirtual GPU ("Metal device: Apple Paravirtual device"). They have no OpenGL at all: Qt's OpenGL context fails, and so do the three OpenGL outputs.
- **A missing scaler.** Every start logs "IOServiceMatching failed for: AppleM2ScalerParavirtDriver". That is the hardware scaler service AVSampleBufferDisplayLayer uses to put video on screen, and it is missing in the virtual machine.
- **Conclusion.** The same output and the same embedding (Qt's "platform" compositor, as upstream VLC uses on macOS) cannot draw video on this virtual GPU. This is the runner, most likely, not Cone. Only a real Mac can confirm it: the first step of the tester list.
- **The one oddity.** "blending YUVA to CVPN failed" (the subtitles blended into the picture buffer) shows on the runner too. If a real Mac shows the picture but not the subtitles, that is where to look.

## Opening an unsigned app (for testers)
Cone Player for macOS has no Apple Developer ID, so macOS says it "cannot be opened because Apple cannot check it for malicious software" the first time. Either way below works once; after that it opens normally.

**Right-click > Open (easiest):**
1. Open the `.dmg` and drag **Cone Player** onto **Applications**.
2. In Applications, **right-click** (or Control-click) **Cone Player** and choose **Open**.
3. In the warning, click **Open**.
   - macOS 15 (Sequoia) and later: if the warning has only **Done** / **Move to Trash**, click **Done**, then go to **System Settings > Privacy & Security**, scroll down to "Cone Player was blocked", click **Open Anyway**, and confirm with your password.

**Terminal (one command):** removes the download's quarantine flag from the app:
```
xattr -dr com.apple.quarantine "/Applications/Cone Player.app"
```

## Test list for a volunteer tester (about 15 minutes)
Any Mac with macOS 12 or later: the `-macos-arm64.dmg` for Apple Silicon (M1 and later), the `-macos-x86_64.dmg` for Intel. Note the Mac model and the macOS version; for each step, "works" or what happened (a screenshot helps).
1. **Install and open:** drag Cone Player to Applications, open it with right-click > Open (see above). The dark Cone window appears.
2. **The picture (most important):** drag an MP4 and an MKV onto the window. Do you see the video, not a black area? Sound?
3. **Controls:** pause, seek on the seek bar, volume, fullscreen (button and F, Escape back).
4. **Subtitles:** a video with an .srt of the same name: they show and can be switched.
5. **Settings:** Cmd+P opens Settings; Escape closes it; a changed theme is kept after quitting.
6. **Quit:** Cmd+Q quits within a few seconds.
7. **Anything odd:** a crash (copy the first 40 lines of macOS's report), a freeze, cut-off text, blurry text on a Retina display.

## Runs
| Run | Head | What it showed / what changed |
|---|---|---|
| build-macos #1 | 0477d8adb2 | bootstrap failed: Homebrew's folder (with python3) on the build PATH made extras/tools take Homebrew's autotools and pkg-config → Homebrew kept off the PATH |
| #2 | acaf70691b | VLC compiled; the ncurses plug-in's link lost the system libraries: VideoLAN's prebuilt contribs name their build machine's SDK (MacOSX26.2.sdk) in their .pc / .la files → pointed at the runner's SDK |
| #3 | 21d7718077 | **the whole build passed** (Qt interface, 388 plug-ins); packaging: `bin/vlc-cache-gen` is libtool's wrapper script, macdeployqt copied QtSql's database drivers → the installed generator, no SQL drivers |
| #4 | 905d859d99 | signing failed: `plugins.dat` (data) unsigned under Contents/Frameworks → signed inside out, as `extras/package/macosx/codesign.sh` |
| #5 | 3b86520509 | **build, app, signature and .dmg green** (97 MB); first smoke run: window, H.264, HEVC, subtitles, Cmd+Q, plug-ins, own folders pass; Settings failed (the local network prompt held the keyboard); "stale plugins cache" (signing changed the plug-ins after the cache) |
| #6 | cd3ba554cb | cache made after signing; prompt dismissed; Settings opened (screenshot) but Qt's content is not in the runner's accessibility tree; cache still stale |
| #7 | 544027e979 | `cp -R` into the .dmg did not keep the files' times (VLC checks them to the second) → `ditto`; cache current; Settings opened in the picture, Escape did not close it |
| #8 | 22e9f4c8e4 | the 30 s test video had ended before the Settings check (Cone on its Home page) → the video repeats (`--input-repeat=50`, as on Linux) |
| #10 | 1d030deb4b | merged `wip/next-test`; **both architectures built** (Apple Silicon 43 min; Intel 2 h 40 min, its first build, no compiler cache). Smoke: Apple Silicon passes everything except one HEVC session, which exited by itself (code 0) after its window appeared, its log overwritten by the retry; Intel passes everything except the HEVC quit (3.22 s, then 3.46 s, limit 3 s). The video output tries (section "The black picture"). Then: each start its own log, the time check's retry in a fresh session, the HEVC quit time a warning, VLC's snapshots kept |
| #9 | a559a4a7ca | build, app, signature and .dmg **green** (the latest .dmg: artifact `cone-macos-arm64` of run 41346080677, and `wip-macos-build--macos-arm64.dmg` on the test-builds draft); the smoke job **never started**: it waited about 15 minutes for a free macOS runner and was cancelled without running a step |

## State (2026-11-08)
- **Mergeable:** `wip/next-test` merged in; the draft PR into `wip/next-test` is up.
- **Built:** Apple Silicon and Intel on every run; a draft macOS release with every release tag (`release-macos.yml`).
- **Smoke:** both architectures. What the runner cannot confirm is a warning.
- **The black picture:** the runner's virtual GPU (section above), to be confirmed on a real Mac.
- **Open for a real Mac (the tester list):** the picture, Escape in Settings, the local network prompt, the update notice (it looks at the Windows and Linux releases; to be decided before a macOS release is published).
