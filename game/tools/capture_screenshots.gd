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
	var comms_terminal: Node = _main.get_node_or_null("WorldLayout/Props/CommsTerminal")
	if comms_terminal != null:
		player.global_position = Vector3(3.0, 0.1, -16.6)
		player.rotation.y = 0.0
		await process_frame
		comms_terminal.call("interact", player)
		await _capture(player, Vector3(3.0, 0.1, -16.6), 0.0, "shot_comms.png")

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
