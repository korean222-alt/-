"""Knife meshes, one set per KnifeModel shape.

Convention (same as KnifeModel.lua): guard centre at the origin, tip toward +Z (Roblox +Y),
blade width along X, thickness along Y. Scale 1 = about 3.2 studs from guard to tip.

Each shape returns {slot: object}. Slots are coloured in Roblox from the skin:
  Blade  skin.blade / bladeMaterial        Edge   blade lightened (Neon when the blade is Neon)
  Guard  skin.guard (metal)                Handle skin.handle / handleMaterial
  Wrap   handle darkened (fabric)          Pommel skin.guard (metal)
  Gem    skin.trail (Neon, rare and up)
"""
import math
from mathutils import Vector
import common as C


# ------------------------------------------------------------------ blade lofting
def _curve(kind, L, amount):
    """Returns f(s) -> (point(x, z), tangent(x, z)) for s in [0, 1] along the blade spine line."""
    if kind == "arc":  # constant curvature, bends toward -X (spine side) as it rises
        total = amount

        def f(s):
            if abs(total) < 1e-6:
                return Vector((0, s * L)), Vector((0, 1))
            r = L / total
            a = total * s
            return Vector((-(r - r * math.cos(a)), r * math.sin(a))), Vector((-math.sin(a), math.cos(a)))
        return f
    if kind == "wave":
        def f(s):
            x = amount * math.sin(s * math.pi * 5) * (1 - s * 0.6)
            dx = amount * math.pi * 5 * math.cos(s * math.pi * 5) * (1 - s * 0.6) / L
            t = Vector((dx, 1)).normalized()
            return Vector((x, s * L)), t
        return f

    def f(s):
        return Vector((0, s * L)), Vector((0, 1))
    return f


def blade(prefix, L, w0, t0, z0=0.1, curve=("straight", 0), single=False, taper=0.35, tip=0.28,
          bevel=0.3, edge_mat=None, mat=None, segs=40, fuller=0.0, belly=0.0):
    """Blade body + separate edge strip(s).

    single : one sharp edge on +X (spine on -X) - cutlass, fang, hook.
    tip    : fraction of the length used by the point.
    belly  : widening near the tip for single edged blades (fang / cleaver feel).
    """
    f = _curve(curve[0], L, curve[1])
    body_rings, edge_rings, edge2_rings = [], [], []
    for i in range(segs + 1):
        s = i / segs
        p, t = f(s)
        n = Vector((t.y, -t.x))  # right-hand normal in the XZ plane (edge side)
        w = w0 * (1 - taper * s) * (1 + belly * math.sin(math.pi * min(1, s / 0.85)))
        th = t0 * (1 - 0.55 * s)
        k = 0.0
        if s > 1 - tip:
            k = (s - (1 - tip)) / tip
            w *= max(0.02, math.sqrt(max(0.0, 1 - k ** 1.6)))
            th *= max(0.08, 1 - k * 0.85)
        shift = 0.0
        if single:
            # edge line stays straight, the spine sweeps down into the point
            shift = (w0 * (1 - taper * s) - w) * 0.5 if k > 0 else 0.0
        cx = p.x + n.x * shift
        cz = p.y + n.y * shift + z0
        bev = min(w * bevel, w * 0.45)

        def P(u, v):
            return (cx + n.x * u, v, cz + n.y * u)

        if single:
            prof = [P(-w / 2, th * 0.5), P(-w / 2, -th * 0.5), P(-w * 0.1, -th * 0.42),
                    P(w / 2 - bev, -th * 0.22), P(w / 2 - bev, th * 0.22), P(-w * 0.1, th * 0.42)]
            if fuller > 0:
                prof = [P(-w / 2, th * 0.5), P(-w / 2, -th * 0.5), P(-w * 0.3, -th * 0.5), P(-w * 0.2, -th * (0.5 - fuller)),
                        P(-w * 0.05, -th * 0.42), P(w / 2 - bev, -th * 0.22), P(w / 2 - bev, th * 0.22),
                        P(-w * 0.05, th * 0.42), P(-w * 0.2, th * (0.5 - fuller)), P(-w * 0.3, th * 0.5)]
            body_rings.append(prof)
            edge_rings.append([P(w / 2 - bev, th * 0.22), P(w / 2 - bev, -th * 0.22), P(w / 2, 0)])
        else:
            prof = [P(-w / 2 + bev, th * 0.2), P(-w / 2 + bev, -th * 0.2), P(-w * 0.12, -th * 0.5), P(w * 0.12, -th * 0.5),
                    P(w / 2 - bev, -th * 0.2), P(w / 2 - bev, th * 0.2), P(w * 0.12, th * 0.5), P(-w * 0.12, th * 0.5)]
            if fuller > 0 and s < 0.75:
                d = th * fuller
                prof = [P(-w / 2 + bev, th * 0.2), P(-w / 2 + bev, -th * 0.2), P(-w * 0.14, -th * 0.5), P(-w * 0.06, -th * 0.5 + d),
                        P(w * 0.06, -th * 0.5 + d), P(w * 0.14, -th * 0.5), P(w / 2 - bev, -th * 0.2), P(w / 2 - bev, th * 0.2),
                        P(w * 0.14, th * 0.5), P(w * 0.06, th * 0.5 - d), P(-w * 0.06, th * 0.5 - d), P(-w * 0.14, th * 0.5)]
            elif fuller > 0:
                prof = [P(-w / 2 + bev, th * 0.2), P(-w / 2 + bev, -th * 0.2), P(-w * 0.14, -th * 0.5), P(-w * 0.06, -th * 0.5),
                        P(w * 0.06, -th * 0.5), P(w * 0.14, -th * 0.5), P(w / 2 - bev, -th * 0.2), P(w / 2 - bev, th * 0.2),
                        P(w * 0.14, th * 0.5), P(w * 0.06, th * 0.5), P(-w * 0.06, th * 0.5), P(-w * 0.14, th * 0.5)]
            body_rings.append(prof)
            edge_rings.append([P(w / 2 - bev, th * 0.2), P(w / 2 - bev, -th * 0.2), P(w / 2, 0)])
            edge2_rings.append([P(-w / 2 + bev, -th * 0.2), P(-w / 2 + bev, th * 0.2), P(-w / 2, 0)])
    if fuller > 0 and not single:
        # fuller profile changes vertex count past 75% - loft in two parts
        split = int(segs * 0.75)
        a = C.loft(prefix + "BladeA", body_rings[:split + 1], mat)
        b = C.loft(prefix + "BladeB", body_rings[split + 1:], mat)
        bl = C.join([a, b], prefix + "Blade")
    else:
        bl = C.loft(prefix + "Blade", body_rings, mat)
    edges = [C.loft(prefix + "Edge", edge_rings, edge_mat)]
    if edge2_rings:
        edges.append(C.loft(prefix + "Edge2", edge2_rings, edge_mat))
    edge = C.join(edges, prefix + "Edge")
    C.smooth_by_angle(bl, 30)
    C.smooth_by_angle(edge, 30)
    return bl, edge, f


# ------------------------------------------------------------------ hilt parts
def grip(prefix, length, r, mat, wrap_mat, turns=6, bulge=0.12, z_top=-0.06):
    prof = []
    n = 14
    for i in range(n + 1):
        s = i / n
        rr = r * (1 + bulge * math.sin(math.pi * s))
        prof.append((rr, z_top - length * (1 - s)))
    handle = C.lathe(prefix + "Handle", list(reversed(prof)), segs=20, mat=mat)
    # spiral cord wrap
    pts, rad = [], []
    steps = turns * 16
    for i in range(steps + 1):
        s = i / steps
        a = 2 * math.pi * turns * s
        z = z_top - length * (0.06 + 0.88 * s)
        rr = r * (1 + bulge * math.sin(math.pi * (0.06 + 0.88 * s))) + r * 0.08
        pts.append((rr * math.cos(a), rr * math.sin(a), z))
        rad.append(r * 0.16)
    wrap = C.tube(prefix + "Wrap", pts, rad, segs=6, mat=wrap_mat)
    # two binding rings at the ends
    for zz in (z_top - length * 0.03, z_top - length * 0.97):
        wrap = C.join([wrap, C.torus(prefix + "WrapRing", r * 1.08, r * 0.12, loc=(0, 0, zz), mat=wrap_mat, maj=20, mnr=6)], prefix + "Wrap")
    return handle, wrap


def cross_guard(prefix, span, r, mat, curl=0.0, ball=True, lift=0.0):
    pts = []
    n = 16
    for i in range(n + 1):
        s = i / n * 2 - 1
        x = s * span / 2
        z = lift * abs(s) ** 2
        pts.append((x, 0, z))
    parts = [C.tube(prefix + "GuardBar", pts, [r * (1.1 - 0.3 * abs(i / n * 2 - 1)) for i in range(n + 1)], segs=10, mat=mat)]
    for sx in (-1, 1):
        if curl > 0:
            cp = []
            for i in range(10):
                a = i / 9 * math.pi * 1.4
                cp.append((sx * (span / 2 + math.sin(a) * curl), 0, lift + curl - math.cos(a) * curl))
            parts.append(C.tube(prefix + "Quillon", cp, [r * (0.8 - 0.4 * i / 9) for i in range(10)], segs=8, mat=mat))
        if ball:
            parts.append(C.sphere(prefix + "GuardBall", r * 1.35, loc=(sx * span / 2, 0, lift + (curl * 2 if curl else 0)), mat=mat, segs=14, rings=8))
    # central langet block with bevels
    parts.append(C.cube(prefix + "Langet", (r * 3.2, r * 2.4, r * 3.0), loc=(0, 0, 0.02), mat=mat, bevel=r * 0.5, bevel_segs=2))
    return C.join(parts, prefix + "Guard")


def pommel(prefix, r, z, mat, kind="ball"):
    if kind == "ball":
        o = C.sphere(prefix + "Pommel", r, loc=(0, 0, z), mat=mat, segs=18, rings=10)
        cap = C.cyl(prefix + "PommelNeck", r * 0.55, r * 0.6, loc=(0, 0, z + r * 0.8), mat=mat, verts=14)
        return C.join([o, cap], prefix + "Pommel")
    if kind == "cap":
        prof = [(0.001, z - r * 0.9), (r * 0.8, z - r * 0.75), (r, z - r * 0.2), (r * 0.75, z + r * 0.5), (r * 0.55, z + r * 0.7)]
        return C.lathe(prefix + "Pommel", prof, segs=18, mat=mat, cap_bottom=False)
    if kind == "facet":
        o = C.ico(prefix + "Pommel", r, loc=(0, 0, z), scale=(1, 1, 1.25), mat=mat, sub=1)
        return o
    return None


def gem(prefix, r, loc, mat, facing=(0, -1, 0)):
    o = C.ico(prefix + "Gem", r, loc=loc, scale=(1, 0.6, 1), mat=mat, sub=1)
    return o


# ------------------------------------------------------------------ shapes
def build(shape, mats):
    """mats: dict slot -> material (for thumbnails). Returns dict slot -> object (Gem optional)."""
    P = "SK_Knife_%s_" % shape
    M = mats
    out = {}
    if shape == "dagger":
        b, e, _ = blade(P, 2.25, 0.46, 0.12, z0=0.12, taper=0.28, tip=0.26, fuller=0.35, mat=M["Blade"], edge_mat=M["Edge"])
        out["Blade"], out["Edge"] = b, e
        out["Guard"] = cross_guard(P, 1.25, 0.075, M["Guard"], lift=0.08)
        out["Handle"], out["Wrap"] = grip(P, 1.25, 0.15, M["Handle"], M["Wrap"])
        out["Pommel"] = pommel(P, 0.2, -1.5, M["Pommel"], "ball")
        out["Gem"] = C.join([gem(P, 0.1, (0, -0.2, -1.5), M["Gem"]), gem(P + "g2", 0.09, (0, -0.13, 0.03), M["Gem"])], P + "Gem")
    elif shape == "bone":
        b, e, f = blade(P, 2.05, 0.54, 0.16, z0=0.12, taper=0.2, tip=0.25, bevel=0.22, mat=M["Blade"], edge_mat=M["Edge"])
        teeth = [b]
        for i in range(7):
            s = 0.12 + i * 0.11
            p, t = f(s)
            w = 0.54 * (1 - 0.2 * s)
            base = Vector((-w / 2 + 0.02, 0, p.y + 0.12))
            teeth.append(C.spike(P + "Tooth%d" % i, base, base + Vector((-0.2, 0, 0.1)), 0.07, mat=M["Blade"], verts=6))
        # knuckle bumps along the spine for a bone feel
        for i in range(3):
            teeth.append(C.sphere(P + "Knob%d" % i, 0.09, loc=(-0.25, 0, 0.25 + i * 0.55), scale=(0.8, 1, 1.2), mat=M["Blade"], segs=10, rings=6))
        out["Blade"] = C.join(teeth, P + "Blade")
        out["Edge"] = e
        # bone guard: two knobbly condyles
        g = [C.sphere(P + "Condyle%d" % sx, 0.2, loc=(sx * 0.32, 0, 0.0), scale=(1.2, 0.9, 0.8), mat=M["Guard"], segs=14, rings=8) for sx in (-1, 1)]
        g.append(C.cyl(P + "GuardCore", 0.14, 0.3, loc=(0, 0, 0), rot=(0, math.pi / 2, 0), mat=M["Guard"], verts=12))
        out["Guard"] = C.join(g, P + "Guard")
        prof = [(0.17, -0.05), (0.13, -0.3), (0.12, -0.6), (0.14, -0.85), (0.12, -1.05), (0.16, -1.2)]
        out["Handle"] = C.lathe(P + "Handle", prof, segs=16, mat=M["Handle"])
        out["Wrap"] = C.join([C.torus(P + "Band%d" % i, 0.15, 0.035, loc=(0, 0, -0.3 - i * 0.28), mat=M["Wrap"], maj=16, mnr=5) for i in range(3)], P + "Wrap")
        out["Pommel"] = C.join([C.sphere(P + "PomK%d" % sx, 0.15, loc=(sx * 0.1, 0, -1.3), mat=M["Pommel"], segs=12, rings=8) for sx in (-1, 1)], P + "Pommel")
        out["Gem"] = gem(P, 0.08, (0, -0.16, -1.3), M["Gem"])
    elif shape == "cutlass":
        b, e, f = blade(P, 3.0, 0.52, 0.12, z0=0.12, curve=("arc", math.radians(24)), single=True, taper=0.12, tip=0.2,
                        fuller=0.18, mat=M["Blade"], edge_mat=M["Edge"], belly=0.12)
        out["Blade"], out["Edge"] = b, e
        # shell guard + knuckle bow sweeping to the pommel on the edge side
        shell = C.sphere(P + "Shell", 0.42, loc=(0.05, 0, -0.02), scale=(1.1, 0.75, 0.28), mat=M["Guard"], segs=20, rings=10)
        bow_pts = []
        for i in range(13):
            s = i / 12
            a = math.pi * s
            bow_pts.append((0.5 + math.sin(a) * 0.28, 0, -0.02 - s * 1.45))
        bow = C.tube(P + "Bow", bow_pts, [0.06] * 13, segs=8, mat=M["Guard"])
        quill = C.spike(P + "Quillon", (-0.1, 0, 0), (-0.62, 0, 0.18), 0.07, mat=M["Guard"], bend=(0, 0, 0.12))
        out["Guard"] = C.join([shell, bow, quill, C.sphere(P + "QBall", 0.08, loc=(-0.62, 0, 0.2), mat=M["Guard"], segs=10, rings=6)], P + "Guard")
        out["Handle"], out["Wrap"] = grip(P, 1.3, 0.15, M["Handle"], M["Wrap"], turns=7)
        out["Pommel"] = pommel(P, 0.19, -1.5, M["Pommel"], "cap")
        out["Gem"] = gem(P, 0.1, (0.06, -0.12, -0.02), M["Gem"])
    elif shape == "kris":
        b, e, _ = blade(P, 2.4, 0.44, 0.11, z0=0.14, curve=("wave", 0.07), taper=0.4, tip=0.24, mat=M["Blade"], edge_mat=M["Edge"])
        out["Blade"], out["Edge"] = b, e
        # asymmetric ganja guard, one side sweeps up
        gp = [(-0.55, 0, 0.12), (-0.3, 0, 0.02), (0, 0, 0), (0.35, 0, 0.02), (0.55, 0, 0.1), (0.7, 0, 0.28)]
        out["Guard"] = C.join([C.tube(P + "Ganja", gp, [0.06, 0.09, 0.1, 0.09, 0.07, 0.03], segs=10, mat=M["Guard"]),
                               C.cube(P + "Langet", (0.26, 0.18, 0.2), loc=(0, 0, 0.02), mat=M["Guard"], bevel=0.04)], P + "Guard")
        # carved spiral handle (hilt bends slightly like a real keris)
        pts = [(0, 0, -0.06), (0.03, 0, -0.4), (0.1, 0, -0.8), (0.2, 0, -1.15)]
        out["Handle"] = C.tube(P + "Handle", pts, [0.15, 0.16, 0.15, 0.17], segs=14, mat=M["Handle"], twist=2.0)
        out["Wrap"] = C.join([C.torus(P + "Ring%d" % i, 0.16, 0.035, loc=(0.03 + i * 0.05, 0, -0.35 - i * 0.3), rot=(0, 0.1 * i, 0), mat=M["Wrap"], maj=16, mnr=5) for i in range(3)], P + "Wrap")
        out["Pommel"] = C.sphere(P + "Pommel", 0.2, loc=(0.24, 0, -1.3), scale=(1.1, 0.9, 0.8), mat=M["Pommel"], segs=16, rings=8)
        out["Gem"] = C.join([gem(P, 0.09, (0.24, -0.17, -1.3), M["Gem"]), gem(P + "b", 0.08, (0, -0.12, 0.04), M["Gem"])], P + "Gem")
    elif shape == "harpoon":
        shaft = C.cyl(P + "Shaft", 0.08, 2.3, loc=(0, 0, 1.2), mat=M["Blade"], verts=12)
        head = [shaft]
        hb, he, _ = blade(P + "H", 0.95, 0.46, 0.1, z0=2.3, taper=0.2, tip=0.62, bevel=0.35, mat=M["Blade"], edge_mat=M["Edge"], segs=24)
        head.append(hb)
        for sx in (-1, 1):
            head.append(C.spike(P + "Barb%d" % sx, (sx * 0.16, 0, 2.45), (sx * 0.42, 0, 2.1), 0.08, mat=M["Blade"], verts=6, bend=(sx * 0.05, 0, 0)))
        head.append(C.cyl(P + "Neck", 0.12, 0.25, loc=(0, 0, 2.25), mat=M["Blade"], verts=12))
        out["Blade"] = C.join(head, P + "Blade")
        out["Edge"] = he
        out["Guard"] = C.join([C.torus(P + "Collar", 0.13, 0.05, loc=(0, 0, 0.05), mat=M["Guard"], maj=18, mnr=6),
                               C.cyl(P + "Ferrule", 0.12, 0.25, loc=(0, 0, 0.0), mat=M["Guard"], verts=14)], P + "Guard")
        out["Handle"], out["Wrap"] = grip(P, 1.1, 0.14, M["Handle"], M["Wrap"], turns=5)
        # rope coil tied to the shaft
        rp = []
        for i in range(50):
            s = i / 49
            a = s * math.pi * 2 * 4
            rp.append((0.12 * math.cos(a), 0.12 * math.sin(a), 0.35 + s * 0.35))
        out["Wrap"] = C.join([out["Wrap"], C.tube(P + "Rope", rp, [0.035] * 50, segs=6, mat=M["Wrap"])], P + "Wrap")
        out["Pommel"] = pommel(P, 0.17, -1.28, M["Pommel"], "cap")
        out["Gem"] = gem(P, 0.08, (0, -0.1, 2.5), M["Gem"])
    elif shape == "hook":
        b, e, _ = blade(P, 2.4, 0.34, 0.12, z0=0.12, curve=("arc", math.radians(150)), single=True, taper=0.4, tip=0.16,
                        mat=M["Blade"], edge_mat=M["Edge"], segs=48)
        out["Blade"], out["Edge"] = b, e
        out["Guard"] = cross_guard(P, 0.8, 0.07, M["Guard"], ball=True)
        out["Handle"], out["Wrap"] = grip(P, 1.35, 0.15, M["Handle"], M["Wrap"], turns=6)
        out["Pommel"] = pommel(P, 0.18, -1.55, M["Pommel"], "ball")
        out["Gem"] = gem(P, 0.09, (0, -0.18, -1.55), M["Gem"])
    elif shape == "fang":
        b, e, f = blade(P, 2.7, 0.66, 0.16, z0=0.14, curve=("arc", math.radians(36)), single=True, taper=0.62, tip=0.3,
                        mat=M["Blade"], edge_mat=M["Edge"], belly=0.18, segs=44)
        # ridge of dragon scales along the spine
        ridge = [b]
        for i in range(9):
            s = 0.05 + i * 0.09
            p, t = f(s)
            n = Vector((t.y, -t.x))
            w = 0.66 * (1 - 0.62 * s) * (1 + 0.18 * math.sin(math.pi * min(1, s / 0.85)))
            base = Vector((p.x - n.x * w * 0.5, 0, p.y + 0.14 - n.y * w * 0.5))
            tip = base - Vector((n.x, 0, n.y)) * (0.16 - s * 0.1) + Vector((t.x, 0, t.y)) * 0.14
            ridge.append(C.spike(P + "Scale%d" % i, base, tip, 0.07 * (1 - s * 0.5), mat=M["Blade"], verts=5))
        out["Blade"] = C.join(ridge, P + "Blade")
        out["Edge"] = e
        # dragon-claw guard: three talons gripping the blade base on each side
        g = [C.sphere(P + "Palm", 0.3, loc=(0, 0, 0.02), scale=(1.5, 0.8, 0.6), mat=M["Guard"], segs=18, rings=10)]
        for sx in (-1, 1):
            for k in range(3):
                y = (k - 1) * 0.1
                base = Vector((sx * 0.35, y, 0.05))
                g.append(C.spike(P + "Talon%d%d" % (sx, k), base, base + Vector((sx * 0.25, y * 0.5, 0.45)), 0.07, mat=M["Guard"],
                                 verts=6, bend=(-sx * 0.12, 0, 0.05)))
        out["Guard"] = C.join(g, P + "Guard")
        out["Handle"], out["Wrap"] = grip(P, 1.3, 0.16, M["Handle"], M["Wrap"], turns=8, bulge=0.18)
        out["Pommel"] = C.join([C.sphere(P + "Pom", 0.22, loc=(0, 0, -1.52), mat=M["Pommel"], segs=16, rings=10)] +
                               [C.spike(P + "PomSpike%d" % k, (0, 0, -1.52), (0.3 * math.cos(k * 2.09), 0.3 * math.sin(k * 2.09), -1.75), 0.06,
                                        mat=M["Pommel"], verts=5) for k in range(3)], P + "Pommel")
        out["Gem"] = C.join([gem(P, 0.12, (0, -0.2, -1.52), M["Gem"]), gem(P + "b", 0.1, (0, -0.18, 0.05), M["Gem"])], P + "Gem")
    else:
        raise ValueError(shape)
    return out


SHAPES = ["dagger", "bone", "cutlass", "kris", "harpoon", "hook", "fang"]
