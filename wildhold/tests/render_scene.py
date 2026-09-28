"""헤드리스 테스트가 내보낸 맵(.scene_parts.txt / .scene_terrain.txt)을 Blender 로 렌더해 레벨을 눈으로 확인한다.
Roblox 좌표 (x, y, z) → Blender (x, -z, y).  python3 render_scene.py [출력 폴더] [--fast]

- 파트는 모양·색 그대로, 숲 키트 메쉬(Asset 줄)는 assets/env/EnvModels.blend 의 실제 에셋으로 바꿔 넣는다.
- 낮: 흐린 하늘 + 안개(미스트 패스 합성, 볼륨보다 훨씬 빠르다). 밤: 모든 PointLight 를 켜고 달빛만 남긴다.
- Roblox 의 재질 질감·풀 장식·Future 조명은 없어서 실제 Studio 화면과는 다르다 (분위기·배치 확인용).
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
args = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = args[0] if args else os.path.join(HERE, "renders")
FAST = "--fast" in sys.argv
os.makedirs(OUT, exist_ok=True)
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
P_INV = P.inverted()
# MapService 의 SetMaterialColor 와 같은 색 (생존 톤)
TERRAIN = {"Grass": (0.29, 0.34, 0.23), "LeafyGrass": (0.24, 0.29, 0.18), "Ground": (0.35, 0.29, 0.23), "Mud": (0.24, 0.2, 0.16),
           "Sand": (0.61, 0.56, 0.43), "Cobblestone": (0.47, 0.45, 0.42), "Rock": (0.38, 0.40, 0.42), "Water": (0.17, 0.31, 0.36)}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16 if FAST else 48
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Base Contrast"
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
BG = world.node_tree.nodes["Background"]


def srgb(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def material(name, color=None, emissive=False, alpha=1.0, noise=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    if color is None:
        info = nt.nodes.new("ShaderNodeObjectInfo")
        nt.links.new(info.outputs["Color"], bsdf.inputs["Base Color"])
        nt.links.new(info.outputs["Alpha"], bsdf.inputs["Alpha"])  # 파트 투명도 (obj.color 의 알파)
        if emissive:
            nt.links.new(info.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 2.0
    elif noise > 0:
        # 지형: 얼룩덜룩한 색 (Roblox 지형 질감 대신)
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 0.08
        tex.inputs["Detail"].default_value = 8
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        lo, hi = [c * (1 - noise) for c in color], [min(1, c * (1 + noise)) for c in color]
        ramp.color_ramp.elements[0].color = (*lo, 1)
        ramp.color_ramp.elements[1].color = (*hi, 1)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.8
    if alpha < 1:
        bsdf.inputs["Alpha"].default_value = alpha
    return mat


MAT_OBJ = material("obj")
MAT_NEON = material("neon", emissive=True)
MAT_GLASS = material("glass")
MAT_GLASS.node_tree.nodes["Principled BSDF"].inputs["Transmission Weight"].default_value = 0.6


def prim(kind):
    if kind in PRIMS:
        return PRIMS[kind]
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=20, ring_count=12)
        bpy.ops.object.shade_smooth()
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, vertices=20, rotation=(0, math.pi / 2, 0))
        bpy.ops.object.transform_apply(rotation=True)
        bpy.ops.object.shade_smooth()
    elif kind == "wedge":
        mesh = bpy.data.meshes.new("wedge")
        # Roblox WedgePart: 수직면이 +Z, 경사면이 -Z 로 내려간다 (로컬 좌표, 크기 1)
        v = [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5), (-.5, .5, .5), (.5, .5, .5)]
        f = [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)]
        mesh.from_pydata(v, [], f)
        obj = bpy.data.objects.new("wedge", mesh)
        scene.collection.objects.link(obj)
        bpy.context.view_layer.objects.active = obj
    obj = bpy.context.active_object
    PRIMS[kind] = obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    return PRIMS[kind]


PRIMS = {}
coll = bpy.data.collections.new("parts")
scene.collection.children.link(coll)


# 파트 메쉬는 Roblox 로컬 축으로 정의하고, 월드 변환에서만 축을 바꾼다: M_b = P · M_r
def place_part(kind, x, y, z, rot, size, color, mat, transparency=0.0):
    obj = bpy.data.objects.new("p", prim(kind))
    m = Matrix.Translation(P @ Vector((x, y, z))) @ (P @ rot).to_4x4() @ Matrix.Diagonal((*size, 1))
    obj.matrix_world = m
    obj.color = (*color, 1 - transparency)
    coll.objects.link(obj)
    if len(obj.material_slots) == 0:
        obj.data.materials.append(MAT_OBJ)
    obj.material_slots[0].link = "OBJECT"
    obj.material_slots[0].material = mat
    return obj


# ---------------------------------------------------------------- 숲 키트 에셋
ENV = {}


def env_asset(name):
    """EnvModels.blend 에서 에셋 메쉬를 가져와 (메쉬, 로컬 bbox 중심, Roblox 축 크기) 를 돌려준다."""
    if name not in ENV:
        path = os.path.join(ROOT, "assets", "env", "EnvModels.blend")
        with bpy.data.libraries.load(path, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n == name]
        obj = dst.objects[0]
        co = [v.co for v in obj.data.vertices]
        lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
        hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
        dims_b = hi - lo
        ENV[name] = (obj.data, (lo + hi) / 2, Vector((dims_b.x, dims_b.z, dims_b.y)))
    return ENV[name]


def place_asset(name, x, y, z, rot, size):
    # 가져오기 규칙: Blender 로컬 (x, y, z) → Roblox 로컬 (x, z, -y), 메쉬는 bbox 중심 기준으로 Size 에 맞춰 늘어난다
    data, centre, dims = env_asset(name)
    scale = Matrix.Diagonal((size[0] / dims.x, size[1] / dims.y, size[2] / dims.z))
    m = Matrix.Translation(P @ Vector((x, y, z))) @ (P @ rot @ scale @ P_INV).to_4x4() @ Matrix.Translation(-centre)
    obj = bpy.data.objects.new(name, data)
    obj.matrix_world = m
    coll.objects.link(obj)
    return obj


count, assets, lights = 0, 0, []
for line in open(os.path.join(HERE, ".scene_parts.txt")):
    t = line.split()
    if t and t[0] == "Light":
        lights.append(tuple(map(float, t[1:9])))
        continue
    if len(t) < 21:
        continue
    shape, matname = t[0], t[1]
    x, y, z = map(float, t[2:5])
    r = list(map(float, t[5:14]))
    sx, sy, sz = map(float, t[14:17])
    col = tuple(map(float, t[17:20]))
    transparency = float(t[20])
    rot = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
    if shape == "Asset":
        place_asset(matname, x, y, z, rot, (sx, sy, sz))
        assets += 1
        continue
    if shape == "Ball" or shape == "Sphere":
        kind = "sphere"
    elif shape == "Cylinder":
        kind = "cyl"
    elif shape == "Wedge":
        kind = "wedge"
    else:
        kind = "cube"
    mat = MAT_NEON if matname == "Neon" else (MAT_GLASS if matname == "Glass" else MAT_OBJ)
    place_part(kind, x, y, z, rot, (sx, sy, sz), col, mat, transparency)
    count += 1

# 지형: 바닥 평면 + 언덕 공 + 원판 + 길(회전 상자)
bpy.ops.mesh.primitive_plane_add(size=460, location=(0, 0, 0))
ground = bpy.context.active_object
terrain_mats = {k: material("t_" + k, v, noise=0.22) for k, v in TERRAIN.items()}
ground.data.materials.append(terrain_mats["Grass"])
order = 0
for line in open(os.path.join(HERE, ".scene_terrain.txt")):
    t = line.split()
    kind, mat = t[0], t[1]
    if mat == "Air":
        continue
    order += 1
    lift = 0.02 + order * 0.00002  # 나중 명령이 위에 보이도록
    if kind == "Ball":
        x, y, z, rr = map(float, t[2:6])
        bpy.ops.mesh.primitive_uv_sphere_add(radius=rr, location=P @ Vector((x, y, z)), segments=24, ring_count=12)
        bpy.ops.object.shade_smooth()
    elif kind == "Cylinder":
        x, y, z, h, rr = map(float, t[2:7])
        top = y + h / 2
        if top < -1 and mat != "Water":
            continue
        zz = -1.8 if mat == "Water" else lift
        bpy.ops.mesh.primitive_cylinder_add(radius=rr, depth=0.02, location=(x, z * -1, zz), vertices=48)
    elif kind == "Block":
        x, y, z = map(float, t[2:5])
        r = list(map(float, t[5:14]))
        sx, sy, sz = map(float, t[14:17])
        if sx > 300:
            continue
        rot = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
        place_part("cube", x, lift, z, rot, (sx, 0.02, sz), TERRAIN.get(mat, (0.5, 0.5, 0.5)), terrain_mats.get(mat, MAT_OBJ))
        continue
    else:
        continue
    obj = bpy.context.active_object
    obj.data.materials.append(terrain_mats.get(mat, MAT_OBJ))

print("parts", count, "assets", assets, "lights", len(lights))

# ---------------------------------------------------------------- 조명 · 안개
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.rotation_euler = (math.radians(48), math.radians(12), math.radians(-40))
scene.collection.objects.link(sun)
night_lights = []
for (x, y, z, rng, bright, r, g, b) in lights:
    light = bpy.data.lights.new("pl", "POINT")
    light.color = (r, g, b)
    light.energy = bright * 30 * (rng / 10) ** 2
    light.shadow_soft_size = 0.4
    obj = bpy.data.objects.new("pl", light)
    obj.location = P @ Vector((x, y, z))
    scene.collection.objects.link(obj)
    night_lights.append(obj)

scene.view_layers[0].use_pass_mist = True
scene.use_nodes = True
cnt = scene.node_tree
cnt.nodes.clear()
rl = cnt.nodes.new("CompositorNodeRLayers")
fog_mix = cnt.nodes.new("CompositorNodeMixRGB")
fog_mix.blend_type = "MIX"
fog_amount = cnt.nodes.new("CompositorNodeMath")
fog_amount.operation = "MULTIPLY"
comp = cnt.nodes.new("CompositorNodeComposite")
cnt.links.new(rl.outputs["Mist"], fog_amount.inputs[0])
cnt.links.new(fog_amount.outputs[0], fog_mix.inputs["Fac"])
cnt.links.new(rl.outputs["Image"], fog_mix.inputs[1])
cnt.links.new(fog_mix.outputs[0], comp.inputs["Image"])


def mood(kind, fog=1.0):
    """day: 흐린 낮 / night: 달빛 + 불빛만. fog = 안개 세기 배율 (멀리서 찍는 전체 사진은 줄인다)"""
    mist = world.mist_settings
    mist.falloff = "QUADRATIC"
    if kind == "day":
        BG.inputs["Color"].default_value = (*srgb((0.6, 0.65, 0.66)), 1)
        BG.inputs["Strength"].default_value = 1.0
        sun.data.energy = 2.2
        sun.data.angle = math.radians(12)
        sun.data.color = (1.0, 0.96, 0.9)
        mist.start, mist.depth = 25, 260
        fog_amount.inputs[1].default_value = 0.72 * fog
        fog_mix.inputs[2].default_value = (*srgb((0.6, 0.64, 0.64)), 1)
        for obj in night_lights:
            obj.hide_render = True
    else:
        BG.inputs["Color"].default_value = (*srgb((0.08, 0.1, 0.16)), 1)
        BG.inputs["Strength"].default_value = 0.08
        sun.data.energy = 0.06
        sun.data.angle = math.radians(2)
        sun.data.color = (0.6, 0.7, 1.0)
        mist.start, mist.depth = 10, 150
        fog_amount.inputs[1].default_value = 0.9 * fog
        fog_mix.inputs[2].default_value = (*srgb((0.05, 0.06, 0.09)), 1)
        for obj in night_lights:
            obj.hide_render = False


def shoot(name, eye_r, target_r, lens=35, size=(1600, 900), kind="day", fog=1.0):
    mood(kind, fog)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = lens
    cam.data.clip_end = 2000
    scene.collection.objects.link(cam)
    eye, target = P @ Vector(eye_r), P @ Vector(target_r)
    cam.location = eye
    cam.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


shoot("map_overview.png", (0, 260, 250), (0, 0, 10), lens=30, fog=0.35)
shoot("map_base.png", (58, 42, 78), (0, 2, 0), lens=32)
shoot("map_meadow.png", (22, 10, 38), (4, 6, 90), lens=30)
shoot("map_night.png", (46, 26, 60), (0, 4, 0), lens=30, kind="night")
