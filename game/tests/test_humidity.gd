## Headless checks for the per-compartment humidity model: sources, scrubbing, leak, events, save/load.
extends SceneTree

var _failures: int = 0
var _spawned: Array[Node] = []
var _humidity_signals: Array[Dictionary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var existing_bus: Node = _find_root_child(&"EventBus")
	if existing_bus != null:
		root.remove_child(existing_bus)
		existing_bus.free()
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	event_bus.connect(&"compartment_humidity_changed", _on_humidity_changed)

	_test_initial_state()
	_test_occupants_raise_humidity()
	_test_scrubber_lowers_humidity()
	_test_candle_raises_humidity()
	_test_leak_decays_humidity()
	_test_fraction_clamps()
	_test_threshold_events()
	_test_save_load_round_trip()

	event_bus.free()
	_finish()


func _test_initial_state() -> void:
	var system: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	var status: Dictionary = system.get_compartment_status(&"main")
	_check(status.has("humidity_g") and status.has("humidity_fraction"), "initial: status exposes humidity fields")
	_check(absf(float(status["humidity_g"]) - 300.0) < 1e-6, "initial: humidity seeds at half capacity")
	_check(absf(float(status["humidity_fraction"]) - 0.5) < 1e-6, "initial: seeded humidity fraction is one half")
	_despawn_all()


func _test_occupants_raise_humidity() -> void:
	var system: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	system.set_occupants(&"main", 2)
	system.sim_tick(1.0)
	var status: Dictionary = system.get_compartment_status(&"main")
	_check(absf(float(status["humidity_g"]) - 420.0) < 1e-6, "occupants: two occupants add their hourly humidity rate")
	_check(absf(float(status["humidity_fraction"]) - 0.7) < 1e-6, "occupants: fraction tracks the added grams")
	_despawn_all()


func _test_scrubber_lowers_humidity() -> void:
	var powered: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	powered.set_scrubber_powered(&"main", true)
	powered.sim_tick(1.0)
	_check(absf(float(powered.get_compartment_status(&"main")["humidity_g"]) - 210.0) < 1e-6, "scrubber: running scrubber removes its hourly rate")

	var idle: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	idle.sim_tick(1.0)
	_check(absf(float(idle.get_compartment_status(&"main")["humidity_g"]) - 300.0) < 1e-6, "scrubber: unpowered scrubber leaves humidity alone")

	var uninstalled: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	uninstalled.set_scrubber_powered(&"main", true)
	uninstalled.set_filter_installed(&"main", false)
	uninstalled.sim_tick(1.0)
	_check(absf(float(uninstalled.get_compartment_status(&"main")["humidity_g"]) - 300.0) < 1e-6, "scrubber: missing filter blocks dehumidification")

	var throttled: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	throttled.set_scrubber_powered(&"main", true)
	throttled.set_scrubber_efficiency(&"main", 0.5)
	throttled.sim_tick(1.0)
	_check(absf(float(throttled.get_compartment_status(&"main")["humidity_g"]) - 255.0) < 1e-6, "scrubber: efficiency scales the removal rate")
	_despawn_all()


func _test_candle_raises_humidity() -> void:
	var occupants_only: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	occupants_only.set_occupants(&"main", 1)
	occupants_only.sim_tick(1.0)
	var occupant_g: float = float(occupants_only.get_compartment_status(&"main")["humidity_g"])

	var candle_lit: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main", 0.0, 1))
	candle_lit.set_occupants(&"main", 1)
	_check(candle_lit.light_o2_candle(&"main"), "candle: ignites from stock")
	candle_lit.sim_tick(1.0)
	var candle_g: float = float(candle_lit.get_compartment_status(&"main")["humidity_g"])
	_check(candle_g > occupant_g, "candle: burning candle raises humidity faster than occupants alone")
	_check(absf((candle_g - occupant_g) - 40.0) < 1e-6, "candle: adds its hourly rate while burning")
	_despawn_all()


func _test_leak_decays_humidity() -> void:
	var system: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main", 0.01))
	var before: Dictionary = system.get_compartment_status(&"main")
	system.sim_tick(10.0)
	var after: Dictionary = system.get_compartment_status(&"main")
	_check(float(after["humidity_g"]) < float(before["humidity_g"]), "leak: humidity falls in a leaking compartment")
	_check(absf(float(after["humidity_g"]) - float(before["humidity_g"]) * exp(-0.1)) < 1e-6, "leak: decays on the same exponential as the gases")
	_despawn_all()


func _test_fraction_clamps() -> void:
	var wet: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	wet.set_occupants(&"main", 4)
	wet.sim_tick(4.0)
	var wet_status: Dictionary = wet.get_compartment_status(&"main")
	_check(float(wet_status["humidity_g"]) > 600.0, "clamp: humidity_g accumulates past capacity")
	_check(float(wet_status["humidity_fraction"]) == 1.0, "clamp: fraction clamps high")

	var drained: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	drained.set_scrubber_powered(&"main", true)
	drained.sim_tick(10.0)
	var drained_status: Dictionary = drained.get_compartment_status(&"main")
	_check(float(drained_status["humidity_g"]) == 0.0, "clamp: humidity floors at zero grams")
	_check(float(drained_status["humidity_fraction"]) == 0.0, "clamp: fraction floors at zero")
	_despawn_all()


func _test_threshold_events() -> void:
	_humidity_signals.clear()
	var system: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	system.set_occupants(&"main", 1)
	for i: int in 4:
		system.sim_tick(0.1)
	_check(_humidity_signals.is_empty(), "events: no signal below a 0.05 fraction change")
	for i: int in 2:
		system.sim_tick(0.1)
	_check(_humidity_signals.size() == 1, "events: signal fires on crossing 0.05")
	if not _humidity_signals.is_empty():
		_check(String(_humidity_signals[0]["compartment_id"]) == "main", "events: signal carries the compartment id")
		_check(float(_humidity_signals[0]["humidity_fraction"]) >= 0.55, "events: signal carries the new fraction")
	for i: int in 6:
		system.sim_tick(0.1)
	_check(_humidity_signals.size() >= 2, "events: signal re-fires on the next 0.05 crossing")
	_despawn_all()


func _test_save_load_round_trip() -> void:
	var system: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	system.set_occupants(&"main", 1)
	system.sim_tick(2.0)
	_check(_humidity_signals.size() >= 1, "save: humidity signal fired while rising")
	var saved: Dictionary = system.save_state()
	var compartment: Dictionary = saved["compartments"]["main"]
	_check(compartment.has("humidity_g"), "save: compartments capture humidity_g")
	_check(compartment.has("last_humidity_fraction"), "save: compartments capture the last emitted humidity fraction")
	var saved_humidity: float = float(compartment["humidity_g"])

	var parsed_value: Variant = JSON.parse_string(JSON.stringify(saved))
	_check(parsed_value is Dictionary, "save: humidity state is JSON-safe")
	var restored: AtmosphereSystem = _spawn_atmosphere(_make_config(&"main"))
	if parsed_value is Dictionary:
		restored.load_state(parsed_value)
	var restored_status: Dictionary = restored.get_compartment_status(&"main")
	_check(absf(float(restored_status["humidity_g"]) - saved_humidity) < 1e-6, "save: humidity_g restores from JSON")
	_check(int(restored_status["occupants"]) == 1, "save: occupancy restores alongside humidity")

	_humidity_signals.clear()
	restored.set_occupants(&"main", 0)
	restored.sim_tick(0.5)
	_check(_humidity_signals.is_empty(), "save: no spurious humidity event after load")
	_despawn_all()


func _make_config(compartment_id: StringName, leak_rate: float = 0.0, candles: int = 0) -> CompartmentConfig:
	var config: CompartmentConfig = CompartmentConfig.new()
	config.compartment_id = compartment_id
	config.volume_m3 = 60.0
	config.leak_rate_per_hour = leak_rate
	config.o2_candles_stocked = candles
	return config


func _spawn_atmosphere(config: CompartmentConfig) -> AtmosphereSystem:
	var defs: Array[CompartmentConfig] = [config]
	var system: AtmosphereSystem = AtmosphereSystem.new()
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


func _on_humidity_changed(compartment_id: StringName, humidity_fraction: float) -> void:
	_humidity_signals.append({"compartment_id": compartment_id, "humidity_fraction": humidity_fraction})


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_humidity")
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
