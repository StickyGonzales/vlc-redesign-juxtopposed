# Testing the redesign builds yourself

## The easy way: the launcher
Double-click **"Test VLC Redesign.bat"** on the Desktop (a copy of `redesign/tools/test-latest.bat`).

It:
1. finds the newest **successful** build of the `redesign` branch on GitHub Actions,
2. downloads it into `<TEST_MEDIA_DIR>\builds\<run number>` (skipped if that run is already there),
3. sets it up in portable mode (a `portable` folder next to `vlc.exe`, so it never touches the installed VLC's settings; your test settings stay between runs of the same build),
4. starts it.

If something is wrong it says so and waits for a key: "gh" not installed, not logged in (run `gh auth login` once in a terminal), no successful build yet (a build takes about 50 minutes after a push), or a download problem (builds are kept for 14 days).

Windows may show a **Windows Security Alert** (firewall) for this vlc.exe the first time: VLC opens network features at startup. **Cancel** is fine for testing.

## Manual fallback
1. Go to https://github.com/StickyGonzales/vlc-redesign-juxtopposed/actions, open the newest green "build-windows" run of the `redesign` branch.
2. Under **Artifacts**, download `vlc-redesign-win64` (a zip).
3. Unzip it into its own folder, e.g. `<TEST_MEDIA_DIR>\builds\<run number>`.
4. Inside `vlc-4.0.0-dev`, create an empty folder named `portable` (keeps the test settings inside that folder).
5. Double-click `vlc-4.0.0-dev\vlc.exe`.

## What is new and worth testing
- **Player screen**: top bar (cone, "...", sidebar toggle, folder chip, title), control bar (play pill, thick seek bar, cone volume 0-200 %, time labels: click the remaining time to switch, click a time to type a position), rounded inset video frame, resume toast ("You already watched till ...", no prompt if you watched to the last 20 s).
- **Bars**: in a window both bars appear when the mouse moves over the player and fade 3 s after it stops; in fullscreen each bar appears when the mouse is near its edge and fades after about 1 s.
- **Tracks popup** (video / audio / subtitle buttons): tabs, None row, Show Preferences.
- **Settings sidebar** (gear): Playback, Video, Audio, Subtitles tabs; sliders, value boxes (click to type), equalizer with presets, filters ("Expand Settings"), "Open Advanced Settings" at the bottom.
- **Queue sidebar** (list button): Queue, Bookmarks, Chapters tabs; select + remove, double-click to play, drag the handle to reorder, sort / repeat / shuffle / add.
- **Main menu** ("..." at the top left): Open File(s), Folder, Network Stream, Disc, Capture Device, Convert, Open Recent, Keyboard Shortcuts, Customize Player, Settings, About.
- **Right-click menu** on the video: Play, Stop, Previous, Next, Record, Hide UI (Ctrl + \ also toggles it; on the Hungarian layout that is Ctrl + AltGr + Q), Playback / Video / Audio / Subtitle submenus, More Settings, Playlist, Open Media, Quit.
- **Settings dialog** (Ctrl + P, the main menu, or "Open Advanced Settings"): categories, search, info (i) popovers, Advanced Options. Most categories still say their settings are in "All VLC Settings" (the pages are the next work package); Subtitles has the first real options.
- **Keyboard Shortcuts** (main menu): search, click a field and press the new key, conflicts, right-click a field, Save. New shortcuts work after restarting VLC (VLC loads them at startup).
- **Open dialogs**: Open Network Stream (Ctrl + N: links, optional playlist name, Save), Open File(s) / Disc / Capture Device / Convert (restyled, one source each).
- Keys inside menus and dialogs (Escape, arrows, typing) must go to the menu or dialog, not to the player.

## Not in this build yet (please do not report these)
- The **library** (Videos, Music, Playlists, Network streams, Home, Recent, pins, mini player): built separately on the `redesign-library` branch, merged later.
- **Step 2 features**: seek preview thumbnails, subtitle timeline and waveform on the seek bar, sleep timer, statistics / metadata panels, per-show presets ("Default Preset"), Ctrl + B instant bookmark, Add Subtitles dialog, OSD showing the pressed key, profiles, new Customize Player controls, onboarding, light theme polish.
- The Settings dialog's category pages (only the shell and the Subtitles example are there).
- Customize Player still opens VLC's existing toolbar editor (its redesign is W8.1).

## Reporting a bug
Open https://github.com/StickyGonzales/vlc-redesign-juxtopposed/issues/new/choose, pick **Bug report**, and fill in what you did, what happened, what you expected, a screenshot, windowed or fullscreen, and which file you played. The run number of the build is the folder name under `<TEST_MEDIA_DIR>\builds`.
