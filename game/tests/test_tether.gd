## Tether tests: attach/release, taut clamp, freed-anchor recovery and the input action.
extends SceneTree

var _failures: int = 0
var _player: CharacterBody3D
var _anchor: TetherAnchor


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var player_scene: PackedScene = load("res://scenes/player.tscn") as PackedScene
	_player = player_scene.instantiate() as CharacterBody3D
	root.add_child(_player)
	_anchor = TetherAnchor.new()
	_anchor.name = "TestAnchor"
	_anchor.max_length = 4.0
	root.add_child(_anchor)
	_anchor.global_position = Vector3.ZERO
	_player.global_position = Vector3(1.0, 0.0, 0.0)
	await physics_frame
	await physics_frame

	_check(InputMap.has_action(&"toggle_tether"), "tether action is mapped")
	_check(not bool(_player.call("is_tethered")), "player starts untethered")
	_check(bool(_player.call("attach_tether", _anchor)), "attach succeeds")
	_check(bool(_player.call("is_tethered")), "player is tethered after attach")

	_player.global_position = Vector3(10.0, 0.0, 0.0)
	await physics_frame
	await physics_frame
	var distance: float = float(_player.call("get_tether_distance"))
	_check(distance <= 4.05, "taut tether clamps the distance (got %.2f m)" % distance)
	var barrier: StaticBody3D = StaticBody3D.new()
	var barrier_shape: CollisionShape3D = CollisionShape3D.new()
	var barrier_box: BoxShape3D = BoxShape3D.new()
	barrier_box.size = Vector3(0.2, 2.0, 2.0)
	barrier_shape.shape = barrier_box
	barrier.add_child(barrier_shape)
	barrier.position = Vector3(6.0, 1.0, 0.0)
	root.add_child(barrier)
	_player.global_position = Vector3(10.0, 0.0, 0.0)
	await physics_frame
	await physics_frame
	_check(_player.global_position.x > 6.0, "taut tether stops at intervening collision instead of clipping through it")
	barrier.free()

	_player.call("release_tether")
	_check(not bool(_player.call("is_tethered")), "release detaches the line")
	_player.global_position = Vector3(20.0, 0.0, 0.0)
	await physics_frame
	_check(float(_player.call("get_tether_distance")) == 0.0, "detached line reports no distance")

	_player.call("attach_tether", _anchor)
	_anchor.free()
	await physics_frame
	await physics_frame
	_check(not bool(_player.call("is_tethered")), "a freed anchor detaches safely")

	_player.free()
	if _failures == 0:
		print("PASS: test_tether")
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
