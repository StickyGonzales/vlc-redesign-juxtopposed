#!/usr/bin/env python3
# Privacy check before every commit/push (run from the repo root):
#   python redesign/tools/privacycheck.py            files changed against the upstream base
#   python redesign/tools/privacycheck.py --staged   only what is staged
# Fails (exit 1) when a changed file contains a personal path, an e-mail address other than a
# noreply one, or a word from the private list, or when a file from the designer's video (frames,
# transcript, video) is tracked. The private list lives in redesign/tools/privacy.local.txt (one
# regular expression per line, gitignored): it holds the owner's names, folders and file names,
# which must never be committed themselves.
import os
import re
import subprocess
import sys

BASE = "a5538c557d276378d5ba0f8f8010a8b87eaa6f78"   # upstream VLC commit the redesign starts from
HERE = os.path.dirname(os.path.abspath(__file__))

GENERIC = [
    r"[A-Za-z]:\\Users\\",                  # Windows user folders
    r"[A-Za-z]:/Users/",
    r"/c/Users/",
    # aur@aur.archlinux.org: the AUR's public SSH login (redesign/SUBMIT_TO_AUR.md), not an address
    r"\b[A-Za-z0-9._%+-]+@(?!users\.noreply\.github\.com|anthropic\.com|videolan\.org|aur\.archlinux\.org)[A-Za-z0-9.-]+\.[a-z]{2,}\b",
]
FORBIDDEN_PATHS = [
    r"^redesign/reference/frames",           # designer's video frames
    r"^redesign/reference/.*\.srt$",          # designer's transcript
    r"\.(mp4|mkv|mov|avi)$",                  # video files
]

# A private entry also matches inside a longer word or a file name: case-insensitive, and its \b
# means a letter boundary (underscores, digits, dots and dashes separate words, letters do not), so
# "sbs_chapters_title.png" or "Title2016" match an entry "\bTitle\b" while an ordinary longer word
# that only contains it does not. (A name in a screenshot file name was missed on 2026-11-12.)
LETTER_EDGE = r"(?:(?<![A-Za-z])(?=[A-Za-z])|(?<=[A-Za-z])(?![A-Za-z]))"

def private_rx(pattern):
    return re.compile(pattern.replace(r"\b", LETTER_EDGE), re.IGNORECASE)

def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, encoding="utf-8").stdout

def main():
    staged = "--staged" in sys.argv
    files = git("diff", "--name-only", "--diff-filter=AM", "--cached" if staged else BASE).split()
    if not staged:
        files += git("diff", "--name-only", "--diff-filter=AM", "--cached").split()
    files = sorted(set(files))
    rx = [re.compile(p) for p in GENERIC]
    private = []
    local = os.path.join(HERE, "privacy.local.txt")
    if os.path.exists(local):
        private = [private_rx(l.strip()) for l in open(local, encoding="utf-8")
                   if l.strip() and not l.startswith("#")]
    else:
        print("note: no privacy.local.txt, only the generic checks run")
    rx += private
    problems = []
    for f in files:
        for p in FORBIDDEN_PATHS:
            if re.search(p, f):
                problems.append("forbidden file: " + f)
        # a private word in a file's own name or folder
        for r in private:
            if r.search(f):
                problems.append("file name matches a private entry: " + f)
        if not os.path.exists(f) or f.endswith(("CREDITS.md", "redesign/tools/privacycheck.py")):
            continue
        try:
            text = open(f, encoding="utf-8").read()
        except (UnicodeDecodeError, IsADirectoryError):
            continue
        for n, line in enumerate(text.split("\n"), 1):
            # license headers name upstream VLC authors with their e-mail: not ours
            header = n <= 30 and re.search(r"(Authors?:|Copyright|^\s*\*\s+\S.*<\S+@\S+>)", line)
            for r in rx:
                if header and r.pattern == GENERIC[3]:
                    continue
                if r.search(line):
                    problems.append("%s:%d: matches %s" % (f, n, r.pattern))
    tracked = git("ls-files").split("\n")
    for t in tracked:
        for p in FORBIDDEN_PATHS[:2]:
            if t and re.search(p, t):
                problems.append("tracked forbidden file: " + t)
                break
    for p in problems[:200]:
        print(p)
    print("privacycheck: %d problem(s)" % len(problems))
    return 1 if problems else 0

sys.exit(main())
