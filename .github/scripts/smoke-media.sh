#!/bin/sh
# Test media of the Windows smoke checks (win64-smoke.ps1): 30 s, 480p30 with a 440 Hz tone, as
# H.264 and HEVC MP4 (a keyframe every 2 s), and subtitles over the whole length. Generated, so
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
i=0
: > "$OUT/test.srt"
while [ $i -lt 10 ]; do
    s=$((i * 3)); e=$((s + 3))
    printf '%d\n00:00:%02d,000 --> 00:00:%02d,000\nSmoke test subtitle %d\n\n' $((i + 1)) "$s" "$e" $((i + 1)) >> "$OUT/test.srt"
    i=$((i + 1))
done
ls -la "$OUT"
