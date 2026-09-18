## Shared scaffolding for deterministic headless scenario tests: clock injection, system builders, event capture.
class_name SimHarness
extends RefCounted

var events: Array[Dictionary] = []

var _tree: SceneTree
var _event_bus: Node
var _sim_clock: Node


func _init(tree: SceneTree) -> void:
	_tree = tree


func setup_clock() -> void:
	_remove_root_child(&"EventBus")
	_remove_root_child(&"SimClock")
	_event_bus = load("res://src/autoload/event_bus.gd").new()
	_event_bus.name = &"EventBus"
	_tree.root.add_child(_event_bus)
	_sim_clock = load("res://src/autoload/sim_clock.gd").new()
	_sim_clock.name = &"SimClock"
	_tree.root.add_child(_sim_clock)
	_event_bus.connect(&"sim_event", _on_sim_event)
	_capture_typed(&"power_brownout", ["bus_id", "load_ratio"])
	_capture_typed(&"power_restored", ["bus_id"])
	_capture_typed(&"component_failed", ["component_id", "failure_mode_id"])
	_capture_typed(&"component_condition_changed", ["component_id", "condition"])
	_capture_typed(&"compartment_pressure_changed", ["compartment_id", "pressure_kpa"])
	_capture_typed(&"compartment_atmosphere_changed", ["compartment_id", "o2_fraction", "co2_ppm"])
	_capture_typed(&"airlock_state_changed", ["airlock_id", "state"])


func make_circuit(circuit_id: StringName, load_w: float, priority: int) -> PowerCircuit:
	var circuit := PowerCircuit.new()
	circuit.circuit_id = circuit_id
	circuit.nominal_load_w = load_w
	circuit.priority = priority
	return circuit


func make_compartment(compartment_id: StringName, volume_m3: float = 60.0) -> CompartmentConfig:
	var config := CompartmentConfig.new()
	config.compartment_id = compartment_id
	config.volume_m3 = volume_m3
	return config


func add_power(circuits: Array[PowerCircuit], battery_wh: float = 4000.0, generation: Dictionary = {}) -> PowerSystem:
	var power := PowerSystem.new()
	power.battery_capacity_wh = battery_wh
	power.generators = generation
	power.circuit_defs = circuits
	_tree.root.add_child(power)
	return power


func add_atmosphere(configs: Array[CompartmentConfig]) -> AtmosphereSystem:
	var atmosphere := AtmosphereSystem.new()
	atmosphere.compartment_defs = configs
	_tree.root.add_child(atmosphere)
	return atmosphere


func add_thermal(configs: Array[CompartmentConfig]) -> ThermalSystem:
	var thermal := ThermalSystem.new()
	thermal.compartment_defs = configs
	_tree.root.add_child(thermal)
	return thermal


func add_stores(inventory: Dictionary) -> Stores:
	var stores := Stores.new()
	stores.initial_inventory = inventory
	_tree.root.add_child(stores)
	return stores


func advance(hours: float) -> void:
	_sim_clock.call("fast_forward", hours)


func hours() -> float:
	return float(_sim_clock.call("get_total_hours"))


func events_named(event_name: StringName) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for event: Dictionary in events:
		if event["name"] == event_name:
			matched.append(event)
	return matched


func event_sequence() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for event: Dictionary in events:
		names.append(String(event["name"]))
	return names


func clear_events() -> void:
	events.clear()


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	events.append({"source": "sim", "name": event_name, "payload": payload})


func _capture_typed(signal_name: StringName, fields: Array) -> void:
	_event_bus.connect(signal_name, func(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
		var payload: Dictionary = {}
		var values: Array = [_a, _b, _c]
		for i: int in fields.size():
			payload[fields[i]] = values[i]
		events.append({"source": "signal", "name": signal_name, "payload": payload})
	)


func _remove_root_child(node_name: StringName) -> void:
	for child: Node in _tree.root.get_children():
		if child.name == node_name:
			_tree.root.remove_child(child)
			child.free()
			return
