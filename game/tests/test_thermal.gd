extends SceneTree

var _failures: int = 0
var _sim_events: Array[Dictionary] = []
var _spawned: Array[Node] = []


class AtmosphereReportSpy extends AtmosphereSystem:
	var report_calls: int = 0

	func get_compartment_status(compartment_id: StringName) -> Dictionary:
		report_calls += 1
		return super.get_compartment_status(compartment_id)


class GenericAtmosphere extends Node:
	var report: Variant = {"occupants": 4}
	var report_calls: int = 0

	func get_compartment_status(_compartment_id: StringName) -> Variant:
		report_calls += 1
		return report


class GuardedAtmosphere extends GenericAtmosphere:
	func has_compartment(compartment_id: StringName) -> bool:
		return compartment_id == &"main"


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
	_test_heater_holds_target()
	_test_freezing_without_heater()
	_test_occupant_heat()
	_test_occupancy_paths()
	_test_power_interlock()
	_test_determinism()
	_test_save_load()
	_test_events()
	_test_data()

	_finish()


func _test_initial_state() -> void:
	var system: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	_check(system.has_compartment(&"main"), "initial: compartment registered")
	_check(not system.has_compartment(&"nope"), "initial: unknown compartment absent")
	var status: Dictionary = system.get_compartment_status(&"main")
	_check(is_equal_approx(float(status["temperature_c"]), 21.0), "initial: temperature matches config")
	_check(bool(status["heater_powered"]), "initial: heater powered by default")
	_check(not bool(status["heater_active"]), "initial: heater idle at target")
	_check(not bool(status["freeze_risk"]), "initial: no freeze risk")
	_check(int(status["occupants"]) == 0, "initial: occupants default to zero")
	_check(is_equal_approx(system.get_temperature(&"main"), 21.0), "initial: get_temperature matches")
	_check(system.get_compartment_status(&"nope").is_empty(), "initial: unknown status is empty")
	_despawn_all()


func _test_heater_holds_target() -> void:
	var system: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	var activated: bool = false
	for i: int in 40:
		system.sim_tick(0.1)
		activated = activated or bool(system.get_compartment_status(&"main")["heater_active"])
	var temperature_c: float = system.get_temperature(&"main")
	_check(absf(temperature_c - 21.0) <= 2.0, "heater holds temperature within target +/- 2 C over 4 h")
	_check(activated, "heater cycles on below the deadband")
	_despawn_all()


func _test_freezing_without_heater() -> void:
	var system: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	system.set_heater_powered(&"main", false)
	for i: int in 48:
		system.sim_tick(0.25)
	var status: Dictionary = system.get_compartment_status(&"main")
	_check(float(status["temperature_c"]) < 1.0, "unheated compartment cools toward exterior")
	_check(bool(status["freeze_risk"]), "freeze risk true after 12 h unheated")
	_check(not bool(status["heater_active"]), "heater stays off while unpowered")
	_despawn_all()


func _test_occupant_heat() -> void:
	var occupied_temperature: float = _run_unheated(_make_config(&"main", 21.0, 1))
	var empty_temperature: float = _run_unheated(_make_config(&"main", 21.0, 0))
	_check(occupied_temperature > empty_temperature, "occupants end warmer than unoccupied")
	_check(occupied_temperature - empty_temperature > 1.0, "occupant heat difference is meaningful")
	_despawn_all()


func _test_occupancy_paths() -> void:
	var atmosphere: AtmosphereReportSpy = AtmosphereReportSpy.new()
	var config: CompartmentConfig = _make_config(&"main", 21.0, 2)
	atmosphere.compartment_defs = [config]
	_spawn(atmosphere)
	var system: ThermalSystem = _spawn_thermal(config)
	system.sim_tick(ThermalSystem.MAX_STEP_HOURS)
	_check(int(system.get_compartment_status(&"main")["occupants"]) == 2, "typed occupancy: tick reads live count")
	atmosphere.set_occupants(&"main", 5)
	system.sim_tick(ThermalSystem.MAX_STEP_HOURS)
	_check(int(system.get_compartment_status(&"main")["occupants"]) == 5, "typed occupancy: next tick reads changed count")
	atmosphere.remove_compartment(&"main")
	system.sim_tick(ThermalSystem.MAX_STEP_HOURS)
	_check(int(system.get_compartment_status(&"main")["occupants"]) == 0, "typed occupancy: removed room reads zero")
	_check(system._read_occupants(atmosphere, &"missing") == 0, "typed occupancy: unknown room reads zero")
	_check(atmosphere.report_calls == 0, "typed occupancy: no full compartment report requested")
	var generic: GenericAtmosphere = GenericAtmosphere.new()
	_check(system._read_occupants(generic, &"main") == 4, "generic occupancy: report fallback without has_compartment")
	generic.report = {"occupants": 2.9}
	_check(system._read_occupants(generic, &"main") == 2, "generic occupancy: report count converts to int")
	generic.report = {"occupants": -2}
	_check(system._read_occupants(generic, &"main") == -2, "generic occupancy: existing negative count semantics retained")
	generic.report = {}
	_check(system._read_occupants(generic, &"main") == 0, "generic occupancy: missing count reads zero")
	generic.report = "invalid"
	_check(system._read_occupants(generic, &"main") == 0, "generic occupancy: non-dictionary report reads zero")
	var guarded: GuardedAtmosphere = GuardedAtmosphere.new()
	_check(system._read_occupants(guarded, &"missing") == 0 and guarded.report_calls == 0, "generic occupancy: absent room skips report")
	_check(system._read_occupants(guarded, &"main") == 4 and guarded.report_calls == 1, "generic occupancy: present room requests report")
	var bare: Node = Node.new()
	_check(system._read_occupants(bare, &"main") == 0 and system._read_occupants(null, &"main") == 0, "generic occupancy: absent method and null read zero")
	bare.free()
	guarded.free()
	generic.free()
	_despawn_all()


func _run_unheated(config: CompartmentConfig) -> float:
	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	var defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = defs
	_spawn(atmosphere)
	var system: ThermalSystem = _spawn_thermal(config)
	system.set_heater_powered(&"main", false)
	for i: int in 40:
		system.sim_tick(0.1)
	var temperature_c: float = system.get_temperature(&"main")
	_despawn_all()
	return temperature_c


func _test_power_interlock() -> void:
	var power: PowerSystem = PowerSystem.new()
	_spawn(power)
	power.add_circuit(_make_circuit(&"life_support", 120.0, 0))
	power.set_breaker(&"life_support", false)
	var system: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	for i: int in 8:
		system.sim_tick(0.25)
	var blocked_temperature: float = system.get_temperature(&"main")
	_check(blocked_temperature < 15.0, "breaker off blocks the heater and the compartment cools")
	power.set_breaker(&"life_support", true)
	for i: int in 24:
		system.sim_tick(0.25)
	var recovered_temperature: float = system.get_temperature(&"main")
	_check(recovered_temperature > blocked_temperature + 5.0, "breaker on lets the heater recover the compartment")
	_despawn_all()


func _test_determinism() -> void:
	var system_a: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	var system_b: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	var series_a: Array[float] = []
	var series_b: Array[float] = []
	for i: int in 300:
		system_a.sim_tick(1.0 / 600.0)
		system_b.sim_tick(1.0 / 600.0)
		series_a.append(system_a.get_temperature(&"main"))
		series_b.append(system_b.get_temperature(&"main"))
	_check(series_a == series_b, "determinism: identical temperature series over 300 ticks")
	_despawn_all()


func _test_save_load() -> void:
	var system: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	for i: int in 20:
		system.sim_tick(0.1)
	var saved: Dictionary = system.save_state()
	_check(saved["system_id"] == "thermal", "save: system_id is thermal")
	_check(int(saved["state_version"]) == 1, "save: state_version is 1")
	var compartments: Dictionary = saved["compartments"]
	_check(compartments.has("main"), "save: compartments keyed by string id")
	var saved_temperature: float = float(compartments["main"]["temperature_c"])
	_check(is_equal_approx(saved_temperature, system.get_temperature(&"main")), "save: temperature captured")
	var json_text: String = JSON.stringify(saved)
	var parsed: Variant = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "save: JSON round trip parses to Dictionary")
	var parsed_dict: Dictionary = {}
	if parsed is Dictionary:
		parsed_dict = parsed
	system.set_heater_powered(&"main", false)
	system.set_heat_gain(&"main", 5000.0)
	for i: int in 8:
		system.sim_tick(0.25)
	_check(absf(system.get_temperature(&"main") - saved_temperature) > 1.0, "save: mutation diverges after save")
	system.load_state(parsed_dict)
	var loaded_status: Dictionary = system.get_compartment_status(&"main")
	_check(is_equal_approx(float(loaded_status["temperature_c"]), saved_temperature), "load: temperature restored from JSON")
	_check(bool(loaded_status["heater_powered"]), "load: heater_powered restored")
	_check(float(loaded_status["heat_input_w"]) < 500.0, "load: constant heat gain cleared")
	_despawn_all()


func _test_events() -> void:
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	_spawn(event_bus)
	event_bus.connect(&"sim_event", _on_sim_event)
	_sim_events.clear()
	var system: ThermalSystem = _spawn_thermal(_make_config(&"main", 21.0, 0))
	system.set_heater_powered(&"main", false)
	for i: int in 12:
		system.sim_tick(1.0)
	var temperature_events: int = 0
	var freeze_events: int = 0
	var freeze_active: bool = false
	for event: Dictionary in _sim_events:
		if event["name"] == &"compartment_temperature_changed":
			temperature_events += 1
		elif event["name"] == &"compartment_freeze_risk":
			freeze_events += 1
			freeze_active = bool(event["payload"]["active"])
	_check(temperature_events >= 2, "events: temperature_changed emitted repeatedly")
	_check(freeze_events == 1 and freeze_active, "events: freeze_risk emitted once on activation")
	_despawn_all()


func _test_data() -> void:
	var main_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_main.tres")
	var storage_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_storage.tres")
	_check(main_config != null, "data: main compartment loads")
	_check(storage_config != null, "data: storage compartment loads")
	if main_config != null:
		_check(is_equal_approx(main_config.initial_temperature_c, 21.0), "data: main initial temperature default")
		_check(is_equal_approx(main_config.thermal_capacity_j_per_k, 90000.0), "data: main thermal capacity default")
	if storage_config != null:
		_check(storage_config.compartment_id == &"storage", "data: storage id")


func _make_config(id: StringName, temperature_c: float, occupants: int = 0) -> CompartmentConfig:
	var config := CompartmentConfig.new()
	config.compartment_id = id
	config.volume_m3 = 10.0
	config.initial_temperature_c = temperature_c
	config.initial_occupants = occupants
	config.thermal_capacity_j_per_k = 90000.0
	config.hull_conductance_w_per_k = 3.0
	config.heater_watts = 400.0
	config.heater_target_c = 21.0
	config.heater_deadband_c = 1.0
	config.occupant_heat_w = 100.0
	config.freeze_threshold_c = 1.0
	return config


func _make_circuit(circuit_id: StringName, load_w: float, priority: int) -> PowerCircuit:
	var circuit := PowerCircuit.new()
	circuit.circuit_id = circuit_id
	circuit.nominal_load_w = load_w
	circuit.priority = priority
	return circuit


func _spawn_thermal(config: CompartmentConfig) -> ThermalSystem:
	var defs: Array[CompartmentConfig] = [config]
	var system := ThermalSystem.new()
	system.compartment_defs = defs
	_spawn(system)
	return system


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	_sim_events.append({"name": event_name, "payload": payload})


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_thermal")
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
