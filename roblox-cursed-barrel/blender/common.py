"""Shared Blender helpers for the Cursed Barrel skin pack.

Everything is built in studs (1 Blender unit = 1 stud), Z-up.
Game pieces are exported untextured and split by colour slot (the game paints each slot per skin,
like the Phase 15 CB_ models). Procedural materials here are only for the shop thumbnails.
"""
import bpy
import bmesh
import math
import os
import json
from mathutils import Vector, Matrix, Euler, Quaternion

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT_DIR = os.path.join(ROOT, "export")
THUMB_DIR = os.path.join(ROOT, "thumbnails")
FX_DIR = os.path.join(ROOT, "fx")
for d in (EXPORT_DIR, THUMB_DIR, FX_DIR):
    os.makedirs(d, exist_ok=True)

TIERS = {
    1: dict(key="Common", ko="일반", hex="#9aa5b1"),
    2: dict(key="Rare", ko="레어", hex="#3fa7ff"),
    3: dict(key="Epic", ko="에픽", hex="#b266ff"),
    4: dict(key="Legendary", ko="전설", hex="#ffb020"),
    5: dict(key="Mythic", ko="신화", hex="#ff4f8b"),
}

QUICK = os.environ.get("SKIN_QUICK") == "1"


# ---------------------------------------------------------------- colors
def srgb_to_lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h, lin=True):
    h = h.lstrip("#")
    rgb = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(srgb_to_lin(v) for v in rgb) if lin else tuple(rgb)


def scale_col(c, k):
    return tuple(max(0.0, min(1.0, v * k)) for v in c)


# ---------------------------------------------------------------- scene
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.device = "CPU"
    s.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in s.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
    s.view_settings.look = "None"
    return s


def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o


def deselect_all():
    for o in bpy.context.view_layer.objects:
        o.select_set(False)


def activate(objs):
    deselect_all()
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


# ---------------------------------------------------------------- materials
def _new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    return m, nt, bsdf


def _coord(nt, scale=(1, 1, 1), kind="Object"):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = scale
    nt.links.new(tc.outputs[kind], mp.inputs["Vector"])
    return mp.outputs[0]


def _ramp(nt, stops, interp="LINEAR", name=None):
    r = nt.nodes.new("ShaderNodeValToRGB")
    if name:
        r.name = name
    cr = r.color_ramp
    cr.interpolation = interp
    while len(cr.elements) < len(stops):
        cr.elements.new(0.5)
    for el, (pos, col) in zip(cr.elements, stops):
        el.position = pos
        el.color = (*col, 1.0)
    return r


def _finish(m, bsdf, metallic, rough, emission=0.0, albedo=None, spec=0.5):
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission > 0 and albedo is not None:
        m.node_tree.links.new(albedo, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return m


def mat_flat(name, color, metallic=0.0, rough=0.5, emission=0.0):
    m, nt, bsdf = _new_mat(name)
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.name = "ALBEDO"
    rgb.outputs[0].default_value = (*color, 1)
    nt.links.new(rgb.outputs[0], bsdf.inputs["Base Color"])
    return _finish(m, bsdf, metallic, rough, emission, rgb.outputs[0])


def mat_noisy(name, color, var=0.25, scale=6.0, metallic=0.0, rough=0.5, emission=0.0, stretch=(1, 1, 1), detail=8.0):
    """Base color with organic variation (dirt, cloth fibres, brushed metal)."""
    m, nt, bsdf = _new_mat(name)
    co = _coord(nt, tuple(scale * s for s in stretch))
    tex = nt.nodes.new("ShaderNodeTexNoise")
    tex.inputs["Detail"].default_value = detail
    tex.inputs["Roughness"].default_value = 0.6
    nt.links.new(co, tex.inputs["Vector"])
    ramp = _ramp(nt, [(0.3, scale_col(color, 1 - var)), (0.7, scale_col(color, 1 + var * 0.7))], name="ALBEDO")
    nt.links.new(tex.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    return _finish(m, bsdf, metallic, rough, emission, ramp.outputs[0])


def mat_wood(name, light, dark, scale=2.5, rough=0.7, grain_axis="Z"):
    """Long grain streaks along one axis + fine pores."""
    m, nt, bsdf = _new_mat(name)
    st = {"Z": (1, 1, 0.06), "X": (0.06, 1, 1), "Y": (1, 0.06, 1)}[grain_axis]
    co = _coord(nt, tuple(scale * 4 * s for s in st))
    n1 = nt.nodes.new("ShaderNodeTexNoise")
    n1.inputs["Detail"].default_value = 10
    n1.inputs["Distortion"].default_value = 1.2
    nt.links.new(co, n1.inputs["Vector"])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = {"Z": "X", "X": "Y", "Y": "X"}[grain_axis]
    wave.inputs["Scale"].default_value = 3.0
    wave.inputs["Distortion"].default_value = 6.0
    wave.inputs["Detail"].default_value = 4
    co2 = _coord(nt, tuple(scale * s for s in st))
    nt.links.new(co2, wave.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMath")
    mix.operation = "MULTIPLY_ADD"
    nt.links.new(n1.outputs["Fac"], mix.inputs[0])
    mix.inputs[1].default_value = 0.6
    nt.links.new(wave.outputs["Fac"], mix.inputs[2])
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul.inputs[1].default_value = 0.62
    nt.links.new(mix.outputs[0], mul.inputs[0])
    ramp = _ramp(nt, [(0.18, dark), (0.55, light), (0.85, scale_col(light, 1.12))], name="ALBEDO")
    nt.links.new(mul.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    return _finish(m, bsdf, 0.0, rough, 0, ramp.outputs[0])


def mat_metal(name, color, rough=0.3, rust=0.0, rust_col="#7a3b17", scale=5.0):
    m, nt, bsdf = _new_mat(name)
    co = _coord(nt, (scale, scale, scale * 0.35))
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Detail"].default_value = 12
    nt.links.new(co, n.inputs["Vector"])
    base = _ramp(nt, [(0.35, scale_col(color, 0.78)), (0.65, scale_col(color, 1.08))])
    nt.links.new(n.outputs["Fac"], base.inputs[0])
    out_col = base.outputs[0]
    if rust > 0:
        co2 = _coord(nt, (scale * 1.6,) * 3)
        n2 = nt.nodes.new("ShaderNodeTexNoise")
        n2.inputs["Detail"].default_value = 14
        n2.inputs["Roughness"].default_value = 0.7
        nt.links.new(co2, n2.inputs["Vector"])
        mask = _ramp(nt, [(0.62 - rust * 0.25, (0, 0, 0)), (0.66 - rust * 0.25, (1, 1, 1))])
        nt.links.new(n2.outputs["Fac"], mask.inputs[0])
        rc = hexc(rust_col)
        rust_ramp = _ramp(nt, [(0.4, scale_col(rc, 0.6)), (0.7, scale_col(rc, 1.3))])
        nt.links.new(n.outputs["Fac"], rust_ramp.inputs[0])
        mixn = nt.nodes.new("ShaderNodeMix")
        mixn.data_type = "RGBA"
        nt.links.new(mask.outputs[0], mixn.inputs["Factor"])
        nt.links.new(base.outputs[0], mixn.inputs[6])
        nt.links.new(rust_ramp.outputs[0], mixn.inputs[7])
        out_col = mixn.outputs[2]
        nt.links.new(mask.outputs[0], bsdf.inputs["Roughness"])
    alb = nt.nodes.new("NodeReroute")
    alb.name = "ALBEDO"
    nt.links.new(out_col, alb.inputs[0])
    nt.links.new(alb.outputs[0], bsdf.inputs["Base Color"])
    return _finish(m, bsdf, 1.0 - rust * 0.6, rough, 0, None)


def mat_scales(name, color, edge, scale=22.0, rough=0.35, metallic=0.3):
    """Voronoi scales: bright centres, dark rims (dragon)."""
    m, nt, bsdf = _new_mat(name)
    co = _coord(nt, (scale, scale, scale * 0.7))
    v = nt.nodes.new("ShaderNodeTexVoronoi")
    v.feature = "DISTANCE_TO_EDGE"
    nt.links.new(co, v.inputs["Vector"])
    ramp = _ramp(nt, [(0.0, edge), (0.08, scale_col(color, 0.7)), (0.35, color), (0.6, scale_col(color, 1.2))], name="ALBEDO")
    nt.links.new(v.outputs["Distance"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    return _finish(m, bsdf, metallic, rough, 0, ramp.outputs[0])


def mat_stripes(name, a, b, count=10.0, axis="Z", rough=0.8):
    m, nt, bsdf = _new_mat(name)
    co = _coord(nt, (1, 1, 1))
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = axis
    wave.inputs["Scale"].default_value = count
    wave.inputs["Distortion"].default_value = 0.0
    wave.wave_profile = "SAW"
    nt.links.new(co, wave.inputs["Vector"])
    ramp = _ramp(nt, [(0.0, a), (0.5, b)], interp="CONSTANT", name="ALBEDO")
    nt.links.new(wave.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    return _finish(m, bsdf, 0.0, rough, 0, ramp.outputs[0])


def mat_glow(name, color, strength=6.0):
    m, nt, bsdf = _new_mat(name)
    rgb = nt.nodes.new("ShaderNodeRGB")
    rgb.name = "ALBEDO"
    rgb.outputs[0].default_value = (*color, 1)
    nt.links.new(rgb.outputs[0], bsdf.inputs["Base Color"])
    nt.links.new(rgb.outputs[0], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength
    bsdf.inputs["Roughness"].default_value = 0.3
    m["glow"] = True
    return m


def mat_ghost(name, color, alpha=0.55, strength=1.2):
    """Translucent spectral cloth (render only; Roblox side uses Transparency)."""
    m, nt, bsdf = _new_mat(name)
    co = _coord(nt, (3, 3, 1.2))
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Detail"].default_value = 6
    nt.links.new(co, n.inputs["Vector"])
    ramp = _ramp(nt, [(0.3, scale_col(color, 0.55)), (0.7, scale_col(color, 1.25))], name="ALBEDO")
    nt.links.new(n.outputs["Fac"], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    nt.links.new(ramp.outputs[0], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength
    bsdf.inputs["Alpha"].default_value = alpha
    bsdf.inputs["Roughness"].default_value = 0.5
    return m


def assign(o, m):
    o.data.materials.clear()
    o.data.materials.append(m)
    return o


# ---------------------------------------------------------------- mesh primitives
def _after_add(name, mat, bevel=0.0, bevel_segs=2, smooth=True):
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = bevel_segs
        mod.limit_method = "ANGLE"
    if smooth:
        bpy.ops.object.shade_smooth()
    if mat:
        assign(o, mat)
    return o


def cube(name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0, bevel_segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    bpy.context.active_object.scale = size
    o = _after_add(name, mat, bevel, bevel_segs, smooth=bevel > 0)
    return o


def cyl(name, r, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, r2=None, verts=24, bevel=0.0, cap="NGON"):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=depth,
                                    location=loc, rotation=rot, end_fill_type=cap)
    return _after_add(name, mat, bevel)


def sphere(name, r, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), mat=None, segs=24, rings=14):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=loc, rotation=rot)
    bpy.context.active_object.scale = scale
    return _after_add(name, mat)


def ico(name, r, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), mat=None, sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=loc, rotation=rot)
    bpy.context.active_object.scale = scale
    return _after_add(name, mat)


def torus(name, R, r, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, maj=32, mnr=10, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=maj, minor_segments=mnr,
                                     location=loc, rotation=rot)
    bpy.context.active_object.scale = scale
    return _after_add(name, mat)


def mesh_from_bm(name, bm, mat=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    link(o)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    if mat:
        assign(o, mat)
    return o


def lathe(name, profile, segs=32, mat=None, radial=None, cap_bottom=True, cap_top=True, loc=(0, 0, 0)):
    """Revolve [(r, z), ...] around Z. radial(theta, z) -> multiplier for radius (planks, flutes)."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segs):
            t = 2 * math.pi * i / segs
            k = radial(t, z) if radial else 1.0
            ring.append(bm.verts.new((loc[0] + r * k * math.cos(t), loc[1] + r * k * math.sin(t), loc[2] + z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom and profile[0][0] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(name, bm, mat)


def _frames(pts):
    """Parallel-transport frames along a polyline."""
    tans = []
    for i in range(len(pts)):
        a = pts[max(0, i - 1)]
        b = pts[min(len(pts) - 1, i + 1)]
        tans.append((b - a).normalized())
    up = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    n = tans[0].cross(up).normalized()
    frames = []
    for i, t in enumerate(tans):
        if i > 0:
            prev = tans[i - 1]
            axis = prev.cross(t)
            if axis.length > 1e-6:
                ang = prev.angle(t)
                n = (Quaternion(axis.normalized(), ang) @ n).normalized()
        b = t.cross(n).normalized()
        frames.append((t, n, b))
    return frames


def tube(name, pts, radii, segs=12, mat=None, cap=True, profile=None, twist=0.0):
    """Sweep a circle (or custom 2D profile [(x,y)] unit-sized) along points with per-point radius."""
    pts = [Vector(p) for p in pts]
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    frames = _frames(pts)
    bm = bmesh.new()
    rings = []
    prof = profile or [(math.cos(2 * math.pi * i / segs), math.sin(2 * math.pi * i / segs)) for i in range(segs)]
    for idx, (p, r, (t, n, b)) in enumerate(zip(pts, radii, frames)):
        ang = twist * idx / max(1, len(pts) - 1)
        ca, sa = math.cos(ang), math.sin(ang)
        ring = []
        for (x, y) in prof:
            xr, yr = x * ca - y * sa, x * sa + y * ca
            rr = r if not isinstance(r, tuple) else None
            if isinstance(r, tuple):
                ring.append(bm.verts.new(p + n * xr * r[0] + b * yr * r[1]))
            else:
                ring.append(bm.verts.new(p + n * xr * rr + b * yr * rr))
        rings.append(ring)
    k = len(prof)
    for a, c in zip(rings, rings[1:]):
        for i in range(k):
            j = (i + 1) % k
            bm.faces.new((a[i], a[j], c[j], c[i]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(name, bm, mat)


def spike(name, base, tip, r, mat=None, verts=8, bend=None):
    """Cone from base to tip; optional bend vector bows the middle (horns, claws, teeth)."""
    base, tip = Vector(base), Vector(tip)
    n = 6
    pts, radii = [], []
    for i in range(n + 1):
        t = i / n
        p = base.lerp(tip, t)
        if bend is not None:
            p += Vector(bend) * math.sin(math.pi * t) * 0.5 + Vector(bend) * t * t * 0.5
        pts.append(p)
        radii.append(max(0.002, r * (1 - t) ** 0.9))
    return tube(name, pts, radii, segs=verts, mat=mat)


def mirror_x(o):
    mod = o.modifiers.new("mirror", "MIRROR")
    mod.use_axis[0] = True
    mod.use_clip = False
    return o


def apply_mods(objs):
    for o in objs:
        if not o.modifiers:
            continue
        activate([o])
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)


def join(objs, name):
    objs = [o for o in objs if o is not None]
    apply_mods(objs)
    activate(objs)
    with bpy.context.temp_override(active_object=objs[0], selected_editable_objects=objs, selected_objects=objs):
        bpy.ops.object.join()
    o = objs[0]
    o.name = name
    o.data.name = name
    return o


def set_origin(o, point):
    """Move object origin to world point without moving geometry."""
    point = Vector(point)
    delta = point - o.matrix_world.translation
    o.data.transform(Matrix.Translation(-delta))
    o.matrix_world.translation = point


def bbox(objs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


def tri_count(objs):
    n = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        n += len(me.loop_triangles)
        o.evaluated_get(dg).to_mesh_clear()
    return n


# ---------------------------------------------------------------- export
def export_fbx(objs, path):
    apply_mods(objs)
    activate(objs)
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z", axis_up="Y", use_mesh_modifiers=True,
        mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True,
        add_leaf_bones=False, bake_anim=False,
    )


def roblox_vec(v):
    """Blender (x, y, z) Z-up -> Roblox (x, y, z) Y-up with the export axes above."""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


# ---------------------------------------------------------------- thumbnails
def _look_at(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def setup_render(samples=64, res=512):
    s = bpy.context.scene
    s.render.resolution_x = res
    s.render.resolution_y = res
    s.render.film_transparent = True
    s.cycles.samples = 16 if QUICK else samples
    s.cycles.use_denoising = True
    s.cycles.denoiser = "OPENIMAGEDENOISE"
    s.cycles.max_bounces = 6
    s.cycles.transparent_max_bounces = 16
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.05, 0.055, 0.07, 1)
    bg.inputs[1].default_value = 1.0
    s.world = w
    return s


def render_thumb(objs, path, tier, az=35.0, el=18.0, roll=0.0, margin=1.12, lens=60, target_offset=(0, 0, 0), fit=None):
    s = setup_render()
    lo, hi = bbox(fit or objs)
    c = (lo + hi) / 2 + Vector(target_offset)
    ext = hi - lo
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.lens = lens
    cam = link(bpy.data.objects.new("Cam", cam_data))
    fov = 2 * math.atan(cam_data.sensor_width / (2 * lens))
    a, e = math.radians(az), math.radians(el)
    dirv = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    # fit: project bbox corners onto the camera plane
    right = dirv.cross(Vector((0, 0, 1))).normalized() * -1
    up = right.cross(dirv).normalized() * -1
    rr = Quaternion(dirv, math.radians(roll))
    right, up = rr @ right, rr @ up
    half = 0.0
    for x in (lo.x, hi.x):
        for y in (lo.y, hi.y):
            for z in (lo.z, hi.z):
                p = Vector((x, y, z)) - c
                half = max(half, abs(p.dot(right)), abs(p.dot(up)))
    dist = half * margin / math.tan(fov / 2) + max(ext) * 0.2
    cam.location = c + dirv * dist
    _look_at(cam, c)
    if roll:
        cam.rotation_euler = (Quaternion(dirv, math.radians(roll)) @ cam.rotation_euler.to_quaternion()).to_euler()
    s.camera = cam
    tier_col = hexc(TIERS[tier]["hex"])
    size = max(ext)
    lights = []

    def area(name, loc, energy, col, sz):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.color = col
        ld.size = sz
        lo_ = link(bpy.data.objects.new(name, ld))
        lo_.location = loc
        _look_at(lo_, c)
        lights.append(lo_)

    k = dist * dist
    area("Key", c + Vector((math.sin(a - 0.9), -math.cos(a - 0.9), 0.9)) * dist, 38 * k, (1.0, 0.95, 0.88), size * 1.2)
    area("Fill", c + Vector((math.sin(a + 1.2), -math.cos(a + 1.2), 0.2)) * dist, 10 * k, (0.8, 0.88, 1.0), size * 1.5)
    area("Rim", c + Vector((-math.sin(a) * 0.9, math.cos(a) * 0.9, 0.6)) * dist, 60 * k, tier_col, size * 0.8)
    area("Top", c + Vector((0, 0, 1.2)) * dist, 12 * k, (1, 1, 1), size)
    s.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in lights + [cam]:
        bpy.data.objects.remove(o, do_unlink=True)
    return path


# ---------------------------------------------------------------- thumbnail FX dressing
def _fx_image(name):
    p = os.path.join(FX_DIR, name)
    return bpy.data.images.load(p, check_existing=True)


def fx_card_mat(name, img_name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = _fx_image(img_name)
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (*color, 1)
    em.inputs[1].default_value = strength
    mixc = nt.nodes.new("ShaderNodeMix")
    mixc.data_type = "RGBA"
    mixc.blend_type = "MULTIPLY"
    mixc.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mixc.inputs[6])
    mixc.inputs[7].default_value = (*color, 1)
    nt.links.new(mixc.outputs[2], em.inputs[0])
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(tex.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    return m


def scatter_cards(prefix, img_name, color, strength, count, center, radius, height, size, seed=1, face=None):
    """Camera-facing-ish textured quads (petals, sparkles) around an object for the thumbnail only."""
    import random
    rnd = random.Random(seed)
    m = fx_card_mat(prefix + "_M", img_name, color, strength)
    objs = []
    for i in range(count):
        ang = rnd.uniform(0, 2 * math.pi)
        rad = radius * math.sqrt(rnd.uniform(0.15, 1.0))
        z = rnd.uniform(-height / 2, height / 2)
        loc = Vector(center) + Vector((math.cos(ang) * rad, math.sin(ang) * rad, z))
        sz = size * rnd.uniform(0.6, 1.3)
        bpy.ops.mesh.primitive_plane_add(size=sz, location=loc,
                                         rotation=(math.radians(90 + rnd.uniform(-40, 40)), rnd.uniform(-0.6, 0.6),
                                                   rnd.uniform(0, 2 * math.pi) if face is None else face + rnd.uniform(-0.5, 0.5)))
        o = bpy.context.active_object
        o.name = f"{prefix}_{i}"
        assign(o, m)
        objs.append(o)
    return objs


def remove(objs):
    for o in objs:
        if o and o.name in bpy.data.objects:
            bpy.data.objects.remove(o, do_unlink=True)


# ---------------------------------------------------------------- lofting
def loft(name, rings, mat=None, cap_start=True, cap_end=True, smooth=True):
    """rings: list of lists of 3D points (equal length, closed loops). Consecutive rings are bridged."""
    bm = bmesh.new()
    vrings = [[bm.verts.new(Vector(p)) for p in ring] for ring in rings]
    k = len(rings[0])
    for a, b in zip(vrings, vrings[1:]):
        for i in range(k):
            j = (i + 1) % k
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_start:
        bm.faces.new(list(reversed(vrings[0])))
    if cap_end:
        bm.faces.new(vrings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mesh_from_bm(name, bm, mat, smooth)


def superellipse(w, d, n=2.6, segs=24):
    pts = []
    for i in range(segs):
        t = 2 * math.pi * i / segs
        c, s_ = math.cos(t), math.sin(t)
        x = (abs(c) ** (2 / n)) * (1 if c >= 0 else -1) * w / 2
        y = (abs(s_) ** (2 / n)) * (1 if s_ >= 0 else -1) * d / 2
        pts.append((x, y))
    return pts


def ring_at(profile, z, cx=0.0, cy=0.0):
    return [(cx + x, cy + y, z) for (x, y) in profile]


def smooth_by_angle(o, deg=35):
    activate([o])
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(deg))
    except Exception:
        bpy.ops.object.shade_smooth()


def subsurf(o, levels=1):
    m = o.modifiers.new("sub", "SUBSURF")
    m.levels = levels
    m.render_levels = levels
    return o


# ---------------------------------------------------------------- Roblox material look-alikes (thumbnails only)
def rgb(c):
    return tuple(srgb_to_lin(v / 255) for v in c)


def mat_roblox(name, color, material="SmoothPlastic", transparency=0.0):
    col = rgb(color)
    m = material or "SmoothPlastic"
    if m == "Neon":
        return mat_glow(name, col, 5.0)
    if m in ("Metal", "DiamondPlate", "Foil"):
        return mat_metal(name, col, rough=0.28)
    if m == "CorrodedMetal":
        return mat_metal(name, col, rough=0.5, rust=0.45)
    if m in ("Wood", "WoodPlanks"):
        return mat_wood(name, col, scale_col(col, 0.55))
    if m in ("Slate", "Basalt", "Rock", "Cobblestone", "Granite"):
        return mat_noisy(name, col, var=0.35, scale=9, rough=0.85)
    if m in ("Ice", "Glass"):
        mm = mat_noisy(name, col, var=0.1, scale=4, rough=0.08)
        b = mm.node_tree.nodes["Principled BSDF"]
        b.inputs["Transmission Weight"].default_value = 0.6
        b.inputs["IOR"].default_value = 1.31
        return mm
    if m in ("Fabric", "Carpet"):
        return mat_noisy(name, col, var=0.18, scale=40, rough=0.95, detail=4)
    if m == "Leather":
        return mat_noisy(name, col, var=0.2, scale=18, rough=0.55)
    if m == "Sand":
        return mat_noisy(name, col, var=0.22, scale=30, rough=0.9)
    if m in ("Plastic", "SmoothPlastic"):
        mm = mat_flat(name, col, rough=0.35 if m == "SmoothPlastic" else 0.5)
        if transparency > 0:
            b = mm.node_tree.nodes["Principled BSDF"]
            b.inputs["Alpha"].default_value = 1 - transparency
        return mm
    return mat_flat(name, col, rough=0.5)


def lerp_rgb(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def roblox_size(v):
    return [round(abs(v[0]), 4), round(abs(v[2]), 4), round(abs(v[1]), 4)]


def vbox(o):
    """Exact world-space bounds from vertices."""
    mw = o.matrix_world
    xs = [mw @ v.co for v in o.data.vertices]
    lo = Vector((min(p.x for p in xs), min(p.y for p in xs), min(p.z for p in xs)))
    hi = Vector((max(p.x for p in xs), max(p.y for p in xs), max(p.z for p in xs)))
    return lo, hi
