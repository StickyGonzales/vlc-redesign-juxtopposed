#!/usr/bin/env python3
# The README's accent colors image: the same player view taken once per accent color
# (Settings > General > Accent color), layered like a fanned stack of cards. The default orange
# is in front; each card behind it sits a step lower and further left, so its left edge (the
# logo) and its control bar (play button, seek bar) show in its own accent. Run from the
# repository root:
#   python3 redesign/brand/make_accents_image.py <folder with accent-<RRGGBB>.png shots>
# Writes docs/images/cone-accents.png. Needs Pillow.
import os
import sys

from PIL import Image, ImageDraw

# Settings' order (Decision 15); the first is the default orange and goes in front
ACCENTS = ["D37918", "E15032", "C49E23", "19A234", "18AAD3", "185DD3", "8E42FF", "F052B3", "AFAFAF"]
CARD_W = 1240               # width of one card (the shots are 16:9)
STEP_X, STEP_Y = 45, 32     # each card behind the front one: this much further left and lower
BG = (17, 17, 17)           # Dark BG
EDGE = (60, 60, 60)         # thin outline that separates two cards
RADIUS = 12
OUT = "docs/images/cone-accents.png"

folder = sys.argv[1] if len(sys.argv) > 1 else "."
shots = [Image.open(os.path.join(folder, "accent-%s.png" % a)).convert("RGB") for a in ACCENTS]
card_h = round(shots[0].height * CARD_W / shots[0].width)
n = len(shots)
W = CARD_W + STEP_X * (n - 1)
H = card_h + STEP_Y * (n - 1)
canvas = Image.new("RGB", (W, H), BG)

mask = Image.new("L", (CARD_W, card_h), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, CARD_W - 1, card_h - 1), RADIUS, fill=255)

# back to front: the last accent is drawn first, bottom left; the default orange last, top right
for i in reversed(range(n)):
    card = shots[i].resize((CARD_W, card_h), Image.LANCZOS)
    x = STEP_X * (n - 1 - i)
    y = STEP_Y * i
    canvas.paste(card, (x, y), mask)
    ImageDraw.Draw(canvas).rounded_rectangle((x, y, x + CARD_W - 1, y + card_h - 1), RADIUS, outline=EDGE, width=2)

canvas.save(OUT, optimize=True)
print(OUT, canvas.size)
