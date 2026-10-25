#!/usr/bin/env python3
"""Generates the Up Next test media (redesign/UP_NEXT_TEST.md): show folders in every naming
style the parser reads, a season 2 subfolder, an Extras folder, music and a podcast that must
never count, and a single movie. Needs ffmpeg on PATH.

    python redesign/tools/upnext_media.py <target folder>

Everything is generated (colour bars and a tone); the target folder is created and replaced.
"""

import os
import shutil
import subprocess
import sys
import tempfile


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", *args], check=True)


def video(path, seconds, hue, credits_at=None):
    """A 320x180 colour-bar video with a tone; `credits_at` adds an "Episode" and a "Credits"
    chapter (Settings > Playback > Show Up Next = When the credits start)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        plain = os.path.join(tmp, "plain.mkv")
        ffmpeg("-f", "lavfi", "-i", f"testsrc2=size=320x180:rate=10,hue=h={hue}",
               "-f", "lavfi", "-i", f"sine=frequency={300 + hue}:sample_rate=22050",
               "-t", str(seconds), "-c:v", "libx264", "-preset", "ultrafast", "-crf", "40",
               "-g", "100", "-c:a", "aac", "-b:a", "24k", plain)
        if credits_at is None:
            shutil.move(plain, path)
            return
        meta = os.path.join(tmp, "chapters.txt")
        with open(meta, "w", encoding="utf-8") as f:
            f.write(";FFMETADATA1\n")
            f.write(f"[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND={credits_at * 1000}\ntitle=Episode\n")
            f.write(f"[CHAPTER]\nTIMEBASE=1/1000\nSTART={credits_at * 1000}\nEND={seconds * 1000}\ntitle=Credits\n")
        ffmpeg("-i", plain, "-i", meta, "-map_metadata", "1", "-map_chapters", "1", "-c", "copy", path)


def audio(path, frequency):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    ffmpeg("-f", "lavfi", "-i", f"sine=frequency={frequency}:sample_rate=22050", "-t", "150",
           "-b:a", "32k", path)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    root = os.path.abspath(sys.argv[1])
    if os.path.exists(root):
        shutil.rmtree(root)
    j = os.path.join

    # SxxEyy, season folders, a Credits chapter at 2:45 of 3:00, an Extras folder
    wand = j(root, "The Wand")
    video(j(wand, "Season 1", "The Wand S01E01 - The First Light.mkv"), 180, 0, 165)
    video(j(wand, "Season 1", "The Wand S01E02 - The Second Spark.mkv"), 180, 40, 165)
    video(j(wand, "Season 1", "The Wand S01E03 - The Third Door.mkv"), 180, 80, 165)
    video(j(wand, "Season 2", "The Wand S02E01 - A New Term.mkv"), 180, 120, 165)
    video(j(wand, "Season 2", "The Wand S02E02 - Old Friends.mkv"), 180, 160, 165)
    video(j(wand, "Extras", "Making of The Wand.mkv"), 180, 200)
    # 1x01
    for n, title, hue in ((1, "Pilot", 220), (2, "The Storm", 240), (3, "Low Tide", 260)):
        video(j(root, "Harbor Lights", f"Harbor Lights 1x0{n} - {title}.mkv"), 150, hue)
    # "Episode 1"
    for n in (1, 2, 3):
        video(j(root, "Cartoon Time", f"Cartoon Time Episode {n}.mkv"), 150, 260 + 20 * n)
    # plain numbers: weak, so 4 files of 10 minutes; the folder gives the title
    for n in (1, 2, 3, 4):
        video(j(root, "Night Garden", f"{n:02d}.mkv"), 610, 30 * n)
    # music and a podcast named like episodes: audio never counts
    for n, name, freq in ((1, "Opening", 330), (2, "Middle", 360), (3, "Closing", 390)):
        audio(j(root, "Music", "Paper Moon", "Second Album", f"0{n} {name}.mp3"), freq)
    for n in (1, 2, 3):
        audio(j(root, "Podcasts", "Talk Hour", f"Talk Hour S01E0{n}.mp3"), 390 + 30 * n)
    # a single movie
    video(j(root, "Movies", "Starfall (2010).mkv"), 200, 340)

    for folder, _, files in sorted(os.walk(root)):
        for name in sorted(files):
            print(os.path.relpath(os.path.join(folder, name), root))


if __name__ == "__main__":
    main()
