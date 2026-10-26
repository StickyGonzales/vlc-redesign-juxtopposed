# synthetic "video" frames: layered hills under a gradient sky (generated, no real media)
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter
def scene(w, h, sky_top, sky_bot, sun, hills, seed, out):
    random.seed(seed)
    im = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / h
        d.line([(0, y), (w, y)], fill=tuple(int(sky_top[i] + (sky_bot[i] - sky_top[i]) * t) for i in range(3)))
    if sun:
        sx, sy, sr, sc = sun
        glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([sx - sr * 3, sy - sr * 3, sx + sr * 3, sy + sr * 3], fill=sc + (60,))
        glow = glow.filter(ImageFilter.GaussianBlur(sr))
        im.paste(glow, (0, 0), glow)
        d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=sc)
    for i, (base, amp, col) in enumerate(hills):
        pts = [(0, h)]
        ph = random.random() * 6
        for x in range(0, w + 8, 8):
            y = h * base + amp * h * (math.sin(x / w * 5 + ph) * 0.6 + math.sin(x / w * 13 + ph * 2) * 0.25)
            pts.append((x, y))
        pts.append((w, h))
        d.polygon(pts, fill=col)
    im.save(out)
a = sys.argv[1]
scene(1920, 1080, (24, 30, 58), (196, 110, 70), (1290, 560, 70, (255, 196, 120)),
      [(0.62, 0.05, (92, 58, 72)), (0.72, 0.06, (58, 38, 56)), (0.84, 0.05, (30, 22, 34))], 3, a + '/frame_ep1.png')
scene(640, 360, (70, 130, 190), (190, 215, 230), (470, 90, 34, (255, 244, 200)),
      [(0.58, 0.07, (96, 140, 96)), (0.7, 0.06, (64, 108, 70)), (0.84, 0.05, (40, 76, 50))], 7, a + '/thumb_ep2.png')
scene(640, 360, (14, 18, 40), (60, 50, 110), (180, 80, 22, (230, 230, 255)),
      [(0.6, 0.06, (40, 40, 80)), (0.74, 0.05, (26, 26, 56)), (0.86, 0.04, (14, 14, 30))], 11, a + '/thumb_s02e01.png')
for i, (st, sb, hc) in enumerate([((60, 40, 30), (200, 120, 60), (90, 50, 30)), ((30, 60, 70), (120, 180, 170), (40, 80, 70)),
                                  ((50, 30, 60), (180, 110, 150), (70, 40, 70)), ((20, 30, 30), (90, 120, 100), (30, 50, 40)),
                                  ((70, 60, 30), (220, 190, 120), (100, 80, 40)), ((20, 20, 50), (90, 90, 160), (30, 30, 70))]):
    scene(160, 90, st, sb, None, [(0.6, 0.08, hc), (0.78, 0.06, tuple(c // 2 for c in hc))], 20 + i, a + '/t%d.png' % i)
