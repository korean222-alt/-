"""WILDHOLD 숲 키트: 사실적인 가문비나무, 고사목, 바위, 쓰러진 통나무, 그루터기, 고사리.

동글동글한 파트 나무 대신 쓰는 메쉬 에셋이다. 모두 한 FBX(EnvModels.fbx)에 담아서
Studio 에서 한 번 가져오기 → ReplicatedStorage 로 옮기면 맵이 이 모델들로 바뀐다.

  python3 blender/env_kit.py            # 전부 만들기
  python3 blender/env_kit.py --render   # + docs/images/env_kit.png 단체 사진

좌표: Blender 미터 단위, Z 위, 원점 = 바닥 가운데. (Roblox 코드가 종류별 높이로 다시 맞춘다)
색은 절차적 셰이더(나무껍질 틈, 솔잎 결, 이끼, 지의류)를 텍스처 한 장으로 굽고 AO 를 곱한다.
"""
from __future__ import annotations

import math
import os
import sys

import bpy
import imageio.v3 as iio
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import sdf  # noqa: E402
from creature_lib import linear_to_srgb, reset, select_only, srgb_to_linear, triangle_count  # noqa: E402

OUT = os.path.join(ROOT, "assets", "env")


# ================================================================ 메쉬 조립

class MeshBuilder:
    """정점·면·정점 속성을 모아서 한 오브젝트로 만든다."""

    def __init__(self, attrs=("leaf", "tip", "cut", "rand")):  # cut: 잘린 단면 / 솔잎 아랫면
        self.verts, self.faces = [], []
        self.attr_names = attrs
        self.attrs = {a: [] for a in attrs}
        self.count = 0

    def add(self, verts, faces, **values):
        verts = np.asarray(verts, float)
        n = len(verts)
        self.verts.append(verts)
        self.faces.extend([tuple(int(i) + self.count for i in f) for f in faces])
        for a in self.attr_names:
            v = values.get(a, 0.0)
            self.attrs[a].append(np.broadcast_to(np.asarray(v, float), (n,)).copy())
        self.count += n

    def build(self, name):
        verts = np.concatenate(self.verts)
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(verts.tolist(), [], self.faces)
        mesh.validate()
        mesh.update()
        for a in self.attr_names:
            data = np.concatenate(self.attrs[a]).astype(np.float32)
            attr = mesh.attributes.new(a, "FLOAT", "POINT")
            attr.data.foreach_set("value", data)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        for poly in mesh.polygons:
            poly.use_smooth = True
        return obj


def unit(v):
    v = np.asarray(v, float)
    return v / max(np.linalg.norm(v), 1e-9)


def frames(points):
    """폴리라인을 따라 비틀림 없는 좌표계 (접선, 법선, 종법선)."""
    pts = np.asarray(points, float)
    tang = np.gradient(pts, axis=0)
    tang = tang / np.linalg.norm(tang, axis=1, keepdims=True)
    ref = np.array([0.0, 0.0, 1.0]) if abs(tang[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    n = unit(np.cross(tang[0], ref))
    normals, binormals = [], []
    for t in tang:
        n = unit(n - t * (n @ t))
        normals.append(n)
        binormals.append(np.cross(t, n))
    return tang, np.array(normals), np.array(binormals)


def tube(mb, points, radii, sides=8, rng=None, bumps=0.0, tip=True, base_cap=False, **attrs):
    """점들을 따라 원을 쓸어 만든 관 (줄기, 가지, 뿌리). radii 는 점마다 반지름."""
    pts = np.asarray(points, float)
    _, nrm, bnr = frames(pts)
    verts, faces = [], []
    ring = len(pts) - (1 if tip else 0)
    ang = np.linspace(0, 2 * math.pi, sides, endpoint=False)
    along = np.linspace(0, 1, len(pts))
    per_vertex = {k: [] for k in attrs}
    for i in range(ring):
        wob = 1.0 + (rng.uniform(-bumps, bumps, sides) if (rng is not None and bumps) else 0.0)
        for j, a in enumerate(ang):
            r = radii[i] * (wob[j] if np.ndim(wob) else wob)
            verts.append(pts[i] + r * (math.cos(a) * nrm[i] + math.sin(a) * bnr[i]))
    for i in range(ring - 1):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    if tip:
        verts.append(pts[-1])
        t = len(verts) - 1
        last = (ring - 1) * sides
        for j in range(sides):
            faces.append((last + j, last + (j + 1) % sides, t))
    if base_cap:
        verts.append(pts[0])
        c = len(verts) - 1
        for j in range(sides):
            faces.append(((j + 1) % sides, j, c))
    idx = np.repeat(np.arange(ring), sides).tolist() + ([len(pts) - 1] if tip else []) + ([0] if base_cap else [])
    values = {}
    for k, v in attrs.items():
        values[k] = np.asarray(v(along[idx]) if callable(v) else v, float)
    values.setdefault("tip", along[idx])
    mb.add(verts, faces, **values)


# ================================================================ 셰이더 (굽기용)

class Nodes:
    """짧게 쓰는 셰이더 노드 도우미. 값은 선형 색 (sRGB hex 를 넣으면 변환)."""

    def __init__(self, mat):
        self.nt = mat.node_tree
        self.nt.nodes.clear()

    def new(self, kind, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            setattr(n, k, v)
        return n

    def link(self, a, b):
        self.nt.links.new(a, b)

    def attr(self, name):
        return self.new("ShaderNodeAttribute", attribute_type="GEOMETRY", attribute_name=name).outputs["Fac"]

    def obj(self, scale=(1, 1, 1)):
        tc = self.new("ShaderNodeTexCoord")
        m = self.new("ShaderNodeMapping")
        m.inputs["Scale"].default_value = scale
        self.link(tc.outputs["Object"], m.inputs["Vector"])
        return m.outputs["Vector"]

    def noise(self, vec, scale, detail=4.0, rough=0.55, distort=0.0):
        n = self.new("ShaderNodeTexNoise")
        self.link(vec, n.inputs["Vector"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distort
        return n.outputs["Fac"]

    def voronoi(self, vec, scale, feature="F1", out="Distance", rand=1.0):
        n = self.new("ShaderNodeTexVoronoi", feature=feature)
        self.link(vec, n.inputs["Vector"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = rand
        return n.outputs[out]

    def ramp(self, value, lo, hi, a=0.0, b=1.0):
        n = self.new("ShaderNodeMapRange", clamp=True)
        self.link(value, n.inputs["Value"])
        n.inputs["From Min"].default_value, n.inputs["From Max"].default_value = lo, hi
        n.inputs["To Min"].default_value, n.inputs["To Max"].default_value = a, b
        return n.outputs["Result"]

    def math(self, op, a, b=0.0):
        n = self.new("ShaderNodeMath", operation=op)
        for i, v in enumerate((a, b)):
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                self.link(v, n.inputs[i])
        return n.outputs[0]

    def color(self, hexcol):
        rgb = srgb_to_linear(sdf.hex_rgb(hexcol))
        n = self.new("ShaderNodeRGB")
        n.outputs[0].default_value = (*rgb, 1.0)
        return n.outputs[0]

    def mix(self, fac, a, b, blend="MIX"):
        n = self.new("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        n.clamp_factor = True
        for sock, v in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
            if isinstance(v, (int, float)):
                sock.default_value = v
            elif isinstance(v, str):
                self.link(self.color(v), sock)
            else:
                self.link(v, sock)
        return n.outputs[2]

    def normal_z(self):
        g = self.new("ShaderNodeNewGeometry")
        s = self.new("ShaderNodeSeparateXYZ")
        self.link(g.outputs["Normal"], s.inputs["Vector"])
        return s.outputs["Z"]

    def pos(self, axis):
        tc = self.new("ShaderNodeTexCoord")
        s = self.new("ShaderNodeSeparateXYZ")
        self.link(tc.outputs["Object"], s.inputs["Vector"])
        return s.outputs[axis]

    def emit(self, col):
        e = self.new("ShaderNodeEmission")
        out = self.new("ShaderNodeOutputMaterial")
        self.link(col, e.inputs["Color"])
        self.link(e.outputs["Emission"], out.inputs["Surface"])


def bark_color(N, dark="#2a221c", mid="#4d4036", light="#6e6256", stretch=0.18, moss=0.0, lichen=0.35):
    """나무껍질: 세로로 길쭉한 비늘 판 + 판 사이 깊은 틈 + 섬유 결, 회색 지의류, 아래쪽 이끼."""
    v = N.obj((1.0, 1.0, stretch))
    plates = N.voronoi(v, 16.0, feature="DISTANCE_TO_EDGE", rand=0.9)
    fissure = N.math("MULTIPLY", N.ramp(plates, 0.0, 0.06), N.ramp(N.noise(N.obj((1, 1, 0.3)), 8.0, 3.0), 0.2, 0.55, 0.55, 1.0))
    fibre = N.noise(N.obj((1.0, 1.0, 0.08)), 60.0, 3.0, 0.5)
    base = N.mix(fibre, mid, light)
    base = N.mix(N.ramp(N.noise(v, 2.5, 3.0), 0.3, 0.7), N.mix(0.5, dark, mid), base)
    col = N.mix(fissure, dark, base)
    if lichen > 0:
        spots = N.ramp(N.noise(N.obj(), 9.0, 6.0, 0.75), 0.62, 0.67, 0.0, lichen)
        col = N.mix(spots, col, "#8a8f7c")
    if moss > 0:
        low = N.ramp(N.pos("Z"), 0.0, 1.6, moss, 0.0)
        patch = N.ramp(N.noise(N.obj(), 4.0, 5.0, 0.65), 0.4, 0.55)
        col = N.mix(N.math("MULTIPLY", low, patch), col, "#3a4a26")
    return col


def cut_wood(N, center_xy=True):
    """잘린 단면: 나이테 + 가운데가 더 짙은 심재."""
    v = N.obj()
    x, y = N.pos("X"), N.pos("Y")
    r = N.math("SQRT", N.math("ADD", N.math("MULTIPLY", x, x), N.math("MULTIPLY", y, y)))
    rings = N.math("SINE", N.math("MULTIPLY", N.math("ADD", r, N.math("MULTIPLY", N.noise(v, 6.0), 0.04)), 90.0))
    ringf = N.ramp(rings, -1.0, 1.0)
    col = N.mix(ringf, "#8c6b49", "#b89468")
    heart = N.ramp(r, 0.05, 0.25)
    col = N.mix(heart, "#6d4f35", col)
    rot = N.ramp(N.noise(v, 5.0, 4.0), 0.55, 0.7)
    return N.mix(rot, col, "#5a4633")


def needle_color(N):
    """솔잎: 짙은 초록 바탕 + 가는 솔잎 결 + 가지 끝의 밝은 새순."""
    v = N.obj()
    streak = N.noise(N.obj((1.0, 1.0, 1.0)), 160.0, 2.0, 0.5)
    clump = N.noise(v, 9.0, 4.0, 0.6)
    base = N.mix(clump, "#16261b", "#2c4430")
    base = N.mix(N.ramp(streak, 0.3, 0.7), N.mix(0.5, base, "#0d170f"), base)
    tip = N.ramp(N.attr("tip"), 0.72, 1.0)
    fresh = N.mix(N.attr("rand"), "#44603a", "#56703f")
    col = N.mix(N.math("MULTIPLY", tip, 0.8), base, fresh)
    # 가지마다 살짝 다른 색 (죽은 가지 몇 개는 갈색)
    brown = N.ramp(N.attr("rand"), 0.94, 0.98)
    col = N.mix(N.math("MULTIPLY", brown, tip), col, "#5b4a33")
    # 아랫면은 그늘진 짙은 색
    return N.mix(N.math("MULTIPLY", N.attr("cut"), 0.7), col, "#0b130d")


def rock_color(N, moss=0.8):
    v = N.obj()
    tone = N.noise(v, 1.6, 5.0, 0.6)
    fine = N.noise(v, 34.0, 6.0, 0.75)
    base = N.mix(tone, "#434645", "#6c6d68")
    base = N.mix(fine, N.mix(0.55, base, "#393c3f"), base)
    wave = N.new("ShaderNodeTexWave", wave_type="BANDS", bands_direction="Z")
    N.link(v, wave.inputs["Vector"])
    wave.inputs["Scale"].default_value, wave.inputs["Distortion"].default_value = 2.2, 6.0
    wave.inputs["Detail"].default_value = 3.0
    base = N.mix(N.math("MULTIPLY", N.ramp(wave.outputs["Fac"], 0.75, 1.0), 0.12), base, "#6f6d66")  # 옅은 퇴적 줄무늬
    base = N.mix(N.ramp(N.noise(v, 0.9, 2.0), 0.45, 0.7), base, "#5f5647")  # 누르스름한 얼룩
    cracks = N.voronoi(N.obj((1, 1, 1.6)), 2.0, feature="DISTANCE_TO_EDGE")
    crack = N.math("MULTIPLY", N.ramp(cracks, 0.012, 0.0), N.ramp(N.noise(v, 2.0, 3.0), 0.5, 0.62))
    col = N.mix(crack, base, "#232527")
    lichen = N.ramp(N.noise(v, 12.0, 6.0, 0.8), 0.6, 0.68, 0.0, 0.8)
    col = N.mix(lichen, col, "#9fa18a")
    top = N.ramp(N.normal_z(), 0.2, 0.65)
    patch = N.ramp(N.noise(v, 2.6, 6.0, 0.72), 0.36, 0.46)
    mossf = N.math("MULTIPLY", N.math("MULTIPLY", top, patch), moss)
    mossc = N.mix(N.noise(v, 28.0), "#2f3d1c", "#4a5a28")
    col = N.mix(mossf, col, mossc)
    dirt = N.ramp(N.pos("Z"), 0.0, 0.2, 0.75, 0.0)
    return N.mix(dirt, col, "#352b22")


def fern_color(N):
    v = N.obj()
    base = N.mix(N.noise(v, 14.0, 3.0), "#1d3018", "#324825")
    tip = N.ramp(N.attr("tip"), 0.7, 1.0)
    col = N.mix(tip, base, "#4a5c30")
    dry = N.ramp(N.attr("rand"), 0.82, 0.88)
    return N.mix(N.math("MULTIPLY", dry, tip), col, "#7a6a3a")


# ================================================================ 굽기

def bake(obj, color_fn, size, out_png, ao_strength=0.7, ao_distance=0.6, samples=32):
    scene = bpy.context.scene
    select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, scale_to_bounds=True)
    bpy.ops.object.mode_set(mode="OBJECT")

    mat = bpy.data.materials.new(obj.name + "_bake")
    mat.use_nodes = True
    N = Nodes(mat)
    N.emit(color_fn(N))
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    tex = N.new("ShaderNodeTexImage")
    color_img = bpy.data.images.new(obj.name + "_col", size, size, float_buffer=True, alpha=False)
    ao_img = bpy.data.images.new(obj.name + "_ao", size, size, float_buffer=True, alpha=False)

    def target(img):
        tex.image = img
        for n in N.nt.nodes:
            n.select = False
        tex.select = True
        N.nt.nodes.active = tex

    scene.render.bake.margin = 6
    scene.render.bake.margin_type = "EXTEND"
    scene.render.bake.use_selected_to_active = False
    target(color_img)
    scene.cycles.samples = 2
    bpy.ops.object.bake(type="EMIT")
    target(ao_img)
    scene.world.light_settings.distance = ao_distance
    scene.cycles.samples = samples
    bpy.ops.object.bake(type="AO")

    px = np.array(color_img.pixels[:], dtype=np.float32).reshape(size, size, 4)[:, :, :3]
    ao = np.array(ao_img.pixels[:], dtype=np.float32).reshape(size, size, 4)[:, :, :1]
    shaded = px * (1.0 - ao_strength + ao_strength * np.clip(ao, 0, 1) ** 0.9)
    srgb = (linear_to_srgb(shaded) * 255 + 0.5).astype(np.uint8)
    iio.imwrite(out_png, np.flipud(srgb))

    # 내보낼 재질: 구운 텍스처 한 장
    final = bpy.data.materials.new(obj.name)
    final.use_nodes = True
    nt = final.node_tree
    nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.85
    img_node = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(out_png)
    img_node.image = img
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(img_node.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    obj.data.materials.clear()
    obj.data.materials.append(final)
    for a in list(obj.data.attributes):
        if a.name in ("leaf", "tip", "cut", "rand"):
            obj.data.attributes.remove(a)


def combined_color(bark=None, leaf=None, cut=None):
    """leaf / cut 속성으로 재질을 나눠 칠한다 (한 텍스처에 같이 굽기)."""

    def fn(N):
        col = bark(N)
        if leaf is not None:
            col = N.mix(N.attr("leaf"), col, leaf(N))
        if cut is not None:
            col = N.mix(N.ramp(N.attr("cut"), 0.5, 0.51), col, cut(N))
        return col

    return fn


# ================================================================ 가문비나무

def skirt(mb, z, R, rng, var, teeth=10, r_in=0.25, lift=0.35, droop=0.5, thick=0.7):
    """가지 한 층: 줄기에서 퍼져 나가며 아래로 처지는 우산 모양. 닫힌 부피라 어느 쪽에서 봐도 안 뚫린다.
    가장자리는 이빨마다 [틈, 어깨, 끝, 어깨] 네 점으로 들쭉날쭉하게 — 길이·처짐이 제각각인 가지 끝.
    층 전체를 조금 기울이고 옮겨서 나무가 반듯한 크리스마스트리처럼 보이지 않게 한다."""
    n = teeth * 4
    ang = rng.uniform(0, 2 * math.pi) + np.arange(n) / n * 2 * math.pi + rng.uniform(-0.3, 0.3, n) * (math.pi / n)
    kind = np.arange(n) % 4                                  # 0 틈, 1 어깨, 2 끝, 3 어깨
    tip_len = np.repeat(rng.uniform(0.8, 1.35, teeth), 4)    # 이빨(가지)마다 길이가 다르다
    gap = np.repeat(rng.random(teeth) < 0.1, 4)              # 가끔 가지가 빠진 자리
    rim_r = R * np.select([kind == 0, kind == 2], [rng.uniform(0.48, 0.62, n), tip_len], rng.uniform(0.7, 0.88, n) * tip_len)
    rim_r = np.where(gap & (kind != 0), rim_r * 0.62, rim_r)
    rim_drop = droop * R * np.select([kind == 0, kind == 2], [rng.uniform(0.4, 0.55, n), rng.uniform(0.95, 1.4, n) * tip_len],
                                     rng.uniform(0.7, 1.0, n))
    bump = rng.uniform(-1, 1, n)
    cos, sin = np.cos(ang), np.sin(ang)
    loops, tips, under = [], [], []
    for f in (0.0, 0.55, 1.0):                               # 윗면: 안 → 밖
        rr = r_in + (rim_r - r_in) * f
        zz = z + lift * (1 - f) ** 1.4 - rim_drop * f ** 1.7 + (0.12 * R * bump if f == 0.55 else 0)
        loops.append(np.column_stack([rr * cos, rr * sin, zz]))
        tips.append(np.full(n, f) * np.where(kind == 2, 1.0, 0.85))
        under.append(np.zeros(n))
    rr = r_in * 0.7                                           # 아랫면: 가장자리에서 줄기 아래로
    zz = z - thick
    loops.append(np.column_stack([rr * cos, rr * sin, np.full(n, zz)]))
    tips.append(np.zeros(n))
    under.append(np.ones(n))
    verts = np.concatenate(loops)
    # 층 기울기 + 중심 흔들기
    tilt = rng.uniform(-0.12, 0.12, 2)
    shift = rng.uniform(-0.08, 0.08, 2) * R
    c = verts - [0, 0, z]
    verts[:, 2] += c[:, 0] * tilt[0] + c[:, 1] * tilt[1]
    verts[:, 0] += shift[0] * (np.hypot(c[:, 0], c[:, 1]) / R)
    verts[:, 1] += shift[1] * (np.hypot(c[:, 0], c[:, 1]) / R)
    L = len(loops)
    faces = []
    for k in range(L):
        k2 = (k + 1) % L
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((k * n + j, k2 * n + j, k2 * n + j2, k * n + j2))
    mb.add(verts, faces, leaf=1.0, tip=np.concatenate(tips), cut=np.concatenate(under), rand=var)


def spruce(name, seed, height=14.0, crown=0.2, bare=0.14, tiers=13, dead_twigs=9, far=False):
    """far=True: 숲 뒷줄용 가벼운 버전 (층·이빨 수를 줄이고 뿌리·잔가지 없음)."""
    rng = np.random.default_rng(seed)
    mb = MeshBuilder()
    if far:
        tiers, dead_twigs = 8, 0
    # 줄기: 아래 뿌리 쪽이 넓게 퍼지고 위로 갈수록 가늘어진다
    zs = np.linspace(0, height * 0.99, 12)
    lean = rng.uniform(-0.15, 0.15, 2)
    pts = np.column_stack([lean[0] * (zs / height) ** 2, lean[1] * (zs / height) ** 2, zs])
    radii = 0.34 * (1 - zs / height) ** 1.15 + 0.025
    radii[0] *= 1.45
    radii[1] *= 1.15
    tube(mb, pts, radii, sides=6 if far else 9, rng=rng, bumps=0.06, leaf=0.0, rand=0.0)
    for k in range(0 if far else 5):
        a = k / 5 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        dvec = np.array([math.cos(a), math.sin(a), 0])
        tube(mb, [np.array([0, 0, 0.5]), dvec * 0.45 + [0, 0, 0.15], dvec * 0.95 + [0, 0, -0.12]], [0.16, 0.12, 0.05],
             sides=5, rng=rng, bumps=0.1, leaf=0.0)
    trunk_r = lambda z: np.interp(z, zs, radii)  # noqa: E731
    trunk_xy = lambda z: np.array([np.interp(z, zs, pts[:, 0]), np.interp(z, zs, pts[:, 1]), 0])  # noqa: E731
    # 아래쪽 마른 잔가지 (숲속 가문비나무의 특징)
    for _ in range(dead_twigs):
        z = rng.uniform(height * 0.04, height * (bare + 0.12))
        a = rng.uniform(0, 2 * math.pi)
        dvec = np.array([math.cos(a), math.sin(a), 0])
        L = rng.uniform(0.6, 1.6)
        base = np.array([0, 0, z]) + dvec * trunk_r(z) * 0.6
        tube(mb, [base, base + dvec * L * 0.5 + [0, 0, -0.1 * L], base + dvec * L + [0, 0, -0.3 * L]], [0.05, 0.03, 0.01], sides=4, leaf=0.0)
    # 가지 층: 간격·크기가 조금씩 불규칙하다
    z0, top = height * bare, height * 0.9
    for k in range(tiers):
        t = k / (tiers - 1)
        z = z0 + (top - z0) * (1 - (1 - t) ** 1.2) + rng.uniform(-0.18, 0.18)
        R = (crown * height * (1 - t) ** 0.95 + 0.45) * rng.uniform(0.85, 1.12)
        m0 = len(mb.verts)
        skirt(mb, z, R, rng, rng.random(), teeth=int(round((10 - 4 * t) * (0.6 if far else 1.0))), r_in=trunk_r(z) * 0.8 + 0.05,
              lift=0.3 + 0.35 * t, droop=rng.uniform(0.45, 0.62) - 0.2 * t, thick=0.5 + 0.4 * (1 - t))
        mb.verts[m0] = mb.verts[m0] + trunk_xy(z)
    # 꼭대기 새순
    tube(mb, [np.array([0, 0, top - 0.5]) + trunk_xy(top), np.array([0, 0, height * 1.03]) + trunk_xy(height)], [0.22, 0.0],
         sides=6, leaf=1.0, tip=1.0, rand=0.3)
    obj = mb.build(name)
    return obj, combined_color(bark=lambda N: bark_color(N, moss=0.6), leaf=needle_color), 1024, 1.2


# ================================================================ 고사목

def dead_tree(name, seed, height=10.0):
    rng = np.random.default_rng(seed)
    mb = MeshBuilder()
    zs = np.linspace(0, height, 12)
    bend = rng.uniform(-0.6, 0.6, 2)
    pts = np.column_stack([bend[0] * (zs / height) ** 2, bend[1] * (zs / height) ** 2, zs])
    radii = 0.3 * (1 - zs / height) ** 0.9 + 0.04
    radii[0] *= 1.5
    # 꺾인 꼭대기: 마지막 점을 옆으로 비틀어 부러진 모양
    pts[-1] += [rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), -0.4]
    radii[-1] = 0.09
    tube(mb, pts, radii, sides=9, rng=rng, bumps=0.12, tip=True, leaf=0.0)
    for k in range(4):
        a = k / 4 * 2 * math.pi + rng.uniform(-0.4, 0.4)
        dvec = np.array([math.cos(a), math.sin(a), 0])
        tube(mb, [np.array([0, 0, 0.6]), dvec * 0.5 + [0, 0, 0.12], dvec * 1.1 + [0, 0, -0.15]], [0.2, 0.13, 0.05], sides=6, rng=rng, bumps=0.1)

    def branch(start, direction, length, radius, depth):
        n = 5
        pts = [start]
        d = unit(direction)
        for i in range(1, n):
            d = unit(d + rng.normal(0, 0.28, 3) + [0, 0, 0.12])
            pts.append(pts[-1] + d * length / (n - 1))
        rad = np.linspace(radius, radius * 0.12, n)
        tube(mb, pts, rad, sides=5 if depth == 0 else 4, rng=rng, bumps=0.05)
        if depth < 1:
            for _ in range(rng.integers(1, 3)):
                i = rng.integers(2, n - 1)
                sub = unit(d + rng.normal(0, 0.8, 3))
                branch(pts[i], sub, length * rng.uniform(0.35, 0.55), rad[i] * 0.8, depth + 1)

    for i in range(rng.integers(6, 9)):
        z = rng.uniform(height * 0.35, height * 0.9)
        a = rng.uniform(0, 2 * math.pi)
        dvec = np.array([math.cos(a), math.sin(a), rng.uniform(0.3, 0.9)])
        start = np.array([np.interp(z, zs, pts[:, 0]), np.interp(z, zs, pts[:, 1]), z])
        branch(start, dvec, rng.uniform(1.4, 3.2) * (1.1 - z / height), np.interp(z, zs, radii) * 0.45, 0)
    obj = mb.build(name)
    color = lambda N: bark_color(N, dark="#3a3632", mid="#6b645c", light="#958d82", stretch=0.2, moss=0.4, lichen=0.55)  # noqa: E731
    return obj, color, 512, 1.0


# ================================================================ 쓰러진 통나무 · 그루터기

def fallen_log(name, seed, length=6.0, radius=0.38):
    rng = np.random.default_rng(seed)
    mb = MeshBuilder()
    zs = np.linspace(0, length, 9)
    pts = np.column_stack([rng.normal(0, 0.03, 9).cumsum() * 0.5, np.zeros(9), zs])
    radii = radius * np.linspace(1.08, 0.86, 9)
    sides = 11
    # 양 끝은 부러진 단면: 안쪽 원을 한 겹 더 넣어 나이테 면을 만들고, 가장자리를 들쭉날쭉하게
    tube(mb, pts, radii, sides=sides, rng=rng, bumps=0.07, tip=False, leaf=0.0)
    for end, sign in ((0, -1), (len(pts) - 1, 1)):
        c = pts[end]
        ring = [c + [radii[end] * 0.98 * math.cos(a), radii[end] * 0.98 * math.sin(a), sign * rng.uniform(0.0, 0.12)]
                for a in np.linspace(0, 2 * math.pi, sides, endpoint=False)]
        centre = c + [0, 0, sign * rng.uniform(0.02, 0.2)]
        verts = ring + [centre]
        faces = [((j + 1) % sides, j, sides) if sign < 0 else (j, (j + 1) % sides, sides) for j in range(sides)]
        mb.add(verts, faces, cut=1.0)
    # 부러진 가지 그루터기
    for _ in range(3):
        z = rng.uniform(0.8, length - 0.8)
        a = rng.uniform(math.radians(110), math.radians(250))  # 눕히면 위·옆을 향하는 쪽
        dvec = np.array([math.cos(a), math.sin(a), rng.uniform(-0.2, 0.3)])
        base = np.array([0, 0, z]) + dvec * radius * 0.6
        tube(mb, [base, base + unit(dvec) * rng.uniform(0.3, 0.7)], [0.08, 0.05], sides=5, leaf=0.0)
    obj = mb.build(name)
    # 굽기는 세운 상태(나무결이 Z 방향)로 하고, 내보낼 때 눕힌다
    color = combined_color(bark=lambda N: bark_color(N, moss=0.0, lichen=0.3), cut=cut_wood)
    return obj, color, 512, 0.8, {"lay": True}


def stump(name, seed, height=0.9, radius=0.48):
    rng = np.random.default_rng(seed)
    mb = MeshBuilder()
    zs = np.linspace(-0.15, height, 6)
    radii = radius * (1.0 + 0.45 * np.exp(-(zs + 0.15) / 0.25))
    sides = 12
    tube(mb, np.column_stack([np.zeros(6), np.zeros(6), zs]), radii, sides=sides, rng=rng, bumps=0.06, tip=False, leaf=0.0)
    ring = [[radii[-1] * math.cos(a), radii[-1] * math.sin(a), height + rng.uniform(-0.06, 0.04)]
            for a in np.linspace(0, 2 * math.pi, sides, endpoint=False)]
    mb.add(ring + [[0, 0, height - 0.02]], [(j, (j + 1) % sides, sides) for j in range(sides)], cut=1.0)
    for k in range(5):
        a = k / 5 * 2 * math.pi + rng.uniform(-0.3, 0.3)
        dvec = np.array([math.cos(a), math.sin(a), 0])
        tube(mb, [dvec * radius * 0.6 + [0, 0, 0.35], dvec * (radius + 0.35) + [0, 0, 0.05], dvec * (radius + 0.9) + [0, 0, -0.18]],
             [0.2, 0.13, 0.05], sides=6, rng=rng, bumps=0.1, leaf=0.0)
    obj = mb.build(name)
    color = combined_color(bark=lambda N: bark_color(N, moss=0.9, lichen=0.3), cut=cut_wood)
    return obj, color, 512, 0.5


# ================================================================ 바위 (SDF)

def fbm(p, scale, octaves=4, seed=0):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        total = total + amp * sdf.value_noise(p, scale * 2 ** o, seed + o)
        norm += amp
        amp *= 0.5
    return total / norm


def rock(name, seed, kind="boulder"):
    rng = np.random.default_rng(seed)
    blobs = []
    if kind == "boulder":
        blobs.append(sdf.Ellipsoid((0, 0, 0.45), (1.25, 0.95, 0.68), sdf.rot(rng.uniform(-8, 8), rng.uniform(-8, 8), rng.uniform(0, 90))))
        for _ in range(3):
            c = (rng.uniform(-0.7, 0.7), rng.uniform(-0.5, 0.5), rng.uniform(0.15, 0.55))
            blobs.append(sdf.Ellipsoid(c, rng.uniform(0.4, 0.7, 3) * [1, 1, 0.8], sdf.rot(*rng.uniform(-30, 30, 3))))
        planes = 8
    elif kind == "slab":
        for i in range(3):
            blobs.append(sdf.Ellipsoid((rng.uniform(-0.3, 0.3), rng.uniform(-0.2, 0.2), 0.18 + i * 0.28),
                                       (1.5 - i * 0.3, 1.0 - i * 0.18, 0.2), sdf.rot(rng.uniform(-6, 6), rng.uniform(-6, 6), rng.uniform(0, 60))))
        planes = 6
    else:  # crag: 키 큰 바위 기둥
        blobs.append(sdf.Ellipsoid((0, 0, 1.0), (0.75, 0.6, 1.35), sdf.rot(rng.uniform(-8, 8), rng.uniform(-8, 8), 0)))
        blobs.append(sdf.Ellipsoid((0.55, 0.2, 0.45), (0.6, 0.55, 0.65)))
        blobs.append(sdf.Ellipsoid((-0.45, -0.3, 0.35), (0.55, 0.5, 0.5)))
        planes = 7
    shape = sdf.Union(*blobs, k=0.25)
    # 쪼개진 면: 무작위 평면으로 깎는다
    for _ in range(planes):
        n = unit(rng.normal(0, 1, 3) + [0, 0, 0.2])
        lo, hi = shape.bounds()
        c = (lo + hi) / 2 + n * rng.uniform(0.3, 0.55) * (hi - lo).max() * 0.5
        shape = sdf.Intersect(shape, sdf.HalfSpace(c, n), k=0.015)
    shape = sdf.Intersect(shape, sdf.HalfSpace((0, 0, 0.02), (0, 0, -1)))
    shape = sdf.Displace(shape, lambda p: (fbm(p, 1.4, 3, seed) - 0.5) * 0.3 + (fbm(p, 5.0, 3, seed + 3) - 0.5) * 0.08 + (fbm(p, 14, 2, seed + 7) - 0.5) * 0.03)
    verts, faces, _ = sdf.mesh_shape(shape, voxel=0.028, pad=0.2)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts.tolist(), [], faces.tolist())
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    target = {"boulder": 1300, "slab": 1100, "crag": 1500}[kind]
    count = sum(len(p.vertices) - 2 for p in mesh.polygons)
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = min(1.0, target / count)
    select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    # 바닥이 땅(0)에 닿게
    zmin = min(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.z -= zmin
    return obj, lambda N: rock_color(N, moss=0.9 if kind != "crag" else 0.6), 512, 0.5


# ================================================================ 고사리

def fern(name, seed, fronds=14):
    rng = np.random.default_rng(seed)
    mb = MeshBuilder()
    for f in range(fronds):
        phi = f / fronds * 2 * math.pi + rng.uniform(-0.25, 0.25)
        d = np.array([math.cos(phi), math.sin(phi), 0.0])
        side = np.array([-math.sin(phi), math.cos(phi), 0.0])
        L = rng.uniform(1.0, 1.5)
        segs = 10
        s = np.linspace(0, 1, segs + 1)
        rise = rng.uniform(1.5, 2.1)
        centers = np.outer(L * s * 0.9, d) + np.outer(L * (rise * s - 1.25 * s ** 2), [0, 0, 1]) + [0, 0, 0.02]
        width = L * 0.2 * np.sin(np.pi * np.clip(s * 0.85 + 0.12, 0, 1)) ** 0.8
        width *= np.where(np.arange(segs + 1) % 2 == 0, 1.0, 0.45)
        width[0] = 0.01
        droop = L * 0.05 * s
        verts, faces = [], []
        for i in range(segs):
            c = centers[i]
            verts += [c - side * width[i] - [0, 0, droop[i]], c + [0, 0, 0.012 + 0.02 * s[i]], c + side * width[i] - [0, 0, droop[i]]]
        verts.append(centers[-1])
        t = len(verts) - 1
        for i in range(segs - 1):
            a = i * 3
            faces += [(a, a + 1, a + 4, a + 3), (a + 1, a + 2, a + 5, a + 4), (a + 2, a, a + 3, a + 5)]
        a = (segs - 1) * 3
        faces += [(a, a + 1, t), (a + 1, a + 2, t), (a + 2, a, t)]
        faces = [f[::-1] for f in faces]
        mb.add(verts, faces, leaf=1.0, tip=np.concatenate([np.repeat(s[:segs], 3), [1.0]]), rand=rng.random())
    obj = mb.build(name)
    return obj, fern_color, 512, 0.25


# ================================================================ 목록

ASSETS = {
    "Spruce1": lambda: spruce("Spruce1", 11, height=14.0),
    "Spruce2": lambda: spruce("Spruce2", 23, height=15.5, crown=0.18, tiers=14),
    "Spruce3": lambda: spruce("Spruce3", 37, height=12.0, crown=0.24, bare=0.07, tiers=12),
    "SpruceFar1": lambda: spruce("SpruceFar1", 51, height=15.0, far=True),
    "SpruceFar2": lambda: spruce("SpruceFar2", 64, height=16.0, crown=0.18, far=True),
    "DeadTree1": lambda: dead_tree("DeadTree1", 5),
    "DeadTree2": lambda: dead_tree("DeadTree2", 19, height=8.0),
    "Boulder1": lambda: rock("Boulder1", 3, "boulder"),
    "Boulder2": lambda: rock("Boulder2", 8, "boulder"),
    "RockSlab": lambda: rock("RockSlab", 13, "slab"),
    "RockCrag": lambda: rock("RockCrag", 21, "crag"),
    "Log1": lambda: fallen_log("Log1", 4),
    "Stump1": lambda: stump("Stump1", 6),
    "Fern1": lambda: fern("Fern1", 2),
}


def build_all(names, render=False):
    os.makedirs(OUT, exist_ok=True)
    reset()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    objs, report = [], []
    x = 0.0
    for name in names:
        result = ASSETS[name]()
        obj, color_fn, size, ao_dist = result[:4]
        opts = result[4] if len(result) > 4 else {}
        bake(obj, color_fn, size, os.path.join(OUT, name + ".png"), ao_distance=ao_dist)
        if opts.get("lay"):
            # 통나무: 세워서 구운 걸 X 축으로 눕히고 바닥에 붙인다
            obj.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
            zmin = min(v.co.z for v in obj.data.vertices) + 0.06  # 땅에 살짝 묻힌다
            xs = [v.co.x for v in obj.data.vertices]
            shift = (max(xs) + min(xs)) / 2
            for v in obj.data.vertices:
                v.co.z -= zmin
                v.co.x -= shift
            obj.data.update()
        co = np.array([v.co[:] for v in obj.data.vertices])
        lo, hi = co.min(axis=0), co.max(axis=0)
        # 가지런히 늘어놓기 (Studio 에서 가져왔을 때 보기 좋게)
        obj.location.x = x - lo[0]
        x += (hi[0] - lo[0]) + 1.5
        tris = triangle_count(obj)
        report.append((name, tris, hi - lo))
        objs.append(obj)
        print(f"{name:10s} 삼각형 {tris:5d}  크기(m) {hi[0]-lo[0]:.1f} x {hi[1]-lo[1]:.1f} x {hi[2]-lo[2]:.1f}")

    fbx = os.path.join(OUT, "EnvModels.fbx")
    select_only(*objs)
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"}, path_mode="COPY", embed_textures=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL")
    # Roblox 좌표(Y 위) 크기표: 테스트 하네스의 가짜 모델과 미리보기 렌더가 쓴다
    with open(os.path.join(OUT, "sizes.lua"), "w") as f:
        f.write("-- env_kit.py 가 만든 에셋 크기 (Roblox 축: X, Y=높이, Z). 테스트·미리보기용\nreturn {\n")
        for name, tris, dims in report:
            f.write(f"\t{name} = {{{dims[0]:.3f}, {dims[2]:.3f}, {dims[1]:.3f}, tris = {tris}}},\n")
        f.write("}\n")
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0  # .blend1 백업 파일을 만들지 않는다
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "EnvModels.blend"), compress=True)
    if render:
        render_lineup(objs)
    return report


def _stage():
    scene = bpy.context.scene
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    world = scene.world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.42, 0.47, 0.52, 1)
    bg.inputs["Strength"].default_value = 0.7
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("ground")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.045, 0.05, 0.032, 1)
    ground.data.materials.append(gm)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(6)
    sun.rotation_euler = (math.radians(52), math.radians(8), math.radians(30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 50
    scene.collection.objects.link(cam)
    scene.camera = cam
    return cam


def render_lineup(objs, out=None, tile=520):
    """에셋마다 따로 화면에 맞춰 찍어서 한 장으로 붙인다 (docs/images/env_kit.png)."""
    out = out or os.path.join(ROOT, "docs", "images", "env_kit.png")
    scene = bpy.context.scene
    cam = _stage()
    tmp = os.path.join(OUT, "_tile.png")
    tiles = []
    for obj in objs:
        for o in objs:
            o.hide_render = o is not obj
        co = np.array([obj.matrix_world @ v.co for v in obj.data.vertices])
        lo, hi = co.min(axis=0), co.max(axis=0)
        centre = (lo + hi) / 2
        radius = max(np.linalg.norm(hi - lo) / 2, 0.5)
        dist = radius / math.tan(math.radians(18)) * 1.05
        eye = Vector(centre) + Vector((0.45, -1.0, 0.32)).normalized() * dist
        cam.location = eye
        cam.rotation_euler = (Vector(centre) - eye).to_track_quat("-Z", "Y").to_euler()
        cam.data.clip_end = dist * 4
        scene.render.resolution_x = scene.render.resolution_y = tile
        scene.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        tiles.append(iio.imread(tmp)[:, :, :3])
    cols = min(4, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    sheet = np.zeros((rows * tile, cols * tile, 3), np.uint8)
    for i, im in enumerate(tiles):
        r, c = divmod(i, cols)
        sheet[r * tile:(r + 1) * tile, c * tile:(c + 1) * tile] = im
    iio.imwrite(out, sheet)
    os.remove(tmp)
    for o in objs:
        o.hide_render = False


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build_all(args or list(ASSETS), render="--render" in sys.argv)
