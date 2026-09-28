"""Blender(bpy) 파이프라인: SDF 파트 → 고해상도 색 메쉬 → 로우폴리 + 텍스처 베이크 → 리깅 → FBX.

각 펫은 Part 목록으로 정의한다.
  Part(name, shape, color_fn, bone=None, tris=목표삼각형수)
  - color_fn(p, n) → (N,3) sRGB 색. 위치/법선으로 배 무늬, 볼터치, 눈동자 등을 칠한다.
  - bone: 이 파트를 통째로 따라갈 뼈 (눈 → Head). None 이면 뼈까지 거리로 자동 가중치.
"""
from __future__ import annotations

import math
import os
from dataclasses import dataclass, field

import bpy
import imageio.v3 as iio
import numpy as np
from mathutils import Vector

import sdf


@dataclass
class Part:
    name: str
    shape: sdf.Shape
    color: callable
    bone: str | None = None
    tris: int = 800
    voxel: float = 0.008
    rough: float = 0.55  # 미리보기 렌더용 거칠기


@dataclass
class Bone:
    name: str
    head: tuple
    tail: tuple
    parent: str | None = None
    radius: float = 0.2  # 자동 가중치 영향 반경
    deform: bool = True


@dataclass
class Creature:
    name: str
    parts: list
    bones: list
    texture_size: int = 1024
    ao_strength: float = 0.65
    notes: dict = field(default_factory=dict)


# ---------------------------------------------------------------- scene

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.unit_settings.system = "METRIC"
    world = bpy.data.worlds.new("World")
    scene.world = world
    return scene


def select_only(*objs, active=None):
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        if o is not None:
            o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def srgb_to_linear(c):
    c = np.asarray(c, float)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def make_mesh(name, verts, faces, colors=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts.tolist(), [], faces.tolist())
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if colors is not None:
        attr = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="POINT")
        rgba = np.column_stack([srgb_to_linear(colors), np.ones(len(colors))]).astype(np.float32)
        attr.data.foreach_set("color", rgba.ravel())
    return obj


# ---------------------------------------------------------------- geometry

def build_high(part: Part):
    verts, faces, normals = sdf.mesh_shape(part.shape, voxel=part.voxel)
    colors = np.clip(part.color(verts, normals), 0, 1)
    return make_mesh(part.name + "_high", verts, faces, colors)


def decimated_copy(high, name, tris):
    mesh = high.data.copy()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    if count > tris:
        mod = obj.modifiers.new("dec", "DECIMATE")
        mod.ratio = tris / count
        mod.use_collapse_triangulate = True
        select_only(obj)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    # 로우폴리에는 베이크한 텍스처만 쓴다
    while obj.data.color_attributes:
        obj.data.color_attributes.remove(obj.data.color_attributes[0])
    return obj


def join(objs, name):
    select_only(*objs, active=objs[0])
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def triangle_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# ---------------------------------------------------------------- texture bake

def bake_texture(creature: Creature, highs, low, out_png):
    size = creature.texture_size
    scene = bpy.context.scene

    select_only(low)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")

    # 고해상도: 버텍스 색을 발광으로 내보내는 재질
    emit_mat = bpy.data.materials.new("bake_emit")
    emit_mat.use_nodes = True
    nt = emit_mat.node_tree
    nt.nodes.clear()
    attr = nt.nodes.new("ShaderNodeAttribute")
    attr.attribute_name = "Col"
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(attr.outputs["Color"], emit.inputs["Color"])
    nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
    for h in highs:
        h.data.materials.clear()
        h.data.materials.append(emit_mat)

    color_img = bpy.data.images.new("bake_color", size, size, float_buffer=True, alpha=False)
    ao_img = bpy.data.images.new("bake_ao", size, size, float_buffer=True, alpha=False)
    low_mat = bpy.data.materials.new(creature.name + "_mat")
    low_mat.use_nodes = True
    lnt = low_mat.node_tree
    tex = lnt.nodes.new("ShaderNodeTexImage")
    low.data.materials.clear()
    low.data.materials.append(low_mat)

    def target(img):
        tex.image = img
        for n in lnt.nodes:
            n.select = False
        tex.select = True
        lnt.nodes.active = tex

    scene.render.bake.margin = 12
    scene.render.bake.margin_type = "EXTEND"

    # 1) 색: 고해상도 → 로우폴리
    target(color_img)
    scene.cycles.samples = 4
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = 0.02
    scene.render.bake.max_ray_distance = 0.06
    select_only(*highs, low, active=low)
    bpy.ops.object.bake(type="EMIT")

    # 2) AO: 로우폴리 자체 (몸 아래, 다리 사이, 눈 주변이 자연스럽게 어두워진다)
    target(ao_img)
    scene.world.light_settings.distance = 0.35
    scene.cycles.samples = 48
    scene.render.bake.use_selected_to_active = False
    for h in highs:
        h.hide_render = True
    select_only(low)
    bpy.ops.object.bake(type="AO")

    px = np.array(color_img.pixels[:], dtype=np.float32).reshape(size, size, 4)[:, :, :3]
    ao = np.array(ao_img.pixels[:], dtype=np.float32).reshape(size, size, 4)[:, :, :1]
    ao = np.clip(ao, 0, 1) ** 0.8
    shaded = px * (1.0 - creature.ao_strength + creature.ao_strength * ao)
    srgb = (linear_to_srgb(shaded) * 255 + 0.5).astype(np.uint8)
    iio.imwrite(out_png, np.flipud(srgb))

    # 내보낼 재질: 베이크된 텍스처 한 장 + 기본 BSDF
    lnt.nodes.clear()
    bsdf = lnt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.6
    img_node = lnt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(out_png)
    img.colorspace_settings.name = "sRGB"
    img_node.image = img
    outn = lnt.nodes.new("ShaderNodeOutputMaterial")
    lnt.links.new(img_node.outputs["Color"], bsdf.inputs["Base Color"])
    lnt.links.new(bsdf.outputs["BSDF"], outn.inputs["Surface"])
    return low_mat


# ---------------------------------------------------------------- rig

def point_segment_distance(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / max(ab @ ab, 1e-9), 0, 1)
    closest = a + np.outer(t, ab)
    return np.linalg.norm(p - closest, axis=1)


def build_rig(creature: Creature, low):
    arm_data = bpy.data.armatures.new(creature.name + "_Rig")
    arm = bpy.data.objects.new(creature.name + "_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    select_only(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    edit = {}
    for b in creature.bones:
        eb = arm_data.edit_bones.new(b.name)
        eb.head, eb.tail = Vector(b.head), Vector(b.tail)
        eb.use_deform = b.deform
        edit[b.name] = eb
    for b in creature.bones:
        if b.parent:
            edit[b.name].parent = edit[b.parent]
    bpy.ops.object.mode_set(mode="OBJECT")

    verts = np.array([v.co[:] for v in low.data.vertices])
    n = len(verts)
    deform = [b for b in creature.bones if b.deform]
    names = [b.name for b in deform]
    weights = np.zeros((n, len(deform)))
    for j, b in enumerate(deform):
        d = point_segment_distance(verts, np.array(b.head), np.array(b.tail))
        weights[:, j] = np.exp(-((d / b.radius) ** 3))
    # 통째로 붙는 파트 (눈, 잎, 등껍질 …): join 전에 "__rigid_<뼈>" 정점 그룹으로 표시해 두었다
    rigid = {g.index: g.name[len("__rigid_"):] for g in low.vertex_groups if g.name.startswith("__rigid_")}
    for v in low.data.vertices:
        for g in v.groups:
            if g.group in rigid:
                weights[v.index] = 0
                weights[v.index, names.index(rigid[g.group])] = 1
    for bone_name in set(rigid.values()):
        low.vertex_groups.remove(low.vertex_groups["__rigid_" + bone_name])
    # 영향 뼈 최대 4개, 합 1
    order = np.argsort(-weights, axis=1)
    for i in range(n):
        keep = order[i, :4]
        w = weights[i, keep]
        if w.sum() < 1e-6:
            w = np.array([1.0, 0, 0, 0])
            keep = np.array([names.index("Body"), 0, 0, 0])
        w = w / w.sum()
        weights[i] = 0
        weights[i, keep] = w
    groups = {name: low.vertex_groups.new(name=name) for name in names}
    for j, name in enumerate(names):
        idx = np.nonzero(weights[:, j] > 0.01)[0]
        for i in idx:
            groups[name].add([int(i)], float(weights[i, j]), "REPLACE")
    mod = low.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    low.parent = arm
    return arm


# ---------------------------------------------------------------- build all

def build(creature: Creature, out_dir):
    reset()
    highs, lows = [], []
    for part in creature.parts:
        high = build_high(part)
        low = decimated_copy(high, part.name, part.tris)
        if part.bone:
            group = low.vertex_groups.new(name="__rigid_" + part.bone)
            group.add(list(range(len(low.data.vertices))), 1.0, "REPLACE")
        highs.append(high)
        lows.append(low)
    low = join(lows, creature.name)
    png = os.path.join(out_dir, creature.name + ".png")
    bake_texture(creature, highs, low, png)
    for h in highs:
        bpy.data.objects.remove(h, do_unlink=True)
    arm = build_rig(creature, low)
    tris = triangle_count(low)
    fbx = os.path.join(out_dir, creature.name + ".fbx")
    select_only(arm, low, active=arm)
    bpy.ops.export_scene.fbx(
        filepath=fbx, use_selection=True, object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False, bake_anim=False, path_mode="COPY", embed_textures=True,
        mesh_smooth_type="FACE", use_armature_deform_only=False,
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
    )
    blend = os.path.join(out_dir, creature.name + ".blend")
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    return {"name": creature.name, "tris": tris, "verts": len(low.data.vertices), "fbx": fbx, "png": png, "blend": blend}
