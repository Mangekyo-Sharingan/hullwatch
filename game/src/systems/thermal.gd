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

var _compartments: Dictionary = {}


func _ready() -> void:
	system_id = &"thermal"
	add_to_group(&"thermal_system")
	super._ready()
	for config: CompartmentConfig in compartment_defs:
		add_compartment(config)


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("ThermalSystem.sim_tick: delta_hours must be finite and positive.")
		return
	var atmosphere: Node = _first_node_in_group(&"atmosphere_system")
	var power: Node = _first_node_in_group(&"power_system")
	var heater_available: bool = _is_heater_available(power)
	for compartment_id: StringName in _compartments:
		var state: Dictionary = _compartments[compartment_id]
		state["occupants"] = _read_occupants(atmosphere, compartment_id)
		_tick_compartment(state, delta_hours, heater_available)
	for compartment_id: StringName in _compartments:
		_emit_changes(compartment_id)


func has_compartment(compartment_id: StringName) -> bool:
	return _compartments.has(compartment_id)


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
	return {"system_id": "thermal", "state_version": 1, "compartments": compartments}


func load_state(state: Dictionary) -> void:
	if not (state.get("compartments") is Dictionary):
		return
	var compartments: Dictionary = state["compartments"]
	for key: Variant in compartments:
		var compartment_id: StringName = StringName(String(key))
		if not _compartments.has(compartment_id):
			continue
		if not (compartments[key] is Dictionary):
			continue
		var saved: Dictionary = compartments[key]
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


func _create_state(config: CompartmentConfig) -> Dictionary:
	var temperature_c: float = config.initial_temperature_c
	return {
		"config": config,
		"temperature_c": temperature_c,
		"heater_powered": true,
		"heater_on": false,
		"constant_gain_w": 0.0,
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
	var temperature_c: float = float(state["temperature_c"])
	if bool(state["heater_on"]):
		if temperature_c >= config.heater_target_c:
			state["heater_on"] = false
	elif temperature_c < config.heater_target_c - config.heater_deadband_c:
		state["heater_on"] = true


func _heat_input_w(state: Dictionary, config: CompartmentConfig) -> float:
	var heater_w: float = config.heater_watts if bool(state["heater_on"]) else 0.0
	return heater_w + float(state["occupants"]) * config.occupant_heat_w + float(state["constant_gain_w"])


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


func _require_state(compartment_id: StringName, method_name: String) -> Dictionary:
	if not _compartments.has(compartment_id):
		push_error("ThermalSystem.%s: unknown compartment_id '%s'." % [method_name, String(compartment_id)])
		return {}
	return _compartments[compartment_id]
