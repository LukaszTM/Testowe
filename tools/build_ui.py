"""Assety z Kronikarz Asset Pack Extended -> assets/ui (komplet)."""
import os, numpy as np
from PIL import Image, ImageDraw, ImageFilter

IN, OUT = "incoming/", "ui_out3/"
os.makedirs(OUT, exist_ok=True)

def trim(im, thr=8):
    a = np.asarray(im.convert("RGBA"))
    ys, xs = np.nonzero(a[:, :, 3] > thr)
    return im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))

def prep(src, dst, width=None, do_trim=True):
    im = Image.open(IN + src).convert("RGBA")
    if do_trim and np.asarray(im)[:, :, 3].min() < 250:
        im = trim(im)
    if width:
        w, h = im.size
        im = im.resize((width, max(1, round(h * width / w))), Image.LANCZOS)
    im.save(OUT + dst)
    return im

jobs = [
    ("backgrounds/menu_background_open_book.png",       "plate_menu.png",  None, False),
    ("backgrounds/gameplay_background_open_book_ui.png","plate_play.png",  None, False),
    ("buttons/button_large.png",                        "btn_wide.png",         540),
    ("buttons/states/button_wide_hover.png",            "btn_wide_hover.png",   540),
    ("buttons/states/button_wide_pressed.png",          "btn_wide_down.png",    540),
    ("buttons/states/button_wide_disabled.png",         "btn_wide_off.png",     540),
    ("buttons/button_medium.png",                       "btn_med.png",          420),
    ("buttons/states/button_medium_hover.png",          "btn_med_hover.png",    420),
    ("buttons/states/button_medium_pressed.png",        "btn_med_down.png",     420),
    ("buttons/states/button_medium_disabled.png",       "btn_med_off.png",      420),
    ("buttons/button_small_topbar.png",                 "btn_small.png",        300),
    ("frames/input_field.png",                          "field.png",            540),
    ("ornaments/divider_ornament.png",                  "ornament.png",         420),
    ("frames/parchment_content_frame.png",              "card_frame.png",       760),
    # UWAGA: pliki w paczce mają odwrotne nazwy — „checked” to pusta ramka,
    # a „unchecked” niesie złoty ptaszek. Mapujemy je na odwrót celowo.
    ("controls/checkbox_unchecked.png",                 "check_on.png",          44),
    ("controls/checkbox_checked.png",                   "check_off.png",         44),
    ("controls/slider_gold.png",                        "slider.png",           420),
]
for j in jobs:
    src, dst, w = j[0], j[1], j[2]
    t = j[3] if len(j) > 3 else True
    im = prep(src, dst, w, t)
    print(f"  {dst:22s} {str(im.size):>12s}")

# ——— paski: rama z paczki + wypełnienia dopasowane do jej szczeliny ———
frame = trim(Image.open(IN + "bars/progress_bar_frame.png").convert("RGBA"))
W0, H0 = frame.size
BW = 286
frame = frame.resize((BW, max(1, round(H0 * BW / W0))), Image.LANCZOS)
frame.save(OUT + "bar_frame.png")
BH = frame.size[1]

# szczelina = ciemne wnętrze ramy
a = np.asarray(frame).astype(np.float32)
lum = a[:, :, :3].mean(axis=2)
dark = (a[:, :, 3] > 200) & (lum < 70)
# najdłuższy ciągły ciemny odcinek w kolumnie przez środek ramy = szczelina
col = dark[:, BW // 2]
best, cur, s0 = (0, 0), 0, 0
for i, v in enumerate(list(col) + [False]):
    if v:
        if cur == 0: s0 = i
        cur += 1
    else:
        if cur > best[0]: best = (cur, s0)
        cur = 0
sy0, sy1 = best[1], best[1] + best[0]
row = dark[(sy0 + sy1) // 2]
xs = np.nonzero(row)[0]
# wcięcie: wypełnienie ma leżeć w szczelinie, nie na złotej ramie ani ozdobach
sx0, sx1 = int(xs.min()) + 30, int(xs.max()) - 30
sy0, sy1 = sy0 + 3, sy1 - 2
print(f"  szczelina paska: x={sx0}..{sx1} y={sy0}..{sy1} (rama {BW}x{BH})")

def bar_fill(name, top, bot):
    im = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    h = sy1 - sy0
    for i in range(h):
        f = i / max(1, h - 1)
        # ciemniej u góry i u dołu, jaśniej w środku — jak wypukły szkliwiony pasek
        k = 1.0 - abs(f - 0.42) * 1.15
        c = tuple(int(top[j] + (bot[j] - top[j]) * f) for j in range(3))
        c = tuple(max(0, min(255, int(v * (0.62 + 0.5 * k)))) for v in c)
        d.line([(sx0, sy0 + i), (sx1, sy0 + i)], fill=c + (255,))
    # zaokrąglone końce, żeby pasek nie wyglądał jak wycięty prostokąt
    m = Image.new("L", (BW, BH), 0)
    r = (sy1 - sy0) // 2
    ImageDraw.Draw(m).rounded_rectangle([sx0, sy0, sx1, sy1 - 1], r, fill=255)
    im.putalpha(Image.composite(im.split()[3], Image.new("L", (BW, BH), 0), m))
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    im.save(OUT + name)

bar_fill("bar_fill_red.png",  (172, 62, 40), (104, 26, 18))
bar_fill("bar_fill_blue.png", (86, 118, 152), (40, 62, 92))
bar_fill("bar_fill_gold.png", (194, 156, 74), (118, 88, 32))
print("  paski: bar_frame + 3 wypełnienia")
