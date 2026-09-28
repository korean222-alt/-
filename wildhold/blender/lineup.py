"""4종을 한 장면에 모아 찍는 단체 렌더.  python3 lineup.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402

import render  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
PETS = os.path.join(HERE, "..", "assets", "pets")
# 게임 안 크기 비율대로 (알파는 크게)
LAYOUT = [("Shellbub", (-1.55, 0.2), 1.0, 20), ("Mossling", (-0.55, -0.3), 1.0, 10),
          ("Emberpup", (0.5, -0.25), 1.0, -12), ("Briarhorn", (1.75, 0.55), 1.35, -28)]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.world = bpy.data.worlds.new("World")
for name, (x, y), scale, yaw in LAYOUT:
    with bpy.data.libraries.load(os.path.join(PETS, name + ".blend")) as (src, dst):
        dst.objects = [n for n in src.objects if n in (name, name + "_Rig")]
    for obj in dst.objects:
        bpy.context.scene.collection.objects.link(obj)
        if obj.type == "ARMATURE":
            obj.location = (x, y, 0)
            obj.scale = (scale, scale, scale)
            obj.rotation_euler = (0, 0, yaw * 3.14159 / 180)
render.stage()
bpy.context.scene.cycles.samples = 96
render.shoot(os.path.join(HERE, "renders", "lineup.png"), target=(0.2, 0.15, 1.35), distance=9.6, yaw=0, pitch=10, size=(1600, 900), lens=45)
