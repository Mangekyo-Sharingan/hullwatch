## M4 layout regression: the generated ship geometry exists and every doorway is ray-passable.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"
const XENON_MATERIAL_PATH: String = "res://src/data/materials/mat_xenon_metal.tres"
const RAY_Y: float = 1.2

const EXPECTED_SPACES: Array[StringName] = [
	&"Cockpit",
	&"Corridor",
	&"Quarters",
	&"LifeSupport",
	&"Galley",
	&"WaterCloset",
	&"Storage",
	&"Airlock",
	&"EngineBay",
]

const ROOM_CENTERS: Dictionary = {
	&"Cockpit": Vector3(0.0, RAY_Y, -16.5),
	&"Corridor": Vector3(0.0, RAY_Y, -6.3),
	&"Quarters": Vector3(-3.15, RAY_Y, -10.4),
	&"LifeSupport": Vector3(-2.65, RAY_Y, -6.3),
	&"Galley": Vector3(2.9, RAY_Y, -5.8),
	&"WaterCloset": Vector3(2.2, RAY_Y, -1.9),
	&"Storage": Vector3(-2.75, RAY_Y, -1.2),
	&"Airlock": Vector3(-5.8, RAY_Y, -1.2),
	&"EngineBay": Vector3(0.0, RAY_Y, 4.7),
}

## One ray per doorway, aimed through the opening: from a point on the room side of the
## gap (0.8 m inside, at the doorway's lateral centre) to the corridor centerline. Room
## centers clip chamfered corners on diagonal doorways, so the origin is doorway-local.
const DOORWAYS: Array = [
	[Vector3(0.0, RAY_Y, -15.2), Vector3(0.0, RAY_Y, -13.5), "Cockpit"],
	[Vector3(-1.7, RAY_Y, -10.0), Vector3(0.0, RAY_Y, -10.0), "Quarters"],
	[Vector3(-1.7, RAY_Y, -6.0), Vector3(0.0, RAY_Y, -6.0), "LifeSupport"],
	[Vector3(1.7, RAY_Y, -5.6), Vector3(0.0, RAY_Y, -5.6), "Galley"],
	[Vector3(1.7, RAY_Y, -1.6), Vector3(0.0, RAY_Y, -1.6), "WaterCloset"],
	[Vector3(-1.7, RAY_Y, -1.2), Vector3(0.0, RAY_Y, -1.2), "Storage"],
	[Vector3(-3.7, RAY_Y, -1.0), Vector3(-6.3, RAY_Y, -1.0), "Airlock"],
	[Vector3(-5.6, RAY_Y, -1.2), Vector3(-7.3, RAY_Y, -1.2), "Airlock outer"],
	[Vector3(0.0, RAY_Y, 2.4), Vector3(0.0, RAY_Y, 1.0), "EngineBay"],
]

const CHAMFER_ROOMS: Array[StringName] = [
	&"Cockpit",
	&"Quarters",
	&"LifeSupport",
	&"Galley",
	&"WaterCloset",
	&"Storage",
	&"Airlock",
	&"EngineBay",
]

const SOLID_CONTROLS: Array = [
	[Vector3(0.0, RAY_Y, -12.0), Vector3(-1.4, RAY_Y, -12.0), "corridor west wall beside quarters"],
	[Vector3(0.0, RAY_Y, -7.5), Vector3(1.4, RAY_Y, -7.5), "corridor east wall beside galley"],
	[Vector3(-3.15, RAY_Y, -10.4), Vector3(-6.2, RAY_Y, -10.4), "quarters west wall"],
	[Vector3(-2.65, RAY_Y, -6.3), Vector3(-5.0, RAY_Y, -6.3), "life support west wall"],
	[Vector3(2.9, RAY_Y, -5.8), Vector3(5.6, RAY_Y, -5.8), "galley east wall"],
	[Vector3(2.2, RAY_Y, -1.9), Vector3(4.0, RAY_Y, -1.9), "water closet east wall"],
	[Vector3(-2.75, RAY_Y, -2.6), Vector3(-5.3, RAY_Y, -2.6), "storage west wall beside the airlock gap"],
	[Vector3(-6.2, RAY_Y, -1.8), Vector3(-7.4, RAY_Y, -1.8), "airlock west wall beside the outer gap"],
	[Vector3(0.0, RAY_Y, -16.5), Vector3(0.0, RAY_Y, -19.5), "cockpit north wall"],
	[Vector3(0.0, RAY_Y, 4.7), Vector3(0.0, RAY_Y, 8.5), "engine bay south wall"],
]

var _failures: int = 0
var _geometry: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if _find_root_child(&"EventBus") == null:
		var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)

	var packed: PackedScene = load(GEOMETRY_PATH) as PackedScene
	_check(packed != null, "ship geometry scene loads")
	if packed == null:
		_finish()
		return
	_geometry = packed.instantiate() as Node3D
	_check(_geometry != null, "ship geometry instantiates as Node3D")
	if _geometry == null:
		_finish()
		return
	root.add_child(_geometry)
	await physics_frame
	await physics_frame

	_test_spaces_exist()
	_test_floors_have_collision()
	_test_doorways_passable()
	_test_solid_walls_block()
	_test_corridor_is_narrow()
	_test_chamfered_corners()
	_test_faceted_corridor()
	_test_xenon_structural_material()

	_geometry.free()
	_finish()


func _test_spaces_exist() -> void:
	for space_name: StringName in EXPECTED_SPACES:
		var space: Node = _geometry.get_node_or_null(NodePath(String(space_name)))
		_check(space != null, "space exists: %s" % space_name)


func _test_floors_have_collision() -> void:
	for space_name: StringName in EXPECTED_SPACES:
		var space: Node = _geometry.get_node_or_null(NodePath(String(space_name)))
		if space == null:
			continue
		var floor_shape: CollisionShape3D = _find_floor_shape(space)
		_check(floor_shape != null and floor_shape.shape != null, "space has floor collision: %s" % space_name)


func _test_doorways_passable() -> void:
	for doorway: Array in DOORWAYS:
		var from: Vector3 = doorway[0]
		var to: Vector3 = doorway[1]
		var label: String = doorway[2]
		_check(not _ray_hits(from, to), "doorway %s -> corridor is free of geometry" % label)


func _test_solid_walls_block() -> void:
	for control: Array in SOLID_CONTROLS:
		var from: Vector3 = control[0]
		var to: Vector3 = control[1]
		var label: String = control[2]
		_check(_ray_hits(from, to), "control: ray into %s hits" % label)


func _test_corridor_is_narrow() -> void:
	_check(not _ray_hits(Vector3(-0.64, RAY_Y, -5.0), Vector3(0.64, RAY_Y, -5.0)), "corridor spine is clear across x[-0.64, 0.64] at y=1.2 (canted walls: true clear width ~1.32 m)")
	_check(_ray_hits(Vector3(-1.0, RAY_Y, -5.0), Vector3(1.0, RAY_Y, -5.0)), "corridor spine is blocked across x[-1.0, 1.0] (clear width <= 1.5 m)")


func _test_chamfered_corners() -> void:
	for room_id: StringName in CHAMFER_ROOMS:
		var room: Node = _geometry.get_node_or_null(NodePath(String(room_id)))
		if room == null:
			_check(false, "chamfer room exists: %s" % room_id)
			continue
		_check(_count_mesh_parts(room, "Chamfer") >= 4, "%s has four chamfer corner panels" % room_id)


func _test_faceted_corridor() -> void:
	var corridor: Node = _geometry.get_node_or_null(NodePath("Corridor"))
	if corridor == null:
		_check(false, "chamfer corridor exists")
		return
	_check(_count_mesh_parts(corridor, "Cant") >= 1, "corridor has canted wall panels")
	_check(_count_mesh_parts(corridor, "Header") >= 1, "corridor has upper header walls")


func _test_xenon_structural_material() -> void:
	var sample: MeshInstance3D = _geometry.get_node_or_null(NodePath("Cockpit/WallNMesh")) as MeshInstance3D
	_check(sample != null, "sampled structural wall mesh exists")
	if sample == null:
		return
	var material: Material = sample.material_override
	_check(material != null and material.resource_path == XENON_MATERIAL_PATH, "sampled structural wall uses the xenon-metal material")


func _ray_hits(from: Vector3, to: Vector3) -> bool:
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var space_state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	return not space_state.intersect_ray(params).is_empty()


func _find_floor_shape(node: Node) -> CollisionShape3D:
	for child: Node in node.get_children():
		if child is CollisionShape3D and child.name.begins_with("Floor"):
			return child as CollisionShape3D
		var nested: CollisionShape3D = _find_floor_shape(child)
		if nested != null:
			return nested
	return null


func _count_mesh_parts(node: Node, prefix: String) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.name.begins_with(prefix):
			count += 1
		count += _count_mesh_parts(child, prefix)
	return count


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_ship_layout")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
