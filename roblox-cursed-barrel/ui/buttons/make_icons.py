"""로비 버튼 그림 7장 (상점 · 퀘스트 · 방해 · 출석 · 룰렛 · 코드 · 항해) 을 그린다.

만화풍 : 두꺼운 검은 외곽선 · 위가 밝은 그러데이션 · 광택 · 투명 배경. 256×256 PNG.

    pip install pillow
    python3 ui/buttons/make_icons.py      # ui/buttons/*.png + preview.png

올리는 법 : Studio → 보기 → 에셋 관리자 → 가져오기 → 그림 오른쪽 클릭 → Copy Asset ID
           → ReleaseConfig.lua 의 C.Images.Buttons = { Shop = 숫자, Quest = 숫자, … }
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent
S = 1024  # 4배로 그려서 줄인다 (가장자리가 매끈하다)
FINAL = 256
INK = (22, 16, 28, 255)
OUTLINE = 34  # 외곽선 두께 (그리는 크기 기준)


def new_mask():
    return Image.new("L", (S, S), 0)


def gradient(mask, top, bottom, angle_top=0.0, y0=None, y1=None):
    """mask 모양대로 위→아래 그러데이션을 칠한 RGBA."""
    box = mask.getbbox() or (0, 0, S, S)
    y0 = box[1] if y0 is None else y0
    y1 = box[3] if y1 is None else y1
    grad = Image.new("RGBA", (1, S))
    for y in range(S):
        t = min(1, max(0, (y - y0) / max(1, y1 - y0)))
        grad.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    grad = grad.resize((S, S))
    # paste(mask) 는 반투명 가장자리의 색을 검게 섞는다 → 색은 그대로 두고 투명도만 mask 로
    grad.putalpha(mask)
    return grad


def solid(mask, color):
    out = Image.new("RGBA", (S, S), color[:3] + (255,))
    alpha = mask if len(color) < 4 or color[3] == 255 else ImageChops.multiply(mask, Image.new("L", (S, S), color[3]))
    out.putalpha(alpha)
    return out


def dilate(mask, size):
    size = size if size % 2 == 1 else size + 1
    return mask.filter(ImageFilter.MaxFilter(size))


def gloss(mask, box, alpha=110):
    """모양 위쪽에 하얀 광택 (모양 밖으로는 안 나간다)."""
    g = new_mask()
    ImageDraw.Draw(g).ellipse(box, fill=alpha)
    g = g.filter(ImageFilter.GaussianBlur(10))
    g = ImageChops.multiply(g, mask)
    return solid(g, (255, 255, 255, 255))


class Icon:
    """레이어를 차례로 쌓는다. 모든 조각의 합에 두꺼운 외곽선 · 그림자를 두른다."""

    def __init__(self):
        self.layers = []
        self.union = new_mask()

    def add(self, layer, mask, outline=True):
        self.layers.append((layer, mask, outline))
        if outline:
            self.union = ImageChops.lighter(self.union, mask)

    def render(self, name):
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        # 그림자 · 외곽선
        shadow = dilate(self.union, OUTLINE * 2).filter(ImageFilter.GaussianBlur(14))
        img.alpha_composite(solid(ImageChops.multiply(shadow, Image.new("L", (S, S), 90)), (0, 0, 0, 255)).transform(
            (S, S), Image.AFFINE, (1, 0, -10, 0, 1, -22)))
        img.alpha_composite(solid(dilate(self.union, OUTLINE * 2), INK))
        for layer, mask, outline in self.layers:
            if outline:
                # 조각 사이에도 가는 선
                inner = ImageChops.subtract(dilate(mask, 12), mask)
                img.alpha_composite(solid(inner, INK))
            img.alpha_composite(layer)
        img = img.resize((FINAL, FINAL), Image.LANCZOS)
        img.save(OUT / f"{name}.png")
        return img


def draw_mask(fn):
    m = new_mask()
    fn(ImageDraw.Draw(m))
    return m


def rrect(box, r):
    return draw_mask(lambda d: d.rounded_rectangle(box, r, fill=255))


def ellipse(box):
    return draw_mask(lambda d: d.ellipse(box, fill=255))


def poly(points):
    return draw_mask(lambda d: d.polygon(points, fill=255))


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


GOLD = ((255, 230, 110), (232, 150, 30))
RED = ((255, 110, 90), (196, 34, 40))
CREAM = ((255, 250, 232), (236, 214, 170))


# ─────────────────────────── 아이콘 ───────────────────────────

def shop():
    ic = Icon()
    # 손잡이 (고리 두 개)
    handle = new_mask()
    ImageDraw.Draw(handle).arc((330, 150, 694, 520), 180, 360, fill=255, width=54)
    ic.add(gradient(handle, (150, 90, 60), (90, 50, 34)), handle)
    body = poly([(210, 330), (814, 330), (870, 860), (154, 860)])
    body = ImageChops.multiply(body, rrect((150, 320, 874, 870), 70))
    ic.add(gradient(body, (255, 140, 70), (214, 58, 40)), body)
    fold = rrect((210, 330, 814, 420), 30)
    ic.add(gradient(fold, (255, 176, 96), (232, 106, 50)), fold, outline=False)
    ic.add(gloss(body, (190, 360, 560, 620), 90), body, outline=False)
    star = poly(star_points(512, 640, 190, 84))
    ic.add(gradient(star, *GOLD), star)
    ic.add(gloss(star, (380, 470, 600, 640), 140), star, outline=False)
    return ic.render("Shop")


def quest():
    ic = Icon()
    paper = rrect((230, 200, 794, 830), 30)
    ic.add(gradient(paper, *CREAM), paper)
    for y in (200, 830):
        roll = rrect((180, y - 60, 844, y + 60), 60)
        ic.add(gradient(roll, (236, 190, 110), (170, 112, 50)), roll)
    lines = new_mask()
    d = ImageDraw.Draw(lines)
    for i, w in enumerate((420, 380, 440, 260)):
        y = 330 + i * 95
        d.rounded_rectangle((300, y, 300 + w, y + 34), 17, fill=255)
    ic.add(solid(lines, (150, 110, 80, 255)), lines, outline=False)
    seal = ellipse((560, 580, 800, 820))
    ic.add(gradient(seal, *RED), seal)
    st = poly(star_points(680, 700, 78, 34))
    ic.add(solid(st, (255, 210, 120, 255)), st, outline=False)
    ic.add(gloss(seal, (590, 600, 730, 700), 120), seal, outline=False)
    return ic.render("Quest")


def sabotage():
    ic = Icon()
    fuse = new_mask()
    d = ImageDraw.Draw(fuse)
    d.arc((520, 90, 860, 430), 190, 300, fill=255, width=40)
    ic.add(solid(fuse, (230, 200, 150, 255)), fuse)
    cap = rrect((560, 250, 720, 380), 24)
    cap = cap.rotate(-28, center=(640, 315))
    ic.add(gradient(cap, (170, 176, 196), (90, 94, 110)), cap)
    bomb = ellipse((170, 300, 730, 860))
    ic.add(gradient(bomb, (96, 88, 120), (26, 22, 36)), bomb)
    ic.add(gloss(bomb, (240, 350, 470, 560), 150), bomb, outline=False)
    spark = poly(star_points(830, 150, 150, 60, n=8, rot=-90))
    ic.add(gradient(spark, (255, 250, 150), (255, 130, 30)), spark)
    core = poly(star_points(830, 150, 70, 30, n=8, rot=-67))
    ic.add(solid(core, (255, 255, 230, 255)), core, outline=False)
    return ic.render("Sabotage")


def attendance():
    ic = Icon()
    page = rrect((170, 220, 854, 860), 60)
    ic.add(gradient(page, (255, 255, 255), (220, 226, 240)), page)
    head = ImageChops.multiply(rrect((170, 220, 854, 860), 60), rrect((170, 220, 854, 400), 0))
    ic.add(gradient(head, *RED), head, outline=False)
    dots = new_mask()
    d = ImageDraw.Draw(dots)
    for row in range(3):
        for col in range(5):
            x, y = 250 + col * 115, 470 + row * 115
            d.rounded_rectangle((x, y, x + 72, y + 72), 16, fill=255)
    ic.add(solid(dots, (200, 208, 226, 255)), dots, outline=False)
    for x in (340, 684):
        ring = rrect((x - 34, 150, x + 34, 300), 34)
        ic.add(gradient(ring, (220, 226, 240), (130, 138, 160)), ring)
    check = new_mask()
    ImageDraw.Draw(check).line([(330, 620), (470, 760), (760, 430)], fill=255, width=120, joint="curve")
    check = check.filter(ImageFilter.MaxFilter(9))
    ic.add(gradient(check, (140, 240, 90), (40, 160, 50)), check)
    ic.add(gloss(page, (200, 240, 600, 360), 70), page, outline=False)
    return ic.render("Attendance")


def roulette():
    ic = Icon()
    cx, cy, r = 512, 540, 330
    rim = ellipse((cx - r - 50, cy - r - 50, cx + r + 50, cy + r + 50))
    ic.add(gradient(rim, *GOLD), rim)
    colors = [(240, 64, 56), (255, 246, 226), (70, 176, 255), (255, 246, 226), (110, 222, 64), (255, 246, 226), (196, 96, 255), (255, 246, 226)]
    for i, color in enumerate(colors):
        seg = draw_mask(lambda d, i=i: d.pieslice((cx - r, cy - r, cx + r, cy + r), i * 45 - 90, (i + 1) * 45 - 90, fill=255))
        ic.add(solid(seg, color + (255,)), seg, outline=False)
    spokes = new_mask()
    d = ImageDraw.Draw(spokes)
    for i in range(8):
        a = math.radians(i * 45 - 90)
        d.line([(cx, cy), (cx + r * math.cos(a), cy + r * math.sin(a))], fill=255, width=16)
    ic.add(solid(spokes, INK), spokes, outline=False)
    hub = ellipse((cx - 80, cy - 80, cx + 80, cy + 80))
    ic.add(gradient(hub, *GOLD), hub)
    pointer = poly([(cx - 90, 90), (cx + 90, 90), (cx, 290)])
    ic.add(gradient(pointer, *RED), pointer)
    ic.add(gloss(rim, (260, 230, 700, 470), 90), rim, outline=False)
    return ic.render("Roulette")


def code():
    ic = Icon()
    ticket = rrect((110, 290, 914, 734), 50)
    notch = new_mask()
    d = ImageDraw.Draw(notch)
    for x in (110, 914):
        d.ellipse((x - 80, 432, x + 80, 592), fill=255)
    ticket = ImageChops.subtract(ticket, notch)
    ticket = ticket.rotate(-12, center=(512, 512), resample=Image.BICUBIC)
    ic.add(gradient(ticket, (140, 240, 230), (30, 150, 170)), ticket)
    dash = new_mask()
    d = ImageDraw.Draw(dash)
    for y in range(320, 720, 60):
        d.rounded_rectangle((640, y, 664, y + 34), 12, fill=255)
    dash = dash.rotate(-12, center=(512, 512), resample=Image.BICUBIC)
    ic.add(solid(ImageChops.multiply(dash, ticket), (255, 255, 255, 200)), dash, outline=False)
    star = poly(star_points(390, 500, 150, 64, rot=-102))
    ic.add(gradient(star, *GOLD), star)
    ic.add(gloss(ticket, (160, 300, 600, 470), 110), ticket, outline=False)
    return ic.render("Code")


def voyage():
    ic = Icon()
    cx, cy = 512, 520
    case = ellipse((cx - 380, cy - 380, cx + 380, cy + 380))
    ic.add(gradient(case, *GOLD), case)
    face = ellipse((cx - 300, cy - 300, cx + 300, cy + 300))
    ic.add(gradient(face, *CREAM), face, outline=False)
    ticks = new_mask()
    d = ImageDraw.Draw(ticks)
    for i in range(8):
        a = math.radians(i * 45)
        r0, r1 = (230, 290) if i % 2 == 0 else (255, 290)
        d.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)), (cx + r1 * math.cos(a), cy + r1 * math.sin(a))], fill=255, width=22)
    ic.add(solid(ticks, (120, 90, 60, 255)), ticks, outline=False)
    north = poly([(cx, cy - 250), (cx + 70, cy), (cx - 70, cy)])
    south = poly([(cx, cy + 250), (cx + 70, cy), (cx - 70, cy)])
    north = north.rotate(-35, center=(cx, cy), resample=Image.BICUBIC)
    south = south.rotate(-35, center=(cx, cy), resample=Image.BICUBIC)
    ic.add(gradient(north, *RED), north)
    ic.add(gradient(south, (120, 190, 255), (40, 100, 210)), south)
    pin = ellipse((cx - 44, cy - 44, cx + 44, cy + 44))
    ic.add(gradient(pin, *GOLD), pin)
    ring = ellipse((cx - 60, cy - 470, cx + 60, cy - 350))
    ring = ImageChops.subtract(ring, ellipse((cx - 28, cy - 438, cx + 28, cy - 382)))
    ic.add(gradient(ring, *GOLD), ring)
    ic.add(gloss(case, (200, 170, 640, 420), 110), case, outline=False)
    return ic.render("Voyage")


ICONS = {"Shop": shop, "Quest": quest, "Sabotage": sabotage, "Attendance": attendance, "Roulette": roulette, "Code": code, "Voyage": voyage}
# 게임 버튼 판 색 (UIKit.iconButton 과 같다) — 미리보기에만 쓴다
TILES = {
    "Shop": ((255, 228, 115), (226, 160, 45)), "Quest": ((139, 219, 255), (56, 146, 226)),
    "Sabotage": ((239, 166, 250), (168, 82, 208)), "Attendance": ((255, 195, 139), (231, 110, 69)),
    "Roulette": ((157, 245, 160), (57, 180, 102)), "Code": ((149, 237, 231), (55, 165, 176)),
    "Voyage": ((181, 198, 255), (93, 114, 206)),
}

if __name__ == "__main__":
    images = {name: fn() for name, fn in ICONS.items()}
    # 미리보기 : 게임 버튼 판 위에 올린 모습
    tile = 200
    sheet = Image.new("RGBA", (len(images) * (tile + 20) + 20, tile + 40), (40, 44, 60, 255))
    for i, (name, img) in enumerate(images.items()):
        top, bottom = TILES[name]
        m = Image.new("L", (tile, tile), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, tile - 1, tile - 1), 26, fill=255)
        g = Image.new("RGBA", (tile, tile))
        for y in range(tile):
            t = y / tile
            ImageDraw.Draw(g).line([(0, y), (tile, y)], fill=tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3)) + (255,))
        base = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
        base.paste(g, (0, 0), m)
        ImageDraw.Draw(base).rounded_rectangle((0, 0, tile - 1, tile - 1), 26, outline=(19, 21, 27, 255), width=7)
        art = img.resize((tile - 16, tile - 16), Image.LANCZOS)
        base.alpha_composite(art, (8, 2))
        sheet.alpha_composite(base, (20 + i * (tile + 20), 20))
    sheet.save(OUT / "preview.png")
    print("wrote", ", ".join(f"{n}.png" for n in images), "+ preview.png")
