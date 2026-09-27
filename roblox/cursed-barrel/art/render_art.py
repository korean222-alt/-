"""
Cursed Barrel · Phase 32.1 그림 (Blender 4.2 · bpy)

  python3 art/render_art.py cards   → art/out/cards/<id>.png  (카드 한 장 300 x 510)
  python3 art/render_art.py icons   → art/out/icons/<id>.png  (아이콘 하나 256 x 256)
  python3 art/pack_sheets.py        → art/sheets/*.png (Roblox 에 올리는 묶음 그림)

운명 카드는 타로 카드처럼 : 짙은 바탕 · 금테 두 겹 · 모서리 장식 · 위쪽 로마 숫자 · 가운데 아치 창(빛살) 안의 입체 그림 · 아래 이름 판.
이름 · 규칙 글자는 그림에 넣지 않는다. Roblox 가 이름 판 위에 글자를 얹는다 (번역 · 수정이 쉽다).
"""
import math
import os
import sys

import bpy  # noqa: E402  (bpy 를 먼저 불러야 addon_utils · bmesh 가 보인다)
import addon_utils  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"

# 카드 크기 (블렌더 단위). 가로 : 세로 = 300 : 510
W, H = 6.0, 10.2


# --------------------------------------------------------------------------
# 장면
# --------------------------------------------------------------------------
def reset(res_x, res_y, ortho, samples=64):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable("cycles", default_set=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.cycles.samples = samples
    s.cycles.use_denoising = True
    s.render.film_transparent = True
    s.render.resolution_x = res_x
    s.render.resolution_y = res_y
    s.render.resolution_percentage = 100
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    s.view_settings.view_transform = "Standard"
    s.view_settings.look = "None"
    s.view_settings.exposure = 0.1
    world = bpy.data.worlds.new("World")
    s.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.5, 0.42, 0.34, 1)
    bg.inputs[1].default_value = 0.35

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", cam_data)
    cam.location = (0, 0, 30)
    s.collection.objects.link(cam)
    s.camera = cam

    def area(name, loc, size, power, color=(1, 0.95, 0.88)):
        data = bpy.data.lights.new(name, "AREA")
        data.size = size
        data.energy = power
        data.color = color
        obj = bpy.data.objects.new(name, data)
        obj.location = loc
        s.collection.objects.link(obj)
        direction = Vector((0, 0, 0)) - Vector(loc)
        obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        return obj

    area("Key", (-8, 9, 12), 7, 2200)
    area("Fill", (8, -5, 10), 10, 380, (0.75, 0.85, 1))
    area("Rim", (2, 10, 3), 5, 600, (1, 0.8, 0.55))
    return s


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


# --------------------------------------------------------------------------
# 재질
# --------------------------------------------------------------------------
_mats = {}


def principled(name, color, metallic=0.0, rough=0.45, emit=None, emit_strength=0.0, alpha=1.0, transmission=0.0):
    key = (name, tuple(color), metallic, rough, emit, emit_strength, alpha, transmission)
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if transmission:
        p.inputs["Transmission Weight"].default_value = transmission
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = emit_strength
    if alpha < 1:
        p.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND"
    _mats[key] = m
    return m


def gold():
    return principled("Gold", (1.0, 0.6, 0.18), metallic=1.0, rough=0.3)


def pale_gold():
    return principled("PaleGold", (1.0, 0.78, 0.42), metallic=1.0, rough=0.32)


def ivory():
    return principled("Ivory", (0.93, 0.89, 0.78), rough=0.42)


def ink():
    return principled("Ink", (0.02, 0.02, 0.025), rough=0.6)


def steel():
    return principled("Steel", (0.78, 0.8, 0.84), metallic=1.0, rough=0.22)


def glow(name, color, strength=3.0):
    return principled(name, color, rough=0.5, emit=color, emit_strength=strength)


def face_material(color):
    """카드 바탕 : 짙은 색 + 벨벳 같은 잔무늬"""
    m = bpy.data.materials.new("Face")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = 0.62
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18
    noise.inputs["Detail"].default_value = 6
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    navy = (0.006, 0.008, 0.02)
    dark = tuple(n + c * 0.012 for n, c in zip(navy, color))
    mid = tuple(n * 2 + c * 0.045 for n, c in zip(navy, color))
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*mid, 1)
    nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.15
    nt.links.new(noise.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    return m


def rays_material(color, center_y, count=18):
    """아치 창 안의 빛살 (가운데가 밝고 바깥으로 갈수록 짙다)"""
    m = bpy.data.materials.new("Rays")
    m.use_nodes = True
    nt = m.node_tree
    nodes = nt.nodes
    out = nodes["Material Output"]
    p = nodes["Principled BSDF"]
    nodes.remove(p)
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(coord.outputs["Object"], sep.inputs[0])
    dy = nodes.new("ShaderNodeMath")
    dy.operation = "SUBTRACT"
    dy.inputs[1].default_value = center_y
    nt.links.new(sep.outputs["Y"], dy.inputs[0])
    ang = nodes.new("ShaderNodeMath")
    ang.operation = "ARCTAN2"
    nt.links.new(dy.outputs[0], ang.inputs[0])
    nt.links.new(sep.outputs["X"], ang.inputs[1])
    mul = nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = count
    nt.links.new(ang.outputs[0], mul.inputs[0])
    sin = nodes.new("ShaderNodeMath")
    sin.operation = "SINE"
    nt.links.new(mul.outputs[0], sin.inputs[0])
    ray = nodes.new("ShaderNodeMapRange")
    ray.inputs["From Min"].default_value = -1
    ray.inputs["From Max"].default_value = 1
    ray.inputs["To Min"].default_value = 0.45
    ray.inputs["To Max"].default_value = 1.0
    nt.links.new(sin.outputs[0], ray.inputs["Value"])
    # 가운데에서 멀수록 어둡게
    vec = nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["X"], vec.inputs["X"])
    nt.links.new(dy.outputs[0], vec.inputs["Y"])
    length = nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    nt.links.new(vec.outputs[0], length.inputs[0])
    fall = nodes.new("ShaderNodeMapRange")
    fall.inputs["From Min"].default_value = 0.0
    fall.inputs["From Max"].default_value = 3.6
    fall.inputs["To Min"].default_value = 1.0
    fall.inputs["To Max"].default_value = 0.08
    nt.links.new(length.outputs["Value"], fall.inputs["Value"])
    both = nodes.new("ShaderNodeMath")
    both.operation = "MULTIPLY"
    nt.links.new(ray.outputs[0], both.inputs[0])
    nt.links.new(fall.outputs[0], both.inputs[1])
    tint = nodes.new("ShaderNodeMixRGB")
    tint.blend_type = "MULTIPLY"
    tint.inputs["Fac"].default_value = 1.0
    peak = max(color)
    light = tuple(min(1, (c / peak) ** 1.6 * 0.9 + 0.03) for c in color)
    tint.inputs["Color2"].default_value = (*light, 1)
    nt.links.new(both.outputs[0], tint.inputs["Color1"])
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Strength"].default_value = 0.62
    nt.links.new(tint.outputs[0], emission.inputs["Color"])
    nt.links.new(emission.outputs[0], out.inputs["Surface"])
    return m


# --------------------------------------------------------------------------
# 모양 도우미
# --------------------------------------------------------------------------
def rounded_outline(w, h, r, cx=0.0, cy=0.0, seg=10):
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)]
    for x, y, start in corners:
        for i in range(seg + 1):
            a = math.radians(start + 90 * i / seg)
            pts.append((cx + x + r * math.cos(a), cy + y + r * math.sin(a)))
    return pts


def arch_outline(w, bottom, spring, cx=0.0, seg=32):
    """아래가 반듯하고 위가 반원인 창. spring = 반원이 시작하는 높이"""
    r = w / 2
    pts = [(cx + r, bottom)]
    for i in range(seg + 1):
        a = math.pi * i / seg
        pts.append((cx + r * math.cos(a), spring + r * math.sin(a)))
    pts.append((cx - r, bottom))
    return pts


def polygon_mesh(name, outline, z0, z1, mat, bevel=0.0):
    """윤곽선을 두께 z0 ~ z1 로 세운 판"""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, z0)) for x, y in outline]
    face = bm.faces.new(verts)
    bmesh.ops.recalc_face_normals(bm, faces=[face])
    if face.normal.z < 0:
        face.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [v for v in ext["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, z1 - z0), verts=top)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        mod.limit_method = "ANGLE"
    return obj


def ring_mesh(name, outer, inner, z0, z1, mat, bevel=0.03):
    """두 윤곽선(같은 점 수) 사이를 채운 테두리"""
    assert len(outer) == len(inner)
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    n = len(outer)
    layers = []
    for z in (z0, z1):
        layers.append(([bm.verts.new((x, y, z)) for x, y in outer], [bm.verts.new((x, y, z)) for x, y in inner]))
    (ob, ib), (ot, it) = layers
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ot[i], ot[j], it[j], it[i]))  # 윗면
        bm.faces.new((ob[j], ob[i], ib[i], ib[j]))  # 아랫면
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))  # 바깥 옆
        bm.faces.new((ib[j], ib[i], it[i], it[j]))  # 안쪽 옆
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new(name, mesh))
    obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def star_outline(points, outer, inner, cx=0.0, cy=0.0, rot=90):
    pts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = math.radians(rot + 180 * i / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def star(name, points, outer, inner, cx, cy, z, mat, depth=0.08, rot=90):
    return polygon_mesh(name, star_outline(points, outer, inner, cx, cy, rot), z, z + depth, mat, bevel=0.02)


def prim(kind, name, mat, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), smooth=True, **kw):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("segments", 40), ring_count=kw.get("rings", 20), radius=kw.get("radius", 1))
    elif kind == "ico":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=kw.get("subdiv", 1), radius=kw.get("radius", 1))
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("vertices", 48), radius=kw.get("radius", 1), depth=kw.get("depth", 1))
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("vertices", 48), radius1=kw.get("r1", 1), radius2=kw.get("r2", 0), depth=kw.get("depth", 1))
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=kw.get("major", 1), minor_radius=kw.get("minor", 0.2), major_segments=kw.get("mseg", 48), minor_segments=kw.get("nseg", 16))
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=kw.get("size", 1))
    obj = bpy.context.active_object
    obj.name = name
    obj.location = loc
    obj.scale = scale
    obj.rotation_euler = [math.radians(a) for a in rot]
    obj.data.materials.append(mat)
    if smooth:
        bpy.ops.object.shade_smooth()
    else:
        bpy.ops.object.shade_flat()
    if kw.get("bevel"):
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = kw["bevel"]
        mod.segments = 3
    return obj


def tube(name, points, radius, mat, cyclic=False, resolution=12):
    """점들을 잇는 둥근 관 (파도 · 갈고리 · 소용돌이)"""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 6
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for i, p in enumerate(points):
        spline.points[i].co = (p[0], p[1], p[2] if len(p) > 2 else 0.6, 1)
    spline.use_cyclic_u = cyclic
    curve.resolution_u = resolution
    obj = link(bpy.data.objects.new(name, curve))
    obj.data.materials.append(mat)
    return obj


def text(name, body, x, y, z, size, mat, depth=0.05, font=FONT):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.font = bpy.data.fonts.load(font, check_existing=True)
    curve.size = size
    curve.extrude = depth
    curve.bevel_depth = 0.012
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = link(bpy.data.objects.new(name, curve))
    obj.location = (x, y, z)
    obj.data.materials.append(mat)
    return obj


def boolean(target, cutter, operation="DIFFERENCE"):
    mod = target.modifiers.new("Bool", "BOOLEAN")
    mod.operation = operation
    mod.object = cutter
    cutter.hide_render = True
    return mod


# --------------------------------------------------------------------------
# 그림 조각
# --------------------------------------------------------------------------
def skull(name, x, y, z, s=1.0, bone=None, eye=None, eye_glow=0.0, tilt=0):
    bone = bone or ivory()
    eye_mat = glow("EyeGlow_%s" % name, eye, eye_glow) if eye else ink()
    parts = []
    # 머리통 · 광대 · 위턱
    parts.append(prim("sphere", name + "Cranium", bone, (x, y + 0.2 * s, z), (1.0 * s, 0.95 * s, 0.7 * s)))
    parts.append(prim("sphere", name + "Cheek", bone, (x, y - 0.32 * s, z + 0.05 * s), (0.78 * s, 0.5 * s, 0.6 * s)))
    parts.append(prim("cube", name + "Jaw", bone, (x, y - 0.78 * s, z), (0.62 * s, 0.34 * s, 0.45 * s), size=1, bevel=0.14 * s))
    # 눈구멍 (크고 깊게) · 코
    for side in (-1, 1):
        parts.append(prim("sphere", name + "Eye", eye_mat, (x + side * 0.38 * s, y - 0.02 * s, z + 0.5 * s), (0.3 * s, 0.33 * s, 0.2 * s)))
    nose = [(x, y - 0.3 * s), (x - 0.13 * s, y - 0.5 * s), (x + 0.13 * s, y - 0.5 * s)]
    parts.append(polygon_mesh(name + "Nose", nose, z + 0.62 * s, z + 0.66 * s, eye_mat))
    # 이빨
    parts.append(prim("cube", name + "Mouth", ink(), (x, y - 0.74 * s, z + 0.44 * s), (0.66 * s, 0.24 * s, 0.05 * s), size=1))
    for i in range(-2, 3):
        parts.append(prim("cube", name + "Tooth", bone, (x + i * 0.13 * s, y - 0.74 * s, z + 0.47 * s), (0.1 * s, 0.2 * s, 0.05 * s), size=1, bevel=0.02 * s))
    if tilt:
        pivot = Vector((x, y, z))
        for p in parts:
            offset = p.location - pivot
            a = math.radians(tilt)
            p.location = pivot + Vector((offset.x * math.cos(a) - offset.y * math.sin(a), offset.x * math.sin(a) + offset.y * math.cos(a), offset.z))
            p.rotation_euler.z += a
    return parts


def coin(name, x, y, z, r=0.42, tilt=(0, 0, 0)):
    tilt = (tilt[0] + 38, tilt[1], tilt[2])
    c = prim("cyl", name, gold(), (x, y, z), (1, 1, 1), tilt, radius=r, depth=0.14, bevel=0.03)
    rim = prim("torus", name + "Rim", pale_gold(), (x, y, z), (1, 1, 1), tilt, major=r * 0.78, minor=r * 0.06)
    rim.location = c.location + c.matrix_world.to_3x3() @ Vector((0, 0, 0.075))
    return c


def dagger(name, x, y, z, angle, length=3.0, blade=None):
    blade = blade or steel()
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)

    def at(t):
        return (x + ux * t, y + uy * t, z)

    prim("cone", name + "Blade", blade, at(length * 0.28), (0.26, 1, 0.08), (0, 0, angle - 90), vertices=4, r1=1, depth=length * 0.72, smooth=False)
    prim("cube", name + "Guard", gold(), at(-length * 0.1), (0.14, 0.9, 0.16), (0, 0, angle), size=1, bevel=0.04)
    prim("cyl", name + "Grip", principled("Leather", (0.25, 0.12, 0.06), rough=0.7), at(-length * 0.3), (0.13, 0.13, 1), (90, 0, angle - 90), radius=1, depth=length * 0.34)
    prim("sphere", name + "Pommel", gold(), at(-length * 0.5), (0.18, 0.18, 0.18))


def flame(name, x, y, z, s=1.0):
    """눈물방울 모양 불꽃 세 겹 (바깥 빨강 → 안쪽 노랑)"""
    layers = [((0.85, 0.12, 0.02), 1.6, 1.0), ((1.0, 0.42, 0.04), 2.2, 0.72), ((1.0, 0.78, 0.25), 2.8, 0.45)]
    for i, (c, strength, k) in enumerate(layers):
        mat = glow("Flame%d" % i, c, strength)
        prim("sphere", "%sBody%d" % (name, i), mat, (x, y - 0.35 * s * k, z + 0.12 * i), (0.9 * s * k, 0.9 * s * k, 0.25))
        prim("cone", "%sTip%d" % (name, i), mat, (x, y + 0.75 * s * k, z + 0.12 * i), (0.88 * s * k, 1.0, 0.25), (-90, 0, 0), r1=1, depth=2.1 * s * k)
        for side in (-1, 1):
            prim("cone", "%sLick%d" % (name, i), mat, (x + side * 0.55 * s * k, y + 0.2 * s * k, z + 0.12 * i), (0.35 * s * k, 1.0, 0.2), (-90, 0, side * -25), r1=1, depth=1.2 * s * k)


# --------------------------------------------------------------------------
# 카드마다 그림 (아치 창 가운데 = (0, 0.7))
# --------------------------------------------------------------------------
CY = 0.7
Z = 0.45


def art_gold():
    wood = principled("Wood", (0.3, 0.14, 0.05), rough=0.55)
    wood_dark = principled("WoodDark", (0.16, 0.07, 0.02), rough=0.6)
    tilt = 68  # 뚜껑이 살짝 보이게 앞으로 기울인다
    body = prim("cyl", "Barrel", wood, (0, CY + 0.3, Z), (1.0, 1.0, 1.0), (tilt, 0, 0), radius=1.05, depth=2.2, vertices=24, bevel=0.05)
    body.data.materials.append(wood_dark)
    for i, poly in enumerate(body.data.polygons):
        poly.material_index = 1 if (i % 2 == 0 and abs(poly.normal.z) < 0.5) else 0
    prim("cyl", "Lid", wood_dark, (0, CY + 0.3 + 1.03, Z + 0.43), (1, 1, 1), (tilt, 0, 0), radius=0.92, depth=0.06)
    for k in (-0.75, 0.0, 0.75):
        dy, dz = k * math.sin(math.radians(tilt)), k * math.cos(math.radians(tilt))
        prim("torus", "Hoop", gold(), (0, CY + 0.3 + dy, Z + dz), (1, 1, 1), (tilt, 0, 0), major=1.08, minor=0.07)
    for i, (x, y) in enumerate([(-1.3, CY - 1.3), (-0.55, CY - 1.55), (0.3, CY - 1.4), (1.15, CY - 1.55), (0.75, CY - 1.0), (-1.0, CY - 0.85)]):
        coin("Coin%d" % i, x, y, Z + 0.9 + i * 0.03, 0.42, (8 * (i % 3 - 1), 10 * ((i + 1) % 3 - 1), 0))
    for x, y in [(-1.6, CY + 1.6), (1.55, CY + 1.9), (1.8, CY + 0.6)]:
        star("Spark", 4, 0.28, 0.07, x, y, Z + 0.6, pale_gold())


def art_sleepy():
    moon = prim("cyl", "Moon", pale_gold(), (-0.2, CY + 0.2, Z), (1, 1, 1), radius=1.55, depth=0.35, bevel=0.06)
    cut = prim("cyl", "MoonCut", pale_gold(), (0.55, CY + 0.6, Z), (1, 1, 1), radius=1.3, depth=1.2)
    boolean(moon, cut)
    for i, (x, y, s) in enumerate([(0.75, CY + 0.9, 0.75), (1.35, CY + 1.65, 0.55), (1.75, CY + 2.2, 0.4)]):
        text("Z%d" % i, "Z", x, y, Z + 0.4, s, glow("SleepZ", (0.75, 0.85, 1.0), 2.5), depth=0.06)
    for x, y in [(-1.6, CY - 1.4), (1.4, CY - 1.1), (-1.8, CY + 1.8), (0.2, CY - 1.8)]:
        star("Star", 5, 0.22, 0.09, x, y, Z + 0.2, gold())


def art_storm():
    bolt = [(0.25, CY + 2.3), (-0.75, CY + 0.35), (-0.05, CY + 0.35), (-0.55, CY - 1.2), (0.95, CY + 0.95), (0.2, CY + 0.95), (0.8, CY + 2.3)]
    polygon_mesh("Bolt", bolt, Z + 0.3, Z + 0.55, glow("Bolt", (1.0, 0.86, 0.3), 5), bevel=0.04)
    sea = principled("Sea", (0.1, 0.45, 0.75), rough=0.25)
    foam = ivory()
    for row, (y, amp) in enumerate([(CY - 1.3, 0.28), (CY - 1.85, 0.24), (CY - 2.35, 0.2)]):
        pts = [(-2.1 + 4.2 * i / 40, y + amp * math.sin(i / 40 * math.pi * 4 + row), Z + 0.2) for i in range(41)]
        tube("Wave%d" % row, pts, 0.17 - row * 0.02, sea if row else foam)
    cloud = principled("Cloud", (0.16, 0.18, 0.24), rough=0.8)
    for x, y, sx in [(-1.05, CY + 1.95, 0.7), (-0.55, CY + 2.15, 0.55), (1.1, CY + 1.75, 0.65), (1.5, CY + 1.6, 0.45)]:
        prim("sphere", "Cloud", cloud, (x, y, Z - 0.1), (sx, sx * 0.55, 0.25))


def art_twins():
    skull("L", -0.8, CY + 0.2, Z, 0.95, tilt=10)
    skull("R", 0.85, CY + 0.35, Z + 0.3, 0.95, tilt=-10)
    for x, y in [(-1.7, CY + 2.0), (1.7, CY + 2.1), (0, CY - 1.9)]:
        star("Star", 4, 0.26, 0.06, x, y, Z + 0.4, gold())


def art_ghosts():
    hull = principled("Hull", (0.16, 0.2, 0.26), rough=0.6)
    sail = principled("Sail", (0.35, 0.62, 0.66), rough=0.6, emit=(0.3, 0.85, 0.9), emit_strength=0.35)
    hull_pts = [(-1.9, CY - 0.6), (1.9, CY - 0.6), (1.4, CY - 1.5), (-1.3, CY - 1.5)]
    polygon_mesh("Hull", hull_pts, Z, Z + 0.4, hull, bevel=0.06)
    for x, top in [(-0.8, 2.1), (0.55, 2.5)]:
        prim("cyl", "Mast", hull, (x, CY + (top - 0.6) / 2 - 0.3, Z + 0.2), (1, 1, 1), (90, 0, 0), radius=0.07, depth=top + 0.6)
        for k, (w, dy) in enumerate([(1.1, 1.55), (0.85, 0.55)]):
            pts = [(x - w / 2, CY + dy - 0.35), (x + w / 2, CY + dy - 0.35), (x + w / 2 + 0.15, CY + dy + 0.45), (x - w / 2 - 0.1, CY + dy + 0.45)]
            polygon_mesh("Sail", pts, Z + 0.25, Z + 0.33, sail, bevel=0.02)
    skull("Ghost", 1.25, CY + 1.55, Z + 0.4, 0.4, bone=principled("Spirit", (0.75, 0.95, 0.95), emit=(0.4, 0.9, 0.9), emit_strength=0.6))
    mist = principled("Mist", (0.4, 0.7, 0.75), emit=(0.3, 0.7, 0.75), emit_strength=0.25, alpha=0.55)
    for i in range(5):
        prim("sphere", "Mist", mist, (-1.7 + i * 0.85, CY - 1.7 + 0.08 * (i % 2), Z + 0.4), (0.55, 0.2, 0.1))


def art_hooks():
    pts = []
    for i in range(0, 31):
        t = i / 30
        if t < 0.45:
            pts.append((0.35, CY + 2.2 - t / 0.45 * 2.4, Z + 0.3))
        else:
            a = math.pi * (t - 0.45) / 0.55 * 1.25
            pts.append((0.35 - 0.95 + 0.95 * math.cos(a), CY - 0.2 - 0.95 * math.sin(a), Z + 0.3))
    tube("Hook", pts, 0.2, steel())
    prim("cone", "Point", steel(), (pts[-1][0] - 0.05, pts[-1][1] + 0.25, Z + 0.3), (0.2, 0.2, 1), (90, 0, 20), r1=1, depth=0.55)
    prim("torus", "Ring", gold(), (0.35, CY + 2.45, Z + 0.3), (1, 1, 1), (0, 0, 0), major=0.32, minor=0.08)
    for i in range(2):
        prim("torus", "Chain%d" % i, gold(), (0.35, CY + 2.9 + i * 0.3, Z + 0.1), (0.7, 1, 1), (0, 90 if i % 2 else 0, 0), major=0.15, minor=0.045)
    for x, y in [(-1.6, CY + 1.5), (1.6, CY - 1.3)]:
        star("Star", 4, 0.24, 0.06, x, y, Z + 0.3, gold())


def art_greed():
    gem = prim("ico", "Gem", principled("Gem", (0.15, 0.95, 0.75), metallic=0.2, rough=0.08, emit=(0.1, 0.8, 0.6), emit_strength=0.8), (0, CY + 0.5, Z + 0.4), (1.0, 1.25, 0.55), smooth=False, subdiv=1, radius=1.25)
    gem.rotation_euler.z = math.radians(18)
    for i, (x, y) in enumerate([(-1.5, CY - 1.2), (-0.7, CY - 1.6), (0.2, CY - 1.4), (1.05, CY - 1.65), (1.6, CY - 1.0), (-1.7, CY - 0.4)]):
        coin("Coin%d" % i, x, y, Z + 0.6 + i * 0.02, 0.4, (10 * (i % 2), -8 * ((i + 1) % 2), 0))
    for x, y in [(-1.5, CY + 1.9), (1.4, CY + 2.1), (1.9, CY + 0.9)]:
        star("Spark", 4, 0.3, 0.07, x, y, Z + 0.5, pale_gold())


def art_lucky():
    leaf = principled("Leaf", (0.2, 0.7, 0.28), rough=0.4)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        for side in (-1, 1):
            b = a + side * math.radians(22)
            prim("sphere", "Leaf", leaf, (math.cos(b) * 0.72, CY + 0.35 + math.sin(b) * 0.72, Z), (0.55, 0.55, 0.22))
    prim("sphere", "Heart", principled("LeafDark", (0.12, 0.45, 0.18), rough=0.5), (0, CY + 0.35, Z + 0.15), (0.3, 0.3, 0.2))
    tube("Stem", [(0, CY + 0.2, Z), (0.2, CY - 0.6, Z), (0.1, CY - 1.4, Z), (-0.3, CY - 2.0, Z)], 0.09, leaf)
    for x, y in [(-1.7, CY + 2.0), (1.7, CY + 1.9), (1.5, CY - 1.4), (-1.5, CY - 1.2)]:
        star("Star", 4, 0.24, 0.06, x, y, Z + 0.3, gold())


def art_blades():
    flame("Flame", 0, CY + 0.1, Z - 0.1, 1.05)
    dagger("A", 0.0, CY + 0.2, Z + 0.8, 55, 3.6)
    dagger("B", 0.0, CY + 0.2, Z + 0.95, 125, 3.6)


def art_brave():
    red = principled("TargetRed", (0.75, 0.1, 0.08), rough=0.4)
    for i, r in enumerate([1.8, 1.4, 1.0, 0.6, 0.25]):
        prim("cyl", "Ring%d" % i, red if i % 2 == 0 else ivory(), (0, CY + 0.2, Z + i * 0.05), (1, 1, 1), radius=r, depth=0.2, bevel=0.02)
    dagger("Stuck", 0.55, CY + 0.75, Z + 0.9, 125, 2.6)


def art_drift():
    purple = principled("Swirl", (0.55, 0.3, 0.95), rough=0.35, emit=(0.5, 0.25, 0.95), emit_strength=0.9)
    pts = []
    for i in range(160):
        t = i / 159
        a = t * math.pi * 5.2
        r = 0.12 + 1.75 * t
        pts.append((r * math.cos(a), CY + 0.2 + r * math.sin(a), Z + 0.1 + 0.3 * (1 - t)))
    tube("Spiral", pts, 0.1, purple)
    skull("Drift", 0, CY + 0.2, Z + 0.4, 0.42)
    for x, y in [(-1.7, CY + 2.1), (1.7, CY - 1.6), (1.6, CY + 2.0)]:
        star("Star", 4, 0.22, 0.06, x, y, Z + 0.3, gold())


def art_hurry():
    glass = principled("Glass", (0.85, 0.95, 1.0), rough=0.05, transmission=0.9, alpha=0.6)
    sand = principled("Sand", (0.95, 0.68, 0.3), rough=0.6)
    for sign in (-1, 1):
        prim("cone", "Bulb", glass, (0, CY + 0.2 + sign * 0.8, Z + 0.3), (1, 1, 1), (90 if sign > 0 else -90, 0, 0), r1=0.95, r2=0.08, depth=1.6)
        prim("cube", "Plate", gold(), (0, CY + 0.2 + sign * 1.72, Z + 0.3), (2.4, 0.26, 0.6), size=1, bevel=0.05)
    for side in (-1, 1):
        prim("cyl", "Post", gold(), (side * 1.05, CY + 0.2, Z + 0.3), (1, 1, 1), (90, 0, 0), radius=0.09, depth=3.3)
    prim("cone", "SandBottom", sand, (0, CY - 1.05, Z + 0.3), (1, 1, 0.5), (-90, 0, 0), r1=0.75, depth=0.55)
    prim("cone", "SandTop", sand, (0, CY + 0.55, Z + 0.3), (1, 1, 0.5), (90, 0, 0), r1=0.45, depth=0.6)
    prim("cyl", "Stream", sand, (0, CY - 0.25, Z + 0.3), (1, 1, 1), (90, 0, 0), radius=0.04, depth=1.0)


def art_calm():
    iron = principled("Iron", (0.55, 0.6, 0.66), metallic=1.0, rough=0.3)
    prim("cyl", "Shaft", iron, (0, CY + 0.35, Z), (1, 1, 1), (90, 0, 0), radius=0.16, depth=3.6)
    prim("torus", "Eye", gold(), (0, CY + 2.35, Z), major=0.36, minor=0.1)
    prim("cube", "Stock", gold(), (0, CY + 1.6, Z + 0.1), (1.9, 0.22, 0.3), size=1, bevel=0.06)
    pts = []
    for i in range(33):
        a = math.pi * (1.1 + 0.8 * i / 32)
        pts.append((1.45 * math.cos(a), CY - 0.35 + 1.45 * math.sin(a), Z))
    tube("Arm", pts, 0.16, iron)
    for side in (-1, 1):
        prim("cone", "Fluke", iron, (side * 1.4, CY - 0.55, Z), (0.35, 0.6, 0.35), (0, 0, -side * 35), vertices=4, r1=0.9, depth=0.8, smooth=False)
    tube("Rope", [(0.36 * math.cos(a), CY + 2.35 + 0.36 * math.sin(a), Z + 0.25) for a in [i * 0.5 for i in range(13)]] + [(0.9, CY + 1.0, Z + 0.3), (0.5, CY - 0.4, Z + 0.3), (-0.6, CY - 1.4, Z + 0.3)], 0.06, principled("Rope", (0.78, 0.62, 0.38), rough=0.8))


def art_back():
    purple = (0.42, 0.24, 0.7)
    star("Compass", 8, 2.1, 0.6, 0, CY - 0.2, Z, gold(), depth=0.12, rot=90)
    star("CompassInner", 8, 1.35, 0.45, 0, CY - 0.2, Z + 0.12, pale_gold(), depth=0.08, rot=112.5)
    ring_mesh("CompassRing", rounded_outline(3.0, 3.0, 1.49, 0, CY - 0.2, 12), rounded_outline(2.7, 2.7, 1.34, 0, CY - 0.2, 12), Z + 0.05, Z + 0.15, gold())
    skull("Emblem", 0, CY - 0.2, Z + 0.35, 0.55, eye=(0.8, 0.5, 1.0), eye_glow=4)
    for i in range(12):
        a = math.radians(i * 30)
        prim("sphere", "Dot", gold(), (math.cos(a) * 2.35, CY - 0.2 + math.sin(a) * 2.35, Z), (0.1, 0.1, 0.1))
    return purple


CARDS = [
    # id, 로마 숫자, 색 (GameConfig.FateCards 의 color 와 같은 느낌)
    ("gold", "I", (1.0, 0.78, 0.3), art_gold),
    ("sleepy", "II", (0.55, 0.72, 1.0), art_sleepy),
    ("storm", "III", (0.3, 0.6, 1.0), art_storm),
    ("twins", "IV", (1.0, 0.55, 0.25), art_twins),
    ("ghosts", "V", (0.75, 0.9, 1.0), art_ghosts),
    ("hooks", "VI", (0.45, 0.68, 1.0), art_hooks),
    ("greed", "VII", (0.3, 1.0, 0.8), art_greed),
    ("lucky", "VIII", (0.45, 0.9, 0.45), art_lucky),
    ("blades", "IX", (1.0, 0.42, 0.25), art_blades),
    ("brave", "X", (1.0, 0.6, 0.25), art_brave),
    ("drift", "XI", (0.75, 0.55, 1.0), art_drift),
    ("hurry", "XII", (1.0, 0.4, 0.35), art_hurry),
    ("calm", "XIII", (0.95, 0.88, 0.72), art_calm),
    ("back", "", (0.55, 0.35, 0.9), art_back),
]

# Roblox 가 이름 글자를 얹는 판 (카드 위에서부터의 비율). FateCardArt 모듈의 값과 같아야 한다
PLAQUE_CY = -3.55
PLAQUE_W, PLAQUE_H = 4.7, 1.05


def build_card(card_id, numeral, color, art):
    face = face_material(color)
    # 바탕
    polygon_mesh("Base", rounded_outline(W, H, 0.45), 0, 0.2, face, bevel=0.04)
    # 금테 두 겹
    ring_mesh("FrameOuter", rounded_outline(W - 0.16, H - 0.16, 0.4), rounded_outline(W - 0.56, H - 0.56, 0.24), 0.2, 0.34, gold(), bevel=0.04)
    ring_mesh("FrameInner", rounded_outline(W - 0.78, H - 0.78, 0.16), rounded_outline(W - 0.9, H - 0.9, 0.1), 0.2, 0.28, pale_gold(), bevel=0.015)
    for sx in (-1, 1):
        for sy in (-1, 1):
            star("Corner", 4, 0.3, 0.09, sx * (W / 2 - 0.62), sy * (H / 2 - 0.62), 0.28, gold(), depth=0.1, rot=45)
    # 아치 창 (빛살) + 금테
    bottom, spring, width = -2.75, 1.3, 4.5
    polygon_mesh("Window", arch_outline(width, bottom, spring), 0.2, 0.22, rays_material(color, CY + 0.3))
    ring_mesh("WindowFrame", arch_outline(width + 0.3, bottom - 0.15, spring), arch_outline(width, bottom, spring), 0.2, 0.36, gold(), bevel=0.03)
    # 위 : 로마 숫자 (뒷면은 별)
    if numeral:
        text("Numeral", numeral, 0, 4.18, 0.3, 1.0, gold(), depth=0.1)
        for sx in (-1, 1):
            polygon_mesh("NumeralLine", rounded_outline(0.8, 0.06, 0.029, sx * 1.6, 4.18, 3), 0.3, 0.34, gold())
            star("NumeralStar", 4, 0.13, 0.04, sx * 2.1, 4.18, 0.3, gold(), depth=0.06, rot=45)
    else:
        star("TopStar", 4, 0.45, 0.12, 0, 4.18, 0.3, gold(), depth=0.1)
    # 아래 : 이름 판 (Roblox 가 글자를 얹는다) · 뒷면은 장식
    if card_id != "back":
        polygon_mesh("Plaque", rounded_outline(PLAQUE_W, PLAQUE_H, 0.22, 0, PLAQUE_CY), 0.2, 0.26, principled("Plaque", tuple(c * 0.02 + 0.004 for c in color), rough=0.35))
        ring_mesh("PlaqueFrame", rounded_outline(PLAQUE_W + 0.2, PLAQUE_H + 0.2, 0.3, 0, PLAQUE_CY), rounded_outline(PLAQUE_W, PLAQUE_H, 0.22, 0, PLAQUE_CY), 0.2, 0.32, gold(), bevel=0.02)
        for sx in (-1, 1):
            star("PlaqueStar", 4, 0.2, 0.05, sx * (PLAQUE_W / 2 + 0.3), PLAQUE_CY, 0.28, gold(), depth=0.06, rot=45)
    else:
        for i in range(-2, 3):
            star("BackStar", 4, 0.22 if i == 0 else 0.14, 0.05, i * 0.75, PLAQUE_CY, 0.28, gold(), depth=0.06, rot=45)
    star("BottomGem", 4, 0.22, 0.12, 0, -4.4, 0.28, principled("Ruby", (0.8, 0.08, 0.12), metallic=0.3, rough=0.15), depth=0.12, rot=90)
    art()


def render_cards(only=None):
    out = os.path.join(HERE, "out", "cards")
    os.makedirs(out, exist_ok=True)
    for card_id, numeral, color, art in CARDS:
        if only and card_id not in only:
            continue
        _mats.clear()
        reset(300, 510, H + 0.02, samples=int(os.environ.get("SAMPLES", "96")))
        build_card(card_id, numeral, color, art)
        bpy.context.scene.render.filepath = os.path.join(out, card_id + ".png")
        bpy.ops.render.render(write_still=True)
        print("card", card_id)


# --------------------------------------------------------------------------
# 해적 종류 아이콘 (256 x 256, 가운데 (0,0) · 반지름 2 안쪽)
# --------------------------------------------------------------------------
def icon_normal():
    skull("N", 0, 0.1, 0, 1.45)


def icon_twin():
    skull("A", -0.75, 0.05, 0, 1.05, tilt=10)
    skull("B", 0.8, 0.2, 0.4, 1.05, tilt=-10, bone=principled("Bone2", (1.0, 0.86, 0.66), rough=0.42))


def icon_side():
    pts = []
    for i in range(31):
        t = i / 30
        if t < 0.4:
            pts.append((0.45, 1.45 - t / 0.4 * 1.9, 0.3))
        else:
            a = math.pi * (t - 0.4) / 0.6 * 1.25
            pts.append((0.45 - 0.9 + 0.9 * math.cos(a), -0.45 - 0.9 * math.sin(a), 0.3))
    tube("Hook", pts, 0.24, steel())
    prim("cone", "Point", steel(), (pts[-1][0] - 0.05, pts[-1][1] + 0.28, 0.3), (0.24, 0.24, 1), (90, 0, 20), r1=1, depth=0.6)
    prim("torus", "Ring", gold(), (0.45, 1.72, 0.3), major=0.28, minor=0.09)


def icon_skull():
    spirit = principled("Spirit", (0.62, 0.86, 0.92), rough=0.5, emit=(0.35, 0.8, 0.9), emit_strength=0.35)
    prim("sphere", "Head", spirit, (0, 0.55, 0), (1.25, 1.2, 0.6))
    pts = [(-1.25, 0.5), (1.25, 0.5), (1.25, -1.2), (0.8, -1.7), (0.4, -1.25), (0, -1.75), (-0.4, -1.25), (-0.8, -1.7), (-1.25, -1.2)]
    polygon_mesh("Sheet", pts, -0.3, 0.3, spirit, bevel=0.15)
    for side in (-1, 1):
        prim("sphere", "Eye", ink(), (side * 0.45, 0.55, 0.55), (0.25, 0.34, 0.12))
    prim("sphere", "Mouth", ink(), (0, -0.1, 0.5), (0.22, 0.28, 0.1))


def icon_mash():
    bag = principled("Bag", (0.36, 0.2, 0.08), rough=0.85)
    prim("sphere", "Bag", bag, (0, -0.35, 0), (1.45, 1.3, 0.7))
    prim("cone", "Neck", bag, (0, 0.95, 0), (1, 1, 1), (-90, 0, 0), r1=0.55, r2=0.28, depth=0.55)
    prim("torus", "Tie", gold(), (0, 0.85, 0), (1, 1, 0.6), (90, 0, 0), major=0.36, minor=0.09)
    prim("sphere", "Top", bag, (0, 1.35, 0), (0.5, 0.3, 0.35))
    coin("Coin", 0, -0.45, 0.75, 0.6)
    text("Dollar", "$", 0, -0.45, 0.86, 0.75, principled("Emboss", (0.55, 0.32, 0.06), metallic=1, rough=0.35), depth=0.04)
    for i, (x, y) in enumerate([(1.35, -1.35), (-1.4, -1.25)]):
        coin("Loose%d" % i, x, y, 0.4, 0.38, (15, 10, 0))


def icon_angry():
    skull("Angry", 0, 0.1, 0, 1.45, bone=principled("AngryBone", (0.78, 0.5, 0.42), rough=0.45), eye=(1.0, 0.06, 0.02), eye_glow=2.2)
    for side in (-1, 1):
        prim("cube", "Brow", principled("Brow", (0.35, 0.05, 0.04)), (side * 0.55, 0.62, 0.95), (0.62, 0.13, 0.1), (0, 0, side * -22), size=1, bevel=0.03)


def icon_lifebuoy():
    red = principled("BuoyRed", (0.85, 0.1, 0.08), rough=0.35)
    white = ivory()
    buoy = prim("torus", "Buoy", red, (0, 0, 0), major=1.3, minor=0.48, mseg=64, nseg=24)
    buoy.data.materials.append(white)
    for poly in buoy.data.polygons:
        center = poly.center
        a = math.degrees(math.atan2(center.y, center.x)) % 90
        poly.material_index = 1 if a < 45 else 0
    rope = principled("Rope", (0.8, 0.66, 0.42), rough=0.85)
    for i in range(4):
        a = math.radians(22.5 + i * 90)
        prim("torus", "Loop", rope, (math.cos(a) * 1.3, math.sin(a) * 1.3, 0.1), (1, 1, 1), (0, 90, math.degrees(a)), major=0.5, minor=0.05)


def icon_lock():
    body = principled("LockBody", (1.0, 0.72, 0.28), metallic=1.0, rough=0.28)
    prim("cube", "Body", body, (0, -0.45, 0), (2.3, 1.8, 0.6), size=1, bevel=0.2)
    pts = [(0.72 * math.cos(math.pi * i / 24), 0.45 + 0.1 + 0.9 * math.sin(math.pi * i / 24), 0) for i in range(25)]
    pts = [(-0.72, 0.4, 0)] + pts[::-1] + [(0.72, 0.4, 0)]
    pts = [(0.72, 0.4, 0)] + [(0.72 * math.cos(math.pi * i / 24), 0.55 + 0.9 * math.sin(math.pi * i / 24), 0) for i in range(25)] + [(-0.72, 0.4, 0)]
    tube("Shackle", pts, 0.2, steel())
    prim("cyl", "Keyhole", ink(), (0, -0.3, 0.32), (1, 1, 1), radius=0.2, depth=0.1)
    prim("cube", "KeySlot", ink(), (0, -0.62, 0.32), (0.14, 0.45, 0.1), size=1)


ICONS = [
    ("normal", icon_normal),
    ("twin", icon_twin),
    ("side", icon_side),
    ("skull", icon_skull),
    ("mash", icon_mash),
    ("angry", icon_angry),
    ("lifebuoy", icon_lifebuoy),
    ("lock", icon_lock),
]


def render_icons(only=None):
    out = os.path.join(HERE, "out", "icons")
    os.makedirs(out, exist_ok=True)
    for icon_id, build in ICONS:
        if only and icon_id not in only:
            continue
        _mats.clear()
        reset(256, 256, 4.6, samples=int(os.environ.get("SAMPLES", "96")))
        build()
        bpy.context.scene.render.filepath = os.path.join(out, icon_id + ".png")
        bpy.ops.render.render(write_still=True)
        print("icon", icon_id)


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "cards"
    only = sys.argv[2].split(",") if len(sys.argv) > 2 else None
    if mode == "cards":
        render_cards(only)
    elif mode == "icons":
        render_icons(only)
