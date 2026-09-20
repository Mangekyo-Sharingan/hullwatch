## M7.4 exterior regression: the hull shell, catwalk, ramp and hardpoints exist and are
## walkable, the airlock opens onto the platform, and nothing intrudes into the rooms.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"

const ROOM_CENTERS: Array[Vector3] = [
	Vector3(0.0, 1.2, -16.5),
	Vector3(0.0, 1.2, -6.3),
	Vector3(-3.15, 1.2, -10.4),
	Vector3(-2.65, 1.2, -6.3),
	Vector3(2.9, 1.2, -5.8),
	Vector3(2.2, 1.2, -1.9),
	Vector3(-2.75, 1.2, -1.2),
	Vector3(0.0, 1.2, 4.7),
	Vector3(-5.8, 1.2, -1.2),
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

	_test_hull_node()
	_test_airlock_opens_onto_the_platform()
	_test_catwalk_ring()
	_test_raft_and_ramp()
	_test_ramp_is_walkable()
	_test_hull_stays_out_of_rooms()
	_test_hardpoints()

	_geometry.free()
	_finish()


func _test_hull_node() -> void:
	var hull: Node = _geometry.get_node_or_null(^"HullExterior")
	_check(hull != null and hull is StaticBody3D, "HullExterior exists as a StaticBody3D")
	if hull == null:
		return
	var shape_node: CollisionShape3D = hull.get_node_or_null(^"ShellShape") as CollisionShape3D
	_check(shape_node != null and shape_node.shape is ConcavePolygonShape3D, "hull shell has trimesh collision")
	var hull_mesh: MeshInstance3D = hull.get_node_or_null(^"HullMesh") as MeshInstance3D
	_check(hull_mesh != null and hull_mesh.mesh != null, "hull shell mesh exists")


func _test_airlock_opens_onto_the_platform() -> void:
	_check(not _ray_hits(Vector3(-5.6, 1.2, -1.2), Vector3(-8.6, 1.2, -1.2)), "outer doorway is free through the hull band")
	_check(_ray_hits(Vector3(-9.0, 1.0, -1.2), Vector3(-9.0, -1.0, -1.2)), "platform floor is solid outside the door")
	_check(not _ray_hits(Vector3(-9.0, 0.5, -1.2), Vector3(-9.0, 2.5, -1.2)), "platform headroom is clear")


func _test_catwalk_ring() -> void:
	var samples: Array[Vector3] = [
		Vector3(-9.0, 1.0, -10.0),
		Vector3(7.1, 1.0, -10.0),
		Vector3(-0.5, 1.0, -20.2),
		Vector3(-0.5, 1.0, 9.2),
	]
	for sample: Vector3 in samples:
		_check(_ray_hits(sample, Vector3(sample.x, -1.0, sample.z)), "catwalk deck is solid at %s" % str(sample))


func _test_raft_and_ramp() -> void:
	_check(_ray_hits(Vector3(1.8, 2.5, 12.0), Vector3(1.8, -1.0, 12.0)), "ramp crosses z=12 above the aft deck")
	_check(_ray_hits(Vector3(-2.0, 1.0, 12.0), Vector3(-2.0, -1.0, 12.0)), "aft deck is solid beside the ramp")


func _test_ramp_is_walkable() -> void:
	var low: Dictionary = _ray_result(Vector3(1.8, 3.0, 13.5), Vector3(1.8, -0.5, 13.5))
	_check(not low.is_empty(), "ramp surface exists at the lower end")
	if not low.is_empty():
		var normal: Vector3 = low["normal"]
		_check(normal.dot(Vector3.UP) > 0.75, "ramp slope is within the walkable limit")
		_check(float((low["position"] as Vector3).y) > 0.2 and float((low["position"] as Vector3).y) < 1.0, "ramp starts low above the aft deck")
	var high: Dictionary = _ray_result(Vector3(1.8, 5.0, 8.6), Vector3(1.8, 1.0, 8.6))
	_check(not high.is_empty(), "ramp surface exists at the deck edge")
	if not high.is_empty():
		_check(absf(float((high["position"] as Vector3).y) - 3.4) < 0.4, "ramp lands at deck height")


func _test_hull_stays_out_of_rooms() -> void:
	for center: Vector3 in ROOM_CENTERS:
		var result: Dictionary = _ray_result(center, center + Vector3(0.45, 0.0, 0.0))
		var blocked_by_hull: bool = false
		if not result.is_empty():
			var collider: Node = result["collider"] as Node
			if collider != null and String(collider.name) == "HullExterior":
				blocked_by_hull = true
		_check(not blocked_by_hull, "no hull shell inside the room at %s" % str(center))


func _test_hardpoints() -> void:
	var hull: Node = _geometry.get_node_or_null(^"HullExterior")
	if hull == null:
		_check(false, "hull exists for hardpoint check")
		return
	var count: int = 0
	for child: Node in hull.get_children():
		if String(child.name).begins_with("Hardpoint"):
			count += 1
			var marker: Node3D = child as Node3D
			if marker != null:
				_check(is_equal_approx(marker.position.y, 3.6), "hardpoint sits on the deck: %s" % child.name)
	_check(count == 4, "four hardpoint markers exist")


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
		print("PASS: test_hull_exterior")
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
