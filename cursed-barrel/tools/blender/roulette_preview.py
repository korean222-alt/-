"""룰렛 판 미리보기 (Phase 16). RouletteWheel.lua 와 같은 모양 · 색으로 그려서 확인용 그림을 만든다.

    python3 tools/blender/roulette_preview.py   →  assets/ui/previews/roulette.png
"""
from pathlib import Path
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import money_icons as M  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/ui/previews/roulette.png'
R = 10
PALETTE = [(236, 62, 62), (255, 190, 40), (60, 146, 255), (70, 200, 90), (168, 86, 255), (255, 136, 36), (36, 196, 196), (255, 96, 170)]
SEGMENTS = [('coins', 60, '60'), ('coins', 150, '150'), ('skin', 0, '스킨'), ('coins', 300, '300'), ('coins', 900, '900'), ('skin', 0, '희귀'), ('coins', 3000, '3000'), ('coins', 6000, '6000')]
GOLD, GOLD_DARK, BACK = (255, 200, 60), (196, 124, 24), (70, 26, 22)


def on_wheel(deg, r, z=0.0):
    a = math.radians(deg)
    return Vector((math.sin(a) * r, math.cos(a) * r, z))


def icon_for(kind, amount):
    if kind == 'skin':
        return 'gift'
    return 'chest' if amount >= 5000 else 'cash3' if amount >= 2000 else 'cash2' if amount >= 500 else 'cash' if amount >= 120 else 'coins'


def mesh_obj(name, bm, color, emit=False):
    bm.transform(M.R2B)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(M.material(name, color, 'Neon' if emit else 'SmoothPlastic', 0, True))
    for p in mesh.polygons:
        p.use_smooth = True
    return obj


def disk(name, radius, z0, z1, color):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=96, radius1=radius, radius2=radius, depth=z1 - z0, matrix=Matrix.Translation((0, 0, (z0 + z1) / 2)))
    return mesh_obj(name, bm, color)


def fan(name, a0, a1, r0, r1, z0, z1, color, steps=12):
    bm = bmesh.new()
    verts = []
    for k in range(steps + 1):
        a = a0 + (a1 - a0) * k / steps
        verts.append((on_wheel(a, r0), on_wheel(a, r1)))
    ring = []
    for z in (z0, z1):
        row = []
        for inner, outer in verts:
            row.append((bm.verts.new(inner + Vector((0, 0, z))), bm.verts.new(outer + Vector((0, 0, z)))))
        ring.append(row)
    for k in range(steps):
        for zi in range(2):
            (i0, o0), (i1, o1) = ring[zi][k], ring[zi][k + 1]
            bm.faces.new((i0, o0, o1, i1) if zi else (i1, o1, o0, i0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_obj(name, bm, color)


def main():
    M.reset()
    cam = M.scene_setup(720)
    bpy.context.scene.render.film_transparent = False
    bpy.context.scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.1, 0.1, 0.16, 1)
    disk('Back', R + 1.9, -1.2, -0.4, BACK)
    disk('GoldRim', R + 1.15, -0.95, -0.05, GOLD)
    disk('RimShadow', R + 0.25, -0.9, 0.0, GOLD_DARK)
    step = 360 / len(SEGMENTS)
    for i, (kind, amount, _) in enumerate(SEGMENTS):
        color = PALETTE[i % len(PALETTE)]
        a0, a1 = i * step - step / 2, i * step + step / 2
        fan(f'S{i}', a0, a1, 0, R, -0.15, 0.15, color)
        fan(f'B{i}', a0, a1, R * 0.28, R * 0.52, 0.0, 0.2, tuple(c + (255 - c) * 0.18 for c in color))
        mid = on_wheel(a0, R / 2, 0.35)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Translation(mid) @ Matrix.Rotation(-math.radians(a0), 4, 'Z') @ Matrix.Diagonal((0.26, R, 0.3, 1)))
        mesh_obj(f'D{i}', bm, GOLD)
        icon = [f for f in M.ICONS if f.name == icon_for(kind, amount)][0]
        objs = M.build(icon, True)
        lo, hi = M.bounds(objs)
        size = max(hi - lo)
        scale = 3.1 / size
        center_b = (lo + hi) / 2
        place = M.R2B @ (Matrix.Translation(on_wheel(i * step, R * 0.74, 1.2)) @ Matrix.Rotation(-math.radians(i * step), 4, 'Z') @ Matrix.Rotation(math.radians(37), 4, 'X')) @ M.R2B.inverted()
        for o in objs:
            o.matrix_world = place @ Matrix.Diagonal((scale, scale, scale, 1)) @ Matrix.Translation(-center_b) @ o.matrix_world
    for i in range(16):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.35, matrix=Matrix.Translation(on_wheel((i + 0.5) * 22.5, R + 1.2, 0.35)))
        mesh_obj(f'L{i}', bm, (255, 244, 170) if i % 2 else (255, 120, 60), emit=True)
    disk('Hub', 2.1, -0.1, 0.8, GOLD)
    disk('HubIn', 1.5, 0.0, 0.95, (220, 44, 44))
    disk('HubCap', 0.65, 0.0, 1.1, GOLD)
    distance = (R + 2.1) / math.tan(math.radians(15))
    cam.location = M.R2B @ Vector((0, 0, distance))
    cam.rotation_euler = (M.R2B @ Vector((0, 0, -1))).to_track_quat('-Z', 'Y').to_euler()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.render.filepath = str(OUT)
    bpy.ops.render.render(write_still=True)


main()
