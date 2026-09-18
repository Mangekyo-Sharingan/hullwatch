## Deterministic single-bus power simulator: generators, battery, and priority-based shedding.
class_name PowerSystem
extends ShipSystem

const BUS_MAIN: StringName = &"main"

@export var battery_capacity_wh: float = 4000.0
@export var battery_max_charge_w: float = 1500.0
@export var battery_max_discharge_w: float = 2000.0
@export var restore_margin_w: float = 25.0
@export var generators: Dictionary = {}
@export var circuit_defs: Array[PowerCircuit] = []

var battery_charge_wh: float = 0.0

var _circuits: Dictionary = {}
var _breaker_on: Dictionary = {}
var _shed: Dictionary = {}
var _load_overrides: Dictionary = {}
var _brownout_active: bool = false
var _served_w: float = 0.0


func _ready() -> void:
	system_id = &"power"
	add_to_group(&"power_system")
	super._ready()
	battery_charge_wh = battery_capacity_wh
	for circuit: PowerCircuit in circuit_defs:
		add_circuit(circuit)


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("PowerSystem.sim_tick: delta_hours must be finite and positive.")
		return
	var generation_w: float = get_generation_w()
	var available_discharge_w: float = minf(battery_max_discharge_w, battery_charge_wh / maxf(delta_hours, 1e-9))
	var supply_w: float = generation_w + available_discharge_w
	var served_demand_w: float = _get_served_demand_w()
	if served_demand_w > supply_w:
		if not _brownout_active:
			_brownout_active = true
			_emit_brownout(get_total_demand_w() / maxf(generation_w + battery_max_discharge_w, 0.001))
		served_demand_w = _shed_to_fit(served_demand_w, supply_w)
	else:
		served_demand_w = _restore_to_fit(served_demand_w, supply_w)
		if _get_shed_count() == 0 and _brownout_active:
			_brownout_active = false
			_emit_power_restored()
	_served_w = minf(served_demand_w, supply_w)
	_update_battery(generation_w, _served_w, delta_hours)


func set_generation(generator_id: StringName, watts: float) -> void:
	if generator_id == &"" or not is_finite(watts) or watts < 0.0:
		push_error("PowerSystem.set_generation: generator_id must be non-empty and watts finite and non-negative.")
		return
	generators[generator_id] = watts


func get_generation_w() -> float:
	var total_w: float = 0.0
	for value: Variant in generators.values():
		total_w += float(value)
	return total_w


func add_circuit(circuit: PowerCircuit) -> bool:
	if circuit == null or circuit.circuit_id == &"":
		push_error("PowerSystem.add_circuit: circuit must be non-null with a non-empty circuit_id.")
		return false
	if _circuits.has(circuit.circuit_id):
		push_error("PowerSystem.add_circuit: duplicate circuit_id '%s'." % String(circuit.circuit_id))
		return false
	_circuits[circuit.circuit_id] = circuit
	_breaker_on[circuit.circuit_id] = true
	_shed[circuit.circuit_id] = false
	return true


func has_circuit(circuit_id: StringName) -> bool:
	return _circuits.has(circuit_id)


func set_breaker(circuit_id: StringName, on: bool) -> bool:
	if not _circuits.has(circuit_id):
		push_error("PowerSystem.set_breaker: unknown circuit_id '%s'." % String(circuit_id))
		return false
	_breaker_on[circuit_id] = on
	return true


func is_breaker_on(circuit_id: StringName) -> bool:
	if not _circuits.has(circuit_id):
		push_error("PowerSystem.is_breaker_on: unknown circuit_id '%s'." % String(circuit_id))
		return false
	return bool(_breaker_on[circuit_id])


func is_circuit_shed(circuit_id: StringName) -> bool:
	if not _circuits.has(circuit_id):
		push_error("PowerSystem.is_circuit_shed: unknown circuit_id '%s'." % String(circuit_id))
		return false
	return bool(_shed[circuit_id])


func set_circuit_load(circuit_id: StringName, watts: float) -> void:
	if not _circuits.has(circuit_id):
		push_error("PowerSystem.set_circuit_load: unknown circuit_id '%s'." % String(circuit_id))
		return
	if not is_finite(watts) or watts < 0.0:
		push_error("PowerSystem.set_circuit_load: watts must be finite and non-negative.")
		return
	_load_overrides[circuit_id] = watts


func get_circuit_load(circuit_id: StringName) -> float:
	if not _circuits.has(circuit_id):
		push_error("PowerSystem.get_circuit_load: unknown circuit_id '%s'." % String(circuit_id))
		return 0.0
	if not bool(_breaker_on[circuit_id]):
		return 0.0
	return _get_effective_load(circuit_id)


func get_total_demand_w() -> float:
	var total_w: float = 0.0
	for circuit_id: StringName in _circuits:
		if not bool(_breaker_on[circuit_id]):
			continue
		total_w += _get_effective_load(circuit_id)
	return total_w


func get_total_load_w() -> float:
	return _served_w


func get_battery_charge() -> float:
	return clampf(battery_charge_wh / maxf(battery_capacity_wh, 0.001), 0.0, 1.0)


func is_brownout() -> bool:
	return _brownout_active


func get_status() -> Dictionary:
	var circuits: Dictionary = {}
	for circuit_id: StringName in _circuits:
		var circuit: PowerCircuit = _circuits[circuit_id]
		var breaker_on: bool = bool(_breaker_on[circuit_id])
		var shed: bool = bool(_shed[circuit_id])
		circuits[circuit_id] = {
			"priority": circuit.priority,
			"breaker_on": breaker_on,
			"shed": shed,
			"demand_w": _get_effective_load(circuit_id) if breaker_on else 0.0,
			"served": breaker_on and not shed,
		}
	return {
		"system_id": system_id,
		"generation_w": get_generation_w(),
		"demand_w": get_total_demand_w(),
		"load_w": _served_w,
		"battery_charge_wh": battery_charge_wh,
		"battery_fraction": get_battery_charge(),
		"battery_capacity_wh": battery_capacity_wh,
		"brownout": _brownout_active,
		"circuits": circuits,
	}


func _get_served_demand_w() -> float:
	var total_w: float = 0.0
	for circuit_id: StringName in _circuits:
		if not bool(_breaker_on[circuit_id]) or bool(_shed[circuit_id]):
			continue
		total_w += _get_effective_load(circuit_id)
	return total_w


func _shed_to_fit(served_demand_w: float, supply_w: float) -> float:
	var candidates: Array[StringName] = _get_unshed_loads_descending()
	for circuit_id: StringName in candidates:
		if served_demand_w <= supply_w:
			break
		_shed[circuit_id] = true
		served_demand_w -= _get_effective_load(circuit_id)
		emit_sim_event(&"circuit_shed", {"circuit_id": circuit_id, "priority": _get_priority(circuit_id)})
	return served_demand_w


func _restore_to_fit(served_demand_w: float, supply_w: float) -> float:
	var candidates: Array[StringName] = _get_shed_loads_ascending()
	for circuit_id: StringName in candidates:
		var load_w: float = _get_effective_load(circuit_id)
		if supply_w - (served_demand_w + load_w) < restore_margin_w:
			break
		_shed[circuit_id] = false
		served_demand_w += load_w
		emit_sim_event(&"circuit_restored", {"circuit_id": circuit_id})
	return served_demand_w


func _get_unshed_loads_descending() -> Array[StringName]:
	var candidates: Array[StringName] = []
	for circuit_id: StringName in _circuits:
		if not bool(_breaker_on[circuit_id]) or bool(_shed[circuit_id]):
			continue
		if _get_priority(circuit_id) <= 0 or _get_effective_load(circuit_id) <= 0.0:
			continue
		candidates.append(circuit_id)
	candidates.sort_custom(_sort_shed_first)
	return candidates


func _get_shed_loads_ascending() -> Array[StringName]:
	var candidates: Array[StringName] = []
	for circuit_id: StringName in _circuits:
		if not bool(_breaker_on[circuit_id]) or not bool(_shed[circuit_id]):
			continue
		candidates.append(circuit_id)
	candidates.sort_custom(_sort_restore_first)
	return candidates


func _sort_shed_first(a: StringName, b: StringName) -> bool:
	var priority_a: int = _get_priority(a)
	var priority_b: int = _get_priority(b)
	if priority_a != priority_b:
		return priority_a > priority_b
	return String(a) < String(b)


func _sort_restore_first(a: StringName, b: StringName) -> bool:
	var priority_a: int = _get_priority(a)
	var priority_b: int = _get_priority(b)
	if priority_a != priority_b:
		return priority_a < priority_b
	return String(a) < String(b)


func _get_effective_load(circuit_id: StringName) -> float:
	if _load_overrides.has(circuit_id):
		return float(_load_overrides[circuit_id])
	var circuit: PowerCircuit = _circuits[circuit_id]
	return circuit.nominal_load_w


func _get_priority(circuit_id: StringName) -> int:
	var circuit: PowerCircuit = _circuits[circuit_id]
	return circuit.priority


func _get_shed_count() -> int:
	var count: int = 0
	for circuit_id: StringName in _shed:
		if bool(_shed[circuit_id]):
			count += 1
	return count


func _update_battery(generation_w: float, served_w: float, delta_hours: float) -> void:
	var net_w: float = generation_w - served_w
	if net_w >= 0.0:
		var headroom_wh: float = maxf(battery_capacity_wh - battery_charge_wh, 0.0)
		battery_charge_wh += minf(minf(net_w * delta_hours, battery_max_charge_w * delta_hours), headroom_wh)
	else:
		var discharge_wh: float = minf(-net_w * delta_hours, battery_max_discharge_w * delta_hours)
		battery_charge_wh = maxf(battery_charge_wh - discharge_wh, 0.0)


func _emit_brownout(ratio: float) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"power_brownout", BUS_MAIN, ratio)


func _emit_power_restored() -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"power_restored", BUS_MAIN)
