"""Builds the whole skin pack.

  export/CursedBarrelSkins.fbx      one file, import once in Studio (3D Importer, "import as single mesh" OFF)
  export/SkinMeshCatalog.lua        sizes / centres of every piece (MeshKit reads it)
  thumbnails/<Kind>_<id>.png        transparent render per skin (shop picture)
  thumbnails/cards/<Kind>_<id>.png  512x512 card with rarity background (developer product icon / upload)

Usage (Blender as a Python module):
  GAMECONFIG_LUA=path/to/GameConfig.lua python build_all.py [export|thumbs|all] [--only Knife_gold,...]
"""
import os
import sys
import math
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import common as C
import knives as K
import barrels as B
import pirate as PR
import pirate_colors as PC
import dragon as D
import extras as X
import skins_data as SD

RANK = {"common": 1, "rare": 2, "epic": 3, "legend": 4, "mythic": 5}
MAX_TRIS = 19000

# dragon geometry (knife scale: coils around a 3-stud blade)
COIL = dict(center=(0, 0, 0), R=0.62, z0=0.3, z1=2.6, turns=1.6, thick=0.085, head_len=0.36)
RING = dict(center=(0, 0, 0), R=2.4, z0=2.25, z1=2.85, turns=1.05, thick=0.2, head_len=0.85)
DRAGON_NEUTRAL = ("#d8b04a", "#402000", "#e03040", "#fff2d6", "#ffe08a", "#7df9ff")


def white(name="SK_Mat"):
    return bpy.data.materials.get(name) or C.mat_flat(name, (0.8, 0.8, 0.8))


def neutral_mats(slots):
    m = white()
    return {s: m for s in slots}


# ------------------------------------------------------------------ export
def build_export():
    C.reset()
    pieces = {}   # name -> (object, meta)
    assets = {}

    def add(asset, slot, obj, **meta):
        name = obj.name
        pieces[name] = (obj, dict(slot=slot, **meta))
        assets.setdefault(asset, []).append(name)

    for shape in K.SHAPES:
        parts = K.build(shape, neutral_mats(["Blade", "Edge", "Guard", "Handle", "Wrap", "Pommel", "Gem"]))
        for slot, o in parts.items():
            o.name = "SK_Knife_%s_%s" % (shape, slot)
            add("Knife_" + shape, slot, o)
    for theme, fn in B.THEMES.items():
        P = "SK_Barrel_%s_" % theme
        parts = fn(P, neutral_mats(["Gold", "Coin", "Gem", "Latch", "Rock", "Glow", "Crystal", "Ice", "Tentacle", "Claw", "Chain", "Seal"]))
        for slot, o in parts.items():
            o.name = P + slot
            add("BarrelDecor_" + theme, slot, o)
    pm = neutral_mats(list(PR.GROUP.keys()))
    parts = PR.build(pm)
    for slot, o in parts.items():
        o.name = "SK_Pirate_" + slot
        asset = "PirateExtra_" + slot if slot in PR.ACCESSORIES else "Pirate"
        add(asset, slot, o, group=PR.GROUP[slot])
    for asset, spec in (("DragonCoil", COIL), ("DragonRing", RING)):
        parts = D.build_dragon("SK_%s_" % asset, colors=DRAGON_NEUTRAL, slots=True, **spec)
        for slot, o in parts.items():
            o.name = "SK_%s_%s" % (asset, slot)
            add(asset, slot, o)
    add("Petal", "Petal", X.petal("SK_Petal", white()))
    add("RuneRing", "Ring", X.rune_ring("SK_RuneRing", white()))
    add("KrakenCapsule", "Capsule", X.kraken_capsule("SK_Kraken_Capsule", white()))

    objs = [o for o, _ in pieces.values()]
    C.apply_mods(objs)
    for o in objs:
        C.activate([o])
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    catalog = {}
    for name, (o, meta) in pieces.items():
        o.data.name = name
        mat = white()
        o.data.materials.clear()
        o.data.materials.append(mat)
        for p in o.data.polygons:
            p.material_index = 0
        lo, hi = C.vbox(o)
        tris = C.tri_count([o])
        if tris > MAX_TRIS:
            raise SystemExit("too many triangles in %s: %d" % (name, tris))
        catalog[name] = dict(center=C.roblox_vec((lo + hi) / 2), size=C.roblox_size(hi - lo), tris=tris, **meta)
    fbx = os.path.join(C.EXPORT_DIR, "CursedBarrelSkins.fbx")
    C.export_fbx(objs, fbx)
    write_catalog(catalog, assets, fbx)
    total = sum(v["tris"] for v in catalog.values())
    print("exported %d pieces, %d assets, %d triangles -> %s" % (len(catalog), len(assets), total, fbx))


def _v(v):
    return "Vector3.new(%.4f, %.4f, %.4f)" % tuple(v)


def write_catalog(catalog, assets, fbx):
    import hashlib
    digest = hashlib.sha1(open(fbx, "rb").read()).hexdigest()[:12]
    joints = {g: C.roblox_vec(Vector(p)) for g, p in PR.JOINTS.items()}
    L = ["-- 자동 생성 파일 (roblox-cursed-barrel/blender/build_all.py). 손으로 고치지 마세요.",
         "-- Blender 스킨 조각 (칼 · 통 장식 · 해적 · 용 · 꽃잎 · 크라켄 마디)의 크기와 자리 (Roblox 좌표 · 스터드).",
         "--   칼   : 코등이가 원점, 칼끝이 +Y (KnifeModel 과 같은 약속)",
         "--   통   : 통 가운데가 원점, 높이 4 · 지름 3.5 기준 (MeshKit.barrel 과 같은 약속)",
         "--   해적 : 가슴 가운데가 원점, 정면 -Z. group 은 PirateModel 관절 이름",
         "--   용   : 도는 축(Y)이 원점을 지난다. DragonCoil 은 칼 크기, DragonRing 은 통 위를 도는 크기",
         "return {",
         '\tFile = "CursedBarrelSkins",',
         '\tDigest = "%s",' % digest,
         "\tPirateJoints = {"]
    for g in ("body", "head", "jaw", "armL", "armR", "tail"):
        L.append("\t\t%s = %s," % (g, _v(joints[g])))
    L.append("\t},")
    L.append("\tPieces = {")
    for name in sorted(catalog):
        e = catalog[name]
        extra = ', slot = "%s"' % e["slot"]
        if e.get("group"):
            extra += ', group = "%s"' % e["group"]
        L.append("\t\t%s = { center = %s, size = %s, tris = %d%s }," % (name, _v(e["center"]), _v(e["size"]), e["tris"], extra))
    L.append("\t},")
    L.append("\tAssets = {")
    for a in sorted(assets):
        L.append("\t\t%s = { %s }," % (a, ", ".join('"%s"' % n for n in assets[a])))
    L.append("\t},")
    L.append("}")
    path = os.path.join(C.EXPORT_DIR, "SkinMeshCatalog.lua")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")
    print("catalog ->", path)


# ------------------------------------------------------------------ thumbnails
def lerp(a, b, t):
    return C.lerp_rgb(a, b, t)


def knife_mats(s):
    blade = s.get("blade", (206, 210, 214))
    guard = s.get("guard", (126, 104, 62))
    handle = s.get("handle", (64, 42, 28))
    return {
        "Blade": C.mat_roblox("Blade", blade, s.get("bladeMaterial", "Metal")),
        "Edge": C.mat_roblox("Edge", lerp(blade, (255, 255, 255), 0.45), "Neon" if s.get("bladeMaterial") == "Neon" else "Metal"),
        "Guard": C.mat_roblox("Guard", guard, "Metal"), "Pommel": C.mat_roblox("Pommel", guard, "Metal"),
        "Handle": C.mat_roblox("Handle", handle, s.get("handleMaterial", "Wood")),
        "Wrap": C.mat_roblox("Wrap", lerp(handle, (0, 0, 0), 0.45), "Fabric"),
        "Gem": C.mat_roblox("Gem", s.get("trail", blade), "Neon"),
    }


def barrel_decor_mats(s):
    hoop = s.get("hoop", (58, 48, 42))
    body = s.get("body", (122, 78, 44))
    glow = s.get("glow", hoop)
    emit = (s.get("fx") or {}).get("emit", glow)
    return {
        "Gold": C.mat_roblox("Gold", hoop, "Metal"), "Coin": C.mat_roblox("Coin", (255, 214, 90), "Metal"),
        "Gem": C.mat_roblox("DGem", emit, "Neon"), "Latch": C.mat_roblox("Latch", hoop, "Plastic"),
        "Rock": C.mat_roblox("Rock", body, "Basalt"), "Glow": C.mat_roblox("DGlow", hoop if s.get("hoopMaterial") == "Neon" else emit, "Neon"),
        "Crystal": C.mat_roblox("Crystal", hoop, "Glass"), "Ice": C.mat_roblox("Ice", s.get("lid", hoop), "Ice"),
        "Tentacle": C.mat_roblox("Tent", lerp(body, (96, 60, 150), 0.55), "SmoothPlastic"),
        "Claw": C.mat_roblox("Claw", hoop, "Metal"), "Chain": C.mat_roblox("Chain", (70, 74, 80), "Metal"),
        "Seal": C.mat_roblox("Seal", (245, 230, 190), "SmoothPlastic"),
    }


def dragon_colors(s):
    fx = s.get("fx") or {}
    col = fx.get("emit", (68, 240, 218))
    acc = fx.get("accent", fx.get("halo", (255, 212, 126)))
    hexs = lambda c: "#%02x%02x%02x" % tuple(c)
    return (hexs(col), hexs(lerp(col, (0, 0, 0), 0.7)), hexs(acc), hexs(lerp(acc, (255, 255, 255), 0.5)), hexs(acc), hexs(lerp(acc, (255, 255, 255), 0.6)))


def dress(kind, s, objs, rank):
    """Thumbnail-only FX: sparkles, glow orbs, rune ring, dragon, petals (more for pricier skins)."""
    extra = []
    if rank < 2:
        return extra
    lo, hi = C.bbox(objs)
    c = (lo + hi) / 2
    ext = hi - lo
    size = max(ext)
    fx = s.get("fx") or {}
    col = C.rgb(fx.get("emit", s.get("trail", s.get("glow", (255, 230, 160)))))
    acc = C.rgb(fx.get("accent", fx.get("halo", fx.get("emit", (255, 230, 160)))))
    extra += C.scatter_cards("Spark", "sparkle.png", col, 6.0, {2: 5, 3: 9, 4: 12, 5: 16}[rank], c, max(ext.x, ext.y) * 0.75,
                             ext.z * 0.9, size * 0.07, seed=rank * 3)
    if rank >= 3:
        extra += C.scatter_cards("Orb", "orb.png", col, 3.0, {3: 6, 4: 9, 5: 12}[rank], c, max(ext.x, ext.y) * 0.9, ext.z, size * 0.05, seed=rank * 7)
    if rank >= 4 and kind == "Ghost":
        ring = X.rune_ring("ThumbRing", C.mat_glow("RingGlow", acc, 5.0), R=max(ext.x, ext.y) * 0.75)
        ring.location = (c.x, c.y, lo.z + 0.02)
        extra.append(ring)
    if rank >= 5:
        extra += C.scatter_cards("Petal", "petal.png", C.rgb((255, 170, 205)), 1.6, 22, c + Vector((0, 0, ext.z * 0.1)), max(ext.x, ext.y) * 1.0,
                                 ext.z * 1.1, size * 0.07, seed=5)
    return extra


def thumb_knife(s):
    shape = s.get("shape", "dagger")
    rank = RANK.get(s.get("rarity", "common"), 1)
    parts = K.build(shape, knife_mats(s))
    if rank < 2:
        C.remove([parts.pop("Gem")])
    objs = list(parts.values())
    if rank >= 5:
        d = D.build_dragon("TD_", colors=dragon_colors(s), slots=True, **COIL)
        objs += list(d.values())
    extra = dress("Knife", s, objs, rank)
    return objs, extra, dict(az=20, el=10, roll=-35, lens=70, margin=1.05)


def thumb_barrel(s):
    rank = RANK.get(s.get("rarity", "common"), 1)
    body = C.mat_roblox("Body", s.get("body", (122, 78, 44)), s.get("bodyMaterial", "Wood"))
    hoop = C.mat_roblox("Hoop", s.get("hoop", (58, 48, 42)), s.get("hoopMaterial", "Metal"))
    lid = C.mat_roblox("Lid", s.get("lid", s.get("body", (96, 62, 36))), s.get("hoopMaterial", "Metal") if s.get("drum") or s.get("ribbed") else s.get("bodyMaterial", "Wood"))
    objs = (B.drum_body if (s.get("drum") or s.get("ribbed")) else B.cask_body)("TB_", body, hoop, lid)
    theme = B.DECOR_OF.get(s["id"])
    if theme:
        objs += list(B.THEMES[theme]("TBD_", barrel_decor_mats(s)).values())
    if rank >= 5:
        d = D.build_dragon("TR_", colors=dragon_colors(s), slots=True, **RING)
        objs += list(d.values())
    extra = dress("Barrel", s, objs, rank)
    return objs, extra, dict(az=25, el=16, margin=1.08)


def thumb_ghost(s):
    rank = RANK.get(s.get("rarity", "common"), 1)
    cols = PC.slots(s)
    M = {k: C.mat_roblox("P" + k, c, m, t) for k, (c, m, t) in cols.items()}
    parts = PR.build(M)
    th = PR.THEME.get(s["id"], {"add": [], "hide": []})
    keep, drop = [], []
    for slot, o in parts.items():
        if (slot in PR.ACCESSORIES and slot not in th["add"]) or slot in th["hide"]:
            drop.append(o)
        else:
            keep.append(o)
    C.remove(drop)
    objs = keep
    if rank >= 5:
        d = D.build_dragon("TG_", colors=dragon_colors(s), slots=True, **COIL)
        for o in d.values():
            o.scale = (3.3, 3.3, 3.3)
            o.location = (0, 0, -3.6)
        bpy.context.view_layer.update()
        objs += list(d.values())
    extra = dress("Ghost", s, objs, rank)
    return objs, extra, dict(az=155, el=10, margin=1.05)


def render_all(only=None):
    skins = SD.load(os.environ["GAMECONFIG_LUA"])
    cards = os.path.join(C.THUMB_DIR, "cards")
    os.makedirs(cards, exist_ok=True)
    index = []
    for kind, fn in (("Knife", thumb_knife), ("Barrel", thumb_barrel), ("Ghost", thumb_ghost)):
        for s in skins[kind]:
            key = "%s_%s" % (kind, s["id"])
            if only and key not in only:
                continue
            C.reset()
            objs, extra, view = fn(s)
            path = os.path.join(C.THUMB_DIR, key + ".png")
            rank = RANK.get(s.get("rarity", "common"), 1)
            C.render_thumb(objs + extra, path, min(5, rank), fit=objs, **view)
            make_card(path, os.path.join(cards, key + ".png"), s.get("rarity", "common"))
            index.append(dict(kind=kind, id=s["id"], name=s.get("name"), rarity=s.get("rarity"), price=s.get("price"), file=key + ".png"))
            print("thumb", key)
    with open(os.path.join(C.THUMB_DIR, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, ensure_ascii=False, indent=1)


RARITY_RGB = {"common": (198, 190, 176), "rare": (120, 190, 255), "epic": (196, 130, 255), "legend": (255, 186, 78), "mythic": (255, 92, 150)}


def make_card(src, dst, rarity, size=512):
    import numpy as np
    from PIL import Image, ImageFilter, ImageDraw
    col = np.array(RARITY_RGB.get(rarity, RARITY_RGB["common"]), dtype=float) / 255
    y, x = (np.mgrid[0:size, 0:size] / size - 0.5) * 2
    r = np.hypot(x, y)
    base = np.clip(1 - r * 0.75, 0, 1)[..., None]
    bg = (col * 0.55 * base + np.array([0.06, 0.07, 0.1]) * (1 - base))
    if rarity in ("legend", "mythic"):
        ang = np.arctan2(y, x)
        rays = (np.cos(ang * 12) * 0.5 + 0.5) ** 6 * np.clip(1 - r, 0, 1) * 0.35
        bg = bg + col * rays[..., None]
    img = Image.fromarray((np.clip(bg, 0, 1) * 255).astype(np.uint8), "RGB").convert("RGBA")
    item = Image.open(src).convert("RGBA").resize((int(size * 0.9), int(size * 0.9)), Image.LANCZOS)
    glow = Image.new("RGBA", item.size, tuple(int(c * 255) for c in col) + (0,))
    glow.putalpha(item.getchannel("A").filter(ImageFilter.GaussianBlur(14)).point(lambda v: int(v * 0.8)))
    off = ((size - item.size[0]) // 2, (size - item.size[1]) // 2)
    img.alpha_composite(glow, off)
    img.alpha_composite(item, off)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 6, size - 7, size - 7], radius=48, outline=tuple(int(c * 255) for c in col) + (255,), width=10)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=52, fill=255)
    img.putalpha(mask)
    img.save(dst)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))
    if mode in ("export", "all"):
        build_export()
    if mode in ("thumbs", "all"):
        render_all(only)
