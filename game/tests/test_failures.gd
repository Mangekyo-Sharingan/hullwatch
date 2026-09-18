## Headless checks for wear-driven component failures in power and atmosphere.
extends SceneTree

var _failures: int = 0
var _failed_events: Array[Dictionary] = []
var _repaired_events: Array[Dictionary] = []
var _condition_events: Array[Dictionary] = []


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
	_test_seeded_determinism()
	_test_power_force_failure_effects()
	_test_power_repair_restores()
	_test_battery_failure_effects()
	_test_lighting_ballast_effects()
	_test_atmosphere_failure_effects()
	_test_condition_crossing_events()
	_test_save_load_round_trip()
	_test_empty_wear_is_inert()

	_finish()


func _test_wear_resources() -> void:
	var expectations: Dictionary = {
		"res://src/data/wear/rtg_main.tres": [&"rtg_main", &"rtg_degraded", &"rtg_open_circuit"],
		"res://src/data/wear/battery_main.tres": [&"battery_main", &"cell_fade", &"cell_short"],
		"res://src/data/wear/scrubber_blower_main.tres": [&"scrubber_blower_main", &"bearing_whine", &"blower_seize"],
	}
	for path: String in expectations:
		var expected: Array = expectations[path]
		var component: WearComponent = load(path) as WearComponent
		_check(component != null, "data: %s loads as WearComponent" % path)
		if component == null:
			continue
		_check(component.component_id == StringName(expected[0]), "data: %s component_id" % path)
		_check(component.wear_rate_per_hour > 0.0, "data: %s wear rate positive" % path)
		var mode_ids: PackedStringArray = PackedStringArray()
		for mode: FailureMode in component.failure_modes:
			if mode != null:
				mode_ids.append(String(mode.id))
		_check(mode_ids == PackedStringArray([String(expected[1]), String(expected[2])]), "data: %s failure modes" % path)


func _test_seeded_determinism() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 4.0)]
	var power_a: PowerSystem = _spawn_power_with_wear(modes, 424242)
	var power_b: PowerSystem = _spawn_power_with_wear(modes, 424242)
	var failure_tick_a: int = -1
	var failure_tick_b: int = -1
	for tick: int in 300:
		power_a.sim_tick(0.1)
		power_b.sim_tick(0.1)
		if failure_tick_a < 0 and _component_failed(power_a, &"rtg_main"):
			failure_tick_a = tick
		if failure_tick_b < 0 and _component_failed(power_b, &"rtg_main"):
			failure_tick_b = tick
	_check(failure_tick_a >= 0, "determinism: seeded wear fails within 300 ticks")
	_check(failure_tick_a == failure_tick_b, "determinism: identical failure tick for identical seeds")
	_check(power_a.get_wear_status() == power_b.get_wear_status(), "determinism: identical wear status after identical ticks")
	power_a.free()
	power_b.free()


func _test_power_force_failure_effects() -> void:
	_failed_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 1000000.0, 0.0), _make_mode(&"rtg_open_circuit", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(modes, 1)
	_check(power.force_failure(&"rtg_main", &"rtg_degraded"), "power: force_failure rtg_degraded accepted")
	_check(absf(power.get_generation_w() - 100.0) < 1e-6, "power: rtg_degraded scales generation to 20 percent")
	_check(_failed_events.size() == 1, "power: typed component_failed emitted once")
	if _failed_events.size() == 1:
		_check(_failed_events[0]["failure_mode_id"] == &"rtg_degraded", "power: component_failed carries the mode id")
	_check(bool(power.get_wear_status()["rtg_main"]["failed"]), "power: forced failure marks the component failed")
	_check(not power.force_failure(&"rtg_main", &"rtg_open_circuit"), "power: force_failure refuses an already failed component")
	_check(not power.force_failure(&"missing", &"rtg_degraded"), "power: force_failure rejects unknown component")

	var open_modes: Array[FailureMode] = [_make_mode(&"rtg_open_circuit", 1000000.0, 0.0)]
	var open_power: PowerSystem = _spawn_power_with_wear(open_modes, 2)
	open_power.force_failure(&"rtg_main", &"rtg_open_circuit")
	_check(open_power.get_generation_w() == 0.0, "power: rtg_open_circuit zeroes generation")
	power.free()
	open_power.free()


func _test_power_repair_restores() -> void:
	_repaired_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(modes, 3)
	power.force_failure(&"rtg_main", &"rtg_degraded")
	_check(power.repair_component(&"rtg_main", 1.0), "power: repair_component accepted")
	_check(absf(power.get_generation_w() - 500.0) < 1e-6, "power: repair restores generator output")
	_check(not bool(power.get_wear_status()["rtg_main"]["failed"]), "power: repair clears failed mode")
	_check(_repaired_events.size() == 1, "power: typed component_repaired emitted once")
	if _repaired_events.size() == 1:
		_check(_repaired_events[0]["repair_quality"] == 1.0, "power: component_repaired carries quality")
	_check(not power.repair_component(&"missing", 1.0), "power: repair rejects unknown component")
	power.free()


func _test_battery_failure_effects() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"cell_fade", 1000000.0, 0.0), _make_mode(&"cell_short", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(modes, 4, 0.0002, 1.0, &"battery_main")
	power.battery_charge_wh = power.battery_capacity_wh
	_check(power.force_failure(&"battery_main", &"cell_fade"), "battery: force_failure cell_fade accepted")
	_check(absf(power.battery_capacity_wh - 2800.0) < 1e-6, "battery: cell_fade cuts capacity by 30 percent")
	_check(power.battery_charge_wh <= power.battery_capacity_wh + 1e-9, "battery: cell_fade clamps charge to capacity")
	power.repair_component(&"battery_main", 1.0)
	_check(absf(power.battery_capacity_wh - 4000.0) < 1e-6, "battery: repair restores capacity")
	power.force_failure(&"battery_main", &"cell_short")
	_check(absf(power.battery_max_discharge_w - 1000.0) < 1e-6, "battery: cell_short halves max discharge")
	power.repair_component(&"battery_main", 1.0)
	_check(absf(power.battery_max_discharge_w - 2000.0) < 1e-6, "battery: repair restores max discharge")
	power.free()


func _test_lighting_ballast_effects() -> void:
	_failed_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"ballast_open", 1000000.0, 0.0), _make_mode(&"ballast_short", 1000000.0, 0.0)]
	var component: WearComponent = _make_component(&"lighting_ballast", modes, 0.0002, 1.0)
	var components: Array[WearComponent] = [component]
	var circuits: Array[PowerCircuit] = [_make_circuit(&"lighting", 200.0, 5)]
	var power: PowerSystem = PowerSystem.new()
	power.circuit_defs = circuits
	power.generators = {&"rtg_main": 500.0}
	power.wear_components = components
	root.add_child(power)
	_check(power.force_failure(&"lighting_ballast", &"ballast_open"), "ballast: force_failure ballast_open accepted")
	_check(absf(power.get_circuit_load(&"lighting")) < 1e-6, "ballast: open ballast cuts lighting load to zero")
	_check(power.repair_component(&"lighting_ballast", 1.0), "ballast: repair accepted after open")
	_check(absf(power.get_circuit_load(&"lighting") - 200.0) < 1e-6, "ballast: repair removes the open override")
	_check(power.force_failure(&"lighting_ballast", &"ballast_short"), "ballast: force_failure ballast_short accepted")
	_check(absf(power.get_circuit_load(&"lighting") - 300.0) < 1e-6, "ballast: short raises lighting load by half")
	_check(power.repair_component(&"lighting_ballast", 1.0), "ballast: repair accepted after short")
	_check(absf(power.get_circuit_load(&"lighting") - 200.0) < 1e-6, "ballast: repair removes the short override")
	power.free()


func _test_atmosphere_failure_effects() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"bearing_whine", 1000000.0, 0.0), _make_mode(&"blower_seize", 1000000.0, 0.0)]
	var atmosphere: AtmosphereSystem = _spawn_atmosphere_with_wear(modes, 5)
	_check(atmosphere.force_failure(&"scrubber_blower_main", &"bearing_whine"), "atmosphere: force_failure bearing_whine accepted")
	_check(absf(_efficiency_multiplier(atmosphere) - 0.5) < 1e-9, "atmosphere: bearing_whine halves scrubber efficiency")
	_check(atmosphere.repair_component(&"scrubber_blower_main", 1.0), "atmosphere: repair_component accepted")
	_check(absf(_efficiency_multiplier(atmosphere) - 1.0) < 1e-9, "atmosphere: repair restores efficiency")
	_check(atmosphere.force_failure(&"scrubber_blower_main", &"blower_seize"), "atmosphere: force_failure blower_seize accepted")
	_check(absf(_efficiency_multiplier(atmosphere) - 0.0) < 1e-9, "atmosphere: blower_seize zeroes scrubber efficiency")

	var seized: AtmosphereSystem = _spawn_atmosphere_with_wear(modes, 6)
	seized.force_failure(&"scrubber_blower_main", &"blower_seize")
	seized.set_occupants(&"main", 1)
	seized.set_scrubber_powered(&"main", true)
	seized.sim_tick(24.0)
	var seized_ppm: float = float(seized.get_compartment_status(&"main")["co2_ppm"])

	var unpowered: AtmosphereSystem = _spawn_atmosphere_with_wear(modes, 7)
	unpowered.set_occupants(&"main", 1)
	unpowered.sim_tick(24.0)
	var unpowered_ppm: float = float(unpowered.get_compartment_status(&"main")["co2_ppm"])
	_check(absf(seized_ppm - unpowered_ppm) < 1e-6, "atmosphere: seized blower scrubs as little as no scrubber")

	atmosphere.free()
	seized.free()
	unpowered.free()


func _test_condition_crossing_events() -> void:
	_condition_events.clear()
	var modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(modes, 8, 0.05, 1.0)
	for tick: int in 5:
		power.sim_tick(1.0)
	_check(_condition_events.size() >= 2, "condition: crossing 0.9 and 0.8 emits typed events")
	if not _condition_events.is_empty():
		var condition: float = float(_condition_events[_condition_events.size() - 1]["condition"])
		_check(condition < 0.8 + 1e-9, "condition: last event carries the crossed condition")
	_check(String(_condition_events[0]["component_id"]) == "rtg_main", "condition: event carries the component id")
	power.free()


func _test_save_load_round_trip() -> void:
	var power_modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(power_modes, 9)
	power.force_failure(&"rtg_main", &"rtg_degraded")
	var saved: Dictionary = power.save_state()
	var exact_restored: PowerSystem = _spawn_power_with_wear(power_modes, 12345)
	exact_restored.load_state(saved)
	_check(int(saved["wear_rng_state"]) == int(exact_restored.save_state()["wear_rng_state"]), "save: wear RNG state round trips in memory")
	_check(exact_restored.get_wear_status() == power.get_wear_status(), "save: in-memory wear status round trips")
	exact_restored.free()

	var parsed_value: Variant = JSON.parse_string(JSON.stringify(saved, "\t"))
	_check(parsed_value is Dictionary, "save: power state is JSON-safe")
	if parsed_value is Dictionary:
		var parsed: Dictionary = parsed_value
		var restored: PowerSystem = _spawn_power_with_wear(power_modes, 777)
		restored.load_state(parsed)
		_check_wear_matches("save: power JSON round trip", restored.get_wear_status(), power.get_wear_status())
		_check(absf(restored.get_generation_w() - 100.0) < 1e-6, "save: failed effect reapplied after load")
		_check(restored.repair_component(&"rtg_main", 1.0), "save: repair after load accepted")
		_check(absf(restored.get_generation_w() - 500.0) < 1e-6, "save: stored pre-failure value restores after load")
		restored.free()

	var atmosphere_modes: Array[FailureMode] = [_make_mode(&"bearing_whine", 1000000.0, 0.0)]
	var atmosphere: AtmosphereSystem = _spawn_atmosphere_with_wear(atmosphere_modes, 10)
	atmosphere.set_occupants(&"main", 1)
	atmosphere.set_scrubber_powered(&"main", true)
	atmosphere.sim_tick(10.0)
	atmosphere.force_failure(&"scrubber_blower_main", &"bearing_whine")
	var atmosphere_parsed_value: Variant = JSON.parse_string(JSON.stringify(atmosphere.save_state(), "\t"))
	_check(atmosphere_parsed_value is Dictionary, "save: atmosphere state is JSON-safe")
	if atmosphere_parsed_value is Dictionary:
		var atmosphere_restored: AtmosphereSystem = _spawn_atmosphere_with_wear(atmosphere_modes, 888)
		atmosphere_restored.load_state(atmosphere_parsed_value)
		_check_wear_matches("save: atmosphere JSON round trip", atmosphere_restored.get_wear_status(), atmosphere.get_wear_status())
		_check(absf(_efficiency_multiplier(atmosphere_restored) - 0.5) < 1e-9, "save: efficiency multiplier round trips")
		_check(atmosphere_restored.repair_component(&"scrubber_blower_main", 1.0), "save: atmosphere repair after load accepted")
		_check(absf(_efficiency_multiplier(atmosphere_restored) - 1.0) < 1e-9, "save: repair after load restores efficiency")
		atmosphere_restored.free()

	power.free()
	atmosphere.free()


func _test_empty_wear_is_inert() -> void:
	_failed_events.clear()
	var circuits: Array[PowerCircuit] = [_make_circuit(&"life_support", 150.0, 0)]
	var power: PowerSystem = PowerSystem.new()
	power.circuit_defs = circuits
	power.generators = {&"rtg_main": 500.0}
	root.add_child(power)
	for tick: int in 3000:
		power.sim_tick(0.1)
	_check(power.get_wear_status().is_empty(), "empty wear: power wear status stays empty")
	_check(_failed_events.is_empty(), "empty wear: power emits no failures")
	power.free()

	var configs: Array[CompartmentConfig] = [_make_config(&"main")]
	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	atmosphere.compartment_defs = configs
	root.add_child(atmosphere)
	atmosphere.set_occupants(&"main", 1)
	atmosphere.set_scrubber_powered(&"main", true)
	for tick: int in 3000:
		atmosphere.sim_tick(0.1)
	_check(atmosphere.get_wear_status().is_empty(), "empty wear: atmosphere wear status stays empty")
	_check(_failed_events.is_empty(), "empty wear: atmosphere emits no failures")
	_check(absf(_efficiency_multiplier(atmosphere) - 1.0) < 1e-9, "empty wear: scrubber efficiency untouched")
	atmosphere.free()


func _spawn_power_with_wear(modes: Array[FailureMode], seed_value: int, wear_rate: float = 0.0002, load_value: float = 1.0, component_id: StringName = &"rtg_main") -> PowerSystem:
	var component: WearComponent = _make_component(component_id, modes, wear_rate, load_value)
	var components: Array[WearComponent] = [component]
	var circuits: Array[PowerCircuit] = [_make_circuit(&"life_support", 150.0, 0)]
	var power: PowerSystem = PowerSystem.new()
	power.wear_seed = seed_value
	power.circuit_defs = circuits
	power.generators = {&"rtg_main": 500.0}
	power.wear_components = components
	root.add_child(power)
	return power


func _spawn_atmosphere_with_wear(modes: Array[FailureMode], seed_value: int) -> AtmosphereSystem:
	var component: WearComponent = _make_component(&"scrubber_blower_main", modes, 0.0002, 1.0)
	var components: Array[WearComponent] = [component]
	var configs: Array[CompartmentConfig] = [_make_config(&"main")]
	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	atmosphere.wear_seed = seed_value
	atmosphere.compartment_defs = configs
	atmosphere.wear_components = components
	root.add_child(atmosphere)
	return atmosphere


func _make_component(component_id: StringName, modes: Array[FailureMode], wear_rate: float, load_value: float) -> WearComponent:
	var component: WearComponent = WearComponent.new()
	component.component_id = component_id
	component.wear_rate_per_hour = wear_rate
	component.load = load_value
	component.failure_modes = modes
	return component


func _make_mode(mode_id: StringName, mtbf_hours: float, max_condition: float = 1.0) -> FailureMode:
	var mode: FailureMode = FailureMode.new()
	mode.id = mode_id
	mode.base_mtbf_hours = mtbf_hours
	mode.max_condition = max_condition
	return mode


func _make_circuit(circuit_id: StringName, load_w: float, priority: int) -> PowerCircuit:
	var circuit: PowerCircuit = PowerCircuit.new()
	circuit.circuit_id = circuit_id
	circuit.nominal_load_w = load_w
	circuit.priority = priority
	return circuit


func _make_config(compartment_id: StringName) -> CompartmentConfig:
	var config: CompartmentConfig = CompartmentConfig.new()
	config.compartment_id = compartment_id
	config.volume_m3 = 60.0
	return config


func _component_failed(system: PowerSystem, component_id: StringName) -> bool:
	var status: Dictionary = system.get_wear_status()
	return status.has(String(component_id)) and bool(status[String(component_id)]["failed"])


func _efficiency_multiplier(atmosphere: AtmosphereSystem) -> float:
	return float(atmosphere.get(&"_efficiency_multiplier"))


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
		print("PASS: test_failures")
		quit(0)
	else:
		print("FAIL: test_failures (%d checks failed)" % _failures)
		quit(1)
