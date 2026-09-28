"""WILDHOLD 펫 4종 정의. 모든 디자인은 WILDHOLD 독자 디자인이다.

좌표: Blender 단위, Z 위, -Y 정면. 크기는 게임 코드가 종별 목표 높이로 다시 맞춘다.
"""
from __future__ import annotations

import numpy as np

from creature_lib import Bone, Creature, Part
from sdf import (Chain, Displace, Ellipsoid, HalfSpace, Intersect, Leaf, RoundCone, Sphere, Subtract, Union,
                 frame, hex_rgb, mix, rot, smoothstep, value_noise)

C = hex_rgb


def paint(base):
    """단색 칠하기."""
    col = C(base)
    return lambda p, n: np.tile(col, (len(p), 1))


def eye_part(name, center, radii, r, iris, iris_light, highlight=(-0.35, 0.4)):
    """반짝이는 큰 눈. 정면 평면 좌표로 동공·홍채·하이라이트 두 개를 칠한다."""
    shape = Ellipsoid(center, radii, r)
    c = np.asarray(center)
    R = r

    def color(p, n):
        q = (p - c) @ R  # 눈 로컬 좌표: x 가로, z 세로, -y 정면
        u = q[:, 0] / radii[0]
        v = q[:, 2] / radii[2]
        front = -q[:, 1] / radii[1]
        rad = np.sqrt(u * u + v * v)
        out = np.tile(C("#1c1d2b"), (len(p), 1))
        # 홍채: 아래쪽이 밝은 그라데이션 고리
        ring = smoothstep(0.30, 0.42, rad) * (1 - smoothstep(0.78, 0.9, rad))
        iris_col = mix(np.tile(C(iris_light), (len(p), 1)), np.tile(C(iris), (len(p), 1)), smoothstep(-0.8, 0.5, v))
        out = mix(out, iris_col, ring * 0.95)
        # 테두리 어둡게
        out = mix(out, np.tile(C("#12121a"), (len(p), 1)), smoothstep(0.86, 0.98, rad))
        # 하이라이트 (큰 것 + 작은 것)
        hx, hy = highlight
        big = np.sqrt((u - hx) ** 2 + (v - hy) ** 2)
        small = np.sqrt((u + hx * 0.8) ** 2 + (v + hy * 0.75) ** 2)
        glint = np.maximum(1 - smoothstep(0.17, 0.22, big), 0.9 * (1 - smoothstep(0.07, 0.1, small)))
        glint = glint * (front > 0.2)
        out = mix(out, np.tile(C("#ffffff"), (len(p), 1)), glint)
        return out

    return Part(name, shape, color, bone="Head", tris=260, voxel=0.0035, rough=0.1)


# ============================================================ Mossling (모슬링)

def mossling():
    head_c = np.array([0.0, -0.05, 0.62])
    body = Union(
        Ellipsoid(head_c, (0.38, 0.34, 0.33)),
        Ellipsoid((0, 0.12, 0.34), (0.28, 0.32, 0.26)),
        # 볼 털뭉치
        Ellipsoid((-0.33, -0.1, 0.5), (0.09, 0.07, 0.07), rot(0, 0, 25)),
        Ellipsoid((0.33, -0.1, 0.5), (0.09, 0.07, 0.07), rot(0, 0, -25)),
        # 작은 주둥이 볼록
        Ellipsoid((0, -0.35, 0.52), (0.12, 0.06, 0.08)),
        # 앞다리 + 발
        RoundCone((-0.15, -0.06, 0.26), (-0.16, -0.12, 0.07), 0.085, 0.075),
        RoundCone((0.15, -0.06, 0.26), (0.16, -0.12, 0.07), 0.085, 0.075),
        Ellipsoid((-0.16, -0.15, 0.05), (0.085, 0.11, 0.055)),
        Ellipsoid((0.16, -0.15, 0.05), (0.085, 0.11, 0.055)),
        # 뒷다리 (통통한 허벅지) + 발
        Ellipsoid((-0.2, 0.22, 0.2), (0.13, 0.16, 0.14)),
        Ellipsoid((0.2, 0.22, 0.2), (0.13, 0.16, 0.14)),
        Ellipsoid((-0.2, 0.12, 0.05), (0.09, 0.13, 0.055)),
        Ellipsoid((0.2, 0.12, 0.05), (0.09, 0.13, 0.055)),
        # 솜뭉치 꼬리
        Sphere((0, 0.45, 0.36), 0.1),
        k=0.07,
    )
    body = Displace(body, lambda p: (value_noise(p, 22, 3) - 0.5) * 0.008)
    eyes = [((side * 0.15, -0.345, 0.645), (0.078, 0.042, 0.098), rot(-6, 0, side * 22)) for side in (-1, 1)]
    for c, radii, R in eyes:
        body = Subtract(body, Ellipsoid(c, tuple(r * 1.04 for r in radii), R), k=0.012)

    def body_color(p, n):
        noise = value_noise(p, 6, 1)
        speck = value_noise(p, 16, 2)
        base = mix(np.tile(C("#72c867"), (len(p), 1)), np.tile(C("#86d578"), (len(p), 1)), noise)
        # 등줄기 이끼 (조금 진한 초록) + 옅은 이끼 얼룩
        spine = (1 - smoothstep(0.1, 0.24, np.abs(p[:, 0]))) * smoothstep(0.0, 0.3, p[:, 1]) * smoothstep(0.35, 0.55, p[:, 2])
        base = mix(base, np.tile(C("#5aac56"), (len(p), 1)), spine * 0.6)
        base = mix(base, np.tile(C("#63b65c"), (len(p), 1)), smoothstep(0.66, 0.8, speck) * 0.35)
        # 크림색: 가슴 한가운데 + 주둥이 + 배 아래
        chest = (1 - smoothstep(0.1, 0.17, np.abs(p[:, 0]))) * smoothstep(-0.1, -0.5, n[:, 1]) * \
            smoothstep(0.1, 0.18, p[:, 2]) * (1 - smoothstep(0.4, 0.47, p[:, 2]))
        muzzle = (1 - smoothstep(0.15, 0.19, np.sqrt((p[:, 0] / 1.3) ** 2 + ((p[:, 2] - 0.5) / 0.8) ** 2))) * smoothstep(-0.22, -0.3, p[:, 1])
        belly = smoothstep(-0.4, -0.85, n[:, 2]) * (1 - smoothstep(0.16, 0.22, np.abs(p[:, 0]))) * (p[:, 2] > 0.1)
        cream = np.maximum(np.maximum(chest, muzzle), belly)
        base = mix(base, np.tile(C("#f5efcf"), (len(p), 1)), cream)
        # 발끝
        base = mix(base, np.tile(C("#eef4d0"), (len(p), 1)), 1 - smoothstep(0.045, 0.075, p[:, 2]))
        # 꼬리 끝 밝게
        tail = 1 - smoothstep(0.05, 0.11, np.linalg.norm(p - np.array([0, 0.52, 0.38]), axis=1))
        base = mix(base, np.tile(C("#e2f6c6"), (len(p), 1)), tail)
        # 볼터치
        for sx in (-1, 1):
            d = np.linalg.norm(p - np.array([sx * 0.235, -0.3, 0.52]), axis=1)
            base = mix(base, np.tile(C("#f49aa6"), (len(p), 1)), (1 - smoothstep(0.03, 0.065, d)) * 0.85)
        # 코 + ω 입
        front = p[:, 1] < -0.3
        nose = 1 - smoothstep(0.012, 0.02, np.sqrt(p[:, 0] ** 2 + ((p[:, 2] - 0.55) * 1.4) ** 2))
        x = p[:, 0]
        mouth_z = 0.518 - 0.014 * np.abs(np.sin(x / 0.045 * np.pi))
        mouth = (np.abs(p[:, 2] - mouth_z) < 0.0055) * (np.abs(x) < 0.045) * front
        base = mix(base, np.tile(C("#d56d7c"), (len(p), 1)), nose * front)
        base = mix(base, np.tile(C("#3a2a2c"), (len(p), 1)), mouth.astype(float))
        return base

    parts = [Part("Body", body, body_color, tris=5200, voxel=0.0065)]

    # 잎사귀 귀: 위·바깥·살짝 뒤로 뻗고, 넓은 면이 정면을 본다
    for side, name in ((-1, "EarL"), (1, "EarR")):
        R = frame((side * 0.42, 0.3, 0.86), (1, 0, 0))
        base = np.array([side * 0.19, 0.0, 0.86])
        center = base + R[:, 1] * 0.24
        leaf = Leaf(center, 0.27, 0.115, 0.024, R, curl=0.6)

        def leaf_color(p, n, center=center, R=R):
            q = (p - center) @ R
            t = q[:, 1] / 0.27
            col = mix(np.tile(C("#4eab55"), (len(p), 1)), np.tile(C("#8fdc7c"), (len(p), 1)), smoothstep(-1, 0.9, t))
            vein = (1 - smoothstep(0.006, 0.013, np.abs(q[:, 0]))) * (t < 0.85)
            side_v = 1 - smoothstep(0.003, 0.007, np.abs(((q[:, 1] - np.abs(q[:, 0]) * 1.2) % 0.07) - 0.035))
            col = mix(col, np.tile(C("#3d8c45"), (len(p), 1)), vein * 0.9)
            col = mix(col, np.tile(C("#4a9f4f"), (len(p), 1)), side_v * (np.abs(q[:, 0]) < 0.08) * (t < 0.8) * 0.45)
            # 안쪽 면(정면)은 조금 더 밝게
            inner = smoothstep(0.2, 0.8, np.abs(n @ R[:, 2]))
            return mix(col, np.tile(C("#b5e89a"), (len(p), 1)), inner * 0.2)

        parts.append(Part(name, leaf, leaf_color, bone=name, tris=420, voxel=0.004))

    # 머리 위 새싹
    sprout = Union(
        RoundCone((0, -0.03, 0.92), (0.01, -0.02, 1.04), 0.018, 0.013),
        Leaf((-0.05, -0.02, 1.07), 0.065, 0.04, 0.012, frame((-1, 0, 0.7), (0, 1, 0)), curl=0.4),
        Leaf((0.065, -0.015, 1.075), 0.075, 0.045, 0.012, frame((1, 0, 0.6), (0, 1, 0)), curl=0.4),
        k=0.012,
    )

    def sprout_color(p, n):
        return mix(np.tile(C("#6a9a48"), (len(p), 1)), np.tile(C("#8ad874"), (len(p), 1)), smoothstep(1.02, 1.06, p[:, 2]))

    parts.append(Part("Sprout", sprout, sprout_color, bone="Sprout", tris=300, voxel=0.0035))

    for (c, radii, R), name, side in zip(eyes, ("EyeL", "EyeR"), (-1, 1)):
        parts.append(eye_part(name, c, radii, R, iris="#1f5a4c", iris_light="#7fd6a0", highlight=(-0.3 * side - 0.1, 0.38)))

    bones = [
        Bone("Root", (0, 0.05, 0), (0, 0.05, 0.12), deform=False),
        Bone("Body", (0, 0.2, 0.3), (0, -0.02, 0.4), "Root", radius=0.24),
        Bone("Head", (0, -0.05, 0.52), (0, -0.05, 0.86), "Body", radius=0.34),
        Bone("EarL", (-0.19, 0.0, 0.86), (-0.3, 0.12, 1.28), "Head", radius=0.1),
        Bone("EarR", (0.19, 0.0, 0.86), (0.3, 0.12, 1.28), "Head", radius=0.1),
        Bone("Sprout", (0, -0.03, 0.92), (0, -0.02, 1.1), "Head", radius=0.06),
        Bone("Tail", (0, 0.36, 0.34), (0, 0.52, 0.38), "Body", radius=0.09),
        Bone("LegFL", (-0.15, -0.06, 0.26), (-0.16, -0.14, 0.02), "Body", radius=0.1),
        Bone("LegFR", (0.15, -0.06, 0.26), (0.16, -0.14, 0.02), "Body", radius=0.1),
        Bone("LegBL", (-0.2, 0.22, 0.24), (-0.2, 0.12, 0.02), "Body", radius=0.12),
        Bone("LegBR", (0.2, 0.22, 0.24), (0.2, 0.12, 0.02), "Body", radius=0.12),
        Bone("Front", (0, -0.4, 0.55), (0, -0.5, 0.55), "Head", deform=False),
    ]
    return Creature("Mossling", parts, bones, notes={"test_pose": {
        "Head": (12, 0, 14), "LegFL": (-35, 0, 0), "LegBR": (30, 0, 0), "EarL": (0, 0, 25), "Tail": (0, 0, 30)}})




def T(h, p):
    return np.tile(C(h), (len(p), 1))


def blush_and_mouth(base, p, cheek_pts, nose_c, mouth_c, mouth_w, front_y, nose_col="#3a2a2c", nose_r=0.02, mouth_col="#3a2a2c"):
    for c in cheek_pts:
        d = np.linalg.norm(p - np.array(c), axis=1)
        base = mix(base, T("#f59aa8", p), (1 - smoothstep(0.025, 0.06, d)) * 0.8)
    front = p[:, 1] < front_y
    nose = 1 - smoothstep(nose_r * 0.7, nose_r, np.linalg.norm((p - np.array(nose_c)) * np.array([1, 0.6, 1.3]), axis=1))
    base = mix(base, T(nose_col, p), nose * front)
    x = p[:, 0] - mouth_c[0]
    mz = mouth_c[2] - 0.012 * np.abs(np.sin(x / mouth_w * np.pi))
    mouth = (np.abs(p[:, 2] - mz) < 0.005) * (np.abs(x) < mouth_w) * front
    return mix(base, T(mouth_col, p), mouth.astype(float))


# ============================================================ Emberpup (엠버펍)

def emberpup():
    eyes = [((s * 0.13, -0.425, 0.69), (0.066, 0.036, 0.082), rot(-4, 0, s * 24)) for s in (-1, 1)]
    tail_pts = [(0, 0.3, 0.4), (0, 0.5, 0.5), (0, 0.6, 0.7), (0, 0.55, 0.88)]
    body = Union(
        Ellipsoid((0, -0.2, 0.66), (0.3, 0.26, 0.26)),
        Ellipsoid((0, -0.45, 0.585), (0.12, 0.13, 0.085), rot(-10, 0, 0)),
        RoundCone((-0.24, -0.26, 0.56), (-0.37, -0.21, 0.5), 0.07, 0.015),
        RoundCone((0.24, -0.26, 0.56), (0.37, -0.21, 0.5), 0.07, 0.015),
        Ellipsoid((0, 0.1, 0.38), (0.22, 0.3, 0.21)),
        Ellipsoid((0, -0.1, 0.42), (0.17, 0.13, 0.16)),
        RoundCone((-0.11, -0.07, 0.3), (-0.12, -0.1, 0.06), 0.065, 0.052),
        RoundCone((0.11, -0.07, 0.3), (0.12, -0.1, 0.06), 0.065, 0.052),
        Ellipsoid((-0.12, -0.13, 0.04), (0.062, 0.085, 0.042)),
        Ellipsoid((0.12, -0.13, 0.04), (0.062, 0.085, 0.042)),
        Ellipsoid((-0.15, 0.24, 0.25), (0.1, 0.13, 0.13)),
        Ellipsoid((0.15, 0.24, 0.25), (0.1, 0.13, 0.13)),
        RoundCone((-0.15, 0.24, 0.2), (-0.15, 0.2, 0.06), 0.065, 0.05),
        RoundCone((0.15, 0.24, 0.2), (0.15, 0.2, 0.06), 0.065, 0.05),
        Ellipsoid((-0.15, 0.15, 0.04), (0.062, 0.09, 0.042)),
        Ellipsoid((0.15, 0.15, 0.04), (0.062, 0.09, 0.042)),
        Chain(tail_pts, [0.065, 0.13, 0.15, 0.1], k=0.05),
        k=0.06,
    )
    body = Displace(body, lambda p: (value_noise(p, 24, 5) - 0.5) * 0.008)
    for c, radii, R in eyes:
        body = Subtract(body, Ellipsoid(c, tuple(r * 1.04 for r in radii), R), k=0.01)

    def body_color(p, n):
        base = mix(T("#f07f3e", p), T("#f89a55", p), value_noise(p, 6, 7))
        back = smoothstep(0.45, 0.62, p[:, 2]) * smoothstep(-0.1, 0.25, p[:, 1]) * (1 - smoothstep(0.12, 0.2, np.abs(p[:, 0])))
        base = mix(base, T("#d9612d", p), back * 0.55)
        # 크림: 주둥이 아래·가슴·볼 털·배
        muzzle = smoothstep(-0.36, -0.44, p[:, 1]) * (1 - smoothstep(0.585, 0.62, p[:, 2]))
        cheeks = smoothstep(0.26, 0.33, np.abs(p[:, 0])) * (1 - smoothstep(0.58, 0.63, p[:, 2])) * (p[:, 1] < -0.12)
        chest = (1 - smoothstep(0.09, 0.15, np.abs(p[:, 0]))) * smoothstep(-0.2, -0.6, n[:, 1]) * (p[:, 2] > 0.2) * (p[:, 2] < 0.56)
        belly = smoothstep(-0.4, -0.85, n[:, 2]) * (p[:, 2] > 0.12)
        base = mix(base, T("#fff0da", p), np.maximum.reduce([muzzle, cheeks, chest, belly]))
        # 짙은 갈색 양말
        base = mix(base, T("#6b3a2b", p), 1 - smoothstep(0.1, 0.16, p[:, 2]))
        # 꼬리: 끝으로 갈수록 크림
        tip = 1 - smoothstep(0.06, 0.16, np.linalg.norm(p - np.array(tail_pts[-1]), axis=1))
        base = mix(base, T("#fff3dc", p), tip)
        # 볼의 불씨 주근깨 (노랑 점 3개씩)
        for s in (-1, 1):
            for dx, dz in ((0.0, 0.0), (0.035, 0.025), (0.045, -0.02)):
                c = np.array([s * (0.2 + dx), -0.36, 0.6 + dz])
                base = mix(base, T("#ffd35a", p), 1 - smoothstep(0.007, 0.012, np.linalg.norm(p - c, axis=1)))
        return blush_and_mouth(base, p, [], (0, -0.575, 0.6), (0, -0.55, 0.535), 0.035, -0.45, nose_col="#2b1d1d", nose_r=0.03)

    parts = [Part("Body", body, body_color, tris=5400, voxel=0.0065)]

    for side, name in ((-1, "EarL"), (1, "EarR")):
        R = frame((side * 0.5, 0.18, 0.85), (1, 0, 0))
        base = np.array([side * 0.15, -0.14, 0.84])
        center = base + R[:, 1] * 0.17
        ear = Leaf(center, 0.2, 0.12, 0.04, R, curl=-0.3)

        def ear_color(p, n, center=center, R=R):
            q = (p - center) @ R
            t = q[:, 1] / 0.2
            col = T("#f07f3e", p)
            inner = smoothstep(0.1, 0.5, -(n @ R[:, 2])) * (1 - smoothstep(0.55, 0.8, np.abs(q[:, 0]) / (0.12 * np.clip(1 - np.abs(t) ** 1.6, 0.05, 1))))
            col = mix(col, T("#ffd9c0", p), inner)
            return mix(col, T("#4a2a22", p), smoothstep(0.45, 0.6, t))

        parts.append(Part(name, ear, ear_color, bone=name, tris=380, voxel=0.004))

    tip = np.array(tail_pts[-1])
    flame = Union(
        Sphere(tip + (0, 0, 0.05), 0.12),
        RoundCone(tip + (0, -0.01, 0.06), tip + (0, -0.08, 0.46), 0.12, 0.01),
        RoundCone(tip + (-0.06, 0.02, 0.05), tip + (-0.2, -0.02, 0.3), 0.08, 0.008),
        RoundCone(tip + (0.06, 0.02, 0.05), tip + (0.2, 0.02, 0.27), 0.075, 0.008),
        RoundCone(tip + (0.0, 0.06, 0.03), tip + (0.03, 0.18, 0.26), 0.07, 0.008),
        k=0.05,
    )

    def flame_color(p, n):
        t = (p[:, 2] - tip[2]) / 0.42
        col = mix(T("#ff5a1f", p), T("#ffb02e", p), smoothstep(0.05, 0.5, t))
        return mix(col, T("#fff6b8", p), smoothstep(0.45, 0.95, t))

    parts.append(Part("Flame", flame, flame_color, bone="Tail2", tris=500, voxel=0.004))
    for (c, radii, R), name, side in zip(eyes, ("EyeL", "EyeR"), (-1, 1)):
        parts.append(eye_part(name, c, radii, R, iris="#8a2e14", iris_light="#ffc14d", highlight=(-0.3 * side - 0.1, 0.38)))

    bones = [
        Bone("Root", (0, 0.05, 0), (0, 0.05, 0.12), deform=False),
        Bone("Body", (0, 0.25, 0.36), (0, -0.08, 0.44), "Root", radius=0.2),
        Bone("Head", (0, -0.16, 0.52), (0, -0.2, 0.86), "Body", radius=0.3),
        Bone("EarL", (-0.15, -0.14, 0.84), (-0.33, -0.07, 1.14), "Head", radius=0.1),
        Bone("EarR", (0.15, -0.14, 0.84), (0.33, -0.07, 1.14), "Head", radius=0.1),
        Bone("Tail1", tail_pts[0], tail_pts[2], "Body", radius=0.11),
        Bone("Tail2", tail_pts[2], (0, 0.5, 1.3), "Tail1", radius=0.12),
        Bone("LegFL", (-0.11, -0.07, 0.3), (-0.12, -0.12, 0.02), "Body", radius=0.08),
        Bone("LegFR", (0.11, -0.07, 0.3), (0.12, -0.12, 0.02), "Body", radius=0.08),
        Bone("LegBL", (-0.15, 0.24, 0.26), (-0.15, 0.16, 0.02), "Body", radius=0.09),
        Bone("LegBR", (0.15, 0.24, 0.26), (0.15, 0.16, 0.02), "Body", radius=0.09),
        Bone("Front", (0, -0.58, 0.6), (0, -0.68, 0.6), "Head", deform=False),
        # 게임에서 불꽃 파티클을 붙이는 위치 표시용 뼈
        Bone("FlameTip", (0, 0.5, 1.12), (0, 0.5, 1.22), "Tail2", deform=False),
    ]
    return Creature("Emberpup", parts, bones, notes={"test_pose": {
        "Head": (-10, 0, -15), "LegFR": (-35, 0, 0), "LegBL": (30, 0, 0), "Tail1": (0, 0, 25), "Tail2": (0, 0, 25)}})


# ============================================================ Shellbub (셸버브)

def shellbub():
    eyes = [((s * 0.12, -0.6, 0.47), (0.062, 0.034, 0.074), rot(-4, 0, s * 25)) for s in (-1, 1)]
    body = Union(
        Ellipsoid((0, 0.05, 0.28), (0.34, 0.4, 0.22)),
        Ellipsoid((0, -0.4, 0.44), (0.27, 0.25, 0.23)),
        RoundCone((0, -0.2, 0.33), (0, -0.36, 0.4), 0.16, 0.18),
        Ellipsoid((-0.3, -0.22, 0.09), (0.1, 0.13, 0.075), rot(0, 0, 30)),
        Ellipsoid((0.3, -0.22, 0.09), (0.1, 0.13, 0.075), rot(0, 0, -30)),
        Ellipsoid((-0.3, 0.3, 0.09), (0.1, 0.13, 0.075), rot(0, 0, -30)),
        Ellipsoid((0.3, 0.3, 0.09), (0.1, 0.13, 0.075), rot(0, 0, 30)),
        RoundCone((0, 0.4, 0.2), (0, 0.6, 0.14), 0.075, 0.02),
        k=0.07,
    )
    for c, radii, R in eyes:
        body = Subtract(body, Ellipsoid(c, tuple(r * 1.04 for r in radii), R), k=0.01)

    def body_color(p, n):
        base = mix(T("#6fb6e6", p), T("#8cc9f0", p), value_noise(p, 5, 11))
        base = mix(base, T("#e8f7ff", p), smoothstep(-0.35, -0.8, n[:, 2]))
        face = smoothstep(-0.52, -0.62, p[:, 1]) * (1 - smoothstep(0.43, 0.48, p[:, 2]))
        base = mix(base, T("#e8f7ff", p), face)
        # 머리 위 물방울 무늬
        for c in ((-0.08, -0.4, 0.66), (0.1, -0.35, 0.665), (0.0, -0.28, 0.66)):
            base = mix(base, T("#b9e4ff", p), 1 - smoothstep(0.02, 0.03, np.linalg.norm(p - np.array(c), axis=1)))
        return blush_and_mouth(base, p, [(-0.2, -0.56, 0.42), (0.2, -0.56, 0.42)], (0, -0.66, 0.44), (0, -0.66, 0.405), 0.03, -0.55,
                               nose_col="#3a4a6a", nose_r=0.012)

    seeds = [np.array((0.0, 0.08, 0.72))]
    for i in range(6):
        a = np.radians(i * 60 + 30)
        seeds.append(np.array((np.cos(a) * 0.25, 0.08 + np.sin(a) * 0.27, 0.64)))
    for i in range(10):
        a = np.radians(i * 36)
        seeds.append(np.array((np.cos(a) * 0.4, 0.08 + np.sin(a) * 0.44, 0.44)))
    seeds = np.array(seeds)

    def voronoi(p):
        d = np.linalg.norm(p[:, None, :] - seeds[None, :, :], axis=2)
        d.sort(axis=1)
        return d[:, 1] - d[:, 0]

    dome = Intersect(Ellipsoid((0, 0.08, 0.3), (0.43, 0.47, 0.42)), HalfSpace((0, 0, 0.36), (0, 0, -1)), k=0.02)
    dome = Displace(dome, lambda p: 0.012 * (1 - smoothstep(0.0, 0.03, voronoi(p))))
    rim = Ellipsoid((0, 0.08, 0.37), (0.46, 0.5, 0.06))
    shell = Union(dome, rim, k=0.03)

    def shell_color(p, n):
        edge = 1 - smoothstep(0.005, 0.03, voronoi(p))
        plate = mix(T("#2f86a4", p), T("#3e9fbd", p), value_noise(p, 7, 13))
        plate = mix(plate, T("#5cc0d6", p), smoothstep(0.55, 0.9, n[:, 2]) * 0.3)
        col = mix(plate, T("#c9f1f2", p), edge)
        rim_band = 1 - smoothstep(0.38, 0.43, p[:, 2])
        return mix(col, T("#f2e2b3", p), rim_band)

    parts = [Part("Body", body, body_color, tris=4300, voxel=0.0065),
             Part("Shell", shell, shell_color, bone="Body", tris=2400, voxel=0.006)]

    for side, name in ((-1, "GillL"), (1, "GillR")):
        root = np.array([side * 0.2, -0.36, 0.52])
        fronds = []
        for tip, r in (((side * 0.38, -0.3, 0.72), 0.045), ((side * 0.43, -0.28, 0.58), 0.045), ((side * 0.39, -0.3, 0.44), 0.04)):
            fronds.append(RoundCone(root, tip, 0.035, 0.022))
            fronds.append(Sphere(tip, r))
        gill = Union(*fronds, k=0.02)

        def gill_color(p, n, root=root):
            t = np.linalg.norm(p - root, axis=1) / 0.25
            return mix(T("#ff7f98", p), T("#ffd0d9", p), smoothstep(0.6, 1.0, t))

        parts.append(Part(name, gill, gill_color, bone=name, tris=500, voxel=0.004))

    for (c, radii, R), name, side in zip(eyes, ("EyeL", "EyeR"), (-1, 1)):
        parts.append(eye_part(name, c, radii, R, iris="#1d3f7c", iris_light="#8fd3ff", highlight=(-0.3 * side - 0.1, 0.38)))

    bones = [
        Bone("Root", (0, 0.05, 0), (0, 0.05, 0.12), deform=False),
        Bone("Body", (0, 0.3, 0.3), (0, -0.15, 0.32), "Root", radius=0.3),
        Bone("Head", (0, -0.32, 0.38), (0, -0.42, 0.62), "Body", radius=0.26),
        Bone("GillL", (-0.2, -0.36, 0.52), (-0.42, -0.28, 0.6), "Head", radius=0.08),
        Bone("GillR", (0.2, -0.36, 0.52), (0.42, -0.28, 0.6), "Head", radius=0.08),
        Bone("Tail", (0, 0.4, 0.2), (0, 0.62, 0.14), "Body", radius=0.07),
        Bone("LegFL", (-0.24, -0.18, 0.16), (-0.34, -0.26, 0.04), "Body", radius=0.09),
        Bone("LegFR", (0.24, -0.18, 0.16), (0.34, -0.26, 0.04), "Body", radius=0.09),
        Bone("LegBL", (-0.24, 0.26, 0.16), (-0.34, 0.34, 0.04), "Body", radius=0.09),
        Bone("LegBR", (0.24, 0.26, 0.16), (0.34, 0.34, 0.04), "Body", radius=0.09),
        Bone("Front", (0, -0.64, 0.44), (0, -0.74, 0.44), "Head", deform=False),
    ]
    return Creature("Shellbub", parts, bones, notes={"test_pose": {
        "Head": (15, 0, 10), "LegFL": (-30, 0, 0), "LegBR": (25, 0, 0), "GillL": (0, 0, 20)}})


# ============================================================ Briarhorn α (브라이어혼)

def briarhorn():
    eyes = [((s * 0.13, -0.862, 1.4), (0.07, 0.036, 0.08), rot(-6, 0, s * 28)) for s in (-1, 1)]
    body = Union(
        Ellipsoid((0, 0.15, 0.8), (0.33, 0.55, 0.33)),
        Ellipsoid((0, -0.25, 0.86), (0.3, 0.26, 0.34)),
        RoundCone((0, -0.28, 0.98), (0, -0.56, 1.3), 0.21, 0.17),
        Ellipsoid((0, -0.66, 1.36), (0.25, 0.27, 0.23)),
        Ellipsoid((0, -0.9, 1.27), (0.13, 0.14, 0.11), rot(-12, 0, 0)),
        RoundCone((-0.18, -0.27, 0.72), (-0.18, -0.3, 0.1), 0.11, 0.07),
        RoundCone((0.18, -0.27, 0.72), (0.18, -0.3, 0.1), 0.11, 0.07),
        Ellipsoid((-0.2, 0.45, 0.74), (0.15, 0.21, 0.23)),
        Ellipsoid((0.2, 0.45, 0.74), (0.15, 0.21, 0.23)),
        RoundCone((-0.2, 0.5, 0.6), (-0.2, 0.55, 0.1), 0.1, 0.066),
        RoundCone((0.2, 0.5, 0.6), (0.2, 0.55, 0.1), 0.1, 0.066),
        Ellipsoid((-0.18, -0.31, 0.055), (0.072, 0.085, 0.06)),
        Ellipsoid((0.18, -0.31, 0.055), (0.072, 0.085, 0.06)),
        Ellipsoid((-0.2, 0.55, 0.055), (0.07, 0.085, 0.06)),
        Ellipsoid((0.2, 0.55, 0.055), (0.07, 0.085, 0.06)),
        Chain([(0, 0.66, 0.95), (0, 0.8, 0.88), (0, 0.86, 0.72)], [0.07, 0.06, 0.025], k=0.02),
        k=0.08,
    )
    body = Displace(body, lambda p: (value_noise(p, 20, 17) - 0.5) * 0.01)
    for c, radii, R in eyes:
        body = Subtract(body, Ellipsoid(c, tuple(r * 1.05 for r in radii), R), k=0.01)
    spots = [(-0.14, 0.1, 1.08), (0.15, 0.2, 1.07), (-0.2, 0.35, 1.0), (0.2, 0.45, 1.0), (0.0, 0.5, 1.1),
             (-0.07, 0.3, 1.12), (0.1, -0.05, 1.12), (-0.24, 0.0, 1.0), (0.26, 0.05, 0.98)]

    def body_color(p, n):
        base = mix(T("#b995df", p), T("#c9a9ea", p), value_noise(p, 5, 19))
        back = smoothstep(0.95, 1.12, p[:, 2]) * (p[:, 1] > -0.35)
        base = mix(base, T("#8d69c0", p), back * 0.7)
        belly = smoothstep(-0.3, -0.8, n[:, 2]) * (p[:, 2] > 0.3)
        base = mix(base, T("#efe4fb", p), belly)
        chest = (1 - smoothstep(0.1, 0.18, np.abs(p[:, 0]))) * smoothstep(-0.3, -0.7, n[:, 1]) * (p[:, 2] > 0.6) * (p[:, 2] < 1.1)
        base = mix(base, T("#efe4fb", p), chest)
        muzzle = smoothstep(-0.84, -0.94, p[:, 1])
        base = mix(base, T("#f3ebfb", p), muzzle)
        for c in spots:
            base = mix(base, T("#f6efff", p), 1 - smoothstep(0.025, 0.04, np.linalg.norm(p - np.array(c), axis=1)))
        # 눈썹 무늬 (조금 더 늠름하게)
        for s in (-1, 1):
            d = np.linalg.norm((p - np.array([s * 0.14, -0.84, 1.5])) * np.array([1, 1, 2.4]), axis=1)
            base = mix(base, T("#6d4b9c", p), (1 - smoothstep(0.035, 0.055, d)) * (p[:, 1] < -0.75))
        base = mix(base, T("#4b3a5c", p), 1 - smoothstep(0.1, 0.14, p[:, 2]))
        return blush_and_mouth(base, p, [(-0.19, -0.84, 1.3), (0.19, -0.84, 1.3)], (0, -1.03, 1.3), (0, -1.0, 1.22), 0.032, -0.95,
                               nose_col="#4a3159", nose_r=0.038)

    parts = [Part("Body", body, body_color, tris=5000, voxel=0.0075)]

    # 잎사귀 갈기: 목 둘레로 잎이 바깥·뒤로 퍼지는 칼라 + 이끼 뭉치
    neck_c = np.array([0, -0.4, 1.12])
    neck_axis = np.array([0, -0.6, 0.8]) / 1.0
    leaves = []
    for i in range(14):
        a = np.radians(i * (360 / 14))
        radial = np.array([np.cos(a), 0.45 * np.sin(a), 0.9 * np.sin(a)])
        if radial[2] < -0.55:
            continue
        radial = radial / np.linalg.norm(radial)
        direction = radial + np.array([0, 0.55, 0.1])
        R = frame(direction, np.cross(direction, radial) + np.array([0, 0, 0.01]))
        base = neck_c + radial * 0.19
        leaves.append(Leaf(base + R[:, 1] * 0.13, 0.17, 0.085, 0.022, R, curl=0.5))
    moss = [Sphere(neck_c + np.array([x, y, z]), r) for x, y, z, r in (
        (0, 0.02, 0.2, 0.1), (-0.14, 0.05, 0.14, 0.085), (0.14, 0.05, 0.14, 0.085), (0, 0.16, 0.12, 0.09),
        (-0.1, 0.24, 0.02, 0.07), (0.1, 0.24, 0.02, 0.07))]
    mane = Union(Union(*leaves), Displace(Union(*moss, k=0.04), lambda p: (value_noise(p, 26, 23) - 0.5) * 0.025), k=0.02)

    def mane_color(p, n):
        col = mix(T("#3f8c43", p), T("#7cc865", p), smoothstep(0.1, 0.3, np.linalg.norm(p - neck_c, axis=1)))
        col = mix(col, T("#58a84e", p), value_noise(p, 14, 29) * 0.4)
        return mix(col, T("#ff9ecf", p), smoothstep(0.85, 0.92, value_noise(p, 18, 31)))

    parts.append(Part("Mane", mane, mane_color, bone="Neck", tris=1600, voxel=0.0045))

    for side, name in ((-1, "EarL"), (1, "EarR")):
        R = frame((side * 0.9, 0.35, 0.3), (0, 0, 1))
        center = np.array([side * 0.21, -0.6, 1.48]) + R[:, 1] * 0.14
        ear = Leaf(center, 0.16, 0.08, 0.026, R, curl=0.4)

        def ear_color(p, n, center=center, R=R):
            q = (p - center) @ R
            col = T("#b995df", p)
            return mix(col, T("#f7c9e6", p), smoothstep(0.2, 0.6, np.abs(n @ R[:, 2])) * (1 - smoothstep(0.03, 0.06, np.abs(q[:, 0]))))

        parts.append(Part(name, ear, ear_color, bone=name, tris=260, voxel=0.004))

    # 가시덩굴 뿔: 가지 + 가시 + 작은 꽃
    antler_shapes = []
    flower_centers = []
    for s in (-1, 1):
        main = [(s * 0.1, -0.62, 1.54), (s * 0.22, -0.58, 1.78), (s * 0.38, -0.5, 1.95), (s * 0.47, -0.42, 2.15)]
        antler_shapes.append(Chain(main, [0.065, 0.05, 0.036, 0.016], k=0.02))
        antler_shapes.append(Chain([main[1], (s * 0.15, -0.72, 1.95), (s * 0.13, -0.76, 2.07)], [0.04, 0.026, 0.012], k=0.01))
        antler_shapes.append(Chain([main[2], (s * 0.55, -0.62, 2.03), (s * 0.64, -0.64, 2.1)], [0.032, 0.021, 0.01], k=0.01))
        for a, b in ((main[0], main[1]), (main[1], main[2]), (main[2], main[3])):
            for t, out in ((0.3, (s * 0.08, 0.06, 0.03)), (0.65, (0, -0.08, 0.04)), (0.85, (s * -0.05, 0.05, 0.05))):
                base = np.array(a) + (np.array(b) - np.array(a)) * t
                antler_shapes.append(RoundCone(base, base + np.array(out), 0.022, 0.002))
        flower_centers += [np.array(main[1]) + (s * 0.03, -0.04, 0.05), np.array(main[3]) + (0, 0, 0.035), (s * 0.14, -0.77, 2.09),
                           (s * 0.64, -0.64, 2.13)]
    antler = Union(*antler_shapes, k=0.008)

    def antler_color(p, n):
        col = mix(T("#6b5238", p), T("#6f9443", p), smoothstep(1.55, 2.0, p[:, 2]))
        thin = smoothstep(0.9, 1.0, value_noise(p, 40, 37))
        return mix(col, T("#efe2c0", p), thin * 0.3)

    parts.append(Part("Antlers", antler, antler_color, bone="Head", tris=1500, voxel=0.004))
    petals = []
    for c in flower_centers:
        c = np.asarray(c, float)
        petals.append(Sphere(c, 0.03))
        for i in range(5):
            a = np.radians(i * 72)
            petals.append(Ellipsoid(c + np.array([np.cos(a) * 0.042, np.sin(a) * 0.042, -0.005]), (0.034, 0.03, 0.013), rot(0, 0, i * 72)))

    def flower_color(p, n):
        d = np.min([np.linalg.norm(p - np.asarray(c, float), axis=1) for c in flower_centers], axis=0)
        return mix(T("#ffe27a", p), T("#ff8fc6", p), smoothstep(0.026, 0.034, d))

    parts.append(Part("Flowers", Union(*petals, k=0.005), flower_color, bone="Head", tris=500, voxel=0.0028))

    for (c, radii, R), name, side in zip(eyes, ("EyeL", "EyeR"), (-1, 1)):
        parts.append(eye_part(name, c, radii, R, iris="#3f7a1f", iris_light="#e8ff7a", highlight=(-0.3 * side - 0.1, 0.4)))

    bones = [
        Bone("Root", (0, 0.1, 0), (0, 0.1, 0.15), deform=False),
        Bone("Body", (0, 0.55, 0.8), (0, -0.2, 0.86), "Root", radius=0.36),
        Bone("Neck", (0, -0.26, 0.98), (0, -0.55, 1.28), "Body", radius=0.2),
        Bone("Head", (0, -0.6, 1.26), (0, -0.68, 1.6), "Neck", radius=0.28),
        Bone("EarL", (-0.21, -0.6, 1.48), (-0.48, -0.5, 1.57), "Head", radius=0.08),
        Bone("EarR", (0.21, -0.6, 1.48), (0.48, -0.5, 1.57), "Head", radius=0.08),
        Bone("Tail", (0, 0.66, 0.95), (0, 0.88, 0.7), "Body", radius=0.08),
        Bone("LegFL", (-0.18, -0.27, 0.74), (-0.18, -0.31, 0.02), "Body", radius=0.12),
        Bone("LegFR", (0.18, -0.27, 0.74), (0.18, -0.31, 0.02), "Body", radius=0.12),
        Bone("LegBL", (-0.2, 0.48, 0.74), (-0.2, 0.55, 0.02), "Body", radius=0.13),
        Bone("LegBR", (0.2, 0.48, 0.74), (0.2, 0.55, 0.02), "Body", radius=0.13),
        Bone("Front", (0, -1.04, 1.3), (0, -1.14, 1.3), "Head", deform=False),
    ]
    return Creature("Briarhorn", parts, bones, notes={"test_pose": {
        "Neck": (-15, 0, 0), "Head": (10, 0, 12), "LegFL": (-30, 0, 0), "LegBR": (28, 0, 0), "Tail": (0, 0, 25)}})


SPECIES = {"Mossling": mossling, "Emberpup": emberpup, "Shellbub": shellbub, "Briarhorn": briarhorn}
