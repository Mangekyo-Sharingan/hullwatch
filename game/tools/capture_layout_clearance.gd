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
	var camera: Camera3D = Camera3D.new()
	camera.near = 0.05
	camera.fov = 80.0
	main.add_child(camera)
	camera.make_current()
	var shots: Array[Dictionary] = [
		{"name": "cockpit_hatch", "eye": Vector3(0.0, 1.55, -19.4), "target": Vector3(0.0, 1.1, -18.2)},
		{"name": "cockpit_walkway", "eye": Vector3(0.0, 1.55, -17.0), "target": Vector3(0.0, 1.1, -15.3)},
		{"name": "branched_hull", "eye": Vector3(11.0, 9.0, -15.0), "target": Vector3(0.0, 0.6, -8.5)},
	]
	for bay: Dictionary in TubeLayout.service_bays():
		shots.append({"name": String(bay["name"]) + "_entry", "eye": Vector3(0.0, 1.55, float(bay["center_z"])), "target": Vector3(float(bay["outer_x"]), 1.15, float(bay["center_z"]))})
		shots.append({"name": String(bay["name"]) + "_apron", "eye": Vector3(float(bay["inner_x"]) + float(bay["side"]) * 0.5, 1.55, float(bay["center_z"]) + 0.3), "target": Vector3(float(bay["outer_x"]), 1.0, float(bay["center_z"]))})
	var folder: String = ProjectSettings.globalize_path("res://../docs/design/layout_clearance/review")
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
