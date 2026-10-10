extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var main: Node3D = load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(main)
	await process_frame
	await physics_frame
	var clock: Node = root.get_node("SimClock")
	clock.call("set_paused", true)
	var player: Node = main.get_node("Player")
	player.set_physics_process(false)
	for layer: Node in main.find_children("*", "CanvasLayer", true, false):
		if layer.name != &"AnalogueFilter":
			(layer as CanvasLayer).visible = false
	var bus: Node = root.get_node("EventBus")
	var guide: Node = main.get_node("UI/GuideOverlay")
	var guide_callback: Callable = Callable(guide, "_on_sim_event")
	if bus.is_connected(&"sim_event", guide_callback):
		bus.disconnect(&"sim_event", guide_callback)
	var camera: Camera3D = Camera3D.new()
	camera.near = 0.05
	camera.fov = 80.0
	main.add_child(camera)
	camera.make_current()
	var shots: Array[Dictionary] = [
		{"name": "hull", "eye": Vector3(-11.0, 9.0, -15.0), "target": Vector3(0.0, 0.6, -8.5)},
		{"name": "cockpit_joint", "eye": Vector3(0.70, 1.55, -19.2), "target": Vector3(0.0, 1.0, -18.3)},
		{"name": "life_support_walkway", "eye": Vector3(0.0, 1.55, -12.1), "target": Vector3(0.0, 1.0, -10.0)},
		{"name": "life_support_bay", "eye": Vector3(0.0, 1.55, -11.05), "target": Vector3(3.848, 1.15, -11.05)},
		{"name": "galley_walkway", "eye": Vector3(0.0, 1.55, -9.4), "target": Vector3(0.0, 1.0, -7.2)},
		{"name": "galley_bay", "eye": Vector3(0.0, 1.55, -8.3), "target": Vector3(-4.024, 1.15, -8.3)},
	]
	var folder: String = "user://layout_comparison"
	DirAccess.make_dir_recursive_absolute(folder)
	for shot: Dictionary in shots:
		camera.position = shot["eye"]
		camera.look_at(shot["target"] as Vector3)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var error: Error = root.get_texture().get_image().save_png(folder.path_join(String(shot["name"]) + ".png"))
		if error != OK:
			push_error("capture_layout_clearance failed: " + String(shot["name"]))
			quit(1)
			return
		print("CAPTURE: ", shot["name"])
	print("PASS: capture_layout_clearance")
	quit(0)
