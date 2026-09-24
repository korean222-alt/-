"""Small shared pieces: kraken arm capsule, falling petal, rune ring."""
import math
from mathutils import Vector
import common as C


def kraken_capsule(name, mat):
    """Tentacle segment along X. Bounding box 2 x 1 x 1 (1 long body + two 0.5 rounded caps).

    In game the size becomes (length + diameter, d, d) so neighbouring caps overlap and hide the joints.
    Fine wrinkles give the flesh a sculpted look instead of a smooth pipe.
    """
    prof = []
    n = 30
    for i in range(n + 1):
        t = i / n  # 0..1 along the length
        x = -1 + 2 * t
        if abs(x) > 0.5:
            k = (abs(x) - 0.5) / 0.5
            r = 0.5 * math.sqrt(max(0.0, 1 - k * k))
        else:
            r = 0.5
        wr = 1 - 0.018 * (0.5 + 0.5 * math.cos(t * math.pi * 6)) if abs(x) < 0.55 else 1
        prof.append((max(r * wr, 0.0005), x))
    o = C.lathe(name, prof, segs=18, mat=mat, cap_bottom=False, cap_top=False)
    # lathe builds around Z; lay it along X
    o.rotation_euler = (0, math.pi / 2, 0)
    C.activate([o])
    import bpy
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return o


def petal(name, mat):
    """Cherry petal about 0.3 studs, gently cupped, notch at the tip."""
    rings = []
    n = 10
    for i in range(n + 1):
        v = i / n
        w = 0.14 * math.sin(math.pi / 2 * min(1, v / 0.65)) if v < 0.65 else 0.14 * math.sqrt(max(0, 1 - ((v - 0.65) / 0.35) ** 2))
        w = max(w, 0.004)
        z = v * 0.32
        cup = 0.03
        notch = 0.035 if v > 0.9 else 0
        rings.append([(-w, cup, z), (-w * 0.5, cup * 0.2, z - notch * 0.2), (0, 0, z - notch), (w * 0.5, cup * 0.2, z - notch * 0.2), (w, cup, z),
                      (w * 0.5, cup * 0.2 + 0.006, z - notch * 0.2), (0, 0.006, z - notch), (-w * 0.5, cup * 0.2 + 0.006, z - notch * 0.2)])
    return C.loft(name, rings, mat)


def rune_ring(name, mat, R=1.0):
    """Flat glowing ring with rune notches - lies in the XY plane (Roblox: horizontal)."""
    parts = [C.torus(name + "Outer", R, 0.03, mat=mat, maj=64, mnr=5, scale=(1, 1, 0.5)),
             C.torus(name + "Inner", R * 0.82, 0.02, mat=mat, maj=64, mnr=5, scale=(1, 1, 0.5))]
    for k in range(16):
        a = k / 16 * 2 * math.pi
        c = Vector((math.cos(a), math.sin(a), 0)) * R * 0.91
        t = Vector((-math.sin(a), math.cos(a), 0))
        if k % 2 == 0:
            parts.append(C.tube(name + "Rune", [c - t * 0.06, c + t * 0.06], [0.018, 0.018], segs=4, mat=mat))
            parts.append(C.tube(name + "Rune", [c - t * 0.03 + Vector((math.cos(a), math.sin(a), 0)) * 0.05,
                                                 c + t * 0.04 - Vector((math.cos(a), math.sin(a), 0)) * 0.05], [0.016, 0.016], segs=4, mat=mat))
        else:
            parts.append(C.ico(name + "Dot", 0.03, loc=tuple(c), mat=mat, sub=1))
    return C.join(parts, name)
