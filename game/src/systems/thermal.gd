## Deterministic per-compartment thermal simulator: hull losses, bang-bang heaters, occupant heat.
class_name ThermalSystem
extends ShipSystem

const LIFE_SUPPORT_CIRCUIT: StringName = &"life_support"
const SECONDS_PER_HOUR: float = 3600.0
const TEMPERATURE_EMIT_DELTA_C: float = 0.1
# Matches SimClock's 6 s tick so explicit Euler stays stable for any delta_hours.
const MAX_STEP_HOURS: float = 1.0 / 600.0

@export var compartment_defs: Array[CompartmentConfig] = []
@export var exterior_temp_c: float = -60.0
@export var wear_components: Array[WearComponent] = []
@export var wear_seed: int = 20260921

var _compartments: Dictionary = {}
var _heat_sources: Dictionary = {}
var _rng: RandomNumberGenerator
var _condition_bucket: Dictionary = {}
var _failure_restore: Dictionary = {}
var _heater_output_factor: float = 1.0
var _target_offset_c: float = 0.0
var _heater_active_this_tick: bool = false


func _ready() -> void:
	system_id = &"thermal"
	add_to_group(&"thermal_system")
	_wear_rng()
	super._ready()
	for config: CompartmentConfig in compartment_defs:
		add_compartment(config)


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("ThermalSystem.sim_tick: delta_hours must be finite and positive.")
		return
	_heater_active_this_tick = false
	var atmosphere: Node = _first_node_in_group(&"atmosphere_system")
	var power: Node = _first_node_in_group(&"power_system")
	var heater_available: bool = _is_heater_available(power)
	for compartment_id: StringName in _compartments:
		var state: Dictionary = _compartments[compartment_id]
		state["occupants"] = _read_occupants(atmosphere, compartment_id)
		_tick_compartment(state, delta_hours, heater_available)
	_tick_wear(delta_hours)
	for compartment_id: StringName in _compartments:
		_emit_changes(compartment_id)


func has_compartment(compartment_id: StringName) -> bool:
	return _compartments.has(compartment_id)


func remove_compartment(compartment_id: StringName) -> bool:
	if not _compartments.has(compartment_id):
		return false
	_compartments.erase(compartment_id)
	return true


func get_compartment_status(compartment_id: StringName) -> Dictionary:
	if not _compartments.has(compartment_id):
		push_error("ThermalSystem.get_compartment_status: unknown compartment_id '%s'." % String(compartment_id))
		return {}
	var state: Dictionary = _compartments[compartment_id]
	var config: CompartmentConfig = state["config"]
	var temperature_c: float = float(state["temperature_c"])
	return {
		"compartment_id": config.compartment_id,
		"temperature_c": temperature_c,
		"heater_powered": bool(state["heater_powered"]),
		"heater_active": bool(state["heater_on"]),
		"heat_input_w": _heat_input_w(state, config),
		"heat_loss_w": config.hull_conductance_w_per_k * (temperature_c - exterior_temp_c),
		"freeze_risk": temperature_c <= config.freeze_threshold_c,
		"occupants": int(state["occupants"]),
	}


func get_temperature(compartment_id: StringName) -> float:
	var state: Dictionary = _require_state(compartment_id, "get_temperature")
	if state.is_empty():
		return 0.0
	return float(state["temperature_c"])


func set_heater_powered(compartment_id: StringName, powered: bool) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_heater_powered")
	if state.is_empty():
		return
	state["heater_powered"] = powered
	if not powered:
		state["heater_on"] = false


func set_heat_gain(compartment_id: StringName, watts: float) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_heat_gain")
	if state.is_empty():
		return
	if not is_finite(watts) or watts < 0.0:
		push_error("ThermalSystem.set_heat_gain: watts must be finite and non-negative.")
		return
	state["constant_gain_w"] = watts


func set_heat_source_gain(compartment_id: StringName, source_id: StringName, watts: float) -> void:
	if not _compartments.has(compartment_id) or not is_finite(watts) or watts < 0.0 or source_id == &"":
		return
	if not _heat_sources.has(compartment_id):
		_heat_sources[compartment_id] = {}
	var sources: Dictionary = _heat_sources[compartment_id]
	if watts == 0.0:
		sources.erase(source_id)
	else:
		sources[source_id] = watts


func add_compartment(config: CompartmentConfig) -> bool:
	if config == null or config.compartment_id == &"":
		push_error("ThermalSystem.add_compartment: config must be non-null with a non-empty compartment_id.")
		return false
	if _compartments.has(config.compartment_id):
		push_error("ThermalSystem.add_compartment: duplicate compartment_id '%s'." % String(config.compartment_id))
		return false
	if not is_finite(config.thermal_capacity_j_per_k) or config.thermal_capacity_j_per_k <= 0.0:
		push_error("ThermalSystem.add_compartment: thermal_capacity_j_per_k must be finite and positive.")
		return false
	_compartments[config.compartment_id] = _create_state(config)
	return true


func repair_component(component_id: StringName, quality: float) -> bool:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null:
		push_error("ThermalSystem.repair_component: unknown component_id '%s'." % String(component_id))
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
		push_error("ThermalSystem.force_failure: unknown component_id '%s' or empty failure_mode_id." % String(component_id))
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
		push_error("ThermalSystem.diagnose_component: unknown component_id '%s'." % String(component_id))
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


func save_state() -> Dictionary:
	var compartments: Dictionary = {}
	for compartment_id: StringName in _compartments:
		var state: Dictionary = _compartments[compartment_id]
		compartments[String(compartment_id)] = {
			"temperature_c": float(state["temperature_c"]),
			"heater_powered": bool(state["heater_powered"]),
			"heater_on": bool(state["heater_on"]),
			"constant_gain_w": float(state["constant_gain_w"]),
		}
	return {
		"maintenance_covers": maintenance_covers.duplicate(),
		"system_id": "thermal",
		"state_version": 1,
		"compartments": compartments,
		"wear": _wear_save_entries(),
		"wear_rng_state": str(_wear_rng().state),
		"failure_restore": _failure_restore_save(),
	}


func load_state(state: Dictionary) -> void:
	restore_maintenance_covers(state)
	var compartments: Variant = state.get("compartments", {})
	if compartments is Dictionary:
		for key: Variant in (compartments as Dictionary):
			var compartment_id: StringName = StringName(String(key))
			if not _compartments.has(compartment_id):
				continue
			if not ((compartments as Dictionary)[key] is Dictionary):
				continue
			var saved: Dictionary = (compartments as Dictionary)[key]
			var compartment_state: Dictionary = _compartments[compartment_id]
			if saved.has("temperature_c"):
				compartment_state["temperature_c"] = float(saved["temperature_c"])
			if saved.has("heater_powered"):
				compartment_state["heater_powered"] = bool(saved["heater_powered"])
			if saved.has("heater_on"):
				compartment_state["heater_on"] = bool(saved["heater_on"])
			if saved.has("constant_gain_w"):
				compartment_state["constant_gain_w"] = float(saved["constant_gain_w"])
			var config: CompartmentConfig = compartment_state["config"]
			var temperature_c: float = float(compartment_state["temperature_c"])
			compartment_state["last_temperature_c"] = temperature_c
			compartment_state["last_freeze_risk"] = temperature_c <= config.freeze_threshold_c
	_load_wear(state.get("wear", []))
	_load_failure_restore(state.get("failure_restore", {}))
	if state.has("wear_rng_state"):
		var rng: RandomNumberGenerator = _wear_rng()
		rng.state = int(state.get("wear_rng_state", rng.state))
	_reapply_failed_effects()


func _create_state(config: CompartmentConfig) -> Dictionary:
	var temperature_c: float = config.initial_temperature_c
	return {
		"config": config,
		"temperature_c": temperature_c,
		"heater_powered": true,
		"heater_on": false,
		"constant_gain_w": config.initial_heat_gain_w,
		"occupants": maxi(config.initial_occupants, 0),
		"last_temperature_c": temperature_c,
		"last_freeze_risk": temperature_c <= config.freeze_threshold_c,
	}


func _tick_compartment(state: Dictionary, delta_hours: float, heater_available: bool) -> void:
	var config: CompartmentConfig = state["config"]
	var steps: int = maxi(1, ceili(delta_hours / MAX_STEP_HOURS))
	var step_hours: float = delta_hours / float(steps)
	for _step: int in steps:
		_update_heater(state, config, heater_available)
		var temperature_c: float = float(state["temperature_c"])
		var heat_input_w: float = _heat_input_w(state, config)
		var heat_loss_w: float = config.hull_conductance_w_per_k * (temperature_c - exterior_temp_c)
		state["temperature_c"] = temperature_c + (heat_input_w - heat_loss_w) * step_hours * SECONDS_PER_HOUR / config.thermal_capacity_j_per_k


func _update_heater(state: Dictionary, config: CompartmentConfig, heater_available: bool) -> void:
	if not bool(state["heater_powered"]) or not heater_available:
		state["heater_on"] = false
		return
	var target_c: float = config.heater_target_c + _target_offset_c
	var temperature_c: float = float(state["temperature_c"])
	if bool(state["heater_on"]):
		if temperature_c >= target_c:
			state["heater_on"] = false
	elif temperature_c < target_c - config.heater_deadband_c:
		state["heater_on"] = true
	if bool(state["heater_on"]):
		_heater_active_this_tick = true


func _heat_input_w(state: Dictionary, config: CompartmentConfig) -> float:
	var heater_w: float = config.heater_watts * _heater_output_factor if bool(state["heater_on"]) else 0.0
	var source_w: float = 0.0
	for watts: Variant in (_heat_sources.get(config.compartment_id, {}) as Dictionary).values():
		source_w += float(watts)
	return heater_w + float(state["occupants"]) * config.occupant_heat_w + float(state["constant_gain_w"]) + source_w


func _emit_changes(compartment_id: StringName) -> void:
	var state: Dictionary = _compartments[compartment_id]
	var config: CompartmentConfig = state["config"]
	var temperature_c: float = float(state["temperature_c"])
	if absf(temperature_c - float(state["last_temperature_c"])) >= TEMPERATURE_EMIT_DELTA_C:
		state["last_temperature_c"] = temperature_c
		emit_sim_event(&"compartment_temperature_changed", {"compartment_id": compartment_id, "temperature_c": temperature_c})
	var freeze_risk: bool = temperature_c <= config.freeze_threshold_c
	if freeze_risk != bool(state["last_freeze_risk"]):
		state["last_freeze_risk"] = freeze_risk
		emit_sim_event(&"compartment_freeze_risk", {"compartment_id": compartment_id, "active": freeze_risk})


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)


func _is_heater_available(power: Node) -> bool:
	if power == null or not power.has_method("is_breaker_on") or not power.has_method("is_circuit_shed"):
		return true
	if power.has_method("has_circuit") and not bool(power.call("has_circuit", LIFE_SUPPORT_CIRCUIT)):
		return false
	return bool(power.call("is_breaker_on", LIFE_SUPPORT_CIRCUIT)) and not bool(power.call("is_circuit_shed", LIFE_SUPPORT_CIRCUIT))


func _read_occupants(atmosphere: Node, compartment_id: StringName) -> int:
	if atmosphere == null or not atmosphere.has_method("get_compartment_status"):
		return 0
	if atmosphere.has_method("has_compartment") and not bool(atmosphere.call("has_compartment", compartment_id)):
		return 0
	var status: Variant = atmosphere.call("get_compartment_status", compartment_id)
	if not (status is Dictionary):
		return 0
	var status_dict: Dictionary = status
	if not status_dict.has("occupants"):
		return 0
	return int(status_dict["occupants"])


func _tick_wear(delta_hours: float) -> void:
	if wear_components.is_empty():
		return
	var environment: Dictionary = {
		"heat": 0.0,
		"load": 1.0 if _heater_active_this_tick else 0.0,
		"vibration": 0.0,
	}
	for component: WearComponent in wear_components:
		if component == null:
			continue
		var failed_mode_id: StringName = component.tick_sim(delta_hours, environment, _wear_rng())
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


func _apply_failure_effect(component: WearComponent, failure_mode_id: StringName) -> void:
	match failure_mode_id:
		&"heater_open":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "heater_output_factor", "target": "", "value": _heater_output_factor}
			_heater_output_factor = 0.0
		&"sensor_drift":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "target_offset_c", "target": "", "value": _target_offset_c}
			_target_offset_c = -8.0
		_:
			pass


func _restore_failure_effect(component_id: StringName) -> void:
	if not _failure_restore.has(component_id):
		return
	var restore: Dictionary = _failure_restore[component_id]
	match String(restore.get("kind", "")):
		"heater_output_factor":
			_heater_output_factor = maxf(float(restore.get("value", _heater_output_factor)), 0.0)
		"target_offset_c":
			_target_offset_c = float(restore.get("value", _target_offset_c))
		_:
			pass
	_failure_restore.erase(component_id)


func _reapply_failed_effects() -> void:
	_heater_output_factor = 1.0
	_target_offset_c = 0.0
	for component: WearComponent in wear_components:
		if component != null and component.is_failed():
			_apply_failure_effect(component, component.failed_mode)


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


func _require_state(compartment_id: StringName, method_name: String) -> Dictionary:
	if not _compartments.has(compartment_id):
		push_error("ThermalSystem.%s: unknown compartment_id '%s'." % [method_name, String(compartment_id)])
		return {}
	return _compartments[compartment_id]
