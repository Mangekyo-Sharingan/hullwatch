"""Build Hullwatch's wall-mounted pilot chair and export its deploy/stow clips."""

import math
import json
import os
import struct

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND_PATH = os.path.join(ROOT, "art", "blender", "pilot_chair_kit.blend")
GLB_PATH = os.path.join(ROOT, "game", "assets", "models", "hullwatch", "cockpit", "hw_pilot_chair.glb")


def make_material(name: str, color: tuple, metallic: float, roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    if shader:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Metallic"].default_value = metallic
        shader.inputs["Roughness"].default_value = roughness
    return material


def box(parent: bpy.types.Object, name: str, size: tuple, location: tuple,
        material: bpy.types.Material, bevel: float = 0.012) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = Vector(location)
    obj.data.materials.append(material)
    if bevel > 0.0:
        modifier = obj.modifiers.new("Soft stamped edges", "BEVEL")
        modifier.width = min(bevel, min(size) * 0.22)
        modifier.segments = 2
    return obj


def cylinder(parent: bpy.types.Object, name: str, radius: float, depth: float,
             location: tuple, rotation: tuple, material: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=16,
        radius1=radius, radius2=radius, depth=depth,
    )
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = Vector(location)
    obj.rotation_euler = rotation
    obj.data.materials.append(material)
    return obj


def pivot(parent: bpy.types.Object, name: str, location: tuple) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = Vector(location)
    return obj


def orient_children_for_stow(part: bpy.types.Object) -> None:
    fold = Matrix.Rotation(math.pi / 2.0, 4, "X")
    for child in part.children:
        child.matrix_local = fold @ child.matrix_local


def animate_fold(part: bpy.types.Object, deployed_angle: float) -> None:
    part.animation_data_create()
    scene = bpy.context.scene
    for clip, start_angle, end_angle in (
        ("deploy", 0.0, deployed_angle),
        ("stow", deployed_angle, 0.0),
    ):
        action = bpy.data.actions.new(name=f"{clip}_{part.name}")
        part.animation_data.action = action
        scene.frame_set(1)
        part.rotation_euler.x = start_angle
        part.keyframe_insert("rotation_euler", index=0, frame=1)
        scene.frame_set(25)
        part.rotation_euler.x = end_angle
        part.keyframe_insert("rotation_euler", index=0, frame=25)
        slot = part.animation_data.action_slot
        part.animation_data.action = None
        track = part.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(name=action.name, start=1, action=action)
        strip.action_slot = slot
        action.use_fake_user = True
    part.rotation_euler.x = 0.0


def restore_stowed_default_pose() -> None:
    with open(GLB_PATH, "rb") as glb_file:
        data = glb_file.read()
    magic, version, _ = struct.unpack_from("<4sII", data, 0)
    offset = 12
    chunks = []
    while offset < len(data):
        length, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        payload = data[offset:offset + length]
        offset += length
        if chunk_type == b"JSON":
            document = json.loads(payload)
            for node in document["nodes"]:
                if node.get("name") in ("SeatPan", "ArmrestL", "ArmrestR"):
                    node.pop("rotation", None)
            payload = json.dumps(document, separators=(",", ":")).encode("utf-8")
            payload += b" " * ((4 - len(payload) % 4) % 4)
        chunks.append(struct.pack("<I4s", len(payload), chunk_type) + payload)
    output = b"".join(chunks)
    with open(GLB_PATH, "wb") as glb_file:
        glb_file.write(struct.pack("<4sII", magic, version, 12 + len(output)) + output)


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 25
    scene.render.fps = 30

    beige = make_material("hw_beige", (0.68, 0.62, 0.50, 1.0), 0.0, 0.72)
    dark = make_material("hw_dark", (0.075, 0.085, 0.085, 1.0), 0.12, 0.58)
    metal = make_material("hw_metal", (0.35, 0.37, 0.36, 1.0), 0.72, 0.36)
    amber = make_material("hw_hazard_amber", (0.62, 0.34, 0.055, 1.0), 0.0, 0.6)
    fabric = make_material("hw_seat_fabric", (0.14, 0.18, 0.15, 1.0), 0.0, 0.92)

    chair = bpy.data.objects.new("PilotChair", None)
    scene.collection.objects.link(chair)

    # The shallow mounting frame stays against the wall when the seat folds away.
    box(chair, "MountPanel", (0.84, 0.075, 1.32), (0.0, 0.105, 0.82), dark, 0.02)
    box(chair, "PanelFace", (0.76, 0.025, 1.23), (0.0, 0.058, 0.82), beige, 0.015)
    box(chair, "RailL", (0.045, 0.06, 0.98), (-0.355, 0.018, 0.81), metal, 0.01)
    box(chair, "RailR", (0.045, 0.06, 0.98), (0.355, 0.018, 0.81), metal, 0.01)
    box(chair, "BackHingeBar", (0.68, 0.09, 0.075), (0.0, -0.01, 0.56), dark)
    cylinder(chair, "SeatAxle", 0.035, 0.73, (0.0, -0.055, 0.56), (0.0, math.pi / 2.0, 0.0), metal)

    # Fixed upholstered back; the pan and arms hinge down from below it.
    back = pivot(chair, "SeatBack", (0.0, -0.095, 0.98))
    box(back, "BackShell", (0.61, 0.12, 0.64), (0.0, 0.0, 0.0), beige, 0.025)
    box(back, "BackCushion", (0.52, 0.055, 0.51), (0.0, -0.083, -0.005), fabric, 0.035)
    box(back, "HeadPad", (0.43, 0.065, 0.13), (0.0, -0.087, 0.225), fabric, 0.03)
    box(back, "LumbarPad", (0.43, 0.065, 0.14), (0.0, -0.087, -0.19), fabric, 0.03)

    seat = pivot(chair, "SeatPan", (0.0, -0.12, 0.56))
    box(seat, "PanShell", (0.60, 0.46, 0.085), (0.0, -0.22, 0.0), beige, 0.022)
    box(seat, "PanCushion", (0.53, 0.39, 0.055), (0.0, -0.225, 0.052), fabric, 0.025)
    box(seat, "FrontWarningBand", (0.49, 0.025, 0.025), (0.0, -0.442, -0.01), amber, 0.004)
    orient_children_for_stow(seat)
    animate_fold(seat, -math.pi / 2.0)

    arm_l = pivot(chair, "ArmrestL", (-0.365, -0.12, 0.70))
    box(arm_l, "ArmLFrame", (0.085, 0.38, 0.06), (0.0, -0.18, 0.0), metal, 0.018)
    box(arm_l, "ArmLPadding", (0.072, 0.31, 0.035), (0.0, -0.18, 0.043), dark, 0.015)
    orient_children_for_stow(arm_l)
    cylinder(chair, "ArmHingeL", 0.027, 0.10, (-0.365, -0.12, 0.70), (0.0, math.pi / 2.0, 0.0), amber)
    animate_fold(arm_l, -math.pi / 2.0)

    arm_r = pivot(chair, "ArmrestR", (0.365, -0.12, 0.70))
    box(arm_r, "ArmRFrame", (0.085, 0.38, 0.06), (0.0, -0.18, 0.0), metal, 0.018)
    box(arm_r, "ArmRPadding", (0.072, 0.31, 0.035), (0.0, -0.18, 0.043), dark, 0.015)
    orient_children_for_stow(arm_r)
    cylinder(chair, "ArmHingeR", 0.027, 0.10, (0.365, -0.12, 0.70), (0.0, math.pi / 2.0, 0.0), amber)
    animate_fold(arm_r, -math.pi / 2.0)

    # Recessed fasteners and a small mechanical release keep the wall unit readable.
    for x in (-0.33, 0.33):
        for z in (0.28, 1.34):
            cylinder(chair, f"Fastener_{x}_{z}", 0.018, 0.012, (x, 0.041, z), (math.pi / 2.0, 0.0, 0.0), metal)
    box(chair, "ReleaseLatch", (0.13, 0.055, 0.055), (0.0, -0.025, 0.49), amber, 0.012)
    box(chair, "LatchGrip", (0.08, 0.035, 0.02), (0.0, -0.063, 0.49), metal, 0.006)

    os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
    for obj in scene.objects:
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = True
        if obj.name in ("SeatPan", "ArmrestL", "ArmrestR"):
            obj.rotation_euler.x = 0.0
    scene.frame_set(1)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    for obj in scene.objects:
        if obj.animation_data:
            for track in obj.animation_data.nla_tracks:
                track.mute = False

    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = chair
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_merge_animation="NLA_TRACK",
        export_yup=True,
        export_apply=True,
    )
    # NLA evaluation leaks into the exported rest transform; the local mesh is already folded.
    restore_stowed_default_pose()


main()
