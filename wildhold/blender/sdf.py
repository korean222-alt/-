"""SDF(부호 거리 함수) 조각 도구. numpy 로 벡터화되어 있고 Blender 없이도 동작한다.

펫 몸통은 타원체·둥근 원뿔을 부드럽게 이어 붙여(smooth union) 조각하듯 만든 뒤
marching cubes 로 메쉬를 뽑는다. 메타볼보다 반지름과 이음새를 정확히 제어할 수 있다.
좌표계: Blender 기준 Z 위, -Y 가 펫의 정면.
"""
from __future__ import annotations

import math

import numpy as np
from skimage.measure import marching_cubes


def rot(rx=0.0, ry=0.0, rz=0.0):
    """XYZ 오일러(도) → 3x3 회전 행렬 (local → world)."""
    rx, ry, rz = (math.radians(a) for a in (rx, ry, rz))
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    mx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    my = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    mz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return mz @ my @ mx


class Shape:
    def sdf(self, p):
        raise NotImplementedError

    def bounds(self):
        raise NotImplementedError


class Ellipsoid(Shape):
    def __init__(self, c, radii, r=None):
        self.c, self.radii = np.asarray(c, float), np.asarray(radii, float)
        self.R = r if r is not None else np.eye(3)

    def sdf(self, p):
        q = (p - self.c) @ self.R
        k0 = np.linalg.norm(q / self.radii, axis=-1)
        k1 = np.linalg.norm(q / (self.radii ** 2), axis=-1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)

    def bounds(self):
        m = self.radii.max()
        return self.c - m, self.c + m


def Sphere(c, r):
    return Ellipsoid(c, (r, r, r))


class RoundCone(Shape):
    """a 쪽 반지름 r1, b 쪽 반지름 r2 인 캡슐 (Inigo Quilez 공식)."""

    def __init__(self, a, b, r1, r2=None):
        self.a, self.b = np.asarray(a, float), np.asarray(b, float)
        self.r1, self.r2 = r1, (r1 if r2 is None else r2)

    def sdf(self, p):
        a, b, r1, r2 = self.a, self.b, self.r1, self.r2
        ba = b - a
        l2 = ba @ ba
        rr = r1 - r2
        a2 = l2 - rr * rr
        il2 = 1.0 / l2
        pa = p - a
        y = pa @ ba
        z = y - l2
        v = pa * l2 - np.outer(y, ba)
        x2 = np.einsum("ij,ij->i", v, v)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0)) + y * rr) * il2 - r1
        d1 = np.sqrt(x2 + z2) * il2 - r2
        d2 = np.sqrt(x2 + y2) * il2 - r1
        return np.where(np.sign(z) * a2 * z2 > k, d1, np.where(np.sign(y) * a2 * y2 < k, d2, d3))

    def bounds(self):
        m = max(self.r1, self.r2)
        return np.minimum(self.a, self.b) - m, np.maximum(self.a, self.b) + m


class Chain(Shape):
    """점 여러 개를 이어 만든 둥근 원뿔 사슬 (꼬리, 뿔, 덩굴)."""

    def __init__(self, points, radii, k=0.0):
        self.parts = [RoundCone(points[i], points[i + 1], radii[i], radii[i + 1]) for i in range(len(points) - 1)]
        self.k = k

    def sdf(self, p):
        d = self.parts[0].sdf(p)
        for part in self.parts[1:]:
            d = smin(d, part.sdf(p), self.k) if self.k > 0 else np.minimum(d, part.sdf(p))
        return d

    def bounds(self):
        lo, hi = zip(*(s.bounds() for s in self.parts))
        return np.min(lo, axis=0), np.max(hi, axis=0)


class Leaf(Shape):
    """잎 모양: 납작한 타원체의 끝을 뾰족하게 좁힌다. 길이 방향 = local Y."""

    def __init__(self, c, length, width, thick, r=None, curl=0.0):
        self.c = np.asarray(c, float)
        self.l, self.w, self.t = length, width, thick
        self.R = r if r is not None else np.eye(3)
        self.curl = curl

    def sdf(self, p):
        q = (p - self.c) @ self.R
        y = q[:, 1] / self.l  # -1..1
        # 폭은 끝으로 갈수록 좁아지고, 가운데가 살짝 접힌 모양 (잎맥)
        taper = np.clip(1.0 - np.abs(y) ** 1.6, 0.02, 1.0)
        x = q[:, 0] / (self.w * taper)
        z = (q[:, 2] - self.curl * (q[:, 0] / self.w) ** 2 * self.t * 3) / (self.t * np.sqrt(taper))
        k0 = np.sqrt(x * x + y * y + z * z)
        return (k0 - 1.0) * min(self.w, self.t * 2) * 0.9

    def bounds(self):
        m = max(self.l, self.w, self.t * 4)
        return self.c - m, self.c + m


class Union(Shape):
    def __init__(self, *shapes, k=0.0):
        self.shapes, self.k = shapes, k

    def sdf(self, p):
        d = self.shapes[0].sdf(p)
        for s in self.shapes[1:]:
            d = smin(d, s.sdf(p), self.k) if self.k > 0 else np.minimum(d, s.sdf(p))
        return d

    def bounds(self):
        lo, hi = zip(*(s.bounds() for s in self.shapes))
        return np.min(lo, axis=0), np.max(hi, axis=0)


class Subtract(Shape):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, k

    def sdf(self, p):
        return smax(self.a.sdf(p), -self.b.sdf(p), self.k)

    def bounds(self):
        return self.a.bounds()


class Intersect(Shape):
    def __init__(self, a, b, k=0.0):
        self.a, self.b, self.k = a, b, k

    def sdf(self, p):
        return smax(self.a.sdf(p), self.b.sdf(p), self.k)

    def bounds(self):
        return self.a.bounds()


class HalfSpace(Shape):
    """n·(p-c) > 0 쪽을 비운다 (Intersect 와 함께 써서 반구 등)."""

    def __init__(self, c, n):
        self.c, self.n = np.asarray(c, float), np.asarray(n, float) / np.linalg.norm(n)

    def sdf(self, p):
        return (p - self.c) @ self.n

    def bounds(self):
        return self.c - 10, self.c + 10


class Displace(Shape):
    def __init__(self, shape, fn):
        self.shape, self.fn = shape, fn

    def sdf(self, p):
        return self.shape.sdf(p) + self.fn(p)

    def bounds(self):
        lo, hi = self.shape.bounds()
        return lo - 0.05, hi + 0.05


def smin(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    if k <= 0:
        return np.maximum(a, b)
    return -smin(-a, -b, k)


def mesh_shape(shape, voxel=0.008, pad=0.04):
    """SDF → (verts, faces, normals). 메모리를 아끼려고 z 조각 단위로 평가한다."""
    lo, hi = shape.bounds()
    lo, hi = lo - pad, hi + pad
    dims = np.ceil((hi - lo) / voxel).astype(int) + 1
    xs = lo[0] + np.arange(dims[0]) * voxel
    ys = lo[1] + np.arange(dims[1]) * voxel
    zs = lo[2] + np.arange(dims[2]) * voxel
    field = np.empty(dims, dtype=np.float32)
    gx, gy = np.meshgrid(xs, ys, indexing="ij")
    flat = np.stack([gx.ravel(), gy.ravel()], axis=-1)
    for k, z in enumerate(zs):
        pts = np.column_stack([flat, np.full(len(flat), z)])
        field[:, :, k] = shape.sdf(pts).reshape(dims[0], dims[1])
    verts, faces, normals, _ = marching_cubes(field, level=0.0, spacing=(voxel, voxel, voxel))
    verts = verts + lo
    # skimage 는 바깥(+)에서 안(-)으로 향하는 법선을 준다 → 뒤집어서 바깥 방향으로
    faces = faces[:, ::-1]
    return verts, faces, -normals


# ---------- 색 도우미 ----------

def hex_rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def mix(a, b, t):
    t = np.clip(t, 0, 1)[:, None] if np.ndim(t) else np.clip(t, 0, 1)
    return a * (1 - t) + b * t


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def value_noise(p, scale=8.0, seed=0):
    """부드러운 3D 값 노이즈 (0..1). 털/이끼 얼룩용."""
    rng = np.random.default_rng(seed)
    table = rng.random(4096)
    q = p * scale
    i = np.floor(q).astype(np.int64)
    f = q - i
    f = f * f * (3 - 2 * f)

    def h(ix, iy, iz):
        return table[(ix * 73856093 ^ iy * 19349663 ^ iz * 83492791) % 4096]

    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + w * h(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz)
    return out


def frame(length_dir, width_hint):
    """잎·뿔처럼 길이 방향이 있는 모양의 회전 행렬. 열 = [폭(x), 길이(y), 두께(z)]."""
    y = np.asarray(length_dir, float)
    y = y / np.linalg.norm(y)
    x = np.asarray(width_hint, float)
    x = x - y * (x @ y)
    x = x / np.linalg.norm(x)
    z = np.cross(x, y)
    return np.column_stack([x, y, z])
