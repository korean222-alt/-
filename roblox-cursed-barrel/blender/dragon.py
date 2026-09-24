"""Eastern (serpentine) dragon coiled on a helix - used by the mythic skins.

build_dragon() returns (body_objects, glow_objects). The helix axis is the world Z axis
through `center`, so in Roblox the dragon can simply be rotated around that axis to orbit.
"""
import math
from mathutils import Vector, Matrix
import common as C


def _thickness(t, thick):
    if t < 0.55:
        return thick * (0.10 + 0.90 * (t / 0.55) ** 0.6)
    if t < 0.86:
        return thick
    return thick * (1 - 0.22 * (t - 0.86) / 0.14)


def _path(center, R, z0, z1, turns, n, phase):
    cx, cy, cz = center
    pts = []
    for i in range(n + 1):
        t = i / n
        ang = phase + 2 * math.pi * turns * t
        r = R * (1 + 0.07 * math.sin(t * math.pi * 7))
        z = z0 + (z1 - z0) * t + 0.04 * (z1 - z0) * math.sin(t * math.pi * 9)
        if t > 0.86:  # rear the neck up and out
            k = (t - 0.86) / 0.14
            r += R * 0.45 * k * k
            z += (z1 - z0) * 0.12 * k
        pts.append(Vector((cx + r * math.cos(ang), cy + r * math.sin(ang), cz + z)))
    return pts


def _xform(objs, M):
    for o in objs:
        o.data.transform(M @ o.matrix_world)
        o.matrix_world = Matrix.Identity(4)


def _head(prefix, mats, glow_mat, h):
    """Canonical head: x right, y forward (snout), z up, size h = head length."""
    sc, mane, horn, whisk, dark = mats
    P = []

    def v(x, y, z):
        return (x * h, y * h, z * h)

    P.append(C.sphere(prefix + "skull", 0.5 * h, v(0, 0.02, 0.08), scale=(0.72, 0.9, 0.62), mat=sc))
    P.append(C.cyl(prefix + "snout", 0.2 * h, 0.6 * h, v(0, 0.48, 0.03), rot=(math.radians(90), 0, 0), r2=0.15 * h, mat=sc, verts=16))
    P[-1].scale = (1.2, 1, 0.8)
    P.append(C.sphere(prefix + "nose", 0.14 * h, v(0, 0.8, 0.07), scale=(1.25, 0.85, 0.8), mat=sc))
    jaw = C.cyl(prefix + "jaw", 0.16 * h, 0.55 * h, v(0, 0.42, -0.2), rot=(math.radians(90 - 14), 0, 0), r2=0.09 * h, mat=sc, verts=14)
    jaw.scale = (1.1, 1, 0.55)
    P.append(jaw)
    # teeth
    for sx in (-1, 1):
        for k in range(4):
            y = 0.4 + k * 0.12
            P.append(C.spike(prefix + f"tooth{sx}{k}", v(sx * 0.15, y, -0.08), v(sx * 0.15, y + 0.02, -0.2), 0.03 * h, mat=horn, verts=6))
    # brows / horns / whiskers / mane
    for sx in (-1, 1):
        P.append(C.spike(prefix + f"brow{sx}", v(sx * 0.2, 0.22, 0.3), v(sx * 0.32, -0.12, 0.46), 0.07 * h, mat=mane, verts=6))
        P.append(C.spike(prefix + f"horn{sx}", v(sx * 0.16, -0.12, 0.3), v(sx * 0.38, -1.0, 0.78), 0.085 * h, mat=horn,
                         bend=(sx * 0.05 * h, 0, 0.18 * h)))
        P.append(C.spike(prefix + f"hornb{sx}", v(sx * 0.26, -0.5, 0.52), v(sx * 0.55, -0.62, 0.95), 0.045 * h, mat=horn, verts=6))
        wpts = [v(sx * 0.2, 0.74, -0.02), v(sx * 0.5, 0.66, -0.08), v(sx * 0.82, 0.36, -0.18), v(sx * 1.02, -0.1, -0.12),
                v(sx * 1.12, -0.55, 0.04), v(sx * 1.1, -0.9, 0.18)]
        P.append(C.tube(prefix + f"whisker{sx}", wpts, [0.028 * h * (1 - i / 6) + 0.006 * h for i in range(6)], segs=6, mat=whisk))
        # ear fins
        P.append(C.spike(prefix + f"ear{sx}", v(sx * 0.3, -0.05, 0.12), v(sx * 0.62, -0.38, 0.2), 0.08 * h, mat=mane, verts=6))
    # mane: flame-like spikes around the back of the skull
    for k in range(11):
        a = math.radians(-120 + 240 * k / 10)
        base = Vector((math.sin(a) * 0.3, -0.2, 0.1 + math.cos(a) * 0.26))
        tip = base + Vector((math.sin(a) * 0.4, -0.62, math.cos(a) * 0.36))
        P.append(C.spike(prefix + f"mane{k}", tuple(base * h), tuple(tip * h), 0.1 * h, mat=mane, verts=7,
                         bend=(0, 0, 0.12 * h)))
    # beard
    for k, x in enumerate((-0.08, 0, 0.08)):
        P.append(C.spike(prefix + f"beard{k}", v(x, 0.45, -0.3), v(x * 1.6, 0.2, -0.72), 0.05 * h, mat=mane, verts=6))
    glows = []
    for sx in (-1, 1):
        glows.append(C.sphere(prefix + f"eye{sx}", 0.075 * h, v(sx * 0.24, 0.26, 0.2), scale=(0.8, 1, 0.75), mat=glow_mat, segs=12, rings=8))
    return P, glows


def build_dragon(prefix, center, R, z0, z1, turns, thick, head_len, colors, phase=0.0, n=110, legs=True, slots=False):
    body_c, edge_c, mane_c, horn_c, whisk_c, eye_c = [C.hexc(x) for x in colors]
    sc = C.mat_scales(prefix + "Scales", body_c, edge_c, scale=22 / max(0.3, thick * 6))
    mane = C.mat_noisy(prefix + "Mane", mane_c, var=0.3, scale=10, rough=0.45)
    horn = C.mat_noisy(prefix + "Horn", horn_c, var=0.15, scale=14, rough=0.35)
    whisk = C.mat_metal(prefix + "Whisk", whisk_c, rough=0.25)
    dark = C.mat_flat(prefix + "Dark", C.hexc("#1a0d0d"))
    eye = C.mat_glow(prefix + "Eye", eye_c, 8.0)

    pts = _path(center, R, z0, z1, turns, n, phase)
    radii = [_thickness(i / n, thick) for i in range(n + 1)]
    frames = C._frames(pts)
    body = [C.tube(prefix + "Body", pts, [(r * 1.08, r * 0.92) for r in radii], segs=10, mat=sc, cap=True)]
    cvec = Vector(center)

    def radial(p):
        d = Vector((p.x - cvec.x, p.y - cvec.y, 0))
        return d.normalized() if d.length > 1e-6 else Vector((1, 0, 0))

    # dorsal spines along the outer-top edge
    for i in range(6, n - 8, 4):
        p, r, (t, nn, b) = pts[i], radii[i], frames[i]
        out = (radial(p) * 0.45 + Vector((0, 0, 1)) * 0.9).normalized()
        base = p + out * r * 0.7
        tip = base + out * r * 1.5 - t * r * 0.9
        body.append(C.spike(prefix + f"Spine{i}", base, tip, r * 0.42, mat=mane, verts=6))
    # tail tuft
    p0, t0 = pts[0], frames[0][0]
    for k in range(6):
        a = 2 * math.pi * k / 6
        off = frames[0][1] * math.cos(a) + frames[0][2] * math.sin(a)
        body.append(C.spike(prefix + f"Tuft{k}", p0 + off * 0.01, p0 - t0 * thick * 3.2 + off * thick * 1.3, thick * 0.35,
                            mat=mane, verts=6))
    # legs with claws
    if legs:
        for li, tt in enumerate((0.34, 0.42, 0.7, 0.78)):
            i = int(tt * n)
            p, r, (t, nn, b) = pts[i], radii[i], frames[i]
            down = (radial(p) * 0.55 - Vector((0, 0, 1)) * 0.8 + t * (0.25 if li % 2 else -0.1)).normalized()
            knee = p + down * r * 1.7 + t * r * 0.6
            foot = knee + (down + t * 0.6).normalized() * r * 1.3
            body.append(C.tube(prefix + f"Leg{li}", [p, knee, foot], [r * 0.45, r * 0.33, r * 0.28], segs=8, mat=sc))
            side = t.cross(down).normalized()
            for c_ in (-1, 0, 1):
                tipp = foot + (t * 0.8 + side * c_ * 0.5 + down * 0.3).normalized() * r * 0.9
                body.append(C.spike(prefix + f"Claw{li}{c_}", foot, tipp, r * 0.13, mat=horn, verts=5,
                                    bend=tuple(down * r * 0.25)))
    # head at the end of the path, looking along the final tangent (slightly outward)
    pe, (te, ne, be) = pts[-1], frames[-1]
    fwd = (te + radial(pe) * 0.35).normalized()
    up = Vector((0, 0, 1))
    right = fwd.cross(up).normalized()
    up = right.cross(fwd).normalized()
    M = Matrix((
        (right.x, fwd.x, up.x, pe.x),
        (right.y, fwd.y, up.y, pe.y),
        (right.z, fwd.z, up.z, pe.z),
        (0, 0, 0, 1),
    ))
    head_parts, glows = _head(prefix + "H_", (sc, mane, horn, whisk, dark), eye, head_len)
    C.apply_mods(head_parts + glows)
    _xform(head_parts + glows, M @ Matrix.Translation((0, head_len * 0.25, 0)))
    body += head_parts
    if not slots:
        return body, glows
    by = {"Scales": [], "Mane": [], "Horn": [], "Eyes": list(glows)}
    for o in body:
        m = o.data.materials[0].name if o.data.materials else ""
        if m.endswith("Scales"):
            by["Scales"].append(o)
        elif m.endswith("Mane"):
            by["Mane"].append(o)
        elif m.endswith("Dark"):
            by["Scales"].append(o)
        else:
            by["Horn"].append(o)
    return {k: C.join(v, prefix + k) for k, v in by.items() if v}
