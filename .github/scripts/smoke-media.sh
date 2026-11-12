#!/bin/sh
# Test media of the Windows smoke checks (win64-smoke.ps1): 30 s, 480p30 with a 440 Hz tone, as
# H.264 and HEVC MP4 (a keyframe every 2 s), an HEVC MP4 with two audio tracks, subtitles over the whole length, and a small show of
# three episodes (the Up Next card). Generated, so
# nothing personal and nothing copyrighted is used.
#   smoke-media.sh <out dir>        (FFMPEG: the ffmpeg to use, "ffmpeg" by default)
set -eu
OUT="$1"
FFMPEG="${FFMPEG:-ffmpeg}"
mkdir -p "$OUT"
SRC="-f lavfi -i testsrc2=size=854x480:rate=30 -f lavfi -i sine=frequency=440:sample_rate=48000 -t 30"
# shellcheck disable=SC2086
"$FFMPEG" -v error -y $SRC -c:v libx264 -preset veryfast -crf 32 -pix_fmt yuv420p -g 60 -c:a aac -b:a 96k "$OUT/test-h264.mp4"
# shellcheck disable=SC2086
"$FFMPEG" -v error -y $SRC -c:v libx265 -preset veryfast -crf 34 -pix_fmt yuv420p -x265-params "keyint=60:log-level=error" \
    -tag:v hvc1 -c:a aac -b:a 96k "$OUT/test-hevc.mp4"
# HEVC with 16 B-frames in a row (deep picture reordering, the hardest case for the decoder's
# picture pool) and two audio tracks (440 and 660 Hz, eng / deu): the audio track switch check
# (win64-smoke.ps1 / linux-smoke.py) switches between them while the video plays
"$FFMPEG" -v error -y -f lavfi -i testsrc2=size=854x480:rate=30 -f lavfi -i sine=frequency=440:sample_rate=48000 \
    -f lavfi -i sine=frequency=660:sample_rate=48000 -t 30 -map 0:v -map 1:a -map 2:a \
    -c:v libx265 -preset ultrafast -crf 34 -pix_fmt yuv420p \
    -x265-params "keyint=60:bframes=16:b-adapt=0:rc-lookahead=20:ref=6:b-pyramid=1:log-level=error" \
    -tag:v hvc1 -c:a aac -b:a 64k -metadata:s:a:0 language=eng -metadata:s:a:1 language=deu "$OUT/test-hevc-2a.mp4"
i=0
: > "$OUT/test.srt"
while [ $i -lt 10 ]; do
    s=$((i * 3)); e=$((s + 3))
    printf '%d\n00:00:%02d,000 --> 00:00:%02d,000\nSmoke test subtitle %d\n\n' $((i + 1)) "$s" "$e" $((i + 1)) >> "$OUT/test.srt"
    i=$((i + 1))
done
# a show of three 7-minute episodes (Up Next: the card shows in the last minute, its Next
# episode button is checked, win64-smoke.ps1 / linux-smoke.py); small and quiet, 320x180 at 15 fps
SHOW="$OUT/Smoke Show"
mkdir -p "$SHOW"
for e in 1 2 3; do
    # shellcheck disable=SC2086
    "$FFMPEG" -v error -y -f lavfi -i testsrc2=size=320x180:rate=15 -f lavfi -i "sine=frequency=$((300 + e * 100)):sample_rate=48000" \
        -t 420 -c:v libx264 -preset veryfast -crf 36 -pix_fmt yuv420p -g 150 -c:a aac -b:a 48k "$SHOW/Smoke Show S01E0$e.mp4"
done
ls -la "$OUT" "$SHOW"
