"""Build sealed drive and tank housings with external service covers."""

import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND_PATH = os.path.join(ROOT, "art", "blender", "ion_drive_kit.blend")
GLB_PATH = os.path.join(ROOT, "game", "assets", "models", "hullwatch", "exterior", "hw_ion_drive.glb")
TANK_PATH = os.path.join(os.path.dirname(GLB_PATH), "hw_xenonite_tank.glb")


def material(name: str, color: tuple, metallic: float, roughness: float) -> bpy.types.Material:
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	shader = mat.node_tree.nodes.get("Principled BSDF")
	if shader:
		shader.inputs["Base Color"].default_value = color
		shader.inputs["Metallic"].default_value = metallic
		shader.inputs["Roughness"].default_value = roughness
	return mat


def box(parent: bpy.types.Object, name: str, size: tuple, location: tuple,
		mat: bpy.types.Material, bevel: float = 0.012) -> bpy.types.Object:
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
	obj.data.materials.append(mat)
	if bevel > 0.0:
		modifier = obj.modifiers.new("Stamped edge", "BEVEL")
		modifier.width = min(bevel, min(size) * 0.2)
		modifier.segments = 2
	return obj


def cylinder(parent: bpy.types.Object, name: str, radius: float, depth: float,
		location: tuple, mat: bpy.types.Material, vertices: int = 12) -> bpy.types.Object:
	bpy.ops.mesh.primitive_cylinder_add(
		vertices=vertices, radius=radius, depth=depth,
		location=(0.0, 0.0, 0.0), rotation=(math.pi * 0.5, 0.0, 0.0),
	)
	obj = bpy.context.object
	obj.name = name
	obj.parent = parent
	obj.location = Vector(location)
	obj.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
	obj.data.materials.append(mat)
	return obj


def octagonal_shell(parent: bpy.types.Object, name: str, outer_radius: float,
		inner_radius: float, y_front: float, y_back: float,
		mat: bpy.types.Material, sides: int = 8) -> bpy.types.Object:
	verts = []
	for y in (y_front, y_back):
		for radius in (outer_radius, inner_radius):
			for index in range(sides):
				angle = math.tau * (index + 0.5) / sides
				verts.append((radius * math.cos(angle), y, radius * math.sin(angle)))
	faces = []
	for index in range(sides):
		next_index = (index + 1) % sides
		front_outer, front_inner = index, sides + index
		back_outer, back_inner = 2 * sides + index, 3 * sides + index
		next_front_outer, next_front_inner = next_index, sides + next_index
		next_back_outer, next_back_inner = 2 * sides + next_index, 3 * sides + next_index
		faces.extend([
			(front_outer, next_front_outer, next_back_outer, back_outer),
			(front_inner, back_inner, next_back_inner, next_front_inner),
			(front_outer, front_inner, next_front_inner, next_front_outer),
			(back_outer, next_back_outer, next_back_inner, back_inner),
		])
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata(verts, [], faces)
	mesh.update()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	obj.data.materials.append(mat)
	return obj


def ion_plume(parent: bpy.types.Object, name: str, y_near: float, y_far: float,
		radius_near: float, radius_far: float, mat: bpy.types.Material) -> bpy.types.Object:
	sides = 16
	verts = []
	for y, radius in ((y_near, radius_near), (y_far, radius_far)):
		for index in range(sides):
			angle = math.tau * index / sides
			verts.append((radius * math.cos(angle), y, radius * math.sin(angle)))
	faces = []
	for index in range(sides):
		next_index = (index + 1) % sides
		faces.append((index, next_index, sides + next_index, sides + index))
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata(verts, [], faces)
	mesh.update()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	obj.data.materials.append(mat)
	return obj


def grid_wires(parent: bpy.types.Object, y: float, mat: bpy.types.Material) -> bpy.types.Object:
	mesh = bpy.data.meshes.new("AcceleratorGridWires")
	bm = bmesh.new()
	for offset in (-0.17, -0.085, 0.0, 0.085, 0.17):
		for size, location in [
			((0.56, 0.014, 0.012), (0.0, y - 0.012, offset)),
			((0.012, 0.014, 0.56), (offset, y - 0.012, 0.0)),
		]:
			created = bmesh.ops.create_cube(bm, size=1.0)
			bmesh.ops.scale(bm, vec=Vector(size), verts=created["verts"])
			bmesh.ops.translate(bm, vec=Vector(location), verts=created["verts"])
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new("AcceleratorGridWires", mesh)
	bpy.context.scene.collection.objects.link(obj)
	obj.parent = parent
	obj.data.materials.append(mat)
	return obj


def service_cover(parent: bpy.types.Object, location: tuple, width: float,
        height: float, case: bpy.types.Material, metal: bpy.types.Material,
        dark: bpy.types.Material) -> None:
    hinge = bpy.data.objects.new("ServiceCoverHinge", None)
    bpy.context.scene.collection.objects.link(hinge)
    hinge.parent = parent
    hinge.location = location
    box(hinge, "ServiceCover", (width, 0.025, height), (0.0, 0.0, -height / 2), case)
    box(hinge, "ServiceHandle", (width * 0.5, 0.035, 0.018),
        (0.0, -0.025, -height * 0.8), metal, 0.004)
    for x in (-width * 0.4, width * 0.4):
        cylinder(hinge, "CoverFastener", 0.009, 0.012,
            (x, -0.018, -height * 0.85), dark, 8)
    # A separate opaque bulkhead stays behind the removable hardware cover.
    for name, angles in (("open_service", (0.0, -100.0)),
                         ("close_service", (-100.0, 0.0))):
        hinge.animation_data_clear()
        for frame, angle in zip((1, 19), angles):
            hinge.rotation_euler.x = math.radians(angle)
            hinge.keyframe_insert("rotation_euler", frame=frame)
        action = hinge.animation_data.action
        action.name = parent.name + "_" + name
        action.use_fake_user = True
    # Separate NLA tracks export stable clip names for both selected subtrees.
    hinge.animation_data_clear()
    hinge.animation_data_create()
    for name in ("open_service", "close_service"):
        track = hinge.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, bpy.data.actions[parent.name + "_" + name])
        track.mute = True
    hinge.rotation_euler.x = 0.0


def export_model(root: bpy.types.Object, path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [root, *root.children_recursive]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
        export_apply=True, export_animations=True, export_animation_mode="NLA_TRACKS",
        export_anim_slide_to_zero=True)
    print(f"Wrote {path}")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 24
    scene.frame_start = 1
    scene.frame_end = 19
    case = material("hw_ion_case", (0.56, 0.55, 0.49, 1.0), 0.25, 0.65)
    metal = material("hw_ion_service_metal", (0.43, 0.41, 0.36, 1.0), 0.55, 0.48)
    dark = material("hw_ion_recess", (0.035, 0.045, 0.052, 1.0), 0.3, 0.52)
    ceramic = material("hw_ion_ceramic", (0.59, 0.57, 0.49, 1.0), 0.12, 0.7)
    hazard = material("hw_ion_hazard", (0.63, 0.35, 0.08, 1.0), 0.12, 0.55)
    plume_mat = material("hw_ion_plume", (0.08, 0.32, 0.9, 0.18), 0.0, 0.4)

    root = bpy.data.objects.new("hw_ion_drive", None)
    scene.collection.objects.link(root)
    # The hull-facing shoe is at y=0; Blender -Y becomes Godot +Z (aft).
    box(root, "MountShoe", (0.62, 0.06, 0.90), (0.0, 0.03, 0.0), metal)
    box(root, "IsolationPlate", (0.48, 0.10, 0.74), (0.0, -0.08, 0.0), dark)
    for x in (-0.24, 0.24):
        for z in (-0.33, 0.33):
            cylinder(root, "MountBolt", 0.035, 0.045, (x, -0.11, z), metal, 8)

    octagonal_shell(root, "IonShroud", 0.43, 0.34, -0.14, -1.24, case)
    # Solid end faces prevent any view through the discharge mesh into the chamber.
    cylinder(root, "SealedChamber", 0.338, 1.02, (0.0, -0.69, 0.0), dark, 16)
    for y in (-0.20, -0.66, -1.17):
        octagonal_shell(root, "ShroudCollar", 0.45, 0.40, y, y - 0.055, metal)
        for angle in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4):
            cylinder(root, "CollarFastener", 0.015, 0.025,
                (0.408 * math.cos(angle), y - 0.065, 0.408 * math.sin(angle)), dark, 8)
    for x in (-0.365, 0.365):
        box(root, "CowlRib", (0.03, 0.94, 0.04), (x, -0.68, 0.15), metal, 0.006)
        for y in (-0.30, -0.96):
            box(root, "ServiceBracket", (0.035, 0.09, 0.12), (x, y, 0.18), metal)
    box(root, "CowlRibTop", (0.10, 0.94, 0.08), (0.0, -0.68, 0.39), metal)
    box(root, "CowlRibBottom", (0.10, 0.94, 0.08), (0.0, -0.68, -0.39), metal)
    grid_wires(root, -1.20, metal)

    box(root, "PowerProcessor", (0.48, 0.32, 0.28), (0.0, -0.27, 0.53), case)
    box(root, "PPUFace", (0.34, 0.02, 0.18), (0.0, -0.44, 0.53), dark, 0.0)
    for x in (-0.10, 0.10):
        cylinder(root, "DiagnosticSocket", 0.024, 0.02, (x, -0.462, 0.53), metal, 8)
    service_cover(root, (0.0, -0.48, 0.65), 0.40, 0.22, case, metal, dark)
    box(root, "HazardBand", (0.12, 0.012, 0.022), (0.0, -0.50, 0.59), hazard, 0.0)
    for x in (-0.16, -0.08, 0.0, 0.08, 0.16):
        for z in (-0.43, 0.43):
            box(root, "RadiatorFin", (0.035, 0.57, 0.11), (x, -0.71, z), metal, 0.006)
    cylinder(root, "FeedRegulator", 0.095, 0.22, (0.23, -0.36, 0.18), ceramic, 10)
    cylinder(root, "PressureGauge", 0.085, 0.055, (0.23, -0.48, 0.30), dark, 16)
    box(root, "GaugeNeedle", (0.012, 0.012, 0.055), (0.23, -0.516, 0.30), hazard, 0.0)
    box(root, "FeedLineA", (0.045, 0.68, 0.045), (0.31, -0.76, 0.18), metal)
    box(root, "FeedLineB", (0.045, 0.045, 0.24), (0.31, -1.08, 0.18), metal)
    box(root, "ServiceValve", (0.18, 0.05, 0.06), (0.34, -0.49, 0.20), hazard, 0.0)
    cylinder(root, "NeutralizerBody", 0.070, 0.38, (0.32, -1.02, -0.16), metal, 10)
    cylinder(root, "NeutralizerKeeper", 0.082, 0.07, (0.32, -1.25, -0.16), ceramic, 10)
    box(root, "KeeperServiceTab", (0.16, 0.07, 0.10), (0.32, -1.18, -0.26), metal)
    box(root, "LabelBracket", (0.06, 0.04, 0.14), (0.0, -0.48, -0.52), metal)
    box(root, "ServiceLabel", (0.30, 0.015, 0.11), (0.0, -0.48, -0.60), dark, 0.0)
    box(root, "ServiceLabelStripe", (0.19, 0.018, 0.022), (0.0, -0.49, -0.60), hazard, 0.0)
    plume = ion_plume(root, "IonPlume", -1.25, -2.15, 0.04, 0.12, plume_mat)
    plume["hidden_until_transit"] = True

    tank = bpy.data.objects.new("hw_xenonite_tank", None)
    scene.collection.objects.link(tank)
    box(tank, "TankMountShoe", (0.36, 0.04, 0.68), (0.0, -0.02, 0.0), metal)
    box(tank, "SealedTankHousing", (0.30, 0.43, 0.58), (0.0, -0.245, 0.0), case, 0.045)
    for z in (-0.24, 0.24):
        box(tank, "TankCollar", (0.34, 0.45, 0.045), (0.0, -0.245, z), metal)
        for x in (-0.16, 0.16):
            box(tank, "TankBracket", (0.025, 0.13, 0.09), (x, -0.06, z), metal)
    for x in (-0.155, 0.155):
        box(tank, "TankRib", (0.018, 0.025, 0.44), (x, -0.468, 0.0), metal, 0.004)
    box(tank, "UVServiceAssembly", (0.23, 0.035, 0.34), (0.0, -0.49, 0.0), dark)
    for z in (-0.10, 0.0, 0.10):
        box(tank, "DriverCartridge", (0.16, 0.025, 0.05), (0.0, -0.518, z), metal)
    for x in (-0.08, 0.08):
        cylinder(tank, "TankDiagnosticSocket", 0.014, 0.015, (x, -0.525, 0.14), ceramic, 8)
    service_cover(tank, (0.0, -0.55, 0.19), 0.25, 0.38, case, metal, dark)
    box(tank, "ServiceMark", (0.07, 0.012, 0.012), (0.0, -0.574, 0.12), hazard, 0.0)

    scene.frame_set(1)
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(corner) for obj in tank.children_recursive
              if obj.type == "MESH" for corner in obj.bound_box]
    size = [max(p[i] for p in points) - min(p[i] for p in points) for i in range(3)]
    assert size[0] <= 0.38 and size[1] <= 0.60 and size[2] <= 0.70, size
    print(f"Tank envelope Blender XYZ: {size}; Godot width/height/aft depth: {size[0]:.3f}/{size[2]:.3f}/{size[1]:.3f} m")
    # Keep both authored objects at the local mount origin; export each subtree.
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
    export_model(root, GLB_PATH)
    export_model(tank, TANK_PATH)
    print(f"Wrote {BLEND_PATH}")


if __name__ == "__main__":
    main()
