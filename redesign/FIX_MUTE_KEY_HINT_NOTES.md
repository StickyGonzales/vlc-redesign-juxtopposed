# "Pressed M" when muting (branch wip/fix-mute-key-hint)

Branch `wip/fix-mute-key-hint`, made from `origin/wip/next-test`. Draft pull request into `wip/next-test`. **Core change** (`src/player/osd.c`), Cone build only; per the repo rules, in its own build.

## Cause
A shortcut's on-screen message names its key on a second line ("Pressed C"; video 15:23-15:28; `src/video_output/video_text.c`). That line is added to **text** messages only. Muting showed only VLC's mute icon (`OSD_MUTE_ICON`), a picture without text, so M never got the line. Unmuting shows "Volume: 45%", a text message, which did get it.

## Fix
In the public build, muting shows the text message **"Muted"**, the same message box as the volume's. Pressed with M, it reads "Muted / Pressed M". The vlc profile keeps the icon.

**Decision (Claude):** a message, not the icon plus a message. Both on the same OSD channel would replace each other, and the message matches the other shortcuts (volume, speed, tracks) in Cone.

## Runs
| Run | Result |
|---|---|
| build-windows #146 (41253477223), this branch | build and **all smoke checks pass** |
| build-linux #53 (41253486005), test-only `wip/test-linux-small-fixes` | in the sandbox: M shows "Muted" with "Pressed M"; M again "Volume: 100%" with "Pressed M". Picture: `redesign/fix-shots/mute_key_hint.jpg` |

Checks: `src/player/osd.c` syntax check in both profiles. privacycheck 0.

## Windows retest (PC session)
Play a video.
1. Press **M**: top right, "Muted" with "Pressed M" under it, for the "Show feedback for" time.
2. Press **M** again: "Volume: N%" with "Pressed M".
3. Click the mute button in the control bar: "Muted" without the "Pressed" line (no key).
4. Mute from the menu or the system mixer: "Muted" without the "Pressed" line.
