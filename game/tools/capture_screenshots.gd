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
	if OS.get_cmdline_user_args().has("--movement-only"):
		await _capture(player, Vector3(0.0, 0.1, -14.4), 0.0, "shot_movement_boots.png")
		player.call("disengage_boots")
		player.global_position.y = 0.35
		player.rotate_object_local(Vector3.FORWARD, 0.25)
		for i: int in 20:
			await physics_frame
		await _capture_current("shot_movement_drift.png")
		player.call("engage_boots")
		for i: int in 60:
			await physics_frame
		await _capture_current("shot_movement_landed.png")
		print("PASS: movement captures -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	if OS.get_cmdline_user_args().has("--watch-loop-only"):
		await _capture(player, Vector3(0.0, 0.1, -4.0), 0.0, "shot_watch_hatch_fore.png")
		await _capture(player, Vector3(0.0, 0.1, -8.3), PI, "shot_watch_hatch_aft.png")
		var board: Node = _main.get_node_or_null("WorldLayout/Props/MaintenanceBoard")
		if board != null:
			_stand_and_face(player, (board as Node3D).global_position, 1.1)
			board.call("interact", player)
			await _capture_current("shot_watch_report.png")
			board.call("close")
		var pause_menu: Node = _main.get_node_or_null("UI/PauseMenu")
		if pause_menu != null:
			pause_menu.call("open")
			await _capture_current("shot_watch_pause.png")
			pause_menu.call("close")
		var menu: Node = (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
		root.add_child(menu)
		await _capture_current("shot_watch_main_menu.png")
		print("PASS: watch loop captures -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	if OS.get_cmdline_user_args().has("--watch-interior-only"):
		await _capture(player, Vector3(0.0, 0.1, -4.0), 0.0, "shot_watch_hatch_fore.png")
		await _capture(player, Vector3(0.0, 0.1, -8.3), PI, "shot_watch_hatch_aft.png")
		await _capture(player, Vector3(0.0, 0.1, -14.4), 0.0, "shot_watch_quarters.png")
		print("PASS: watch interior captures -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	if OS.get_cmdline_user_args().has("--propulsion-only"):
		await _ion_drive_shots()
		print("PASS: propulsion captures -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	if OS.get_cmdline_user_args().has("--voyage-only"):
		await _voyage_shots(player)
		print("PASS: voyage captures -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return

	if _tube_preview():
		if player.has_method("release_tether"):
			player.call("release_tether")
		await _capture(player, Vector3(0.95, 0.1, -18.95), 0.0, "shot_tube_cockpit.png")
		var pilot_chair: PilotChair = _main.get_node_or_null("WorldLayout/Props/PilotChair") as PilotChair
		if pilot_chair != null and player.has_method("enter_pilot_seat"):
			player.global_position = pilot_chair.global_position + Vector3(0.0, 0.0, 1.0)
			player.call("enter_pilot_seat", pilot_chair)
			player.rotation.y = 0.0
			await _capture_current("shot_tube_pilot_view.png")
			player.rotation.y = -PI * 0.5
			await _capture_current("shot_tube_cockpit_starboard_bank.png")
			player.rotation.y = PI * 0.5
			await _capture_current("shot_tube_cockpit_port_bank.png")
			player.call("exit_pilot_seat")
		await _capture(player, Vector3(0.0, 0.1, -4.5), PI, "shot_tube_storage.png")
		await _capture(player, Vector3(0.0, 0.1, -13.9), 0.0, "shot_tube_quarters.png")
		await _capture(player, Vector3(-0.8, 0.1, -13.9), -PI * 0.5, "shot_tube_quarters_locker.png")
		await _capture(player, Vector3(0.6, 0.1, -8.3), PI * 0.5, "shot_tube_galley.png")
		await _capture(player, Vector3(0.8, 0.1, -11.05), PI * 0.5, "shot_tube_life_support.png")
		await _capture(player, Vector3(0.6, 1.3, -10.3), PI * 0.5, "shot_tube_filter_rack.png")
		await _capture(player, Vector3(1.0, 0.1, 2.0), PI * 0.5, "shot_tube_engine_bay.png")
		await _capture(player, Vector3(-1.0, 0.1, 2.0), -PI * 0.5, "shot_tube_tool_cart.png")
		var wall_computer: WallComputer = _main.get_node_or_null("WorldLayout/Props/WallComputer") as WallComputer
		if wall_computer != null:
			await _capture(player, Vector3(-0.15, 1.15, -17.75), PI * 0.5, "shot_tube_wall_computer.png")
			wall_computer.interact(player)
			var animator: AnimationPlayer = wall_computer.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if animator != null:
				await create_timer(animator.current_animation_length + 0.1).timeout
			await _capture(player, Vector3(-0.15, 1.15, -17.75), PI * 0.5, "shot_tube_wall_computer_open.png")
			wall_computer.close()
		await _capture(player, Vector3(0.0, 0.1, -4.0), PI, "shot_tube_chain.png")
		await _capture(player, Vector3(0.0, 0.1, -0.65), PI * 0.5, "shot_tube_airlock.png")
		await _capture(player, Vector3(0.0, 0.1, -0.65), 0.0, "shot_tube_airlock_inner.png")
		await _capture(player, Vector3(0.0, 1.4, -18.6), 0.0, "shot_tube_bow.png")
		await _capture(player, Vector3(0.0, 1.4, -6.0), PI, "shot_tube_aft.png")
		await _capture(player, Vector3(-4.3, 0.1, -0.65), -PI * 0.5, "shot_tube_eva.png")
		await _capture(player, Vector3(-3.24, 0.1, -7.0), 0.0, "shot_tube_walkway.png")
		await _hull_shot(Vector3(-9.5, 3.4, -25.5), Vector3(0.0, 1.6, -17.0), "shot_tube_hull_bow.png")
		await _hull_shot(Vector3(-10.5, 3.8, -3.0), Vector3(0.0, 1.5, -5.0), "shot_tube_hull_broadside.png")
		await _hull_shot(Vector3(5.0, 4.0, 17.5), Vector3(0.0, 1.6, 7.0), "shot_tube_hull_stern.png")
		await _ion_drive_shots()
		await _hull_shot(Vector3(6.8, 3.6, 5.2), Vector3(3.2, 2.4, 8.3), "shot_tube_solar_array.png")

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

	await _tool_shots()
	await _voyage_shots(player)

	print("PASS: capture_screenshots -> ", ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


## Hand tools: the authored kit in the operator's hand mid-use, and the suit-clipped cutter
## while a sample canister rides the carry slot. Runs last, since the cutter stays clipped.
func _tool_shots() -> void:
	var player: Node3D = _main.get_node("Player")
	var event_bus: Node = root.get_node_or_null("EventBus")
	var multimeter: Node = _main.get_node_or_null("WorldLayout/Props/MultimeterTool")
	if multimeter != null:
		player.global_position = Vector3(-0.35, 0.1, -3.3)
		player.rotation.y = -PI * 0.5
		await process_frame
		multimeter.call("interact", player)
		if event_bus != null:
			event_bus.call("emit_event", &"probe_diagnosis", {"system": &"power_system", "component_id": &"rtg_main", "failure_mode_id": &"rtg_degraded"})
		await create_timer(0.2).timeout
		await _capture(player, Vector3(-0.35, 0.1, -3.3), -PI * 0.5, "shot_tool_multimeter.png")
		player.call("drop_carried")
	var cutter: Node = _main.get_node_or_null("WorldLayout/Props/CutterTool")
	var canister: Node = _main.get_node_or_null("WorldLayout/Props/SampleCanister2")
	if cutter != null and canister != null:
		player.global_position = Vector3(0.1, 0.1, -0.9)
		player.rotation.y = PI * 0.5
		await process_frame
		cutter.call("interact", player)
		canister.call("interact", player)
		if event_bus != null:
			event_bus.call("emit_event", &"sample_taken", {"object_id": "shot", "resource": "ore", "units": 1.0, "remaining": 1.0})
		await create_timer(0.2).timeout
		await _capture(player, Vector3(0.1, 0.1, -0.9), PI * 0.5, "shot_tool_cutter.png")
		player.call("drop_carried")


func _voyage_shots(player: Node3D) -> void:
	var nav: Node = _main.get_node_or_null("Systems/NavSystem")
	var console: NavConsole = _main.get_node_or_null("WorldLayout/Props/NavConsole") as NavConsole
	if nav == null or console == null:
		return
	player.call("release_tether")
	await create_timer(4.1).timeout
	var arrival: Node = _main.get_node_or_null("UI/LegCompleteOverlay")
	console.interact(player)
	await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_star_chart.png")
	console.select_action(&"arden_ii")
	await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_star_chart_course.png")
	console.close()
	if bool(nav.call("begin_transit")):
		nav.call("sim_tick", 48.0)
		await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_arden_ii_arrival.png")
		if arrival != null:
			arrival.call("dismiss")
			await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_arden_ii_window.png")
		console.interact(player)
		await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_arden_ii_chart.png")
		console.close()
		if bool(nav.call("plot_course", &"kestrel_system")) and bool(nav.call("begin_transit")):
			nav.call("sim_tick", 96.0)
			await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_kestrel_arrival.png")
			if arrival != null:
				arrival.call("dismiss")
				await _capture(player, Vector3(0.0, 0.1, -15.0), 0.0, "shot_kestrel_window.png")
	var breaker: BreakerPanel = _main.get_node_or_null("WorldLayout/Props/BreakerPanel") as BreakerPanel
	if breaker != null:
		breaker.interact(player)
		await _capture(player, Vector3(0.0, 0.1, -4.5), PI, "shot_lighting_breaker_open.png")
		breaker.interact(player)


## An exterior vantage: park the player, aim at the hull, carry a work light (the
## exterior has no lighting until the M12 pass).
func _hull_shot(position: Vector3, target: Vector3, file_name: String, hide_hud: bool = false) -> void:
	var player: Node3D = _main.get_node("Player")
	player.global_position = position
	player.look_at(target, Vector3.UP)
	await _capture(player, player.global_position, player.rotation.y, file_name, hide_hud)


func _ion_drive_shots() -> void:
	var nav: Node = _main.get_node_or_null("Systems/NavSystem")
	if nav == null:
		return
	nav.call("load_state", {
		"state_version": 2,
		"current_destination_id": "",
		"plotted_destination_id": "",
		"fuel_mass_kg": 1200.0,
		"course_error": 0.0,
		"transit_elapsed_hours": 0.0,
		"transit_active": false,
		"visited_destinations": {},
	})
	await _hull_shot(Vector3(0.0, 1.8, 14.8), Vector3(0.0, 1.55, 10.5), "shot_tube_ion_drives_idle.png", true)
	await _hull_shot(Vector3(-1.9, 2.25, 10.6), Vector3(-0.72, 1.55, 10.5), "shot_tube_ion_drive_service.png", true)
	await _hull_shot(Vector3(2.5, 1.8, 12.6), Vector3(0.72, 1.55, 10.5), "shot_tube_ion_drive_eva.png", true)
	for target: StringName in [&"port", &"starboard", &"tank"]:
		nav.call("service_action", target, &"isolate", &"")
		nav.call("service_action", target, &"open", &"wrench")
		await create_timer(0.85).timeout
		var side: float = -1.0 if target == &"port" else 1.0
		var position: Vector3 = Vector3(side * 1.9, 2.25, 11.9) if target != &"tank" else Vector3(0.0, 1.8, 12.0)
		var look_target: Vector3 = Vector3(side * 0.72, 2.0, 10.65) if target != &"tank" else Vector3(0.0, 1.55, 10.7)
		await _hull_shot(position, look_target, "shot_tube_drive_%s_service_open.png" % String(target), true)
		nav.call("service_action", target, &"close", &"wrench")
		nav.call("service_action", target, &"restore", &"multimeter")
		await create_timer(0.85).timeout
	if bool(nav.call("plot_course", &"arden_ii")) and bool(nav.call("begin_transit")):
		await _hull_shot(Vector3(3.2, 1.8, 14.4), Vector3(0.0, 1.55, 10.7), "shot_tube_ion_drives_burning.png", true)
		nav.call("force_failure", &"port_grid", &"grid_fouled")
		await _hull_shot(Vector3(3.2, 1.8, 14.4), Vector3(0.0, 1.55, 10.7), "shot_tube_ion_drive_single.png", true)
		var service: Node = _main.get_node_or_null("ShipGeometry/HullExterior/IonDrivePort/DriveService")
		if service != null:
			nav.call("service_action", &"port", &"isolate", &"")
			nav.call("service_action", &"port", &"open", &"wrench")
			nav.call("service_action", &"port", &"diagnose", &"multimeter")
			service.call("interact", null)
			await _hull_shot(Vector3(-1.9, 2.25, 11.9), Vector3(-0.72, 2.0, 10.65), "shot_tube_drive_diagnostics.png")
			service.call("close")
		nav.call("sim_tick", 48.0)


func _capture(player: Node3D, position: Vector3, yaw: float, file_name: String, hide_hud: bool = false) -> void:
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
	await physics_frame
	await physics_frame
	await process_frame
	var restore_layers: Array[CanvasLayer] = []
	if hide_hud:
		for node: Node in _main.find_children("*", "CanvasLayer", true, false):
			var layer: CanvasLayer = node as CanvasLayer
			if layer.name != &"AnalogueFilter" and layer.visible:
				restore_layers.append(layer)
				layer.visible = false
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	image.save_png(OUTPUT_DIR + "/" + file_name)
	for layer: CanvasLayer in restore_layers:
		layer.visible = true
	if work_light != null:
		work_light.queue_free()


func _capture_current(file_name: String) -> void:
	var player: Node3D = _main.get_node("Player") as Node3D
	var work_light: OmniLight3D = OmniLight3D.new()
	work_light.light_energy = 4.0
	work_light.omni_range = 10.0
	work_light.position = Vector3(0.8, -0.3, -0.8)
	player.add_child(work_light)
	await process_frame
	await physics_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	image.save_png(OUTPUT_DIR + "/" + file_name)
	work_light.queue_free()


## True when the scene was generated with the M13.2 tube interior (preview run).
## True when the scenes on disk are the tube interior, either because that is what ships or
## because --interior-style=tube asked for it.
func _tube_preview() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--interior-style=tube":
			return true
		if arg == "--interior-style=flat":
			return false
	var scene: Node = load("res://scenes/ship_geometry.tscn").instantiate()
	var is_tube: bool = scene.get_node_or_null(^"Section_storage") != null
	scene.free()
	return is_tube


## Interior lamps follow the lighting breaker; carry a work light only for exterior captures.
func _needs_work_light(position: Vector3) -> bool:
	return position.y > 3.4 or absf(position.x) > 7.0 or position.z < -19.5 or position.z > 8.5 or position.x < -8.5


func _stand_and_face(player: Node3D, target: Vector3, distance: float) -> void:
	var flat_target := Vector3(target.x, player.global_position.y, target.z)
	var direction: Vector3 = flat_target - player.global_position
	if direction.length() < 0.01:
		direction = Vector3.FORWARD
	player.global_position = flat_target - direction.normalized() * distance
	player.look_at(flat_target, Vector3.UP)
