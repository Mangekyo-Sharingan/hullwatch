## Headless checks for wear-driven component failures in the thermal and hull systems.
extends SceneTree

var _failures: int = 0
var _failed_events: Array[Dictionary] = []
var _repaired_events: Array[Dictionary] = []
var _condition_events: Array[Dictionary] = []
var _spawned: Array[Node] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()

	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	event_bus.connect(&"component_failed", _on_component_failed)
	event_bus.connect(&"component_repaired", _on_component_repaired)
	event_bus.connect(&"component_condition_changed", _on_component_condition_changed)

	_test_wear_resources()
	_test_thermal_heater_open()
	_test_thermal_sensor_drift()
	_test_hull_plating_fatigue()
	_test_hull_seam_split()
	_test_condition_crossings()
	_test_save_load_round_trip()
	_test_water_pump_effects()

	_despawn_all()
	_finish()


func _test_wear_resources() -> void:
	var expectations: Dictionary = {
		"res://src/data/wear/heater_main.tres": [&"heater_main", &"heater_open", &"sensor_drift", 0.00015, 2500.0, 3000.0],
		"res://src/data/wear/hull_plating_main.tres": [&"hull_plating_main", &"plating_fatigue", &"seam_split", 0.00005, 5000.0, 7000.0],
	}
	for path: String in expectations:
		var expected: Array = expectations[path]
		var component: WearComponent = load(path) as WearComponent
		_check(component != null, "data: %s loads as WearComponent" % path)
		if component == null:
			continue
		_check(component.component_id == StringName(expected[0]), "data: %s component_id" % path)
		_check(is_equal_approx(component.wear_rate_per_hour, float(expected[3])), "data: %s wear rate" % path)
		var mode_ids: PackedStringArray = PackedStringArray()
		for mode: FailureMode in component.failure_modes:
			if mode != null:
				mode_ids.append(String(mode.id))
		_check(mode_ids == PackedStringArray([String(expected[1]), String(expected[2])]), "data: %s failure modes" % path)
		if component.failure_modes.size() == 2:
			_check(is_equal_approx(component.failure_modes[0].base_mtbf_hours, float(expected[4])), "data: %s first MTBF" % path)
			_check(is_equal_approx(component.failure_modes[1].base_mtbf_hours, float(expected[5])), "data: %s second MTBF" % path)
			for mode: FailureMode in component.failure_modes:
				if mode != null and String(mode.id) in ["heater_open", "sensor_drift"]:
					_check(is_equal_approx(float(mode.environmental_factors.get("load", 0.0)), 2.0), "data: %s load factor" % path)


func _test_thermal_heater_open() -> void:
	_failed_events.clear()
	_repaired_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"heater_open", 1.0e9), _make_mode(&"sensor_drift", 1.0e9)]
	var control: ThermalSystem = _spawn_thermal(5.0, modes, 101, 0.0001)
	var broken: ThermalSystem = _spawn_thermal(5.0, modes, 101, 0.0001)
	_check(broken.force_failure(&"heater_main", &"heater_open"), "heater_open: force_failure accepted")
	_check(_failed_events.size() == 1, "heater_open: typed component_failed emitted once")
	if _failed_events.size() == 1:
		_check(_failed_events[0]["failure_mode_id"] == &"heater_open", "heater_open: component_failed carries the mode id")
	_check(bool(broken.get_wear_status()["heater_main"]["failed"]), "heater_open: wear status marks the component failed")
	_check(not broken.force_failure(&"heater_main", &"heater_open"), "heater_open: force_failure refuses an already failed component")
	_check(not broken.force_failure(&"missing", &"heater_open"), "heater_open: force_failure rejects unknown component")
	for tick: int in 40:
		control.sim_tick(0.1)
		broken.sim_tick(0.1)
	var control_temperature: float = control.get_temperature(&"main")
	var broken_temperature: float = broken.get_temperature(&"main")
	_check(control_temperature > 15.0, "heater_open: control compartment warms toward the target")
	_check(broken_temperature < 5.0, "heater_open: failed compartment keeps cooling")
	_check(control_temperature - broken_temperature > 10.0, "heater_open: control ends far warmer than the failed compartment")
	_check(broken.repair_component(&"heater_main", 1.0), "heater_open: repair_component accepted")
	_check(_repaired_events.size() == 1, "heater_open: typed component_repaired emitted once")
	_check(not bool(broken.get_wear_status()["heater_main"]["failed"]), "heater_open: repair clears the failed mode")
	for tick: int in 40:
		broken.sim_tick(0.1)
	_check(broken.get_temperature(&"main") > broken_temperature + 5.0, "heater_open: repair restores heating")


func _test_thermal_sensor_drift() -> void:
	_repaired_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"heater_open", 1.0e9), _make_mode(&"sensor_drift", 1.0e9)]
	var control: ThermalSystem = _spawn_thermal(21.0, modes, 202, 0.0001)
	var drifted: ThermalSystem = _spawn_thermal(21.0, modes, 202, 0.0001)
	_check(drifted.force_failure(&"heater_main", &"sensor_drift"), "sensor_drift: force_failure accepted")
	for tick: int in 48:
		control.sim_tick(0.25)
		drifted.sim_tick(0.25)
	var control_temperature: float = control.get_temperature(&"main")
	var drifted_temperature: float = drifted.get_temperature(&"main")
	_check(absf(control_temperature - 21.0) <= 2.0, "sensor_drift: control holds the configured target")
	_check(drifted_temperature < control_temperature - 4.0, "sensor_drift: cabin settles below the control")
	_check(absf((control_temperature - drifted_temperature) - 8.0) <= 2.5, "sensor_drift: held gap is roughly the 8 C drift")
	_check(drifted.repair_component(&"heater_main", 1.0), "sensor_drift: repair_component accepted")
	for tick: int in 48:
		drifted.sim_tick(0.25)
	_check(absf(drifted.get_temperature(&"main") - control_temperature) <= 2.0, "sensor_drift: repair restores the thermostat target")


func _test_hull_plating_fatigue() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"plating_fatigue", 1.0e9), _make_mode(&"seam_split", 1.0e9)]
	var control_config: CompartmentConfig = _make_hull_config(&"main")
	control_config.puncture_mtbf_hours = 4.0
	var failed_config: CompartmentConfig = _make_hull_config(&"main")
	failed_config.puncture_mtbf_hours = 4.0
	var control: HullSystem = _spawn_hull(_defs(control_config), modes, 505, 0.0001)
	var failed: HullSystem = _spawn_hull(_defs(failed_config), modes, 505, 0.0001)
	_check(failed.force_failure(&"hull_plating_main", &"plating_fatigue"), "plating_fatigue: force_failure accepted")
	_check(is_equal_approx(float(failed.get_status()["puncture_rate_multiplier"]), 0.5), "plating_fatigue: status exposes the halved MTBF multiplier")
	for tick: int in 500:
		control.sim_tick(1.0)
		failed.sim_tick(1.0)
	var control_count: int = control.get_puncture_count(&"main")
	var failed_count: int = failed.get_puncture_count(&"main")
	_check(control_count > 0, "plating_fatigue: control seeds random punctures under the test MTBF")
	_check(failed_count > control_count, "plating_fatigue: doubled rate yields more punctures over equal simulated hours")
	_check(failed.get_total_leak_rate(&"main") > control.get_total_leak_rate(&"main"), "plating_fatigue: failed hull leaks faster")
	_check(failed.repair_component(&"hull_plating_main", 1.0), "plating_fatigue: repair_component accepted")
	_check(is_equal_approx(float(failed.get_status()["puncture_rate_multiplier"]), 1.0), "plating_fatigue: repair restores the rate multiplier")


func _test_hull_seam_split() -> void:
	_failed_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"plating_fatigue", 1.0e9), _make_mode(&"seam_split", 1.0e9)]
	var configs: Array[CompartmentConfig] = [_make_hull_config(&"main"), _make_hull_config(&"storage")]
	var hull: HullSystem = _spawn_hull(configs, modes, 606, 0.0001)
	_check(hull.get_puncture_count(&"main") == 0 and hull.get_puncture_count(&"storage") == 0, "seam_split: hull starts intact")
	_check(hull.force_failure(&"hull_plating_main", &"seam_split"), "seam_split: force_failure accepted")
	_check(hull.get_puncture_count(&"main") == 1, "seam_split: guarded compartment main gains a puncture immediately")
	_check(hull.get_puncture_count(&"storage") == 1, "seam_split: guarded compartment storage gains a puncture immediately")
	_check(absf(hull.get_total_leak_rate(&"main") - (0.002 + 1.5 * 0.004)) < 1e-9, "seam_split: puncture severity is 1.5")
	_check(_failed_events.size() == 1, "seam_split: typed component_failed emitted once")
	_check(hull.repair_component(&"hull_plating_main", 1.0), "seam_split: repair_component accepted")
	_check(hull.get_puncture_count(&"main") == 1, "seam_split: repair leaves the physical puncture in place")
	_check(is_equal_approx(float(hull.get_status()["puncture_rate_multiplier"]), 1.0), "seam_split: repair restores the rate multiplier")


func _test_condition_crossings() -> void:
	_condition_events.clear()
	var thermal_modes: Array[FailureMode] = [_make_mode(&"heater_open", 1.0e9)]
	var thermal: ThermalSystem = _spawn_thermal(21.0, thermal_modes, 707, 0.25)
	for tick: int in 5:
		thermal.sim_tick(1.0)
	_check(_condition_events.size() >= 2, "condition: thermal crossing emits typed component_condition_changed")
	if not _condition_events.is_empty():
		_check(String(_condition_events[0]["component_id"]) == "heater_main", "condition: thermal event carries the component id")

	_condition_events.clear()
	var hull_modes: Array[FailureMode] = [_make_mode(&"plating_fatigue", 1.0e9)]
	var hull: HullSystem = _spawn_hull(_defs(_make_hull_config(&"main")), hull_modes, 808, 0.25)
	for tick: int in 5:
		hull.sim_tick(1.0)
	_check(_condition_events.size() >= 2, "condition: hull crossing emits typed component_condition_changed")
	if not _condition_events.is_empty():
		_check(String(_condition_events[0]["component_id"]) == "hull_plating_main", "condition: hull event carries the component id")


func _test_save_load_round_trip() -> void:
	var thermal_modes: Array[FailureMode] = [_make_mode(&"heater_open", 1.0e9), _make_mode(&"sensor_drift", 1.0e9)]
	var thermal: ThermalSystem = _spawn_thermal(5.0, thermal_modes, 909, 0.0002)
	thermal.force_failure(&"heater_main", &"sensor_drift")
	thermal.sim_tick(2.0)
	var thermal_saved: Dictionary = thermal.save_state()
	_check(thermal_saved.has("wear") and thermal_saved.has("failure_restore"), "save: thermal state carries wear fields")
	_check(thermal_saved["wear_rng_state"] is String, "save: thermal wear_rng_state stringified")
	_check(thermal_saved["failure_restore"].has("heater_main"), "save: thermal failure_restore captures the failed component")
	if thermal_saved["failure_restore"].has("heater_main"):
		var restore_entry: Dictionary = thermal_saved["failure_restore"]["heater_main"]
		_check(String(restore_entry["kind"]) == "target_offset_c", "save: thermal restore kind")
		_check(absf(float(restore_entry["value"])) < 1e-9, "save: thermal restore value is the pre-failure offset")
	var thermal_parsed_value: Variant = JSON.parse_string(JSON.stringify(thermal_saved, "\t"))
	_check(thermal_parsed_value is Dictionary, "save: thermal state is JSON-safe")
	if thermal_parsed_value is Dictionary:
		var thermal_restored: ThermalSystem = _spawn_thermal(21.0, thermal_modes, 1111, 0.0002)
		thermal_restored.load_state(thermal_parsed_value)
		_check_wear_matches("save: thermal wear round trip", thermal_restored.get_wear_status(), thermal.get_wear_status())
		for tick: int in 4:
			thermal.sim_tick(0.5)
			thermal_restored.sim_tick(0.5)
		_check(absf(thermal_restored.get_temperature(&"main") - thermal.get_temperature(&"main")) < 1e-6, "save: thermal failed effect reapplied after load")
		_check(thermal_restored.repair_component(&"heater_main", 1.0), "save: thermal repair after load accepted")
		_check(absf(float(thermal_restored.get("_target_offset_c"))) < 1e-9, "save: stored pre-failure offset restores after load")
		_check(thermal_restored.save_state()["failure_restore"].is_empty(), "save: thermal restore entry cleared after repair")

	var hull_modes: Array[FailureMode] = [_make_mode(&"plating_fatigue", 1.0e9), _make_mode(&"seam_split", 1.0e9)]
	var configs: Array[CompartmentConfig] = [_make_hull_config(&"main"), _make_hull_config(&"storage")]
	var hull: HullSystem = _spawn_hull(configs, hull_modes, 1001, 0.0002)
	hull.sim_tick(2.0)
	hull.force_failure(&"hull_plating_main", &"seam_split")
	_check(hull.get_puncture_count(&"main") == 1, "save: seam_split seeds a puncture before save")
	var hull_saved: Dictionary = hull.save_state()
	_check(hull_saved.has("wear") and hull_saved.has("failure_restore"), "save: hull state carries wear fields")
	_check(hull_saved["wear_rng_state"] is String, "save: hull wear_rng_state stringified")
	_check(hull_saved["failure_restore"].has("hull_plating_main"), "save: hull failure_restore captures the failed component")
	if hull_saved["failure_restore"].has("hull_plating_main"):
		var hull_restore_entry: Dictionary = hull_saved["failure_restore"]["hull_plating_main"]
		_check(String(hull_restore_entry["kind"]) == "puncture_rate_multiplier", "save: hull restore kind")
		_check(is_equal_approx(float(hull_restore_entry["value"]), 1.0), "save: hull restore value is the pre-failure multiplier")
	var hull_parsed_value: Variant = JSON.parse_string(JSON.stringify(hull_saved, "\t"))
	_check(hull_parsed_value is Dictionary, "save: hull state is JSON-safe")
	if hull_parsed_value is Dictionary:
		var hull_restored: HullSystem = _spawn_hull(configs, hull_modes, 2222, 0.0002)
		hull_restored.load_state(hull_parsed_value)
		_check_wear_matches("save: hull wear round trip", hull_restored.get_wear_status(), hull.get_wear_status())
		_check(is_equal_approx(float(hull_restored.get_status()["puncture_rate_multiplier"]), 0.5), "save: hull failed effect reapplied after load")
		_check(hull_restored.get_puncture_count(&"main") == 1, "save: reapply does not duplicate seam punctures")
		_check(hull_restored.get_puncture_count(&"storage") == 1, "save: guarded punctures round trip")
		_check(hull_restored.repair_component(&"hull_plating_main", 1.0), "save: hull repair after load accepted")
		_check(is_equal_approx(float(hull_restored.get_status()["puncture_rate_multiplier"]), 1.0), "save: stored pre-failure multiplier restores after load")


func _test_water_pump_effects() -> void:
	_failed_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"pump_impeller_wear", 1.0e9), _make_mode(&"pump_seize", 1.0e9)]
	var pump: WearComponent = WearComponent.new()
	pump.component_id = &"water_pump_main"
	pump.wear_rate_per_hour = 0.00015
	pump.failure_modes = modes
	var components: Array[WearComponent] = [pump]
	var water := WaterSystem.new()
	water.wear_components = components
	_spawn(water)
	water.set_reclaimer_powered(true)
	water.greywater_l = 20.0
	water.sim_tick(1.0)
	var healthy_potable: float = water.potable_l
	_check(healthy_potable > 0.0, "water pump: healthy reclaimer recovers potable")
	_check(water.force_failure(&"water_pump_main", &"pump_impeller_wear"), "water pump: force_failure impeller wear accepted")
	_check(_failed_events.size() == 1, "water pump: typed component_failed emitted once")
	if _failed_events.size() == 1:
		_check(_failed_events[0]["failure_mode_id"] == &"pump_impeller_wear", "water pump: component_failed carries the mode id")
	water.greywater_l = 20.0
	water.potable_l = 0.0
	water.contamination = 0.0
	water.sim_tick(1.0)
	_check(water.potable_l > 0.0, "water pump: worn impeller still moves some water")
	_check(water.potable_l < healthy_potable, "water pump: worn impeller moves less than a healthy pump")
	_check(water.repair_component(&"water_pump_main", 1.0), "water pump: repair accepted")
	_check(absf(float(water.get_status()["capacity_multiplier"]) - 1.0) < 1e-9, "water pump: repair restores the capacity multiplier")
	_check(water.force_failure(&"water_pump_main", &"pump_seize"), "water pump: force_failure seize accepted")
	water.greywater_l = 20.0
	water.potable_l = 0.0
	water.sim_tick(1.0)
	_check(is_equal_approx(water.potable_l, 0.0), "water pump: seized pump moves no water")
	_check(is_equal_approx(water.greywater_l, 20.0), "water pump: seized pump leaves greywater untouched")
	_check(not bool(water.get_status()["reclaimer_active"]), "water pump: seized pump reports inactive")
	_check(water.repair_component(&"water_pump_main", 1.0), "water pump: repair after seize accepted")

	water.force_failure(&"water_pump_main", &"pump_impeller_wear")
	var saved: Dictionary = water.save_state()
	_check(saved.has("wear") and saved.has("failure_restore"), "water pump: save carries wear fields")
	_check(saved["wear_rng_state"] is String, "water pump: wear_rng_state is stringified")
	_check(saved["failure_restore"].has("water_pump_main"), "water pump: failure_restore captures the pump")
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(saved))
	_check(parsed_value is Dictionary, "water pump: save state is JSON-safe")
	if parsed_value is Dictionary:
		var restored_pump: WearComponent = WearComponent.new()
		restored_pump.component_id = &"water_pump_main"
		restored_pump.wear_rate_per_hour = 0.00015
		restored_pump.failure_modes = modes
		var restored_components: Array[WearComponent] = [restored_pump]
		var restored := WaterSystem.new()
		restored.wear_components = restored_components
		_spawn(restored)
		restored.load_state(parsed_value)
		_check(absf(float(restored.get_status()["capacity_multiplier"]) - 0.3) < 1e-9, "water pump: failed effect reapplied after load")
		_check(restored.repair_component(&"water_pump_main", 1.0), "water pump: repair after load accepted")
		_check(absf(float(restored.get_status()["capacity_multiplier"]) - 1.0) < 1e-9, "water pump: pre-failure capacity restores after load")


func _spawn_thermal(initial_temperature_c: float, modes: Array[FailureMode], seed_value: int, wear_rate: float) -> ThermalSystem:
	var component: WearComponent = WearComponent.new()
	component.component_id = &"heater_main"
	component.wear_rate_per_hour = wear_rate
	component.failure_modes = modes
	var components: Array[WearComponent] = [component]
	var config: CompartmentConfig = _make_thermal_config(&"main", initial_temperature_c)
	var defs: Array[CompartmentConfig] = [config]
	var system: ThermalSystem = ThermalSystem.new()
	system.wear_seed = seed_value
	system.compartment_defs = defs
	system.wear_components = components
	_spawn(system)
	return system


func _spawn_hull(configs: Array[CompartmentConfig], modes: Array[FailureMode], seed_value: int, wear_rate: float) -> HullSystem:
	var component: WearComponent = WearComponent.new()
	component.component_id = &"hull_plating_main"
	component.wear_rate_per_hour = wear_rate
	component.failure_modes = modes
	var components: Array[WearComponent] = [component]
	var hull: HullSystem = HullSystem.new()
	hull.wear_seed = seed_value
	hull.compartment_defs = configs
	hull.wear_components = components
	_spawn(hull)
	return hull


func _make_mode(mode_id: StringName, mtbf_hours: float) -> FailureMode:
	var mode: FailureMode = FailureMode.new()
	mode.id = mode_id
	mode.base_mtbf_hours = mtbf_hours
	return mode


func _make_thermal_config(id: StringName, initial_temperature_c: float) -> CompartmentConfig:
	var config: CompartmentConfig = CompartmentConfig.new()
	config.compartment_id = id
	config.volume_m3 = 10.0
	config.initial_temperature_c = initial_temperature_c
	config.thermal_capacity_j_per_k = 90000.0
	config.hull_conductance_w_per_k = 3.0
	config.heater_watts = 400.0
	config.heater_target_c = 21.0
	config.heater_deadband_c = 1.0
	config.occupant_heat_w = 100.0
	config.freeze_threshold_c = 1.0
	return config


func _make_hull_config(id: StringName) -> CompartmentConfig:
	var config: CompartmentConfig = CompartmentConfig.new()
	config.compartment_id = id
	config.volume_m3 = 60.0
	config.leak_rate_per_hour = 0.002
	config.puncture_leak_per_hour = 0.004
	config.puncture_mtbf_hours = 1.0e12
	return config


func _defs(config: CompartmentConfig) -> Array[CompartmentConfig]:
	var defs: Array[CompartmentConfig] = [config]
	return defs


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _check_wear_matches(label: String, actual: Dictionary, expected: Dictionary) -> void:
	_check(actual.size() == expected.size(), label + ": component count")
	for key: Variant in expected:
		_check(actual.has(key), label + ": has " + String(key))
		if not actual.has(key):
			continue
		var actual_status: Dictionary = actual[key]
		var expected_status: Dictionary = expected[key]
		_check(String(actual_status["failed_mode"]) == String(expected_status["failed_mode"]), label + ": failed_mode")
		_check(absf(float(actual_status["condition"]) - float(expected_status["condition"])) < 1e-6, label + ": condition")
		_check(absf(float(actual_status["hours_operated"]) - float(expected_status["hours_operated"])) < 1e-6, label + ": hours_operated")


func _on_component_failed(component_id: StringName, failure_mode_id: StringName) -> void:
	_failed_events.append({"component_id": component_id, "failure_mode_id": failure_mode_id})


func _on_component_repaired(component_id: StringName, repair_quality: float) -> void:
	_repaired_events.append({"component_id": component_id, "repair_quality": repair_quality})


func _on_component_condition_changed(component_id: StringName, condition: float) -> void:
	_condition_events.append({"component_id": component_id, "condition": condition})


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_component_breadth")
		quit(0)
	else:
		print("FAIL: test_component_breadth (%d checks failed)" % _failures)
		quit(1)
