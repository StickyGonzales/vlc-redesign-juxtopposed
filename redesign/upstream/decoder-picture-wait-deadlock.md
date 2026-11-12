# Draft: VideoLAN bug report (not posted)

Ready to paste into a new issue at https://code.videolan.org/videolan/vlc/-/issues once StickyGonzales says so. It describes what we found in VLC 4 (master) and the fix the Cone fork carries (branch `wip/fix-quit-stalls`), and it is written for upstream readers. Nothing in it names Cone's interface, because the bug is in the core.

---

**Title:** decoder: a video decoder waiting in picture_pool_Wait() blocks flush and close (stalled video after a track switch, slow or hung quit)

**Version:** VLC 4.0.0-dev (master), Windows 10/11 x64. Software decoding with frame threads, and D3D11VA.

**Summary**

`ModuleThread_NewVideoBuffer()` (src/input/decoder.c) gets its picture with `picture_pool_Wait()`. That wait cannot be interrupted. With frame threading, libavcodec calls `get_buffer2` (lavc_GetFrame → `decoder_NewPicture()`) from its frame threads, while the decoder thread waits inside `avcodec_send_packet()` for those threads. While a frame thread is blocked in `picture_pool_Wait()`:

1. **Flush (`vlc_input_decoder_Flush`)** only sets `flushing` and signals the fifo. The decoder thread serves the request after `pf_decode` returns, which only happens once a pool picture is free again. Any picture that does not come back on its own therefore stalls the video decoder. The input then waits in `vlc_input_decoder_Wait()` for the first picture after the flush, and the video stands still while the audio of the new track starts. This is what we see after an audio track switch on HEVC with deep B-frame reordering (16 B-frames, `sps_max_dec_pic_buffering` 7 and up): the switch goes through `ES_OUT_RESET_PCR`, which flushes every decoder.
2. **Close (`vlc_input_decoder_Delete`)** sets `aborting`, signals and then joins the decoder thread. The pictures the decoder waits for are held by the video output's queue, and the video output releases them only when they are displayed or flushed. It does neither while the input is stopping, and `DeleteDecoder()` (which would release them) runs only after the join. So the join can take seconds, or it never returns. A frontend's quit then hangs, and our interface has to end the process after 5 s.

Commit 1fe351861a6 ("avcodec: va: wait indefinitely until a surface is available") made the hardware surface wait unbounded on the same assumption, that "on Flush or Close the decoder will release all the past pictures/surfaces". Flush and Close run on the decoder thread, though, and that thread is the one that is stuck.

**Steps to reproduce** (Windows, a multi-core PC)

1. Make a test file: `ffmpeg -f lavfi -i testsrc2=size=854x480:rate=30 -f lavfi -i sine=frequency=440 -f lavfi -i sine=frequency=660 -t 30 -map 0:v -map 1:a -map 2:a -c:v libx265 -preset ultrafast -x265-params "keyint=60:bframes=16:b-adapt=0:rc-lookahead=20:ref=6:b-pyramid=1" -tag:v hvc1 -c:a aac hevc-2a.mp4`. A real 1080p x265 film with B-frames shows it too.
2. `vlc --extraintf=cli --rc-host=127.0.0.1:4212 hevc-2a.mp4`
3. From the cli, switch the audio track a few times (`atrack 1`, `atrack 2`, ...), 2 s apart, and check `get_time` after each switch.
4. Close VLC (`quit`, or close the window) and time how long the process takes to end.

**Expected:** after each switch the time moves on, and VLC quits in well under a second.

**Actual:** now and then the time stands still after a switch (the video is stuck and the audio of the new track plays, or nothing does). The quit then takes seconds, or does not end. The thread dump shows a frame thread in `picture_pool_Wait` ← `ModuleThread_NewVideoBuffer` ← `lavc_GetFrame`, and the decoder thread in `avcodec_send_packet`.

**Proposed fix** (the patch we carry)

- `picture_pool_Cancel(pool, bool)` (it existed in VLC 3 in a similar form): while a pool is canceled, `picture_pool_Wait()` returns NULL instead of blocking, and canceling wakes the threads already waiting. A unit test is in src/test/picture_pool.c.
- `vlc_input_decoder_Flush()` cancels the video decoder's pool. The decoder thread resumes the pool after it has flushed (`DecoderThread` flush branch, and the synchronous path). A frame thread that was waiting gets NULL, its frame fails (it is flushed anyway) and the decoder thread reaches the flush.
- `vlc_input_decoder_Delete()` cancels the pool and flushes the video output (`vout_FlushAll`) **before** joining the decoder thread. The queued pictures (and with them their hardware surfaces) go back to their pools, so the frame threads and `va_pool_Get()` wake up and the join returns.

Files: include/vlc_picture_pool.h, src/misc/picture_pool.c, src/libvlccore.sym, src/input/decoder.c, src/test/picture_pool.c.
