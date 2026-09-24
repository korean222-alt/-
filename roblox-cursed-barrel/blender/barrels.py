"""Barrel decor meshes that sit on top of the existing Cask / Drum body (MeshKit.barrel).

Frame: same as the Phase 15 cask - centred at the origin, height 4 along Z, diameter 3.5.
MeshKit scales everything by (diameter/3.5, height/4).

Rule: nothing may cover the knife-slot band (|z| < 1.45) because knives are stabbed there.
Decor lives on the top rim, around the foot, or floats (the dragon ring is animated in-game).
"""
import math
import random
from mathutils import Vector
import common as C

RIM = 1.72      # radius at the chime (top / bottom edge)
TOP = 2.0
BOT = -2.0


def _ring_pos(r, a, z):
    return (r * math.cos(a), r * math.sin(a), z)


def treasure(P, M):
    out = {}
    gold = []
    for z in (1.72, -1.72):
        gold.append(C.torus(P + "Band%d" % (z > 0), RIM + 0.07, 0.07, loc=(0, 0, z), mat=M["Gold"], maj=48, mnr=8, scale=(1, 1, 1.6)))
        for i in range(16):
            a = i / 16 * 2 * math.pi
            gold.append(C.sphere(P + "Stud", 0.06, loc=_ring_pos(RIM + 0.17, a, z), mat=M["Gold"], segs=8, rings=5))
    # corner brackets on the chime (top and foot only)
    for i in range(4):
        a = (i + 0.5) / 4 * 2 * math.pi
        for z0, z1 in ((1.5, 2.05), (-2.05, -1.5)):
            p0, p1 = Vector(_ring_pos(RIM + 0.12, a, z0)), Vector(_ring_pos(RIM + 0.12, a, z1))
            gold.append(C.tube(P + "Bracket", [p0, p1], [0.11, 0.11], segs=4, mat=M["Gold"], profile=[(1, 0.35), (-1, 0.35), (-1, -0.35), (1, -0.35)]))
    out["Gold"] = C.join(gold, P + "Gold")
    # coins spilling around the foot and a few on the rim
    rnd = random.Random(4)
    coins = []
    for i in range(46):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(1.85, 2.55)
        z = BOT + 0.05 + rnd.uniform(0, 0.25) * (2.55 - r)
        coins.append(C.cyl(P + "Coin", 0.16, 0.04, loc=_ring_pos(r, a, z), rot=(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.5, 0.5), 0), mat=M["Coin"], verts=12))
    for i in range(8):
        a = rnd.uniform(0, 2 * math.pi)
        coins.append(C.cyl(P + "RimCoin", 0.16, 0.04, loc=_ring_pos(RIM - 0.05, a, TOP + 0.02 + i % 3 * 0.04), rot=(0.25, 0, a), mat=M["Coin"], verts=12))
    out["Coin"] = C.join(coins, P + "Coin")
    gems = []
    for i in range(4):
        a = i / 4 * 2 * math.pi
        gems.append(C.ico(P + "Gem", 0.13, loc=_ring_pos(RIM + 0.2, a, 1.72), scale=(0.6, 1, 1.2), rot=(0, 0, a), mat=M["Gem"], sub=1))
    out["Gem"] = C.join(gems, P + "Gem")
    return out


def kimchi(P, M):
    latches = []
    for i in range(4):
        a = i / 4 * 2 * math.pi + math.pi / 4
        rot = (0, 0, a)
        c = Vector(_ring_pos(RIM + 0.14, a, 1.78))
        latches.append(C.cube(P + "Latch", (0.14, 0.5, 0.55), loc=c, rot=rot, mat=M["Latch"], bevel=0.05))
        latches.append(C.cube(P + "LatchLip", (0.3, 0.44, 0.1), loc=c + Vector((0, 0, 0.3)) - Vector((math.cos(a), math.sin(a), 0)) * 0.08, rot=rot, mat=M["Latch"], bevel=0.03))
        latches.append(C.cyl(P + "Hinge", 0.06, 0.5, loc=c - Vector((0, 0, 0.22)) + Vector((math.cos(a), math.sin(a), 0)) * 0.04,
                             rot=(math.pi / 2, 0, a + math.pi / 2), mat=M["Latch"], verts=10))
    # rubber seal ring under the lid
    latches.append(C.torus(P + "Seal", RIM + 0.02, 0.05, loc=(0, 0, 1.98), mat=M["Latch"], maj=48, mnr=6))
    return {"Latch": C.join(latches, P + "Latch")}


def volcano(P, M):
    rnd = random.Random(7)
    rocks, glow = [], []
    for i in range(22):
        a = i / 22 * 2 * math.pi + rnd.uniform(-0.1, 0.1)
        r = RIM + rnd.uniform(0.05, 0.35)
        s = rnd.uniform(0.22, 0.42)
        rocks.append(C.ico(P + "Rock", s, loc=_ring_pos(r, a, BOT + s * 0.6), scale=(1, rnd.uniform(0.7, 1.2), rnd.uniform(0.9, 1.6)),
                           rot=(rnd.uniform(0, 3), rnd.uniform(0, 3), a), mat=M["Rock"], sub=1))
    for i in range(7):
        a = i / 7 * 2 * math.pi + 0.3
        rocks.append(C.spike(P + "Spire", _ring_pos(RIM + 0.1, a, BOT + 0.2), _ring_pos(RIM + 0.35, a, BOT + 1.05), 0.2, mat=M["Rock"], verts=5))
    for i in range(6):
        a = i / 6 * 2 * math.pi
        rocks.append(C.ico(P + "RimRock", 0.2, loc=_ring_pos(RIM, a, TOP + 0.05), scale=(1.3, 0.9, 0.7), rot=(0, 0, a), mat=M["Rock"], sub=1))
    # glowing lava drips from the top rim (stop above the knife band)
    for i in range(12):
        a = i / 12 * 2 * math.pi + 0.13
        length = rnd.uniform(0.25, 0.5)
        pts = [Vector(_ring_pos(RIM + 0.06, a, TOP - 0.02 - t * length)) for t in (0, 0.5, 1)]
        glow.append(C.tube(P + "Drip", pts, [0.07, 0.06, 0.09], segs=6, mat=M["Glow"]))
        glow.append(C.sphere(P + "DripEnd", 0.08, loc=tuple(pts[-1]), mat=M["Glow"], segs=8, rings=5))
    # magma seams between the foot rocks
    glow.append(C.torus(P + "Magma", RIM + 0.12, 0.06, loc=(0, 0, BOT + 0.12), mat=M["Glow"], maj=48, mnr=6))
    return {"Rock": C.join(rocks, P + "Rock"), "Glow": C.join(glow, P + "Glow")}


def _crystal(name, base, direction, length, r, mat):
    d = Vector(direction).normalized()
    pts = [Vector(base), Vector(base) + d * length * 0.8, Vector(base) + d * length]
    hexp = [(math.cos(k * math.pi / 3), math.sin(k * math.pi / 3)) for k in range(6)]
    return C.tube(name, pts, [r, r * 0.95, 0.01], segs=6, mat=mat, profile=hexp)


def frost(P, M):
    rnd = random.Random(11)
    cr = []
    for cluster in range(4):
        a0 = cluster / 4 * 2 * math.pi + 0.4
        for k in range(4):
            a = a0 + rnd.uniform(-0.18, 0.18)
            base = Vector(_ring_pos(RIM - 0.05, a, TOP))
            out_dir = Vector((math.cos(a), math.sin(a), 0))
            d = out_dir * rnd.uniform(0.2, 0.7) + Vector((0, 0, 1)) + Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 0))
            cr.append(_crystal(P + "Crystal", base, d, rnd.uniform(0.45, 0.9), rnd.uniform(0.08, 0.14), M["Crystal"]))
    for cluster in range(5):
        a0 = cluster / 5 * 2 * math.pi
        for k in range(3):
            a = a0 + rnd.uniform(-0.15, 0.15)
            base = Vector(_ring_pos(RIM + 0.05, a, BOT + 0.05))
            d = Vector((math.cos(a), math.sin(a), 0)) * rnd.uniform(0.4, 1.0) + Vector((0, 0, 1))
            cr.append(_crystal(P + "FootCrystal", base, d, rnd.uniform(0.35, 0.7), rnd.uniform(0.08, 0.13), M["Crystal"]))
    ice = []
    for i in range(18):
        a = i / 18 * 2 * math.pi
        L = rnd.uniform(0.12, 0.34)
        ice.append(C.spike(P + "Icicle", _ring_pos(RIM + 0.1, a, 1.82), _ring_pos(RIM + 0.1, a, 1.82 - L), 0.055, mat=M["Ice"], verts=6))
    ice.append(C.torus(P + "Snow", RIM + 0.03, 0.09, loc=(0, 0, TOP + 0.02), mat=M["Ice"], maj=48, mnr=8, scale=(1, 1, 0.7)))
    return {"Crystal": C.join(cr, P + "Crystal"), "Ice": C.join(ice, P + "Ice")}


def abyss(P, M):
    tent = []
    for i in range(5):
        a = i / 5 * 2 * math.pi + 0.2
        pts, rad = [], []
        for k in range(18):
            t = k / 17
            r = RIM + 0.25 + 0.25 * t
            ang = a + 0.35 * t
            z = BOT + 0.1 + 0.55 * math.sin(t * math.pi * 0.9)
            curl = t ** 3
            pts.append(Vector(_ring_pos(r + 0.3 * curl * math.cos(t * 7), ang, z + 0.35 * curl)))
            rad.append(0.16 * (1 - t) + 0.02)
        tent.append(C.tube(P + "Tentacle", pts, rad, segs=8, mat=M["Tentacle"]))
        for k in range(3, 14, 2):
            t = k / 17
            p = pts[k]
            tent.append(C.sphere(P + "Sucker", 0.05 * (1.2 - t), loc=tuple(p + Vector((0, 0, -rad[k] * 0.8))), scale=(1, 1, 0.5), mat=M["Tentacle"], segs=8, rings=4))
    glow = []
    for z in (1.66, -1.66):
        for k in range(24):
            a0, a1 = k / 24 * 2 * math.pi, (k + 0.6) / 24 * 2 * math.pi
            pts = [Vector(_ring_pos(RIM + 0.1, a0 + (a1 - a0) * t, z + (0.05 if k % 3 == 0 else 0) * math.sin(t * math.pi))) for t in (0, 0.5, 1)]
            glow.append(C.tube(P + "Rune", pts, [0.035] * 3, segs=5, mat=M["Glow"]))
    return {"Tentacle": C.join(tent, P + "Tentacle"), "Glow": C.join(glow, P + "Glow")}


def dragon_seal(P, M):
    claws = []
    for i in range(4):
        a = i / 4 * 2 * math.pi + math.pi / 4
        o = Vector((math.cos(a), math.sin(a), 0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        palm_c = o * (RIM - 0.15) + Vector((0, 0, TOP + 0.1))
        claws.append(C.sphere(P + "Palm", 0.28, loc=tuple(palm_c), scale=(1, 1, 0.55), rot=(0, 0, a), mat=M["Claw"], segs=14, rings=8))
        claws.append(C.sphere(P + "Knuckle", 0.2, loc=tuple(o * (RIM + 0.05) + Vector((0, 0, TOP + 0.05))), rot=(0, 0, a), mat=M["Claw"], segs=12, rings=6))
        for k in (-1, 0, 1):
            base = o * (RIM + 0.12) + side * (k * 0.17) + Vector((0, 0, TOP - 0.02))
            tip = base + o * 0.18 - Vector((0, 0, 0.5)) + side * (k * 0.05)
            claws.append(C.spike(P + "Talon", tuple(base), tuple(tip), 0.08, mat=M["Claw"], verts=6, bend=tuple(o * 0.12)))
        # scaled wrist going back over the lid edge
        claws.append(C.spike(P + "Wrist", tuple(palm_c), tuple(palm_c - o * 0.6 + Vector((0, 0, 0.15))), 0.2, mat=M["Claw"], verts=8))
    chain = []
    n = 34
    for k in range(n):
        a = k / n * 2 * math.pi
        rot = (math.pi / 2 if k % 2 else 0, 0, a + math.pi / 2)
        chain.append(C.torus(P + "Link", 0.12, 0.035, loc=_ring_pos(RIM + 0.14, a, -1.62), rot=rot, mat=M["Chain"], maj=12, mnr=5, scale=(1.4, 1, 1)))
    seals = []
    for i in range(4):
        a = i / 4 * 2 * math.pi
        o = Vector((math.cos(a), math.sin(a), 0))
        c = o * (RIM + 0.14) + Vector((0, 0, -1.85))
        seals.append(C.cube(P + "Talisman", (0.34, 0.03, 0.62), loc=tuple(c), rot=(0.08, 0, a + math.pi / 2), mat=M["Seal"]))
    return {"Claw": C.join(claws, P + "Claw"), "Chain": C.join(chain, P + "Chain"), "Seal": C.join(seals, P + "Seal")}


THEMES = {
    "treasure": treasure,
    "kimchi": kimchi,
    "volcano": volcano,
    "frost": frost,
    "abyss": abyss,
    "dragon": dragon_seal,
}

# which barrel skins use which decor set
DECOR_OF = {
    "treasure": "treasure", "kimchi": "kimchi", "volcano": "volcano", "frost": "frost", "abyss": "abyss",
    "tide_dragon": "dragon", "crimson_dragon": "dragon", "moon_dragon": "dragon",
}


# ------------------------------------------------------------------ base bodies (thumbnail only - the game uses CB_Cask / CB_Drum)
def cask_body(P, body_mat, hoop_mat, lid_mat):
    def r(z):
        return 1.62 + 0.19 * (1 - (z / 2) ** 2)

    prof = [(r(z), z) for z in [i / 20 * 4 - 2 for i in range(21)]]

    def planks(t, z):
        n = 18
        f = (t / (2 * math.pi) * n) % 1
        return 1 - 0.012 * math.exp(-((min(f, 1 - f)) / 0.03) ** 2)
    staves = C.lathe(P + "Staves", prof, segs=144, mat=body_mat, radial=planks, cap_top=False, cap_bottom=False)
    lid = C.cyl(P + "Lid", 1.6, 0.08, loc=(0, 0, 1.9), mat=lid_mat, verts=48)
    foot = C.cyl(P + "Foot", 1.6, 0.08, loc=(0, 0, -1.9), mat=lid_mat, verts=48)
    hoops = []
    for z in (-1.55, -1.25, 1.25, 1.55):
        hoops.append(C.torus(P + "Hoop", r(z) + 0.02, 0.05, loc=(0, 0, z), mat=hoop_mat, maj=64, mnr=6, scale=(1, 1, 1.8)))
    return [staves, lid, foot] + hoops


def drum_body(P, body_mat, hoop_mat, lid_mat):
    prof = [(1.72, -2), (1.76, -1.96), (1.76, 1.96), (1.72, 2)]
    shell = C.lathe(P + "Shell", prof, segs=64, mat=body_mat, cap_top=False, cap_bottom=False)
    parts = [shell, C.cyl(P + "Lid", 1.72, 0.06, loc=(0, 0, 1.95), mat=lid_mat, verts=64), C.cyl(P + "Foot", 1.72, 0.06, loc=(0, 0, -1.95), mat=lid_mat, verts=64)]
    for z in (-0.7, 0.7):
        parts.append(C.torus(P + "Roll", 1.78, 0.06, loc=(0, 0, z), mat=hoop_mat, maj=64, mnr=8))
    for z in (-1.99, 1.99):
        parts.append(C.torus(P + "Chime", 1.74, 0.05, loc=(0, 0, z), mat=hoop_mat, maj=64, mnr=8))
    parts.append(C.cyl(P + "Bung", 0.2, 0.08, loc=(0.9, 0.3, 2.0), mat=hoop_mat, verts=16))
    return parts
