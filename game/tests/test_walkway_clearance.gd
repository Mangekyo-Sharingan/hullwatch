extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var geometry: Node3D = load("res://scenes/ship_geometry.tscn").instantiate() as Node3D
	var layout: Node3D = load("res://scenes/world_layout.tscn").instantiate() as Node3D
	var player: CharacterBody3D = load("res://scenes/player.tscn").instantiate() as CharacterBody3D
	root.add_child(geometry)
	root.add_child(layout)
	root.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		var z0: float = TubeLayout.span(index).y
		var z1: float = TubeLayout.span(index + 1).x
		var joint: StaticBody3D = geometry.get_node("Joint_%s_%s" % [TubeLayout.sections()[index]["name"], TubeLayout.sections()[index + 1]["name"]]) as StaticBody3D
		var faces: PackedVector3Array = (joint.get_node("ShellShape").shape as ConcavePolygonShape3D).get_faces()
		var jamb_count: int = 0
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i + 1]
			var c: Vector3 = faces[i + 2]
			if is_equal_approx(absf(a.x), TubeLayout.HATCH_HALF_WIDTH) and is_equal_approx(a.x, b.x) and is_equal_approx(a.x, c.x):
				jamb_count += 1
				for point: Vector3 in [a, b, c]:
					_check(point.z >= z0 - 0.001 and point.z <= z1 + 0.001, "%s jamb stays inside its neck" % joint.name)
		_check(jamb_count > 0, "%s retains real jamb collision" % joint.name)
		var middle: float = (z0 + z1) * 0.5
		for side: float in [-1.0, 1.0]:
			for direction: float in [-1.0, 1.0]:
				var start: Vector3 = Vector3(side * 0.65, 1.3, middle + direction * 0.25)
				var end: Vector3 = Vector3(start.x, start.y, middle - direction * 0.25)
				var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, 1)
				query.exclude = [player.get_rid()]
				var hit: Dictionary = root.world_3d.direct_space_state.intersect_ray(query)
				_check(not hit.is_empty(), "%s has a solid bulkhead face on both sides" % joint.name)
				if not hit.is_empty():
					var hit_position: Vector3 = hit["position"]
					_check(is_equal_approx(hit_position.z, middle + direction * TubeLayout.WALL * 0.5), "%s bulkhead has wall thickness instead of a center plane" % joint.name)
		if index in [0, 1]:
			for room_z: float in [z0 - 0.1, z1 + 0.1]:
				for side: float in [-1.0, 1.0]:
					player.position = Vector3(side * 0.75, 0.02, room_z)
					var contact: KinematicCollision3D = player.move_and_collide(Vector3(-side * 0.5, 0.0, 0.0), true)
					_check(contact == null, "cockpit lateral recovery clears %s at z %.3f side %.0f" % [joint.name, room_z, side])
	for bay: Dictionary in TubeLayout.service_bays():
		var bay_body: StaticBody3D = geometry.get_node("ServiceBay_" + String(bay["name"])) as StaticBody3D
		var bay_faces: PackedVector3Array = (bay_body.get_node("ShellShape").shape as ConcavePolygonShape3D).get_faces()
		var back_face_count: int = 0
		var bore_depth: float = 0.0
		for i: int in range(0, bay_faces.size(), 3):
			var a: Vector3 = bay_faces[i]
			var b: Vector3 = bay_faces[i + 1]
			var c: Vector3 = bay_faces[i + 2]
			if is_equal_approx(a.z, TubeLayout.WALL) and is_equal_approx(b.z, a.z) and is_equal_approx(c.z, a.z):
				back_face_count += 1
			if is_equal_approx(absf(a.x), 0.6) and is_equal_approx(b.x, a.x) and is_equal_approx(c.x, a.x):
				bore_depth = maxf(bore_depth, maxf(a.z, maxf(b.z, c.z)) - minf(a.z, minf(b.z, c.z)))
		_check(back_face_count > 0 and is_equal_approx(bore_depth, TubeLayout.WALL), "%s entrance has separate faces and full-depth jambs" % bay["name"])
		var center_x: float = float(bay["inner_x"]) + float(bay["side"]) * 0.55
		var center_z: float = float(bay["center_z"])
		for edge: float in [-1.0, 1.0]:
			var wall_x: float = float(bay["inner_x"]) - float(bay["side"]) * 0.15
			var from: Vector3 = Vector3(wall_x, 1.55, center_z + edge * 0.6 - 0.2)
			var to: Vector3 = Vector3(wall_x, 1.55, from.z + 0.4)
			var profile_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
			profile_query.exclude = [player.get_rid()]
			profile_query.hit_back_faces = true
			_check(root.world_3d.direct_space_state.intersect_ray(profile_query).is_empty(), "%s entrance jamb follows the cabin profile at shoulder height" % bay["name"])
		for offset: float in [-0.75, 0.75]:
			var start: Vector3 = Vector3(float(bay["inner_x"]) + float(bay["side"]) * 0.05, 1.4, center_z + offset)
			var end: Vector3 = Vector3(center_x, 1.4, center_z + offset)
			var seam_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, 1)
			seam_query.exclude = [player.get_rid()]
			seam_query.hit_back_faces = true
			_check(root.world_3d.direct_space_state.intersect_ray(seam_query).is_empty(), "%s contains no buried exterior sheet at %.2f" % [bay["name"], offset])
		player.position = Vector3(float(bay["side"]) * 0.6, 0.02, center_z)
		var travel: Vector3 = Vector3(center_x - player.position.x, 0.0, 0.0)
		_check(player.move_and_collide(travel, true) == null, "%s has a capsule-clear entrance" % bay["name"])
		player.position = Vector3(center_x, 0.02, center_z)
		_check(player.move_and_collide(-travel, true) == null, "%s has a capsule-clear return" % bay["name"])
		for i: int in 64:
			var y: float = 1.0 - 2.0 * (float(i) + 0.5) / 64.0
			var radial: float = sqrt(1.0 - y * y)
			var direction: Vector3 = Vector3(cos(float(i) * 2.399963) * radial, y, sin(float(i) * 2.399963) * radial)
			var from: Vector3 = Vector3(center_x, 1.4, center_z)
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + direction * 40.0, 1)
			query.exclude = [player.get_rid()]
			query.hit_back_faces = true
			_check(not root.world_3d.direct_space_state.intersect_ray(query).is_empty(), "%s pressure enclosure ray %d" % [bay["name"], i])
		var compartment: StringName = TubeLayout.ROOM_COMPARTMENTS[StringName(bay["room"])]
		var matching_zones: int = 0
		for zone: Node in layout.get_node("Zones").get_children():
			if zone.get("compartment_id") == compartment:
				matching_zones += 1
				_check(zone.get_node_or_null("ShapeServiceBay") != null, "%s uses one occupancy owner for room and bay" % bay["name"])
		_check(matching_zones == 1, "%s does not duplicate occupancy writers" % bay["name"])
	player.free()
	layout.free()
	geometry.free()
	await process_frame
	if _failures == 0:
		print("PASS: test_walkway_clearance")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("FAIL: " + message)
		_failures += 1
