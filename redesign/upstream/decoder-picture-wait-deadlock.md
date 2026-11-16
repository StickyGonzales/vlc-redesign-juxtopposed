# Draft: VideoLAN bug report (not posted)

Ready to paste into a new issue at https://code.videolan.org/videolan/vlc/-/issues once StickyGonzales
says so. It describes only what was measured on plain VLC 4 (no Cone code in it), written for upstream
readers. (The file name is kept from an earlier draft about a decoder stall during an audio track switch;
that stall was not reproduced, so it is no longer in the report.)

---

**Title:** Windows: quitting takes about 2 s while a video plays (VLC 4.0.0-dev)

**Version:** VLC 4.0.0-dev (master, a build from November 2026), Windows 10 x64, NVIDIA GeForce
RTX 2060, Direct3D11 video output, D3D11VA / DXVA2 hardware decoding (the defaults).

**What happens:** while a video plays, quitting VLC takes about 2 seconds before the process ends.
The window stays on screen during that time.

**Measured** (the process started with `--extraintf=cli --rc-host=127.0.0.1:<port>`, played for a few
seconds, audio track switched every 2.5 s, then `quit` sent on the cli; the time is from `quit` to the
end of the process; 5 rounds per file, a portable configuration):

| File | Quit times (s) |
|---|---|
| HEVC 854x480, 30 fps, 16 B-frames, two AAC tracks (generated with ffmpeg, command below) | 2.13, 2.01, 2.01, 1.88, 1.92 |
| A 1080p x265 film (MKV, one audio track) | 1.94, 1.89, 1.87, 2.13, 2.33 |

The audio track switches themselves played on without a stall in every round.

**Test file:**
`ffmpeg -f lavfi -i testsrc2=size=854x480:rate=30 -f lavfi -i sine=frequency=440 -f lavfi -i sine=frequency=660 -t 30 -map 0:v -map 1:a -map 2:a -c:v libx265 -preset ultrafast -x265-params "keyint=60:bframes=16:b-adapt=0:rc-lookahead=20:ref=6:b-pyramid=1" -tag:v hvc1 -c:a aac hevc-2a.mp4`

**Steps to reproduce:**
1. `vlc --extraintf=cli --rc-host=127.0.0.1:4212 hevc-2a.mp4`
2. After a few seconds of playback, send `quit` on the cli.
3. Time how long the `vlc.exe` process takes to end: about 2 s.

**Expected:** the window goes away at once and the process ends well under a second after the quit.

**Not investigated yet:** which part of the shutdown takes the time (the input and decoder threads,
the video output, the audio output or the interface). (Attach a debug log of one quit, --file-logging --log-verbose=2, when posting.)
