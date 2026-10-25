# Waveform seek bar (P6-06): notes for the PC session

Branch `redesign-waveform`, from `origin/redesign` 0a514865de (2026-10-15). Web session, no VLC build here: nothing in this file is verified on the PC. Every item still needs the build, real screenshots side by side with the Figma PNGs, the UX pass, the performance round and the regression checklist.

## 1. Status

- **Built:**
  - the background scanner (C++, `RdWaveformScanner`);
  - the per-file manager and its cache (C++, `RdWaveform`);
  - the bar drawing item (C++, `RdWaveformItem`);
  - the Playback tab toggle "Show Waveform on Seekbar" (QML, committed).
- **Hooked up on the PC (2026-10-15, wip/next-batch):** the patch of section 5 was applied by hand on the current SliderBar (preview card, right click, endless sliders) and deleted; the review fixes are in BUILD_NOTES.md ("W7.2 waveform seek bar merged"). Before that, the seek bar showed the waveform only after the PC session applied `redesign/WAVEFORM_HOOKUP.patch` (section 5). It touches the shared files `qt.cpp`, `mainui.cpp`, `VLCStyle.qml` and `SliderBar.qml`. Until then, the toggle writes an option VLC does not know yet (nothing happens).
- **Checks on the last commit:**
  - qmlcheck: `errors: 1 files: 369 crashed: 0` (the known HighResolutionTimeWidget stub). Same result with the hookup patch applied. A deliberately wrong property on the new item was caught, so the stubs cover it.
  - buildlists: `0 problem(s)`.
  - privacycheck: `0 problem(s)`. Only the generic checks ran: the web session has no privacy.local.txt, so run it again on the PC.
  - C++ syntax check of the six new files, and of `mainui.cpp` with the patch, against Qt 6.4 headers with `-Wall -Wextra -Wconversion`: no warnings in the new code.
  - moc output of both new QObject headers compiles.
- **Ran here (not verification):**
  - **The real scanner,** linked against a minimal VLC 4 core built from this tree (meson, no external codecs: filesystem access, wav and mp4 demuxers, copy packetizer, araw decoder). Results in section 7.
  - **The real drawing item,** rendered offscreen with Qt 6.4 at 100, 125, 150 and 200 %, next to the Figma "Player - Music" PNG. At 2x the bars land on the same device pixels as Figma.
- **Not run here:** the full compile and link of the Qt module, the runtime QML console, anything on Windows.

## 2. What was built

### Scanner (`player/rd_waveform_scanner.hpp/.cpp`)
- **What it measures.** The loudness of the file's first audio track, over 1000 equal slices of its duration.
  - Each slice gets the RMS of its samples, scaled so the loudest slice is 255.
  - Stored as 1000 bytes.
- **How it decodes.** It opens the file a second time with VLC's own modules, the same ones playback uses: access, demuxer, packetizer and audio decoder. There is no audio output and no clock.
  - The es_out reports only the measured track as selected. Demuxers that can (mp4, mkv) then skip the video: they do not hand it on, but a read from start to end still passes over its bytes (see "Full or sampled").
  - Passthrough decoders (S/PDIF) are refused through the format callback, the same way the core falls back to a sample decoder.
  - Decoder reloads on a format change follow the core's decoder loop.
  - VLC core itself is unchanged; everything uses exported plugin API.
- **Full or sampled (rule of 2026-10-16).** The choice follows what a full scan has to read, not the file size alone.
  - A full scan decodes the file from start to end and gives the exact waveform, but it passes over every byte of the file: the video of an MKV is read through (the demuxer only skips handing it on), and an MP4's audio chunks are spread between the video chunks, so the reads cover most of the file there too. Its cost is the file size, while the audio it needs is a small part of a video file.
  - **Full scan** (exact) when that read is quick:
    - any file up to 32 MiB (`kFullScanMaxBytes`): at most about 1.5 s even on a cold disk shared with playback;
    - a file without video up to 256 MiB (`kAudioFullScanMaxBytes`): music (MP3, AAC, FLAC, WAV, Opus ...), where every byte read is audio the waveform needs and decoding is hundreds of times faster than real time. "Without video" means no video track once the demuxer has opened the file; a still picture track (JPEG, PNG, BMP, GIF, WebP cover or chapter art) does not count. Music files keep the exact waveform, as before.
  - **Sampled scan** for everything else (videos over 32 MiB, audio files over 256 MiB): 0.25 s of audio is decoded in each slice, never more than the slice holds. A 50 GB film costs at most about 1000 seeks, not a full read. A seek may land early: MP4 moves every track to the video keyframe before the time, even with the video unselected. Audio up to 30 s before the stretch (`kMaxPrerollSeconds`, by its timestamp) is not measured, so neighbouring slices of a short video do not all measure the audio at the same keyframe; audio further away (timestamps that do not follow the duration, MPEG-TS) is taken as it comes.
    - **Read in order, seek only when it pays (2026-10-16, sweep fix).** The stretches are measured in order. When a stretch is complete and its audio was where its timestamps say, the next stretch is reached by reading on, and the scan seeks only when the gap to it is longer than both where a seek lands before its target on average (measured on the file: about half a keyframe interval for MP4, the audio read last for an MKV without audio cues) and the 0.2 s warm-up, and never reads on across more than 30 s (slices of files over about 8 h); a seek restarts the stretch it targets. Stretches that touch (a file up to 1000 x 0.25 s = 250 s long) are therefore read once from the start, with one seek.
    - **Dropped before the decoder.** An audio packet that ends more than 0.2 s (`kWarmupSeconds`: AAC overlap and priming, the MP3 bit reservoir, Opus pre-roll) before the stretch never reaches the packetizer: the audio from the keyframe an MP4 seek lands on, and the gap between two stretches read on. Before the first packet decoded after such a gap, the packetizer and decoder are flushed, as after a seek. A packet without a length (MKV SimpleBlock, PES, AVI chunk) is dropped only when it starts 1 s (`kUnknownLengthSeconds`) earlier still. The decoded warm-up is skipped by its timestamp as before.
    - Log: `waveform sampling: seeks N, audio packets dropped before the decoder N of N` after the scan line.
  - A demuxer that announces its tracks only while reading (MPEG-PS): when a video track shows up during the full scan of a file over 32 MiB, the scan starts again sampled (log: `sampled, video found while reading`).
  - Without a known size the file is decoded fully. A file to sample whose demuxer cannot seek gets no waveform (PC review: no full read of a large file).
  - Why (PC test, build 38810713227): the 249 MiB 1080p MP4 and MKV (2:00, H.264 17 Mbit/s + AAC) took the full path under the old 256 MB limit and were not ready within 12 s on a first scan while playing, although the scan alone took 584 ms once the file was in the system's file cache: the cost is the 249 MiB read from disk next to the player's own reads, at the lowest thread priority. The 302 MB 4K clip took the sampled path: 340 ms. Under the new rule both 249 MiB files are sampled. Accepted limit: a QuickTime Photo-JPEG or PNG video counts as a still picture, so such a file up to 256 MiB still gets the full scan (bounded by the 60 s budget).
- **Cancel.** `cancel()` works from any thread. The scan stops within one demuxed packet, and its VLC interrupt context also aborts blocking reads.
  - Measured: a 285 MB scan cancelled after 3, 20 and 200 ms returned within 1 ms of the cancel.
- **No audio.** A file that shows no audio track within 2000 packets stops early.

### Manager and cache (`player/rd_waveform.hpp/.cpp`, QML singleton `RdWaveform`)
- **Nothing runs** until a seek bar holds it: `RdWaveformItem.active`, which the patch binds to "thick bar and option on".
- **Lowest priority.** One worker thread (`QThreadPool`, max 1 thread, `QThread::LowestPriority`). Playback and the UI never wait on it.
- **Cancelled** when the media changes, and when the last seek bar lets go (option switched off).
- **Local files only**, and only once the player knows their duration.
  - Streams, discs and network shares opened as URLs keep the plain bar.
  - A local file opened through a `file://` URL on a network drive is scanned too (see section 8).
- **Cache.** `<VLC user data folder>/waveforms/<sha1>.wf`, about 1 KB per file.
  - The key is the file's absolute path, size and modification time, so an edited file is scanned again.
  - A file with no usable audio is cached as "none", so it is not scanned on every visit.
  - A cache hit refreshes the file's time.
  - The cache version went to 2 with the full / sampled rule of 2026-10-16: files scanned before are scanned again once.
  - After each new entry, the least recently used files beyond 2000 are deleted. That caps the cache at about 2 MB of data.
- **Reopening** a cached file shows the waveform as soon as the worker has read 1 KB. There is no scan.

### Bars (`player/rd_waveform_item.hpp/.cpp`, QML type `RdWaveformItem`)
- **Figma Controls "Property 1=waveform" (2139:8124), "Frame 21":**
  - bars 2 px wide every 5 px, the first 6 px from the left end;
  - bar heights 2 to 14 px in 2 px steps (7 sizes), vertically centered in the 28 px trough;
  - round ends (radius 4 on a 2 px bar = a pill);
  - played bars Dark/Accent/DIm, the others Dark/FG/A4;
  - 3 px free on both sides of the 4x24 playhead.
- **Inputs from QML.** The trough and the playhead stay SliderBar's own Rectangles. The item only draws the bars, and reads the playhead's center and width from the handle.
- **Painting.** The bars are painted once into one texture: a played row and an unplayed row, one sprite per bar height.
  - Two image nodes show the rows cut at the playhead.
  - A moving playhead (playback, dragging) only moves the two cuts, and only when it crosses a bar. No painting, no upload, and no scene graph update between crossings.
  - The texture is painted again only when the size, the screen scale, a color (live accent or theme switch) or the levels change.
- **Whole device pixels at every scale.** Even bars and gaps at 125 % and 150 %, and parity-matched heights so bars stay centered on a pixel.
- **Bar heights.** Each bar takes the mean loudness of the slices under it, and the loudest bar reaches 14 px, so every window width uses the full range.

### Playback tab toggle (`player/qml/PlaybackSettingsPage.qml`)
- **"Show Waveform on Seekbar"**, a 52 px toggle row styled like Show Metadata. Figma has no frame for it; the row is the video's (Decision 13).
- **Position.** First row for now. The video puts it second, under "Show Subtitle Timeline on Seekbar", which does not exist yet.
- **Option.** It writes VLC's `qt-seek-waveform` through RdEffects, like the other option rows. A change from anywhere shows at once.
- **Default off** (VIDEO_INDEX row 146: the toggle is OFF).

### Seek bar layer (in the patch, `SliderBar.qml`)
- A `RdWaveformItem` over the trough in SliderBar's background, active while the bar is thick and the option is on.
- **When the scan is ready:**
  - the bars fade in over 100 ms (`VLCStyle.duration_short`);
  - the plain played fill fades out over the same 100 ms;
  - the playhead narrows from 8 to 4 px around the same center (100 ms).
- **Until then,** the plain bar stays as it is.
- **Unchanged.** The layer takes no input:
  - Seeking, dragging, hover, the preview card, the keys and the right-click menu are SliderBar's, unchanged (the seek bar takes no wheel since Decision 54).
  - The seek to 00:00:00 (417fc21e96) is unchanged: it lives in the FSM and the player, which the patch does not touch.

## 3. VIDEO_INDEX rows covered

Please update their Status after the PC test. Suggested: `in progress (redesign-waveform <hash>, not verified)`.

| Row | Id | What |
|---|---|---|
| 146 | P4-36 | Playback tab toggle "Show Waveform on Seekbar", OFF by default |
| 213 | P6-06 | Waveform seek bar: played part in the accent, the rest grey, playhead; offered as an option |
| 212 | IB-24 | The waveform part of the row: thin bars in the black rounded trough, played in the accent, playhead taller. The 15 s skip buttons in the same row are not part of this branch |
| 210 | P6-05 | Music control bar: its seek bar shows the waveform when the option is on |

Unsure lines 655 and 671 (a second decode pass, cached; streams cannot have one) are answered by sections 2 and 8.

## 4. Decisions (Claude) to add to VIDEO_INDEX.md

One line each:
- P6-06 played bars: Figma's Dark/Accent/DIm (derived from the live accent), not Accent/Main. The playhead stays Accent/Main as in Figma.
- P6-06 bars: a fixed 5 px grid from 6 px. A live playhead cannot shift the bars the way the static Figma frame does, so the bars it overlaps are hidden whole, and the space beside it is 3 to 7 px instead of exactly 3.
- P6-06 heights: RMS loudness per slice, the loudest bar 14 px, 7 sizes (Figma's 2 to 14 in steps of 2).
- P6-06 scans: local files only; full (exact) scan for files up to 32 MiB and files without video up to 256 MiB, all others sampled (0.25 s per 1/1000 of the duration; section 2); cache capped at 2000 files.
- P6-06 switch: the bars fade in over 100 ms when the scan is ready and the playhead narrows 8 to 4 px; on a media change the plain bar shows until the next file's waveform is ready.
- P4-36: the toggle is the Playback tab's first row until the subtitle timeline toggle (P3-16) arrives above it.
- P6-05: the music layout uses the waveform only when the option is on (P6-06 offers it as an option); with it on, the music bar matches Figma "Player - Music".

## 5. PC session hookups

### 5.1 Apply the patch

Run from the repo root:
```
git apply redesign/WAVEFORM_HOOKUP.patch
```
- It applies cleanly on 0a514865de.
- If one of the four files moved on, apply the hunks below by hand.
- Then delete the patch file in the same commit, so it is not applied twice.

### 5.2 `modules/gui/qt/qt.cpp`

Next to the SEEK_THUMBNAILS texts:
```
#define SEEK_WAVEFORM_TEXT N_( "Show waveform on seek bar" )
#define SEEK_WAVEFORM_LONGTEXT N_( "The seek bar draws the audio waveform of the file playing. " \
    "Only for files on this computer: their audio is scanned once in the background and kept in " \
    "the user data folder." )
```
After `add_bool( "qt-seek-thumbnails", ... )`:
```
    /* redesign: waveform seek bar (P6-06; the Playback tab's "Show Waveform on Seekbar": off) */
    add_bool( "qt-seek-waveform", false, SEEK_WAVEFORM_TEXT, SEEK_WAVEFORM_LONGTEXT )
```

### 5.3 `modules/gui/qt/maininterface/mainui.cpp`

Includes, after `player/rd_seek_thumbnailer.hpp`:
```
#include "player/rd_waveform.hpp"
#include "player/rd_waveform_item.hpp"
```
In the `VLC.Player` block, after the RdSeekThumbnailer registration:
```
        // redesign: waveform seek bar (P6-06): the playing file's waveform, and its bars
        qmlRegisterSingletonInstance<RdWaveform>(uri, versionMajor, versionMinor, "RdWaveform",
                                                 new RdWaveform(m_intf, m_intf->p_mainPlayerController, this));
        qmlRegisterType<RdWaveformItem>(uri, versionMajor, versionMinor, "RdWaveformItem");
```

### 5.4 `modules/gui/qt/style/VLCStyle.qml`

After `rd_seekHandleWidth`: the eight `rd_waveform*` tokens.

| Token | Value |
|---|---|
| `rd_waveformBarWidth` | 2 |
| `rd_waveformBarSpacing` | 3 |
| `rd_waveformBarMinHeight` | 2 |
| `rd_waveformBarMaxHeight` | 14 |
| `rd_waveformBarStep` | 2 |
| `rd_waveformPadding` | 6 |
| `rd_waveformPlayheadWidth` | 4 |
| `rd_waveformPlayheadGap` | 3 |

Each is `MainCtx.dp(n, scale)`.

### 5.5 `modules/gui/qt/player/qml/SliderBar.qml`

Four edits, all in the patch:
1. **Properties,** after `scrubPosition`:
   - `_waveformOption`, which reads `qt-seek-waveform` through RdEffects;
   - `waveformShown: waveform.ready`.
2. **`progressRect`:**
   - `visible: (control.thick || !Player.hasChapters) && opacity > 0`;
   - `opacity: control.waveformShown ? 0 : 1`;
   - a 100 ms Behavior on opacity.
3. **The layer,** before `bufferRect` in the background: the `RdWaveformItem { id: waveform ... }` block. It sets:
   - `source: RdWaveform`;
   - `active: control.thick && control._waveformOption`;
   - `playheadX: sliderHandle.x + sliderHandle.width / 2`, plus `playheadWidth` and `playheadGap`;
   - `playedColor: VLCStyle.palette.rdAccentDim`, `unplayedColor: VLCStyle.palette.rdFgA4`;
   - the six bar tokens;
   - a 100 ms opacity fade.
4. **`sliderHandle.implicitWidth`:**
   - `rd_waveformPlayheadWidth` while `waveformShown`, otherwise `rd_seekHandleWidth`;
   - a 100 ms Behavior that is enabled only while the bar is thick. The thin bar keeps its state transitions.

### 5.6 Nothing else

- The build lists already have the six new files.
- The Settings dialog's Playback page (redesign-settings) has no waveform row. If one is wanted there later, it is one more RdEffects option row on `qt-seek-waveform`.

## 6. Files changed

**New:**
- `modules/gui/qt/player/rd_waveform_scanner.hpp`, `.cpp`
- `modules/gui/qt/player/rd_waveform.hpp`, `.cpp`
- `modules/gui/qt/player/rd_waveform_item.hpp`, `.cpp`
- `redesign/WAVEFORM_HOOKUP.patch`
- `redesign/WAVEFORM_NOTES.md`

**Changed:**
- `modules/gui/qt/meson.build`: moc headers and sources.
- `modules/gui/qt/Makefile.am`: sources and `.moc.cpp`.
- `modules/gui/qt/player/qml/PlaybackSettingsPage.qml`: the toggle row.
- `redesign/INTERACTIONS.md`: section 5, the waveform layer.

## 7. Tests run here

### Scanner

The real `rd_waveform_scanner.cpp` was linked against libvlccore built from this tree. The test files were generated: a 1 kHz tone whose loudness rises linearly to the middle and falls back.

| File | Path | Result | Time |
|---|---|---|---|
| WAV, 60 s, 10 MB | full | 1000 slices: 0, 25, 51 ... 255 ... 51, 25 | 12 ms |
| MOV, MJPEG video + PCM audio, 60 s, 21 MB | full; video not read | same profile | 16 ms |
| WAV, 27 min, 285 MB | sampled | same profile | 68 ms |
| WAV 285 MB, cancelled after 3 / 20 / 200 ms | sampled | empty | stopped within 1 ms |
| MOV, video only | full | empty (no audio) | 0 ms |
| random bytes | no demuxer | empty | 0 ms |
| missing file | | empty | 0 ms |

- All runs were repeated under AddressSanitizer with leak detection: no errors, no leaks.
- These are a minimal build's modules. Real files go through avcodec, mkv and so on, on the PC (section 9).

### Bars

Offscreen render of `RdWaveformItem` (Qt 6.4) with the Figma frame's 244 bar heights as levels, compared with "Player - Music.png" (2x):
- The bars start and repeat on the same device pixels (12-15, 22-25, ... at 2x).
- The heights and round ends match.
- At 125 % the bars are 3 device pixels wide with a 6 px pitch (2.5 px cannot be drawn evenly). At 150 % they are 3 px wide with an 8 px pitch.
- This is not verification: the real check is a screenshot of the built VLC.

## 8. Performance risks to measure first (PERF.md)

The marks in VLC's debug log (verbosity 2, added on the PC): `waveform: job started for the playing file` (GUI thread: the option is on and a thick seek bar shows it), `waveform scan (full|sampled|sampled, video found while reading|large, not seekable|not seekable, video found while reading|no duration): levels|no waveform|no waveform, over the time budget|cancelled in N ms` (the scan alone, worker thread; the scan line comes from the libvlc instance, `main libvlc debug`) and `waveform: ready|no waveform from the cache|from the scan, N ms after the job started` (GUI thread: the bars' data arrived). A scan stops after 60 s (`kTimeBudgetSeconds`; the file is then cached as "no waveform"), and quitting waits at most 500 ms for a cancelled one.

1. **The scan while playing a large local video.**
   - The sampled scan seeks through the same file the player reads. On a hard disk, the head moves between both, so watch for dropped frames during the first seconds of a 4K file with the option on.
   - Expected: about 1000 short reads at the lowest thread priority. If it shows, delay the scan start until playback has buffered (a few seconds), or lower the sample count.
2. **The upper bounds of the full path** (section 2): a 32 MiB video and a 256 MiB audio file (a long FLAC or WAV).
   - Measure the time to ready on a first scan (file not in the system's file cache, e.g. after a restart), and CPU while playing.
   - Pass limits (2026-10-16): time to ready at most 2 s for an MP4 and 5 s for an MKV on a first scan, cache reopen at most 100 ms, zero extra dropped frames. The 249 MiB 1080p MP4 / MKV test files now take the sampled path.
   - If a bound is too slow, lower `kFullScanMaxBytes` or `kAudioFullScanMaxBytes`.
3. **Seek bar frame times while playing and dragging,** with the waveform shown: should be the same as the plain bar.
   - Only the cuts move, and only when the playhead crosses a bar.
   - Check QSG_RENDER_TIMING for texture uploads during playback: there should be none.
4. **Window resize:** each new width paints the texture again.
   - That is one sprite blit per bar, about 700 at 4K.
   - Watch the worst frame while dragging the window edge.
5. **Startup and opening a file:** nothing runs while the option is off.
   - With it on, opening a file starts one worker job.
   - Opening a file should stay the same as stock VLC.
6. **A network share** opened as a local path (a mapped drive) is treated as a local file and read a second time. Check that this is acceptable on a slow share.
7. **Sampled scan cost per slice (sweep fix of 2026-10-16, estimate, not measured yet).**
   - The test files (ffprobe): both 2:00, H.264 1080p30 with a keyframe every 8.33 s (x264's default 250 frames), AAC 48 kHz stereo (5 626 packets of 21.3 ms), the audio interleaved every 2 video frames (3 599 audio runs in the file). The 1000 slices are 0.12 s long, so the stretches touch.
   - A simulation of the scan over the files' real packet tables gave the counts below; the costs come from the sweep's times (build 38829058873) and the cached full scan of 2026-10-16 (584 ms for the whole 249 MiB MKV: every block read, all AAC decoded once).

   | File | Before | After |
   |---|---|---|
   | wave_1080p_250MiB.mp4 | 1000 seeks, 198 220 AAC packets decoded (198 per slice: about 4.1 s from the keyframe, 0.12 s kept); about 75 us per packet = about 14 ms per slice; measured 14.9 s / 13.5 s | 1 seek, 5 626 packets decoded once (5.6 per slice): about 0.4 to 0.6 ms per slice, ready in about 0.5 s with the file in the system's file cache (target 2 s) |
   | wave_1080p_250MiB.mkv | 1000 seeks, 6 625 packets decoded: without audio cues every MKV seek resumes at the last audio block read, so the old scan already read the file once from the start; the cost was the 1000 seeks and decoder restarts, about 4.2 ms each; measured 4.8 s | 1 seek, the same single read without the restarts: about 0.6 ms per slice, ready in about 0.6 s cached (target 5 s) |
   | wave_4k60_80mbps_remux.mkv (0:30, 0.03 s slices) | 1000 seeks; measured 2.6 s | 1 seek, one read: about 0.3 to 0.4 s cached |

   - Dropping the packets before the decoder alone (without reading on) would have left the MP4 at about 5 to 7 s: the 198 packets per slice are still demuxed (read from the file, about 30 to 40 % of the 75 us), so the scan also reads on instead of seeking when the stretches are close.
   - Cold disk (file not in the system's file cache): the audio sits every 2 video frames in both files, so reading all of it touches the whole 249 MiB, before and after the fix. The time to ready is then bounded by the disk's read of the file next to the player's reads (seen as more than 12 s once on 2026-10-16 with the old full scan). The fix removes the CPU cost, not this read.
   - Long files (stretches apart), simulated for a 2 h film with the same layout (7.2 s slices): MP4 still seeks for each slice (the gap of 6.95 s is longer than the 4.1 s average lead); the 207 000 packets from the keyframes are demuxed but only 22 000 are decoded (was all 207 000): about 7 s instead of about 15 s cached, plus 1000 disk seeks on a cold disk. MKV without audio cues reads the whole file either way (the seeks never jump forward past what was read); only 22 000 of 338 000 audio packets are decoded now, but the video blocks are still read, so a large MKV film can still reach the 60 s budget on a slow disk. Its log still shows about 1000 seeks: each lands where the demuxer already is (the average lead stays just under the 6.95 s gap), cheap but not reading on. Possible follow-up (not done, needs a PC test): during a long jump, report the video track as selected so the MKV seeker uses the video cues.
   - Retest: the three files with the cache moved aside; the `waveform sampling:` line should show 1 seek for each (a few more if the audio starts after the video: the slices before it seek as before); the shape unchanged (the 2 min hill with its 12 dips, no staircase).

## 9. UX pass and tests for the PC

- **The toggle:**
  - on and off, live, over a playing file, in the sidebar;
  - the bars appear or disappear without a jump in the bar's size;
  - the option survives a restart.
- **Timing:**
  - first open of a file: the plain bar, then the bars fade in;
  - reopen: the bars show at once.
- **Media switching:**
  - next and previous in the queue cancel the old scan;
  - each file shows its own waveform;
  - rapid next/next/next leaves no stale waveform.
- **Seek bar behavior, all unchanged with the waveform shown:**
  - seeking, dragging (also past both ends), hover;
  - the preview card;
  - wheel, arrow keys, Shift-precise drag;
  - the right-click menu;
  - a seek to 00:00:00;
  - chapters (the thick bar does not draw chapter segments today).
- **Live colors:**
  - every accent color recolors the played bars at once;
  - the light theme uses Light FG/A4 and the light Accent/DIm.
- **Scaling:**
  - 100, 125 and 150 % Windows scaling: even bars, no blur;
  - fullscreen and a narrow window (the seek bar minimum is 76 px: no bars below about 14 px).
- **Media types:**
  - audio only (the music layout);
  - a video with several audio tracks (the first track is measured);
  - a file with no audio (plain bar);
  - a stream (plain bar);
  - a very long file (sampled).
- **Side by side:**
  - the music layout against "Player - Music.png" and "Player - Music-1.png";
  - the video bar against Controls "Property 1=waveform".

## 10. Not done, or limits

- **Not verified on the PC, nothing.** No runtime QML console here.
- **The audio track** is the first audio track of the file, not the track selected in the player. Following the selected track would need a rescan per track. That is possible, but the video does not show it.
- **No progressive drawing:** the bars appear when the whole scan is ready, as asked. A long full scan shows the plain bar until then.
- **Streams, discs and remote URLs** never get a waveform (VIDEO_INDEX line 671).
- **Real codecs** (MP3, AAC, FLAC, Opus, AC-3, DTS and so on) were not run here: the minimal build has no avcodec. The decoder path is the core's, so they should behave like the araw decoder. Check a few on the PC.
- **The prototype's click on the seek row** that toggles the waveform (FIGMA_FLOWS line 23) is a demo shortcut and was not built. The option is the real trigger.
