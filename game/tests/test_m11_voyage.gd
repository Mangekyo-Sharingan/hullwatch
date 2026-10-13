## Live M11 loop: planet and star arrivals update simulation, visuals, caches and saves.
extends SceneTree

var _failures: int = 0
var _main: Node
var _planet_ration_count: int = 0
var _star_ration_count: int = 0
var _settings: Node
var _previous_planet_frequency: float = 1.0


func _initialize() -> void:
	await process_frame
	_settings = root.get_node_or_null(^"GameSettings")
	if _settings != null:
		_previous_planet_frequency = float(_settings.call(&"get_value", &"planet_frequency"))
		_settings.call(&"set_value", &"planet_frequency", 0.0)
	_run()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	_main = packed.instantiate()
	root.add_child(_main)
	await process_frame
	var nav: Node = _get_system(&"nav_system")
	var sector: Node = _get_system(&"sector_system")
	var cargo: Node = _get_system(&"cargo_system")
	var stores: Node = _get_system(&"stores_system")
	_check(nav != null, "live scene has NavSystem")
	_check(sector != null, "live scene has SectorSystem")
	_check(cargo != null, "live scene has CargoSystem")
	_check(stores != null, "live scene has Stores")
	if nav == null or sector == null or cargo == null or stores == null:
		_finish()
		return
	var destinations: Array = nav.call("get_destinations")
	_check(destinations.size() == 2, "star chart has planet and star destinations")
	var console: Node = _main.find_child("NavConsole", true, false)
	_check(console is NavConsole, "generated cockpit contains the star chart console")
	_check(StringName(nav.get_status()["current_destination_id"]) == &"", "voyage begins in the drift corridor")
	_test_ion_drive_state(nav)
	_test_planet_arrival(nav, sector, cargo, stores)
	_test_star_arrival_and_round_trip(nav, sector, cargo, stores)
	if is_instance_valid(_main):
		root.remove_child(_main)
		_main.free()
	_finish()


func _test_planet_arrival(nav: Node, sector: Node, cargo: Node, stores: Node) -> void:
	var clock: Node = root.get_node_or_null(^"SimClock")
	var clock_before: float = float(clock.call("get_total_hours")) if clock != null else 0.0
	var starting_rations: int = int(stores.call("get_count", &"food_ration"))
	_check(bool(nav.call("plot_course", &"arden_ii")), "planet: course plots")
	_test_ion_plumes(false, "course plotted")
	_check(bool(nav.call("begin_transit")), "planet: transit starts")
	_test_ion_plumes(true, "transit starts")
	var status_panel: Node = _main.get_node_or_null("WorldLayout/Props/StatusPanel")
	var underway: String = "\n".join(status_panel.call("build_readout")) if status_panel != null else ""
	_check(underway.contains("ION DRIVE  2/2 CASSETTES FUNCTIONAL") and underway.contains("PORT  FIRING") and underway.contains("STARBOARD  FIRING") and underway.contains("XENON"), "status panel reports both cassettes firing and xenon reserve")
	if clock != null:
		clock.call("fast_forward", 48.0)
		_check(is_equal_approx(float(clock.call("get_total_hours")) - clock_before, 49.0), "planet: plotting and transit advance shared simulation time")
	else:
		nav.call("sim_tick", 48.0)
	var status: Dictionary = nav.call("get_status")
	_check(not bool(status["transit_active"]), "planet: autopilot arrives after two days")
	_test_ion_plumes(false, "planet arrival")
	_check(StringName(status["current_destination_id"]) == &"arden_ii", "planet: destination becomes current")
	_check(is_equal_approx(float(status["fuel_mass_kg"]), 1015.0), "planet: plotting and transit fuel costs are applied")
	_check(int(sector.get("field_seed")) == 73019, "planet: sector is reseeded")
	_check(is_equal_approx(float(sector.call("get_drift_distance")), 0.0), "planet: local drift resets on arrival")
	_check(is_equal_approx(float(cargo.call("get_units", &"ice")), 4.0), "planet: ice cache is transferred")
	var arden: VoyageDestination = nav.call("get_destination", &"arden_ii")
	_planet_ration_count = int(stores.call("get_count", &"food_ration"))
	_check(_planet_ration_count == starting_rations - arden.transit_days + int(arden.arrival_stores.get(&"food_ration", 0)), "planet: finite ration cache offsets transit use")
	_check(int(stores.call("get_count", &"filter_co2")) == 3, "planet: filter cache is transferred")
	var sky: WorldEnvironment = _main.get_node("WorldEnvironment")
	var sky_material: ShaderMaterial = sky.environment.sky.sky_material as ShaderMaterial
	_check(sky_material.get_shader_parameter(&"planet_color") == arden.planet_color, "planet: destination palette reaches the sky")
	var window_pane: MeshInstance3D = _main.find_child("DressingWindowPane", true, false) as MeshInstance3D
	_check(window_pane != null and window_pane.material_override is StandardMaterial3D, "planet: cockpit glass shows the destination sky")
	status_panel = _main.get_node_or_null("WorldLayout/Props/StatusPanel")
	var arrived: String = "\n".join(status_panel.call("build_readout")) if status_panel != null else ""
	_check(arrived.contains("STANDBY") and not arrived.contains("FIRING") and arrived.contains("XENON"), "status panel reports the drive on standby after arrival")
	var overlay: Node = _main.get_node("UI/LegCompleteOverlay")
	_check(bool(overlay.call("is_visible_overlay")), "planet: quiet arrival overlay appears")
	_check(String(overlay.call("get_overlay_text")).contains("ARDEN II"), "planet: arrival overlay names the destination")
	var overlay_text: Control = overlay.get_node("LegText") as Control
	_check(overlay_text.visible, "planet: arrival report text is visible")
	overlay.call("dismiss")
	_check(not overlay_text.visible, "planet: dismissing the report clears its text")


func _test_star_arrival_and_round_trip(nav: Node, sector: Node, cargo: Node, stores: Node) -> void:
	var save_manager: Node = root.get_node_or_null(^"SaveManager")
	var saved_at_planet: Dictionary = save_manager.call("save_to_dict") if save_manager != null else {}
	_check(int(saved_at_planet.get("save_version", 0)) == 7, "save: new voyage data writes save version 7")
	_check(bool(nav.call("plot_course", &"kestrel_system")), "star: course plots from planet")
	_check(bool(nav.call("begin_transit")), "star: longer transit starts")
	_test_ion_plumes(true, "star transit starts")
	var clock: Node = root.get_node_or_null(^"SimClock")
	var star_transit_start: float = float(clock.call("get_total_hours")) if clock != null else 0.0
	if clock != null:
		clock.call("fast_forward", 96.0)
	else:
		nav.call("sim_tick", 96.0)
	var status: Dictionary = nav.call("get_status")
	_check(not bool(status["transit_active"]), "star: autopilot arrives after four days")
	_test_ion_plumes(false, "star arrival")
	_check(StringName(status["current_destination_id"]) == &"kestrel_system", "star: current destination updates")
	_check(int(sector.get("field_seed")) == 158407, "star: field uses its own sector seed")
	_check(is_equal_approx(float(cargo.call("get_units", &"metal")), 3.0), "star: metal cache is transferred")
	_check(int(stores.call("get_count", &"gasket")) == 2, "star: spares cache is transferred")
	var kestrel: VoyageDestination = nav.call("get_destination", &"kestrel_system")
	_star_ration_count = int(stores.call("get_count", &"food_ration"))
	_check(_star_ration_count == _planet_ration_count - kestrel.transit_days + int(kestrel.arrival_stores.get(&"food_ration", 0)), "star: cache offsets the live transit ration use")
	if clock != null:
		_check(is_equal_approx(float(clock.call("get_total_hours")) - star_transit_start, 96.0), "star: life support and stores continue through transit")
	var star_material: ShaderMaterial = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment.sky.sky_material as ShaderMaterial
	_check(star_material.get_shader_parameter(&"sun_color") == kestrel.sun_color, "star: destination star palette reaches the sky")
	var window_pane: MeshInstance3D = _main.find_child("DressingWindowPane", true, false) as MeshInstance3D
	_check(window_pane != null and window_pane.material_override is StandardMaterial3D, "star: cockpit glass shows the updated destination sky")
	var saved_at_star: Dictionary = save_manager.call("save_to_dict") if save_manager != null else {}
	_check(bool(nav.call("plot_course", &"arden_ii")), "return: route can be plotted")
	_check(bool(nav.call("begin_transit")), "return: transit can be resumed")
	nav.call("sim_tick", 24.0)
	var saved_midflight: Dictionary = save_manager.call("save_to_dict") if save_manager != null else {}
	nav.call("sim_tick", 48.0)
	_check(StringName(nav.get_status()["current_destination_id"]) == &"arden_ii", "return: prior destination can be revisited")
	_check(int(stores.call("get_count", &"food_ration")) == _star_ration_count, "return: a visited cache does not replenish twice")
	if save_manager != null:
		_check(bool(save_manager.call("load_from_dict", saved_midflight)), "save: active return transit loads")
		status = nav.call("get_status")
		_check(bool(status["transit_active"]), "save: transit resumes in flight")
		_test_ion_plumes(true, "midflight save restored")
		_check(is_equal_approx(float(status["transit_elapsed_hours"]), 24.0), "save: midflight progress is retained")
		_check(int(sector.get("field_seed")) == 158407, "save: sector restores to the last destination")
		_check(star_material.get_shader_parameter(&"sun_color") == kestrel.sun_color, "save: sky restores to the saved destination")
		_check(bool(save_manager.call("load_from_dict", saved_at_star)), "save: star arrival round trips")
		_check(StringName(nav.get_status()["current_destination_id"]) == &"kestrel_system", "save: current destination round trips")
		_test_ion_plumes(false, "arrival save restored")
		_check(is_equal_approx(float(cargo.call("get_units", &"metal")), 3.0), "save: destination cargo round trips")
		_check(bool(save_manager.call("load_from_dict", saved_at_planet)), "save: planet arrival round trips")
		_check(StringName(nav.get_status()["current_destination_id"]) == &"arden_ii", "save: planet position round trips")
	_check(int(stores.call("get_count", &"food_ration")) == _planet_ration_count, "save: cache supplies are not granted again")
	_test_fuel_exhaustion_stops_the_wake(nav)


func _get_system(group_name: StringName) -> Node:
	return get_first_node_in_group(group_name)


func _test_ion_drive_state(nav: Node) -> void:
	var port: Node = _main.find_child("IonDrivePort", true, false)
	var starboard: Node = _main.find_child("IonDriveStarboard", true, false)
	_check(port is IonDriveFx and starboard is IonDriveFx and nav != null, "live ship has both ion-drive cassettes")
	_test_ion_plumes(false, "initial idle")


func _test_ion_plumes(expected_visible: bool, phase: String) -> void:
	for drive_name: String in ["IonDrivePort", "IonDriveStarboard"]:
		var drive: Node = _main.find_child(drive_name, true, false)
		var plume: MeshInstance3D = drive.find_child("IonPlume", true, false) as MeshInstance3D if drive != null else null
		_check(plume != null and plume.visible == expected_visible, "%s wake %s" % [drive_name, phase])


func _test_fuel_exhaustion_stops_the_wake(nav: Node) -> void:
	_check(bool(nav.call("plot_course", &"kestrel_system")), "fuel exhaustion: a route can be plotted")
	_check(bool(nav.call("begin_transit")), "fuel exhaustion: transit begins")
	for drive_name: String in ["IonDrivePort", "IonDriveStarboard"]:
		var drive: Node = _main.find_child(drive_name, true, false)
		var plume: MeshInstance3D = drive.find_child("IonPlume", true, false) as MeshInstance3D if drive != null else null
		_check(plume != null and plume.visible, "%s wake lights before exhaustion" % drive_name)
	nav.set("fuel_mass_kg", 0.01)
	nav.call("sim_tick", 24.0)
	_check(not bool(nav.get_status()["transit_active"]), "fuel exhaustion: the burn halts")
	_test_ion_plumes(false, "fuel exhausted")


func _finish() -> void:
	if _settings != null:
		_settings.call(&"set_value", &"planet_frequency", _previous_planet_frequency)
	if _failures == 0:
		print("PASS: test_m11_voyage")
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
