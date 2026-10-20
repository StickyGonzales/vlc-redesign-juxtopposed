# Quit hang on Windows: where it is stuck (branch wip/quit-hang-cause)

Branch `wip/quit-hang-cause`, from `origin/wip/next-test`, draft pull request into `wip/next-test`. PC session, 2026-10-20 (handed over by StickyGonzales). Analysis only: no code change yet; the safety net is PR #34 (wip/quit-watchdog).

## The hang
The PC's recipe on <TEST_MOVIE> (1080p HEVC, software decoding): every sidebar slider dragged, then the delay / speed / volume / seek / v / b key loops, then the window's close button. Cone's window goes, the process stays (75-108 threads, responding). It hung 6 of 6 runs on builds with and without PR #32 (runs quit8-r1 2026-10-19, quit8-fix-r1, quit8-p32-r1 2026-10-20 and the earlier bisect runs).

## What the stacks show (dump of run quit8-p32-r1, build 39415673284)
- **vlc-qt is idle** in its event loop (win32u!NtUserMsgWaitForMultipleObjectsEx): the interface is not blocked.
- **Main thread** waits in Cone.exe: the interface never asked to quit, because the window close stops playback first and asks to quit only on "stopped" (`MainCtx::onWindowClose`), and "stopped" never comes.
- **vlc-player-end** waits in `vlc_cond_wait`: the player's destructor thread waiting for the stopping input to end. The libqt_plugin.dll addresses on its stack (+0x43C2F5, +0x22EEFA0, +0x2423CE0) are stale values the stack scan picks up, not live frames: the earlier reading "a BlockingQueuedConnection into the interface" (FIX_QUIT_DEADLOCK_NOTES.md, PR #32) does not hold, which is why #32 changed nothing.
- **vlc-input** (mkv demux) waits on a condition in the decoder / es_out code (near `vlc_input_decoder_SetSpuHighlight` / `input_resource_Release` exports): the input thread cannot finish stopping because a decoder does not return.
- **vlc-dec-video is inside libavcodec**, and all nine HEVC frame threads (`av:hevc:df0`..`df8`) wait (ZwWaitForAlertByThreadId, libavcodec frames only). vlc-dec-audio waits in the WASAPI output, vlc-vout in its normal timed wait, vlc-spu-prerend idle.
- The release build has no debug information (the `.dbg` files objcopy keeps are 872 bytes, no symbol table, no DWARF), so frames can only be named by the nearest export.

## Test: frame threading off
Same build, same recipe, `--avcodec-threads=1` (no frame threads): **2 of 2 runs quit cleanly** (0.78 s and 0.68 s), against 6 of 6 hangs with the default threading (up to 10 threads for HEVC, `modules/codec/avcodec/video.c`).

## Conclusion so far
The quit waits on the HEVC software decoder: with frame threading, a frame thread stays blocked and the decoder never returns during the input's stop, so the input, then the player, then the quit wait for good. The likeliest wait is a frame thread inside `get_buffer2` (`lavc_GetFrame` > `decoder_NewPicture`) waiting for a picture buffer that the stopped or paused video output never hands back, while the decoder's flush / close waits for that frame thread. The trigger in the recipe is the speed slider (the bisect on 2026-10-18: Speed alone plus the key loops hangs; sliders alone and keys alone do not): many rate changes followed by seeks and track switches.

Not a Qt bug, and not the window callbacks: the fix belongs in the core's decoder / picture pool teardown (`src/input/decoder.c`, the avcodec module), which is a core change (Decision 27: approved where needed, own build).

## Not done yet (next steps)
1. Stock VLC 4 (build 38315049322) with the same film and a key-only version of the recipe (`]` / `[` held to drive the rate, then the same loops): if it hangs too, it is upstream VLC 4 (report it there and carry a minimal fix).
2. A build with debug information for the Qt plug-in and libvlccore (`-g` reaching the link, the `.dbg` uploaded): one hang run, then the exact frames of vlc-input and vlc-dec-video.
3. Then the fix in the decoder's abort path (cancel the picture-pool wait before flushing / closing a frame-threaded decoder), in its own build, retested with the recipe 4 times.
4. Not a fix: `--avcodec-threads=1` or `low-delay` as a default would make 4K HEVC stutter (slice threading only).

Until then PR #34's watchdog ends a stuck quit after 5 s.
