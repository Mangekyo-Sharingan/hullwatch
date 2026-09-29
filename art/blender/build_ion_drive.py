"""Build one serviceable Xenonite ion-drive cassette and export its source and glTF."""

import math
import os

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BLEND_PATH = os.path.join(ROOT, "art", "blender", "ion_drive_kit.blend")
GLB_PATH = os.path.join(ROOT, "game", "assets", "models", "hullwatch", "exterior", "hw_ion_drive.glb")


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


def main() -> None:
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	case = material("hw_ion_case", (0.32, 0.34, 0.35, 1.0), 0.4, 0.62)
	metal = material("hw_ion_service_metal", (0.43, 0.41, 0.36, 1.0), 0.55, 0.48)
	dark = material("hw_ion_recess", (0.035, 0.045, 0.052, 1.0), 0.3, 0.52)
	ceramic = material("hw_ion_ceramic", (0.59, 0.57, 0.49, 1.0), 0.12, 0.7)
	hazard = material("hw_ion_hazard", (0.63, 0.35, 0.08, 1.0), 0.12, 0.55)
	plume_mat = material("hw_ion_plume", (0.08, 0.32, 0.9, 0.18), 0.0, 0.4)

	root = bpy.data.objects.new("hw_ion_drive", None)
	scene.collection.objects.link(root)
	root["drive_type"] = "electric_ion"
	root["working_propellant"] = "xenon"

	# The hull-facing shoe is at y=0; Blender -Y becomes Godot +Z (aft).
	box(root, "MountShoe", (0.62, 0.06, 0.90), (0.0, 0.03, 0.0), metal)
	box(root, "IsolationPlate", (0.48, 0.10, 0.74), (0.0, -0.08, 0.0), dark)
	for x in (-0.24, 0.24):
		for z in (-0.33, 0.33):
			cylinder(root, "MountBolt", 0.035, 0.045, (x, -0.11, z), hazard, 8)

	# Eight-sided, open-back shroud exposes the accelerator lattice rather than a rocket bell.
	octagonal_shell(root, "IonShroud", 0.43, 0.34, -0.14, -1.24, case)
	for y in (-0.20, -0.66, -1.17):
		octagonal_shell(root, "ShroudCollar", 0.45, 0.40, y, y - 0.055, metal)
	box(root, "CowlRibTop", (0.10, 0.94, 0.08), (0.0, -0.68, 0.39), metal)
	box(root, "CowlRibBottom", (0.10, 0.94, 0.08), (0.0, -0.68, -0.39), metal)

	# Xenonite optic stack and screened discharge chamber. Godot replaces this material
	# with the same mottled Xenonite material used on the pressure hull.
	core = octagonal_shell(root, "XenoniteCore", 0.285, 0.225, -0.43, -1.12, ceramic)
	core["material_role"] = "xenonite_ion_optics"
	for y in (-0.49, -0.72, -0.95, -1.15):
		octagonal_shell(root, "AcceleratorGrid", 0.315, 0.29, y, y - 0.025, dark)
		grid_wires(root, y, metal)

	# Human service layer: PPU, regulator, cathode/neutralizer, radiator straps and feed.
	box(root, "PowerProcessor", (0.48, 0.32, 0.28), (0.0, -0.27, 0.53), case)
	box(root, "PPUFace", (0.34, 0.02, 0.18), (0.0, -0.44, 0.53), dark, 0.0)
	box(root, "HazardBand", (0.50, 0.025, 0.055), (0.0, -0.45, 0.61), hazard, 0.0)
	for x in (-0.16, -0.08, 0.0, 0.08, 0.16):
		box(root, "RadiatorFin", (0.035, 0.57, 0.11), (x, -0.71, -0.43), metal, 0.006)
		box(root, "RadiatorFin", (0.035, 0.57, 0.11), (x, -0.71, 0.43), metal, 0.006)

	# Xenon feed regulator and short visible line into the discharge chamber.
	cylinder(root, "XenonRegulator", 0.095, 0.22, (0.23, -0.36, 0.18), ceramic, 10)
	cylinder(root, "PressureGauge", 0.085, 0.055, (0.23, -0.48, 0.30), dark, 16)
	box(root, "GaugeNeedle", (0.012, 0.012, 0.055), (0.23, -0.516, 0.30), hazard, 0.0)
	box(root, "FeedLineA", (0.045, 0.68, 0.045), (0.31, -0.76, 0.18), metal, 0.012)
	box(root, "FeedLineB", (0.045, 0.045, 0.24), (0.31, -1.08, 0.18), metal, 0.012)
	box(root, "ServiceValve", (0.18, 0.05, 0.06), (0.34, -0.49, 0.20), hazard, 0.0)

	# Offset cathode/neutralizer with a replaceable ceramic keeper cap.
	cylinder(root, "NeutralizerBody", 0.070, 0.38, (0.32, -1.02, -0.16), metal, 10)
	cylinder(root, "NeutralizerKeeper", 0.082, 0.07, (0.32, -1.25, -0.16), ceramic, 10)
	box(root, "KeeperServiceTab", (0.16, 0.07, 0.10), (0.32, -1.18, -0.26), hazard, 0.008)

	plume = ion_plume(root, "IonPlume", -1.25, -2.15, 0.04, 0.12, plume_mat)
	plume["hidden_until_transit"] = True

	# Surface marks read as service labels at close range, not decorative lights.
	box(root, "ServiceLabel", (0.30, 0.015, 0.11), (0.0, -0.48, -0.60), dark, 0.0)
	box(root, "ServiceLabelStripe", (0.19, 0.018, 0.022), (0.0, -0.49, -0.60), hazard, 0.0)

	# Keep the source scene clean for inspection and rerendering.
	for obj in scene.objects:
		obj.select_set(False)
	root.select_set(True)
	bpy.context.view_layer.objects.active = root
	bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
	bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", export_apply=True)
	print(f"Wrote {BLEND_PATH}")
	print(f"Wrote {GLB_PATH}")


if __name__ == "__main__":
	main()
