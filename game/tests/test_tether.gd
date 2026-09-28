## Tether tests: attach/release, taut clamp, freed-anchor recovery and the input action.
extends SceneTree

var _failures: int = 0
var _player: CharacterBody3D
var _anchor: TetherAnchor
var _strained_events: Array[Dictionary] = []


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

	var event_bus: Node = root.get_node_or_null("EventBus")
	_check(event_bus != null, "event bus is available")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)
	_check(InputMap.has_action(&"toggle_tether"), "tether action is mapped")
	_check(not bool(_player.call("is_tethered")), "player starts untethered")
	_check(float(_player.call("get_tether_extension_ratio")) == 0.0, "untethered extension ratio is zero")
	_check(bool(_player.call("attach_tether", _anchor)), "attach succeeds")
	_check(bool(_player.call("is_tethered")), "player is tethered after attach")
	_check(absf(float(_player.call("get_tether_extension_ratio")) - 0.25) < 0.01, "extension ratio is normalized to anchor length")

	var hud: CanvasLayer = load("res://src/ui/hud.gd").new()
	root.add_child(hud)
	hud.call("_update_eva", 0.25)
	var hud_text: String = String(hud.call("get_eva_text"))
	_check(hud_text.contains("TETHER 1.0 m") and hud_text.contains("[T: RELEASE]"), "HUD keeps tether distance and release prompt")

	_player.global_position = Vector3(3.7, 0.0, 0.0)
	await physics_frame
	_check(_strained_events.size() == 1, "crossing 90% extension emits one strain event")
	if not _strained_events.is_empty():
		_check(float(_strained_events[0].get("ratio", 0.0)) >= 0.9, "strain event includes normalized extension")
	_check(float(_player.call("get_tether_extension_ratio")) >= 0.9, "near-taut tether reports high extension")
	hud.call("_update_eva", 0.25)
	hud_text = String(hud.call("get_eva_text"))
	_check(hud_text.contains("TETHER STRAIN") and hud_text.contains("m") and hud_text.contains("[T: RELEASE]"), "HUD identifies a strained tether and keeps its distance and release prompt")

	_player.global_position = Vector3(3.4, 0.0, 0.0)
	await physics_frame
	_player.global_position = Vector3(3.8, 0.0, 0.0)
	await physics_frame
	_check(_strained_events.size() == 1, "strain event stays latched above the rearm threshold")
	_player.global_position = Vector3(3.1, 0.0, 0.0)
	await physics_frame
	_player.global_position = Vector3(3.8, 0.0, 0.0)
	await physics_frame
	_check(_strained_events.size() == 2, "dropping below 80% rearms the strain event")

	_player.global_position = Vector3(10.0, 0.0, 0.0)
	await physics_frame
	await physics_frame
	var distance: float = float(_player.call("get_tether_distance"))
	_check(distance <= 4.05, "taut tether clamps the distance (got %.2f m)" % distance)
	_check(_strained_events.size() == 2, "hard tether clamp does not repeat a latched strain event")
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
	_check(float(_player.call("get_tether_extension_ratio")) == 0.0, "detached extension ratio is zero")
	_player.global_position = Vector3(20.0, 0.0, 0.0)
	await physics_frame
	_check(float(_player.call("get_tether_distance")) == 0.0, "detached line reports no distance")

	_player.call("attach_tether", _anchor)
	_anchor.free()
	await physics_frame
	await physics_frame
	_check(not bool(_player.call("is_tethered")), "a freed anchor detaches safely")

	hud.free()
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


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"tether_strained":
		_strained_events.append(payload)
