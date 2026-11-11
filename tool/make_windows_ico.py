"""Build the Windows .ico (tray + exe) from the macOS 1024 px app icon.

    python3 tool/make_windows_ico.py \
        macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png \
        assets/tray_kwaai_logo.ico preview.png
    cp assets/tray_kwaai_logo.ico windows/runner/resources/app_icon.ico

White becomes transparency in proportion to its distance from white, so the
soft drop shadows survive as faint grey instead of a white square on a dark
taskbar. The logo is cropped to its bounds so it fills the 16 px tray slot,
and every size is scaled from the master (the pre-rendered small PNGs are
anti-aliased against white). preview.png shows each size on a dark and a
light taskbar colour. Needs Pillow and NumPy.
"""
import sys
import numpy as np
from PIL import Image

src, out, preview = sys.argv[1], sys.argv[2], sys.argv[3]
T = 150.0  # distance from white at which a pixel is fully opaque

a = np.asarray(Image.open(src).convert('RGB')).astype(np.float64)
dist = (255.0 - a).max(axis=2)
alpha = np.clip(dist / T, 0.0, 1.0)
safe = np.where(alpha > 0, alpha, 1.0)
rgb = np.clip(255.0 - (255.0 - a) / safe[..., None], 0, 255)
rgba = np.dstack([rgb, alpha * 255.0]).round().astype(np.uint8)

# Crop to the logo, then pad to a centred square with a small margin.
ys, xs = np.where(alpha > 0.10)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
im = Image.fromarray(rgba, 'RGBA').crop((x0, y0, x1, y1))
side = int(max(im.size) * 1.04)
sq = Image.new('RGBA', (side, side), (0, 0, 0, 0))
sq.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2))
master = sq.resize((1024, 1024), Image.Resampling.LANCZOS)

sizes = [16, 20, 24, 32, 40, 48, 64, 256]
frames = [master.resize((s, s), Image.Resampling.LANCZOS) for s in sizes]
frames[-1].save(out, format='ICO', sizes=[(s, s) for s in sizes],
                append_images=frames[:-1], bitmap_format='bmp')

# Preview: every size on a dark and a light taskbar colour, at 4x.
pad = 8
w = sum(sizes) + pad * (len(sizes) + 1)
h = sizes[-1] + 2 * pad
sheet = Image.new('RGBA', (w, h * 2))
for row, bg in enumerate([(32, 32, 32, 255), (243, 243, 243, 255)]):
    band = Image.new('RGBA', (w, h), bg)
    x = pad
    for f in frames:
        band.alpha_composite(f, (x, pad)); x += f.size[0] + pad
    sheet.paste(band, (0, row * h))
small = sheet.crop((0, 0, sum(sizes[:-1]) + pad * len(sizes), h * 2))
small = small.resize((small.size[0] * 4, small.size[1] * 4), Image.Resampling.NEAREST)
small.save(preview)
print('crop', (x0, y0, x1, y1), 'ico bytes', __import__('os').path.getsize(out))
