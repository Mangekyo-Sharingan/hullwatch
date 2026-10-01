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
	head.rotation.x = deg_to_rad(45.0)
	var free_start: Vector3 = player.global_position
	Input.action_press(&"move_forward")
	for i: int in 30:
		await physics_frame
	Input.action_release(&"move_forward")
	_check(player.global_position.y > free_start.y + 0.05, "free-flight thrust follows the camera pitch")

	_check(player.global_position.z < free_start.z - 0.05, "free-flight W thrust moves forward, not backward")
	Input.action_press(&"brake")
	for i: int in 30:
		await physics_frame
	Input.action_release(&"brake")
	_check(player.velocity.length() < 0.01, "brake cancels drift without aiming against momentum")
	Input.action_press(&"crouch")
	for i: int in 20:
		await physics_frame
	Input.action_release(&"crouch")
	_check(player.velocity.y < -0.1, "Ctrl supplies downward thrust without changing camera aim")
	_check(not player.get("_crouched"), "drift thrust does not crouch or snap the camera")

	player.global_position = Vector3(0.0, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	head.rotation.x = 0.0
	_check(player.engage_boots(), "boots re-engage near surface")
	_check(player.is_boots_engaged(), "boots report engaged")

	for i: int in 40:
		await physics_frame
	var velocity_before: Vector3 = player.velocity
	var pushed: bool = player.push_off()
	_check(pushed, "push_off finds a surface while engaged")
	_check(player.velocity.y > velocity_before.y, "push_off adds upward velocity")
	player.disengage_boots()
	var wall: StaticBody3D = StaticBody3D.new()
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(0.2, 6.0, 6.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(1.0, 3.0, 0.0)
	root.add_child(wall)
	player.global_position = Vector3(0.35, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	await physics_frame
	player.velocity = Vector3(3.0, 0.0, 0.0)
	_check(player.push_off(), "push finds a side wall before collision, with boots facing away")
	_check(player.velocity.x < -1.5, "push reverses incoming wall drift instead of adding an ineffective impulse")
	var outgoing: float = player.velocity.x
	player.push_off()
	_check(player.velocity.x < outgoing, "another reachable push preserves and adds to outgoing momentum")
	player.velocity = Vector3.ZERO
	player.global_rotation.z = deg_to_rad(30.0)
	_check(player.engage_boots(), "boots recover the deck after rolling, without looking down")
	_check(player.up_direction.dot(Vector3.UP) > 0.99, "deck takes priority over adjacent wall")
	for i: int in 60:
		await physics_frame
	_check(player.is_on_floor(), "recovered boots land on the deck through collision movement")
	_check((player.get_node(^"Head/Camera3D") as Camera3D).position.length() < 0.01, "eased boot view returns to its normal eye anchor")
	_check(player.global_position.x < 0.66, "deck recovery does not move through the side wall")
	player.disengage_boots()
	player.global_position = Vector3(0.35, 1.0, 0.0)
	player.global_rotation = Vector3.ZERO
	Input.action_press(&"roll_right")
	for i: int in 20:
		await physics_frame
	Input.action_release(&"roll_right")
	_check(absf(player.global_rotation.z) > 0.1, "roll supplies a third rotation axis in free flight")
	floor_body.collision_layer = 0
	player.global_rotation = Vector3.ZERO
	player.global_position = Vector3(0.35, 1.0, 0.0)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	_check(player.engage_boots(), "EVA boots can align away from a close wall when there is no deck")
	_check(player.up_direction.dot(Vector3.LEFT) > 0.99, "wall attachment uses the physical outward normal")
	_check(player.global_position.x < 0.66, "wall attachment stays on the near side of the hull")
	player.disengage_boots()
	floor_body.collision_layer = 1
	wall.free()
	var ceiling: StaticBody3D = StaticBody3D.new()
	var ceiling_shape: CollisionShape3D = CollisionShape3D.new()
	var ceiling_box: BoxShape3D = BoxShape3D.new()
	ceiling_box.size = Vector3(6.0, 0.2, 6.0)
	ceiling_shape.shape = ceiling_box
	ceiling.add_child(ceiling_shape)
	ceiling.position = Vector3(0.0, 4.0, 0.0)
	root.add_child(ceiling)
	ceiling.position.y = 2.6
	player.global_position = Vector3(0.0, 1.0, 0.0)
	player.global_rotation.z = PI * 0.5
	player.velocity = Vector3.ZERO
	await physics_frame
	_check(player.engage_boots(), "sideways recovery fits under a 2.5 m cabin ceiling")
	for i: int in 60:
		await physics_frame
	_check(player.is_on_floor(), "sideways recovery reaches the floor without ceiling collision")
	player.disengage_boots()
	ceiling.position.y = 4.0
	await physics_frame
	await physics_frame
	player.global_rotation = Vector3.ZERO
	player.global_position = Vector3(0.0, 2.0, 0.0)
	player.velocity = Vector3.ZERO
	await physics_frame
	player.velocity = Vector3(0.0, 3.0, 0.0)
	_check(player.push_off(), "push finds an overhead surface without a slide contact")
	_check(player.velocity.y < -1.5, "overhead push supplies a usable downward impulse")
	ceiling.free()
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
