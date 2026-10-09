extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	root.get_node("SimClock").call("set_paused", true)
	var player: Node3D = main.get_node("Player") as Node3D
	player.set_process(false)
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for layer: Node in main.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var sector: SectorSystem = main.get_node("Systems/SectorSystem") as SectorSystem
	var streamer: FieldStreamer = main.get_node("FieldStreamer") as FieldStreamer
	var salvage: SalvageSystem = main.get_node("Systems/SalvageSystem") as SalvageSystem
	var wreck: SalvageWreck = null
	for step: int in 20:
		streamer.sync_now()
		for entry: Dictionary in sector.get_active_objects():
			if StringName(entry["kind"]) == &"debris":
				wreck = streamer.get_object_node(String(entry["id"])) as SalvageWreck
				break
		if wreck != null:
			break
		sector.sim_tick(1.0)
	if wreck == null:
		push_error("No wreck found for capture")
		quit(1)
		return
	var camera: Camera3D = Camera3D.new()
	main.add_child(camera)
	camera.global_position = wreck.global_position + Vector3(-0.3, 1.7, -4.5)
	camera.look_at(wreck.global_position + Vector3(0.25, 1.15, 0.6))
	camera.current = true
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(-0.5, 1.7, -1.5)
	light.omni_range = 9.0
	light.light_energy = 2.0
	light.light_color = Color(1.0, 0.89, 0.72)
	wreck.add_child(light)
	var directory: String = ProjectSettings.globalize_path("res://").path_join("../docs/design/survival_slices/review").simplify_path()
	DirAccess.make_dir_recursive_absolute(directory)
	await _capture(directory.path_join("01-wreck-overview.png"))
	var mount: SalvageMount = wreck.get_node("RecoveryMount") as SalvageMount
	salvage.isolate_unit(mount.unit_id)
	salvage.release_unit(mount.unit_id, &"wrench", mount.global_position + sector.get_ship_position() + Vector3(0, 0, -0.6))
	streamer.sync_now()
	await _capture(directory.path_join("01-released-case.png"))
	print("PASS: capture_salvage (preview light; actual scene geometry)")
	quit(0)


func _capture(path: String) -> void:
	for frame: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png(path)
	if error != OK:
		push_error("Capture failed: " + path)
