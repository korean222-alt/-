"""저주받은 통 3D 모델 (Blender 5 · bpy).

    python3 tools/blender/build_models.py            # FBX + MeshCatalog.lua
    python3 tools/blender/build_models.py --render   # 미리보기 PNG 도 같이

만드는 것
  assets/models/CursedBarrelModels.fbx   Studio 의 "3D 가져오기"로 한 번에 넣는 파일 (조각 이름이 CB_ 로 시작)
  assets/models/previews/*.png            모델 미리보기
  game/.../Shared/MeshCatalog.lua          조각마다 크기 · 자리 (게임 코드가 이 값으로 메시를 제자리에 놓는다)

좌표
  모든 모양은 Roblox 좌표(스터드, Y 가 위, 뱃머리 +Z)로 만든다. 저장할 때 Blender 좌표로 바꾸고,
  FBX 는 Y-up 으로 내보내므로 Studio 에서는 다시 Roblox 좌표 그대로다.
  조각의 크기 · 가운데는 MeshCatalog 에 적는다. 게임 코드는 가져온 MeshPart 의 Size · CFrame 을 그 값으로 맞춘다.
  (그래서 Studio 가져오기의 단위 설정이 무엇이든 크기가 어긋나지 않는다)
"""
from pathlib import Path
import math
import random
import sys
import hashlib

import bpy
import bmesh
from mathutils import Matrix, Vector, noise

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import kraken_dump  # noqa: E402

OUT = ROOT / 'assets/models'
CATALOG = ROOT / 'game/ReplicatedStorage/CursedBarrel/Shared/MeshCatalog.lua'
FBX_NAME = 'CursedBarrelModels'

# Roblox (x, y, z) -> Blender (x, -z, y)
R2B = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
TAU = math.pi * 2
random.seed(15)


def V(x, y, z):
    return Vector((x, y, z))


def smoothstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


# --------------------------------------------------
# 조각 (Roblox 좌표의 bmesh)
# --------------------------------------------------
class Piece:
    def __init__(self, name, color, roughness=0.5, metallic=0.0, uv_scale=4.0, sharp=34):
        self.name = name
        self.bm = bmesh.new()
        self.color = color
        self.roughness = roughness
        self.metallic = metallic
        self.uv_scale = uv_scale
        self.sharp = math.radians(sharp)
        self.uv_done = set()  # 직접 UV 를 준 면

    # 새로 만든 점들만 골라 옮기기
    def _new_verts(self, before):
        return [v for v in self.bm.verts if v.index == -1 or v.index >= before]

    def mark(self):
        self.bm.verts.index_update()
        return len(self.bm.verts)

    def fresh(self, before):
        self.bm.verts.ensure_lookup_table()
        return self.bm.verts[before:]

    # 상자 (모서리 둥글게)
    def box(self, center, size, bevel=0.03, rot=None, segments=2):
        before = self.mark()
        m = Matrix.Translation(Vector(center))
        if rot is not None:
            m = m @ rot
        m = m @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        verts = self.fresh(before)
        if bevel > 0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges + list(verts), offset=bevel, segments=segments, profile=0.5,
                            affect='EDGES', clamp_overlap=True)
        return verts

    # 원통 (axis 방향, 가운데 center)
    def cylinder(self, center, axis, radius, length, segments=24, caps=True, radius2=None, bevel=0.0):
        before = self.mark()
        axis = Vector(axis).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(axis).to_matrix().to_4x4()
        m = Matrix.Translation(Vector(center)) @ rot
        bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=segments, radius1=radius,
                              radius2=radius if radius2 is None else radius2, depth=length, matrix=m)
        verts = self.fresh(before)
        if bevel > 0:
            edges = [e for e in {e for v in verts for e in v.link_edges} if e.calc_face_angle(0) > 0.6]
            if edges:
                bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=2, profile=0.5, affect='EDGES',
                                clamp_overlap=True)
        return verts

    def sphere(self, center, radius, u=16, v=10, scale=(1, 1, 1)):
        before = self.mark()
        m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
        bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=radius, matrix=m)
        return self.fresh(before)

    # 회전체. profile = [(축 위치 a, 반지름 r), ...] 을 뒤(−a) → 바깥 → 앞(+a) 순서로 준다.
    # 그 순서면 겉면의 법선이 바깥을 본다. (안으로 꺾여 들어가는 구멍 벽은 구멍 쪽을 본다)
    # frame : 축(a) 이 로컬 X 인 좌표계 → Roblox 좌표 (Matrix)
    def lathe(self, profile, frame, segments=32, wobble=None):
        rows = []
        for (a, r) in profile:
            ring = []
            for j in range(segments):
                t = j / segments * TAU
                rr = r
                if wobble:
                    rr = wobble(a, r, t)
                if r <= 1e-6:
                    ring.append(None)
                else:
                    ring.append(frame @ V(a, rr * math.cos(t), rr * math.sin(t)))
            rows.append(ring)
        # 반지름 0 인 점은 하나만 만든다
        made = []
        for i, ring in enumerate(rows):
            if ring[0] is None:
                a = profile[i][0]
                made.append(self.bm.verts.new(frame @ V(a, 0, 0)))
            else:
                made.append([self.bm.verts.new(p) for p in ring])
        faces = []
        for i in range(len(made) - 1):
            A, B = made[i], made[i + 1]
            for j in range(segments):
                k = (j + 1) % segments
                if isinstance(A, list) and isinstance(B, list):
                    quad = (A[j], A[k], B[k], B[j])
                    faces.append(self.bm.faces.new(quad))
                elif isinstance(A, list):  # B 는 한 점
                    faces.append(self.bm.faces.new((A[j], A[k], B)))
                elif isinstance(B, list):
                    faces.append(self.bm.faces.new((A, B[k], B[j])))
        return faces

    # 점 목록으로 된 다각형을 두께만큼 밀어낸다 (옆판 · 쐐기). outline 은 XY 평면, 두께는 Z.
    def slab(self, outline, z0, z1, frame=Matrix.Identity(4), bevel=0.02):
        before = self.mark()
        front = [self.bm.verts.new(frame @ V(x, y, z1)) for (x, y) in outline]
        back = [self.bm.verts.new(frame @ V(x, y, z0)) for (x, y) in outline]
        n = len(outline)
        self.bm.faces.new(front)
        self.bm.faces.new(list(reversed(back)))
        for i in range(n):
            j = (i + 1) % n
            self.bm.faces.new((back[i], back[j], front[j], front[i]))
        verts = self.fresh(before)
        bmesh.ops.recalc_face_normals(self.bm, faces=list({f for v in verts for f in v.link_faces}))
        if bevel > 0:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=2, profile=0.5, affect='EDGES',
                            clamp_overlap=True)
        return verts

    def torus(self, center, axis, major, minor, segments=32, sides=10, arc=TAU):
        axis = Vector(axis).normalized()
        rot = Vector((1, 0, 0)).rotation_difference(axis).to_matrix().to_4x4()
        frame = Matrix.Translation(Vector(center)) @ rot
        full = abs(arc - TAU) < 1e-6
        count = segments if full else segments + 1
        rings = []
        for i in range(count):
            t = i / segments * arc
            c = V(0, major * math.cos(t), major * math.sin(t))
            out = V(0, math.cos(t), math.sin(t))
            ring = []
            for j in range(sides):
                s = j / sides * TAU
                p = c + out * (minor * math.cos(s)) + V(minor * math.sin(s), 0, 0)
                ring.append(self.bm.verts.new(frame @ p))
            rings.append(ring)
        made = []
        for i in range(count if full else count - 1):
            A, B = rings[i], rings[(i + 1) % count]
            for j in range(sides):
                k = (j + 1) % sides
                made.append(self.bm.faces.new((A[j], B[j], B[k], A[k])))
        bmesh.ops.recalc_face_normals(self.bm, faces=made)

    # --------------------------------------------------
    def finish(self, collection, catalog, world=False):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bm.normal_update()
        # 경계 상자 (Roblox 좌표)
        xs = [v.co.x for v in bm.verts]
        ys = [v.co.y for v in bm.verts]
        zs = [v.co.z for v in bm.verts]
        lo = V(min(xs), min(ys), min(zs))
        hi = V(max(xs), max(ys), max(zs))
        # UV : 직접 준 면 말고는 상자 투영 (Roblox 재질 무늬가 늘어지지 않게)
        uv = bm.loops.layers.uv.active or bm.loops.layers.uv.new('UVMap')
        s = self.uv_scale
        for f in bm.faces:
            if f.index in self.uv_done:
                continue
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for loop in f.loops:
                c = loop.vert.co
                if ax == 0:
                    loop[uv].uv = (c.z / s, c.y / s)
                elif ax == 1:
                    loop[uv].uv = (c.x / s, c.z / s)
                else:
                    loop[uv].uv = (c.x / s, c.y / s)
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method='BEAUTY', ngon_method='BEAUTY')
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            if e.is_manifold and e.calc_face_angle(0) > self.sharp:
                e.smooth = False
        tris = len(bm.faces)
        bm.transform(R2B)
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        collection.objects.link(obj)
        mat = bpy.data.materials.get('M_' + self.name) or bpy.data.materials.new('M_' + self.name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        if bsdf:
            bsdf.inputs['Base Color'].default_value = (*[c / 255 for c in self.color], 1)
            bsdf.inputs['Roughness'].default_value = self.roughness
            bsdf.inputs['Metallic'].default_value = self.metallic
        mesh.materials.append(mat)
        center = (lo + hi) / 2
        size = hi - lo
        catalog[self.name] = {'center': center, 'size': size, 'tris': tris, 'world': world}
        if tris > 19000:
            raise SystemExit(f'{self.name}: {tris} triangles (Roblox limit is about 20,000 per mesh)')
        return obj


# --------------------------------------------------
# 대포 (가운데 = 포신 가운데. 포구가 +X. 갑판은 y = −2.2)
# --------------------------------------------------
def cannon(col, catalog):
    ident = Matrix.Identity(4)
    tube = Piece('CB_Cannon_Tube', (46, 48, 54), roughness=0.38, metallic=0.85)
    profile = [
        (-3.74, 0.0), (-3.72, 0.1), (-3.66, 0.22), (-3.56, 0.32), (-3.44, 0.38), (-3.31, 0.395), (-3.18, 0.37),
        (-3.09, 0.29), (-3.03, 0.22), (-2.96, 0.23), (-2.93, 0.42), (-2.89, 0.62), (-2.84, 0.8), (-2.8, 0.92),
        (-2.78, 0.975), (-2.62, 0.975), (-2.59, 0.93), (-2.55, 0.905), (-1.0, 0.87), (-0.97, 0.93),
        (-0.8, 0.935), (-0.77, 0.86), (-0.74, 0.845), (0.18, 0.8), (0.21, 0.86), (0.33, 0.865),
        (0.36, 0.78), (0.4, 0.765), (2.02, 0.665), (2.12, 0.645), (2.24, 0.68), (2.4, 0.75), (2.56, 0.81),
        (2.66, 0.86), (2.76, 0.865), (2.8, 0.83), (2.81, 0.55), (2.79, 0.47), (2.72, 0.44), (2.3, 0.435),
    ]
    tube.lathe(profile, ident, segments=40)
    # 포이(손잡이 두 개) · 화문
    for x in (-0.55, 0.1):
        tube.torus(V(x, 0.86, 0), (0, 0, 1), 0.2, 0.055, segments=18, sides=8, arc=math.pi)
    tube.box(V(-2.25, 0.93, 0), V(0.32, 0.12, 0.26), bevel=0.03)
    # 굴대 (포신을 가로지른다)
    for sz in (-1, 1):
        tube.cylinder(V(-0.2, 0, sz * 1.02), (0, 0, 1), 0.26, 0.64, segments=20, bevel=0.03)
    tube.finish(col, catalog)

    bore = Piece('CB_Cannon_Bore', (10, 10, 12), roughness=0.9)
    bore.lathe([(1.2, 0.0), (1.22, 0.43), (2.74, 0.43)], Matrix.Diagonal((1, -1, 1, 1)), segments=24)
    bore.finish(col, catalog)

    wood = Piece('CB_Cannon_Carriage', (112, 60, 34), roughness=0.75, uv_scale=3.0)
    # 옆판 (계단 모양 · 굴대 홈)
    outline = [(-2.42, -1.3), (1.9, -1.3), (1.92, 0.02), (1.7, 0.08), (0.15, 0.08)]
    for i in range(1, 8):  # 굴대 홈 (반원)
        t = math.pi * i / 8
        outline.append((-0.2 + 0.3 * math.cos(t), 0.08 - 0.3 * math.sin(t) * 1.05))
    outline += [(-0.55, 0.08), (-0.62, -0.36), (-1.66, -0.36), (-1.72, -0.76), (-2.38, -0.76)]
    for sz in (-1, 1):
        z0, z1 = (0.88, 1.22) if sz > 0 else (-1.22, -0.88)
        wood.slab(outline, z0, z1, bevel=0.03)
    wood.box(V(1.62, -0.78, 0), V(0.42, 0.8, 1.8), bevel=0.04)          # 앞 가로대
    wood.box(V(-2.1, -1.05, 0), V(0.5, 0.5, 1.8), bevel=0.04)           # 뒤 가로대
    for k, x in enumerate((-1.95, -1.2, -0.45, 0.3, 1.05)):             # 바닥 판자 다섯 장
        wood.box(V(x + 0.37, -1.3, 0), V(0.72, 0.22, 1.76), bevel=0.025)
    for (x, y) in ((1.45, -1.6), (-1.9, -1.69)):                        # 굴대 받침
        wood.box(V(x, y + 0.02, 0), V(0.5, 0.42, 2.72), bevel=0.05)
    # 쐐기 (포신 뒤를 받친다) + 손잡이
    wedge = [(-2.78, -1.1), (-1.45, -1.1), (-1.45, -0.72)]
    wood.slab(wedge, -0.42, 0.42, bevel=0.02)
    wood.cylinder(V(-2.72, -0.98, 0), (1, 0, 0), 0.09, 0.3, segments=12)
    wood.finish(col, catalog)

    trucks = Piece('CB_Cannon_Trucks', (74, 42, 24), roughness=0.8, uv_scale=2.0)
    for (x, y, r) in ((1.45, -1.6, 0.6), (-1.9, -1.69, 0.51)):
        for sz in (-1, 1):
            z = sz * 1.5
            prof = [(-0.17, 0.0), (-0.17, r * 0.3), (-0.16, r * 0.82), (-0.14, r * 0.94), (-0.1, r),
                    (0.1, r), (0.14, r * 0.94), (0.16, r * 0.82), (0.17, r * 0.3), (0.17, 0.0)]
            frame = Matrix.Translation(V(x, y, z)) @ Matrix.Rotation(-math.pi / 2, 4, 'Y')
            trucks.lathe(prof, frame, segments=28)
    trucks.finish(col, catalog)

    iron = Piece('CB_Cannon_Iron', (48, 52, 58), roughness=0.45, metallic=0.8)
    for sz in (-1, 1):
        z = sz * 1.05
        # 굴대 덮개 (반원 띠)
        iron.torus(V(-0.2, 0.0, z), (0, 0, 1), 0.3, 0.05, segments=16, sides=6, arc=math.pi)
        for x in (-0.9, 0.3, 1.5):  # 볼트 머리
            iron.cylinder(V(x, -0.7, sz * 1.24), (0, 0, 1), 0.07, 0.06, segments=10)
        iron.torus(V(0.9, -0.95, sz * 1.27), (0, 0, 1), 0.12, 0.03, segments=14, sides=6)  # 고리
    for (x, y, r) in ((1.45, -1.6, 0.6), (-1.9, -1.69, 0.51)):
        for sz in (-1, 1):
            z = sz * 1.5
            iron.torus(V(x, y, z), (0, 0, 1), r - 0.01, 0.045, segments=28, sides=6)       # 쇠 테
            iron.cylinder(V(x, y, z + sz * 0.21), (0, 0, 1), 0.11, 0.12, segments=12)       # 굴대 끝
    iron.finish(col, catalog)


# --------------------------------------------------
# 나무통 (가운데 = 통 가운데, 높이 4, 반지름 1.75. 뚜껑은 게임 파트가 그대로 덮는다)
# --------------------------------------------------
def cask_radius(y):
    return 1.66 + 0.14 * math.cos(math.pi * y / 4.0)


def cask(col, catalog, prefix='CB_Cask', height=4.0):
    staves = Piece(prefix + '_Staves', (122, 78, 44), roughness=0.8, uv_scale=2.5, sharp=30)
    count = 18
    gap = 0.018
    rows = 14
    half = height / 2
    for s in range(count):
        a0 = s / count * TAU + gap
        a1 = (s + 1) / count * TAU - gap
        cols = 4
        jitter = random.uniform(-0.012, 0.012)
        tilt = random.uniform(-0.01, 0.01)
        outer, inner = [], []
        for i in range(rows + 1):
            y = -half + height * i / rows
            ro = cask_radius(y) + jitter + tilt * y
            ri = ro - 0.11
            orow, irow = [], []
            for j in range(cols + 1):
                a = a0 + (a1 - a0) * j / cols
                # 판자 가운데가 조금 볼록 · 모서리는 살짝 둥글게
                edge = abs(j / cols - 0.5) * 2
                bump = 0.012 * (1 - edge * edge)
                orow.append(staves.bm.verts.new(V((ro + bump) * math.sin(a), y, (ro + bump) * math.cos(a))))
                irow.append(staves.bm.verts.new(V(ri * math.sin(a), y, ri * math.cos(a))))
            outer.append(orow)
            inner.append(irow)
        for i in range(rows):
            for j in range(cols):
                staves.bm.faces.new((outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j]))
                staves.bm.faces.new((inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1]))
        for i in range(rows):  # 판자 옆면 (틈 사이로 보인다)
            staves.bm.faces.new((outer[i][0], outer[i + 1][0], inner[i + 1][0], inner[i][0]))
            staves.bm.faces.new((outer[i][cols], inner[i][cols], inner[i + 1][cols], outer[i + 1][cols]))
        for j in range(cols):  # 위 · 아래 끝
            staves.bm.faces.new((outer[rows][j], outer[rows][j + 1], inner[rows][j + 1], inner[rows][j]))
            staves.bm.faces.new((outer[0][j], inner[0][j], inner[0][j + 1], outer[0][j + 1]))
    bmesh.ops.recalc_face_normals(staves.bm, faces=staves.bm.faces[:])
    # 바닥 판 (틈 사이로 안이 비어 보이지 않게)
    staves.cylinder(V(0, -half + 0.12, 0), (0, 1, 0), cask_radius(-half) - 0.1, 0.08, segments=36)
    staves.finish(col, catalog)

    hoops = Piece(prefix + '_Hoops', (58, 48, 42), roughness=0.5, metallic=0.75, uv_scale=2.0)
    for (yc, width) in ((-1.72, 0.2), (-1.1, 0.26), (1.1, 0.26), (1.72, 0.2)):
        y0, y1 = yc - width / 2, yc + width / 2
        prof = []
        for k in range(7):
            y = y0 + (y1 - y0) * k / 6
            lift = 0.032 + 0.012 * math.sin(math.pi * k / 6)
            prof.append((y, cask_radius(y) + lift))
        prof = [(y0, cask_radius(y0) - 0.02)] + prof + [(y1, cask_radius(y1) - 0.02)]
        frame = Matrix.Rotation(math.pi / 2, 4, 'Z')  # 로컬 X(축) → Roblox Y
        hoops.lathe(prof, frame, segments=48)
        for k in range(8):  # 징
            a = k / 8 * TAU + 0.2
            r = cask_radius(yc) + 0.05
            hoops.sphere(V(r * math.sin(a), yc, r * math.cos(a)), 0.045, u=8, v=5)
    hoops.finish(col, catalog)


# --------------------------------------------------
# 철제 드럼 (가운데 = 통 가운데, 높이 4, 반지름 1.75)
# --------------------------------------------------
def drum(col, catalog):
    shell = Piece('CB_Drum_Shell', (26, 70, 178), roughness=0.3, metallic=0.6, uv_scale=2.0, sharp=40)
    prof = [(-2.0, 0.0), (-1.99, 1.62), (-1.96, 1.7), (-1.93, 1.745)]
    y = -1.9
    ribs = [-1.62, -1.46, -1.3, -1.14, 1.14, 1.3, 1.46, 1.62]
    hoops = [-0.667, 0.667]
    while y < 1.9:
        r = 1.75
        for c in ribs:
            d = abs(y - c)
            if d < 0.06:
                r += 0.022 * math.cos(d / 0.06 * math.pi / 2)
        for c in hoops:
            d = abs(y - c)
            if d < 0.2:
                r -= 0.02 * math.cos(d / 0.2 * math.pi / 2)
        prof.append((y, r))
        y += 0.04
    prof += [(1.93, 1.745), (1.96, 1.7), (1.975, 1.62)]
    # 위는 열려 있다 (게임의 뚜껑 파트가 덮는다). 안쪽 벽을 조금 만든다.
    prof += [(1.975, 1.6), (1.6, 1.6)]
    frame = Matrix.Rotation(math.pi / 2, 4, 'Z')
    shell.lathe(prof, frame, segments=48)
    shell.finish(col, catalog)

    rings = Piece('CB_Drum_Rings', (34, 84, 196), roughness=0.3, metallic=0.6, uv_scale=2.0)
    for c in hoops:  # 굴림 테 (불룩한 띠)
        prof = [(c - 0.16, 1.73), (c - 0.12, 1.79), (c - 0.06, 1.835), (c, 1.85), (c + 0.06, 1.835),
                (c + 0.12, 1.79), (c + 0.16, 1.73)]
        rings.lathe(prof, frame, segments=48)
    for c in (-1.97, 1.97):  # 말린 테두리
        rings.torus(V(0, c, 0), (0, 1, 0), 1.72, 0.075, segments=48, sides=10)
    rings.finish(col, catalog)


# --------------------------------------------------
# 크라켄
# --------------------------------------------------
def sucker_profile():
    # 축(+X)이 바깥. 두께 0.22, 지름 1
    return [(0.0, 0.0), (0.0, 0.5), (0.1, 0.5), (0.17, 0.47), (0.215, 0.41), (0.2, 0.33), (0.14, 0.26),
            (0.1, 0.16), (0.085, 0.06), (0.09, 0.0)]


def kraken_parts(col, catalog):
    seg = Piece('CB_Kraken_Segment', (122, 40, 70), roughness=0.35, sharp=80)
    prof = []
    for k in range(9):
        x = -0.5 + k / 8
        prof.append((x, 0.5 * (1 + 0.035 * math.sin(k / 8 * TAU * 1.5))))

    def wobble(a, r, t):
        return r * (1 + 0.02 * math.sin(t * 7) + 0.012 * math.sin(t * 13 + a * 9))

    seg.lathe(prof, Matrix.Identity(4), segments=22, wobble=wobble)
    seg.finish(col, catalog)

    sucker = Piece('CB_Kraken_Sucker', (244, 196, 184), roughness=0.4, sharp=70)
    sucker.lathe(sucker_profile(), Matrix.Identity(4), segments=18)
    sucker.finish(col, catalog)


def transport_frames(tangents, desired, window=14):
    """비틀림이 가장 적은 틀(평행 이동)을 만든 뒤, 원하는 빨판 방향으로 천천히 돌린다."""
    n = len(tangents)
    normals = []
    first = desired[0] - tangents[0] * desired[0].dot(tangents[0])
    normals.append(first.normalized())
    for i in range(1, n):
        q = tangents[i - 1].rotation_difference(tangents[i])
        nrm = q @ normals[i - 1]
        nrm = nrm - tangents[i] * nrm.dot(tangents[i])
        normals.append(nrm.normalized())
    angles, prev = [], 0.0
    for i in range(n):
        t, nrm = tangents[i], normals[i]
        b = t.cross(nrm)
        d = desired[i] - t * desired[i].dot(t)
        a = math.atan2(d.dot(b), d.dot(nrm))
        while a - prev > math.pi:
            a -= TAU
        while a - prev < -math.pi:
            a += TAU
        angles.append(a)
        prev = a
    out = []
    for i in range(n):
        acc = wsum = 0.0
        for k in range(-window, window + 1):
            j = min(max(i + k, 0), n - 1)
            w = 1 - abs(k) / (window + 1)
            acc += angles[j] * w
            wsum += w
        a = acc / wsum
        t, nrm = tangents[i], normals[i]
        b = t.cross(nrm)
        out.append((nrm * math.cos(a) + b * math.sin(a)).normalized())
    return out


def tube_frames(points):
    tangents = []
    n = len(points)
    for i in range(n):
        a = points[max(i - 1, 0)]
        b = points[min(i + 1, n - 1)]
        tangents.append((b - a).normalized())
    return tangents


def resting_arm(col, catalog, arm):
    samples = arm['samples']
    name = 'CB_' + arm['name'].replace('Rest_', 'KrakenRest_')
    points = [V(*s['p']) for s in samples]
    radii = [s['r'] for s in samples]
    inners = [V(*s['inner']) for s in samples]
    tangents = tube_frames(points)
    inners = transport_frames(tangents, inners)
    # 굽은 곳의 반지름이 굵기보다 작으면 안쪽 살이 접힌다. 만들 때 알려 준다.
    worst = 99.0
    for i in range(2, len(points) - 2):
        a, b, c = points[i - 2], points[i], points[i + 2]
        ab, bc = (b - a), (c - b)
        angle = ab.angle(bc, 0.0)
        if angle > 1e-4:
            bend = (ab.length + bc.length) / 2 / angle
            worst = min(worst, bend / max(radii[i], 1e-3))
    print(f'  {name}: tightest bend = {worst:.2f} x radius')

    skin = Piece(name + '_Skin', (122, 40, 70), roughness=0.3, sharp=179)
    belly = Piece(name + '_Belly', (226, 150, 150), roughness=0.35, sharp=179)
    suckers = Piece(name + '_Suckers', (244, 196, 184), roughness=0.4, sharp=70)
    sides = 30
    length = 0.0
    rings = []
    arcs = []
    for i, p in enumerate(points):
        if i > 0:
            length += (p - points[i - 1]).length
        arcs.append(length)
    for i, p in enumerate(points):
        t = tangents[i]
        nrm = inners[i]
        bin = t.cross(nrm).normalized()
        r = radii[i]
        ring = []
        for j in range(sides):
            phi = j / sides * TAU
            c, s = math.cos(phi), math.sin(phi)
            # 빨판 쪽(phi=0)은 납작하게, 등은 둥글게. 주름 · 우둘투둘한 살결
            flat = 1 - 0.14 * max(c, 0) ** 2
            wrinkle = 1 + 0.035 * math.sin(arcs[i] * 2.4 / max(r, 0.4)) * (0.4 + 0.6 * max(-c, 0))
            bumps = 1 + 0.03 * noise.noise(Vector((p.x * 0.7, p.y * 0.7 + phi, p.z * 0.7)))
            rr = r * flat * wrinkle * bumps
            ring.append(p + nrm * (c * rr) + bin * (s * rr))
        rings.append(ring)
    n = len(points)
    vs_skin = [[skin.bm.verts.new(q) for q in ring] for ring in rings]
    vs_belly = [[belly.bm.verts.new(q) for q in ring] for ring in rings]
    for i in range(n - 1):
        for j in range(sides):
            k = (j + 1) % sides
            mid = (j + 0.5) / sides * TAU
            on_belly = math.cos(mid) > 0.55
            target, vs = (belly, vs_belly) if on_belly else (skin, vs_skin)
            target.bm.faces.new((vs[i][j], vs[i][k], vs[i + 1][k], vs[i + 1][j]))
    # 끝 마개
    tip = skin.bm.verts.new(points[-1] + tangents[-1] * radii[-1] * 0.9)
    for j in range(sides):
        k = (j + 1) % sides
        skin.bm.faces.new((vs_skin[-1][j], vs_skin[-1][k], tip))

    # 빨판 두 줄 (엇갈려서). 뿌리 쪽 물속 부분과 말린 끝 안쪽은 뺀다
    total = arcs[-1]
    s = total * 0.14
    row = 0
    prof = sucker_profile()
    while s < total * 0.965:
        i = next((k for k in range(n) if arcs[k] >= s), n - 1)
        p, t, nrm, r = points[i], tangents[i], inners[i], radii[i]
        if p.y > -1.0:
            bin = t.cross(nrm).normalized()
            side = 0.38 if row % 2 == 0 else -0.38
            face = (nrm * math.cos(side) + bin * math.sin(side)).normalized()
            size = r * 0.62
            surface = r * (1 - 0.14 * math.cos(side) ** 2)
            base = p + face * (surface - 0.03 * r)
            rot = Vector((1, 0, 0)).rotation_difference(face).to_matrix().to_4x4()
            frame = Matrix.Translation(base) @ rot @ Matrix.Diagonal((size * 0.9, size, size, 1))
            suckers.lathe(prof, frame, segments=12)
        s += max(r * 0.68, 0.18)
        row += 1
    skin.finish(col, catalog, world=True)
    belly.finish(col, catalog, world=True)
    suckers.finish(col, catalog, world=True)


def kraken_mantle(col, catalog, head):
    # 머리 좌표 : 가운데 원점, 앞(노려보는 쪽)이 −Z, 위가 +Y. 눈은 (±eyeSpread, eyeRise, −eyeForward)
    radius = head['mantle'] / 2
    back_c = V(0, head['mantle'] * 0.2, head['mantle'] * 0.16)
    back_r = head['mantle'] * 0.8 / 2
    eyes = [V(sx * head['eyeSpread'], head['eyeRise'], -head['eyeForward']) for sx in (-1, 1)]
    eye_r = head['eye'] / 2
    mantle = Piece('CB_Kraken_Mantle', (122, 40, 70), roughness=0.3, sharp=179)
    bm = mantle.bm
    # 극(뾰족한 점)이 위 · 아래로 가게 (앞쪽 눈 사이에 오면 주름이 모인다)
    bmesh.ops.create_uvsphere(bm, u_segments=80, v_segments=56, radius=1.0, matrix=Matrix.Rotation(-math.pi / 2, 4, 'X'))
    for v in bm.verts:
        d = v.co.normalized()
        # 두 공을 부드럽게 합친 겉모양 (게임의 예전 머리와 같은 크기)
        a = radius
        dc = d.dot(back_c)
        disc = dc * dc - back_c.length_squared + back_r * back_r
        b = dc + math.sqrt(max(disc, 0)) if disc > 0 else 0
        k = 7.0
        h = max(k - abs(a - b), 0) / k
        rr = max(a, b) + h * h * k / 4  # 부드러운 최댓값 (이음매가 둥글게)
        p = d * rr
        # 세로 주름 (머리 뒤쪽 위) · 우둘투둘한 살결
        up = max(0.0, d.y)
        ang = math.atan2(d.x, d.z)
        fold = up * (1 - up) * 4  # 정수리로 모이지 않게 옆면에서만
        p += d * (0.8 * fold * math.sin(ang * 9) * (0.5 + 0.5 * max(0, d.z)))
        p += d * (1.4 * noise.noise(p * 0.06) + 0.5 * noise.noise(p * 0.2))
        # 사마귀 같은 작은 혹
        wart = noise.noise(p * 0.55 + V(3.1, 7.7, 1.3))
        p += d * (0.55 * max(0.0, wart - 0.25) * 2.2)
        # 눈구멍 (눈이 반쯤 박히게) · 눈썹 뼈
        for e in eyes:
            dist = (p - e).length
            # 눈 둘레가 도톰하게 솟는다 (눈이 구멍에 앉은 것처럼)
            p += p.normalized() * (1.25 * math.exp(-((dist - eye_r * 1.12) / (eye_r * 0.32)) ** 2))
            # 눈썹 뼈 : 눈 위로 비스듬히 솟은 둔덕 (경계가 없는 부드러운 모양)
            # 가운데로 갈수록 내려오는 성난 눈썹
            inward = -1 if e.x > 0 else 1
            q = p - (e + V(0, eye_r * 1.15, eye_r * 0.1))
            slope = q.y + inward * q.x * 0.35
            spread = (q.x / (eye_r * 1.6)) ** 2 + (slope / (eye_r * 0.5)) ** 2 + (q.z / (eye_r * 1.5)) ** 2
            p += p.normalized() * (2.6 * math.exp(-spread))
        # 물속 아래쪽은 오므린다 (다리가 나오는 곳)
        if d.y < -0.3:
            p *= 1 - 0.18 * smoothstep((-d.y - 0.3) / 0.6)
        v.co = p
    mantle.finish(col, catalog)


# --------------------------------------------------
# 미리보기
# --------------------------------------------------
def preview_scene(render):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 48
    try:
        scene.cycles.use_denoising = True
    except Exception:
        pass
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    world = bpy.data.worlds.new('Sky')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.35, 0.5, 0.7, 1)
    bg.inputs['Strength'].default_value = 0.7
    scene.world = world
    sun = bpy.data.lights.new('Sun', 'SUN')
    sun.energy = 3.5
    sun.angle = math.radians(8)
    sun_obj = bpy.data.objects.new('Sun', sun)
    sun_obj.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    scene.collection.objects.link(sun_obj)
    cam = bpy.data.cameras.new('Cam')
    cam.lens = 50
    cam_obj = bpy.data.objects.new('Cam', cam)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    return cam_obj


def look_at(cam_obj, eye_r, target_r):
    eye = R2B @ Vector(eye_r)
    target = R2B @ Vector(target_r)
    cam_obj.location = eye
    direction = target - eye
    cam_obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()


def render_shot(path, objects, eye, target, extra=()):
    shown = set(objects) | set(extra)
    for obj in bpy.data.objects:
        if obj.type == 'MESH':
            obj.hide_render = obj.name not in shown
    cam = bpy.context.scene.camera
    look_at(cam, eye, target)
    bpy.context.scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def proxy(name, center_r, size_r, color):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector(center_r)) @ Matrix.Diagonal((*size_r, 1)))
    bm.transform(R2B)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new('M_' + name)
    mat.use_nodes = True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*[c / 255 for c in color], 1)
    mesh.materials.append(mat)
    return obj


def proxy_ball(name, center_r, radius, color):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=radius,
                              matrix=Matrix.Translation(Vector(center_r)))
    for f in bm.faces:
        f.smooth = True
    bm.transform(R2B)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mat = bpy.data.materials.new('M_' + name)
    mat.use_nodes = True
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*[c / 255 for c in color], 1)
    mesh.materials.append(mat)
    return obj


def translate_copy(obj, offset_r, name):
    copy = obj.copy()
    copy.data = obj.data.copy()
    copy.name = name
    copy.location = R2B @ Vector(offset_r)
    bpy.context.scene.collection.objects.link(copy)
    return copy


# --------------------------------------------------
def lua_vec(v):
    return 'Vector3.new(%.4f, %.4f, %.4f)' % (v.x, v.y, v.z)


def write_catalog(catalog, assets, digest):
    lines = [
        '-- 자동 생성 파일 (tools/blender/build_models.py). 손으로 고치지 마세요.',
        '-- Blender 로 만든 3D 모델 조각의 크기와 자리 (Roblox 좌표 · 스터드).',
        '-- world = true 인 조각은 월드 좌표 그대로 놓는다 (갑판에 누운 크라켄 다리).',
        'return {',
        '\tFile = "%s",' % FBX_NAME,
        '\tDigest = "%s",' % digest,
        '\tPieces = {',
    ]
    for name in sorted(catalog):
        c = catalog[name]
        lines.append('\t\t%s = { center = %s, size = %s, tris = %d%s },' % (
            name, lua_vec(c['center']), lua_vec(c['size']), c['tris'], ', world = true' if c['world'] else ''))
    lines.append('\t},')
    lines.append('\tAssets = {')
    for asset in sorted(assets):
        lines.append('\t\t%s = { %s },' % (asset, ', '.join('"%s"' % p for p in assets[asset])))
    lines.append('\t},')
    lines.append('}')
    CATALOG.write_text('\n'.join(lines) + '\n')


def main():
    render = '--render' in sys.argv
    bpy.ops.wm.read_factory_settings(use_empty=True)
    col = bpy.data.collections.new(FBX_NAME)
    bpy.context.scene.collection.children.link(col)
    catalog = {}
    cannon(col, catalog)
    cask(col, catalog)
    drum(col, catalog)
    kraken_parts(col, catalog)
    data = kraken_dump.load()
    for arm in data['resting']:
        resting_arm(col, catalog, arm)
    kraken_mantle(col, catalog, data['head'])

    assets = {
        'Cannon': ['CB_Cannon_Tube', 'CB_Cannon_Bore', 'CB_Cannon_Carriage', 'CB_Cannon_Trucks', 'CB_Cannon_Iron'],
        'Cask': ['CB_Cask_Staves', 'CB_Cask_Hoops'],
        'Drum': ['CB_Drum_Shell', 'CB_Drum_Rings'],
        'KrakenPieces': ['CB_Kraken_Segment', 'CB_Kraken_Sucker', 'CB_Kraken_Mantle'],
    }
    for arm in data['resting']:
        base = 'CB_' + arm['name'].replace('Rest_', 'KrakenRest_')
        assets[arm['name']] = [base + '_Skin', base + '_Belly', base + '_Suckers']

    OUT.mkdir(parents=True, exist_ok=True)
    for obj in bpy.data.objects:
        obj.select_set(obj.type == 'MESH' and obj.name in catalog)
    fbx = OUT / (FBX_NAME + '.fbx')
    bpy.ops.export_scene.fbx(filepath=str(fbx), use_selection=True, object_types={'MESH'},
                             axis_forward='-Z', axis_up='Y', bake_space_transform=True,
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE',
                             mesh_smooth_type='FACE', use_mesh_modifiers=True, add_leaf_bones=False,
                             use_custom_props=False, path_mode='AUTO', embed_textures=False)
    digest = hashlib.sha256(fbx.read_bytes()).hexdigest()[:12]
    write_catalog(catalog, assets, digest)
    total = sum(c['tris'] for c in catalog.values())
    print(f'FBX {fbx.relative_to(ROOT)}  pieces={len(catalog)}  triangles={total}  digest={digest}')
    for name in sorted(catalog):
        c = catalog[name]
        print(f'  {name:36s} tris={c["tris"]:6d} size=({c["size"].x:.2f}, {c["size"].y:.2f}, {c["size"].z:.2f})')

    if render:
        previews = OUT / 'previews'
        previews.mkdir(exist_ok=True)
        preview_scene(render)
        cannon_parts = assets['Cannon']
        render_shot(previews / 'cannon.png', cannon_parts, (6.5, 3.2, 7.5), (0, -0.6, 0))
        render_shot(previews / 'cask.png', assets['Cask'], (5.5, 3.0, 7.0), (0, 0, 0))
        render_shot(previews / 'drum.png', assets['Drum'], (5.5, 3.0, 7.0), (0, 0, 0))
        head = data['head']
        eyes = []
        for sx in (-1, 1):
            c = (sx * head['eyeSpread'], head['eyeRise'], -head['eyeForward'])
            eyes.append(proxy_ball('EyeProxy%d' % sx, c, head['eye'] / 2, (236, 214, 120)))
            eyes.append(proxy_ball('IrisProxy%d' % sx, (c[0], c[1], c[2] - head['eye'] * 0.2), head['eye'] * 0.36, (255, 150, 40)))
            eyes.append(proxy_ball('PupilProxy%d' % sx, (c[0], c[1], c[2] - head['eye'] * 0.5), head['eye'] * 0.12, (12, 8, 10)))
        sea = proxy('SeaProxy', (0, 7.6, 0), (200, 0.4, 200), (28, 104, 150))
        render_shot(previews / 'kraken_head.png', ['CB_Kraken_Mantle'], (48, 34, -80), (0, 14, 0),
                    extra=[o.name for o in eyes] + [sea.name])
        # 누운 다리 : 간단한 갑판 · 난간을 깔고 찍는다
        deck = [proxy('DeckProxy', (30, 0.5, 40), (54, 1, 44), (133, 88, 49)),
                proxy('RailProxy', (56.6, 2.5, 40), (0.8, 3.5, 44), (87, 51, 30)),
                proxy('RailCapProxy', (56.6, 4.42, 40), (1.1, 0.25, 44), (191, 142, 67)),
                proxy('SeaProxy2', (0, -2.4, 0), (400, 0.2, 400), (28, 104, 150)),
                proxy('QuarterProxy', (0, 17.4, -130), (107, 0.8, 54), (133, 88, 49)),
                proxy('QuarterRailA', (53, 19, -130), (0.7, 3, 54), (42, 28, 24)),
                proxy('QuarterRailB', (-53, 19, -130), (0.7, 3, 54), (42, 28, 24)),
                proxy('HullProxyA', (56, 8, -130), (2, 18, 54), (87, 51, 30)),
                proxy('HullProxyB', (-56, 8, -130), (2, 18, 54), (87, 51, 30))]
        names = [d.name for d in deck]
        arm1 = assets['Rest_Starboard_Deck']
        render_shot(previews / 'kraken_deck.png', arm1, (34, 17, 58), (54, 3, 42), extra=names)
        arms2 = assets['Rest_Starboard_Quarter'] + assets['Rest_Port_Quarter']
        bpy.context.scene.camera.data.lens = 32
        render_shot(previews / 'kraken_quarterdeck.png', arms2, (14, 36, -104), (42, 19, -134), extra=names)
        print('previews ->', previews.relative_to(ROOT))


if __name__ == '__main__':
    main()
