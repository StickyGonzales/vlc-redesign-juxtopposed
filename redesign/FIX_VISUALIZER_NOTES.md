# Audio visualizer: quit hang #3, white window, window title (branch wip/fix-visualizer)

Branch `wip/fix-visualizer`, made from `origin/wip/next-test` (9290edc6b2). Pull request into `wip/next-test`.

**This is a core change** (`modules/video_output/win32/window.c`, `include/vlc_config.h` and the X11 / Wayland window modules are outside `modules/gui/qt`), so it gets its own build and test before the merge (Decision 55, build rounds rule). Nothing here is verified on Windows yet.

## 1. Does PR #32 cover this hang? No
PR #32 changes how the **Qt** video window (the one inside Cone's main window) is disabled. That fix was about a player thread parked inside libqt_plugin.dll.

This hang is different. The PC's dump (STATUS.md, session visdelay, `hang-4960.txt`) shows:
- **Main thread:** in `vlc_player_Delete`, joining `vlc-player-end`.
- **`vlc-player-end`:** waiting in the core, with no Qt frame. It is joining the input thread.
- **`vlc-input` (MKV demux):** waiting on a condition in the decoder / ES output path. It waits for a decoder that never answers.

The audio visualizer's video output never uses the Qt window. Cone's single Qt window is already taken by the film's video, so VLC gives the visualizer a window of its own from its Windows window module (`modules/video_output/win32/window.c`). PR #32 does not touch that window.

## 2. Cause (code reading; not reproducible in the Linux sandbox)
Each visualizer output gets its own window. That window has its own message thread (`vlc-window-win`).

1. Right after it creates the window, that thread reads the monitor's colour profile (ICC) and hands it to the video output (`MonitorChanged` → `UpdateICCProfile` → `vlc_window_ReportICCProfile` → `vout_ChangeIccProfile`). That call takes the output's **display lock**.
2. At the same moment, the audio decoder thread starts that output. `vout_Start` opens the Direct3D11 display in the new window **while holding the same display lock**. Opening a display in a window that belongs to another thread can need that thread to answer window messages (the display's child window and the DXGI swap chain).
3. When the two meet, each waits for the other for good:
   - The window thread stops answering messages, so Windows shows the window **blank white**.
   - The audio decoder stays blocked, so the input thread waits for it.
   - At quit, the player thread waits for the input thread and `vlc_player_Delete` waits for the player thread, as in the dump.

**Why it needs the visualizer and `b`:** the visualizer creates this window, and every audio track switch (`b`) restarts the audio filters. Each restart closes the visualizer output and creates a new one with a new window, so every `b` is a new chance for the race. The PC saw the white window right after `b`, then the hang at quit.

**Why not on Linux:** on X11, opening a display never waits for the window's own thread (the X server answers, not a message loop), so the same report cannot block it. On Windows the window module's size reports already go through a timer (`wasync_resize_compressor.h`) for this same kind of reason; the colour profile report did not. In the sandbox (3 runs of the recipe with Spectrometer, 40 × `h`, `b`, close; X11, once with VLC's plain X11 video output) Cone exited in 0.5 to 0.8 s every time. With the sandbox's software OpenGL the visualizer's display does not open (libplacebo refuses a software renderer), so the visualizer itself is not drawn there.

This is upstream VLC 4 code. Cone did not change the window module before this branch.

## 3. Fix
- **ICC profile from a timer thread.** `modules/video_output/win32/window.c` no longer hands the colour profile to the output from the window's message thread. The window thread keeps only the latest profile and fires a timer, and the timer thread hands it over (the same way window size reports are already sent). The window thread no longer waits for the display lock, so the display can always open.
- **Window close.** Close stops the timer, waiting for a report in progress, and frees a profile still waiting.
- Both profiles (vlc and public).
- **Check:** `window.c` compiles without warnings for Windows (mingw-w64 GCC, `-Wall -Wextra`, syntax check).

## 4. Window title (item 2)
**The titles before this branch:**
- Windows: the visualizer's window is titled `VOUT_TITLE " (Direct3D11 output)"`, which reads "VLC (Direct3D11 output)" (first "VLC (VLC Video Output)" until the display opens).
- Linux X11 and Wayland: "VLC media player".

**The change, public profile only** (`#ifdef VLC_BRAND_PUBLIC`):
- `VOUT_TITLE` is "Cone" (`include/vlc_config.h`).
- New `VOUT_OUTPUT_TITLE(output)`: just "Cone" in the public profile, VLC's "VLC (<output>)" in the vlc profile. Windows uses it everywhere it names a window: the window module's own window (`win32/window.c`, `win32/events.c`) and the Direct3D11, Direct3D9, OpenGL and WinGDI displays. So the visualizer window reads exactly **"Cone"** on Windows (StickyGonzales, 2026-10-20).
- X11 and Wayland windows read "Cone".
- The vlc profile is unchanged: "VLC (Direct3D11 output)" and the other VLC titles.
- **Checks:**
  - mingw-w64 syntax check of `window.c`, `events.c`, `direct3d9.c` and `wingdi.c` in both profiles: no warnings.
  - The two files that need the full Windows build environment (`direct3d11.cpp`, `glwin32.c`): their title lines are checked by preprocessing, giving "Cone" in the public profile and "VLC (Direct3D11 output)" / "VLC (OpenGL output)" in the vlc profile.

The blank white window is the stopped window thread of section 2. The same fix covers it.

## 5. Sandbox (Linux)
- **Test build:** build-linux 39420013501 of the test-only branch `wip/fix-visualizer-linux` (wip/next-test + this branch + the Linux build job; never merge it). It compiles, including the X11 and Wayland window modules with the public brand.
- **Before:** build-linux 39313634848 (wip/next-test + #32).
- **Window title (X11):**
  - Before: Spectrometer opens a separate 800 × 500 window titled "VLC media player".
  - After: the same window is titled "Cone".
  - Its picture is not drawn in the sandbox (software OpenGL, see section 2).
- **The recipe** (Spectrometer, 40 × `h`, `b`, window close), 3 runs: exit in 2.76, 0.47 and 0.47 s (before: 0.82, 0.58 and 0.49 s). No hang. The 2.8 s run is once in three; watch the quit time in the Windows retest.
- **Main window after `b`:** the same as before (screenshots compared).
- **The ICC change** is Windows-only code, so it only compiles for Windows: syntax check above, and the Windows build of this branch.

## 6. Retest on Windows
Use a build of this branch alone (core change), the test folder of the visdelay session, and the generated MKV with two audio tracks and the .srt. Before each run, check that no Cone is left running. Stop at the first hang.
1. **The hang recipe.** Play the MKV, sidebar > Playback > Audio Visualizer > Spectrometer, `h` 40 times, `b`, close the window. Cone must exit within about 2 s. Run it 4 times.
2. **The visualizer window after `b`:** it keeps drawing the spectrum (no white window). Press `b` 10 more times, about 1 s apart: it draws after each one.
3. **Its title** (title bar and taskbar) reads exactly "Cone" (the main window's title is unchanged).
4. **Other visualizers.** Scope, then VU meter, then Disabled: each window opens and draws, Disabled closes it, and quit exits.
5. **Moving the window:** drag the visualizer window to a second monitor if there is one. It keeps drawing (the colour profile is sent from the timer now).
6. **If it still hangs:** keep the process and capture every thread's stack. The `vlc-window-win` and `vlc-dec-audio` frames are the ones that matter.
