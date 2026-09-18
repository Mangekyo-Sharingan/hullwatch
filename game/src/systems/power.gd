## Deterministic single-bus power simulator: generators, battery, and priority-based shedding.
class_name PowerSystem
extends ShipSystem

const BUS_MAIN: StringName = &"main"
const RTG_MAIN: StringName = &"rtg_main"

@export var battery_capacity_wh: float = 4000.0
@export var battery_max_charge_w: float = 1500.0
@export var battery_max_discharge_w: float = 2000.0
@export var restore_margin_w: float = 25.0
@export var generators: Dictionary = {}
@export var circuit_defs: Array[PowerCircuit] = []
@export var wear_components: Array[WearComponent] = []
@export var wear_seed: int = 20260918

var battery_charge_wh: float = 0.0

var _circuits: Dictionary = {}
var _breaker_on: Dictionary = {}
var _shed: Dictionary = {}
var _load_overrides: Dictionary = {}
var _brownout_active: bool = false
var _served_w: float = 0.0
var _rng: RandomNumberGenerator
var _condition_bucket: Dictionary = {}
var _failure_restore: Dictionary = {}
var _wear_environment: Dictionary = {}


func _ready() -> void:
	system_id = &"power"
	add_to_group(&"power_system")
	_wear_rng()
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
	_tick_wear(delta_hours)


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
	emit_sim_event(&"breaker_toggled", {"circuit_id": circuit_id, "on": on})
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


func repair_component(component_id: StringName, quality: float) -> bool:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null:
		push_error("PowerSystem.repair_component: unknown component_id '%s'." % String(component_id))
		return false
	component.apply_repair(quality)
	if not component.is_failed():
		_restore_failure_effect(component.component_id)
	_condition_bucket[component.component_id] = _condition_bucket_for(component.condition)
	_emit_component_repaired(component.component_id, clampf(quality, 0.0, 1.0))
	return true


func get_wear_status() -> Dictionary:
	var status: Dictionary = {}
	for component: WearComponent in wear_components:
		if component == null or component.component_id == &"":
			continue
		status[String(component.component_id)] = component.get_status()
	return status


func force_failure(component_id: StringName, failure_mode_id: StringName) -> bool:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null or failure_mode_id == &"":
		push_error("PowerSystem.force_failure: unknown component_id '%s' or empty failure_mode_id." % String(component_id))
		return false
	if component.is_failed():
		return false
	component.failed_mode = failure_mode_id
	_apply_failure_effect(component, failure_mode_id)
	_emit_component_failed(component.component_id, failure_mode_id)
	return true


func diagnose_component(component_id: StringName) -> StringName:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null:
		push_error("PowerSystem.diagnose_component: unknown component_id '%s'." % String(component_id))
		return &""
	if not component.is_failed():
		return &""
	var was_diagnosed: bool = component.diagnosed
	var failure_mode_id: StringName = component.diagnose()
	if not was_diagnosed:
		var event_bus: Node = _get_autoload(&"EventBus")
		if event_bus != null:
			event_bus.emit_signal(&"component_diagnosed", component_id, failure_mode_id)
		emit_sim_event(&"component_diagnosed", {"component_id": component_id, "failure_mode_id": failure_mode_id})
	return failure_mode_id


func get_undiagnosed_failures() -> Array[StringName]:
	var failures: Array[StringName] = []
	for component: WearComponent in wear_components:
		if component == null or component.component_id == &"":
			continue
		if component.is_failed() and not component.diagnosed:
			failures.append(component.component_id)
	return failures


func scan_system() -> Dictionary:
	var conditions: Dictionary = {}
	for component: WearComponent in wear_components:
		if component == null or component.component_id == &"":
			continue
		component.scan()
		conditions[String(component.component_id)] = component.condition
	emit_sim_event(&"components_scanned", {"system_id": String(system_id)})
	return conditions


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


func save_state() -> Dictionary:
	var breakers: Dictionary = {}
	var shed: Dictionary = {}
	var load_overrides: Dictionary = {}
	for circuit_id: StringName in _circuits:
		breakers[String(circuit_id)] = bool(_breaker_on[circuit_id])
		shed[String(circuit_id)] = bool(_shed[circuit_id])
		if _load_overrides.has(circuit_id):
			load_overrides[String(circuit_id)] = float(_load_overrides[circuit_id])
	var generator_values: Dictionary = {}
	for generator_id: Variant in generators:
		generator_values[String(generator_id)] = float(generators[generator_id])
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"battery_charge_wh": battery_charge_wh,
		"battery_capacity_wh": battery_capacity_wh,
		"battery_max_discharge_w": battery_max_discharge_w,
		"generators": generator_values,
		"breakers": breakers,
		"shed": shed,
		"load_overrides": load_overrides,
		"brownout": _brownout_active,
		"served_w": _served_w,
		"wear": _wear_save_entries(),
		"wear_rng_state": str(_wear_rng().state),
		"failure_restore": _failure_restore_save(),
	}


func load_state(state: Dictionary) -> void:
	if state.has("battery_capacity_wh"):
		battery_capacity_wh = maxf(float(state.get("battery_capacity_wh", battery_capacity_wh)), 0.0)
	if state.has("battery_max_discharge_w"):
		battery_max_discharge_w = maxf(float(state.get("battery_max_discharge_w", battery_max_discharge_w)), 0.0)
	var saved_generators: Dictionary = state.get("generators", {})
	for generator_id: Variant in saved_generators:
		var generator_key: StringName = StringName(generator_id)
		if generators.has(generator_key):
			generators[generator_key] = float(saved_generators[generator_id])
	battery_charge_wh = clampf(float(state.get("battery_charge_wh", battery_charge_wh)), 0.0, battery_capacity_wh)
	var breakers: Dictionary = state.get("breakers", {})
	var shed: Dictionary = state.get("shed", {})
	var load_overrides: Dictionary = state.get("load_overrides", {})
	_load_overrides.clear()
	for circuit_id: StringName in _circuits:
		var key: String = String(circuit_id)
		if breakers.has(key):
			_breaker_on[circuit_id] = bool(breakers[key])
		if shed.has(key):
			_shed[circuit_id] = bool(shed[key])
		if load_overrides.has(key):
			_load_overrides[circuit_id] = float(load_overrides[key])
	_brownout_active = bool(state.get("brownout", false))
	_served_w = float(state.get("served_w", 0.0))
	_load_wear(state.get("wear", []))
	_load_failure_restore(state.get("failure_restore", {}))
	if state.has("wear_rng_state"):
		var rng: RandomNumberGenerator = _wear_rng()
		rng.state = int(state.get("wear_rng_state", rng.state))
	_reapply_failed_effects()


func get_wear_environment() -> Dictionary:
	return _wear_environment


func _tick_wear(delta_hours: float) -> void:
	_wear_environment = {
		"heat": _heat_factor(),
		"load": _load_factor(),
		"vibration": 0.0,
		"humidity": _humidity_factor(),
	}
	if wear_components.is_empty():
		return
	for component: WearComponent in wear_components:
		if component == null:
			continue
		var failed_mode_id: StringName = component.tick_sim(delta_hours, _wear_environment, _wear_rng())
		if failed_mode_id != &"":
			_apply_failure_effect(component, failed_mode_id)
			_emit_component_failed(component.component_id, failed_mode_id)
		_emit_condition_crossings(component)


func _wear_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = wear_seed
	return _rng


func _find_wear_component(component_id: StringName) -> WearComponent:
	for component: WearComponent in wear_components:
		if component != null and component.component_id == component_id:
			return component
	return null


func _heat_factor() -> float:
	var thermal: Node = _first_node_in_group(&"thermal_system")
	if thermal == null or not thermal.has_method(&"get_status"):
		return 0.0
	var status: Variant = thermal.call("get_status")
	if not (status is Dictionary):
		return 0.0
	var compartments: Variant = (status as Dictionary).get("compartments", {})
	if not (compartments is Dictionary):
		return 0.0
	var hottest_c: float = 20.0
	var found: bool = false
	for value: Variant in (compartments as Dictionary).values():
		if value is Dictionary and (value as Dictionary).has("temperature_c"):
			hottest_c = maxf(hottest_c, float((value as Dictionary)["temperature_c"]))
			found = true
	if not found:
		return 0.0
	return clampf((hottest_c - 20.0) / 40.0, 0.0, 1.0)


func _load_factor() -> float:
	return clampf(_served_w / maxf(get_generation_w(), 1.0), 0.0, 1.0)


func _humidity_factor() -> float:
	var atmosphere: Node = _first_node_in_group(&"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"get_status"):
		return 0.0
	var status: Variant = atmosphere.call("get_status")
	if not (status is Dictionary):
		return 0.0
	var compartments: Variant = (status as Dictionary).get("compartments", {})
	if not (compartments is Dictionary):
		return 0.0
	var highest_fraction: float = 0.0
	for value: Variant in (compartments as Dictionary).values():
		if value is Dictionary:
			highest_fraction = maxf(highest_fraction, float((value as Dictionary).get("humidity_fraction", 0.0)))
	return clampf(highest_fraction, 0.0, 1.0)


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)


func _apply_failure_effect(component: WearComponent, failure_mode_id: StringName) -> void:
	match failure_mode_id:
		&"rtg_degraded":
			_scale_generator(RTG_MAIN, 0.2, component.component_id)
		&"rtg_open_circuit":
			_scale_generator(RTG_MAIN, 0.0, component.component_id)
		&"cell_fade":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "battery_capacity_wh", "value": battery_capacity_wh}
			battery_capacity_wh = float(_failure_restore[component.component_id]["value"]) * 0.7
			battery_charge_wh = clampf(battery_charge_wh, 0.0, battery_capacity_wh)
		&"cell_short":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "battery_max_discharge_w", "value": battery_max_discharge_w}
			battery_max_discharge_w = float(_failure_restore[component.component_id]["value"]) * 0.5
		&"ballast_open":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "load_override", "target": "lighting", "value": _get_effective_load(&"lighting")}
			_load_overrides[&"lighting"] = 0.0
		&"ballast_short":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "load_override", "target": "lighting", "value": _get_effective_load(&"lighting")}
			_load_overrides[&"lighting"] = float(_failure_restore[component.component_id]["value"]) * 1.5
		_:
			pass


func _scale_generator(generator_id: StringName, factor: float, component_id: StringName) -> void:
	var generator_key: Variant = _find_generator_key(generator_id)
	if generator_key == null:
		return
	if not _failure_restore.has(component_id):
		_failure_restore[component_id] = {
			"kind": "generator",
			"target": String(generator_id),
			"value": float(generators[generator_key]),
		}
	generators[generator_key] = float(_failure_restore[component_id]["value"]) * factor


func _restore_failure_effect(component_id: StringName) -> void:
	if not _failure_restore.has(component_id):
		return
	var restore: Dictionary = _failure_restore[component_id]
	match String(restore.get("kind", "")):
		"generator":
			var generator_key: Variant = _find_generator_key(StringName(String(restore.get("target", ""))))
			if generator_key != null:
				generators[generator_key] = float(restore.get("value", 0.0))
		"battery_capacity_wh":
			battery_capacity_wh = maxf(float(restore.get("value", battery_capacity_wh)), 0.0)
			battery_charge_wh = clampf(battery_charge_wh, 0.0, battery_capacity_wh)
		"battery_max_discharge_w":
			battery_max_discharge_w = maxf(float(restore.get("value", battery_max_discharge_w)), 0.0)
		"load_override":
			var override_id: StringName = StringName(String(restore.get("target", "")))
			if override_id != &"":
				_load_overrides.erase(override_id)
		_:
			pass
	_failure_restore.erase(component_id)


func _find_generator_key(generator_id: StringName) -> Variant:
	if generators.has(generator_id):
		return generator_id
	for key: Variant in generators:
		if String(key) == String(generator_id):
			return key
	return null


func _emit_component_failed(component_id: StringName, failure_mode_id: StringName) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_failed", component_id, failure_mode_id)
	emit_sim_event(&"component_failed", {"component_id": component_id, "failure_mode_id": failure_mode_id})


func _emit_component_repaired(component_id: StringName, quality: float) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_repaired", component_id, quality)
	emit_sim_event(&"component_repaired", {"component_id": component_id, "quality": quality})


func _emit_condition_crossings(component: WearComponent) -> void:
	var bucket: int = _condition_bucket_for(component.condition)
	if not _condition_bucket.has(component.component_id):
		_condition_bucket[component.component_id] = bucket
		return
	if bucket >= int(_condition_bucket[component.component_id]):
		_condition_bucket[component.component_id] = bucket
		return
	_condition_bucket[component.component_id] = bucket
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_condition_changed", component.component_id, component.condition)


func _condition_bucket_for(condition: float) -> int:
	return int(floor(clampf(condition, 0.0, 1.0) * 10.0 + 1e-9))


func _reapply_failed_effects() -> void:
	for component: WearComponent in wear_components:
		if component != null and component.is_failed():
			_apply_failure_effect(component, component.failed_mode)


func _load_wear(entries: Variant) -> void:
	if not (entries is Array):
		return
	for entry: Variant in (entries as Array):
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		var component: WearComponent = _find_wear_component(StringName(String(data.get("component_id", ""))))
		if component == null:
			continue
		component.condition = clampf(float(data.get("condition", component.condition)), 0.0, 1.0)
		component.hours_operated = maxf(float(data.get("hours_operated", component.hours_operated)), 0.0)
		component.load = float(data.get("load", component.load))
		component.failed_mode = StringName(String(data.get("failed_mode", "")))
		component.diagnosed = bool(data.get("diagnosed", false))
		component.scanned = bool(data.get("scanned", false))
		_condition_bucket[component.component_id] = _condition_bucket_for(component.condition)


func _load_failure_restore(saved: Variant) -> void:
	_failure_restore.clear()
	if not (saved is Dictionary):
		return
	for key: Variant in (saved as Dictionary):
		var entry: Variant = (saved as Dictionary)[key]
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		_failure_restore[StringName(String(key))] = {
			"kind": String(data.get("kind", "")),
			"target": String(data.get("target", "")),
			"value": float(data.get("value", 0.0)),
		}


func _wear_save_entries() -> Array:
	var entries: Array = []
	for component: WearComponent in wear_components:
		if component == null:
			continue
		entries.append({
			"component_id": String(component.component_id),
			"condition": component.condition,
			"hours_operated": component.hours_operated,
			"load": component.load,
			"failed_mode": String(component.failed_mode),
			"diagnosed": component.diagnosed,
			"scanned": component.scanned,
		})
	return entries


func _failure_restore_save() -> Dictionary:
	var saved: Dictionary = {}
	for component_id: Variant in _failure_restore:
		var entry: Dictionary = _failure_restore[component_id]
		saved[String(component_id)] = {
			"kind": String(entry.get("kind", "")),
			"target": String(entry.get("target", "")),
			"value": float(entry.get("value", 0.0)),
		}
	return saved
