# No VLC position slider after a seek (branch wip/hide-osd-seek-slider)

Branch `wip/hide-osd-seek-slider`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. **Core change** (Decision 27, minimal and isolated): `src/player/osd.c`, Cone build only (`VLC_BRAND_PUBLIC`); the vlc profile is unchanged. Built on its own branch, not mixed with interface changes.

## The bug
- **Reported by StickyGonzales** (screenshot, and a screen recording of a fullscreen episode with seeks): after a seek (dragging the seek bar or jumping with the keys), once the control bar hid, a thin progress line in the accent color stayed over the bottom of the video, its played part brighter and the rest dimmer.
- **The recording** was gone through frame by frame (10 frames per second, the bottom of every frame searched for the line's colors). It shows the episode in fullscreen and the jumps of the seeks, but neither the line nor the bars. The capture held only the video layer.

## What draws it
- **VLC's own on-screen position slider**, not Cone's seek bar:
  - On every seek, `vlc_player_osd_Position()` (src/player/osd.c, called by the player's seek by time and by position, src/player/input.c, and by src/player/player.c) shows the message "time / length".
  - In fullscreen it also shows `vouts_osd_Slider(..., OSD_HOR_SLIDER)`.
- **The slider** (src/video_output/video_widgets.c, `OSDSlider`) is orange `0xf48b00`. Its played part is drawn at alpha 0xA0 over a track at alpha 0x25 ("played part brighter, rest dimmer"). It is a horizontal line 1 % of the video height tall, 10 % in from each side, at the bottom of the window.
- **Why it stood out:**
  - VLC's orange is close to Cone's default accent (#D37918), so it looked like a leftover of Cone's seek bar.
  - It shows only in fullscreen and stays for the OSD duration after the seek, so it is noticed once the control bar has hidden.

## The fix
- **Cone build:** `vlc_player_osd_Position()` no longer shows the slider. Cone's control bar already shows the position.
- **Kept:** the on-screen "time / length" message of a seek, and the shortcut line under it ("Pressed →", Cone's OSD messages).
- **Unchanged:**
  - the vlc profile;
  - the volume's vertical slider in fullscreen (only the position slider was reported).

## Checks
- `privacycheck.py`: 0 problems. No QML or build list change.

## Runs
| Run | Head | Result |
|---|---|---|
| build-windows #177 (run 41536473026) | 35dfd8d437 | green, smoke included |
| build-linux #80 (run 41536478323) | 35dfd8d437 | green, smoke included |

## Windows retest (PC session)
Build: the build-windows run of this branch (or `gh workflow run build-windows.yml --ref wip/hide-osd-seek-slider`), Cone (portable), a landscape test video.
1. **Keys in fullscreen.** Play, press F for fullscreen, keep the mouse still. Press → a few times, then wait until the control bar hides: the message "time / length" shows at the top and fades, no orange line over the bottom of the video.
2. **Seek bar drag in fullscreen.** Move to the bottom edge, drag the seek bar, let go, move the mouse away so the bar hides: no orange line.
3. **Click on the seek bar** (fullscreen and windowed): no line, the message shows.
4. **Windowed.** The same with the keys in a window (VLC showed the slider only in fullscreen): no line, as before.
5. **Volume.** Volume up/down in fullscreen: as before (message, and VLC's vertical volume slider on the right).
