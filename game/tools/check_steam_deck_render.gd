## Run the matching editor with --main-pack exported_ELF at 1280x800 and a real display.
## Linux release templates disable --script; native startup is checked separately.
extends SceneTree

var _output: String = "user://captures/steamdeck"
var _failed: bool = false


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			_output = argument.trim_prefix("--output=")
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendering check requires a real display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_output)
	var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _capture("main_menu", menu.get("_view") as Control)
	var settings: Node = menu.get("_settings") as Node
	settings.call("open")
	await _capture("settings", settings.call("get_menu") as Control)
	menu.queue_free()
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var player: Node = main.get_node("Player")
	player.set_physics_process(false)
	root.get_node("SimClock").set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _capture("cabin", null)
	var body: Node3D = player as Node3D
	var spawn: Transform3D = body.global_transform
	body.global_position = Vector3(0.0, 0.04, -21.7)
	body.rotation = Vector3.ZERO
	await _capture("cockpit", null)
	body.global_transform = spawn
	for name: String in ["NavConsole", "ManualBinder", "Fabricator", "AirlockPanel"]:
		var station: Node = main.get_node_or_null("WorldLayout/Props/" + name)
		if station == null:
			push_error("Missing station " + name)
			_failed = true
			continue
		station.call("interact", player)
		await _capture(name, station.get("_root") as Control)
		if station is ComputerTerminal:
			station.call("set_program", &"control")
			await _capture("control", station.get("_root") as Control)
			station.call("select_action", &"page:lighting")
			await _capture("lighting", station.get("_root") as Control)
		if station is ManualBinder:
			for page: int in station.get_page_count():
				station.get_menu().set_highlighted_index(page)
				await _capture("manual_%02d" % page, station.get("_root") as Control)
		station.call("close")
	main.queue_free()
	await process_frame
	await process_frame
	print("%s: steam_deck_render (%s, %s, %s) -> %s" % ["FAIL" if _failed else "PASS", DisplayServer.get_name(), RenderingServer.get_current_rendering_method(), root.size, ProjectSettings.globalize_path(_output)])
	quit(1 if _failed else 0)


func _capture(label: String, panel: Control) -> void:
	for frame: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	if panel != null:
		var bounds: Rect2 = panel.get_global_rect()
		if not Rect2(Vector2.ZERO, Vector2(root.size)).encloses(bounds):
			push_error("Panel outside viewport: %s %s" % [label, bounds])
			_failed = true
	var error: Error = root.get_texture().get_image().save_png(_output.path_join(label + ".png"))
	if error != OK:
		push_error("Capture failed: " + label)
		_failed = true
