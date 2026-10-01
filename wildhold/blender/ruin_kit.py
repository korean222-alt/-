"""WILDHOLD 유적 키트 (v2): 무너진 신전 기둥·아치·벽·석상 머리·제단·오벨리스크·반쯤 잠긴 탑·선돌, 보물상자(몸통·뚜껑),
지역 소품(흑요석 첨탑·수정 무리·거대 버섯·거대 뿌리·빛나는 식물·이끼 늘어진 나무).

파트로 조립한 대체 모델(src/shared/Visuals/Ruins.lua) 대신 쓰는 메쉬 에셋. 모두 한 FBX(assets/ruins/RuinModels.fbx)에 담아서
Studio 에서 한 번 가져오기 → ReplicatedStorage/RuinModels 로 옮기면 유적이 이 모델로 바뀐다 (없으면 파트 대체 모델).

  python3 blender/ruin_kit.py            # 전부 만들기
  python3 blender/ruin_kit.py --render   # + docs/images/ruin_kit.png 단체 사진

좌표 (build_kit 과 같음): 1 Blender 단위 = 1 stud. Z 위, 원점 = 바닥 가운데.
  Blender +Y = Roblox 의 앞(-Z). 보물상자 뚜껑(ChestLid)만 원점 = 경첩(뒤 위 모서리), 뚜껑은 경첩에서 앞(+Y)으로 뻗는다.
재질은 조각마다 정점 속성으로 나누고, 절차적 셰이더(깎은 돌 + 위쪽 이끼, 흑요석, 버섯 갓 …)를 텍스처 한 장으로 굽는다.
"""
from __future__ import annotations

import math
import os
import sys

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import sdf  # noqa: E402
import build_kit  # noqa: E402
from creature_lib import reset, select_only, triangle_count  # noqa: E402
from env_kit import bake, bark_color, cut_wood, fbm, tube  # noqa: E402
from build_kit import Kit, metal_color, plank_color, rot  # noqa: E402

OUT = os.path.join(ROOT, "assets", "ruins")
SIZES_LUA = os.path.join(ROOT, "src", "shared", "Config", "RuinSizes.lua")
MATS = ("mStone", "mStoneDark", "mMoss", "mGold", "mWood", "mIron", "mObsidian", "mLava", "mCrystal", "mCap", "mStem", "mGlow",
        "mGlowGreen", "mBark", "mLeaf", "mMossHang", "mVoid", "mRune", "mLog", "mCut")
# build_kit.Kit 이 쓰는 재질 목록을 이 키트의 것으로 바꾼다 (Kit 은 모듈 전역 MATS/ATTRS 를 본다)
build_kit.MATS = MATS
build_kit.ATTRS = MATS + ("rand", "smooth", "leaf", "tip", "cut")


# ================================================================ 조각 도우미

def raw(k, verts, faces, mat, smooth=True):
    """감기 방향을 내가 맞춘 면을 그대로 넣는다 (볼록하지 않은 모양: 홈 판 기둥, 반원통 뚜껑)."""
    values = {m: (1.0 if m == mat else 0.0) for m in MATS}
    values["rand"], values["smooth"] = k.rng.random(), 1.0 if smooth else 0.0
    k.mb.add(np.asarray(verts, float), [tuple(f) for f in faces], **values)


def lathe(k, profile, mat, sides=16, flutes=0, depth=0.0, M=None, offset=(0, 0, 0), jag=0.0, caps=(True, True), smooth=True):
    """(높이, 반지름) 단면을 Z 축으로 돌린 몸 (기둥·탑·버섯 대). flutes = 세로 홈 수, jag = 맨 위 단면을 들쭉날쭉 (부러진 기둥)."""
    M = np.eye(3) if M is None else np.asarray(M)
    off = np.asarray(offset, float)
    ang = np.linspace(0, 2 * math.pi, sides, endpoint=False)
    verts, faces = [], []
    rings = len(profile)
    for i, (z, r) in enumerate(profile):
        for j, a in enumerate(ang):
            rr = r * (1.0 - depth * 0.5 * (1 + math.cos(flutes * a))) if flutes else r
            zz = z + (k.rng.uniform(-jag, jag) if (jag and i == rings - 1) else 0.0)
            verts.append([rr * math.cos(a), rr * math.sin(a), zz])
    for i in range(rings - 1):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    if caps[0]:
        verts.append([0, 0, profile[0][0]])
        c = len(verts) - 1
        for j in range(sides):
            faces.append((c, (j + 1) % sides, j))
    if caps[1]:
        top = (rings - 1) * sides
        verts.append([0, 0, profile[-1][0] - (jag * 0.6 if jag else 0.0)])
        c = len(verts) - 1
        for j in range(sides):
            faces.append((c, top + j, top + (j + 1) % sides))
    verts = [M @ np.asarray(v) + off for v in verts]
    raw(k, verts, faces, mat, smooth)


class Xform(sdf.Shape):
    """SDF 모양을 돌리고 옮긴다 (R = 회전 행렬, t = 이동)."""

    def __init__(self, shape, R, t):
        self.shape, self.R, self.t = shape, np.asarray(R, float), np.asarray(t, float)

    def sdf(self, p):
        return self.shape.sdf((p - self.t) @ self.R)

    def bounds(self):
        lo, hi = self.shape.bounds()
        corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
        world = corners @ self.R.T + self.t
        return world.min(axis=0), world.max(axis=0)


class Box(sdf.Shape):
    """모서리를 둥글린 상자 (반 크기 h, 둥글기 r)."""

    def __init__(self, c, h, r=0.05, R=None):
        self.c, self.h, self.r = np.asarray(c, float), np.asarray(h, float), r
        self.R = np.eye(3) if R is None else np.asarray(R, float)

    def sdf(self, p):
        q = np.abs((p - self.c) @ self.R) - (self.h - self.r)
        return np.linalg.norm(np.maximum(q, 0), axis=-1) + np.minimum(q.max(axis=-1), 0) - self.r

    def bounds(self):
        m = np.linalg.norm(self.h)
        return self.c - m, self.c + m


def blob(k, shape, voxel, mat):
    verts, faces, _ = sdf.mesh_shape(shape, voxel=voxel, pad=voxel * 3)
    raw(k, verts, faces, mat, smooth=True)


def weather(shape, seed, big=0.18, small=0.05):
    return sdf.Displace(shape, lambda p: (fbm(p, 0.9, 3, seed) - 0.5) * big + (fbm(p, 4.0, 2, seed + 5) - 0.5) * small)


def ground_cut(shape, z=0.0):
    return sdf.Intersect(shape, sdf.HalfSpace((0, 0, z), (0, 0, -1)))


def rubble(k, centre, spread, n, size=0.6, mat="mStone"):
    for _ in range(n):
        p = np.asarray(centre, float) + np.array([k.rng.uniform(-spread, spread), k.rng.uniform(-spread, spread), 0])
        s = size * k.rng.uniform(0.5, 1.2)
        k.box(p + [0, 0, s * 0.35], (s * 1.2, s, s * 0.8), mat, R=rot(*k.rng.uniform(-25, 25, 3)), bevel=0.06, jitter=0.12)


# ================================================================ 재질 (굽기용 셰이더)

def ruin_stone(N, dark="#6f6a5e", light="#a39c8a", moss=0.9):
    """깎은 돌: 블록 이음매 · 갈라진 틈 · 지의류 · 위를 보는 면에 이끼 · 아래는 흙물."""
    v = N.obj()
    tone = N.noise(v, 1.3, 4.0, 0.6)
    base = N.mix(tone, dark, light)
    fine = N.noise(v, 28.0, 5.0, 0.7)
    base = N.mix(N.math("MULTIPLY", fine, 0.35), base, "#4f4b43")
    cracks = N.voronoi(N.obj((1, 1, 1.4)), 1.6, feature="DISTANCE_TO_EDGE")
    crack = N.math("MULTIPLY", N.ramp(cracks, 0.015, 0.0), N.ramp(N.noise(v, 2.0, 3.0), 0.45, 0.6))
    col = N.mix(crack, base, "#2a2824")
    stain = N.ramp(N.noise(N.obj((1, 1, 0.25)), 3.0, 3.0), 0.55, 0.75, 0.0, 0.5)
    col = N.mix(stain, col, "#4a4438")
    lichen = N.ramp(N.noise(v, 10.0, 6.0, 0.8), 0.62, 0.7, 0.0, 0.7)
    col = N.mix(lichen, col, "#b4b598")
    top = N.ramp(N.normal_z(), 0.25, 0.7)
    patch = N.ramp(N.noise(v, 1.8, 6.0, 0.7), 0.34, 0.46)
    mossf = N.math("MULTIPLY", N.math("MULTIPLY", top, patch), moss)
    col = N.mix(mossf, col, N.mix(N.noise(v, 24.0), "#34461f", "#566b2c"))
    dirt = N.ramp(N.pos("Z"), 0.0, 0.5, 0.7, 0.0)
    return N.mix(dirt, col, "#3a3027")


def material_color(N):
    col = ruin_stone(N)
    v = N.obj()
    spots = N.ramp(N.voronoi(N.obj(), 1.2), 0.0, 0.16, 1.0, 0.0)
    layers = [
        ("mStoneDark", ruin_stone(N, dark="#2f2d35", light="#504c58", moss=0.5)),
        ("mMoss", N.mix(N.noise(v, 18.0, 4.0), "#2f4219", "#5a7030")),
        ("mGold", N.mix(N.noise(v, 9.0, 3.0), "#9a7020", "#e8c25a")),
        ("mWood", plank_color(N, mid="#7a5532", dark="#4d331f", light="#9a7048")),
        ("mIron", metal_color(N)),
        ("mObsidian", N.mix(N.ramp(N.noise(N.obj((1, 1, 0.3)), 5.0, 4.0), 0.55, 0.75), N.mix(N.noise(v, 14.0), "#100d15", "#221b2c"), "#5b4a75")),
        ("mLava", N.mix(N.noise(v, 8.0, 3.0), "#ff5a12", "#ffc24a")),
        ("mCrystal", N.mix(N.noise(v, 5.0), "#5fd8f0", "#d8fffb")),
        ("mCap", N.mix(spots, N.mix(N.noise(v, 3.0, 4.0), "#8a2f22", "#c4553a"), "#efe3c6")),
        ("mStem", N.mix(N.noise(N.obj((5, 5, 0.6)), 12.0, 3.0), "#cbbd9e", "#efe4cc")),
        ("mGlow", N.color("#8ff5e8")),
        ("mGlowGreen", N.color("#b6ff8a")),
        ("mBark", bark_color(N, moss=0.6, lichen=0.4)),
        ("mLeaf", N.mix(N.noise(v, 10.0), "#253f1f", "#4f6b35")),
        ("mMossHang", N.mix(N.noise(N.obj((6, 6, 0.4)), 20.0, 3.0), "#4f6235", "#8a9a5c")),
        ("mVoid", N.color("#141210")),
        ("mRune", N.color("#7ef2e2")),
        ("mLog", bark_color(N, moss=0.4)),
        ("mCut", cut_wood(N)),
    ]
    for attr, layer in layers:
        col = N.mix(N.attr(attr), col, layer)
    return col


# ================================================================ 유적

def pillar_shaft(k, z0, z1, r0, r1, jag=0.0):
    zs = np.linspace(z0, z1, 6)
    prof = [(z, r0 + (r1 - r0) * (z - z0) / (z1 - z0) + 0.04 * math.sin((z - z0) / (z1 - z0) * math.pi)) for z in zs]
    lathe(k, prof, "mStone", sides=20, flutes=16, depth=0.1, jag=jag, caps=(False, True))


def pillar_base(k):
    k.box((0, 0, 0.4), (3.6, 3.6, 0.8), "mStone", bevel=0.1, jitter=0.05)
    lathe(k, [(0.8, 1.6), (0.95, 1.65), (1.1, 1.5), (1.25, 1.32)], "mStone", sides=20)


def ruin_pillar():
    k = Kit("RuinPillar", seed=201)
    pillar_base(k)
    pillar_shaft(k, 1.25, 11.9, 1.27, 1.12)
    lathe(k, [(11.9, 1.18), (12.2, 1.45), (12.55, 1.7)], "mStone", sides=20)
    k.box((0, 0, 13.0), (3.5, 3.5, 0.9), "mStone", bevel=0.1, jitter=0.06)
    rubble(k, (0, 0, 0), 2.6, 4, 0.5)
    return k.build(), 512


def ruin_pillar_broken():
    k = Kit("RuinPillarBroken", seed=202)
    pillar_base(k)
    pillar_shaft(k, 1.25, 6.3, 1.27, 1.2, jag=0.55)
    # 떨어져 나간 토막
    lathe(k, [(0, 1.2), (2.2, 1.2)], "mStone", sides=18, flutes=16, depth=0.1, M=rot(0, 90, 25), offset=(2.4, 1.9, 1.05))
    rubble(k, (0, 0, 0), 2.8, 6, 0.55)
    return k.build(), 512


def ruin_pillar_fallen():
    k = Kit("RuinPillarFallen", seed=203)
    for i, x in enumerate((-3.9, 0.0, 3.8)):
        yaw = k.rng.uniform(-8, 8)
        lathe(k, [(-1.6, 1.22), (1.6, 1.2)], "mStone", sides=20, flutes=16, depth=0.1, M=rot(0, 0, yaw) @ rot(0, 90, 0),
              offset=(x, k.rng.uniform(-0.3, 0.3), 1.0))
    k.box((6.6, 0.4, 0.8), (1.6, 3.4, 3.2), "mStone", R=rot(0, 12, 20), bevel=0.1, jitter=0.06)
    k.box((0, 0, 2.15), (5.5, 1.2, 0.08), "mMoss", R=rot(0, 0, 4), bevel=0.02, jitter=0.3)
    rubble(k, (0, 0, 0), 5.0, 6, 0.5)
    return k.build(), 512


def ruin_arch():
    k = Kit("RuinArch", seed=204)
    for x in (-5.5, 5.5):
        k.box((x, 0, 0.4), (3.5, 3.5, 0.8), "mStone", bevel=0.1, jitter=0.05)
        for i in range(5):
            k.box((x + k.rng.uniform(-0.06, 0.06), k.rng.uniform(-0.06, 0.06), 1.8 + i * 2.0), (3.0, 3.0, 1.96), "mStone", bevel=0.1, jitter=0.07)
        k.box((x, 0, 11.1), (3.5, 3.4, 0.6), "mStone", bevel=0.08, jitter=0.04)
    for i in range(9):
        theta = math.pi - i * math.pi / 8
        pos = (math.cos(theta) * 5.5, 0, 11.4 + math.sin(theta) * 5.5)
        size = (2.0, 3.0, 2.3) if i != 4 else (2.4, 3.3, 2.8)
        k.box(pos, size, "mStone", R=rot(0, 90 - math.degrees(theta), 0), bevel=0.1, jitter=0.06)
    # 아치 위 이끼와 늘어진 덩굴
    for i in (2, 3, 5, 6):
        theta = math.pi - i * math.pi / 8
        k.box((math.cos(theta) * 5.5, 0, 11.4 + math.sin(theta) * 6.7), (1.6, 2.4, 0.15), "mMoss", R=rot(0, 90 - math.degrees(theta), 0), bevel=0.03, jitter=0.25)
    for x in (-3.4, 2.8):
        k.box((x, 1.3, 13.0), (0.25, 0.06, 2.6), "mMossHang", bevel=0.01, jitter=0.2)
    rubble(k, (0, 0, 0), 6.5, 8, 0.6)
    return k.build(), 512


def ruin_wall():
    k = Kit("RuinWall", seed=205)
    for row in range(4):
        count = 5 - row
        for i in range(count):
            if row > 0 and k.rng.random() < 0.18 * row:
                continue
            x = (i - (count - 1) / 2) * 2.4 + (row % 2) * 0.5 + k.rng.uniform(-0.1, 0.1)
            k.box((x, k.rng.uniform(-0.05, 0.05), 1.0 + row * 1.95), (2.32, 2.0, 1.9), "mStone", bevel=0.1, jitter=0.08)
    rubble(k, (0, 1.6, 0), 5.0, 7, 0.6)
    return k.build(), 512


def statue_head():
    k = Kit("RuinStatueHead", seed=206)
    head = sdf.Union(
        sdf.Ellipsoid((0, 0, 0), (2.3, 2.6, 2.9)),
        sdf.RoundCone((0, -2.25, 0.5), (0, -2.75, -0.35), 0.32, 0.5),
        sdf.Ellipsoid((0, -2.05, 1.05), (2.0, 0.65, 0.45)),
        sdf.Ellipsoid((0, -2.35, -1.05), (0.95, 0.4, 0.28)),
        sdf.Ellipsoid((-2.25, 0, 0.3), (0.35, 0.65, 0.95)),
        sdf.Ellipsoid((2.25, 0, 0.3), (0.35, 0.65, 0.95)),
        sdf.Ellipsoid((0, 0.25, 2.5), (2.55, 2.8, 1.0)),
        k=0.3)
    for x in (-0.85, 0.85):
        head = sdf.Subtract(head, sdf.Ellipsoid((x, -2.45, 0.45), (0.55, 0.42, 0.3)), k=0.08)
    head = sdf.Subtract(head, Box((1.6, -0.6, 2.6), (1.0, 1.2, 0.8), 0.1, rot(20, 10, 30)), k=0.05)  # 깨진 관
    shape = Xform(head, rot(-14, 0, 9), (0, 0, 2.2))
    shape = ground_cut(weather(shape, 61, 0.22, 0.06))
    blob(k, shape, 0.1, "mStone")
    rubble(k, (0, -1, 0), 3.0, 4, 0.5)
    return k.build(), 512


def altar():
    k = Kit("RuinAltar", seed=207)
    k.box((0, 0, 0.4), (6.4, 6.4, 0.8), "mStone", bevel=0.1, jitter=0.05)
    k.box((0, 0, 1.2), (5.0, 5.0, 0.8), "mStone", bevel=0.1, jitter=0.05)
    k.box((0, 0, 2.2), (3.6, 3.6, 1.2), "mStone", bevel=0.1, jitter=0.04)
    lathe(k, [(2.75, 1.45), (2.95, 1.55), (3.05, 1.2), (2.9, 0.0)], "mStone", sides=20, caps=(False, False))
    k.cyl((0, 0, 2.86), (0, 0, 2.92), 1.25, mat="mGlow", sides=20)
    for side in range(4):
        R = rot(0, 0, side * 90)
        for i in range(3):
            k.box(R @ np.array([(i - 1) * 0.9, -2.53, 1.2]), (0.5, 0.06, 0.45), "mRune", R=R, bevel=0.01)
    k.box((0, -3.25, 0.82), (1.8, 0.12, 0.12), "mGold", bevel=0.02)
    return k.build(), 512


def obelisk():
    k = Kit("RuinObelisk", seed=208)
    k.box((0, 0, 0.6), (3.4, 3.4, 1.2), "mStoneDark", bevel=0.12, jitter=0.05)
    b, t = 1.1, 0.75
    z0, z1 = 1.2, 13.6
    k.hull([(-b, -b, z0), (b, -b, z0), (b, b, z0), (-b, b, z0), (-t, -t, z1), (t, -t, z1), (t, t, z1), (-t, t, z1)], "mStoneDark")
    k.cone((0, 0, z1), t * 1.414, 2.0, sides=4, mat="mGold", R=rot(0, 0, 45))
    for face in (1, -1):
        for i in range(6):
            z = 3.0 + i * 1.7
            w = b - (b - t) * (z - z0) / (z1 - z0)
            k.box((0, face * (w + 0.02), z), (0.9 if i % 2 else 0.5, 0.05, 0.9), "mRune", bevel=0.01)
    rubble(k, (0, 0, 0), 2.6, 4, 0.45, "mStoneDark")
    return k.build(), 512


def tower():
    k = Kit("RuinTower", seed=209)
    M = rot(7, 0, -5)
    off = (0, 0, -0.6)
    prof = [(0.0, 4.6)]
    for c in range(8):
        z = 0.4 + c * 2.1
        r = 4.35 - c * 0.05
        prof += [(z, r), (z + 1.95, r), (z + 2.0, r - 0.12)]
    lathe(k, prof, "mStone", sides=24, M=M, offset=off, caps=(True, False))
    top = prof[-1][0]
    lathe(k, [(top, 3.9), (top + 0.05, 3.2), (top - 0.6, 3.2)], "mStoneDark", sides=24, M=M, offset=off, caps=(False, True))
    for i in range(8):
        if i in (3, 6):
            continue
        a = math.radians(i * 45)
        c = M @ np.array([math.cos(a) * 3.85, math.sin(a) * 3.85, top + 0.8]) + off
        k.box(c, (1.4, 1.5, 1.6), "mStone", R=M @ rot(0, 0, i * 45 + 90), bevel=0.08, jitter=0.06)
    for z, w, h in ((2.0, 2.4, 3.6), (9.0, 1.2, 2.2), (13.5, 1.2, 2.2)):
        c = M @ np.array([0, 4.3, z]) + off
        k.box(c, (w, 0.3, h), "mVoid", R=M, bevel=0.02)
    rubble(k, (0, 0, 0), 6.0, 10, 0.7)
    return k.build(), 1024


def standing_stone():
    k = Kit("StandingStone", seed=210)
    s = Box((0, 0, 3.5), (1.1, 0.68, 3.6), 0.45)
    s = sdf.Intersect(s, sdf.HalfSpace((0.7, 0, 7.0), (0.5, 0, 1)), k=0.2)
    s = ground_cut(weather(s, 71, 0.2, 0.05))
    blob(k, s, 0.11, "mStone")
    for i in range(3):
        k.box((0, 0.66, 2.6 + i * 1.1), (0.55 if i != 1 else 0.3, 0.06, 0.5), "mRune", bevel=0.01)
    return k.build(), 512


# ================================================================ 지역 소품

def obsidian_spire():
    k = Kit("ObsidianSpire", seed=211)
    k.cone((0, 0, -0.2), 1.9, 14.2, sides=5, mat="mObsidian", R=rot(3, -2, 10))
    for i in range(5):
        a = i / 5 * 2 * math.pi + 0.4
        base = (math.cos(a) * 1.6, math.sin(a) * 1.6, -0.2)
        k.cone(base, k.rng.uniform(0.6, 1.1), k.rng.uniform(3.0, 7.5), sides=5, mat="mObsidian",
               R=rot(math.degrees(-math.sin(a)) * 0.35, math.degrees(math.cos(a)) * 0.35, k.rng.uniform(0, 72)))
    for i in range(4):
        a = k.rng.uniform(0, 2 * math.pi)
        k.box((math.cos(a) * 2.4, math.sin(a) * 2.4, 0.03), (2.2, 0.25, 0.06), "mLava", R=rot(0, 0, math.degrees(a) + 90), bevel=0.01)
    rubble(k, (0, 0, 0), 3.0, 6, 0.6, "mStoneDark")
    return k.build(), 512


def crystal_cluster():
    k = Kit("CrystalCluster", seed=212)
    rock = ground_cut(weather(sdf.Ellipsoid((0, 0, 0.1), (1.9, 1.6, 0.8)), 81, 0.25, 0.05))
    blob(k, rock, 0.13, "mStoneDark")
    for i in range(8):
        a = i / 8 * 2 * math.pi + k.rng.uniform(-0.3, 0.3)
        tilt = 0 if i == 0 else k.rng.uniform(18, 38)
        h = 4.6 if i == 0 else k.rng.uniform(1.6, 3.2)
        r = 0.55 if i == 0 else k.rng.uniform(0.25, 0.42)
        base = np.array([0, 0, 0.3]) if i == 0 else np.array([math.cos(a) * 0.9, math.sin(a) * 0.8, 0.3])
        R = rot(-math.sin(a) * tilt, math.cos(a) * tilt, k.rng.uniform(0, 60))
        top = base + R @ np.array([0, 0, h * 0.78])
        k.cyl(base, top, r, r, sides=6, mat="mCrystal", smooth=False)
        k.cone(top, r, h * 0.22, sides=6, mat="mCrystal", R=R)
    return k.build(), 512


def giant_mushroom():
    k = Kit("GiantMushroom", seed=213)
    zs = np.linspace(0, 12.6, 8)
    lathe(k, [(z, 1.25 + 1.0 * math.exp(-z / 1.2) - 0.08 * z / 12.6) for z in zs], "mStem", sides=20, caps=(True, False))
    lathe(k, [(8.4, 1.2), (8.6, 2.6), (8.3, 2.7), (8.0, 1.25)], "mStem", sides=20, caps=(False, False))
    lathe(k, [(12.3, 1.2), (12.1, 3.5), (12.0, 6.8), (12.35, 7.1)], "mStem", sides=28, caps=(False, False))
    cap = [(12.35, 7.1)] + [(12.35 + 3.8 * math.sin(t * math.pi / 2), 7.1 * math.cos(t * math.pi / 2) ** 0.8) for t in np.linspace(0.1, 1.0, 7)]
    lathe(k, cap, "mCap", sides=28, caps=(False, False))
    for i in range(9):
        a = k.rng.uniform(0, 2 * math.pi)
        t = k.rng.uniform(0.3, 0.75)
        r = 7.1 * math.cos(t * math.pi / 2) ** 0.8
        z = 12.35 + 3.8 * math.sin(t * math.pi / 2)
        k.box((math.cos(a) * r, math.sin(a) * r, z + 0.05), (0.7, 0.7, 0.25), "mGlow", R=rot(0, 0, math.degrees(a)), bevel=0.08)
    for i in range(3):
        a = k.rng.uniform(0, 2 * math.pi)
        k.cyl((math.cos(a) * 2.4, math.sin(a) * 2.4, 0), (math.cos(a) * 2.5, math.sin(a) * 2.5, 1.4), 0.25, 0.22, mat="mStem", sides=8)
        k.cone((math.cos(a) * 2.5, math.sin(a) * 2.5, 1.35), 0.7, 0.5, sides=10, mat="mCap")
    return k.build(), 1024


def giant_root():
    k = Kit("GiantRoot", seed=214)
    mats = {m: (1.0 if m == "mBark" else 0.0) for m in MATS}
    for side, scale, yoff in ((0, 1.0, 0.0), (1, 0.55, 1.6), (-1, 0.5, -1.4)):
        n = 12
        t = np.linspace(0, 1, n)
        L = 16 * scale
        pts = np.column_stack([(t - 0.5) * L, yoff + np.sin(t * 5 + side) * 0.5 * scale, np.sin(t * math.pi) * 5.4 * scale - 0.7])
        radii = (1.5 - np.abs(t - 0.5) * 1.1) * scale + 0.25
        tube(k.mb, pts, radii, sides=12, rng=k.rng, bumps=0.08, tip=False, base_cap=True, **mats, rand=k.rng.random(), smooth=1.0)
    k.box((0, 0, 5.3), (3.0, 1.6, 0.12), "mMoss", bevel=0.02, jitter=0.3)
    return k.build(), 512


def glow_plant():
    k = Kit("GlowPlant", seed=215)
    for i in range(6):
        a = i / 6 * 2 * math.pi + k.rng.uniform(-0.3, 0.3)
        h = k.rng.uniform(1.6, 2.9)
        lean = k.rng.uniform(0.15, 0.4)
        pts = [np.array([math.cos(a) * lean * h * s * s, math.sin(a) * lean * h * s * s, h * s]) for s in np.linspace(0, 1, 5)]
        tube(k.mb, pts, [0.07, 0.06, 0.055, 0.05, 0.04], sides=5, tip=False, **{m: (1.0 if m == "mLeaf" else 0.0) for m in MATS},
             rand=k.rng.random(), smooth=1.0)
        blob(k, sdf.Ellipsoid(pts[-1] + [0, 0, 0.18], (0.26, 0.26, 0.34)), 0.09, "mGlowGreen")
    for i in range(5):
        a = i / 5 * 2 * math.pi
        d = np.array([math.cos(a), math.sin(a), 0])
        side = np.array([-math.sin(a), math.cos(a), 0])
        w = 0.05
        p0, p1 = d * 0.1, d * 1.1 + [0, 0, 0.35]
        k.hull([p0 - side * 0.05, p0 + side * 0.05, p1 + side * 0.25, p1 - side * 0.25,
                p0 - side * 0.05 + [0, 0, w], p0 + side * 0.05 + [0, 0, w], p1 + side * 0.25 + [0, 0, w], p1 - side * 0.25 + [0, 0, w]], "mLeaf")
    return k.build(), 256


def moss_tree():
    k = Kit("MossTree", seed=216)
    bark = {m: (1.0 if m == "mBark" else 0.0) for m in MATS}
    trunk = [np.array([0.2 * math.sin(z * 0.4), 0.15 * math.cos(z * 0.3), z]) for z in np.linspace(-0.2, 9.5, 8)]
    tube(k.mb, trunk, np.linspace(0.85, 0.3, 8), sides=10, rng=k.rng, bumps=0.1, tip=True, base_cap=True, **bark, rand=k.rng.random(), smooth=1.0)
    for i in range(5):
        a = i / 5 * 2 * math.pi + k.rng.uniform(-0.4, 0.4)
        z = k.rng.uniform(4.5, 8.5)
        d = np.array([math.cos(a), math.sin(a), 0])
        L = k.rng.uniform(2.5, 4.2)
        pts = [np.array([0, 0, z]) + d * L * s + np.array([0, 0, L * 0.45 * s - L * 0.25 * s * s]) for s in np.linspace(0, 1, 5)]
        tube(k.mb, pts, np.linspace(0.32, 0.08, 5), sides=7, rng=k.rng, bumps=0.08, tip=True, **bark, rand=k.rng.random(), smooth=1.0)
        for s in (0.55, 0.85, 1.0):
            p = np.array([0, 0, z]) + d * L * s + np.array([0, 0, L * 0.45 * s - L * 0.25 * s * s])
            hang = k.rng.uniform(1.5, 3.2)
            k.box(p - [0, 0, hang / 2], (0.45, 0.05, hang), "mMossHang", R=rot(0, 0, math.degrees(a) + 90 + k.rng.uniform(-30, 30)), bevel=0.01, jitter=0.25)
    for i in range(4):
        a = i / 4 * 2 * math.pi + 0.3
        d = np.array([math.cos(a), math.sin(a), 0])
        tube(k.mb, [d * 0.4 + [0, 0, 0.6], d * 1.2 + [0, 0, 0.1], d * 1.9 + [0, 0, -0.2]], [0.35, 0.22, 0.08], sides=6, rng=k.rng,
             bumps=0.1, tip=True, **bark, rand=k.rng.random(), smooth=1.0)
    return k.build(), 512


# ================================================================ 보물상자

def chest_base():
    k = Kit("ChestBase", seed=217)
    k.box((0, 0, 1.1), (4.3, 2.9, 2.2), "mWood", bevel=0.08)
    for x in (-1.5, 1.5):
        k.box((x, 0, 1.1), (0.35, 3.0, 2.25), "mIron", bevel=0.04)
    for x in (-2.15, 2.15):
        for y in (-1.45, 1.45):
            k.box((x, y, 1.1), (0.3, 0.3, 2.3), "mGold", bevel=0.05)
    k.box((0, 1.47, 1.65), (0.9, 0.12, 0.9), "mGold", bevel=0.05)
    k.box((0, 1.55, 1.55), (0.25, 0.08, 0.35), "mVoid", bevel=0.02)
    return k.build(), 512


def chest_lid():
    """원점 = 경첩 (뒤 위 모서리). 뚜껑은 +Y(앞)으로 3, 위로 둥글게 0.95."""
    k = Kit("ChestLid", seed=218)

    def arc_body(x0, x1, y0, y1, z0, height, mat, steps=10, grow=0.0):
        cy, ry = (y0 + y1) / 2, (y1 - y0) / 2 + grow
        ring = [(cy - ry * math.cos(t), z0 + (height + grow) * math.sin(t)) for t in np.linspace(0, math.pi, steps)]
        verts = [[x0, y, z] for y, z in ring] + [[x1, y, z] for y, z in ring]
        n = len(ring)
        faces = []
        for i in range(n - 1):
            faces.append((i, i + 1, n + i + 1, n + i))
        faces.append((0, n, 2 * n - 1, n - 1))  # 바닥
        faces.append(tuple(range(n - 1, -1, -1)))  # 왼쪽 끝 (-X)
        faces.append(tuple(range(n, 2 * n)))  # 오른쪽 끝 (+X)
        # 바깥을 보게: 면 법선이 몸 가운데에서 멀어지는 쪽인지 검사해서 뒤집는다
        V = np.asarray(verts, float)
        centre = np.array([(x0 + x1) / 2, cy, z0 + height * 0.4])
        fixed = []
        for f in faces:
            a, b, c = V[f[0]], V[f[1]], V[f[2]]
            nrm = np.cross(b - a, c - a)
            mid = V[list(f)].mean(axis=0)
            fixed.append(f if nrm @ (mid - centre) >= 0 else tuple(reversed(f)))
        raw(k, V, fixed, mat)

    arc_body(-2.15, 2.15, 0.0, 2.9, 0.0, 0.95, "mWood", steps=12)
    for x in (-1.5, 1.5):
        arc_body(x - 0.18, x + 0.18, -0.03, 2.93, -0.01, 0.95, "mIron", steps=12, grow=0.04)
    for x in (-2.2, 2.2):
        arc_body(x - 0.08, x + 0.08, -0.05, 2.95, -0.02, 0.95, "mGold", steps=12, grow=0.06)
    k.box((0, 2.95, 0.25), (0.9, 0.12, 0.5), "mGold", bevel=0.04)
    return k.build(), 512


# ================================================================ 목록

ASSETS = {
    "RuinPillar": ruin_pillar, "RuinPillarBroken": ruin_pillar_broken, "RuinPillarFallen": ruin_pillar_fallen, "RuinArch": ruin_arch,
    "RuinWall": ruin_wall, "RuinStatueHead": statue_head, "RuinAltar": altar, "RuinObelisk": obelisk, "RuinTower": tower,
    "StandingStone": standing_stone, "ObsidianSpire": obsidian_spire, "CrystalCluster": crystal_cluster, "GiantMushroom": giant_mushroom,
    "GiantRoot": giant_root, "GlowPlant": glow_plant, "MossTree": moss_tree, "ChestBase": chest_base, "ChestLid": chest_lid,
}
BUDGET = 4000  # 에셋 하나의 삼각형 상한 (넘으면 줄인다). 작은 소품은 더 적게
BUDGETS = {"GlowPlant": 900, "CrystalCluster": 1600, "StandingStone": 1600, "RuinStatueHead": 3500}


def decimate(obj, target):
    count = triangle_count(obj)
    if count <= target:
        return
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = target / count
    select_only(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def build_all(names, render=False):
    os.makedirs(OUT, exist_ok=True)
    reset()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    objs, report = [], []
    x = 0.0
    for name in names:
        obj, size = ASSETS[name]()
        decimate(obj, BUDGETS.get(name, BUDGET))
        co = np.array([v.co[:] for v in obj.data.vertices])
        lo, hi = co.min(axis=0), co.max(axis=0)
        for other in objs:
            other.hide_render = True
        bake(obj, material_color, size, os.path.join(OUT, name + ".png"), ao_strength=0.75, ao_distance=1.4)
        for other in objs:
            other.hide_render = False
        centre = (lo + hi) / 2
        dims = hi - lo
        report.append((name, triangle_count(obj), dims, centre))
        obj.location.x = x - lo[0]
        x += dims[0] + 2.0
        objs.append(obj)
        print(f"{name:17s} 삼각형 {report[-1][1]:5d}  크기 {dims[0]:.1f} x {dims[1]:.1f} x {dims[2]:.1f}", flush=True)

    fbx = os.path.join(OUT, "RuinModels.fbx")
    select_only(*objs)
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"}, path_mode="COPY", embed_textures=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL")
    with open(SIZES_LUA, "w") as f:
        f.write("-- blender/ruin_kit.py 가 만든 유적 키트 에셋 크기 (자동 생성 · 손으로 고치지 마세요)\n")
        f.write("-- Size = Roblox 축 크기 (X, Y=높이, Z), Center = 바닥 가운데(원점)에서 상자 중심까지 (Roblox 축, -Z = 앞)\n")
        f.write("return {\n")
        for name, tris, dims, c in report:
            f.write(f"\t{name} = {{Size = {{{dims[0]:.3f}, {dims[2]:.3f}, {dims[1]:.3f}}}, Center = {{{c[0]:.3f}, {c[2]:.3f}, {-c[1]:.3f}}}, Tris = {tris}}},\n")
        f.write("}\n")
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "RuinModels.blend"), compress=True)
    if render:
        from env_kit import render_lineup
        render_lineup(objs, out=os.path.join(ROOT, "docs", "images", "ruin_kit.png"), tile=420)
    return report


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build_all(args or list(ASSETS), render="--render" in sys.argv)
