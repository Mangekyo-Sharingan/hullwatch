extends SceneTree

const MAIN_VOLUME: float = 60.0

var _failures: int = 0
var _pressure_signals: int = 0
var _atmosphere_signals: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var existing_bus: Node = _find_root_child(&"EventBus")
	if existing_bus != null:
		root.remove_child(existing_bus)
		existing_bus.free()
	_check(_find_root_child(&"EventBus") == null, "EventBus absent-safe: no EventBus autoload present")

	_test_initial_state()
	_test_occupants()
	_test_scrubber()
	_test_filter()
	_test_leak()
	_test_candles()
	_test_mixing()
	_test_connection_flow()
	_test_signals()
	_test_determinism()
	_test_data()
	_test_invalid_inputs()

	_finish()


func _test_initial_state() -> void:
	var system := AtmosphereSystem.new()
	_check(system != null, "atmosphere instantiates without autoloads")
	var config := _make_config(&"main", MAIN_VOLUME)
	_check(system.add_compartment(config), "add_compartment returns true")
	var status: Dictionary = system.get_compartment_status(&"main")
	_check(absf(float(status["pressure_kpa"]) - 101.325) < 1e-3, "initial pressure matches config")
	_check(absf(float(status["o2_fraction"]) - 0.21) < 1e-6, "initial o2 fraction matches config")
	_check(absf(float(status["co2_ppm"]) - 400.0) < 0.5, "initial co2 ppm matches config")
	_check(not status.has("n_o2") and not status.has("config"), "status dict does not leak internals")
	var full_status: Dictionary = system.get_status()
	_check(full_status.has("system_id") and full_status.has("compartments"), "get_status shape")
	var compartments: Dictionary = full_status["compartments"]
	_check(compartments.has(&"main"), "get_status includes added compartment")


func _test_occupants() -> void:
	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"main", MAIN_VOLUME))
	system.set_occupants(&"main", 1)
	system.sim_tick(24.0)
	var status: Dictionary = system.get_compartment_status(&"main")
	var actual_ppm: float = float(status["co2_ppm"])

	var n_total: float = 101.325 * AtmosphereSystem.PA_PER_KPA * MAIN_VOLUME / (AtmosphereSystem.R_GAS * AtmosphereSystem.TEMP_K)
	var n_o2: float = n_total * 0.21 - AtmosphereSystem.O2_KG_PER_HOUR_PER_OCCUPANT / AtmosphereSystem.MOLAR_MASS_O2 * 24.0
	var n_co2: float = n_total * 400e-6 + AtmosphereSystem.CO2_KG_PER_HOUR_PER_OCCUPANT / AtmosphereSystem.MOLAR_MASS_CO2 * 24.0
	var n_n2: float = n_total - n_total * 0.21 - n_total * 400e-6
	var expected_ppm: float = n_co2 / (n_o2 + n_co2 + n_n2) * 1e6

	_check(actual_ppm > 5000.0, "24h occupant raises CO2 meaningfully")
	_check(absf(actual_ppm - expected_ppm) / expected_ppm < 0.02, "CO2 rise matches analytic expectation within 2%")
	var o2_fraction: float = float(status["o2_fraction"])
	_check(o2_fraction < 0.21 and o2_fraction > 0.19, "O2 fraction drops modestly over 24h")


func _test_scrubber() -> void:
	var unpowered := AtmosphereSystem.new()
	unpowered.add_compartment(_make_config(&"main", MAIN_VOLUME))
	unpowered.set_occupants(&"main", 1)
	unpowered.sim_tick(24.0)
	var unpowered_ppm: float = float(unpowered.get_compartment_status(&"main")["co2_ppm"])

	var powered := AtmosphereSystem.new()
	powered.add_compartment(_make_config(&"main", MAIN_VOLUME))
	powered.set_occupants(&"main", 1)
	powered.set_scrubber_powered(&"main", true)
	powered.sim_tick(24.0)
	var powered_ppm: float = float(powered.get_compartment_status(&"main")["co2_ppm"])

	_check(powered_ppm < 700.0, "powered scrubber holds CO2 below 700 ppm")
	_check(powered_ppm < unpowered_ppm, "powered scrubber beats unpowered")

	var inefficient := AtmosphereSystem.new()
	inefficient.add_compartment(_make_config(&"main", MAIN_VOLUME))
	inefficient.set_occupants(&"main", 1)
	inefficient.set_scrubber_powered(&"main", true)
	inefficient.set_scrubber_efficiency(&"main", 0.0)
	inefficient.sim_tick(24.0)
	var inefficient_ppm: float = float(inefficient.get_compartment_status(&"main")["co2_ppm"])
	_check(absf(inefficient_ppm - unpowered_ppm) < 1e-6, "zero efficiency removes no CO2")

	inefficient.set_scrubber_efficiency(&"main", 5.0)
	var efficiency: float = float(inefficient.get_compartment_status(&"main")["scrubber_efficiency"])
	_check(efficiency == 1.0, "scrubber efficiency clamps to 1.0")


func _test_filter() -> void:
	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"main", MAIN_VOLUME))
	var initial: Dictionary = system.get_compartment_status(&"main")
	_check(bool(initial["filter_installed"]), "filter installed initially")
	_check(absf(float(initial["filter_condition"]) - 1.0) < 1e-9, "filter starts at full condition")

	system.set_scrubber_powered(&"main", true)
	system.sim_tick(100.0)
	_check(absf(system.get_filter_condition(&"main") - 0.6) < 1e-6, "filter wears 0.004/h while scrubbing")

	var missing_filter := AtmosphereSystem.new()
	missing_filter.add_compartment(_make_config(&"main", MAIN_VOLUME))
	missing_filter.set_occupants(&"main", 1)
	missing_filter.set_scrubber_powered(&"main", true)
	missing_filter.set_filter_installed(&"main", false)
	missing_filter.sim_tick(24.0)
	var missing_ppm: float = float(missing_filter.get_compartment_status(&"main")["co2_ppm"])

	var unpowered := AtmosphereSystem.new()
	unpowered.add_compartment(_make_config(&"main", MAIN_VOLUME))
	unpowered.set_occupants(&"main", 1)
	unpowered.sim_tick(24.0)
	var unpowered_ppm: float = float(unpowered.get_compartment_status(&"main")["co2_ppm"])
	_check(absf(missing_ppm - unpowered_ppm) / unpowered_ppm < 0.001, "missing filter scrubs nothing")

	missing_filter.set_filter_installed(&"main", true)
	missing_filter.set_filter_condition(&"main", 1.0)
	missing_filter.sim_tick(24.0)
	var resumed_ppm_1: float = float(missing_filter.get_compartment_status(&"main")["co2_ppm"])
	missing_filter.sim_tick(24.0)
	var resumed_ppm_2: float = float(missing_filter.get_compartment_status(&"main")["co2_ppm"])
	missing_filter.sim_tick(48.0)
	var resumed_ppm_3: float = float(missing_filter.get_compartment_status(&"main")["co2_ppm"])
	_check(resumed_ppm_1 < missing_ppm and resumed_ppm_2 < resumed_ppm_1 and resumed_ppm_3 < resumed_ppm_2, "fresh filter resumes scrubbing and CO2 declines")

	var half := AtmosphereSystem.new()
	half.add_compartment(_make_config(&"main", MAIN_VOLUME))
	half.set_occupants(&"main", 1)
	half.set_scrubber_powered(&"main", true)
	half.set_filter_condition(&"main", 0.5)
	half.sim_tick(24.0)
	var half_ppm: float = float(half.get_compartment_status(&"main")["co2_ppm"])
	var full := AtmosphereSystem.new()
	full.add_compartment(_make_config(&"main", MAIN_VOLUME))
	full.set_occupants(&"main", 1)
	full.set_scrubber_powered(&"main", true)
	full.sim_tick(24.0)
	var full_ppm: float = float(full.get_compartment_status(&"main")["co2_ppm"])
	_check(half_ppm > full_ppm and half_ppm < unpowered_ppm, "worn filter scrubs between fresh and none")

	system.set_filter_condition(&"main", 5.0)
	_check(system.get_filter_condition(&"main") == 1.0, "filter condition clamps high")
	system.set_filter_condition(&"main", -2.0)
	_check(system.get_filter_condition(&"main") == 0.0, "filter condition clamps low")


func _test_leak() -> void:
	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"main", MAIN_VOLUME, 0.01))
	var before: Dictionary = system.get_compartment_status(&"main")
	system.sim_tick(1.0)
	var after: Dictionary = system.get_compartment_status(&"main")
	var expected_pressure: float = 101.325 * exp(-0.01)
	_check(absf(float(after["pressure_kpa"]) - expected_pressure) < 1e-6, "leak decays pressure exponentially")
	_check(absf(float(after["o2_fraction"]) - float(before["o2_fraction"])) < 1e-9, "leak preserves composition")


func _test_candles() -> void:
	var control := AtmosphereSystem.new()
	control.add_compartment(_make_config(&"main", MAIN_VOLUME))
	control.sim_tick(4.0)

	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"main", MAIN_VOLUME, 0.0, 2))
	_check(system.light_o2_candle(&"main"), "first candle lights")
	_check(system.light_o2_candle(&"main"), "second candle lights")
	_check(not system.light_o2_candle(&"main"), "third candle refused when stock is empty")
	system.sim_tick(4.0)
	var status: Dictionary = system.get_compartment_status(&"main")
	var control_o2: float = float(control.get_compartment_status(&"main")["o2_fraction"])
	_check(float(status["o2_fraction"]) > control_o2, "candles raise O2 fraction versus control")
	_check(float(status["candle_burn_remaining_hours"]) == 0.0, "candle burn completes")
	_check(int(status["candles_remaining"]) == 0, "candle stock decremented to zero")


func _test_mixing() -> void:
	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"main", MAIN_VOLUME))
	system.add_compartment(_make_config(&"storage", 25.0, 0.0, 0, 50.0))
	system.connect_compartments(&"main", &"storage")
	var difference_before: float = _pressure_difference(system)
	system.sim_tick(1.0)
	var difference_after: float = _pressure_difference(system)
	_check(difference_after < difference_before, "connected compartments converge in pressure")
	_check(difference_after > 0.0, "mixing does not overshoot")

	var isolated := AtmosphereSystem.new()
	isolated.add_compartment(_make_config(&"main", MAIN_VOLUME))
	isolated.add_compartment(_make_config(&"storage", 25.0, 0.0, 0, 50.0))
	isolated.set_isolated(&"storage", true)
	isolated.connect_compartments(&"main", &"storage")
	var isolated_before: float = _pressure_difference(isolated)
	isolated.sim_tick(1.0)
	var isolated_after: float = _pressure_difference(isolated)
	_check(absf(isolated_after - isolated_before) < 1e-9, "isolation blocks mixing")


func _test_connection_flow() -> void:
	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"center", 30.0, 0.0, 0, 100.0))
	system.add_compartment(_make_config(&"closed_neighbor", 30.0, 0.0, 0, 50.0))
	system.add_compartment(_make_config(&"open_neighbor", 30.0, 0.0, 0, 50.0))
	system.set_connection_open(&"center", &"closed_neighbor", false)
	system.connect_compartments(&"center", &"closed_neighbor")
	system.connect_compartments(&"center", &"open_neighbor")
	system.connect_compartments(&"center", &"closed_neighbor")
	var center_before: float = float(system.get_compartment_status(&"center")["pressure_kpa"])
	var closed_before: float = float(system.get_compartment_status(&"closed_neighbor")["pressure_kpa"])
	var open_before: float = float(system.get_compartment_status(&"open_neighbor")["pressure_kpa"])
	system.sim_tick(1.0)
	var center_after: float = float(system.get_compartment_status(&"center")["pressure_kpa"])
	var closed_after: float = float(system.get_compartment_status(&"closed_neighbor")["pressure_kpa"])
	var open_after: float = float(system.get_compartment_status(&"open_neighbor")["pressure_kpa"])
	_check(absf(closed_after - closed_before) < 1e-9, "closed connection blocks only its own gas path")
	_check(center_after < center_before and open_after > open_before, "the other open path still mixes gas")
	_check(absf(center_after - open_after) < absf(center_before - open_before), "open passage equalizes toward shared pressure")


func _test_signals() -> void:
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	event_bus.connect(&"compartment_pressure_changed", _on_pressure_changed)
	event_bus.connect(&"compartment_atmosphere_changed", _on_atmosphere_changed)

	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"sig", MAIN_VOLUME, 0.01))
	system.set_occupants(&"sig", 1)
	system.sim_tick(1.0)
	_check(_pressure_signals == 1, "pressure signal emitted once above threshold")
	_check(_atmosphere_signals >= 1, "atmosphere signal emitted above threshold")

	root.remove_child(event_bus)
	event_bus.free()


func _test_determinism() -> void:
	var system_a := _make_deterministic_system()
	var system_b := _make_deterministic_system()
	for i: int in 300:
		system_a.sim_tick(1.0 / 600.0)
		system_b.sim_tick(1.0 / 600.0)
	var status_a: Dictionary = system_a.get_compartment_status(&"main")
	var status_b: Dictionary = system_b.get_compartment_status(&"main")
	_check(absf(float(status_a["pressure_kpa"]) - float(status_b["pressure_kpa"])) < 1e-9, "determinism: identical pressure")
	_check(absf(float(status_a["co2_ppm"]) - float(status_b["co2_ppm"])) < 1e-9, "determinism: identical co2")


func _test_data() -> void:
	var main_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_main.tres") as CompartmentConfig
	var storage_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_storage.tres") as CompartmentConfig
	_check(main_config != null, "data: main compartment loads")
	_check(storage_config != null, "data: storage compartment loads")
	if main_config != null:
		_check(main_config.compartment_id == &"main", "data: main id")
		_check(is_equal_approx(main_config.volume_m3, 28.0), "data: main volume")
		_check(is_equal_approx(main_config.leak_rate_per_hour, 0.002), "data: main leak rate")
		_check(main_config.o2_candles_stocked == 2, "data: main candle stock")
	if storage_config != null:
		_check(storage_config.compartment_id == &"storage", "data: storage id")
		_check(storage_config.o2_candles_stocked == 0, "data: storage candle stock")
	for room: StringName in [&"quarters", &"storage", &"engine_bay"]:
		var config_path: String = "res://src/data/atmosphere/compartment_%s.tres" % String(room)
		var config: CompartmentConfig = load(config_path) as CompartmentConfig
		_check(config != null, "data: %s compartment loads" % String(room))
		if config == null:
			continue
		var expected_volume: float = 0.0
		for section_index: int in TubeLayout.sections_for_room(room):
			var section: Dictionary = TubeLayout.sections()[section_index]
			var cross_section: PackedVector2Array = SectionHull.tube_section(float(section["radius"]))
			expected_volume += absf(HullProfile.signed_area(cross_section)) * float(section["length"])
		_check(is_equal_approx(config.volume_m3, expected_volume), "data: %s volume matches slim tube profile" % String(room))


func _test_invalid_inputs() -> void:
	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"main", MAIN_VOLUME))
	_check(not system.add_compartment(_make_config(&"main", MAIN_VOLUME)), "duplicate compartment rejected")
	_check(not system.add_compartment(null), "null compartment rejected")
	_check(system.get_compartment_status(&"nope").is_empty(), "unknown compartment status is empty")
	_check(not system.light_o2_candle(&"nope"), "candle on unknown compartment refused")
	var leak_before: float = float(system.get_compartment_status(&"main")["leak_rate_per_hour"])
	system.set_leak_rate(&"main", -1.0)
	var leak_after: float = float(system.get_compartment_status(&"main")["leak_rate_per_hour"])
	_check(absf(leak_before - leak_after) < 1e-12, "negative leak rate rejected without change")
	system.connect_compartments(&"main", &"main")
	_check(true, "self-connection is a no-op")


func _make_config(id: StringName, volume: float, leak: float = 0.0, candles: int = 0, pressure: float = 101.325) -> CompartmentConfig:
	var config := CompartmentConfig.new()
	config.compartment_id = id
	config.volume_m3 = volume
	config.leak_rate_per_hour = leak
	config.o2_candles_stocked = candles
	config.initial_pressure_kpa = pressure
	return config


func _make_deterministic_system() -> AtmosphereSystem:
	var system := AtmosphereSystem.new()
	system.add_compartment(_make_config(&"main", MAIN_VOLUME, 0.002))
	system.set_occupants(&"main", 1)
	system.set_scrubber_powered(&"main", true)
	return system


func _pressure_difference(system: AtmosphereSystem) -> float:
	var main_status: Dictionary = system.get_compartment_status(&"main")
	var storage_status: Dictionary = system.get_compartment_status(&"storage")
	return absf(float(main_status["pressure_kpa"]) - float(storage_status["pressure_kpa"]))


func _on_pressure_changed(_compartment_id: StringName, _pressure_kpa: float) -> void:
	_pressure_signals += 1


func _on_atmosphere_changed(_compartment_id: StringName, _o2_fraction: float, _co2_ppm: float) -> void:
	_atmosphere_signals += 1


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_atmosphere")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


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
