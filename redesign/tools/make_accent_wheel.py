"""Make the Custom accent swatch image: a square conic color wheel (every hue around the centre,
red at the top, then yellow, green, cyan, blue, magenta clockwise), 4x supersampled.
Made pixmaps/redesign/accent_wheel.png (Qt 6 with PySide6): python make_accent_wheel.py out.png [size]"""
import colorsys, math, sys
from PySide6.QtGui import QImage, QColor
from PySide6.QtCore import Qt

out = sys.argv[1]
size = int(sys.argv[2]) if len(sys.argv) > 2 else 120
ss = 4
big = QImage(size * ss, size * ss, QImage.Format_RGB32)
c = (size * ss - 1) / 2.0
for y in range(size * ss):
    for x in range(size * ss):
        # the angle clockwise from 12 o'clock, 0..1
        a = (math.atan2(x - c, -(y - c)) / (2 * math.pi)) % 1.0
        r, g, b = colorsys.hsv_to_rgb(a, 1.0, 1.0)
        big.setPixel(x, y, QColor(int(r * 255), int(g * 255), int(b * 255)).rgb())
img = big.scaled(size, size, Qt.IgnoreAspectRatio, Qt.SmoothTransformation)
img.save(out)
print("wrote", out, img.width(), "x", img.height())
