"""Wymazywanie wtopionego tekstu z makiet: gładkie tło z otoczenia + ziarno papieru."""
from PIL import Image, ImageFilter
import numpy as np

def load(p): return np.asarray(Image.open(p).convert("RGBA")).astype(np.float32)
def save(a, p): Image.fromarray(np.clip(a,0,255).astype(np.uint8), "RGBA").save(p)

def _blur(a, r):
    im = Image.fromarray(np.clip(a,0,255).astype(np.uint8), "RGB").filter(ImageFilter.GaussianBlur(r))
    return np.asarray(im).astype(np.float32)

def _ring_grid(img, rect, G=40, band=14):
    """Kolor papieru tuż za krawędzią prostokąta, spróbkowany na siatkę GxG."""
    x,y,w,h = rect
    H,W,_ = img.shape
    known = np.zeros((G,G,3), np.float32)
    mask  = np.zeros((G,G), bool)
    def sample(cx, cy):
        x0,x1 = max(0,cx-band), min(W,cx+band)
        y0,y1 = max(0,cy-band), min(H,cy+band)
        if x1<=x0 or y1<=y0: return None
        px = img[y0:y1, x0:x1, :3].reshape(-1,3)
        return np.percentile(px, 72, axis=0)          # papier, nie tusz
    for i in range(G):
        fx = x + int((i+0.5)*w/G)
        for cy, j in ((y-band-4, 0), (y+h+band+4, G-1)):
            s = sample(fx, cy)
            if s is not None: known[j,i] = s; mask[j,i] = True
    for j in range(G):
        fy = y + int((j+0.5)*h/G)
        for cx, i in ((x-band-4, 0), (x+w+band+4, G-1)):
            s = sample(cx, fy)
            if s is not None: known[j,i] = s; mask[j,i] = True
    return known, mask

def _relax(known, mask, iters=900):
    """Wypełnienie wnętrza siatki przez uśrednianie sąsiadów (dyfuzja Laplace'a)."""
    g = known.copy()
    seed = known[mask].mean(axis=0) if mask.any() else np.array([170.,150.,120.])
    g[~mask] = seed
    for _ in range(iters):
        p = np.pad(g, ((1,1),(1,1),(0,0)), mode="edge")
        avg = (p[:-2,1:-1] + p[2:,1:-1] + p[1:-1,:-2] + p[1:-1,2:]) * 0.25
        g = np.where(mask[:,:,None], known, avg)
    return g

def _base(img, rect, G=40):
    x,y,w,h = rect
    known, mask = _ring_grid(img, rect, G)
    g = _relax(known, mask)
    im = Image.fromarray(np.clip(g,0,255).astype(np.uint8), "RGB").resize((w,h), Image.BICUBIC)
    return np.asarray(im).astype(np.float32)

def _grain(patches, w, h, rng, hf=42):
    """Ziarno papieru: górnoprzepustowe wycinki, sklejane z losowym przesunięciem."""
    if not isinstance(patches, list): patches = [patches]
    hps = [p[:,:,:3] - _blur(p[:,:,:3], hf) for p in patches]
    ph, pw, _ = hps[0].shape
    step_y, step_x = ph//2, pw//2                     # 50% zakładki
    acc = np.zeros((h+2*ph, w+2*pw, 3), np.float32)
    wsum = np.zeros((h+2*ph, w+2*pw, 1), np.float32) + 1e-6
    fy = np.hanning(ph+2)[1:-1]; fx = np.hanning(pw+2)[1:-1]
    win = (fy[:,None]*fx[None,:])[:,:,None] + 1e-4
    for yy in range(0, h+step_y, step_y):
        for xx in range(0, w+step_x, step_x):
            t = hps[int(rng.integers(len(hps)))]
            if rng.random() < 0.5: t = t[::-1]
            if rng.random() < 0.5: t = t[:, ::-1]
            acc[yy:yy+ph, xx:xx+pw] += t*win
            wsum[yy:yy+ph, xx:xx+pw] += win
    return (acc/wsum)[:h, :w]

def feather(w, h, r):
    m = np.ones((h,w), np.float32)
    if r <= 0: return m
    ramp = np.clip((np.arange(r)+0.5)/float(r), 0, 1)
    for i,v in enumerate(ramp):
        m[i,:] = np.minimum(m[i,:], v); m[h-1-i,:] = np.minimum(m[h-1-i,:], v)
        m[:,i] = np.minimum(m[:,i], v); m[:,w-1-i] = np.minimum(m[:,w-1-i], v)
    return m

def wipe(img, rect, patch, soft=8, seed=7, grain=1.0, hf=42):
    """Zamaluj prostokąt czystym papierem: gładkie tło z otoczenia + ziarno."""
    x,y,w,h = rect
    rng = np.random.default_rng(seed)
    out = _base(img, rect) + _grain(patch, w, h, rng, hf)*grain
    m = feather(w, h, soft)[:,:,None]
    img[y:y+h, x:x+w, :3] = img[y:y+h, x:x+w, :3]*(1-m) + np.clip(out,0,255)*m
    return img

def restore(dst, src, rect, soft=6):
    """Wklej z powrotem ozdobny fragment oryginału (miękka maska)."""
    x,y,w,h = rect
    m = feather(w, h, soft)[:,:,None]
    dst[y:y+h, x:x+w, :3] = dst[y:y+h, x:x+w, :3]*(1-m) + src[y:y+h, x:x+w, :3]*m
    return dst


def restore_ink(dst, src, rect, soft=5, strength=1.0):
    """Przywróć sam rysunek ornamentu (mnożenie), zostawiając nowy, czysty papier."""
    x, y, w, h = rect
    o = src[y:y+h, x:x+w, :3]
    paper = _blur(o, 26)
    paper = np.maximum(paper, _blur(o, 60))
    ratio = np.clip(o / np.maximum(paper, 1.0), 0.0, 1.0)
    ratio = 1.0 - (1.0 - ratio) * strength
    m = feather(w, h, soft)[:, :, None]
    cur = dst[y:y+h, x:x+w, :3]
    dst[y:y+h, x:x+w, :3] = cur * (1 - m) + np.clip(cur * ratio, 0, 255) * m
    return dst


def _ink_frac(t):
    g = t[:, :, :3].mean(axis=2)
    return float((g < np.percentile(g, 88) - 24).mean())

def clean_patches(img, region, n=4, size=96, max_ink=0.006):
    """Znajdź n nienachodzących na siebie, czystych wycinków papieru w regionie."""
    rx, ry, rw, rh = region
    cand = []
    for y in range(ry, ry + rh - size, 8):
        for x in range(rx, rx + rw - size, 8):
            t = img[y:y+size, x:x+size]
            if t[:, :, :3].mean() < 120: continue
            f = _ink_frac(t)
            if f <= max_ink: cand.append((f, x, y))
    cand.sort()
    out, used = [], []
    for f, x, y in cand:
        if any(abs(x-ux) < size and abs(y-uy) < size for ux, uy in used): continue
        used.append((x, y)); out.append(img[y:y+size, x:x+size].copy())
        if len(out) >= n: break
    if not out:
        raise RuntimeError("brak czystego papieru w regionie %s" % (region,))
    print("   czyste wycinki:", [(x, y) for x, y in used])
    return out


def wipe_label(img, rect, soft=4, pct=30, dark_text=False):
    """Zetrzyj napis z metalowej płytki, odtwarzając gradient wiersz po wierszu."""
    x, y, w, h = rect
    dst = img[y:y+h, x:x+w, :3]
    q = 100 - pct if dark_text else pct
    base = np.percentile(dst, q, axis=1)                  # (h,3) — tło wiersza
    prof = base[:, None, :] * np.ones((1, w, 1), np.float32)
    m = feather(w, h, soft)[:, :, None]
    img[y:y+h, x:x+w, :3] = dst * (1 - m) + prof * m
    return img

def nine_patch_ok(a, l, t, r, b):
    """Sanity-check: środek 9-patcha musi być jednolity (inaczej rozciąganie zniekształci wzór)."""
    h, w, _ = a.shape
    c = a[t:h-b, l:w-r, :3]
    return float(c.std())


def rail_period(a, band, x0, x1, lo=8, hi=40):
    """Okres powtarzalnego splotu na listwie ramki (autokorelacja)."""
    y0, y1 = band
    strip = a[y0:y1, x0:x1, :3].mean(axis=(0, 2))
    strip = strip - strip.mean()
    best, bp = -1e18, lo
    for p in range(lo, hi):
        s = float((strip[:-p] * strip[p:]).sum() / max(1, len(strip) - p))
        if s > best: best, bp = s, p
    return bp

def drop_center_ornament(a, half=44, bands=None):
    """Usuń ozdobę ze środka listwy, przedłużając splot — 9-patch da się wtedy kafelkować."""
    h, w, _ = a.shape
    cx = w // 2
    if bands is None:
        bands = [(0, 26), (h - 26, h)]
    for (y0, y1) in bands:
        p = rail_period(a, (y0, y1), 40, cx - 60)
        shift = p * max(1, int(round((2 * half + 24) / p)))
        x0, x1 = cx - half, cx + half
        src = a[y0:y1, x0 - shift:x1 - shift, :3]
        m = feather(x1 - x0, y1 - y0, 5)[:, :, None]
        a[y0:y1, x0:x1, :3] = a[y0:y1, x0:x1, :3] * (1 - m) + src * m
    return a

def cut_from_paper(a, corner=6, thr=44, soft=1.7):
    """Wytnij płytkę z otaczającego pergaminu — alfa z odległości od koloru papieru."""
    h, w, _ = a.shape
    corners = np.concatenate([
        a[:corner, :corner, :3].reshape(-1, 3), a[:corner, -corner:, :3].reshape(-1, 3),
        a[-corner:, :corner, :3].reshape(-1, 3), a[-corner:, -corner:, :3].reshape(-1, 3)])
    paper = np.median(corners, axis=0)
    d = np.sqrt(((a[:, :, :3] - paper) ** 2).sum(axis=2))
    al = np.clip((d - thr) / (thr * soft), 0, 1)
    im = Image.fromarray((al * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(0.8))
    al = np.asarray(im).astype(np.float32) / 255.0
    # zalej dziury: przezroczyste jest tylko to, co łączy się z brzegiem obrazu
    solid = al > 0.35
    outside = np.zeros((h, w), bool)
    outside[0, :] = outside[-1, :] = True
    outside[:, 0] = outside[:, -1] = True
    outside &= ~solid
    for _ in range(max(h, w)):
        grown = outside.copy()
        grown[1:, :] |= outside[:-1, :]; grown[:-1, :] |= outside[1:, :]
        grown[:, 1:] |= outside[:, :-1]; grown[:, :-1] |= outside[:, 1:]
        grown &= ~solid
        if grown.sum() == outside.sum(): break
        outside = grown
    al = np.where(outside, al, np.maximum(al, 1.0))
    a[:, :, 3] = al * 255.0
    return a
