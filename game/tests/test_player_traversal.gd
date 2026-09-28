## Integration test: verifies that the player can walk end-to-end through every section
## of the ship without getting blocked by equipment, modules, or doorways.
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
	var airlock_inner = main.get_node_or_null("WorldLayout/Props/DoorAirlockInner")
	if airlock_inner != null:
		airlock_inner.call("_set_open", true)

	await process_frame

	# Test 1: Shape cast / intersect check along center aisle from bow to stern
	# Every 0.25 m from z = -20.2 to z = 5.5, the player must be able to stand
	# at some x in [-0.25, 0.25] on the deck (y = 0.05).
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
		# Try x = 0.0, -0.15, 0.15, -0.25, 0.25
		for x_offset: float in [0.0, -0.15, 0.15, -0.25, 0.25]:
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
	# Start at cupola / cockpit bow: z = -20.0
	player.global_position = Vector3(0.0, 0.05, -20.0)
	player.velocity = Vector3.ZERO
	await process_frame

	var current_z: float = player.global_position.z
	var steps: int = 0
	var max_steps: int = 600 # 600 frames at ~60fps is 10 seconds
	var reached_stern: bool = false

	# Target walk speed: 4.0 m/s
	while steps < max_steps:
		# Steer along aisle towards z = 5.5
		var target_x: float = 0.0
		# Gentle steering towards center
		var x_err: float = target_x - player.global_position.x
		player.velocity = Vector3(clampf(x_err * 3.0, -2.0, 2.0), -9.8, 3.5)
		player.move_and_slide()
		steps += 1
		if player.global_position.z >= 5.0:
			reached_stern = true
			break
		await physics_frame

	_check(reached_stern, "player walked bow-to-stern from z=-20.0 to z=5.0 (reached z=%.2f in %d frames)" % [player.global_position.z, steps])

	# Test 3: Dynamic movement back from stern to bow
	var reached_bow: bool = false
	steps = 0
	while steps < max_steps:
		var target_x: float = 0.0
		var x_err: float = target_x - player.global_position.x
		player.velocity = Vector3(clampf(x_err * 3.0, -2.0, 2.0), -9.8, -3.5)
		player.move_and_slide()
		steps += 1
		if player.global_position.z <= -19.5:
			reached_bow = true
			break
		await physics_frame

	_check(reached_bow, "player walked stern-to-bow from z=5.0 to z=-19.5 (reached z=%.2f in %d frames)" % [player.global_position.z, steps])

	main.queue_free()
	await process_frame
	_finish()
