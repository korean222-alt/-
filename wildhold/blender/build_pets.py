"""펫 빌드 CLI.  python3 build_pets.py [종 이름 ...]

결과: ../assets/pets/<종>.fbx / .png / .blend, renders/<종>.png
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import creature_lib  # noqa: E402
import pets  # noqa: E402
import render  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "pets")
RENDERS = os.path.join(HERE, "renders")


def main(names):
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(RENDERS, exist_ok=True)
    report = {}
    for name in names:
        t0 = time.time()
        creature = pets.SPECIES[name]()
        info = creature_lib.build(creature, OUT)
        arm = bpy.data.objects[name + "_Rig"]
        render.stage()
        height = max((arm.matrix_world @ v.co).z for v in bpy.data.objects[name].data.vertices)
        render.shoot(os.path.join(RENDERS, name + ".png"), target=(0, 0, height * 0.48), distance=height * 2.9)
        render.shoot(os.path.join(RENDERS, name + "_side.png"), target=(0, 0, height * 0.48), distance=height * 2.9, yaw=-100, pitch=10)
        render.pose(arm, creature.notes.get("test_pose", {}))
        bpy.context.view_layer.update()
        render.shoot(os.path.join(RENDERS, name + "_pose.png"), target=(0, 0, height * 0.48), distance=height * 2.9, yaw=35)
        info["height"] = round(height, 3)
        info["seconds"] = round(time.time() - t0, 1)
        report[name] = info
        print(json.dumps(info, ensure_ascii=False))
    return report


if __name__ == "__main__":
    main(sys.argv[1:] or list(pets.SPECIES))
