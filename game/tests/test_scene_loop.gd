## Integration test: boots the real main scene and runs the day loop end to end.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_check(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var scrubber: ScrubberUnit = main.get_node("WorldLayout/Props/ScrubberUnit") as ScrubberUnit
	var panel: StatusPanel = main.get_node("WorldLayout/Props/StatusPanel") as StatusPanel
	var bunk: Bunk = main.get_node("WorldLayout/Props/Bunk") as Bunk
	var transition: SleepTransition = main.get_node("UI/SleepTransition") as SleepTransition
	_check(scrubber != null and panel != null and bunk != null and transition != null, "interactables and UI are wired into the scene")

	var atmosphere: Node = main.get_node("Systems/AtmosphereSystem")
	_check(bool(atmosphere.call("has_compartment", &"main")), "atmosphere compartments are registered")

	var status: Dictionary = atmosphere.call("get_compartment_status", &"main")
	_check(bool(status["scrubber_powered"]), "scrubber unit synced itself to the sim on scene load")
	_check(int(status["occupants"]) == 1, "scene compartment ships with a crew occupant")

	var readout: String = "\n".join(panel.build_readout())
	_check(readout.contains("CO2") and readout.contains("FILTER 15%"), "panel reports the worn filter in-world")
	_check(readout.contains("RTG_MAIN"), "panel reports live component condition in-world")

	var player: CharacterBody3D = main.get_node("Player") as CharacterBody3D
	var interact_ray: RayCast3D = main.get_node("Player/Head/Camera3D/InteractRay") as RayCast3D
	_check(player != null and interact_ray != null, "player interaction rig exists")
	if player != null and interact_ray != null:
		_check(interact_ray.collision_mask == 3, "interact ray sees the door sensor layer")
		_check(player.collision_mask == 1, "player body ignores the door sensor layer")

	_test_world_wiring(main, atmosphere)
	_test_space_backdrop(main)

	transition.fade_out_seconds = 0.05
	transition.fade_in_seconds = 0.05
	transition.summary_hold_seconds = 0.05
	atmosphere.call("set_leak_rate", &"quarters", 0.01)
	var pressure_before: float = float(atmosphere.call("get_compartment_status", &"quarters")["pressure_kpa"])
	var power: Node = main.get_node("Systems/PowerSystem")
	var battery_before: float = float(power.call("get_status")["battery_fraction"])
	var sim_clock: Node = root.get_node_or_null("SimClock")
	_check(sim_clock != null, "sim clock autoload present")
	var before_hours: float = float(sim_clock.call("get_total_hours"))
	bunk.interact(null)
	var frames_waited: int = 0
	while bunk.is_sleeping() and frames_waited < 900:
		await process_frame
		frames_waited += 1
	_check(not bunk.is_sleeping(), "bunk completes the sleep transition")
	var advanced: float = float(sim_clock.call("get_total_hours")) - before_hours
	_check(absf(advanced - 8.0) < 0.05, "scene sleep advances the shared clock by 8 hours")
	var summary: String = transition.get_summary_text()
	var pressure_after: float = float(atmosphere.call("get_compartment_status", &"quarters")["pressure_kpa"])
	var battery_after: float = float(power.call("get_status")["battery_fraction"])
	_check(summary.contains("SLEPT 8 HOURS"), "scene sleep shows the shift duration")
	_check(pressure_after < pressure_before, "controlled quarters leak changes pressure overnight")
	_check(summary.contains("QUARTERS PRESSURE  %.1f TO %.1f KPA" % [pressure_before, pressure_after]), "watch report uses measured pre/post pressure")
	_check(summary.contains("BATTERY  %.0f%% TO %.0f%%" % [battery_before * 100.0, battery_after * 100.0]), "watch report uses measured pre/post battery charge")
	_check(summary.contains("CHECK STATUS PANEL / MAINTENANCE BOARD"), "watch report sends operator to physical readouts")
	_check(not summary.contains("FAULT") and not summary.contains("ALERT") and not summary.contains("ALL CLEAR"), "watch report makes no unverified diagnosis")

	var audio_director: Node = root.get_node_or_null("AudioDirector")
	_check(audio_director != null, "audio director autoload present")
	if audio_director != null:
		var state: Dictionary = audio_director.call("get_debug_state")
		_check(bool(state["scrubber_audible"]), "audio follows the live scrubber state")

	main.free()
	_finish()


func _test_world_wiring(main: Node, atmosphere: Node) -> void:
	var missing: PackedStringArray = PackedStringArray()
	var zones: Node = main.get_node("WorldLayout/Zones")
	for zone: Node in zones.get_children():
		var compartment_id: StringName = zone.get(&"compartment_id")
		if bool(atmosphere.call("has_compartment", compartment_id)):
			zone.call("push_occupancy")
		else:
			missing.append("zone:" + String(compartment_id))
	var door_count: int = 0
	for prop: Node in main.get_node("WorldLayout/Props").get_children():
		if prop.get(&"compartment_a") == null:
			continue
		door_count += 1
		for key: StringName in [&"compartment_a", &"compartment_b"]:
			var id: StringName = prop.get(key)
			if id == &"":
				continue
			if not bool(atmosphere.call("has_compartment", id)):
				missing.append("door:" + String(id))
	var link_count: int = 0
	for link: Node in main.get_node("WorldLayout/Links").get_children():
		link_count += 1
		for key: StringName in [&"compartment_a", &"compartment_b"]:
			var id: StringName = link.get(key)
			if not bool(atmosphere.call("has_compartment", id)):
				missing.append("link:" + String(id))
	_check(door_count == 10, "all ten doors are wired")
	_check(link_count == 9, "all nine compartment links are wired")
	_check(missing.is_empty(), "every zone, door and link maps to a registered compartment (%s)" % ", ".join(missing))


func _test_space_backdrop(main: Node) -> void:
	var environment_node: WorldEnvironment = main.get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	var environment: Environment = environment_node.environment if environment_node != null else null
	_check(environment != null and environment.background_mode == Environment.BG_SKY, "environment renders a space sky")
	_check(environment != null and environment.sky != null and environment.sky.sky_material is ShaderMaterial, "sky uses the starfield shader")
	var star_light: DirectionalLight3D = main.get_node_or_null(^"StarLight") as DirectionalLight3D
	_check(star_light != null and star_light.light_energy > 0.0, "star light illuminates the exterior")


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_scene_loop")
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
