## M4 layout regression: the generated ship geometry exists and every doorway is ray-passable.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"
const RAY_Y: float = 1.2

const EXPECTED_SPACES: Array[StringName] = [
	&"Cockpit",
	&"Corridor",
	&"Quarters",
	&"LifeSupport",
	&"Galley",
	&"WaterCloset",
	&"Storage",
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
	&"EngineBay": Vector3(0.0, RAY_Y, 4.7),
}

## One ray per doorway: room center -> a point on the corridor centerline (x = 0)
## at the doorway. The side rooms are offset along the spine, so a ray to the
## spine's geometric center would clip a corridor wall instead of the opening.
const DOORWAYS: Array = [
	[&"Cockpit", Vector3(0.0, RAY_Y, -13.5)],
	[&"Quarters", Vector3(0.0, RAY_Y, -10.0)],
	[&"LifeSupport", Vector3(0.0, RAY_Y, -6.0)],
	[&"Galley", Vector3(0.0, RAY_Y, -5.6)],
	[&"WaterCloset", Vector3(0.0, RAY_Y, -1.6)],
	[&"Storage", Vector3(0.0, RAY_Y, -1.2)],
	[&"EngineBay", Vector3(0.0, RAY_Y, 1.0)],
]

const SOLID_CONTROLS: Array = [
	[Vector3(0.0, RAY_Y, -12.0), Vector3(-1.4, RAY_Y, -12.0), "corridor west wall beside quarters"],
	[Vector3(0.0, RAY_Y, -7.5), Vector3(1.4, RAY_Y, -7.5), "corridor east wall beside galley"],
	[Vector3(-3.15, RAY_Y, -10.4), Vector3(-6.2, RAY_Y, -10.4), "quarters west wall"],
	[Vector3(-2.65, RAY_Y, -6.3), Vector3(-5.0, RAY_Y, -6.3), "life support west wall"],
	[Vector3(2.9, RAY_Y, -5.8), Vector3(5.6, RAY_Y, -5.8), "galley east wall"],
	[Vector3(2.2, RAY_Y, -1.9), Vector3(4.0, RAY_Y, -1.9), "water closet east wall"],
	[Vector3(-2.75, RAY_Y, -1.2), Vector3(-5.3, RAY_Y, -1.2), "storage west wall"],
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
		var room_id: StringName = doorway[0]
		var corridor_point: Vector3 = doorway[1]
		var from: Vector3 = ROOM_CENTERS[room_id]
		_check(not _ray_hits(from, corridor_point), "doorway %s -> corridor is free of geometry" % room_id)


func _test_solid_walls_block() -> void:
	for control: Array in SOLID_CONTROLS:
		var from: Vector3 = control[0]
		var to: Vector3 = control[1]
		var label: String = control[2]
		_check(_ray_hits(from, to), "control: ray into %s hits" % label)


func _test_corridor_is_narrow() -> void:
	_check(not _ray_hits(Vector3(-0.7, RAY_Y, -5.0), Vector3(0.7, RAY_Y, -5.0)), "corridor spine is clear across x[-0.7, 0.7]")
	_check(_ray_hits(Vector3(-1.0, RAY_Y, -5.0), Vector3(1.0, RAY_Y, -5.0)), "corridor spine is blocked across x[-1.0, 1.0] (clear width <= 1.5 m)")


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
