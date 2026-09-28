extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = &"TestFloor"
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(26.0, 0.2, 26.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.1, 0.0)
	root.add_child(floor_body)

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	_check(player_scene != null, "player scene loads")
	if player_scene == null:
		_finish()
		return
	var player: CharacterBody3D = player_scene.instantiate()
	root.add_child(player)
	player.global_position = Vector3(0.0, 0.5, 0.0)
	_check(player.is_boots_engaged(), "boots engaged at start")

	for i: int in 40:
		await physics_frame
	_check(player.is_on_floor(), "player settles onto floor")
	_check(player.velocity.length() < 0.05, "player velocity settles")

	var start_position: Vector3 = player.global_position
	Input.action_press(&"move_forward")
	for i: int in 30:
		await physics_frame
	Input.action_release(&"move_forward")
	var moved: Vector3 = player.global_position - start_position
	_check(moved.z < -0.2, "move_forward moves player forward")
	_check(absf(moved.y) < 0.05, "forward movement stays on floor plane")

	player.disengage_boots()
	player.velocity = Vector3(0.0, 2.0, 0.0)
	for i: int in 30:
		await physics_frame
	_check(not player.is_boots_engaged(), "boots disengaged")
	_check(absf(player.velocity.y - 2.0) < 0.3, "zero-g keeps upward drift")
	player.velocity = Vector3.ZERO
	var head: Node3D = player.get_node(^"Head") as Node3D
	head.rotation.x = deg_to_rad(-45.0)
	var free_start_y: float = player.global_position.y
	Input.action_press(&"move_forward")
	for i: int in 30:
		await physics_frame
	Input.action_release(&"move_forward")
	_check(player.global_position.y > free_start_y + 0.05, "free-flight thrust follows the camera pitch")

	player.global_position = Vector3(0.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	head.rotation.x = 0.0
	_check(player.engage_boots(), "boots re-engage near surface")
	_check(player.is_boots_engaged(), "boots report engaged")

	var velocity_before: Vector3 = player.velocity
	var pushed: bool = player.push_off()
	_check(pushed, "push_off finds a surface while engaged")
	_check(player.velocity.y > velocity_before.y, "push_off adds upward velocity")
	floor_body.collision_layer = 0
	var sensor: StaticBody3D = StaticBody3D.new()
	sensor.collision_layer = 2
	var sensor_shape: CollisionShape3D = CollisionShape3D.new()
	var sensor_box: BoxShape3D = BoxShape3D.new()
	sensor_box.size = Vector3(2.0, 0.2, 2.0)
	sensor_shape.shape = sensor_box
	sensor.add_child(sensor_shape)
	sensor.position = Vector3(0.0, -0.1, 0.0)
	root.add_child(sensor)
	player.disengage_boots()
	player.global_position = Vector3(0.0, 1.0, 0.0)
	await physics_frame
	_check(not player.engage_boots(), "boots ignore non-solid sensor geometry")

	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_player")
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
