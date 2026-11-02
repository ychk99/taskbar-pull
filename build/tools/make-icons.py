"""Draws the Taskbar Pull icon (a screen above a taskbar, with an arrow going up from a
taskbar button into the screen) and writes every icon and logo the app and its packages use.

    python build/tools/make-icons.py            (from the repository root; needs Pillow)

Outputs
    src/assets/TaskbarPull.ico        16-256 px, tray icon and shortcuts
    src/assets/TaskbarPull-off.ico    greyed version, tray icon while disabled
    packaging/msix/Assets/*.png       MSIX logos (plain names + scale/targetsize variants)
    docs/logo-300.png, docs/logo-1024.png   Store listing / README
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
BIG = 1024

ON = dict(frame=(38, 50, 72), screen=(64, 156, 255), screen2=(40, 118, 230), bar=(30, 36, 48),
          btn=(90, 100, 120), arrow=(255, 184, 28), arrow_edge=(140, 82, 0))
OFF = dict(frame=(70, 70, 74), screen=(150, 150, 156), screen2=(128, 128, 134), bar=(60, 60, 64),
           btn=(110, 110, 116), arrow=(200, 200, 204), arrow_edge=(90, 90, 94))


def draw(size, pal, simple=False):
    """Draw at 1024 px and scale down; small sizes use thicker shapes so they stay readable."""
    s = BIG
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = s / 256
    # screen (monitor) at the top
    pad = 18 if not simple else 8
    top, bottom = 22 if not simple else 10, 168 if not simple else 160
    d.rounded_rectangle([pad * k, top * k, (256 - pad) * k, bottom * k], radius=22 * k, fill=pal["frame"])
    inset = 12 if not simple else 14
    d.rounded_rectangle([(pad + inset) * k, (top + inset) * k, (256 - pad - inset) * k, (bottom - inset) * k],
                        radius=12 * k, fill=pal["screen"])
    # a darker lower half on the screen for depth
    d.rectangle([(pad + inset) * k, ((top + bottom) / 2 + 8) * k, (256 - pad - inset) * k, (bottom - inset - 10) * k],
                fill=pal["screen2"])
    d.rounded_rectangle([(pad + inset) * k, ((top + bottom) / 2 + 8) * k, (256 - pad - inset) * k, (bottom - inset) * k],
                        radius=12 * k, fill=pal["screen2"])
    # taskbar at the bottom
    bt = 190 if not simple else 184
    d.rounded_rectangle([8 * k, bt * k, 248 * k, 246 * k], radius=16 * k, fill=pal["bar"])
    if not simple:
        for x in (40, 84, 172, 216):
            d.rounded_rectangle([(x - 14) * k, (bt + 14) * k, (x + 14) * k, (bt + 42) * k], radius=6 * k, fill=pal["btn"])
    # highlighted button (the one clicked) in the middle
    d.rounded_rectangle([108 * k, (bt + 10) * k, 148 * k, (bt + 46) * k], radius=8 * k, fill=pal["arrow"])
    # arrow from the button up into the screen
    sw = 26 if not simple else 40           # shaft half-width
    head_w = 62 if not simple else 76
    tip = 44 if not simple else 30
    head_base = 104 if not simple else 98
    shaft_bottom = bt + 4
    edge = 7 if not simple else 0
    if edge:
        d.polygon([(128 * k, (tip - edge) * k), ((128 + head_w + edge) * k, (head_base + edge * .6) * k),
                   ((128 + sw + edge) * k, (head_base + edge * .6) * k), ((128 + sw + edge) * k, (shaft_bottom + edge) * k),
                   ((128 - sw - edge) * k, (shaft_bottom + edge) * k), ((128 - sw - edge) * k, (head_base + edge * .6) * k),
                   ((128 - head_w - edge) * k, (head_base + edge * .6) * k)], fill=pal["arrow_edge"])
    d.polygon([(128 * k, tip * k), ((128 + head_w) * k, head_base * k), ((128 + sw) * k, head_base * k),
               ((128 + sw) * k, shaft_bottom * k), ((128 - sw) * k, shaft_bottom * k), ((128 - sw) * k, head_base * k),
               ((128 - head_w) * k, head_base * k)], fill=pal["arrow"])
    return im.resize((size, size), Image.LANCZOS)


def icon_frames(pal):
    return [draw(n, pal, simple=n <= 24) for n in (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)]


def save_ico(path, pal):
    frames = icon_frames(pal)
    path.parent.mkdir(parents=True, exist_ok=True)
    frames[-1].save(path, format="ICO", sizes=[f.size for f in frames], append_images=frames[:-1])


def logo(w, h, pal, scale_of_height=1.0, plate=None):
    """Square icon centred on a w x h canvas (transparent or plated)."""
    im = Image.new("RGBA", (w, h), plate or (0, 0, 0, 0))
    n = max(1, int(round(min(w, h) * scale_of_height)))
    ic = draw(n, pal, simple=n <= 24)
    im.alpha_composite(ic, ((w - n) // 2, (h - n) // 2))
    return im


def main():
    save_ico(ROOT / "src/assets/TaskbarPull.ico", ON)
    save_ico(ROOT / "src/assets/TaskbarPull-off.ico", OFF)
    a = ROOT / "packaging/msix/Assets"
    a.mkdir(parents=True, exist_ok=True)
    # name: (base width, base height, icon fraction)
    logos = {"Square44x44Logo": (44, 44, 1.0), "Square71x71Logo": (71, 71, .7), "Square150x150Logo": (150, 150, .6),
             "Wide310x150Logo": (310, 150, .6), "Square310x310Logo": (310, 310, .6), "StoreLogo": (50, 50, 1.0)}
    for name, (w, h, f) in logos.items():
        logo(w, h, ON, f).save(a / f"{name}.png")
        for sc in (100, 125, 150, 200, 400):
            logo(round(w * sc / 100), round(h * sc / 100), ON, f).save(a / f"{name}.scale-{sc}.png")
    for t in (16, 24, 32, 48, 256):
        im = logo(t, t, ON, 1.0)
        im.save(a / f"Square44x44Logo.targetsize-{t}.png")
        im.save(a / f"Square44x44Logo.targetsize-{t}_altform-unplated.png")
    (ROOT / "docs").mkdir(exist_ok=True)
    logo(300, 300, ON, .9).save(ROOT / "docs/logo-300.png")
    draw(1024, ON).save(ROOT / "docs/logo-1024.png")
    print("icons written")


if __name__ == "__main__":
    main()
