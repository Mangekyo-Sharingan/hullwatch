## Field streamer tests: scene nodes mirror the active sector objects, positions are ship
## relative, kinds carry the right geometry/collision, and dropped objects are freed.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await _test_streaming()
	await _test_despawn()
	_finish()


func _test_streaming() -> void:
	var sector: SectorSystem = SectorSystem.new()
	sector.field_seed = 20260918
	sector.drift_axis = Vector3.FORWARD
	sector.drift_speed_m_per_hour = 1500.0
	root.add_child(sector)
	var streamer: FieldStreamer = FieldStreamer.new()
	root.add_child(streamer)
	await process_frame
	for i: int in 24:
		sector.sim_tick(1.0)
	streamer.sync_now()
	var active: Array[Dictionary] = sector.get_active_objects()
	_check(active.size() > 0, "the field has active objects to stream (%d)" % active.size())
	_check(streamer.get_node_count() == active.size(), "streamed node count matches the sim")
	var positions_match: bool = true
	var kinds_ok: bool = true
	var ship: Vector3 = sector.get_ship_position()
	for entry: Dictionary in active:
		var node: Node3D = streamer.get_object_node(String(entry["id"]))
		if node == null:
			kinds_ok = false
			continue
		if node.position.distance_to((entry["position"] as Vector3) - ship) > 0.001:
			positions_match = false
		var mesh_instance: MeshInstance3D = node.get_node_or_null(^"Mesh") as MeshInstance3D
		var shape: CollisionShape3D = node.get_node_or_null(^"Shape") as CollisionShape3D
		if mesh_instance == null or mesh_instance.mesh == null or shape == null or shape.shape == null:
			kinds_ok = false
	_check(positions_match, "streamed nodes sit at ship-relative object positions")
	_check(kinds_ok, "every streamed node has geometry and collision")
	var kinds_seen: Dictionary = {}
	for entry: Dictionary in active:
		kinds_seen[String(entry["kind"])] = true
	var shape_types_ok: bool = true
	for entry: Dictionary in active:
		var node: Node3D = streamer.get_object_node(String(entry["id"]))
		if node == null:
			continue
		var shape: CollisionShape3D = node.get_node_or_null(^"Shape") as CollisionShape3D
		match String(entry["kind"]):
			"asteroid":
				if not (shape.shape is ConvexPolygonShape3D):
					shape_types_ok = false
			"anomaly", "debris":
				if not (shape.shape is SphereShape3D):
					shape_types_ok = false
	_check(shape_types_ok, "asteroids are convex, anomalies and debris are spheres (%s)" % ", ".join(kinds_seen.keys()))
	sector.free()
	streamer.free()


func _test_despawn() -> void:
	var sector: SectorSystem = SectorSystem.new()
	sector.field_seed = 777
	sector.drift_axis = Vector3.FORWARD
	sector.drift_speed_m_per_hour = 1500.0
	root.add_child(sector)
	var streamer: FieldStreamer = FieldStreamer.new()
	root.add_child(streamer)
	await process_frame
	var stale_node: Node3D = null
	var stale_id: String = ""
	var removed: bool = false
	for i: int in 120:
		sector.sim_tick(1.0)
		streamer.sync_now()
		for entry: Dictionary in sector.get_active_objects():
			var id: String = String(entry["id"])
			if streamer.get_object_node(id) != null:
				stale_id = id
				stale_node = streamer.get_object_node(id)
				break
		if stale_node == null:
			continue
		var still_active: bool = false
		for entry: Dictionary in sector.get_active_objects():
			if String(entry["id"]) == stale_id:
				still_active = true
		if not still_active:
			removed = true
			break
		streamer.sync_now()
		if streamer.get_object_node(stale_id) == null:
			removed = true
			break
	_check(stale_node != null, "a streamed object was tracked for despawn")
	if stale_node != null:
		if not removed:
			sector.sim_tick(24.0)
			streamer.sync_now()
		_check(not is_instance_valid(stale_node), "objects that leave the stream are freed")
	_check(streamer.get_node_count() == sector.get_active_objects().size(), "node count stays in step with the sim")
	sector.free()
	streamer.free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_field_streamer")
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
