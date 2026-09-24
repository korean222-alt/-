"""돈 모양 그림 (Blender 5 · bpy)  — Phase 16

    python3 tools/blender/money_icons.py

모양은 여기 한 곳에서만 정한다 (Roblox 좌표 · 파트 조각 단위). 이 파일이 두 가지를 만든다.
  game/.../Shared/MoneyIconData.lua     조각 목록. 게임은 그림 ID 가 없을 때 이 조각으로 작은 3D 모형을 띄운다
  assets/ui/money/<종류>.png             만화풍 그림 (둥근 모서리 · 검은 외곽선 · 투명 배경 512px). 올려서 쓰면 더 예쁘다
  assets/ui/money/parts/<종류>.png       게임 안 3D 모형이 어떻게 보이는지 (확인용)
"""
from pathlib import Path
import math
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/ui/money'
DATA = ROOT / 'game/ReplicatedStorage/CursedBarrel/Shared/MoneyIconData.lua'
R2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

# --------------------------------------------------
# Roblox CFrame 흉내 (4x4 행렬)
# --------------------------------------------------


def T(x=0, y=0, z=0):
    return Matrix.Translation(Vector((x, y, z)))


def A(x=0, y=0, z=0):
    """CFrame.Angles(x, y, z) = Rx * Ry * Rz (라디안)"""
    return Matrix.Rotation(x, 4, 'X') @ Matrix.Rotation(y, 4, 'Y') @ Matrix.Rotation(z, 4, 'Z')


def D(deg):
    return math.radians(deg)


FLAT = A(0, 0, math.pi / 2)  # 원통(축 X)을 세워서 둥근 면이 위를 보게

C = {
    'bill': (52, 176, 74), 'billDark': (24, 112, 48), 'billLight': (126, 220, 128),
    'band': (255, 206, 52), 'bandDark': (226, 150, 24),
    'gold': (255, 200, 48), 'goldDark': (214, 138, 20),
    'wood': (150, 88, 44), 'woodDark': (98, 54, 28),
    'steel': (160, 170, 186), 'steelDark': (84, 92, 108), 'black': (30, 34, 42),
    'gem': (80, 200, 255), 'gemDark': (30, 120, 230),
    'red': (236, 60, 60), 'purple': (170, 90, 255), 'lilac': (200, 130, 255),
    'white': (255, 250, 235), 'orange': (255, 120, 60), 'glass': (220, 240, 255),
}


class Icon:
    def __init__(self, name):
        self.name = name
        self.prims = []

    def add(self, kind, size, cf, color, mat='SmoothPlastic', transparency=0.0, reflect=0.0):
        self.prims.append(dict(kind=kind, size=tuple(size), cf=cf.copy(), color=C.get(color, color) if isinstance(color, str) else color,
                               mat=mat, tr=transparency, rf=reflect))

    def block(self, size, cf, color, **kw):
        self.add('Block', size, cf, color, **kw)

    def cyl(self, length, diameter, cf, color, **kw):
        self.add('Cylinder', (length, diameter, diameter), cf, color, **kw)

    def ball(self, d, cf, color, **kw):
        self.add('Ball', (d, d, d), cf, color, **kw)


# --------------------------------------------------
# 모양
# --------------------------------------------------


def bundle(icon, cf):
    """지폐 묶음 하나. 길이 2.4 · 너비 1.2 · 두께 0.5 (cf = 한가운데)"""
    for i in range(5):
        icon.block((2.4, 0.1, 1.2), cf @ T(0, -0.2 + i * 0.1, 0), 'bill' if i % 2 == 0 else 'billLight')
    icon.block((2.16, 0.02, 0.96), cf @ T(0, 0.255, 0), 'billDark')
    icon.block((2.0, 0.024, 0.8), cf @ T(0, 0.262, 0), 'bill')
    icon.cyl(0.03, 0.56, cf @ T(0, 0.275, 0) @ FLAT, 'billDark')
    icon.cyl(0.034, 0.36, cf @ T(0, 0.28, 0) @ FLAT, 'billLight')
    icon.block((0.46, 0.56, 1.26), cf, 'band')
    icon.block((0.48, 0.04, 1.28), cf @ T(0, 0.28, 0), 'bandDark')


def coin(icon, cf, s=1.0):
    icon.cyl(0.18 * s, 1.0 * s, cf @ FLAT, 'gold', mat='Metal', reflect=0.1)
    icon.cyl(0.2 * s, 0.74 * s, cf @ FLAT, 'goldDark', mat='Metal')
    icon.cyl(0.22 * s, 0.42 * s, cf @ FLAT, 'gold', mat='Metal')


def make_cash():
    i = Icon('cash')
    bundle(i, A(0, D(-20), 0))
    return i


def make_cash2():
    i = Icon('cash2')
    bundle(i, T(0, -0.28, 0.1) @ A(0, D(-12), 0))
    bundle(i, T(0.15, 0.28, -0.1) @ A(0, D(-40), 0))
    return i


def make_cash3():
    i = Icon('cash3')
    bundle(i, T(-0.7, -0.28, 0.3) @ A(0, D(-8), 0))
    bundle(i, T(0.8, -0.28, -0.1) @ A(0, D(-30), 0))
    bundle(i, T(0.05, 0.28, 0.1) @ A(0, D(-18), 0))
    bundle(i, T(0.2, 0.84, -0.05) @ A(0, D(-40), 0))
    coin(i, T(-1.55, -0.3, 1.0) @ A(D(15), 0, D(10)), 0.8)
    coin(i, T(1.75, -0.35, 0.9) @ A(D(-10), 0, D(-15)), 0.7)
    return i


def make_coins():
    i = Icon('coins')
    spots = [(0, -0.45, 0, 5), (0.95, -0.45, 0.2, -8), (-0.9, -0.45, 0.25, 12), (0.1, -0.45, 0.95, -4),
             (0.45, -0.27, 0.3, 10), (-0.35, -0.27, 0.45, -12), (0.05, -0.09, 0.2, 6)]
    for x, y, z, tilt in spots:
        coin(i, T(x, y, z) @ A(D(tilt), 0, D(tilt * 0.6)), 1.0)
    coin(i, T(0.2, 0.45, 0.3) @ A(D(62), D(-15), 0), 1.1)
    return i


def make_chest():
    i = Icon('chest')
    i.block((3.0, 1.5, 1.9), T(0, -0.6, 0), 'wood', mat='Wood')
    for x in (-1.35, 1.35):
        i.block((0.24, 1.56, 1.96), T(x, -0.6, 0), 'gold', mat='Metal')
    i.block((3.08, 0.2, 1.98), T(0, 0.12, 0), 'gold', mat='Metal')
    i.block((0.5, 0.6, 0.1), T(0, -0.35, 0.99), 'goldDark', mat='Metal')
    lid = T(0, 0.22, -0.95) @ A(D(-72), 0, 0) @ T(0, 0, 0.95)
    i.block((3.0, 0.34, 1.9), lid @ T(0, 0.17, 0), 'woodDark', mat='Wood')
    i.block((3.08, 0.38, 0.24), lid @ T(0, 0.17, 0.85), 'gold', mat='Metal')
    bundle(i, T(-0.55, 0.36, 0.1) @ A(0, D(-15), D(8)))
    bundle(i, T(0.62, 0.46, -0.05) @ A(0, D(-35), D(-10)))
    coin(i, T(0.1, 0.78, 0.62) @ A(D(55), 0, 0), 0.75)
    coin(i, T(-1.0, 0.66, 0.62) @ A(D(65), D(30), 0), 0.62)
    coin(i, T(1.1, 0.3, 0.75) @ A(D(70), D(-20), 0), 0.6)
    return i


def make_vault():
    i = Icon('vault')
    i.block((2.8, 2.6, 2.0), T(0, 0, -0.2), 'steelDark', mat='Metal')
    i.block((2.4, 2.2, 0.1), T(0, 0, 0.8), 'black')
    # 문이 열린 금고 앞으로 지폐가 쏟아져 나온다
    for y, z, turn in ((-0.72, 1.05, -4), (-0.16, 0.98, 6), (0.4, 1.02, -8)):
        bundle(i, T(0, y, z) @ A(0, D(turn), 0))
    door = T(1.2, 0, 0.8) @ A(0, D(-110), 0) @ T(-1.2, 0, 0)
    i.block((2.4, 2.3, 0.3), door, 'steel', mat='Metal')
    i.cyl(0.14, 0.9, door @ T(0, 0, 0.2) @ A(0, math.pi / 2, 0), 'gold', mat='Metal')
    for k in range(3):
        i.block((1.3, 0.14, 0.14), door @ T(0, 0, 0.3) @ A(0, 0, D(k * 60)), 'goldDark', mat='Metal')
    for y in (-0.8, 0.8):
        i.block((0.3, 0.35, 0.3), T(1.35, y, 0.8), 'steelDark', mat='Metal')
    return i


def make_gem():
    i = Icon('gem')
    # 모서리로 선 정육면체 = 다이아몬드
    i.block((1.6, 1.6, 1.6), A(D(35.26), 0, D(45)), 'gem', mat='Glass', transparency=0.05, reflect=0.1)
    i.block((1.3, 1.3, 1.3), A(D(35.26), 0, D(45)), 'gemDark', mat='Glass')
    return i


def make_gift():
    i = Icon('gift')
    i.block((2.2, 1.8, 2.2), T(0, -0.3, 0), 'purple')
    i.block((2.44, 0.42, 2.44), T(0, 0.7, 0), 'lilac')
    i.block((0.46, 2.34, 2.48), T(0, -0.09, 0), 'band')
    i.block((2.48, 2.34, 0.46), T(0, -0.09, 0), 'band')
    # 리본 고리 둘 (납작한 원판을 비스듬히) + 가운데 매듭
    for side in (-1, 1):
        i.cyl(0.26, 0.95, T(side * 0.42, 1.28, 0) @ A(0, D(side * 20), D(side * 35)), 'band')
        i.cyl(0.28, 0.5, T(side * 0.42, 1.28, 0) @ A(0, D(side * 20), D(side * 35)), 'bandDark')
    i.ball(0.5, T(0, 1.05, 0), 'band')
    return i


def make_crown():
    i = Icon('crown')
    i.cyl(0.9, 2.4, FLAT, 'gold', mat='Metal', reflect=0.1)
    i.cyl(0.95, 2.0, FLAT, 'goldDark', mat='Metal')
    for k in range(5):
        a = D(k * 72)
        cf = T(math.sin(a) * 1.02, 0.78, math.cos(a) * 1.02)
        i.block((0.5, 0.9, 0.5), cf @ A(0, a, D(0)), 'gold', mat='Metal')
        i.ball(0.38, cf @ T(0, 0.56, 0), 'white')
        i.ball(0.36, T(math.sin(a) * 1.2, 0, math.cos(a) * 1.2), 'red' if k % 2 == 0 else 'gem')
    return i


def make_potion():
    i = Icon('potion')
    i.ball(1.9, T(0, -0.4, 0), 'orange', mat='Glass', transparency=0.1)
    i.cyl(0.9, 0.62, T(0, 0.85, 0) @ FLAT, 'glass', mat='Glass', transparency=0.3)
    i.cyl(0.4, 0.52, T(0, 1.45, 0) @ FLAT, 'wood', mat='Wood')
    i.ball(0.42, T(-0.45, -0.05, 0.62), 'white', mat='Neon')
    return i


ICONS = [make_cash(), make_cash2(), make_cash3(), make_coins(), make_chest(), make_vault(), make_gift(), make_crown(), make_potion()]

# --------------------------------------------------
# Luau 자료
# --------------------------------------------------


def write_data():
    lines = ['-- 자동 생성 파일 (tools/blender/money_icons.py). 손으로 고치지 마세요.',
             '-- 돈 모양 그림의 조각 목록 (Roblox 좌표). MoneyIcon 이 그림 ID 가 없을 때 이 조각으로 3D 모형을 만든다.',
             '-- t : 모양 (Block · Cylinder · Ball) · s : 크기 · c : CFrame 12개 수 · k : 색 · m : 재질 · tr : 투명도 · rf : 반사',
             'return {']
    for icon in ICONS:
        lines.append(f'\t{icon.name} = {{')
        for p in icon.prims:
            m = p['cf']
            nums = [m[0][3], m[1][3], m[2][3], m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]]
            c = ', '.join(f'{v:.4f}'.rstrip('0').rstrip('.') if abs(v) > 1e-9 else '0' for v in nums)
            s = ', '.join(f'{v:g}' for v in p['size'])
            k = ', '.join(str(int(v)) for v in p['color'])
            extra = ''
            if p['tr']:
                extra += f', tr = {p["tr"]:g}'
            if p['rf']:
                extra += f', rf = {p["rf"]:g}'
            lines.append(f'\t\t{{ t = "{p["kind"]}", s = {{ {s} }}, c = {{ {c} }}, k = {{ {k} }}, m = "{p["mat"]}"{extra} }},')
        lines.append('\t},')
    lines.append('}')
    DATA.write_text('\n'.join(lines) + '\n')
    print('wrote', DATA.relative_to(ROOT))


# --------------------------------------------------
# 그리기
# --------------------------------------------------


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, mat, tr, art):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes['Principled BSDF']
    rgb = [c / 255 for c in color]
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    rough = {'Metal': 0.32, 'Wood': 0.75, 'Glass': 0.08, 'Neon': 0.5}.get(mat, 0.45)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = 0.75 if mat == 'Metal' else 0.0
    if mat == 'Glass':
        bsdf.inputs['Transmission Weight'].default_value = 0.35 if art else 0.2
    if mat == 'Neon':
        bsdf.inputs['Emission Color'].default_value = (*rgb, 1)
        bsdf.inputs['Emission Strength'].default_value = 2.0
    return m


def outline_material():
    m = bpy.data.materials.new('Outline')
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    mix = nt.nodes.new('ShaderNodeMixShader')
    black = nt.nodes.new('ShaderNodeEmission')
    black.inputs['Color'].default_value = (0.03, 0.02, 0.04, 1)
    clear = nt.nodes.new('ShaderNodeBsdfTransparent')
    nt.links.new(geo.outputs['Backfacing'], mix.inputs['Fac'])
    # 뒤집힌 껍데기 : 카메라 쪽 면(뒷면으로 잡힌다)은 투명, 가장자리로 삐져나온 먼 쪽 면만 검게
    nt.links.new(clear.outputs['BSDF'], mix.inputs[1])
    nt.links.new(black.outputs['Emission'], mix.inputs[2])
    nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
    return m


def build(icon, art):
    objects = []
    for n, p in enumerate(icon.prims):
        bm = bmesh.new()
        sx, sy, sz = p['size']
        if p['kind'] == 'Block':
            bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Diagonal((sx, sy, sz, 1)))
        elif p['kind'] == 'Cylinder':
            bmesh.ops.create_cone(bm, cap_ends=True, segments=40, radius1=sy / 2, radius2=sy / 2, depth=sx,
                                  matrix=Matrix.Rotation(math.pi / 2, 4, 'Y'))
        else:
            bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=20, radius=sx / 2)
        bm.transform(R2B @ p['cf'])
        mesh = bpy.data.meshes.new(f'{icon.name}_{n}')
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(mesh.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        mesh.materials.append(material(f'M{n}', p['color'], p['mat'], p['tr'], art))
        if p['kind'] != 'Block':
            for poly in mesh.polygons:
                poly.use_smooth = True
        if art:
            if p['kind'] == 'Block':
                bev = obj.modifiers.new('Bevel', 'BEVEL')
                bev.width = min(0.05, min(p['size']) * 0.3)
                bev.segments = 3
                for poly in mesh.polygons:
                    poly.use_smooth = True
                obj.modifiers.new('Normals', 'WEIGHTED_NORMAL').keep_sharp = True
        objects.append(obj)
    return objects


def bounds(objects):
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for obj in objects:
        for v in obj.data.vertices:
            w = obj.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def scene_setup(size):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 40
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.film_transparent = True
    # 검은 외곽선 (Freestyle) : 바깥 윤곽은 굵게, 안쪽 꺾인 모서리는 가늘게
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = 'ABSOLUTE'
    scene.render.line_thickness = size / 150
    view = scene.view_layers[0]
    view.use_freestyle = True
    settings = view.freestyle_settings
    for lineset in list(settings.linesets):
        settings.linesets.remove(lineset)
    outer = settings.linesets.new('Silhouette')
    outer.select_by_visibility = True
    outer.select_silhouette = True
    outer.select_border = True
    outer.select_crease = False
    outer.linestyle.color = (0.04, 0.03, 0.06)
    outer.linestyle.thickness = 1.0
    inner = settings.linesets.new('Creases')
    inner.select_silhouette = False
    inner.select_border = False
    inner.select_crease = True
    inner.linestyle.color = (0.04, 0.03, 0.06)
    inner.linestyle.thickness = 0.35
    settings.crease_angle = math.radians(120)
    scene.view_settings.view_transform = 'Standard'
    world = bpy.data.worlds.new('W')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (1, 1, 1, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 0.4
    scene.world = world
    sun = bpy.data.lights.new('Sun', 'SUN')
    sun.energy = 4.0
    sun.angle = math.radians(20)
    sun_obj = bpy.data.objects.new('Sun', sun)
    # Roblox 의 LightDirection(-0.6, -1, -0.7) 과 비슷한 쪽 (왼쪽 위 앞에서)
    sun_obj.rotation_euler = (math.radians(40), math.radians(-25), math.radians(-30))
    scene.collection.objects.link(sun_obj)
    cam = bpy.data.cameras.new('Cam')
    cam.lens_unit = 'FOV'
    cam.angle = math.radians(28)
    cam_obj = bpy.data.objects.new('Cam', cam)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    return cam_obj


VIEW = Vector((0.25, 0.75, 1)).normalized()  # MoneyIcon.lua 의 VIEW_DIRECTION 과 같다 (Roblox 좌표)


def render(icon, art, path, size):
    reset()
    cam = scene_setup(size)
    objects = build(icon, art)
    lo, hi = bounds(objects)
    center_b = (lo + hi) / 2
    radius = (hi - lo).length / 2
    distance = radius / math.sin(math.radians(14))
    view_b = (R2B @ VIEW.to_4d()).to_3d()
    cam.location = center_b + view_b * distance
    cam.rotation_euler = (center_b - cam.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main():
    write_data()
    only = [a for a in sys.argv[1:] if not a.startswith('-')]
    (OUT / 'parts').mkdir(parents=True, exist_ok=True)
    for icon in ICONS:
        if only and icon.name not in only:
            continue
        render(icon, True, OUT / f'{icon.name}.png', 512)
        if '--parts' in sys.argv:
            render(icon, False, OUT / 'parts' / f'{icon.name}.png', 256)
        print('rendered', icon.name)


if __name__ == '__main__':
    main()
