## M4 layout regression: the generated ship geometry exists and every doorway is ray-passable.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"
const RAY_Y: float = 1.2

const EXPECTED_SPACES: Array[StringName] = [
	&"Habitat",
	&"CorridorN",
	&"Cockpit",
	&"CorridorS",
	&"EngineBay",
	&"CorridorE",
	&"WaterCloset",
]

const ROOM_CENTERS: Dictionary = {
	&"Habitat": Vector3(0.0, RAY_Y, 0.0),
	&"CorridorN": Vector3(0.0, RAY_Y, -5.6),
	&"Cockpit": Vector3(0.0, RAY_Y, -10.1),
	&"CorridorS": Vector3(0.0, RAY_Y, 5.6),
	&"EngineBay": Vector3(0.0, RAY_Y, 11.1),
	&"CorridorE": Vector3(6.5, RAY_Y, 0.0),
	&"WaterCloset": Vector3(9.1, RAY_Y, 0.0),
}

const DOORWAYS: Array = [
	[&"Habitat", &"CorridorN"],
	[&"Habitat", &"CorridorS"],
	[&"Habitat", &"CorridorE"],
	[&"CorridorN", &"Cockpit"],
	[&"CorridorS", &"EngineBay"],
	[&"CorridorE", &"WaterCloset"],
]

const SOLID_CONTROLS: Array = [
	[Vector3(0.0, RAY_Y, 0.0), Vector3(-6.6, RAY_Y, 0.0), "habitat west wall"],
	[Vector3(-3.0, RAY_Y, 0.0), Vector3(-3.0, RAY_Y, -4.6), "habitat north wall"],
	[Vector3(0.0, RAY_Y, -10.1), Vector3(0.0, RAY_Y, -13.6), "cockpit north wall"],
	[Vector3(0.0, RAY_Y, 11.1), Vector3(0.0, RAY_Y, 15.6), "engine bay south wall"],
	[Vector3(6.5, RAY_Y, 0.0), Vector3(6.5, RAY_Y, 1.3), "corridor east north wall"],
	[Vector3(9.1, RAY_Y, 0.0), Vector3(11.6, RAY_Y, 0.0), "water closet east wall"],
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
	for pair: Array in DOORWAYS:
		var from_id: StringName = pair[0]
		var to_id: StringName = pair[1]
		var from: Vector3 = ROOM_CENTERS[from_id]
		var to: Vector3 = ROOM_CENTERS[to_id]
		_check(not _ray_hits(from, to), "doorway %s -> %s is free of geometry" % [from_id, to_id])


func _test_solid_walls_block() -> void:
	for control: Array in SOLID_CONTROLS:
		var from: Vector3 = control[0]
		var to: Vector3 = control[1]
		var label: String = control[2]
		_check(_ray_hits(from, to), "control: ray into %s hits" % label)


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
