## Generates the cramped space-station ship layout (spine corridor + seven rooms + doorway gaps)
## as res://scenes/ship_geometry.tscn. Geometry is built in memory and packed, so it is
## reproducible from the tables below.
## Re-run after changing the layout:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_ship_geometry.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/ship_geometry.tscn"

const MATERIAL_FLOOR: String = "res://src/data/materials/mat_floor_grate.tres"
const MATERIAL_WALL_PAINTED: String = "res://src/data/materials/mat_wall_painted.tres"
const MATERIAL_WALL_CONTAINER: String = "res://src/data/materials/mat_wall_container.tres"
const MATERIAL_CEILING: String = "res://src/data/materials/mat_panel_scratched.tres"
const MATERIAL_STRIP: String = "res://src/data/materials/mat_light_strip.tres"
const MATERIAL_CONDUIT: String = "res://src/data/materials/mat_metal_rusted.tres"
const MATERIAL_XENON: String = "res://src/data/materials/mat_xenon_metal.tres"

const WALL_THICKNESS: float = 0.2
const ROOM_HEIGHT: float = 3.0
const SLAB_THICKNESS: float = 0.2
const WALL_CENTER_Y: float = 1.5
const FLOOR_CENTER_Y: float = -0.1
const CEILING_CENTER_Y: float = 3.1

const SPACE_NAMES: Array[String] = [
	"Cockpit",
	"Corridor",
	"Quarters",
	"LifeSupport",
	"Galley",
	"WaterCloset",
	"Storage",
	"EngineBay",
	"Airlock",
]

var _root: Node3D
var _materials: Dictionary = {}
var _failures: int = 0


func _initialize() -> void:
	_load_materials()
	if _failures == 0:
		_build()
	_save()


func _load_materials() -> void:
	for path: String in [MATERIAL_FLOOR, MATERIAL_WALL_PAINTED, MATERIAL_WALL_CONTAINER, MATERIAL_CEILING, MATERIAL_STRIP, MATERIAL_CONDUIT, MATERIAL_XENON]:
		var material: Material = load(path) as Material
		if material == null:
			_failures += 1
			print("FAIL: missing material ", path)
		else:
			_materials[path] = material


func _build() -> void:
	_root = Node3D.new()
	_root.name = "ShipGeometry"
	_build_cockpit()
	_build_corridor()
	_build_quarters()
	_build_life_support()
	_build_galley()
	_build_water_closet()
	_build_storage()
	_build_airlock()
	_build_engine_bay()
	_build_dressing()


func _make_space(space_name: String) -> StaticBody3D:
	var space: StaticBody3D = StaticBody3D.new()
	space.name = space_name
	_root.add_child(space)
	return space


func _add_part(space: Node3D, part_name: String, center: Vector3, size: Vector3, material_path: String, rotation_degrees: Vector3 = Vector3.ZERO) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = part_name + "Shape"
	shape_node.shape = shape
	shape_node.position = center
	shape_node.rotation_degrees = rotation_degrees
	space.add_child(shape_node)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = part_name + "Mesh"
	mesh_node.mesh = mesh
	mesh_node.material_override = _materials[material_path] as Material
	mesh_node.position = center
	mesh_node.rotation_degrees = rotation_degrees
	space.add_child(mesh_node)


func _add_floor(space: StaticBody3D, center_x: float, center_z: float, size_x: float, size_z: float) -> void:
	_add_part(space, "Floor", Vector3(center_x, FLOOR_CENTER_Y, center_z), Vector3(size_x, SLAB_THICKNESS, size_z), MATERIAL_FLOOR)


func _add_ceiling(space: StaticBody3D, center_x: float, center_z: float, size_x: float, size_z: float) -> void:
	_add_part(space, "Ceiling", Vector3(center_x, CEILING_CENTER_Y, center_z), Vector3(size_x, SLAB_THICKNESS, size_z), MATERIAL_XENON)


func _add_wall(space: StaticBody3D, part_name: String, center_x: float, center_z: float, size_x: float, size_z: float, material_path: String) -> void:
	_add_part(space, part_name, Vector3(center_x, WALL_CENTER_Y, center_z), Vector3(size_x, ROOM_HEIGHT, size_z), material_path)


## Faceted corridor side segment: short lower wall, an inward-leaning cant and an upper
## header, split with the same spans the flat side walls used. `side` is -1 for west, +1 east.
func _add_corridor_segment(space: StaticBody3D, side_name: String, segment: String, side: float, center_z: float, span: float) -> void:
	var cant_angle: float = rad_to_deg(atan(0.35 / 1.8))
	_add_part(space, "Wall%s_%s" % [side_name, segment], Vector3(0.8 * side, 0.4, center_z), Vector3(0.2, 0.8, span), MATERIAL_XENON)
	_add_part(space, "Cant%s_%s" % [side_name, segment], Vector3(0.625 * side, 1.7, center_z), Vector3(0.12, 1.8, span), MATERIAL_XENON, Vector3(0.0, 0.0, cant_angle * side))
	_add_part(space, "Header%s_%s" % [side_name, segment], Vector3(0.45 * side, 2.8, center_z), Vector3(0.2, 0.4, span), MATERIAL_XENON)


## Four 45-degree corner chamfer panels for a room interior x[x_min, x_max] z[z_min, z_max].
func _add_chamfers(space: StaticBody3D, x_min: float, z_min: float, x_max: float, z_max: float, cut: float = 0.9) -> void:
	var offset: float = cut * 0.5
	var names: Array[String] = ["A", "B", "C", "D"]
	var edge_x: Array[float] = [x_min, x_max, x_max, x_min]
	var edge_z: Array[float] = [z_min, z_min, z_max, z_max]
	var dx: Array[float] = [1.0, -1.0, -1.0, 1.0]
	var dz: Array[float] = [1.0, 1.0, -1.0, -1.0]
	for i: int in names.size():
		_add_part(
			space,
			"Chamfer" + names[i],
			Vector3(edge_x[i] + offset * dx[i], WALL_CENTER_Y, edge_z[i] + offset * dz[i]),
			Vector3(cut * sqrt(2.0), ROOM_HEIGHT, 0.2),
			MATERIAL_XENON,
			Vector3(0.0, 45.0 * dx[i] * dz[i], 0.0)
		)


## COCKPIT interior x[-3.4, 3.4], z[-18.8, -14.2]. South wall split around the 1.4 m corridor doorway.
func _build_cockpit() -> void:
	var space: StaticBody3D = _make_space("Cockpit")
	_add_floor(space, 0.0, -16.5, 7.2, 5.0)
	_add_ceiling(space, 0.0, -16.5, 7.2, 5.0)
	_add_wall(space, "WallN", 0.0, -18.9, 7.2, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallE", 3.5, -16.5, WALL_THICKNESS, 5.0, MATERIAL_XENON)
	_add_wall(space, "WallW", -3.5, -16.5, WALL_THICKNESS, 5.0, MATERIAL_XENON)
	_add_wall(space, "WallS_A", -2.15, -14.1, 2.9, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallS_B", 2.15, -14.1, 2.9, WALL_THICKNESS, MATERIAL_XENON)
	_add_chamfers(space, -3.4, -18.8, 3.4, -14.2)


## CORRIDOR spine interior x[-0.7, 0.7], z[-14.0, 1.4]. Each side is a faceted cross-section
## (lower wall, inward-leaning cant, upper header) split around every east/west doorway gap;
## the cockpit south wall and engine-bay north wall close the ends.
func _build_corridor() -> void:
	var space: StaticBody3D = _make_space("Corridor")
	_add_floor(space, 0.0, -6.3, 1.8, 15.8)
	_add_ceiling(space, 0.0, -6.3, 1.3, 15.8)
	_add_corridor_segment(space, "W", "A", -1.0, -12.4, 3.6)
	_add_corridor_segment(space, "W", "B", -1.0, -8.0, 2.8)
	_add_corridor_segment(space, "W", "C", -1.0, -3.6, 3.6)
	_add_corridor_segment(space, "W", "D", -1.0, 0.5, 2.2)
	_add_corridor_segment(space, "E", "A", 1.0, -10.2, 8.0)
	_add_corridor_segment(space, "E", "B", 1.0, -3.6, 2.8)
	_add_corridor_segment(space, "E", "C", 1.0, 0.3, 2.6)


## QUARTERS interior x[-5.4, -0.9], z[-12.6, -8.2]. East side is the corridor wall;
## its doorway gap sits at z[-10.6, -9.4].
func _build_quarters() -> void:
	var space: StaticBody3D = _make_space("Quarters")
	_add_floor(space, -3.25, -10.4, 4.7, 4.8)
	_add_ceiling(space, -3.25, -10.4, 4.7, 4.8)
	_add_wall(space, "WallN", -3.2, -12.7, 4.8, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallS", -3.2, -8.1, 4.8, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallW", -5.5, -10.4, WALL_THICKNESS, 4.8, MATERIAL_XENON)
	_add_chamfers(space, -5.4, -12.6, -0.9, -8.2)


## LIFE_SUPPORT interior x[-4.4, -0.9], z[-7.6, -5.0]. East side is the corridor wall;
## its doorway gap sits at z[-6.6, -5.4].
func _build_life_support() -> void:
	var space: StaticBody3D = _make_space("LifeSupport")
	_add_floor(space, -2.75, -6.3, 3.7, 3.0)
	_add_ceiling(space, -2.75, -6.3, 3.7, 3.0)
	_add_wall(space, "WallN", -2.7, -7.7, 3.8, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallS", -2.7, -4.9, 3.8, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallW", -4.5, -6.3, WALL_THICKNESS, 3.0, MATERIAL_XENON)
	_add_chamfers(space, -4.4, -7.6, -0.9, -5.0)


## GALLEY interior x[0.9, 4.9], z[-7.6, -4.0]. West side is the corridor wall;
## its doorway gap sits at z[-6.2, -5.0].
func _build_galley() -> void:
	var space: StaticBody3D = _make_space("Galley")
	_add_floor(space, 3.0, -5.8, 4.2, 4.0)
	_add_ceiling(space, 3.0, -5.8, 4.2, 4.0)
	_add_wall(space, "WallN", 2.95, -7.7, 4.3, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallS", 2.95, -3.9, 4.3, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallE", 5.0, -5.8, WALL_THICKNESS, 4.0, MATERIAL_XENON)
	_add_chamfers(space, 0.9, -7.6, 4.9, -4.0)


## WATER_CLOSET interior x[0.9, 3.5], z[-3.0, -0.8]. West side is the corridor wall;
## its doorway gap sits at z[-2.2, -1.0].
func _build_water_closet() -> void:
	var space: StaticBody3D = _make_space("WaterCloset")
	_add_floor(space, 2.3, -1.9, 2.8, 2.6)
	_add_ceiling(space, 2.3, -1.9, 2.8, 2.6)
	_add_wall(space, "WallN", 2.25, -3.1, 2.9, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallS", 2.25, -0.7, 2.9, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallE", 3.6, -1.9, WALL_THICKNESS, 2.6, MATERIAL_XENON)
	_add_chamfers(space, 0.9, -3.0, 3.5, -0.8, 0.25)


## STORAGE interior x[-4.6, -0.9], z[-3.0, 0.6]. East side is the corridor wall;
## its doorway gap sits at z[-1.8, -0.6]. West wall is split around the 1.2 m airlock
## doorway at z[-1.6, -0.4].
func _build_storage() -> void:
	var space: StaticBody3D = _make_space("Storage")
	_add_floor(space, -2.85, -1.2, 3.9, 4.0)
	_add_ceiling(space, -2.85, -1.2, 3.9, 4.0)
	_add_wall(space, "WallN", -2.8, -3.1, 4.0, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallS", -2.8, 0.7, 4.0, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallW_A", -4.7, -2.4, WALL_THICKNESS, 1.6, MATERIAL_XENON)
	_add_wall(space, "WallW_B", -4.7, 0.2, WALL_THICKNESS, 1.2, MATERIAL_XENON)
	_add_chamfers(space, -4.6, -3.0, -0.9, 0.6)


## AIRLOCK interior x[-6.8, -4.8], z[-2.2, -0.2]. East side shares the storage wall
## (doorway gap z[-1.6, -0.4]); the west wall is split around the 1.0 m outer doorway
## at z[-1.7, -0.7], which opens straight into vacuum.
func _build_airlock() -> void:
	var space: StaticBody3D = _make_space("Airlock")
	_add_floor(space, -5.8, -1.2, 2.0, 2.0)
	_add_ceiling(space, -5.8, -1.2, 2.0, 2.0)
	_add_wall(space, "WallN", -5.9, -2.3, 2.2, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallS", -5.9, -0.1, 2.2, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallW_A", -6.9, -2.0, WALL_THICKNESS, 0.6, MATERIAL_XENON)
	_add_wall(space, "WallW_B", -6.9, -0.4, WALL_THICKNESS, 0.6, MATERIAL_XENON)
	_add_chamfers(space, -6.8, -2.2, -4.8, -0.2, 0.25)


## ENGINE_BAY interior x[-3.6, 3.6], z[1.6, 7.8]. North wall split around the 1.4 m corridor doorway.
func _build_engine_bay() -> void:
	var space: StaticBody3D = _make_space("EngineBay")
	_add_floor(space, 0.0, 4.7, 7.6, 6.6)
	_add_ceiling(space, 0.0, 4.7, 7.6, 6.6)
	_add_wall(space, "WallS", 0.0, 7.9, 7.6, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallE", 3.7, 4.7, WALL_THICKNESS, 6.6, MATERIAL_XENON)
	_add_wall(space, "WallW", -3.7, 4.7, WALL_THICKNESS, 6.6, MATERIAL_XENON)
	_add_wall(space, "WallN_A", -2.25, 1.5, 3.1, WALL_THICKNESS, MATERIAL_XENON)
	_add_wall(space, "WallN_B", 2.25, 1.5, 3.1, WALL_THICKNESS, MATERIAL_XENON)
	_add_chamfers(space, -3.6, 1.6, 3.6, 7.8)


## Visual greeble only (no collision): ceiling light strips, corridor ribs, conduit runs.
func _build_dressing() -> void:
	_add_dressing("Corridor", "Strip", Vector3(0, 2.94, -6.3), Vector3(0.22, 0.04, 14.2), MATERIAL_STRIP)
	_add_dressing("Cockpit", "Strip", Vector3(0, 2.94, -16.5), Vector3(0.22, 0.04, 4.0), MATERIAL_STRIP)
	_add_dressing("Quarters", "Strip", Vector3(-3.15, 2.94, -10.4), Vector3(0.22, 0.04, 3.8), MATERIAL_STRIP)
	_add_dressing("LifeSupport", "Strip", Vector3(-2.65, 2.94, -6.3), Vector3(2.9, 0.04, 0.22), MATERIAL_STRIP)
	_add_dressing("Galley", "Strip", Vector3(2.9, 2.94, -5.8), Vector3(0.22, 0.04, 3.0), MATERIAL_STRIP)
	_add_dressing("WaterCloset", "Strip", Vector3(2.2, 2.94, -1.9), Vector3(0.22, 0.04, 1.6), MATERIAL_STRIP)
	_add_dressing("Storage", "Strip", Vector3(-2.75, 2.94, -1.2), Vector3(0.22, 0.04, 3.0), MATERIAL_STRIP)
	_add_dressing("Airlock", "Strip", Vector3(-5.8, 2.94, -1.2), Vector3(0.22, 0.04, 1.6), MATERIAL_STRIP)
	_add_dressing("EngineBay", "Strip", Vector3(0, 2.94, 4.7), Vector3(6.6, 0.04, 0.22), MATERIAL_STRIP)
	var spine_z: Array[float] = [-13.0, -10.6, -8.2, -5.8, -3.4, -1.0, 1.2]
	for i: int in spine_z.size():
		_add_dressing("Corridor", "RibW%d" % i, Vector3(-0.66, 0.8, spine_z[i]), Vector3(0.08, 1.6, 0.12), MATERIAL_XENON)
		_add_dressing("Corridor", "RibE%d" % i, Vector3(0.66, 0.8, spine_z[i]), Vector3(0.08, 1.6, 0.12), MATERIAL_XENON)
	_add_dressing("Corridor", "ConduitW", Vector3(-0.34, 2.72, -6.3), Vector3(0.07, 0.07, 15.0), MATERIAL_CONDUIT)
	_add_dressing("Corridor", "ConduitE", Vector3(0.34, 2.72, -6.3), Vector3(0.07, 0.07, 15.0), MATERIAL_CONDUIT)


func _add_dressing(space_name: String, part_name: String, center: Vector3, size: Vector3, material_path: String) -> void:
	var space: Node = _root.get_node_or_null(NodePath(space_name))
	if space == null:
		_failures += 1
		print("FAIL: dressing target missing ", space_name)
		return
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "Dressing" + part_name
	node.mesh = mesh
	node.material_override = _materials[material_path] as Material
	node.position = center
	space.add_child(node)


func _save() -> void:
	if _failures > 0 or _root == null:
		print("FAILURES: ", _failures)
		quit(1)
		return
	_assign_owners(_root, _root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(_root)
	if pack_error != OK:
		print("FAIL: pack error ", pack_error)
		quit(1)
		return
	var save_error: Error = ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		print("FAIL: save error ", save_error)
		quit(1)
		return
	_root.free()
	_root = null
	if not _normalize_output():
		print("FAILURES: ", _failures)
		quit(1)
		return
	if not _verify():
		print("FAILURES: ", _failures)
		quit(1)
		return
	print("PASS: build_ship_geometry")
	quit(0)


## PackedScene.pack() assigns random per-run node unique_ids; strip them so regenerating is byte-stable.
func _normalize_output() -> bool:
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		_failures += 1
		print("FAIL: cannot reopen ", OUTPUT_PATH)
		return false
	var text: String = file.get_as_text()
	file.close()
	var regex: RegEx = RegEx.new()
	regex.compile(" unique_id=\\d+")
	var write_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if write_file == null:
		_failures += 1
		print("FAIL: cannot rewrite ", OUTPUT_PATH)
		return false
	write_file.store_string(regex.sub(text, "", true))
	write_file.close()
	return true


func _assign_owners(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		_assign_owners(child, owner)


func _verify() -> bool:
	var loaded: PackedScene = load(OUTPUT_PATH) as PackedScene
	if loaded == null:
		_failures += 1
		print("FAIL: generated scene did not load")
		return false
	var instance: Node = loaded.instantiate()
	for space_name: String in SPACE_NAMES:
		var space: Node = instance.get_node_or_null(NodePath(space_name))
		if space == null:
			_failures += 1
			print("FAIL: missing space ", space_name)
			continue
		if not (space is StaticBody3D):
			_failures += 1
			print("FAIL: space is not a StaticBody3D: ", space_name)
			continue
		var floor_shape: CollisionShape3D = _find_floor_shape(space)
		if floor_shape == null or floor_shape.shape == null:
			_failures += 1
			print("FAIL: no floor collision in ", space_name)
	print("OK: spaces=", SPACE_NAMES.size(), " parts=", _count_parts(instance))
	instance.free()
	return _failures == 0


func _find_floor_shape(node: Node) -> CollisionShape3D:
	for child: Node in node.get_children():
		if child is CollisionShape3D and child.name.begins_with("Floor"):
			return child as CollisionShape3D
	return null


func _count_parts(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is CollisionShape3D or child is MeshInstance3D:
			count += 1
		count += _count_parts(child)
	return count

