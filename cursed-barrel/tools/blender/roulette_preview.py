"""룰렛 판 미리보기 (Phase 16.1). RouletteWheel.lua 와 같은 모양 · 색 · 글자 자리로, 게임 안처럼
그림자 · 음영 없이 평면(2D)으로 그린다. (ViewportFrame 은 그림자를 그리지 않고, 판은 고른 빛만 쓴다)

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
FONT = '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc'
R = 10
HALF = R + 2.1  # RouletteWheel 판(Frame)의 절반 = 월드 12.1
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


def flat(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    # 게임 속 색(sRGB)을 그대로 보이게 선형 값으로 바꾼다
    lin = [((c / 255 + 0.055) / 1.055) ** 2.4 if c / 255 > 0.04045 else c / 255 / 12.92 for c in color]
    em.inputs['Color'].default_value = (*lin, 1)
    nt.links.new(em.outputs['Emission'], out.inputs['Surface'])
    return m


def mesh_obj(name, bm, color):
    bm.transform(M.R2B)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(flat(name, color))
    obj.visible_shadow = False
    return obj


def disk(name, radius, z0, z1, color):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=96, radius1=radius, radius2=radius, depth=z1 - z0, matrix=Matrix.Translation((0, 0, (z0 + z1) / 2)))
    return mesh_obj(name, bm, color)


def fan(name, a0, a1, r0, r1, z, color, steps=12):
    bm = bmesh.new()
    inner = [bm.verts.new(on_wheel(a0 + (a1 - a0) * k / steps, r0, z)) for k in range(steps + 1)]
    outer = [bm.verts.new(on_wheel(a0 + (a1 - a0) * k / steps, r1, z)) for k in range(steps + 1)]
    for k in range(steps):
        try:
            bm.faces.new((inner[k], outer[k], outer[k + 1], inner[k + 1]))
        except ValueError:
            pass
    return mesh_obj(name, bm, color)


def text(body, center, angle_deg, height, color, outline):
    objs = []
    for layer, (col, offset, z) in enumerate(((outline, 0.09, 1.6), (color, 0.0, 1.7))):
        curve = bpy.data.curves.new(f'T{body}{layer}', 'FONT')
        curve.body = body
        curve.font = bpy.data.fonts.load(FONT, check_existing=True)
        curve.size = height
        curve.align_x = 'CENTER'
        curve.align_y = 'CENTER'
        curve.offset = offset
        obj = bpy.data.objects.new(curve.name, curve)
        bpy.context.scene.collection.objects.link(obj)
        curve.materials.append(flat(curve.name, col))
        place = Matrix.Translation(Vector((center.x, center.y, z))) @ Matrix.Rotation(-math.radians(angle_deg), 4, 'Z')
        # 글자는 제 XY 평면(앞 +Z)에 생긴다 = Roblox 판의 XY 평면(앞 +Z). 그대로 Roblox 자리에 놓고 Blender 좌표로 바꾼다
        obj.matrix_world = M.R2B @ place
        obj.visible_shadow = False
        objs.append(obj)
    return objs


def main():
    M.reset()
    cam = M.scene_setup(720)
    scene = bpy.context.scene
    scene.render.film_transparent = False
    scene.render.use_freestyle = False
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.13, 0.12, 0.2, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
    disk('Back', R + 1.9, -1.2, -0.4, BACK)
    disk('GoldRim', R + 1.15, -0.95, -0.05, GOLD)
    disk('RimShadow', R + 0.25, -0.9, 0.0, GOLD_DARK)
    step = 360 / len(SEGMENTS)
    for i, (kind, amount, label) in enumerate(SEGMENTS):
        color = PALETTE[i % len(PALETTE)]
        a0, a1 = i * step - step / 2, i * step + step / 2
        fan(f'S{i}', a0, a1, 0.0, R, 0.15, color)
        fan(f'B{i}', a0, a1, R * 0.28, R * 0.52, 0.2, tuple(c + (255 - c) * 0.18 for c in color))
        mid = on_wheel(a0, R / 2, 0.35)
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1, matrix=Matrix.Translation(mid) @ Matrix.Rotation(-math.radians(a0), 4, 'Z') @ Matrix.Diagonal((0.26, R, 0.3, 1)))
        mesh_obj(f'D{i}', bm, GOLD)
        # 금액 글자 (반지름 방향) : 판 크기의 0.325 · 높이 0.078
        pos = on_wheel(i * step, 0.325 * 2 * HALF)
        turned = (i * step) % 360
        text(label, pos, i * step + (180 if 90 < turned < 270 else 0), 0.078 * 2 * HALF * 0.8, (255, 255, 255), (30, 16, 12))
        # 칸 그림 (똑바로 선 작은 돈 그림, 따로 빛을 받는다) : 판 크기의 0.19 · 크기 0.12
        icon = [f for f in M.ICONS if f.name == icon_for(kind, amount)][0]
        objs = M.build(icon, False)
        lo, hi = M.bounds(objs)
        center_b = (lo + hi) / 2
        size = (hi - lo).length
        scale = 0.12 * 2 * HALF / size * 1.35
        view_b = (M.R2B @ M.VIEW.to_4d()).to_3d()
        turn = view_b.rotation_difference((M.R2B @ Vector((0, 0, 1, 0))).to_3d()).to_matrix().to_4x4()
        spot = M.R2B @ on_wheel(i * step, 0.19 * 2 * HALF, 2.5).to_4d()
        for o in objs:
            o.matrix_world = Matrix.Translation(spot.to_3d()) @ turn @ Matrix.Diagonal((scale, scale, scale, 1)) @ Matrix.Translation(-center_b) @ o.matrix_world
            o.visible_shadow = False
    for i in range(16):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=0.35, matrix=Matrix.Translation(on_wheel((i + 0.5) * 22.5, R + 1.2, 0.35)))
        mesh_obj(f'L{i}', bm, (255, 244, 170) if i % 2 else (255, 120, 60))
    disk('Hub', 2.1, -0.1, 0.8, GOLD)
    disk('HubIn', 1.5, 0.0, 0.95, (220, 44, 44))
    disk('HubCap', 0.65, 0.0, 1.1, GOLD)
    # 바늘 (위 · 고정) : RouletteWheel 의 Pointer 뷰포트와 같은 자리 · 크기
    s = 0.2 * 2 * HALF / (2 * 11 * math.tan(math.radians(15)))
    top = HALF + 0.06 * 2 * HALF
    cy = top - 0.1 * 2 * HALF
    def pin_tri(name, pts, color, z):
        bm = bmesh.new()
        vs = [bm.verts.new(Vector((x * s, cy + (y + 0.1) * s, z))) for x, y in pts]
        bm.faces.new(vs)
        mesh_obj(name, bm, color)
    pin_tri('PinGold', [(-1.25, 1.1), (1.25, 1.1), (0, -1.6)], GOLD, 3.0)
    pin_tri('PinRed', [(-0.95, 0.92), (0.95, 0.92), (0, -1.2)], (230, 40, 40), 3.1)
    distance = (HALF + 1.8) / math.tan(math.radians(14))
    cam.location = M.R2B @ Vector((0, 0.9, distance))
    cam.rotation_euler = (M.R2B @ Vector((0, 0, -1))).to_track_quat('-Z', 'Y').to_euler()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    scene.render.filepath = str(OUT)
    bpy.ops.render.render(write_still=True)


main()
