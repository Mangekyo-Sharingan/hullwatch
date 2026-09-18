extends SceneTree

const LIFE_SUPPORT_PATH: String = "res://src/data/power/circuit_life_support.tres"
const SCRUBBER_PATH: String = "res://src/data/power/circuit_scrubber.tres"
const LIGHTING_PATH: String = "res://src/data/power/circuit_lighting.tres"

var _failures: int = 0
var _brownout_count: int = 0
var _restored_count: int = 0
var _last_brownout_ratio: float = -1.0


func _initialize() -> void:
	await process_frame
	var autoload_bus: Node = _find_root_child(&"EventBus")
	if autoload_bus != null:
		root.remove_child(autoload_bus)
		autoload_bus.free()
	_check(_find_root_child(&"EventBus") == null, "EventBus absent-safe: no EventBus autoload present")

	_test_instantiation_without_autoloads()

	var event_bus_script: GDScript = load("res://src/autoload/event_bus.gd")
	var event_bus: Node = event_bus_script.new() if event_bus_script != null else null
	_check(event_bus != null, "event_bus instantiates")
	if event_bus != null:
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
		event_bus.connect(&"power_brownout", _on_power_brownout)
		event_bus.connect(&"power_restored", _on_power_restored)

	_test_breaker_toggle()
	_test_charge_with_surplus()
	_test_discharge_to_empty()
	_test_brownout_and_restore()
	_test_all_critical_deficit()
	_test_determinism()
	_test_data_resources()
	_test_invalid_inputs()

	_finish()


func _test_instantiation_without_autoloads() -> void:
	var power: PowerSystem = _spawn_power()
	_check(power != null, "power system instantiates without autoloads")
	if power == null:
		return
	_check(power.system_id == &"power", "system_id is power")
	_check(is_equal_approx(power.battery_charge_wh, power.battery_capacity_wh), "battery starts at capacity")
	_check(power.add_circuit(_make_circuit(&"life_support", 120.0, 0)), "circuit adds without autoloads")
	power.set_generation(&"gen", 0.0)
	power.battery_charge_wh = 0.0
	power.sim_tick(1.0)
	_check(power.is_brownout(), "brownout without EventBus does not crash")


func _test_breaker_toggle() -> void:
	var power: PowerSystem = _spawn_power()
	power.add_circuit(_make_circuit(&"life_support", 120.0, 0))
	power.add_circuit(_make_circuit(&"scrubber", 150.0, 2))
	power.add_circuit(_make_circuit(&"lighting", 200.0, 5))
	_check(is_equal_approx(power.get_total_demand_w(), 470.0), "breaker on: demand is 470 W")
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 200.0), "breaker on: circuit load is 200 W")
	_check(power.set_breaker(&"lighting", false), "set_breaker false succeeds")
	_check(is_equal_approx(power.get_total_demand_w(), 270.0), "breaker off: demand drops to 270 W")
	_check(is_equal_approx(power.get_circuit_load(&"lighting"), 0.0), "breaker off: circuit load is 0 W")
	_check(power.set_breaker(&"lighting", true), "set_breaker true succeeds")
	_check(is_equal_approx(power.get_total_demand_w(), 470.0), "breaker on: demand returns to 470 W")


func _test_charge_with_surplus() -> void:
	var power: PowerSystem = _spawn_power()
	power.battery_charge_wh = power.battery_capacity_wh / 2.0
	power.add_circuit(_make_circuit(&"load", 300.0, 5))
	power.set_generation(&"gen", 500.0)
	power.sim_tick(1.0)
	var expected_charge_wh: float = 2000.0 + minf(minf(200.0, power.battery_max_charge_w), power.battery_capacity_wh - 2000.0)
	_check(absf(power.battery_charge_wh - expected_charge_wh) <= 1e-6, "surplus: battery charges by the net surplus over 1 h")
	_check(is_equal_approx(power.get_total_load_w(), 300.0), "surplus: full demand served")
	_check(not power.is_brownout(), "surplus: no brownout")


func _test_discharge_to_empty() -> void:
	var power: PowerSystem = _spawn_power()
	power.add_circuit(_make_circuit(&"life_support", 120.0, 0))
	power.set_generation(&"gen", 0.0)
	power.sim_tick(1.0)
	_check(absf(power.battery_charge_wh - (power.battery_capacity_wh - 120.0)) <= 1e-6, "discharge: battery drains at 120 W per hour")
	for i: int in 40:
		power.sim_tick(1.0)
	_check(power.battery_charge_wh == 0.0, "discharge: battery hits exactly 0, not negative")
	_check(power.get_total_load_w() == 0.0, "discharge: served load is 0 when battery is empty")


func _test_brownout_and_restore() -> void:
	_brownout_count = 0
	_restored_count = 0
	_last_brownout_ratio = -1.0
	var power: PowerSystem = _spawn_power()
	power.add_circuit(_make_circuit(&"life_support", 120.0, 0))
	power.add_circuit(_make_circuit(&"scrubber", 150.0, 2))
	power.add_circuit(_make_circuit(&"lighting", 200.0, 5))
	power.set_generation(&"gen", 300.0)
	power.battery_charge_wh = 0.0
	power.sim_tick(1.0)
	_check(power.is_circuit_shed(&"lighting"), "brownout: highest priority number shed first")
	_check(not power.is_circuit_shed(&"scrubber"), "brownout: scrubber stays on")
	_check(not power.is_circuit_shed(&"life_support"), "brownout: life support never shed")
	_check(power.is_brownout(), "brownout: active after shedding")
	_check(_brownout_count == 1, "brownout: exactly one brownout signal emitted")
	_check(absf(_last_brownout_ratio - (470.0 / 2300.0)) <= 1e-6, "brownout: ratio is demand over generation plus max discharge")
	_check(is_equal_approx(power.get_total_demand_w(), 470.0), "brownout: shed demand still counted in total demand")
	_check(is_equal_approx(power.get_total_load_w(), 270.0), "brownout: served load excludes the shed circuit")
	power.set_generation(&"gen", 600.0)
	power.sim_tick(1.0)
	_check(not power.is_circuit_shed(&"lighting"), "restore: lighting unshed once supply allows")
	_check(not power.is_brownout(), "restore: brownout cleared")
	_check(_restored_count == 1, "restore: exactly one power_restored signal emitted")
	_check(_brownout_count == 1, "restore: no duplicate brownout signal")


func _test_all_critical_deficit() -> void:
	var power: PowerSystem = _spawn_power()
	power.add_circuit(_make_circuit(&"critical_a", 120.0, 0))
	power.add_circuit(_make_circuit(&"critical_b", 150.0, 0))
	power.add_circuit(_make_circuit(&"critical_c", 200.0, 0))
	power.set_generation(&"gen", 300.0)
	power.battery_charge_wh = 0.0
	power.sim_tick(1.0)
	_check(power.is_brownout(), "all-critical: brownout active")
	_check(not power.is_circuit_shed(&"critical_a") and not power.is_circuit_shed(&"critical_b") and not power.is_circuit_shed(&"critical_c"), "all-critical: nothing shed")
	var supply_w: float = power.get_generation_w() + minf(power.battery_max_discharge_w, power.battery_charge_wh / 1.0)
	_check(power.get_total_load_w() <= supply_w + 1e-9, "all-critical: served load within supply")


func _test_determinism() -> void:
	var power_a: PowerSystem = _make_deterministic_power()
	var power_b: PowerSystem = _make_deterministic_power()
	for i: int in 200:
		power_a.sim_tick(1.0 / 600.0)
		power_b.sim_tick(1.0 / 600.0)
	_check(power_a.battery_charge_wh == power_b.battery_charge_wh, "determinism: identical battery charge after 200 ticks")
	var status_a: Dictionary = power_a.get_status()
	var status_b: Dictionary = power_b.get_status()
	_check(status_a == status_b, "determinism: identical status dictionaries")


func _test_data_resources() -> void:
	var expectations: Dictionary = {
		LIFE_SUPPORT_PATH: {"id": &"life_support", "name": "Life Support", "load": 120.0, "priority": 0},
		SCRUBBER_PATH: {"id": &"scrubber", "name": "CO2 Scrubber", "load": 150.0, "priority": 2},
		LIGHTING_PATH: {"id": &"lighting", "name": "Lighting", "load": 200.0, "priority": 5},
	}
	for resource_path: String in expectations:
		var circuit: PowerCircuit = load(resource_path)
		var expected: Dictionary = expectations[resource_path]
		_check(circuit != null and circuit is PowerCircuit, "data: %s is a PowerCircuit" % resource_path)
		if circuit == null:
			continue
		_check(circuit.circuit_id == expected["id"], "data: %s circuit_id" % resource_path)
		_check(circuit.display_name == expected["name"], "data: %s display_name" % resource_path)
		_check(is_equal_approx(circuit.nominal_load_w, expected["load"]), "data: %s nominal_load_w" % resource_path)
		_check(circuit.priority == expected["priority"], "data: %s priority" % resource_path)


func _test_invalid_inputs() -> void:
	var power: PowerSystem = _spawn_power()
	_check(not power.set_breaker(&"nope", false), "invalid: set_breaker unknown id returns false")
	_check(not power.set_breaker(&"nope", true), "invalid: set_breaker unknown id on returns false")
	_check(not power.add_circuit(null), "invalid: add_circuit null returns false")
	_check(not power.add_circuit(PowerCircuit.new()), "invalid: add_circuit without circuit_id returns false")
	_check(not power.is_breaker_on(&"nope"), "invalid: is_breaker_on unknown id returns false")
	_check(not power.is_circuit_shed(&"nope"), "invalid: is_circuit_shed unknown id returns false")
	_check(power.get_circuit_load(&"nope") == 0.0, "invalid: get_circuit_load unknown id returns 0")
	var demand_before: float = power.get_total_demand_w()
	power.set_circuit_load(&"nope", 100.0)
	_check(power.get_total_demand_w() == demand_before, "invalid: set_circuit_load unknown id is a no-op")
	power.set_generation(&"", 100.0)
	_check(power.get_generation_w() == 0.0, "invalid: set_generation empty id is a no-op")
	var duplicate: PowerCircuit = _make_circuit(&"dup", 10.0, 5)
	_check(power.add_circuit(duplicate), "invalid: first add of an id succeeds")
	_check(not power.add_circuit(duplicate), "invalid: duplicate circuit_id rejected")


func _spawn_power() -> PowerSystem:
	var power: PowerSystem = PowerSystem.new()
	root.add_child(power)
	return power


func _make_circuit(circuit_id: StringName, load_w: float, priority: int) -> PowerCircuit:
	var circuit: PowerCircuit = PowerCircuit.new()
	circuit.circuit_id = circuit_id
	circuit.nominal_load_w = load_w
	circuit.priority = priority
	return circuit


func _make_deterministic_power() -> PowerSystem:
	var power: PowerSystem = _spawn_power()
	power.add_circuit(_make_circuit(&"life_support", 120.0, 0))
	power.add_circuit(_make_circuit(&"scrubber", 150.0, 2))
	power.add_circuit(_make_circuit(&"lighting", 200.0, 5))
	power.set_generation(&"gen", 350.0)
	power.battery_charge_wh = 1000.0
	return power


func _on_power_brownout(bus_id: StringName, load_ratio: float) -> void:
	if bus_id == PowerSystem.BUS_MAIN:
		_brownout_count += 1
		_last_brownout_ratio = load_ratio


func _on_power_restored(bus_id: StringName) -> void:
	if bus_id == PowerSystem.BUS_MAIN:
		_restored_count += 1


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_power")
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
