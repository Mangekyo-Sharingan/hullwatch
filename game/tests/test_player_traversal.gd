## Integration test: verifies that the player can walk through the section chain and reach the
## cockpit from either end without getting blocked by equipment, modules, or doorways.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		print("FAIL: ", message)
		_failures += 1


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_player_traversal")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _run() -> void:
	await process_frame

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_check(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var player: CharacterBody3D = main.get_node_or_null("Player") as CharacterBody3D
	_check(player != null, "player exists in scene")
	if player == null:
		_finish()
		return

	# Make sure the airlock inner door is open for traversal to engine bay if needed
	var airlock_inner: Door = main.get_node_or_null("WorldLayout/Props/DoorAirlockInner") as Door
	if airlock_inner != null:
		airlock_inner.call("_set_open", true)
		var slab_shape: CollisionShape3D = airlock_inner.get_node_or_null(^"SlabShape") as CollisionShape3D
		var open_frames: int = 0
		while slab_shape != null and not slab_shape.disabled and open_frames < 60:
			await physics_frame
			open_frames += 1
		_check(slab_shape != null and slab_shape.disabled, "airlock hatch finishes opening before aisle checks")
	else:
		_check(false, "inner airlock hatch exists")

	# Test 1: A standing lane remains open beside the central pilot chair.
	var space_state: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.24
	shape.height = 1.75

	var shape_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.collision_mask = 1 # world layer
	shape_query.exclude = [player.get_rid()]

	var test_z: float = -20.0
	var z_end: float = 5.5
	var blocked_points: Array[float] = []

	while test_z <= z_end:
		var clear_at_z: bool = false
		for x_offset: float in [0.0, -0.15, 0.15, -0.25, 0.25, -1.05, 1.05]:
			shape_query.transform = Transform3D(Basis(), Vector3(x_offset, 0.875 + 0.05, test_z))
			var hits: Array[Dictionary] = space_state.intersect_shape(shape_query, 1)
			if hits.is_empty():
				clear_at_z = true
				break
		if not clear_at_z:
			blocked_points.append(test_z)
		test_z += 0.25

	_check(blocked_points.is_empty(), "aisle is clear of blocking geometry at all z stations (blocked: %s)" % [str(blocked_points)])

	# Test 2: Dynamic movement from bow to stern using move_and_slide
	# Start on the starboard lane beside the pilot chair.
	player.global_position = Vector3(1.05, 0.05, -20.0)
	player.velocity = Vector3.ZERO
	await process_frame

	var current_z: float = player.global_position.z
	var steps: int = 0
	var max_steps: int = 600 # 600 frames at ~60fps is 10 seconds
	var reached_stern: bool = false

	# Target walk speed: 4.0 m/s
	while steps < max_steps:
		var target_x: float = 1.05 if player.global_position.z < -19.22 else 0.0
		var x_err: float = target_x - player.global_position.x
		var z_speed: float = 0.0 if player.global_position.z >= -19.22 and player.global_position.x > 0.16 else 3.5
		player.velocity = Vector3(clampf(x_err * 3.0, -2.0, 2.0), -9.8, z_speed)
		player.move_and_slide()
		steps += 1
		if player.global_position.z >= 5.0:
			reached_stern = true
			break
		await physics_frame

	_check(reached_stern, "player walked bow-to-stern from z=-20.0 to z=5.0 (reached z=%.2f in %d frames)" % [player.global_position.z, steps])

	# Test 3: Return through the chain to the cockpit; the pilot station occupies the prow end.
	var reached_cockpit: bool = false
	steps = 0
	while steps < max_steps:
		player.velocity = Vector3(0.0, -9.8, -3.5)
		player.move_and_slide()
		steps += 1
		if player.global_position.z <= TubeLayout.span(TubeLayout.index_of("cupola")).y:
			reached_cockpit = true
			break
		await physics_frame

	_check(reached_cockpit, "player walked stern-to-cockpit from z=5.0 to the pilot station (reached z=%.2f in %d frames)" % [player.global_position.z, steps])
	await _test_ring_decks(player, main)

	main.queue_free()
	await process_frame
	_finish()


func _test_ring_decks(player: CharacterBody3D, main: Node) -> void:
	for room: String in ["Quarters", "Storage", "EngineBayA", "EngineBayB"]:
		var ladder: ShipLadder = main.get_node_or_null("ShipGeometry/ShipLadder_" + room) as ShipLadder
		_check(ladder != null, "ring-deck ladder exists: " + room)
		if ladder == null:
			continue
		var ray: RayCast3D = player.get_node(^"Head/Camera3D/InteractRay") as RayCast3D
		_set_ladder_approach(player, ladder, false, room == "EngineBayB")
		await physics_frame
		ray.force_raycast_update()
		_check(ray.get_collider() == ladder, "standing interact ray targets ladder: " + room)
		player.call(&"_try_interact")
		_check(bool(player.call(&"is_climbing_ladder")), "interacting through the standing ray starts the climb: " + room)
		Input.action_press(&"move_forward")
		var frames: int = 0
		while bool(player.call(&"is_climbing_ladder")) and frames < 180:
			await physics_frame
			frames += 1
		Input.action_release(&"move_forward")
		_check(not bool(player.call(&"is_climbing_ladder")), "operator climbs to the upper deck: " + room)
		_check(absf(player.global_position.y - 2.2) < 0.03, "upper landing is at standing height: " + room)
		var upper_x: float = player.global_position.x
		player.rotation.y = 0.0
		Input.action_press(&"move_right")
		for frame: int in 20:
			await physics_frame
		Input.action_release(&"move_right")
		_check(player.global_position.x > upper_x + 0.3 and absf(player.global_position.y - 2.2) < 0.05, "operator walks across the upper deck: %s (x=%.2f from %.2f)" % [room, player.global_position.x, upper_x])
		_set_ladder_approach(player, ladder, true)
		await physics_frame
		ray.force_raycast_update()
		_check(ray.get_collider() == ladder, "upper interact ray targets ladder: " + room)
		player.call(&"_try_interact")
		_check(bool(player.call(&"is_climbing_ladder")), "upper interact ray re-enters the ladder: " + room)
		Input.action_press(&"move_back")
		frames = 0
		while bool(player.call(&"is_climbing_ladder")) and frames < 180:
			await physics_frame
			frames += 1
		Input.action_release(&"move_back")
		_check(not bool(player.call(&"is_climbing_ladder")) and absf(player.global_position.y) < 0.03, "operator descends to the lower deck: " + room)


func _set_ladder_approach(player: CharacterBody3D, ladder: ShipLadder, from_upper: bool, aft_approach: bool = false) -> void:
	var target_y: float = ladder.deck_height - 0.05 if from_upper else ladder.deck_height * 0.5
	var target: Vector3 = ladder.global_position + Vector3.UP * target_y
	var approach_z: float = 0.75 if aft_approach else -0.75
	var origin: Vector3 = ladder.call(&"get_upper_exit_position") if from_upper else ladder.global_position + Vector3(0.0, 0.05, approach_z)
	if not from_upper:
		origin.y = 0.05
	player.global_position = origin
	var offset: Vector3 = target - (origin + Vector3.UP * 1.55)
	player.rotation.y = atan2(-offset.x, -offset.z)
	player.get_node(^"Head").rotation.x = atan2(offset.y, Vector2(offset.x, offset.z).length())
	player.velocity = Vector3.ZERO
