"""Make the Custom accent swatch images: a conic color wheel (every hue around the centre, red at
the top, then yellow, green, cyan, blue, magenta clockwise), 4x supersampled.
Square (Settings, pixmaps/redesign/accent_wheel.png) or round with transparent corners (the
onboarding's round swatches, pixmaps/redesign/accent_wheel_round.png). Qt 6 with PySide6:
python make_accent_wheel.py out.png [size] [--round]"""
import colorsys, math, sys
from PySide6.QtGui import QImage, QColor
from PySide6.QtCore import Qt

args = [a for a in sys.argv[1:] if not a.startswith("--")]
out = args[0]
size = int(args[1]) if len(args) > 1 else 120
round_ = "--round" in sys.argv
ss = 4
n = size * ss
big = QImage(n, n, QImage.Format_ARGB32)
big.fill(Qt.transparent)
c = (n - 1) / 2.0
radius = n / 2.0
for y in range(n):
    for x in range(n):
        if round_ and math.hypot(x - c, y - c) > radius:
            continue
        # the angle clockwise from 12 o'clock, 0..1
        a = (math.atan2(x - c, -(y - c)) / (2 * math.pi)) % 1.0
        r, g, b = colorsys.hsv_to_rgb(a, 1.0, 1.0)
        big.setPixel(x, y, QColor(int(r * 255), int(g * 255), int(b * 255)).rgba())
img = big.scaled(size, size, Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
img.save(out)
print("wrote", out, img.width(), "x", img.height())
