# Windows smoke checks on GitHub (branch wip/ci-smoke)

Branch `wip/ci-smoke`, made from `origin/wip/next-test` (a0a81e77f9). Draft pull request into `wip/next-test`. CI only: no change to Cone itself.

## 1. What runs, and when
After **every public Windows build**:
- pushes to `redesign`
- manual `build-windows` runs with brand `public`
- release builds

Each runs a `smoke` job on a GitHub **Windows runner**. A failed check fails the run, with an error naming the check. Builds of the vlc profile are not checked.

| File | What it is |
|---|---|
| `.github/workflows/build-windows.yml` | new `smoke` job after `win64`, calls the reusable workflow below |
| `.github/workflows/smoke-windows.yml` | the reusable workflow: `smoke-media` (Linux, makes the test media) and `smoke` (Windows, runs the checks) |
| `.github/workflows/smoke-windows-manual.yml` | the same checks by hand on an earlier build run's artifacts (they last one day): Actions > smoke-windows-manual > Run workflow > the build run's id |
| `.github/scripts/smoke-media.sh` | the test media: 30 s 480p30 with a tone, as **H.264** and **HEVC** MP4, plus a 10-cue SRT; generated, nothing personal or copyrighted |
| `.github/scripts/win64-smoke.ps1` | the checks (UI Automation and Win32 input, like `redesign/tools/perf/vlcperf.ps1`; playback state from VLC's cli interface on 127.0.0.1) |

**Results artifact:** `cone-smoke-results`, one day. It holds:
- `summary.md`, also shown on the run's summary page
- `smoke-log.txt`
- Cone's own log of each session
- the screenshots

On a release run the checks gate the release: `release.yml`'s release job waits for the whole build workflow, the smoke job included.

## 2. The checks
Each check that fails runs once more. Every retry is listed under "Retries" in the summary, with the first attempt's error.

**Portable zip.** The zip from the build gets a `portable` folder next to `Cone.exe`, as a user would make one. Then two sessions run, one per codec (H.264, HEVC). Each starts Cone with the video and `--sub-file`, then checks:

| Check | How | Pass |
|---|---|---|
| main window appears | a visible Qt window of the Cone process | within 30 s |
| playback time advances | cli `get_time`, 3 s apart | the second time is later |
| subtitle file loads | cli `strack` | a subtitle track is selected (`*`) |
| seek bar responds | the "Progress" slider found through UI Automation, a real mouse click at 75 % of its width | the time is 75 % of the length (within 3 s or 10 %) |
| Settings opens | Ctrl+P | the "Global Settings" page appears in the UI Automation tree within 8 s; Escape closes it |
| quit | Ctrl+Q | see below |

**Quit, H.264:**
- **Pass:** the process ends in under 3 s, without the quit watchdog.
- **Fail:** the watchdog's log line ("quit watchdog: Cone did not finish quitting"), or 3 s or more.

**Quit, HEVC:** the known HEVC quit stall (STATUS.md).
- **Warning, not a failure:** a quit the watchdog ends (after its 5 s). The summary and the run show it as a warning.
- **Fail:** Cone still runs 10 s after Ctrl+Q, so the watchdog did not end it.

**Quit retry:** a failed quit is retried in a **new session** of the same file (start, play 4 s, Ctrl+Q), because the first attempt already ended Cone.

**Portable settings:**
- After the H.264 session, `portable\Cone\vlc-qt-interface.ini` must exist.
- `%APPDATA%\Cone` must not have been created.

**Installer:**

| Check | How | Pass |
|---|---|---|
| silent install | `coneplayer-*-win64.exe /S` | exit code 0, `C:\Program Files\Cone\Cone.exe`, the uninstall entry `HKLM\...\Uninstall\Cone` |
| the installed Cone plays | one H.264 session: window, time advances, quit | as above |
| silent uninstall | `uninstall.exe /S _?=<dir>` | exit code 0, `Cone.exe` and the uninstall entry gone. Files left in the folder are a warning, listed in the summary |

**A missing build artifact:** the build uploads the zip and the installer with continue-on-error (Actions storage can be full). The smoke job then stops with an error naming the missing artifact.

## 3. What it does not cover (still a person)
- **Picture and sound:** the runner has no GPU and no sound card, and Cone renders in software there. Nothing checks how the video looks (colours, scaling, HDR, tearing), that subtitles are drawn, or what sound comes out.
- **Hardware decoding** (D3D11VA / DXVA) and GPU video output: the runner decodes in software.
- **Look and motion:**
  - matching Figma and the video
  - animations and hover states
  - fonts at 125 / 150 % scaling
  - the light theme and the accent colours
- **Performance:** frame times, CPU and RAM against stock VLC (`redesign/PERF.md`, `vlcperf.ps1`).
- **Real mouse use:**
  - drag and drop (Customize Player, drag to the queue)
  - the seek bar drag
  - the volume cone
  - the wheel
  - the right-click menus
- **Everything else in the interface:**
  - the library and the media library scan
  - network streams
  - Add Subtitles / OpenSubtitles
  - presets, the sidebar tabs, the tracks popup
  - Up Next, the update notice
  - the mini player, the onboarding
- **Long files, big queues, 4K, other formats** (MKV, AVI, DVD, audio-only), several audio and subtitle tracks.
- **The installer's interactive pages:** language, the options page, the "Run Cone" box, the Start menu and desktop shortcuts, file associations, an upgrade over an older Cone, an install next to VLC.
- **Windows versions other than the runner's** (Windows Server 2022/2025 image, one screen, 100 % scaling, an administrator account).

The PC session's on-PC tests stay for all of these; the smoke checks replace only its routine start / play / seek / settings / quit / install round.

## 4. Runs
(filled in below)
