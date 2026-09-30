"""WILDHOLD 건축 키트: 제작대 Lv1~3, 벽 Lv1~3, 문 Lv1~2, 화살 포탑 Lv1~3, 가시 함정 Lv1~2, 펫 배치대, 횃불대,
알(보통·희귀), 부화장 둥지, 원정 수레.

파트로 조립한 대체 모델 대신 쓰는 메쉬 에셋. 모두 한 FBX(assets/build/BuildModels.fbx)에 담아서
Studio 에서 한 번 가져오기 → ReplicatedStorage/BuildModels 로 옮기면 구조물이 이 모델로 바뀐다 (없으면 파트 대체 모델).

  python3 blender/build_kit.py            # 전부 만들기
  python3 blender/build_kit.py --render   # + docs/images/build_kit.png 단체 사진

좌표 (중요): 1 Blender 단위 = 1 stud. Z 위, 원점 = 바닥 가운데.
  Blender +Y = Roblox 의 앞(-Z) = 괴물이 오는 바깥쪽. Blender -Y = 뒤(기지 안쪽). 벽은 X 로 길다.
재질은 조각마다 정점 속성(mWood, mStone, …)으로 나누고, 절차적 셰이더를 텍스처 한 장으로 굽는다 (env_kit 과 같은 방식).
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
from creature_lib import reset, select_only, triangle_count  # noqa: E402
from env_kit import MeshBuilder, Nodes, bake, bark_color, cut_wood, rock_color, tube  # noqa: E402

OUT = os.path.join(ROOT, "assets", "build")
SIZES_LUA = os.path.join(ROOT, "src", "shared", "Config", "KitSizes.lua")
MATS = ("mWood", "mDark", "mLog", "mCut", "mStone", "mMetal", "mRope", "mGlow", "mCrystal", "mStraw", "mRoof", "mTeal", "mEggA", "mEggB", "mCloth", "mIron")
ATTRS = MATS + ("rand", "smooth", "leaf", "tip", "cut")


# ================================================================ 조각

def rot(rx=0.0, ry=0.0, rz=0.0):
    """도 단위 회전 행렬 (X → Y → Z 순)."""
    rx, ry, rz = map(math.radians, (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    X = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Y = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Z = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Z @ Y @ X


class Kit:
    """조각을 모아 에셋 하나를 만든다. 조각마다 재질 하나 + 무작위 색 흔들림(rand)."""

    def __init__(self, name, seed=1):
        self.name = name
        self.mb = MeshBuilder(ATTRS)
        self.rng = np.random.default_rng(seed)

    def _add(self, verts, faces, mat, smooth=False, **extra):
        verts = np.asarray(verts, float)
        centre = verts.mean(axis=0)
        fixed = []
        # 볼록한 조각: 면이 바깥을 보게 돌린다
        for f in faces:
            a, b, c = verts[f[0]], verts[f[1]], verts[f[2]]
            n = np.cross(b - a, c - a)
            mid = verts[list(f)].mean(axis=0)
            fixed.append(tuple(f) if n @ (mid - centre) >= 0 else tuple(reversed(f)))
        values = {m: (1.0 if m == mat else 0.0) for m in MATS}
        values["rand"] = self.rng.random()
        values["smooth"] = 1.0 if smooth else 0.0
        values.update(extra)
        self.mb.add(verts, fixed, **values)

    def box(self, centre, size, mat="mWood", R=None, bevel=0.06, jitter=0.0):
        """모서리를 깎은 상자. jitter = 손으로 다듬은 돌처럼 꼭짓점을 흔든다."""
        R = np.eye(3) if R is None else R
        h = np.asarray(size, float) / 2
        b = min(bevel, *(h * 0.45))
        verts, index = [], {}
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    for axis in range(3):
                        v = np.array([sx * (h[0] - b), sy * (h[1] - b), sz * (h[2] - b)])
                        v[axis] = (sx, sy, sz)[axis] * h[axis]
                        if jitter:
                            v = v + self.rng.uniform(-jitter, jitter, 3) * h.min()
                        index[(sx, sy, sz, axis)] = len(verts)
                        verts.append(v)
        faces = []
        for axis in range(3):
            o = [a for a in range(3) if a != axis]
            for s in (-1, 1):
                quad = []
                for u, w in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    key = [0, 0, 0]
                    key[axis], key[o[0]], key[o[1]] = s, u, w
                    quad.append(index[(key[0], key[1], key[2], axis)])
                faces.append(quad)
        for axis in range(3):  # 모서리 띠
            o = [a for a in range(3) if a != axis]
            for s1 in (-1, 1):
                for s2 in (-1, 1):
                    k1, k2 = [0, 0, 0], [0, 0, 0]
                    k1[axis], k2[axis] = -1, 1
                    k1[o[0]] = k2[o[0]] = s1
                    k1[o[1]] = k2[o[1]] = s2
                    faces.append([index[(*k1, o[0])], index[(*k2, o[0])], index[(*k2, o[1])], index[(*k1, o[1])]])
        for sx in (-1, 1):  # 꼭짓점 세모
            for sy in (-1, 1):
                for sz in (-1, 1):
                    faces.append([index[(sx, sy, sz, 0)], index[(sx, sy, sz, 1)], index[(sx, sy, sz, 2)]])
        verts = [np.asarray(centre, float) + R @ v for v in verts]
        # 모서리 띠는 볼록 판정이 조각 전체 중심 기준이라 안전하다
        self._add(verts, faces, mat)

    def cyl(self, p0, p1, r0, r1=None, sides=10, mat="mLog", caps=True, smooth=True, cap_mat=None):
        """원기둥/원뿔대 (r1=0 이면 뾰족)."""
        r1 = r0 if r1 is None else r1
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        axis = p1 - p0
        length = np.linalg.norm(axis)
        t = axis / length
        ref = np.array([0, 0, 1.0]) if abs(t[2]) < 0.9 else np.array([1.0, 0, 0])
        u = np.cross(t, ref)
        u /= np.linalg.norm(u)
        w = np.cross(t, u)
        verts, faces = [], []
        for ring, (p, r) in enumerate(((p0, r0), (p1, r1))):
            for i in range(sides):
                a = 2 * math.pi * i / sides
                verts.append(p + r * (math.cos(a) * u + math.sin(a) * w))
        for i in range(sides):
            j = (i + 1) % sides
            faces.append([i, j, sides + j, sides + i])
        self._add(verts, faces, mat, smooth=smooth)
        if caps:
            for p, r, sign in ((p0, r0, -1), (p1, r1, 1)):
                if r <= 1e-3:
                    continue
                ring = [p + r * (math.cos(2 * math.pi * i / sides) * u + math.sin(2 * math.pi * i / sides) * w) for i in range(sides)]
                cap = ring + [p]
                cf = [[i, (i + 1) % sides, sides] for i in range(sides)]
                # 뚜껑은 원판이라 중심 판정이 안 되므로 직접 방향을 맞춘다
                verts2 = np.asarray(cap)
                fixed = []
                for f in cf:
                    n = np.cross(verts2[f[1]] - verts2[f[0]], verts2[f[2]] - verts2[f[0]])
                    fixed.append(f if n @ (t * sign) >= 0 else list(reversed(f)))
                values = {m: 0.0 for m in MATS}
                values[cap_mat or ("mCut" if mat == "mLog" else mat)] = 1.0
                values["rand"], values["smooth"] = self.rng.random(), 0.0
                self.mb.add(verts2, [tuple(f) for f in fixed], **values)

    def log(self, p0, p1, r, sharpen=0.0, bumps=0.08, sides=9):
        """껍질이 붙은 통나무. sharpen > 0 이면 위쪽 끝을 뾰족하게 깎는다."""
        p0, p1 = np.asarray(p0, float), np.asarray(p1, float)
        n = 6
        pts = [p0 + (p1 - p0) * i / (n - 1) for i in range(n)]
        radii = [r * (1.0 + self.rng.uniform(-0.05, 0.05)) for _ in range(n)]
        tube(self.mb, pts, radii, sides=sides, rng=self.rng, bumps=bumps, tip=False, base_cap=True,
             **{m: (1.0 if m == "mLog" else 0.0) for m in MATS}, rand=self.rng.random(), smooth=1.0)
        top = p1
        axis = (p1 - p0) / np.linalg.norm(p1 - p0)
        if sharpen > 0:
            self.cyl(top, top + axis * sharpen, r * 0.98, 0.02, sides=sides, mat="mCut", caps=False, smooth=False)
        else:
            self.cyl(top - axis * 0.02, top, r * 0.98, r * 0.98, sides=sides, mat="mCut", caps=True, smooth=False)

    def cone(self, base, radius, height, sides=8, mat="mRoof", R=None):
        R = np.eye(3) if R is None else R
        base = np.asarray(base, float)
        verts = [base + R @ np.array([radius * math.cos(2 * math.pi * i / sides), radius * math.sin(2 * math.pi * i / sides), 0]) for i in range(sides)]
        verts.append(base + R @ np.array([0, 0, height]))
        verts.append(base)
        faces = [[i, (i + 1) % sides, sides] for i in range(sides)] + [[(i + 1) % sides, i, sides + 1] for i in range(sides)]
        self._add(verts, faces, mat)

    def hull(self, verts, mat, smooth=False):
        """꼭짓점 8개(아래 4 + 위 4, 같은 순서)로 된 볼록한 덩어리 (도끼날·창날처럼 한쪽이 얇아지는 모양)."""
        faces = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
        self._add(verts, faces, mat, smooth=smooth)

    def rope(self, centre, radius, axis="x", turns=3, thick=0.09):
        """묶은 밧줄 (고리 몇 바퀴)."""
        c = np.asarray(centre, float)
        for k in range(turns):
            off = (k - (turns - 1) / 2) * thick * 1.8
            pts = []
            for i in range(13):
                a = 2 * math.pi * i / 12
                if axis == "x":
                    pts.append(c + np.array([off, radius * math.cos(a), radius * math.sin(a)]))
                elif axis == "y":
                    pts.append(c + np.array([radius * math.cos(a), off, radius * math.sin(a)]))
                else:
                    pts.append(c + np.array([radius * math.cos(a), radius * math.sin(a), off]))
            tube(self.mb, pts, [thick] * len(pts), sides=5, tip=False, **{m: (1.0 if m == "mRope" else 0.0) for m in MATS},
                 rand=self.rng.random(), smooth=1.0)

    def blob(self, shape, voxel, mat, smooth=True):
        """SDF 모양 → 메쉬 (알처럼 매끈한 것)."""
        verts, faces, _ = sdf.mesh_shape(shape, voxel=voxel)
        values = {m: (1.0 if m == mat else 0.0) for m in MATS}
        values["rand"], values["smooth"] = self.rng.random(), 1.0 if smooth else 0.0
        self.mb.add(np.asarray(verts, float), [tuple(f) for f in faces], **values)

    def build(self):
        obj = self.mb.build(self.name)
        smooth = obj.data.attributes["smooth"].data
        for poly in obj.data.polygons:
            poly.use_smooth = smooth[poly.vertices[0]].value > 0.5
        return obj


# ================================================================ 재질 (굽기용 셰이더)

def plank_color(N, mid="#6a5442", dark="#4a3b2e", light="#8c7a64"):
    """비바람에 바랜 널빤지: 결 + 옹이 + 판마다 조금씩 다른 색."""
    grain = N.math("MAXIMUM", N.noise(N.obj((1.0, 12.0, 12.0)), 3.0, 4.0, 0.6), N.noise(N.obj((12.0, 12.0, 1.0)), 3.0, 4.0, 0.6))
    col = N.mix(grain, dark, mid)
    col = N.mix(N.ramp(N.attr("rand"), 0.0, 1.0, 0.0, 0.35), col, light)
    knots = N.ramp(N.voronoi(N.obj(), 3.0), 0.0, 0.05, 0.6, 0.0)
    col = N.mix(knots, col, "#2e241c")
    dirt = N.ramp(N.pos("Z"), 0.0, 1.2, 0.45, 0.0)
    return N.mix(N.math("MULTIPLY", dirt, N.noise(N.obj(), 3.0, 4.0)), col, "#3a3326")


def metal_color(N):
    """오래된 쇠: 어두운 철 + 녹 얼룩 + 닳은 곳은 밝게."""
    base = N.mix(N.noise(N.obj(), 12.0, 5.0), "#3a3f45", "#555c63")
    rust = N.ramp(N.noise(N.obj(), 4.0, 6.0, 0.7), 0.52, 0.62)
    return N.mix(rust, base, "#7a4a2a")


def material_color(N):
    col = plank_color(N)
    layers = [
        ("mDark", plank_color(N, mid="#4d3d30", dark="#33281f", light="#5e4a38")),
        ("mLog", bark_color(N, moss=0.35)),
        ("mCut", cut_wood(N)),
        ("mStone", rock_color(N, moss=0.45)),
        ("mMetal", metal_color(N)),
        ("mRope", N.mix(N.noise(N.obj((6, 6, 6)), 30.0, 3.0), "#9c8458", "#c2aa78")),
        ("mGlow", N.color("#ff9a3c")),
        ("mCrystal", N.mix(N.noise(N.obj(), 6.0), "#7ff0ff", "#d8fffb")),
        ("mStraw", N.mix(N.noise(N.obj((1, 1, 6)), 18.0, 3.0), "#8a7440", "#c9ae66")),
        ("mRoof", N.mix(N.noise(N.obj((1, 1, 4)), 14.0, 3.0), "#4a3c30", "#6a5846")),
        ("mTeal", N.mix(N.noise(N.obj(), 10.0), "#2f6f7a", "#4a8f96")),
        ("mCloth", N.mix(N.noise(N.obj((4, 4, 4)), 20.0, 2.0), "#b9ac8c", "#d6cba9")),
        ("mIron", N.mix(N.noise(N.obj((1, 1, 20)), 30.0, 2.0), "#aab4bb", "#d5dde2")),
        ("mEggA", egg_color(N, "#efe3c6", "#a8916a")),
        ("mEggB", egg_color(N, "#cdeeff", "#7a5cff", swirl=True)),
    ]
    for attr, layer in layers:
        col = N.mix(N.attr(attr), col, layer)
    return col


def egg_color(N, base, spot, swirl=False):
    spots = N.ramp(N.voronoi(N.obj(), 2.6), 0.0, 0.2, 1.0, 0.0)
    col = N.mix(N.ramp(N.pos("Z"), 0.0, 2.4, 0.0, 0.25), base, "#ffffff")
    col = N.mix(spots, col, spot)
    if swirl:
        band = N.ramp(N.noise(N.obj((1, 1, 3)), 2.0, 4.0, 0.6, 2.0), 0.45, 0.6)
        col = N.mix(band, col, "#b89cff")
    return col


# ================================================================ 에셋

def workbench(level):
    k = Kit("Workbench%d" % level, seed=10 + level)
    top_mat = "mMetal" if level >= 3 else "mWood"
    # 상판: 널빤지 네 장 (Lv3 는 쇠판)
    if level >= 3:
        k.box((0, 0, 3.3), (8.0, 4.0, 0.5), "mMetal", bevel=0.08)
    else:
        for i in range(4):
            k.box((0, -1.5 + i * 1.0, 3.3), (8.0 + k.rng.uniform(-0.2, 0.2), 0.94, 0.45), "mWood", R=rot(0, k.rng.uniform(-1, 1), 0), bevel=0.05)
    # 다리
    for x in (-3.4, 3.4):
        for y in (-1.5, 1.5):
            if level >= 2:
                k.box((x, y, 1.55), (1.0, 1.0, 3.1), "mStone", bevel=0.12, jitter=0.12)
            else:
                k.log((x, y, 0), (x, y, 3.1), 0.36, bumps=0.05)
    # 다리 가로대 + 선반
    k.box((0, 0, 1.0), (7.2, 3.4, 0.25), "mDark", bevel=0.04)
    for x in (-3.4, 3.4):
        k.box((x, 0, 2.4), (0.3, 3.2, 0.3), "mDark", bevel=0.04)
    # 뒤판 (기지 안쪽 = Blender -Y) + 공구걸이
    back_mat = "mMetal" if level >= 3 else "mDark"
    k.box((0, -1.9, 5.6), (8.0, 0.3, 4.0), back_mat, bevel=0.05)
    for x in (-3.9, 3.9):
        k.box((x, -1.9, 3.8), (0.35, 0.4, 7.6 if level >= 3 else 4.2), "mMetal" if level >= 3 else "mWood", bevel=0.05)
    # 걸린 공구: 톱, 망치, 집게
    k.box((-2.3, -1.72, 5.6), (1.8, 0.06, 0.55), "mMetal", bevel=0.01)
    k.box((-1.25, -1.72, 5.6), (0.35, 0.18, 0.5), "mDark", bevel=0.02)
    k.box((0.6, -1.7, 5.5), (0.18, 0.18, 1.5), "mWood", bevel=0.03)
    k.box((0.6, -1.7, 6.25), (0.8, 0.3, 0.35), "mMetal", bevel=0.04)
    k.box((2.0, -1.7, 5.3), (0.12, 0.12, 1.2), "mMetal", R=rot(0, 12, 0), bevel=0.02)
    k.box((2.3, -1.7, 5.3), (0.12, 0.12, 1.2), "mMetal", R=rot(0, -12, 0), bevel=0.02)
    # 상판 위: 망치, 끌, 밧줄, 널빤지 조각, 못 상자
    k.box((-1.8, 0.4, 3.66), (0.3, 1.8, 0.25), "mWood", R=rot(0, 0, 30), bevel=0.03)
    k.box((-1.35, 1.1, 3.72), (0.5, 0.5, 0.4), "mMetal", R=rot(0, 0, 30), bevel=0.05)
    k.rope((1.8, 0.3, 3.9), 0.42, axis="z", turns=3, thick=0.1)
    k.box((0.4, -0.8, 3.62), (2.2, 0.6, 0.18), "mWood", R=rot(0, 0, -8), bevel=0.02)
    k.box((2.9, -0.9, 3.75), (0.9, 0.7, 0.45), "mDark", bevel=0.03)
    # 모루 그루터기 (오른쪽)
    k.log((5.9, 0.4, 0), (5.9, 0.4, 2.35), 1.15, bumps=0.06)
    k.box((5.9, 0.4, 2.8), (1.9, 0.8, 0.9), "mMetal", bevel=0.1)
    k.box((6.95, 0.4, 3.0), (0.6, 0.45, 0.4), "mMetal", R=rot(0, 20, 0), bevel=0.06)
    if level >= 2:
        # 돌 화덕 + 굴뚝 + 풀무 (왼쪽)
        for i in range(10):
            a = 2 * math.pi * i / 10
            k.box((-6.1 + math.cos(a) * 1.2, 0.2 + math.sin(a) * 1.1, 1.1), (0.9, 0.9, 2.2), "mStone", R=rot(0, 0, math.degrees(a)), bevel=0.12, jitter=0.15)
        k.box((-6.1, 0.2, 2.25), (1.6, 1.4, 0.3), "mGlow", bevel=0.1)
        k.cyl((-6.1, -0.6, 2.2), (-6.1, -0.6, 6.0), 0.35, 0.28, mat="mStone", sides=8)
        k.box((-4.6, 1.3, 1.3), (1.0, 1.2, 0.35), "mCloth", R=rot(0, 0, 20), bevel=0.05)
    if level >= 3:
        # 바이스 + 수정 등 + 쇠 테두리
        k.box((-3.2, 1.6, 3.95), (0.8, 0.5, 0.8), "mMetal", bevel=0.06)
        k.cyl((-3.2, 1.6, 4.1), (-3.2, 2.5, 4.1), 0.08, mat="mMetal", sides=6)
        k.cyl((3.2, -1.5, 7.6), (3.2, -1.5, 8.1), 0.25, mat="mMetal", sides=8)
        k.box((3.2, -1.5, 8.6), (0.7, 0.7, 1.2), "mCrystal", R=rot(0, 0, 45), bevel=0.2)
        k.box((0, -1.9, 7.75), (8.2, 0.35, 0.3), "mMetal", bevel=0.04)
    return k.build(), 1024


def wall(level):
    k = Kit("Wall%d" % level, seed=20 + level)
    width = 12.0
    if level == 1:
        # 뾰족한 통나무 말뚝 + 뒤쪽 가로대 두 줄 + 밧줄 묶음
        n = 7
        for i in range(n):
            x = -width / 2 + 0.85 + i * (width - 1.7) / (n - 1)
            h = 6.0 + k.rng.uniform(0, 0.9)
            lean = k.rng.uniform(-2.5, 2.5)
            top = np.array([x + math.sin(math.radians(lean)) * h * 0.05, 0.0, h])
            k.log((x, 0, -0.3), top, 0.8 + k.rng.uniform(-0.05, 0.05), sharpen=1.3)
        for z in (1.8, 4.6):
            k.log((-width / 2, -0.95, z), (width / 2, -0.95, z), 0.26, bumps=0.04, sides=7)
            for i in range(n):
                x = -width / 2 + 0.85 + i * (width - 1.7) / (n - 1)
                k.rope((x, -0.75, z), 0.36, axis="x", turns=2, thick=0.07)
    else:
        rows = 4 if level >= 3 else 3
        for r in range(rows):
            x = -width / 2 + (1.1 if r % 2 else 0.0)
            while x < width / 2 - 0.3:
                w = min(2.2 + k.rng.uniform(-0.3, 0.3), width / 2 - x)
                if w > 0.4:
                    k.box((x + w / 2, 0, 0.8 + r * 1.62), (w - 0.08, 2.6, 1.56), "mStone", bevel=0.14, jitter=0.07)
                x += w
        top = 0.4 + rows * 1.62
        # 윗단 나무 방책
        for i in range(int(width / 1.8)):
            x = -width / 2 + 0.9 + i * 1.8
            k.box((x, -0.8, top + 0.8), (1.2, 0.6, 1.6), "mWood", bevel=0.05)
            k.cyl((x, -0.8, top + 1.6), (x, -0.8, top + 2.5), 0.45, 0.02, sides=4, mat="mWood", smooth=False)
        if level >= 3:
            for x in (-width / 2 + 1.4, 0, width / 2 - 1.4):
                k.box((x, 1.42, top / 2), (1.6, 0.25, top), "mMetal", bevel=0.05)
                for z in (1.0, top - 1.0):
                    k.cyl((x - 0.5, 1.6, z), (x - 0.5, 1.7, z), 0.12, mat="mMetal", sides=6)
                    k.cyl((x + 0.5, 1.6, z), (x + 0.5, 1.7, z), 0.12, mat="mMetal", sides=6)
            for i in range(6):
                x = -width / 2 + 1 + i * (width - 2) / 5
                k.cyl((x, 1.3, 1.3), (x, 3.3, 2.0), 0.26, 0.02, sides=6, mat="mMetal", smooth=False)
    return k.build(), 1024


def gate(level):
    k = Kit("Gate%d" % level, seed=30 + level)
    width = 10.0
    for x in (-width / 2 - 0.4, width / 2 + 0.4):
        k.log((x, 0, -0.3), (x, 0, 9.0), 0.85, sharpen=1.2)
    k.log((-width / 2 - 1.2, 0, 8.2), (width / 2 + 1.2, 0, 8.2), 0.55, bumps=0.05)
    # 반쯤 열린 두 짝 문 (안쪽 = -Y 로 열림)
    for side in (-1, 1):
        hinge = np.array([side * width / 2, 0.0, 0.0])
        R = rot(0, 0, side * -55)
        for i in range(4):
            local = np.array([-side * (0.8 + i * 1.3), 0.0, 3.3])
            k.box(hinge + R @ local, (1.24, 0.5, 6.2), "mWood", R=R, bevel=0.06)
        for z in (1.5, 5.0):
            k.box(hinge + R @ np.array([-side * 2.8, 0.3, z]), (5.4, 0.3, 0.55), "mMetal" if level >= 2 else "mDark", R=R, bevel=0.05)
        if level >= 2:
            k.box(hinge + R @ np.array([-side * 2.8, 0.3, 3.3]), (5.4, 0.3, 0.45), "mMetal", R=R, bevel=0.05)
    if level >= 2:
        for x in (-width / 2 - 0.4, width / 2 + 0.4):
            for z in (2, 6):
                k.box((x, 0, z), (1.9, 1.9, 0.35), "mMetal", bevel=0.06)
    return k.build(), 1024


def tower(level):
    k = Kit("Tower%d" % level, seed=40 + level)
    h = (8.0, 10.0, 12.0)[level - 1]
    if level >= 2:
        # 돌 원통 받침
        rows = int(h * 0.55 / 1.1)
        for r in range(rows):
            for i in range(10):
                a = 2 * math.pi * (i + (0.5 if r % 2 else 0)) / 10
                k.box((math.cos(a) * 2.5, math.sin(a) * 2.5, 0.55 + r * 1.1), (1.7, 1.1, 1.05), "mStone", R=rot(0, 0, math.degrees(a) + 90), bevel=0.1, jitter=0.08)
    for x in (-2, 2):
        for y in (-2, 2):
            k.log((x, y, 0), (x * 0.92, y * 0.92, h), 0.42, bumps=0.05, sides=8)
    if level == 1:
        for z in (h * 0.3, h * 0.62):
            for sign in (-1, 1):
                k.box((0, sign * 2.0, z), (4.6, 0.35, 0.35), "mDark", R=rot(0, 28 * sign, 0), bevel=0.04)
                k.box((sign * 2.0, 0, z), (0.35, 4.6, 0.35), "mDark", R=rot(28 * sign, 0, 0), bevel=0.04)
    # 발판 + 난간
    for i in range(6):
        k.box((-2.7 + i * 1.08, 0, h), (1.02, 6.4, 0.45), "mWood", bevel=0.04)
    for i in range(4):
        a = i * 90
        R = rot(0, 0, a)
        k.box(R @ np.array([0, 3.0, h + 1.0]), (6.4, 0.35, 1.3), "mWood", R=R, bevel=0.05)
    # 석궁 (앞 = +Y 를 겨눈다)
    k.box((0, 0.6, h + 1.6), (0.6, 3.0, 0.6), "mDark", bevel=0.06)
    k.box((0, 1.8, h + 1.6), (3.6, 0.3, 0.3), "mMetal", R=rot(0, 0, 0), bevel=0.04)
    k.cyl((-1.8, 1.8, h + 1.6), (1.8, 1.8, h + 1.6), 0.03, mat="mRope", sides=4)
    k.box((0, 1.0, h + 1.95), (0.12, 2.4, 0.12), "mCloth", bevel=0.02)
    # 지붕 기둥 + 지붕
    for x in (-2.8, 2.8):
        for y in (-2.8, 2.8):
            k.box((x, y, h + 2.2), (0.4, 0.4, 3.2), "mWood", bevel=0.05)
    k.cone((0, 0, h + 3.7), 4.9, 3.6 + level * 0.4, sides=4, mat="mTeal" if level == 3 else "mRoof", R=rot(0, 0, 45))
    return k.build(), 1024


def spikes(level):
    k = Kit("Spike%d" % level, seed=50 + level)
    k.cyl((0, 0, 0), (0, 0, 0.3), 4.3, mat="mDark" if level == 1 else "mMetal", sides=16, smooth=False)
    count = 16 if level >= 2 else 11
    for _ in range(count):
        a = k.rng.random() * 2 * math.pi
        r = math.sqrt(k.rng.random()) * 3.4
        h = 1.2 + k.rng.random() * (1.4 if level >= 2 else 0.9)
        tilt = np.array([math.cos(a), math.sin(a), 0]) * k.rng.uniform(0.1, 0.35)
        base = np.array([math.cos(a) * r, math.sin(a) * r, 0.2])
        tip = base + (np.array([0, 0, 1.0]) + tilt) / np.linalg.norm(np.array([0, 0, 1.0]) + tilt) * h
        if level >= 2:
            k.cyl(base, tip, 0.28, 0.02, sides=4, mat="mMetal", smooth=False)
        else:
            k.log(base, tip - (tip - base) * 0.25, 0.2, sharpen=h * 0.25, bumps=0.03, sides=6)
    return k.build(), 512


def pet_stand():
    k = Kit("PetStand", seed=60)
    for i in range(12):
        a = 2 * math.pi * i / 12
        k.box((math.cos(a) * 2.3, math.sin(a) * 2.3, 0.6), (1.35, 1.0, 1.2), "mStone", R=rot(0, 0, math.degrees(a) + 90), bevel=0.14, jitter=0.1)
    k.cyl((0, 0, 0), (0, 0, 1.2), 2.2, mat="mStone", sides=14, smooth=False)
    k.cyl((0, 0, 1.2), (0, 0, 2.0), 2.3, 2.2, mat="mStone", sides=14, smooth=False)
    k.cyl((0, 0, 2.0), (0, 0, 2.08), 2.0, mat="mCrystal", sides=20, smooth=False)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        x, y = math.cos(a) * 2.6, math.sin(a) * 2.6
        k.box((x, y, 2.5), (0.25, 0.25, 1.0), "mMetal", bevel=0.03)
        k.box((x, y, 3.2), (0.55, 0.55, 0.6), "mGlow", bevel=0.08)
        k.cone((x, y, 3.5), 0.45, 0.35, sides=4, mat="mMetal")
    return k.build(), 512


def torch_post():
    k = Kit("TorchPost", seed=70)
    k.log((0, 0, 0), (0, 0, 6.0), 0.3, bumps=0.04, sides=8)
    k.cyl((0, 0, 5.9), (0, 0, 6.5), 0.55, 0.7, mat="mMetal", sides=8, smooth=False)
    k.cyl((0, 0, 6.3), (0, 0, 6.9), 0.45, 0.4, mat="mCloth", sides=8)
    k.rope((0, 0, 5.2), 0.34, axis="z", turns=2, thick=0.07)
    for i in range(3):
        a = 2 * math.pi * i / 3
        k.cyl((0, 0, 1.2), (math.cos(a) * 1.0, math.sin(a) * 1.0, 0), 0.14, mat="mLog", sides=6)
    return k.build(), 512


def egg(kind):
    """알: 위가 조금 좁은 달걀 모양 (위도·경도 격자, 매끈한 음영)."""
    k = Kit("Egg" + kind, seed=80 if kind == "Common" else 81)
    rx, rz = (0.9, 1.15) if kind == "Common" else (1.0, 1.3)
    rings, sides = 18, 28
    verts, faces = [], []
    for i in range(1, rings):
        t = math.pi * i / rings  # 0 = 위, pi = 아래
        z = rz * (1 - math.cos(t))  # 바닥 0 → 꼭대기 2rz (아래에서 위로 뒤집어 계산)
        z = 2 * rz - z
        squash = 1.0 - 0.12 * ((z - rz) / rz)
        r = rx * math.sin(t) * squash
        for j in range(sides):
            a = 2 * math.pi * j / sides
            verts.append((r * math.cos(a), r * math.sin(a), z))
    top, bottom = len(verts), len(verts) + 1
    verts += [(0, 0, 2 * rz), (0, 0, 0)]
    for i in range(rings - 2):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append([a, b, b + sides, a + sides])
    last = (rings - 2) * sides
    for j in range(sides):
        faces.append([top, (j + 1) % sides, j])
        faces.append([bottom, last + j, last + (j + 1) % sides])
    k._add(verts, faces, "mEggA" if kind == "Common" else "mEggB", smooth=True)
    return k.build(), 512


def nest():
    k = Kit("Nest", seed=90)
    for i in range(46):
        a = k.rng.random() * 2 * math.pi
        r = 2.4 + k.rng.uniform(-0.3, 0.4)
        z = 0.2 + k.rng.random() * 1.0
        d = np.array([-math.sin(a), math.cos(a), k.rng.uniform(-0.2, 0.2)])
        c = np.array([math.cos(a) * r, math.sin(a) * r, z])
        k.cyl(c - d * 1.1, c + d * 1.1, 0.12, mat="mStraw", sides=5)
    k.cyl((0, 0, 0), (0, 0, 0.35), 2.5, mat="mStraw", sides=18, smooth=False)
    return k.build(), 512


def wagon():
    k = Kit("Wagon", seed=95)
    # 짐칸 (Blender Y 가 수레 길이, 앞(+Y) 에 끌채)
    for i in range(7):
        k.box((-3.0 + i * 1.0, 0, 2.2), (0.96, 11.0, 0.5), "mWood", bevel=0.04)
    for x in (-3.4, 3.4):
        k.box((x, 0, 3.1), (0.35, 11.0, 1.5), "mDark", bevel=0.05)
        for y in (-3.6, 3.6):
            k.cyl((x + (0.45 if x > 0 else -0.45), y, 1.7), (x + (0.95 if x > 0 else -0.95), y, 1.7), 1.6, mat="mDark", sides=16, smooth=False)
            k.cyl((x + (0.5 if x > 0 else -0.5), y, 1.7), (x + (0.9 if x > 0 else -0.9), y, 1.7), 1.7, mat="mMetal", sides=16, caps=False)
    k.cyl((-3.8, 3.6, 1.7), (3.8, 3.6, 1.7), 0.18, mat="mMetal", sides=8)
    k.cyl((-3.8, -3.6, 1.7), (3.8, -3.6, 1.7), 0.18, mat="mMetal", sides=8)
    # 천막: 둥근 뼈대 + 천
    for y in (-4.6, -1.5, 1.5, 4.6):
        pts = [np.array([math.sin(math.radians(a)) * 3.5, y, 3.8 + math.cos(math.radians(a)) * 3.4]) for a in range(-90, 91, 15)]
        tube(k.mb, pts, [0.12] * len(pts), sides=5, tip=False, **{m: (1.0 if m == "mDark" else 0.0) for m in MATS}, rand=0.5, smooth=1.0)
    for i in range(12):
        a0, a1 = math.radians(-90 + i * 15), math.radians(-90 + (i + 1) * 15)
        mid = (a0 + a1) / 2
        k.box((math.sin(mid) * 3.55, 0.2, 3.8 + math.cos(mid) * 3.45), (0.95, 9.8, 0.08), "mCloth", R=rot(0, math.degrees(mid), 0), bevel=0.01)
    # 끌채
    for x in (-1, 1):
        k.box((x, 7.6, 2.0), (0.35, 5.0, 0.35), "mDark", R=rot(-8, 0, 0), bevel=0.04)
    # 짐: 상자 둘 + 통 + 자루
    k.box((-1.5, -3.0, 3.35), (1.8, 1.8, 1.8), "mWood", bevel=0.08)
    k.box((-1.4, -3.1, 4.9), (1.3, 1.3, 1.3), "mWood", R=rot(0, 0, 18), bevel=0.06)
    k.cyl((1.6, -3.2, 2.45), (1.6, -3.2, 4.8), 1.0, 0.9, mat="mDark", sides=12, smooth=False)
    k.rope((1.6, -3.2, 3.2), 1.02, axis="z", turns=1, thick=0.08)
    k.rope((1.6, -3.2, 4.2), 0.97, axis="z", turns=1, thick=0.08)
    k.box((1.3, -0.4, 3.0), (1.6, 1.4, 1.2), "mCloth", bevel=0.4)
    return k.build(), 1024


# ================================================================ 손에 드는 도구 (원점 = 손이 쥐는 곳)
# Roblox ToolLook 과 같은 자세: 도끼·곡괭이·횃불은 자루가 위(+Z), 날은 앞(+Y). 창은 앞(+Y)으로 눕힌다.
HEAD = {1: "mMetal", 2: "mStone", 3: "mIron", 4: "mCrystal"}


def axe(tier):
    k = Kit("Axe%d" % tier, seed=100 + tier)
    head = HEAD[tier]
    k.cyl((0, 0, -0.7), (0, 0.04, 2.75), 0.13, 0.12, mat="mWood", sides=8)
    k.cyl((0, 0, -0.38), (0, 0, 0.38), 0.165, mat="mCloth", sides=8)
    k.cyl((0, 0, -0.78), (0, 0, -0.62), 0.17, mat="mDark", sides=8)
    top = 2.2
    k.box((0, 0.02, top), (0.34, 0.44, 0.62), head, bevel=0.05)
    k.box((0, -0.3, top), (0.28, 0.3, 0.4), head, bevel=0.05)
    # 날: 뺨에서 앞으로 가면서 얇아지고 위아래로 벌어진다
    t0, t1 = 0.12, 0.03
    k.hull([(-t0, 0.2, top - 0.26), (t0, 0.2, top - 0.26), (t1, 0.95, top - 0.58), (-t1, 0.95, top - 0.58),
            (-t0, 0.2, top + 0.26), (t0, 0.2, top + 0.26), (t1, 0.95, top + 0.58), (-t1, 0.95, top + 0.58)], head)
    if tier >= 3:
        k.rope((0, 0.05, top - 0.45), 0.16, axis="z", turns=2, thick=0.04)
    return k.build(), 256


def pick(tier):
    k = Kit("Pick%d" % tier, seed=110 + tier)
    head = HEAD[tier]
    k.cyl((0, 0, -0.65), (0, 0, 2.85), 0.13, 0.12, mat="mWood", sides=8)
    k.cyl((0, 0, -0.38), (0, 0, 0.38), 0.165, mat="mCloth", sides=8)
    top = 2.72
    k.box((0, 0, top), (0.36, 0.46, 0.42), head, bevel=0.05)
    for side in (-1, 1):
        k.box((0, side * 0.58, top + 0.02), (0.22, 0.8, 0.3), head, R=rot(side * 8, 0, 0), bevel=0.04)
        k.box((0, side * 1.16, top - 0.13), (0.18, 0.62, 0.24), head, R=rot(side * 24, 0, 0), bevel=0.03)
        k.cyl((0, side * 1.42, top - 0.26), (0, side * 1.72, top - 0.52), 0.1, 0.01, mat=head, sides=6, smooth=False)
    return k.build(), 256


def spear(tier):
    k = Kit("Spear%d" % tier, seed=120 + tier)
    head = HEAD[tier]
    k.cyl((0, -1.9, 0), (0, 3.55, 0), 0.12, 0.11, mat="mWood", sides=8)
    k.cyl((0, -0.3, 0), (0, 0.3, 0), 0.155, mat="mCloth", sides=8)
    k.cyl((0, 3.2, 0), (0, 3.6, 0), 0.15, mat="mRope", sides=8)
    # 나뭇잎 모양 창날 (세로로 선 납작한 날)
    w = 0.05
    k.hull([(-w, 3.55, -0.08), (w, 3.55, -0.08), (w, 4.2, -0.27), (-w, 4.2, -0.27),
            (-w, 3.55, 0.08), (w, 3.55, 0.08), (w, 4.2, 0.27), (-w, 4.2, 0.27)], head)
    k.hull([(-w, 4.2, -0.27), (w, 4.2, -0.27), (0.01, 4.95, -0.01), (-0.01, 4.95, -0.01),
            (-w, 4.2, 0.27), (w, 4.2, 0.27), (0.01, 4.95, 0.01), (-0.01, 4.95, 0.01)], head)
    if tier >= 2:
        # 날 밑 가로 막대
        k.box((0, 3.55, 0), (0.12, 0.12, 0.7), head, bevel=0.02)
    if tier == 4:
        k.box((0, 3.4, 0), (0.28, 0.28, 0.28), "mCrystal", R=rot(45, 45, 0), bevel=0.05)
    return k.build(), 256


def torch_tool():
    k = Kit("TorchTool", seed=130)
    k.cyl((0, 0, -0.55), (0, 0, 1.75), 0.13, 0.12, mat="mWood", sides=8)
    k.cyl((0, 0, 1.55), (0, 0, 1.75), 0.2, mat="mMetal", sides=8)
    k.cyl((0, 0, 1.7), (0, 0, 2.3), 0.24, 0.2, mat="mCloth", sides=8)
    k.rope((0, 0, 1.95), 0.23, axis="z", turns=2, thick=0.04)
    return k.build(), 256


ASSETS = {
    "Workbench1": lambda: workbench(1), "Workbench2": lambda: workbench(2), "Workbench3": lambda: workbench(3),
    "Wall1": lambda: wall(1), "Wall2": lambda: wall(2), "Wall3": lambda: wall(3),
    "Gate1": lambda: gate(1), "Gate2": lambda: gate(2),
    "Tower1": lambda: tower(1), "Tower2": lambda: tower(2), "Tower3": lambda: tower(3),
    "Spike1": lambda: spikes(1), "Spike2": lambda: spikes(2),
    "PetStand": pet_stand, "TorchPost": torch_post,
    "EggCommon": lambda: egg("Common"), "EggRare": lambda: egg("Rare"),
    "Nest": nest, "Wagon": wagon,
    "Axe1": lambda: axe(1), "Axe2": lambda: axe(2), "Axe3": lambda: axe(3), "Pick2": lambda: pick(2), "Pick3": lambda: pick(3),
    "Spear1": lambda: spear(1), "Spear2": lambda: spear(2), "Spear3": lambda: spear(3), "Spear4": lambda: spear(4), "TorchTool": torch_tool,
}


def build_all(names, render=False):
    os.makedirs(OUT, exist_ok=True)
    reset()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    objs, report = [], []
    x = 0.0
    for name in names:
        obj, size = ASSETS[name]()
        co = np.array([v.co[:] for v in obj.data.vertices])
        lo, hi = co.min(axis=0), co.max(axis=0)
        # 앞서 만든 에셋이 원점 근처에 있으면 그림자(AO)가 묻는다 → 구울 때는 숨긴다
        for other in objs:
            other.hide_render = True
        bake(obj, material_color, size, os.path.join(OUT, name + ".png"), ao_strength=0.75, ao_distance=1.2)
        for other in objs:
            other.hide_render = False
        # 에셋 원점(바닥 가운데) 기준 상자 중심 → Roblox 축 (X, Y=높이, Z=-Blender Y)
        centre = (lo + hi) / 2
        dims = hi - lo
        report.append((name, triangle_count(obj), dims, centre))
        obj.location.x = x - lo[0]
        x += dims[0] + 2.0
        objs.append(obj)
        print(f"{name:11s} 삼각형 {report[-1][1]:5d}  크기 {dims[0]:.1f} x {dims[1]:.1f} x {dims[2]:.1f}")

    fbx = os.path.join(OUT, "BuildModels.fbx")
    select_only(*objs)
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"}, path_mode="COPY", embed_textures=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL")
    with open(SIZES_LUA, "w") as f:
        f.write("-- blender/build_kit.py 가 만든 건축 키트 에셋 크기 (자동 생성 · 손으로 고치지 마세요)\n")
        f.write("-- Size = Roblox 축 크기 (X, Y=높이, Z), Center = 바닥 가운데(원점)에서 상자 중심까지 (Roblox 축, -Z = 앞)\n")
        f.write("return {\n")
        for name, tris, dims, c in report:
            f.write(f"\t{name} = {{Size = {{{dims[0]:.3f}, {dims[2]:.3f}, {dims[1]:.3f}}}, Center = {{{c[0]:.3f}, {c[2]:.3f}, {-c[1]:.3f}}}, Tris = {tris}}},\n")
        f.write("}\n")
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "BuildModels.blend"), compress=True)
    if render:
        from env_kit import render_lineup
        render_lineup(objs, out=os.path.join(ROOT, "docs", "images", "build_kit.png"), tile=420)
    return report


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build_all(args or list(ASSETS), render="--render" in sys.argv)
