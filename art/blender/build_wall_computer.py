"""Build the wall computer kit: hw_wall_computer.blend + the exported glTF.

Run headless from the repo root:
    blender --background --factory-startup --python art/blender/build_wall_computer.py

The piece is a wall-mounted ship computer: a flush backplate the operator reads through a
recessed slot, and a blade module that slides out of the slot and folds down 32 degrees to
face them. The single "unfold" action runs stowed (frame 1) -> slid out (frame 12) -> folded
down (frame 24); Godot plays it forward to deploy and backwards to stow. Authored Z-up with
the wall at +Y and the front at -Y, which the glTF export maps to Godot's +Z front.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND_PATH = os.path.join(ROOT, "art", "blender", "wall_computer_kit.blend")
GLB_PATH = os.path.join(ROOT, "game", "assets", "models", "hullwatch", "cockpit", "hw_wall_computer.glb")


def make_material(name: str, base: tuple, metallic: float, roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
    return material


def box(parent: bpy.types.Object, name: str, size: tuple, location: tuple, material: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = Vector(location)
    obj.parent = parent
    obj.data.materials.append(material)
    return obj


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    case = make_material("hw_beige", (0.72, 0.68, 0.58, 1.0), 0.0, 0.65)
    dark = make_material("hw_dark", (0.07, 0.07, 0.08, 1.0), 0.1, 0.5)
    metal = make_material("hw_metal", (0.33, 0.35, 0.39, 1.0), 0.7, 0.35)
    hazard = make_material("hw_hazard_amber", (0.62, 0.36, 0.05, 1.0), 0.0, 0.55)
    screen = make_material("hw_phosphor_green", (0.02, 0.06, 0.03, 1.0), 0.0, 0.3)

    root = bpy.data.objects.new("hw_wall_computer", None)
    scene.collection.objects.link(root)

    box(root, "frame", (0.64, 0.05, 0.74), (0.0, 0.025, 0.0), dark)
    box(root, "slot_bottom", (0.64, 0.11, 0.05), (0.0, -0.055, -0.345), case)
    box(root, "slot_top", (0.64, 0.11, 0.05), (0.0, -0.055, 0.345), case)
    box(root, "slot_left", (0.05, 0.11, 0.74), (-0.295, -0.055, 0.0), case)
    box(root, "slot_right", (0.05, 0.11, 0.74), (0.295, -0.055, 0.0), case)
    box(root, "rail_left", (0.02, 0.02, 0.62), (-0.262, -0.080, 0.0), metal)
    box(root, "rail_right", (0.02, 0.02, 0.62), (0.262, -0.080, 0.0), metal)
    box(root, "label_plate", (0.20, 0.02, 0.05), (0.16, -0.012, 0.295), hazard)
    box(root, "warning_stripe", (0.30, 0.015, 0.03), (-0.10, -0.014, -0.315), hazard)

    module = bpy.data.objects.new("module", None)
    scene.collection.objects.link(module)
    module.parent = root
    module.location = (0.0, -0.06, 0.31)
    module.rotation_mode = "XYZ"
    box(module, "module_back", (0.56, 0.07, 0.63), (0.0, 0.035, -0.315), case)
    box(module, "bezel", (0.52, 0.02, 0.50), (0.0, -0.01, -0.31), dark)
    box(module, "Screen", (0.46, 0.012, 0.40), (0.0, -0.024, -0.31), screen)
    box(module, "handle", (0.20, 0.06, 0.035), (0.0, -0.02, -0.585), metal)
    box(module, "runner_left", (0.03, 0.03, 0.60), (-0.262, 0.0, -0.315), metal)
    box(module, "runner_right", (0.03, 0.03, 0.60), (0.262, 0.0, -0.315), metal)
    box(module, "Led", (0.03, 0.02, 0.02), (0.21, -0.035, -0.075), hazard)

    scene.frame_start = 1
    scene.frame_end = 24
    module.keyframe_insert("location", frame=1)
    module.keyframe_insert("rotation_euler", frame=1)
    module.location = (0.0, -0.18, 0.31)
    module.keyframe_insert("location", frame=12)
    module.keyframe_insert("rotation_euler", frame=12)
    module.rotation_euler = (math.radians(-32.0), 0.0, 0.0)
    module.keyframe_insert("location", frame=24)
    module.keyframe_insert("rotation_euler", frame=24)
    if module.animation_data and module.animation_data.action:
        module.animation_data.action.name = "unfold"

    os.makedirs(os.path.dirname(GLB_PATH), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_yup=True,
        export_apply=True,
    )


main()
