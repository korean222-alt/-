"""The ghost pirate captain that bursts out of the barrel (PirateModel.lua).

Blender frame: pivot = chest centre, front = +Y (Roblox -Z), up = +Z.
Pieces are grouped exactly like PirateModel's joints so the existing animation (jaw scream,
arm reach, lean, tail sway) keeps working:
  body  (0, 0, 0)        head (0, 0, 1.4)       jaw (0, 0.35, 1.73)
  armL  (-1.25, 0, 1.0)  armR (1.25, 0, 1.0)    tail (0, 0, -1.55)
"""
import math
import random
from mathutils import Vector
import common as C

JOINTS = {
    "body": (0, 0, 0), "head": (0, 0, 1.4), "jaw": (0, 0.35, 1.73),
    "armL": (-1.25, 0, 1.0), "armR": (1.25, 0, 1.0), "tail": (0, 0, -1.55),
}

# slot -> group
GROUP = {
    "Coat": "body", "CoatTrim": "body", "Vest": "body", "Sash": "body", "Belt": "body", "Buckle": "body",
    "Epaulette": "body", "Neck": "body", "Iron": "body",
    "Head": "head", "FaceDark": "head", "MouthDark": "head", "Eye": "head", "Patch": "head", "Teeth": "head",
    "Hat": "head", "HatTrim": "head", "HatSkull": "head", "Feather": "head",
    "Jaw": "jaw", "JawTeeth": "jaw", "Beard": "jaw",
    "SleeveL": "armL", "CuffL": "armL", "LaceL": "armL", "Hook": "armL",
    "SleeveR": "armR", "CuffR": "armR", "LaceR": "armR", "HandR": "armR",
    "Mist": "tail", "Rags": "tail",
    # theme accessories
    "ChefHat": "head", "TentacleBeard": "jaw", "VoidCrown": "head", "FlameCrown": "head", "FinCrown": "head", "DragonHorns": "head",
}


def _torso_loft(name, levels, mat, dy=0.0, segs=28, n=2.8):
    rings = [C.ring_at(C.superellipse(w, d, n, segs), z, 0, dy) for (z, w, d) in levels]
    o = C.loft(name, rings, mat)
    return o


def body(P, M):
    out = {}
    coat = [_torso_loft(P + "Torso", [(-1.28, 2.42, 1.34), (-0.95, 2.22, 1.2), (-0.62, 2.08, 1.14), (0.0, 2.22, 1.2),
                                       (0.62, 2.34, 1.26), (1.02, 2.3, 1.16), (1.2, 2.0, 1.0), (1.34, 1.2, 0.8)], M["Coat"])]
    # standing collar (open at the front)
    for sx in (-1, 1):
        coat.append(C.cube(P + "Collar%d" % sx, (0.42, 0.14, 0.62), loc=(sx * 0.5, 0.42, 1.42), rot=(math.radians(-18), math.radians(sx * 10), math.radians(sx * 16)),
                           mat=M["Coat"], bevel=0.05))
    # coat tails behind, flaring out
    for sx in (-1, 1):
        rings = []
        for i in range(8):
            t = i / 7
            z = -0.9 - t * 1.75
            x = sx * (0.55 + 0.25 * t)
            y = -0.42 - 0.18 * t
            w = 0.95 + 0.25 * t
            rings.append([(x + px, y + py, z) for (px, py) in C.superellipse(w, 0.16, 2.2, 12)])
        coat.append(C.loft(P + "Tail%d" % sx, rings, M["Coat"]))
    out["Coat"] = C.join(coat, P + "Coat")

    out["Vest"] = _torso_loft(P + "Vest", [(-1.05, 0.9, 1.16), (-0.6, 0.95, 1.2), (0.3, 1.0, 1.24), (1.0, 0.8, 1.16), (1.22, 0.6, 1.0)], M["Vest"], dy=0.12, n=2.4)

    trim = []
    for sx in (-1, 1):
        pts = [(sx * 0.52, 0.66, -1.24), (sx * 0.5, 0.63, -0.6), (sx * 0.52, 0.66, 0.1), (sx * 0.5, 0.64, 0.7), (sx * 0.42, 0.5, 1.12)]
        trim.append(C.tube(P + "Edge%d" % sx, pts, [0.06] * 5, segs=6, mat=M["CoatTrim"]))
        for k in range(3):
            trim.append(C.sphere(P + "Button", 0.075, loc=(sx * 0.72, 0.64, 0.45 - k * 0.38), mat=M["CoatTrim"], segs=10, rings=6))
    hem = [(x, y, -1.26) for (x, y) in C.superellipse(2.46, 1.38, 2.8, 40)]
    trim.append(C.tube(P + "Hem", hem + [hem[0]], [0.05] * (len(hem) + 1), segs=6, mat=M["CoatTrim"], cap=False))
    out["CoatTrim"] = C.join(trim, P + "CoatTrim")

    sash = [(-0.95, 0.6, 1.0), (-0.45, 0.7, 0.55), (0.1, 0.72, 0.0), (0.6, 0.7, -0.45), (0.95, 0.62, -0.85)]
    out["Sash"] = C.join([C.tube(P + "SashBand", sash, [(0.16, 0.05)] * 5, segs=8, mat=M["Sash"]),
                          C.sphere(P + "Knot", 0.16, loc=(0.95, 0.62, -0.88), mat=M["Sash"], segs=10, rings=6),
                          C.spike(P + "SashEnd", (0.95, 0.62, -0.95), (1.05, 0.66, -1.45), 0.1, mat=M["Sash"], verts=6)], P + "Sash")

    belt = [C.ring_at(C.superellipse(2.2, 1.24, 2.8, 32), z, 0, 0) for z in (-0.8, -0.5)]
    out["Belt"] = C.loft(P + "Belt", belt, M["Belt"])
    buckle = [C.cube(P + "BuckleFrame%d" % i, s, loc=l, mat=M["Buckle"], bevel=0.02) for i, (s, l) in enumerate([
        ((0.5, 0.06, 0.08), (0, 0.66, -0.47)), ((0.5, 0.06, 0.08), (0, 0.66, -0.83)),
        ((0.08, 0.06, 0.44), (-0.22, 0.66, -0.65)), ((0.08, 0.06, 0.44), (0.22, 0.66, -0.65)), ((0.05, 0.08, 0.36), (0, 0.68, -0.65))])]
    out["Buckle"] = C.join(buckle, P + "Buckle")

    ep = []
    for sx in (-1, 1):
        ep.append(C.sphere(P + "Ep%d" % sx, 0.45, loc=(sx * 1.12, 0, 1.2), scale=(1.1, 1.0, 0.32), mat=M["Epaulette"], segs=18, rings=8))
        for k in range(9):
            a = k / 8 * math.pi - math.pi / 2
            base = (sx * (1.12 + 0.4 * math.cos(a) * 0 + 0.42), 0.42 * math.sin(a), 1.12)
            ep.append(C.cyl(P + "Fringe", 0.035, 0.34, loc=(base[0], base[1], 0.95), mat=M["Epaulette"], verts=6))
    out["Epaulette"] = C.join(ep, P + "Epaulette")

    out["Neck"] = C.cyl(P + "NeckCyl", 0.34, 0.6, loc=(0, 0, 1.4), mat=M["Neck"], verts=16)

    chain = []
    for k in range(9):
        t = k / 8
        x = -0.9 + 1.8 * t
        z = -0.95 - math.sin(t * math.pi) * 0.32
        chain.append(C.torus(P + "Link", 0.08, 0.025, loc=(x, 0.7, z), rot=(0, math.pi / 2 if k % 2 else 0, 0.3), mat=M["Iron"], maj=10, mnr=5, scale=(1.4, 1, 1)))
    out["Iron"] = C.join(chain, P + "Iron")
    return out


def _tricorn(P, M, zc=2.96):
    R_x, R_y, rc = 1.6, 1.06, 0.72
    rings_n, segs = 7, 72
    import bmesh
    bm = bmesh.new()
    grid = []
    for i in range(rings_n + 1):
        f = i / rings_n
        row = []
        for j in range(segs):
            th = 2 * math.pi * j / segs
            x = math.sin(th) * (rc + (R_x - rc) * f)
            y = math.cos(th) * (rc * 0.85 + (R_y - rc * 0.85) * f)
            lift = 0.62 * (1 - math.cos(3 * th)) / 2 * f ** 1.4
            row.append(bm.verts.new((x, y, zc + lift + 0.02 * f)))
        grid.append(row)
    for a, b in zip(grid, grid[1:]):
        for j in range(segs):
            k = (j + 1) % segs
            bm.faces.new((a[j], a[k], b[k], b[j]))
    brim = C.mesh_from_bm(P + "Brim", bm, M["Hat"])
    sol = brim.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.09
    sol.offset = 0
    crown = C.sphere(P + "Crown", 0.78, loc=(0, -0.02, zc + 0.12), scale=(1.05, 0.92, 0.72), mat=M["Hat"], segs=24, rings=12)
    hat = C.join([brim, crown], P + "Hat")
    edge = []
    for j in range(segs + 1):
        th = 2 * math.pi * j / segs
        x = math.sin(th) * R_x
        y = math.cos(th) * R_y
        lift = 0.62 * (1 - math.cos(3 * th)) / 2
        edge.append((x, y, zc + lift + 0.02))
    trim = C.tube(P + "BrimBraid", edge, [0.05] * len(edge), segs=6, mat=M["HatTrim"], cap=False)
    band = C.torus(P + "Band", 0.78, 0.07, loc=(0, -0.02, zc + 0.1), mat=M["HatTrim"], maj=40, mnr=6, scale=(1.05, 0.92, 1))
    skull = [C.sphere(P + "Skull", 0.2, loc=(0, 0.66, zc + 0.35), scale=(1, 0.7, 1.05), mat=M["HatSkull"], segs=14, rings=8),
             C.cube(P + "SkullJaw", (0.2, 0.1, 0.1), loc=(0, 0.68, zc + 0.17), mat=M["HatSkull"], bevel=0.03)]
    for sx in (-1, 1):
        skull.append(C.tube(P + "Bone%d" % sx, [(-0.34 * sx, 0.7, zc + 0.02), (0.34 * sx, 0.7, zc + 0.42)], [0.035, 0.035], segs=6, mat=M["HatSkull"]))
        for end in (-1, 1):
            skull.append(C.sphere(P + "BoneEnd", 0.05, loc=(0.34 * sx * end, 0.7, zc + 0.22 + 0.2 * end * sx), mat=M["HatSkull"], segs=8, rings=5))
    # feather plume sweeping up and back from the right side
    pts, radii = [], []
    for i in range(14):
        t = i / 13
        pts.append((0.72 + 0.35 * t, -0.2 - 0.65 * t, zc + 0.3 + 1.25 * math.sin(t * 1.35)))
        w = 0.24 * math.sin(math.pi * min(1, t * 1.1 + 0.05)) + 0.02
        radii.append((w, 0.03))
    feather = C.tube(P + "Plume", pts, radii, segs=10, mat=M["Feather"], twist=0.6)
    return {"Hat": hat, "HatTrim": C.join([trim, band], P + "HatTrim"), "HatSkull": C.join(skull, P + "HatSkull"), "Feather": feather}


def head(P, M):
    out = {}
    hc = Vector((0, 0.05, 2.05))
    h = [C.sphere(P + "Skull", 0.84, loc=tuple(hc), scale=(1.0, 0.94, 1.02), mat=M["Head"], segs=32, rings=18)]
    for sx in (-1, 1):
        h.append(C.sphere(P + "Cheek%d" % sx, 0.3, loc=(sx * 0.48, 0.52, 1.92), scale=(1, 0.8, 0.8), mat=M["Head"], segs=14, rings=8))
    h.append(C.sphere(P + "BrowRidge", 0.5, loc=(0, 0.52, 2.42), scale=(1.45, 0.55, 0.45), mat=M["Head"], segs=20, rings=10))
    out["Head"] = C.join(h, P + "Head")
    dark = [C.sphere(P + "SocketL", 0.2, loc=(-0.34, 0.74, 2.24), scale=(1.15, 0.45, 1.0), mat=M["FaceDark"], segs=14, rings=8),
            C.sphere(P + "SocketR", 0.2, loc=(0.34, 0.74, 2.24), scale=(1.15, 0.45, 1.0), mat=M["FaceDark"], segs=14, rings=8),
            C.cyl(P + "Nose", 0.09, 0.14, loc=(0, 0.86, 2.02), rot=(math.pi / 2 + 0.2, 0, 0), r2=0.02, mat=M["FaceDark"], verts=3),
            C.cube(P + "BrowR", (0.44, 0.1, 0.09), loc=(0.34, 0.8, 2.46), rot=(0, math.radians(-22), 0), mat=M["FaceDark"], bevel=0.03)]
    out["FaceDark"] = C.join(dark, P + "FaceDark")
    out["MouthDark"] = C.sphere(P + "Mouth", 0.36, loc=(0, 0.54, 1.72), scale=(1.1, 0.5, 0.45), mat=M["MouthDark"], segs=16, rings=8)
    out["Eye"] = C.sphere(P + "EyeGlow", 0.1, loc=(0.34, 0.8, 2.24), scale=(1.0, 0.6, 1.15), mat=M["Eye"], segs=12, rings=8)
    patch = [C.sphere(P + "PatchCup", 0.24, loc=(-0.34, 0.78, 2.25), scale=(1.1, 0.35, 0.95), mat=M["Patch"], segs=14, rings=8)]
    strap = []
    for k in range(33):
        a = k / 32 * 2 * math.pi
        strap.append((0.86 * math.sin(a), 0.05 + 0.8 * math.cos(a), 2.3 + 0.24 * math.sin(a)))
    patch.append(C.tube(P + "Strap", strap, [0.03] * 33, segs=5, mat=M["Patch"], cap=False))
    out["Patch"] = C.join(patch, P + "Patch")
    teeth = []
    for k in range(6):
        x = (k - 2.5) * 0.11
        teeth.append(C.cube(P + "Tooth", (0.09, 0.08, 0.13), loc=(x, 0.78 - abs(x) * 0.35, 1.8), rot=(0, 0, -x * 0.9), mat=M["Teeth"], bevel=0.02))
    out["Teeth"] = C.join(teeth, P + "Teeth")
    out.update(_tricorn(P, M))
    return out


def jaw(P, M):
    j = [C.sphere(P + "JawBone", 0.5, loc=(0, 0.36, 1.58), scale=(1.1, 0.95, 0.42), mat=M["Jaw"], segs=20, rings=10),
         C.sphere(P + "Chin", 0.22, loc=(0, 0.68, 1.5), scale=(1.2, 0.8, 0.8), mat=M["Jaw"], segs=12, rings=8)]
    teeth = [C.cube(P + "LTooth", (0.08, 0.07, 0.11), loc=((k - 2) * 0.11, 0.76 - abs(k - 2) * 0.04, 1.66), mat=M["JawTeeth"], bevel=0.02) for k in range(5)]
    rnd = random.Random(5)
    beard = []
    for k in range(7):
        x0 = (k - 3) * 0.13
        pts, rad = [], []
        L = 1.0 + (3 - abs(k - 3)) * 0.22 + rnd.uniform(-0.1, 0.1)
        for i in range(10):
            t = i / 9
            pts.append((x0 * (1 + 0.3 * t) + 0.08 * math.sin(t * 7 + k), 0.62 - 0.1 * t, 1.46 - L * t))
            rad.append((0.07 * (1 - t * 0.7), 0.025))
        beard.append(C.tube(P + "Kelp%d" % k, pts, rad, segs=6, mat=M["Beard"], twist=1.2))
    return {"Jaw": C.join(j, P + "Jaw"), "JawTeeth": C.join(teeth, P + "JawTeeth"), "Beard": C.join(beard, P + "Beard")}


def arm(P, M, side):
    sx = -1 if side == "L" else 1
    x0 = sx * 1.25
    sleeve = [C.sphere(P + "Shoulder", 0.46, loc=(x0, 0, 1.0), mat=M["Sleeve" + side], segs=18, rings=10)]
    pts = [(x0, 0, 1.0), (x0 + sx * 0.06, 0.02, 0.3), (x0 + sx * 0.04, 0.08, -0.55)]
    sleeve.append(C.tube(P + "Sleeve", pts, [0.42, 0.37, 0.33], segs=16, mat=M["Sleeve" + side]))
    cuff = C.lathe(P + "Cuff", [(0.34, -0.5), (0.47, -0.62), (0.5, -0.82), (0.44, -0.86)], segs=20, mat=M["Cuff" + side],
                   loc=(x0 + sx * 0.04, 0.08, 0))
    cuff = C.join([cuff] + [C.sphere(P + "CuffBtn", 0.05, loc=(x0 + sx * 0.04, 0.08 + 0.49, -0.72 + k * 0.1), mat=M["Cuff" + side], segs=8, rings=5) for k in (-1, 1)], P + "Cuff")
    lace = C.lathe(P + "Lace", [(0.2, -0.84), (0.42, -0.9), (0.38, -1.0), (0.18, -0.98)], segs=40, mat=M["Lace" + side],
                   radial=lambda t, z: 1 + 0.12 * math.sin(t * 10), loc=(x0 + sx * 0.04, 0.08, 0))
    out = {"Sleeve" + side: C.join(sleeve, P + "Sleeve"), "Cuff" + side: cuff, "Lace" + side: lace}
    cx, cy = x0 + sx * 0.04, 0.08
    if side == "L":
        hook = [C.lathe(P + "HookCup", [(0.001, -0.95), (0.22, -0.97), (0.2, -1.12), (0.08, -1.2)], segs=16, mat=M["Hook"], loc=(cx, cy, 0)),
                C.cyl(P + "HookShaft", 0.045, 0.35, loc=(cx, cy, -1.36), mat=M["Hook"], verts=10)]
        hp = []
        for i in range(12):
            a = i / 11 * math.pi * 1.25
            hp.append((cx, cy + 0.2 - 0.2 * math.cos(a), -1.53 - 0.2 * math.sin(a)))
        hook.append(C.tube(P + "HookCurve", hp, [0.045 - 0.03 * i / 11 for i in range(12)], segs=8, mat=M["Hook"]))
        out["Hook"] = C.join(hook, P + "Hook")
    else:
        hand = [C.sphere(P + "Palm", 0.28, loc=(cx, cy + 0.05, -1.18), scale=(1, 0.8, 1.1), mat=M["HandR"], segs=14, rings=8)]
        for k in range(4):
            a = (k - 1.5) * 0.35
            base = Vector((cx + math.sin(a) * 0.2, cy + 0.18, -1.3))
            mid = base + Vector((math.sin(a) * 0.1, 0.18, -0.25))
            tip = mid + Vector((0, 0.1, -0.22))
            hand.append(C.tube(P + "Finger%d" % k, [base, mid, tip], [0.07, 0.055, 0.015], segs=8, mat=M["HandR"]))
        thumb = Vector((cx - sx * 0.22, cy + 0.12, -1.12))
        hand.append(C.tube(P + "Thumb", [thumb, thumb + Vector((-sx * 0.12, 0.2, -0.1)), thumb + Vector((-sx * 0.1, 0.35, -0.22))], [0.07, 0.05, 0.015], segs=8, mat=M["HandR"]))
        out["HandR"] = C.join(hand, P + "Hand")
    return out


def tail(P, M):
    pts, rad = [], []
    for i in range(24):
        t = i / 23
        a = t * math.pi * 1.6
        pts.append((0.45 * t * math.sin(a), -0.15 - 0.35 * t * t, -1.15 - 2.3 * t + 0.25 * t ** 3))
        rad.append((1.0 * (1 - t) ** 1.2 + 0.03, 0.62 * (1 - t) ** 1.2 + 0.03))
    mist = C.tube(P + "Mist", pts, rad, segs=16, mat=M["Mist"], twist=2.5)
    rnd = random.Random(9)
    rags = []
    for k in range(9):
        a = -1.2 + k * 0.3
        x, y = 1.18 * math.sin(a), 0.66 * math.cos(a)
        L = rnd.uniform(0.6, 1.1)
        top = Vector((x, y, -1.2))
        rings = []
        for i in range(5):
            t = i / 4
            w = 0.26 * (1 - 0.5 * t)
            c = top + Vector((x * 0.1 * t, y * 0.12 * t, -L * t))
            tang = Vector((math.cos(a), -math.sin(a), 0))
            nrm = Vector((math.sin(a), math.cos(a), 0))
            rings.append([tuple(c + tang * w), tuple(c + nrm * 0.02), tuple(c - tang * w), tuple(c - nrm * 0.02)])
        rags.append(C.loft(P + "Rag%d" % k, rings, M["Rags"]))
    return {"Mist": mist, "Rags": C.join(rags, P + "Rags")}


# ------------------------------------------------------------------ theme accessories
def accessories(P, M):
    out = {}
    zc = 2.96
    chef = [C.cyl(P + "ChefBand", 0.8, 0.55, loc=(0, 0, 2.95), mat=M["ChefHat"], verts=32)]
    for k in range(7):
        a = k / 7 * 2 * math.pi
        chef.append(C.sphere(P + "Puff%d" % k, 0.5, loc=(0.45 * math.cos(a), 0.45 * math.sin(a), 3.5), mat=M["ChefHat"], segs=16, rings=8))
    chef.append(C.sphere(P + "PuffTop", 0.62, loc=(0, 0, 3.72), mat=M["ChefHat"], segs=18, rings=10))
    out["ChefHat"] = C.join(chef, P + "ChefHat")

    tb = []
    for k in range(6):
        x0 = (k - 2.5) * 0.15
        pts, rad = [], []
        for i in range(14):
            t = i / 13
            curl = t ** 2.5
            pts.append((x0 * (1 + t) + 0.25 * curl * math.sin(k), 0.6 + 0.3 * curl, 1.45 - 1.1 * t + 0.5 * curl))
            rad.append(0.1 * (1 - t) + 0.015)
        tb.append(C.tube(P + "Tent%d" % k, pts, rad, segs=8, mat=M["TentacleBeard"]))
    out["TentacleBeard"] = C.join(tb, P + "TentacleBeard")

    crown = [C.torus(P + "CrownRing", 0.58, 0.08, loc=(0, -0.02, zc + 0.62), mat=M["VoidCrown"], maj=32, mnr=6, scale=(1.05, 0.92, 1.4))]
    for k in range(7):
        a = k / 7 * 2 * math.pi
        base = (0.6 * math.sin(a), -0.02 + 0.55 * math.cos(a), zc + 0.66)
        crown.append(C.spike(P + "CrownSpike", base, (base[0] * 1.1, base[1] * 1.1, zc + 1.25 + 0.2 * (k % 2)), 0.1, mat=M["VoidCrown"], verts=5))
    out["VoidCrown"] = C.join(crown, P + "VoidCrown")

    flames = []
    rnd = random.Random(2)
    for k in range(9):
        a = k / 9 * 2 * math.pi
        base = Vector((0.62 * math.sin(a), 0.5 * math.cos(a), zc + 0.45))
        tip = base + Vector((0.15 * math.sin(a), 0.15 * math.cos(a), rnd.uniform(0.6, 1.1)))
        flames.append(C.spike(P + "Flame", base, tip, 0.18, mat=M["FlameCrown"], verts=7, bend=(0.12 * math.cos(a), -0.12 * math.sin(a), 0)))
    out["FlameCrown"] = C.join(flames, P + "FlameCrown")

    fin = []
    for sx in (-1, 1):
        for k in range(3):
            base = Vector((sx * 0.8, 0.1 - k * 0.18, 2.1 + k * 0.05))
            fin.append(C.spike(P + "Fin", base, base + Vector((sx * 0.55, -0.35, 0.45 - k * 0.15)), (0.14, 0.03)[0], mat=M["FinCrown"], verts=4))
    for k in range(5):
        a = (k - 2) * 0.35
        fin.append(C.sphere(P + "Shell", 0.12, loc=(0.7 * math.sin(a), 0.62 * math.cos(a), zc - 0.28), scale=(1, 0.5, 1.2), mat=M["FinCrown"], segs=10, rings=6))
    out["FinCrown"] = C.join(fin, P + "FinCrown")

    horns = []
    for sx in (-1, 1):
        horns.append(C.spike(P + "Horn", (sx * 0.62, -0.05, 2.5), (sx * 1.25, -0.75, 3.9), 0.17, mat=M["DragonHorns"], verts=8, bend=(sx * 0.2, 0.1, 0.25)))
        horns.append(C.spike(P + "HornB", (sx * 0.95, -0.4, 3.2), (sx * 1.45, -0.3, 3.55), 0.08, mat=M["DragonHorns"], verts=6))
    for k in range(6):
        a = (k - 2.5) * 0.35
        base = Vector((0.62 * math.sin(a), -0.62 * math.cos(a), 2.3))
        horns.append(C.spike(P + "Mane", base, base + Vector((math.sin(a) * 0.3, -0.65, -0.25)), 0.12, mat=M["DragonHorns"], verts=6))
    out["DragonHorns"] = C.join(horns, P + "DragonHorns")
    return out


def build(M, with_accessories=True):
    P = "SK_Pirate_"
    out = {}
    out.update(body(P, M))
    out.update(head(P, M))
    out.update(jaw(P, M))
    out.update(arm(P, M, "L"))
    out.update(arm(P, M, "R"))
    out.update(tail(P, M))
    if with_accessories:
        out.update(accessories(P, M))
    return out


# which accessory each Ghost skin wears, and which default pieces it hides
THEME = {
    "cook": {"add": ["ChefHat"], "hide": ["Hat", "HatTrim", "HatSkull", "Feather"]},
    "kraken": {"add": ["TentacleBeard"], "hide": ["Beard"]},
    "voidking": {"add": ["VoidCrown"], "hide": ["Feather"]},
    "ember": {"add": ["FlameCrown"], "hide": ["Feather"]},
    "siren": {"add": ["FinCrown"], "hide": []},
    "tide_dragon": {"add": ["DragonHorns"], "hide": ["Feather"]},
    "crimson_dragon": {"add": ["DragonHorns"], "hide": ["Feather"]},
    "moon_dragon": {"add": ["DragonHorns"], "hide": ["Feather"]},
}
ACCESSORIES = ["ChefHat", "TentacleBeard", "VoidCrown", "FlameCrown", "FinCrown", "DragonHorns"]
