"""헤드리스 테스트가 내보낸 맵(.scene_parts.txt / .scene_terrain.txt)을 Blender 로 렌더해 레벨을 눈으로 확인한다.
Roblox 좌표 (x, y, z) → Blender (x, -z, y).  python3 render_scene.py [출력 폴더]
"""
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "renders")
os.makedirs(OUT, exist_ok=True)
P = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
# MapService 의 SetMaterialColor 와 같은 색 (생존 톤)
TERRAIN = {"Grass": (0.32, 0.41, 0.24), "LeafyGrass": (0.26, 0.35, 0.20), "Ground": (0.43, 0.34, 0.25), "Mud": (0.29, 0.23, 0.17),
           "Sand": (0.61, 0.56, 0.43), "Cobblestone": (0.47, 0.45, 0.42), "Rock": (0.38, 0.40, 0.42), "Water": (0.17, 0.31, 0.36)}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 40
scene.cycles.use_denoising = True
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
# 낮 하늘. (월드 볼륨 안개는 CPU 렌더가 10분을 넘겨서 뺐다. 밤 안개는 Studio 에서 확인)
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.70, 0.74, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8


def material(name, color=None, emissive=False, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    if color is None:
        info = nt.nodes.new("ShaderNodeObjectInfo")
        nt.links.new(info.outputs["Color"], bsdf.inputs["Base Color"])
        if emissive:
            nt.links.new(info.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 2.0
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.75
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
def place_part(kind, x, y, z, rot, size, color, mat):
    obj = bpy.data.objects.new("p", prim(kind))
    m = Matrix.Translation(P @ Vector((x, y, z))) @ (P @ rot).to_4x4() @ Matrix.Diagonal((*size, 1))
    obj.matrix_world = m
    obj.color = (*color, 1)
    coll.objects.link(obj)
    if len(obj.material_slots) == 0:
        obj.data.materials.append(MAT_OBJ)
    obj.material_slots[0].link = "OBJECT"
    obj.material_slots[0].material = mat
    return obj


count = 0
for line in open(os.path.join(HERE, ".scene_parts.txt")):
    t = line.split()
    if len(t) < 21:
        continue
    shape, matname = t[0], t[1]
    x, y, z = map(float, t[2:5])
    r = list(map(float, t[5:14]))
    sx, sy, sz = map(float, t[14:17])
    col = tuple(map(float, t[17:20]))
    rot = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
    if shape == "Ball" or shape == "Sphere":
        kind = "sphere"
    elif shape == "Cylinder":
        kind = "cyl"
    elif shape == "Wedge":
        kind = "wedge"
    else:
        kind = "cube"
    mat = MAT_NEON if matname == "Neon" else (MAT_GLASS if matname == "Glass" else MAT_OBJ)
    place_part(kind, x, y, z, rot, (sx, sy, sz), col, mat)
    count += 1

# 지형: 바닥 평면 + 언덕 공 + 원판 + 길(회전 상자)
bpy.ops.mesh.primitive_plane_add(size=420, location=(0, 0, 0))
ground = bpy.context.active_object
ground.data.materials.append(material("grass", TERRAIN["Grass"]))
terrain_mats = {k: material("t_" + k, v) for k, v in TERRAIN.items()}
for line in open(os.path.join(HERE, ".scene_terrain.txt")):
    t = line.split()
    kind, mat = t[0], t[1]
    if mat == "Air":
        continue
    if kind == "Ball":
        x, y, z, rr = map(float, t[2:6])
        bpy.ops.mesh.primitive_uv_sphere_add(radius=rr, location=P @ Vector((x, y, z)), segments=24, ring_count=12)
        bpy.ops.object.shade_smooth()
    elif kind == "Cylinder":
        x, y, z, h, rr = map(float, t[2:7])
        top = y + h / 2
        if top < -1 and mat != "Water":
            continue
        zz = 0.02 + (0.01 if mat != "LeafyGrass" else 0) if mat != "Water" else -1.8
        if mat == "Sand":
            zz = 0.015
        bpy.ops.mesh.primitive_cylinder_add(radius=rr, depth=0.02, location=(x, z * -1, zz), vertices=48)
    elif kind == "Block":
        x, y, z = map(float, t[2:5])
        r = list(map(float, t[5:14]))
        sx, sy, sz = map(float, t[14:17])
        if sx > 300:
            continue
        rot = Matrix(((r[0], r[1], r[2]), (r[3], r[4], r[5]), (r[6], r[7], r[8])))
        obj = place_part("cube", x, 0.03, z, rot, (sx, 0.02, sz), TERRAIN.get(mat, (0.5, 0.5, 0.5)), terrain_mats.get(mat, MAT_OBJ))
        continue
    else:
        continue
    obj = bpy.context.active_object
    obj.data.materials.append(terrain_mats.get(mat, MAT_OBJ))

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5
sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(-40))
scene.collection.objects.link(sun)


def shoot(name, eye_r, target_r, lens=35, size=(1600, 900)):
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


print("parts", count)
shoot("map_overview.png", (0, 260, 250), (0, 0, 10), lens=30)
shoot("map_base.png", (58, 42, 78), (0, 2, 0), lens=32)
shoot("map_meadow.png", (22, 12, 34), (4, 3, 80), lens=30)
