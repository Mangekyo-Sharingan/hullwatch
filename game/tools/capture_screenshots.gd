## Captures in-game screenshots from the real main scene for review and store use.
## Must run WINDOWED (not --headless) because rendering is required:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --path game --script res://tools/capture_screenshots.gd
extends SceneTree

const OUTPUT_DIR: String = "user://captures"

var _main: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame
	await process_frame

	var player: Node3D = _main.get_node("Player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	await _capture(player, Vector3(-3.15, 0.1, -9.6), 0.0, "shot_quarters.png")
	await _capture(player, Vector3(0.0, 0.1, -2.5), 0.0, "shot_corridor_north.png")
	await _capture(player, Vector3(-2.6, 0.1, -5.3), 0.0, "shot_life_support.png")
	await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_cockpit.png")
	await _capture(player, Vector3(-2.8, 0.1, 0.2), 0.0, "shot_storage.png")
	await _capture(player, Vector3(0.2, 0.1, -5.6), PI, "shot_corridor_south.png")
	var status_panel: Node = _main.get_node_or_null("WorldLayout/Props/StatusPanel")
	if status_panel != null:
		player.global_position = Vector3(0.2, 0.1, -7.0)
		player.rotation.y = PI * 0.5
		await process_frame
		status_panel.call("interact", player)
		await _capture(player, Vector3(0.2, 0.1, -7.0), PI * 0.5, "shot_status_panel.png")
		var event_bus: Node = root.get_node_or_null("EventBus")
		if event_bus != null:
			event_bus.call("emit_event", &"probe_scanned", {"system": &"power_system"})
		await _capture(player, Vector3(0.2, 0.1, -7.0), PI * 0.5, "shot_probe_feedback.png")
		status_panel.call("close")
	var binder: Node = _main.get_node_or_null("WorldLayout/Props/ManualBinder")
	if binder != null:
		_stand_and_face(player, (binder as Node3D).global_position, 1.1)
		await process_frame
		binder.call("interact", player)
		await _capture(player, player.global_position, player.rotation.y, "shot_manual_open.png")
		binder.call("close")
	var comms_terminal: Node = _main.get_node_or_null("WorldLayout/Props/CommsTerminal")
	if comms_terminal != null:
		player.global_position = Vector3(3.0, 0.1, -16.6)
		player.rotation.y = 0.0
		await process_frame
		comms_terminal.call("interact", player)
		await _capture(player, Vector3(3.0, 0.1, -16.6), 0.0, "shot_comms.png")
		comms_terminal.call("close")

	await _capture(player, Vector3(-8.9, 0.1, -6.0), 0.0, "shot_eva_platform.png")
	await _capture(player, Vector3(-6.0, 3.7, -6.0), PI * 0.5, "shot_hull_deck.png")
	await _capture(player, Vector3(1.5, 0.2, 11.5), PI, "shot_aft_ramp.png")

	print("PASS: capture_screenshots -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _capture(player: Node3D, position: Vector3, yaw: float, file_name: String) -> void:
	player.global_position = position
	player.rotation.y = yaw
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	image.save_png(OUTPUT_DIR + "/" + file_name)


func _stand_and_face(player: Node3D, target: Vector3, distance: float) -> void:
	var flat_target := Vector3(target.x, player.global_position.y, target.z)
	var direction: Vector3 = flat_target - player.global_position
	if direction.length() < 0.01:
		direction = Vector3.FORWARD
	player.global_position = flat_target - direction.normalized() * distance
	player.look_at(flat_target, Vector3.UP)
