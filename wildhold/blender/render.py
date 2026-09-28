"""미리보기 렌더 (Cycles CPU). Roblox 에서 보일 로우폴리 + 베이크 텍스처 그대로 찍는다."""
from __future__ import annotations

import math

import bpy
from mathutils import Vector


def _look(cam, target):
    direction = Vector(target) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def stage(ground_color=(0.62, 0.78, 0.55), sky=(0.55, 0.7, 0.95)):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.view_settings.view_transform = "Standard"
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*sky, 1)
    bg.inputs["Strength"].default_value = 0.55

    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    ground = bpy.context.active_object
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*ground_color, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    ground.data.materials.append(mat)

    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 4.0
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = (math.radians(50), math.radians(-10), math.radians(-35))
    scene.collection.objects.link(sun)
    fill_data = bpy.data.lights.new("fill", "AREA")
    fill_data.energy = 60
    fill_data.size = 3
    fill = bpy.data.objects.new("fill", fill_data)
    fill.location = (2.5, -2.0, 1.6)
    _look(fill, (0, 0, 0.4))
    scene.collection.objects.link(fill)


def shoot(out, target=(0, 0, 0.45), distance=2.6, yaw=-28, pitch=14, size=(900, 900), lens=50):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    yaw_r, pitch_r = math.radians(yaw), math.radians(pitch)
    offset = Vector((math.sin(yaw_r) * math.cos(pitch_r), -math.cos(yaw_r) * math.cos(pitch_r), math.sin(pitch_r))) * distance
    cam.location = Vector(target) + offset
    _look(cam, target)
    scene.camera = cam
    scene.render.resolution_x, scene.render.resolution_y = size
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def pose(arm, rotations):
    """rotations: {뼈이름: (x, y, z) 도} — 변형 확인용 자세."""
    for name, (rx, ry, rz) in rotations.items():
        pb = arm.pose.bones.get(name)
        if pb:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
