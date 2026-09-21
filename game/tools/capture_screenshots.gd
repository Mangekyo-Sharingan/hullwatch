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

	await _capture(player, Vector3(-4.2, 0.1, -9.6), 0.0, "shot_quarters.png")
	await _capture(player, Vector3(0.0, 0.1, -2.5), 0.0, "shot_corridor_north.png")
	await _capture(player, Vector3(-3.7, 0.1, -5.3), 0.0, "shot_life_support.png")
	await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_cockpit.png")
	await _capture(player, Vector3(0.0, 0.1, -10.0), PI * 0.5, "shot_door_prefab.png")
	await _capture(player, Vector3(-3.8, 0.1, 0.2), 0.0, "shot_storage.png")
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
	player.global_position = Vector3(-9.2, 0.2, -10.4)
	player.look_at(Vector3(-8.5, 1.4, -10.4), Vector3.UP)
	await _capture(player, player.global_position, player.rotation.y, "shot_dock_plate.png")

	await _hull_shot(Vector3(-13.0, 2.2, -24.0), Vector3(0.0, 1.8, -19.5), "shot_hull_bow.png")
	await _hull_shot(Vector3(-16.5, 2.2, -5.0), Vector3(0.0, 1.5, -6.0), "shot_hull_broadside.png")
	await _hull_shot(Vector3(3.0, 3.2, 18.0), Vector3(-1.0, 1.6, 10.0), "shot_hull_stern.png")

	var cargo: Node = _main.get_node_or_null("Systems/CargoSystem")
	var modules: Node = _main.get_node_or_null("Systems/ModuleSystem")
	if cargo != null and modules != null and not bool(modules.call("is_installed", &"utility_pod")):
		cargo.call("add_material", &"metal", 8.0)
		cargo.call("add_material", &"ore", 4.0)
		modules.call("start_build", &"utility_pod")
		modules.call("sim_tick", 999.0)
		await process_frame
		await _capture(player, Vector3(-9.2, 0.2, -10.4), PI * 0.5, "shot_dock_mount.png")
		await _capture(player, Vector3(-14.6, 0.4, -10.4), -PI * 0.5, "shot_pod_outside.png")
		await _capture(player, Vector3(-12.6, 0.1, -10.4), -PI * 0.5, "shot_pod_inside.png")
		player.global_position = Vector3(-4.2, 0.1, -9.6)
		await _capture(player, Vector3(-4.2, 0.1, -9.6), PI * 0.5, "shot_pod_doorway.png")
		if modules.has_method(&"fit_machine"):
			cargo.call("add_material", &"metal", 20.0)
			cargo.call("add_material", &"ore", 10.0)
			cargo.call("add_material", &"ice", 6.0)
			modules.call("fit_machine", &"grow_rack", &"hp_quarters:0")
			modules.call("fit_machine", &"work_bench", &"hp_quarters:1")
			modules.call("fit_machine", &"cargo_rack", &"hp_quarters:2")
			modules.call("sim_tick", 999.0)
			await process_frame
			var socket0: Node = _main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters/Socket_0")
			var socket: Node = _main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters/Socket_1")
			player.global_position = Vector3(-10.9, 1.5, -10.4)
			player.look_at(Vector3(-12.05, 0.7, -9.4), Vector3.UP)
			await _capture(player, player.global_position, player.rotation.y, "shot_pod_machines.png")
			if socket != null:
				player.global_position = Vector3(-10.7, 0.1, -10.4)
				player.rotation.y = PI * 0.5
				player.rotation.x = -0.5
				await process_frame
				socket.call("interact", player)
				await _capture(player, Vector3(-10.7, 0.1, -10.4), PI * 0.5, "shot_socket_menu.png")
				socket.call("close")

	print("PASS: capture_screenshots -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


## An exterior vantage: park the player, aim at the hull, carry a work light (the
## exterior has no lighting until the M12 pass).
func _hull_shot(position: Vector3, target: Vector3, file_name: String) -> void:
	var player: Node3D = _main.get_node("Player")
	player.global_position = position
	player.look_at(target, Vector3.UP)
	await _capture(player, player.global_position, player.rotation.y, file_name)


func _capture(player: Node3D, position: Vector3, yaw: float, file_name: String) -> void:
	player.global_position = position
	player.rotation.y = yaw
	var work_light: OmniLight3D = null
	if _needs_work_light(position):
		work_light = OmniLight3D.new()
		work_light.light_energy = 4.0
		work_light.omni_range = 10.0
		work_light.position = Vector3(0.8, -0.3, -0.8)
		player.add_child(work_light)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	image.save_png(OUTPUT_DIR + "/" + file_name)
	if work_light != null:
		work_light.queue_free()


## The exterior has no lighting yet (M12); carry a work light so exterior captures read.
func _needs_work_light(position: Vector3) -> bool:
	return position.y > 3.4 or absf(position.x) > 7.0 or position.z < -19.5 or position.z > 8.5 or position.x < -8.5


func _stand_and_face(player: Node3D, target: Vector3, distance: float) -> void:
	var flat_target := Vector3(target.x, player.global_position.y, target.z)
	var direction: Vector3 = flat_target - player.global_position
	if direction.length() < 0.01:
		direction = Vector3.FORWARD
	player.global_position = flat_target - direction.normalized() * distance
	player.look_at(flat_target, Vector3.UP)
