#!/usr/bin/env python3
# The repository's social preview (GitHub: Settings > General > Social preview), 1280 x 640:
# the Cone Player logo, the name, the pitch and one app screenshot. Run from the repository root
# after the homepage screenshots change:
#   python3 redesign/brand/make_social_preview.py [screenshot]
# Writes redesign/brand/social-preview.png. Needs Pillow.
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 1280, 640
BG = (17, 17, 17)            # Dark BG
TEXT = (255, 255, 255)
TEXT_DIM = (170, 170, 170)
ACCENT = (211, 121, 24)      # Accent #D37918
FRAME = (42, 42, 42)

FONTS = "modules/gui/qt/pixmaps/fonts/"
LOGO = "modules/gui/qt/pixmaps/brand/public/cone-256.png"
SHOT = sys.argv[1] if len(sys.argv) > 1 else "docs/images/cone-library.png"
OUT = "redesign/brand/social-preview.png"


def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius, fill=255)
    out = Image.new("RGBA", image.size)
    out.paste(image, (0, 0), mask)
    return out


canvas = Image.new("RGBA", (W, H), BG + (255,))
draw = ImageDraw.Draw(canvas)

# left column: logo, name, a short accent rule, the pitch
logo = Image.open(LOGO).convert("RGBA").resize((128, 128), Image.LANCZOS)
canvas.alpha_composite(logo, (80, 150))

bold = ImageFont.truetype(FONTS + "Inter-Bold.ttf", 68)
regular = ImageFont.truetype(FONTS + "Inter-Regular.ttf", 27)
draw.text((84, 300), "Cone Player", font=bold, fill=TEXT)
draw.rectangle((86, 392, 146, 397), fill=ACCENT)
draw.text((84, 418), "Juxtopposed's VLC redesign,", font=regular, fill=TEXT_DIM)
draw.text((84, 454), "built on a real VLC 4 fork. Not a skin.", font=regular, fill=TEXT_DIM)

# right: the screenshot in a thin frame, its right part running off the edge
shot = Image.open(SHOT).convert("RGBA")
shot_w = 700
shot = shot.resize((shot_w, round(shot.height * shot_w / shot.width)), Image.LANCZOS)
x, y = 640, (H - shot.height) // 2
draw.rounded_rectangle((x - 2, y - 2, x + shot.width + 1, y + shot.height + 1), 16, fill=FRAME)
canvas.alpha_composite(rounded(shot, 14), (x, y))

canvas.convert("RGB").save(OUT, optimize=True)
print(OUT, canvas.size)
