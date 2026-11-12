# Quit stalls and the HEVC audio-switch stall

Branch `wip/fix-quit-stalls`. Draft pull request into `wip/next-test`. StickyGonzales, 2026-11-12. **Core change** (src/, include/): it is built and tested on its own branch.

## 1. The two known issues
1. **Slow quit:** closing Cone sometimes takes up to 5 s, until the quit watchdog ends it. It is worst on some HEVC files. Example: the PC's quit recipe with the 1080p x265 film (software decoding), STATUS.md 2026-10-25/26, where 1 to 2 quits in 3 were ended by the watchdog.
2. **Audio switch stall:** on a few HEVC files with many B-frames, switching the audio track can stall the video, and quitting then takes 5 s.

## 2. Whose bug: VLC 4 core
- **Where it blocks.** Both issues are the same wait inside VLC's core, and Cone's interface is not part of it. The PC's thread dumps (STATUS.md 2026-10-20/25) show a libavcodec frame thread in `picture_pool_Wait()` ← `ModuleThread_NewVideoBuffer()` (src/input/decoder.c) ← `decoder_NewPicture()` ← `lavc_GetFrame()`, and the decoder thread inside `avcodec_send_packet()` waiting for that frame thread.
  - `picture_pool_Wait()` cannot be interrupted.
  - A **flush** only sets a flag. The decoder thread serves it once `pf_decode` returns, and it cannot return while its frame thread waits for a picture. An audio switch flushes every decoder (`ES_OUT_RESET_PCR`), and the input then waits for the video decoder's first picture, so the video stands still.
  - **Close** (`vlc_input_decoder_Delete`) joins the decoder thread *before* it releases the video output. The pictures the frame thread waits for sit in the video output's queue, and they only come back when shown or flushed, which does not happen while the input stops. So the join waits, and the quit hangs until the watchdog.
  - Upstream's own surface wait (`va_pool_Get`, commit 1fe351861a6) assumes that "on Flush or Close the decoder will release all the past pictures". Flush and Close run on the very thread that is stuck.
- **Reproduction with the plain VLC 4 build** (the vlc profile, no Cone interface): this needs Windows, because the stall only shows on the PC's decoding setup.
  - On Linux (software decoding, 5 and 16 frame threads, `--intf=dummy`), the same clip played through 7 switches with no stall and quit in 0.3 s.
  - The verdict above comes from the code and the PC's thread dumps. Section 5 step 1 confirms it on the PC with `vlc.exe` from build-windows #229 (vlc profile, `wip/next-test`, no fix) and `redesign/tools/quit-stall-repro.ps1`.
  - A stall or watchdog quit there is **VLC 4 core**. If only Cone shows it, it is **ours (Cone)**, and the fix below is not enough.
- **A wrong turn, corrected:** on the MKV copy of the clip, VLC logs `find KaxCues FIXME ... EOF` after a switch, and this looked like the playback ending 50 s early.
  - It does not end early: the clip is 60 s long and plays 60.3 s with or without a switch.
  - The warning is the normal end of the file. It is not a bug, and no report was filed for it.

## 3. The fix (core, in the fork)
| File | Change |
|---|---|
| `include/vlc_picture_pool.h`, `src/misc/picture_pool.c`, `src/libvlccore.sym` | `picture_pool_Cancel(pool, bool)`: while a pool is canceled, `picture_pool_Wait()` returns NULL instead of blocking, and canceling wakes the threads already waiting. |
| `src/input/decoder.c` | **Flush:** the video decoder's pool is canceled when the flush is requested, so a waiting frame thread gets NULL, its frame fails (it is flushed anyway) and the decoder thread reaches the flush. The pool is resumed once the decoder thread has flushed (and in the synchronous path), unless the decoder is being deleted. **Delete:** the pool is canceled and the video output flushed (`vout_FlushAll`) *before* the decoder thread is joined, so the queued pictures (and their D3D11 surfaces) go back and every wait ends. |
| `src/input/decoder.c` (pool creation) | A pool created while the decoder flushes or stops (a format change in that moment) starts canceled, like the one it replaces. |
| `src/test/picture_pool.c` | Unit test: a canceled empty pool returns NULL, a thread already waiting wakes up on cancel, and the pool works again after the cancel is lifted. |

**Limit:** with D3D11VA / DXVA2, a frame thread can also wait for a hardware surface (`va_pool_Get`, a semaphore wait in modules/codec/avcodec/va_surface.c), and the pool cancel does not wake that wait. Flush and Delete both flush the video output first, which hands back the surfaces its queued pictures hold. A stall remains possible only if libavcodec's own reference frames use up every surface. The fork already sized the HEVC surface pool for that (16 + 2 + 2, frame threads counted twice: 9323061a32, fea8ac6d03, 883156a0ad). Section 5 runs on the PC's hardware decoding to cover this case, which the CI runners (software decoding) cannot.

Nothing in the Qt interface changes. The VideoLAN report draft is `redesign/upstream/decoder-picture-wait-deadlock.md` (not posted).

## 4. Checks
| Check | Where |
|---|---|
| New media `test-hevc-2a.mp4`: 30 s, 480p HEVC with 16 B-frames in a row (b-adapt 0, b-pyramid, ref 6), two AAC tracks 440 / 660 Hz (eng / deu) | `.github/scripts/smoke-media.sh` |
| **New smoke check, Windows** (`Check-AudioSwitch`): 6 audio track switches 2.5 s apart; after each, the time must change (the file repeats). Then Ctrl+Q must end Cone without the quit watchdog, in **under 3 s on the runner**. The runner's limit is the H.264 quit check's 3 s because its software rendering alone takes 1.5 to 2 s for a clean quit (#231: H.264 1.6 s, HEVC 2.01 s, installed H.264 1.48 s). The 2 s target is measured on the PC (section 5). | `.github/scripts/win64-smoke.ps1`, build-windows smoke |
| **New smoke check, Linux** (`check_audio_switch`): the same steps on the tarball, quit under 2 s | `.github/scripts/linux-smoke.py`, build-linux smoke |
| The existing quit and HEVC smoke checks (quit within 3 s, HEVC quit by the watchdog a warning) | unchanged |
| PC script: the same switches and quit through the cli, for any exe | `redesign/tools/quit-stall-repro.ps1` |

Runs (filled in below as they finish):

| Run | What | Result |
|---|---|---|
| build-windows #227, #228, build-linux #120 | the first commit (5c798eb) | cancelled after the review, rebuilt below |
| build-windows #231 (43223628366), fe9ff5a | Cone (public), this branch, with the new smoke check | compiled. Smoke: every check passed but one. The new check: playback moved after all 6 switches (3->7, 8->12, 12->16, 17->21, 22->26, 27->1); the quit took 2.16 s, no watchdog, over the then 2 s limit. The runner's own clean quits in the same run: 1.48 to 2.01 s. Limit set to 3 s on the runner (above). |
| build-windows #232 (43223634851), fe9ff5a | vlc profile, this branch | **green** |
| build-windows #229 (43222935921) | vlc profile, `wip/next-test` (no fix): for the classification on the PC | running |
| build-linux #121 (43223640964), fe9ff5a | Linux, this branch, with the new smoke check | **green**. Ubuntu 24.04: 6 switches, the time moves after each (4->10, 10->17, 17->23, 24->0, 0->7, 7->13), quit 0.16 s; every other check passed (H.264 quit 0.26 s, HEVC 0.16 s). Ubuntu 22.04, Debian 12 and the Wayland / X11 embed checks green too. |

## 5. Windows retest (PC session)
Use the HEVC test media: the generated `test-hevc-2a.mp4` (the build's smoke-media artifact, or `smoke-media.sh`) and the x265 film of the quit recipe (<TEST_MOVIE>). Run every step once; close everything after.
1. **Whose bug.** Unzip #229's vlc-profile zip (no fix) into `<TEST_MEDIA_DIR>\builds\vlc-nofix`. Run:
   `powershell -File redesign\tools\quit-stall-repro.ps1 -Exe <TEST_MEDIA_DIR>\builds\vlc-nofix\vlc.exe -Video <file> -Rounds 5`
   on both files, then the same with the released Cone 1.3.x `Cone.exe`. Note per round: stalls, quit seconds, watchdog. A stall or a quit of 2 s or more with `vlc.exe` means **VLC 4 core**. Write the verdict for each issue into STATUS.md.
2. **The fix, plain VLC:** the same script with #232's `vlc.exe` (vlc profile, with the fix): no stall in any round, every quit under 1 s.
3. **The fix, Cone:** deploy #231 into `builds\current`, then run the script with its `Cone.exe` on both files, 5 rounds each. Expect no stall, every quit under 1 s, no `did not finish quitting` in the logs.
4. **By hand in Cone (#231):**
   - Open the x265 film and switch the audio track in the tracks popup 5 times while it plays: the picture keeps moving each time.
   - Then close with the window's X: the window and the process are gone within 1 s.
   - Repeat with Ctrl+Q.
5. **Regression:**
   - Seek back and forth on both files.
   - Pause, switch the audio track while paused, resume: the picture and sound continue.
   - The previous-frame key (if bound) still steps back.
   - Subtitle track switching.
   - An H.264 file plays and quits as before.

## 6. Independent review
A fresh subagent reviewed the full diff. It found no crash or deadlock in the core change: every new access is under the fifo lock, Delete during a flush cannot undo the cancel, and every `decoder_NewPicture()` caller handles NULL. Fixed from its findings:
- A pool made during a flush or stop now starts canceled.
- The Delete comment no longer claims to wake the hardware surface wait. The limit is written down in section 3.
- The new quit checks keep the first attempt's failure as the result. Before, the retry reported "already exited".
- The Linux track wait no longer fails on a cli that is not up yet.
- The PC script keeps going after a failed round and writes the summary after every round.
