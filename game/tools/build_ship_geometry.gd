## Generates the M4 alpha ship layout (5 rooms + corridors + doorway gaps) as res://scenes/ship_geometry.tscn.
## Geometry is built in memory and packed, so it is reproducible from the tables below.
## Re-run after changing the layout:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_ship_geometry.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/ship_geometry.tscn"

const MATERIAL_FLOOR: String = "res://src/data/materials/mat_floor_grate.tres"
const MATERIAL_WALL_PAINTED: String = "res://src/data/materials/mat_wall_painted.tres"
const MATERIAL_WALL_CONTAINER: String = "res://src/data/materials/mat_wall_container.tres"
const MATERIAL_CEILING: String = "res://src/data/materials/mat_panel_scratched.tres"

const WALL_THICKNESS: float = 0.2
const ROOM_HEIGHT: float = 3.0
const SLAB_THICKNESS: float = 0.2
const WALL_CENTER_Y: float = 1.5
const FLOOR_CENTER_Y: float = -0.1
const CEILING_CENTER_Y: float = 3.1

const SPACE_NAMES: Array[String] = [
	"Habitat",
	"CorridorN",
	"Cockpit",
	"CorridorS",
	"EngineBay",
	"CorridorE",
	"WaterCloset",
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
	for path: String in [MATERIAL_FLOOR, MATERIAL_WALL_PAINTED, MATERIAL_WALL_CONTAINER, MATERIAL_CEILING]:
		var material: Material = load(path) as Material
		if material == null:
			_failures += 1
			print("FAIL: missing material ", path)
		else:
			_materials[path] = material


func _build() -> void:
	_root = Node3D.new()
	_root.name = "ShipGeometry"
	_build_habitat()
	_build_corridor_n()
	_build_cockpit()
	_build_corridor_s()
	_build_engine_bay()
	_build_corridor_e()
	_build_water_closet()


func _make_space(space_name: String) -> StaticBody3D:
	var space: StaticBody3D = StaticBody3D.new()
	space.name = space_name
	_root.add_child(space)
	return space


func _add_part(space: Node3D, part_name: String, center: Vector3, size: Vector3, material_path: String) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	shape_node.name = part_name + "Shape"
	shape_node.shape = shape
	shape_node.position = center
	space.add_child(shape_node)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.name = part_name + "Mesh"
	mesh_node.mesh = mesh
	mesh_node.material_override = _materials[material_path] as Material
	mesh_node.position = center
	space.add_child(mesh_node)


func _add_floor(space: StaticBody3D, center_x: float, center_z: float, size_x: float, size_z: float) -> void:
	_add_part(space, "Floor", Vector3(center_x, FLOOR_CENTER_Y, center_z), Vector3(size_x, SLAB_THICKNESS, size_z), MATERIAL_FLOOR)


func _add_ceiling(space: StaticBody3D, center_x: float, center_z: float, size_x: float, size_z: float) -> void:
	_add_part(space, "Ceiling", Vector3(center_x, CEILING_CENTER_Y, center_z), Vector3(size_x, SLAB_THICKNESS, size_z), MATERIAL_CEILING)


func _add_wall(space: StaticBody3D, part_name: String, center_x: float, center_z: float, size_x: float, size_z: float, material_path: String) -> void:
	_add_part(space, part_name, Vector3(center_x, WALL_CENTER_Y, center_z), Vector3(size_x, ROOM_HEIGHT, size_z), material_path)


## HABITAT interior x[-6, 6], z[-4, 4]. North/south walls are split around the 3 m doorway gaps.
func _build_habitat() -> void:
	var space: StaticBody3D = _make_space("Habitat")
	_add_floor(space, 0.0, 0.0, 12.4, 8.4)
	_add_ceiling(space, 0.0, 0.0, 12.4, 8.4)
	_add_wall(space, "WallN_A", -3.85, -4.1, 4.7, WALL_THICKNESS, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallN_B", 3.85, -4.1, 4.7, WALL_THICKNESS, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallS_A", -3.85, 4.1, 4.7, WALL_THICKNESS, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallS_B", 3.85, 4.1, 4.7, WALL_THICKNESS, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallE_A", 6.1, -2.475, WALL_THICKNESS, 3.45, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallE_B", 6.1, 2.475, WALL_THICKNESS, 3.45, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallW", -6.1, 0.0, WALL_THICKNESS, 8.4, MATERIAL_WALL_CONTAINER)


## CORRIDOR_N interior x[-1.5, 1.5], z[-7.0, -4.2].
func _build_corridor_n() -> void:
	var space: StaticBody3D = _make_space("CorridorN")
	_add_floor(space, 0.0, -5.6, 3.4, 3.2)
	_add_ceiling(space, 0.0, -5.6, 3.4, 3.2)
	_add_wall(space, "WallW", -1.6, -5.6, WALL_THICKNESS, 3.2, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallE", 1.6, -5.6, WALL_THICKNESS, 3.2, MATERIAL_WALL_CONTAINER)


## COCKPIT interior x[-4, 4], z[-13.0, -7.2]. South wall split around the corridor doorway.
func _build_cockpit() -> void:
	var space: StaticBody3D = _make_space("Cockpit")
	_add_floor(space, 0.0, -10.1, 8.4, 6.2)
	_add_ceiling(space, 0.0, -10.1, 8.4, 6.2)
	_add_wall(space, "WallN", 0.0, -13.1, 8.4, WALL_THICKNESS, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallE", 4.1, -10.1, WALL_THICKNESS, 6.2, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallW", -4.1, -10.1, WALL_THICKNESS, 6.2, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallS_A", -2.85, -7.1, 2.7, WALL_THICKNESS, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallS_B", 2.85, -7.1, 2.7, WALL_THICKNESS, MATERIAL_WALL_PAINTED)


## CORRIDOR_S interior x[-1.5, 1.5], z[4.2, 7.0].
func _build_corridor_s() -> void:
	var space: StaticBody3D = _make_space("CorridorS")
	_add_floor(space, 0.0, 5.6, 3.4, 3.2)
	_add_ceiling(space, 0.0, 5.6, 3.4, 3.2)
	_add_wall(space, "WallW", -1.6, 5.6, WALL_THICKNESS, 3.2, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallE", 1.6, 5.6, WALL_THICKNESS, 3.2, MATERIAL_WALL_CONTAINER)


## ENGINE_BAY interior x[-4, 4], z[7.2, 15.0]. North wall split around the corridor doorway.
func _build_engine_bay() -> void:
	var space: StaticBody3D = _make_space("EngineBay")
	_add_floor(space, 0.0, 11.1, 8.4, 8.2)
	_add_ceiling(space, 0.0, 11.1, 8.4, 8.2)
	_add_wall(space, "WallS", 0.0, 15.1, 8.4, WALL_THICKNESS, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallE", 4.1, 11.1, WALL_THICKNESS, 8.2, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallW", -4.1, 11.1, WALL_THICKNESS, 8.2, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallN_A", -2.85, 7.1, 2.7, WALL_THICKNESS, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallN_B", 2.85, 7.1, 2.7, WALL_THICKNESS, MATERIAL_WALL_CONTAINER)


## CORRIDOR_E interior x[6.2, 7.0], z[-0.75, 0.75]. East/west ends are the habitat/closet walls.
func _build_corridor_e() -> void:
	var space: StaticBody3D = _make_space("CorridorE")
	_add_floor(space, 6.5, 0.0, 1.0, 1.9)
	_add_ceiling(space, 6.5, 0.0, 1.0, 1.9)
	_add_wall(space, "WallN", 6.5, 0.85, 1.0, WALL_THICKNESS, MATERIAL_WALL_CONTAINER)
	_add_wall(space, "WallS", 6.5, -0.85, 1.0, WALL_THICKNESS, MATERIAL_WALL_CONTAINER)


## WATER_CLOSET interior x[7.2, 11.0], z[-1.5, 1.5]. West wall split around the corridor doorway.
func _build_water_closet() -> void:
	var space: StaticBody3D = _make_space("WaterCloset")
	_add_floor(space, 9.1, 0.0, 4.2, 3.4)
	_add_ceiling(space, 9.1, 0.0, 4.2, 3.4)
	_add_wall(space, "WallN", 9.1, 1.6, 4.2, WALL_THICKNESS, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallS", 9.1, -1.6, 4.2, WALL_THICKNESS, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallE", 11.1, 0.0, WALL_THICKNESS, 3.4, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallW_A", 7.1, -1.225, WALL_THICKNESS, 0.95, MATERIAL_WALL_PAINTED)
	_add_wall(space, "WallW_B", 7.1, 1.225, WALL_THICKNESS, 0.95, MATERIAL_WALL_PAINTED)


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
