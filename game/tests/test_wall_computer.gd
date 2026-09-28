## Wall computer regression: the generated station exists, unfolds on use and folds on close.
extends SceneTree

const LAYOUT_PATH: String = "res://scenes/world_layout.tscn"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	var layout: Node3D = (load(LAYOUT_PATH) as PackedScene).instantiate() as Node3D
	root.add_child(layout)
	await process_frame
	await process_frame

	var terminal: WallComputer = layout.get_node_or_null(^"Props/WallComputer") as WallComputer
	_check(terminal != null, "world layout holds the wall computer")
	if terminal == null:
		layout.free()
		_finish()
		return

	var animator: AnimationPlayer = terminal.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(animator != null, "wall computer carries the authored animator")
	_check(animator != null and animator.has_animation(&"unfold"), "animator ships the unfold clip")

	var screen: MeshInstance3D = terminal.find_child("Screen", true, false) as MeshInstance3D
	_check(screen != null, "model exposes its screen mesh")
	_check(screen != null and screen.material_override != null, "screen takes the phosphor tint on load")

	var shape: CollisionShape3D = terminal.get_node_or_null(^"Shape") as CollisionShape3D
	_check(shape != null and (shape.shape as BoxShape3D).size.x <= 0.2, "stowed collision stays a slim wall box")
	_check(shape != null and (shape.shape as BoxShape3D).size.y >= 0.6, "wall box spans the panel height")

	var deploy_shape: CollisionShape3D = terminal.get_node_or_null(^"DeployedShape") as CollisionShape3D
	_check(deploy_shape != null, "the pulled-out tray carries its own collider")
	_check(deploy_shape != null and deploy_shape.disabled, "tray collider rests disabled while stowed")
	_check(deploy_shape != null and deploy_shape.position.x > 0.0, "tray collision projects into the cockpit from the left wall")

	var programs: Array[StringName] = terminal.programs
	_check(programs == [&"status", &"control", &"log"], "wall terminal offers status, control and log")
	_check(terminal.get_current_program() == &"status", "wall terminal opens on the status report")

	_check(terminal.get_interaction_prompt() == "Use terminal", "stowed terminal invites use")
	terminal.interact(null)
	_check(terminal.is_open(), "interaction opens the terminal")
	await process_frame
	_check(animator != null and animator.current_animation == &"unfold", "opening plays the unfold clip")
	_check(animator != null and animator.get_playing_speed() > 0.0, "the clip runs forward to deploy")
	_check(deploy_shape != null and deploy_shape.disabled, "tray stays non-solid while it unfolds")
	if animator != null:
		animator.advance(animator.current_animation_length + 0.1)
	_check(deploy_shape != null and not deploy_shape.disabled, "tray collider wakes when deployment finishes")
	_check(terminal.get_interaction_prompt() == "Close terminal", "open terminal offers close")

	terminal.close()
	await process_frame
	_check(not terminal.is_open(), "close stows the readout")
	_check(animator != null and animator.current_animation == &"unfold" and animator.get_playing_speed() < 0.0, "stowing folds the blade back")
	_check(deploy_shape != null and not deploy_shape.disabled, "tray remains solid while it stows")
	if animator != null:
		animator.advance(animator.current_animation_length + 0.1)
	_check(deploy_shape != null and deploy_shape.disabled, "tray collider sleeps when stowing finishes")

	layout.free()
	_finish()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_wall_computer")
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
