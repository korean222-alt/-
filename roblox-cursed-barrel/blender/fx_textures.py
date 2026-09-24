"""2D particle textures for Roblox ParticleEmitters (and thumbnail dressing).

White/neutral where possible so ParticleEmitter.Color can tint them in-game.
Run with any Python that has Pillow + numpy.
"""
import math
import os
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FX = os.path.join(os.path.dirname(HERE), "fx")
os.makedirs(FX, exist_ok=True)
SS = 4  # supersampling


def _save(arr, name, size):
    img = Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8), "RGBA")
    img = img.resize((size, size), Image.LANCZOS)
    img.save(os.path.join(FX, name))
    return img


def petal(size=256):
    """Cherry blossom petal with the notched tip, pale centre -> pink rim."""
    n = size * SS
    y, x = np.mgrid[0:n, 0:n] / n  # 0..1
    u = (x - 0.5) * 2          # -1..1 across
    v = 1 - y                   # 0 base .. 1 tip
    vc = np.clip(v, 0, 1)
    grow = 0.6 * np.sin(np.pi / 2 * np.clip((vc - 0.03) / 0.62, 0, 1)) ** 1.1
    cap = 0.6 * np.sqrt(np.clip(1 - ((vc - 0.65) / 0.32) ** 2, 0, 1))
    width = np.where(vc < 0.65, grow, cap)
    notch = 0.97 - 0.2 * np.clip(1 - np.abs(u) / 0.2, 0, 1) ** 1.4
    inside = (np.abs(u) < width) & (v > 0.03) & (v < notch)
    edge = np.clip(1 - np.abs(u) / np.maximum(width, 1e-3), 0, 1)
    tipd = np.clip((notch - v) * 8, 0, 1)
    shade = np.minimum(edge ** 0.5, tipd)
    pale = np.array([1.0, 0.95, 0.97])
    pink = np.array([1.0, 0.62, 0.78])
    col = pink[None, None, :] * (1 - shade[..., None]) + pale[None, None, :] * shade[..., None]
    # faint vein
    vein = np.exp(-(u / 0.03) ** 2) * (v < 0.7) * 0.12
    col = col - vein[..., None] * np.array([0.0, 0.25, 0.15])
    a = inside.astype(float)
    out = np.dstack([col, a])
    img = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(SS * 0.6))
    img = img.resize((size, size), Image.LANCZOS)
    img.save(os.path.join(FX, "petal.png"))


def sparkle(size=256):
    """Four-point star with soft core. White; tint in Roblox."""
    n = size * SS
    y, x = (np.mgrid[0:n, 0:n] / n - 0.5) * 2
    r = np.hypot(x, y) + 1e-6
    core = np.exp(-(r / 0.10) ** 2)
    halo = np.exp(-(r / 0.35) ** 2) * 0.35
    ray = np.exp(-(np.abs(x) / 0.025)) * np.exp(-(np.abs(y) / 0.75) ** 2) + np.exp(-(np.abs(y) / 0.025)) * np.exp(-(np.abs(x) / 0.75) ** 2)
    diag = (np.exp(-(np.abs(x - y) / 0.03)) + np.exp(-(np.abs(x + y) / 0.03))) * np.exp(-(r / 0.35) ** 2) * 0.4
    a = np.clip(core + halo + ray * 0.9 + diag, 0, 1)
    _save(np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a]), "sparkle.png", size)


def orb(size=128):
    """Soft round glow for aura / embers."""
    n = size * SS
    y, x = (np.mgrid[0:n, 0:n] / n - 0.5) * 2
    r = np.hypot(x, y)
    a = np.clip(1 - r, 0, 1) ** 2.2
    _save(np.dstack([np.ones_like(a)] * 3 + [a]), "orb.png", size)


def wisp(size=256):
    """Ghostly smoke puff (for ghost tiers)."""
    rng = np.random.default_rng(7)
    n = size
    base = np.zeros((n, n))
    for octave in range(5):
        f = 2 ** octave * 3
        g = rng.random((f + 1, f + 1))
        g = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)) / 255
        base += g / (2 ** octave)
    base /= base.max()
    y, x = (np.mgrid[0:n, 0:n] / n - 0.5) * 2
    r = np.hypot(x, y)
    a = np.clip((base - 0.35) * 1.8, 0, 1) * np.clip(1 - r, 0, 1) ** 1.5
    img = Image.fromarray((np.dstack([np.ones_like(a)] * 3 + [a]) * 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(2))
    img.save(os.path.join(FX, "wisp.png"))


def rune_ring(size=512):
    """Circle of angular runes, white on transparent (legendary+ ground ring)."""
    n = size * 2
    img = Image.new("L", (n, n), 0)
    from PIL import ImageDraw
    d = ImageDraw.Draw(img)
    c = n / 2
    for rr, w in ((0.47, 10), (0.36, 6)):
        d.ellipse([c - rr * n, c - rr * n, c + rr * n, c + rr * n], outline=255, width=w)
    rng = np.random.default_rng(3)
    count = 24
    for i in range(count):
        a0 = 2 * math.pi * i / count
        rm = 0.415 * n
        cx, cy = c + math.cos(a0) * rm, c + math.sin(a0) * rm
        s = 0.035 * n
        tang = a0 + math.pi / 2
        segs = rng.integers(2, 4)
        for _ in range(segs):
            p = rng.uniform(-1, 1, 4)
            x1 = cx + (p[0] * math.cos(tang) - p[1] * math.sin(tang)) * s
            y1 = cy + (p[0] * math.sin(tang) + p[1] * math.cos(tang)) * s
            x2 = cx + (p[2] * math.cos(tang) - p[3] * math.sin(tang)) * s
            y2 = cy + (p[2] * math.sin(tang) + p[3] * math.cos(tang)) * s
            d.line([x1, y1, x2, y2], fill=255, width=7)
    img = img.filter(ImageFilter.GaussianBlur(1.5)).resize((size, size), Image.LANCZOS)
    a = np.array(img) / 255
    glow = np.array(img.filter(ImageFilter.GaussianBlur(10))) / 255
    a = np.clip(a + glow * 0.8, 0, 1)
    _save(np.dstack([np.ones_like(a)] * 3 + [a]), "rune_ring.png", size)


if __name__ == "__main__":
    petal()
    sparkle()
    orb()
    wisp()
    rune_ring()
    print("fx textures ->", FX, sorted(os.listdir(FX)))
