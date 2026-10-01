## A seated operator can freelook, use nearby live panels, and leave by the side aisle.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player: CharacterBody3D = main.get_node("Player") as CharacterBody3D
	var chair: PilotChair = main.get_node("WorldLayout/Props/PilotChair") as PilotChair
	var contact: Node3D = main.get_node("WorldLayout/Props/ContactConsole") as Node3D
	var blade: WallComputer = main.get_node("WorldLayout/Props/WallComputer") as WallComputer
	_check(player != null and chair != null and contact != null and blade != null, "pilot and cockpit stations exist")
	if player == null or chair == null or contact == null or blade == null:
		main.queue_free()
		_finish()
		return

	player.global_position = chair.global_position + Vector3(0.0, 0.0, 1.15)
	player.global_rotation.z = 0.4
	var approach_position: Vector3 = player.global_position
	chair.interact(player)
	await physics_frame
	_check(bool(player.get("_seat_transitioning")), "boarding waits through the chair preparation")
	_check(player.global_position.distance_to(approach_position) < 0.01, "operator remains at the approach point until the chair is ready")
	var seat_distance: float = player.global_position.distance_to(chair.get_seat_world_position())
	var saw_sit_motion: bool = false
	var timeout: SceneTreeTimer = create_timer(8.0)
	while timeout.time_left > 0.0 and not bool(player.call("is_pilot_seated")):
		await physics_frame
		var remaining_distance: float = player.global_position.distance_to(chair.get_seat_world_position())
		if remaining_distance > 0.05 and remaining_distance < seat_distance - 0.02:
			saw_sit_motion = true
	_check(bool(player.call("is_pilot_seated")) and chair.is_occupied(), "E seats the operator and locks the chair forward")
	_check(absf(player.global_rotation.z) < 0.01 and absf(player.global_rotation.x) < 0.01, "boarding levels prior drift roll and pitch")
	_check(saw_sit_motion, "camera body travels into the seat instead of snapping there")
	_check(player.global_position.distance_to(chair.get_seat_world_position()) < 0.05, "camera body moves to the pilot eye anchor")
	var shape: CollisionShape3D = player.get_node(^"CollisionShape3D") as CollisionShape3D
	_check(shape != null and shape.disabled, "seated body does not collide with its own chair")
	var ray: RayCast3D = player.get_node(^"Head/Camera3D/InteractRay") as RayCast3D
	_check(ray.target_position.length() > 3.5, "seated panel reach covers both wall banks")
	Input.action_press(&"move_forward")
	player.call("_physics_process", 0.1)
	Input.action_release(&"move_forward")
	_check(player.velocity == Vector3.ZERO, "seated movement input cannot walk the chair")
	var yaw_before: float = player.rotation.y
	player.call("_apply_look_motion", Vector2(80.0, -30.0))
	_check(not is_equal_approx(player.rotation.y, yaw_before), "seated mouse movement preserves freelook")
	var camera: Camera3D = player.get_node(^"Head/Camera3D") as Camera3D
	camera.look_at(contact.global_position, Vector3.UP)
	await physics_frame
	var target: CollisionObject3D = player.call("get_seated_target") as CollisionObject3D
	_check(target == contact, "freelook ray reaches the real contact panel past the chair")
	if target == contact:
		player.call("_try_interact")
		_check(bool(contact.call("is_open")), "E opens a live cockpit console from the seat")
		contact.call("close")

	blade.interact(player)
	_check(blade.is_open(), "pull-out computer opens from the seated station")
	blade.close()
	_check(bool(player.call("is_pilot_seated")) and player.is_processing_unhandled_input(), "closing blade returns to seated freelook")
	var leave: InputEventAction = InputEventAction.new()
	leave.action = &"leave_seat"
	leave.pressed = true
	var exit_distance: float = player.global_position.distance_to(chair.get_exit_world_position())
	var saw_exit_motion: bool = false
	player.call("_unhandled_input", leave)
	await physics_frame
	_check(not bool(player.call("is_pilot_seated")) and not chair.is_occupied(), "X leaves the pilot seat")
	timeout = create_timer(2.0)
	while timeout.time_left > 0.0 and bool(player.get("_seat_transitioning")):
		await physics_frame
		var remaining_exit_distance: float = player.global_position.distance_to(chair.get_exit_world_position())
		if remaining_exit_distance > 0.05 and remaining_exit_distance < exit_distance - 0.02:
			saw_exit_motion = true
	_check(saw_exit_motion, "operator rises and moves into the side aisle")
	_check(shape != null and not shape.disabled and ray.target_position.length() < 3.0, "standing collision and interaction reach restore")
	_check(player.global_position.distance_to(chair.get_exit_world_position()) < 0.05, "operator exits into the side aisle")

	main.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_pilot_seat_flow")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)
