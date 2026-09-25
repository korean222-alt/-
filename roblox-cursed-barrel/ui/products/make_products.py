"""로벅스 상품 · 게임패스 그림 8장 (512×512 PNG). Creator Hub 상품 만들기 화면의 「이미지 업로드」에 넣는다.

    python3 ui/products/make_products.py

만들어지는 것 : coins_small · coins_medium · coins_large · coins_huge · coins_vault · starter · VIP · Booster
그리는 방법(외곽선 · 그러데이션 · 광택)은 ui/buttons/make_icons.py 와 같다.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "buttons"))
import make_icons as K  # noqa: E402

OUT = Path(__file__).resolve().parent
K.FINAL = 512


def coin(ic, cx, cy, r=120):
    rim = K.ellipse((cx - r, cy - r * 0.62, cx + r, cy + r * 0.62))
    ic.add(K.gradient(rim, (255, 214, 80), (206, 120, 20)), rim)
    face = K.ellipse((cx - r * 0.74, cy - r * 0.44, cx + r * 0.74, cy + r * 0.40))
    ic.add(K.gradient(face, (255, 240, 150), (240, 170, 40)), face, outline=False)
    star = K.poly(K.star_points(cx, cy - 4, r * 0.34, r * 0.15))
    ic.add(K.solid(star, (214, 130, 20, 255)), star, outline=False)


def stack(ic, cx, base, count, r=120):
    for i in range(count):
        coin(ic, cx, base - i * 44, r)


def background(name, top, bottom):
    """게임 버튼처럼 둥근 판 + 가운데 빛."""
    tile = Image.new("RGBA", (512, 512))
    d = ImageDraw.Draw(tile)
    for y in range(512):
        t = y / 511
        d.line([(0, y), (512, y)], fill=tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3)) + (255,))
    glow = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(glow).ellipse((56, 40, 456, 440), fill=120)
    glow = glow.filter(K.ImageFilter.GaussianBlur(60))
    light = Image.new("RGBA", (512, 512), (255, 250, 220, 255))
    light.putalpha(glow)
    tile.alpha_composite(light)
    mask = Image.new("L", (512, 512), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 511, 511), 70, fill=255)
    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    out.paste(tile, (0, 0), mask)
    ImageDraw.Draw(out).rounded_rectangle((4, 4, 507, 507), 66, outline=(19, 21, 27, 255), width=12)
    art = Image.open(OUT / f"_{name}.png")
    out.alpha_composite(art.resize((470, 470), Image.LANCZOS), (21, 16))
    out.save(OUT / f"{name}.png")
    (OUT / f"_{name}.png").unlink()


def render(name, draw, colors):
    ic = K.Icon()
    draw(ic)
    K.OUT = OUT
    ic.render("_" + name)
    background(name, *colors)


GOLD_BG = ((255, 226, 110), (226, 150, 40))
GREEN_BG = ((140, 236, 120), (40, 160, 70))
PURPLE_BG = ((226, 160, 255), (130, 60, 210))
RED_BG = ((255, 150, 120), (210, 60, 50))

PRODUCTS = {
    "coins_small": (lambda ic: stack(ic, 512, 720, 4, 170), GREEN_BG),
    "coins_medium": (lambda ic: (stack(ic, 380, 720, 3), stack(ic, 640, 700, 5)), GREEN_BG),
    "coins_large": (lambda ic: (stack(ic, 300, 740, 4), stack(ic, 724, 740, 4), stack(ic, 512, 700, 7)), GOLD_BG),
    "coins_huge": (lambda ic: (stack(ic, 250, 760, 5), stack(ic, 774, 760, 5), stack(ic, 400, 720, 8), stack(ic, 624, 720, 8)), GOLD_BG),
}


def vault(ic):
    body = K.rrect((170, 430, 854, 850), 50)
    ic.add(K.gradient(body, (190, 110, 60), (120, 64, 34)), body)
    lid = K.rrect((150, 250, 874, 470), 90)
    ic.add(K.gradient(lid, (214, 130, 70), (150, 80, 40)), lid)
    for x in (300, 724):
        band = K.rrect((x - 34, 250, x + 34, 850), 12)
        ic.add(K.gradient(band, *K.GOLD), band, outline=False)
    lock = K.rrect((440, 410, 584, 560), 30)
    ic.add(K.gradient(lock, *K.GOLD), lock)
    for cx, cy in ((330, 250), (512, 210), (694, 250)):
        coin(ic, cx, cy, 90)
    ic.add(K.gloss(lid, (200, 270, 620, 380), 90), lid, outline=False)


def starter(ic):
    blade = K.poly([(560, 130), (650, 170), (430, 700), (370, 660)])
    ic.add(K.gradient(blade, (240, 244, 255), (150, 160, 190)), blade)
    guard = K.rrect((280, 640, 540, 710), 30).rotate(-22, center=(410, 675))
    ic.add(K.gradient(guard, *K.GOLD), guard)
    grip = K.rrect((330, 690, 400, 870), 30).rotate(-22, center=(365, 780))
    ic.add(K.gradient(grip, (150, 80, 50), (90, 44, 26)), grip)
    stack(ic, 700, 820, 3, 110)


def crown(ic):
    body = K.poly([(170, 740), (220, 330), (380, 520), (512, 250), (644, 520), (804, 330), (854, 740)])
    ic.add(K.gradient(body, *K.GOLD), body)
    band = K.rrect((170, 700, 854, 820), 30)
    ic.add(K.gradient(band, (255, 200, 70), (200, 110, 20)), band)
    for x, color in ((300, (240, 64, 56)), (512, (70, 176, 255)), (724, (110, 222, 64))):
        gem = K.ellipse((x - 46, 714, x + 46, 806))
        ic.add(K.solid(gem, color + (255,)), gem, outline=False)
    for x, y in ((220, 320), (512, 240), (804, 320)):
        ball = K.ellipse((x - 40, y - 40, x + 40, y + 40))
        ic.add(K.gradient(ball, (255, 250, 200), (240, 170, 40)), ball)
    ic.add(K.gloss(body, (260, 380, 620, 560), 100), body, outline=False)


def booster(ic):
    flame = K.poly([(512, 110), (700, 420), (650, 800), (512, 900), (374, 800), (324, 420)])
    ic.add(K.gradient(flame, (255, 240, 120), (240, 70, 30)), flame)
    inner = K.poly([(512, 360), (610, 560), (512, 820), (414, 560)])
    ic.add(K.solid(inner, (255, 250, 210, 255)), inner, outline=False)
    coin(ic, 512, 640, 110)


PRODUCTS.update({
    "coins_vault": (vault, PURPLE_BG),
    "starter": (starter, ((150, 220, 255), (50, 120, 220))),
    "VIP": (crown, PURPLE_BG),
    "Booster": (booster, RED_BG),
})

if __name__ == "__main__":
    for name, (draw, colors) in PRODUCTS.items():
        render(name, draw, colors)
    names = list(PRODUCTS)
    sheet = Image.new("RGBA", (len(names) * 180 + 20, 200), (40, 44, 60, 255))
    for i, name in enumerate(names):
        sheet.alpha_composite(Image.open(OUT / f"{name}.png").resize((160, 160), Image.LANCZOS), (20 + i * 180, 20))
    sheet.save(OUT / "preview.png")
    print("wrote", ", ".join(names), "+ preview.png")
