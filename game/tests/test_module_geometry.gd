## M10.2 dock geometry: every pinned hardpoint has a doorway from its parent room and a
## throat that reaches a sealing mount plate, and the generated pod scene mates with it.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"
const POD_PATH: String = "res://scenes/dock_pod.tscn"

## id -> [room entry point, throat floor sample, wall sample beside the doorway, outward]
const DOCKS: Array = [
	["quarters", Vector3(-5.5, 1.2, -10.4), Vector3(-7.35, 1.0, -10.4), -9.75, -1.0],
	["life_support", Vector3(-4.5, 1.2, -6.3), Vector3(-7.0, 1.0, -6.3), -5.7, -1.0],
	["galley", Vector3(4.5, 1.2, -5.8), Vector3(6.35, 1.0, -5.8), -5.25, 1.0],
	["engine_bay", Vector3(2.0, 1.2, 4.7), Vector3(5.0, 1.0, 4.7), 3.6, 1.0],
]

var _failures: int = 0
var _geometry: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load(GEOMETRY_PATH) as PackedScene
	_check(packed != null, "ship geometry scene loads")
	if packed == null:
		_finish()
		return
	_geometry = packed.instantiate() as Node3D
	root.add_child(_geometry)
	await physics_frame
	await physics_frame
	_test_dock_walkways()
	_test_generated_files()
	_geometry.free()
	_geometry = null
	await physics_frame
	await physics_frame
	_test_pod_scene()
	_finish()


func _test_dock_walkways() -> void:
	var hull: Node = _geometry.get_node_or_null(^"HullExterior")
	_check(hull != null, "hull shell exists")
	if hull == null:
		return
	for dock: Array in DOCKS:
		var id: String = dock[0]
		var start: Vector3 = dock[1]
		var floor_sample: Vector3 = dock[2]
		var beside_z: float = dock[3]
		var outward: float = dock[4]
		var plate: Node = hull.get_node_or_null(NodePath("DockPlate_" + id))
		var marker: Node = hull.get_node_or_null(NodePath("Hardpoint_" + id))
		_check(plate != null and plate.is_in_group(&"dock_plate"), "mount plate exists: " + id)
		_check(marker != null and marker.is_in_group(&"hardpoint"), "hardpoint marker exists: " + id)
		var plate_face: float = -8.35 if outward < 0.0 else 6.45
		var target: Vector3 = Vector3(plate_face + outward * 0.1, 1.2, start.z)
		var walk: Dictionary = _ray_result(start, target)
		var walk_x: float = float((walk["position"] as Vector3).x) if not walk.is_empty() else 0.0
		_check(
			not walk.is_empty() and absf(walk_x - plate_face) < 0.05,
			"doorway walks from the room to the mount plate: %s (x=%.3f)" % [id, walk_x]
		)
		var floor_hit: Dictionary = _ray_result(floor_sample, floor_sample - Vector3(0.0, 1.5, 0.0))
		_check(
			not floor_hit.is_empty() and absf(float((floor_hit["position"] as Vector3).y)) < 0.05,
			"throat floor is solid: " + id
		)
		var beside: Vector3 = Vector3(start.x, 1.2, beside_z)
		var beside_hit: Dictionary = _ray_result(beside, Vector3(beside.x + outward * 4.0, beside.y, beside.z))
		_check(not beside_hit.is_empty(), "wall beside the doorway is solid: " + id)


func _test_generated_files() -> void:
	var ship_text: String = _read_text(GEOMETRY_PATH)
	var pod_text: String = _read_text(POD_PATH)
	_check(not ship_text.contains("unique_id"), "ship geometry keeps no volatile node ids")
	_check(not pod_text.contains("unique_id"), "pod scene keeps no volatile node ids")
	_check(ship_text.contains("DockPlate_quarters") and ship_text.contains("Hardpoint_engine_bay"), "ship geometry carries the pinned dock nodes")
	_check(pod_text.contains("PodRoom") and pod_text.contains("compartment_id = &\"module\""), "pod scene carries its room and compartment")


func _test_pod_scene() -> void:
	var packed: PackedScene = load(POD_PATH) as PackedScene
	_check(packed != null, "pod scene loads")
	if packed == null:
		return
	var pod: Node3D = packed.instantiate() as Node3D
	root.add_child(pod)
	var room: Node = pod.get_node_or_null(^"PodRoom")
	_check(room != null and room is StaticBody3D, "pod room is a StaticBody3D")
	var zone: Node = pod.get_node_or_null(^"Zone")
	_check(zone != null and zone.get(&"compartment_id") == &"module", "pod zone claims the module compartment")
	if zone != null:
		var shape: CollisionShape3D = zone.get_node_or_null(^"Shape") as CollisionShape3D
		_check(shape != null and shape.shape is BoxShape3D, "pod zone has a box shape")
	var link: Node = pod.get_node_or_null(^"Link")
	_check(link != null and link.get(&"compartment_a") == &"module", "pod link is wired to the module compartment")
	var floor_hit: Dictionary = _ray_result(Vector3(2.3, 1.5, 0.0), Vector3(2.3, -0.5, 0.0))
	_check(not floor_hit.is_empty() and absf(float((floor_hit["position"] as Vector3).y)) < 0.05, "pod floor is solid")
	var ceiling_hit: Dictionary = _ray_result(Vector3(2.3, 1.5, 0.0), Vector3(2.3, 3.4, 0.0))
	_check(not ceiling_hit.is_empty() and absf(float((ceiling_hit["position"] as Vector3).y) - 3.0) < 0.05, "pod ceiling sits at head height")
	_check(not _ray_hits(Vector3(3.0, 1.2, 0.0), Vector3(-0.6, 1.2, 0.0)), "pod doorway is open")
	var beside: Dictionary = _ray_result(Vector3(3.0, 1.2, 0.7), Vector3(-0.6, 1.2, 0.7))
	_check(
		not beside.is_empty() and absf(float((beside["position"] as Vector3).x) - 0.4) < 0.05,
		"pod wall beside the doorway is solid"
	)
	pod.free()


func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "cannot read " + path)
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _ray_hits(from: Vector3, to: Vector3) -> bool:
	return not _ray_result(from, to).is_empty()


func _ray_result(from: Vector3, to: Vector3) -> Dictionary:
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var space_state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	return space_state.intersect_ray(params)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_module_geometry")
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
