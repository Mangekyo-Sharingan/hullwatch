## Deterministic per-compartment life-support simulator: O2, CO2, pressure, leaks, scrubbing, candles.
class_name AtmosphereSystem
extends ShipSystem

const R_GAS: float = 8.314462618
const PA_PER_KPA: float = 1000.0
const MOLAR_MASS_O2: float = 0.032
const MOLAR_MASS_CO2: float = 0.044
const MOLAR_MASS_N2: float = 0.028
const TEMP_K: float = 293.15
const O2_KG_PER_HOUR_PER_OCCUPANT: float = 0.035
const CO2_KG_PER_HOUR_PER_OCCUPANT: float = 0.042
const MIX_RATE_PER_HOUR: float = 6.0
const PRESSURE_EMIT_DELTA_KPA: float = 0.05
const CO2_EMIT_DELTA_PPM: float = 25.0
const O2_EMIT_DELTA_FRACTION: float = 0.001

@export var compartment_defs: Array[CompartmentConfig] = []
@export var wear_components: Array[WearComponent] = []
@export var wear_seed: int = 20260919

var _compartments: Dictionary = {}
var _connections: Dictionary = {}
var _efficiency_multiplier: float = 1.0
var _rng: RandomNumberGenerator
var _condition_bucket: Dictionary = {}


func _ready() -> void:
	system_id = &"atmosphere"
	add_to_group(&"atmosphere_system")
	_wear_rng()
	super._ready()
	for config: CompartmentConfig in compartment_defs:
		add_compartment(config)


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("AtmosphereSystem.sim_tick: delta_hours must be finite and positive.")
		return
	_tick_wear(delta_hours)
	for compartment_id: StringName in _compartments:
		_tick_compartment(compartment_id, delta_hours)
	_mix_connected(delta_hours)
	for compartment_id: StringName in _compartments:
		_emit_changes(compartment_id)


func add_compartment(config: CompartmentConfig) -> bool:
	if config == null or config.compartment_id == &"":
		push_error("AtmosphereSystem.add_compartment: config must be non-null with a non-empty compartment_id.")
		return false
	if _compartments.has(config.compartment_id):
		push_error("AtmosphereSystem.add_compartment: duplicate compartment_id '%s'." % String(config.compartment_id))
		return false
	if config.volume_m3 <= 0.0 or not is_finite(config.volume_m3):
		push_error("AtmosphereSystem.add_compartment: volume_m3 must be finite and positive.")
		return false
	_compartments[config.compartment_id] = _create_state(config)
	return true


func has_compartment(compartment_id: StringName) -> bool:
	return _compartments.has(compartment_id)


func get_compartment_status(compartment_id: StringName) -> Dictionary:
	if not _compartments.has(compartment_id):
		push_error("AtmosphereSystem.get_compartment_status: unknown compartment_id '%s'." % String(compartment_id))
		return {}
	return _status_for(_compartments[compartment_id])


func set_occupants(compartment_id: StringName, count: int) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_occupants")
	if state.is_empty():
		return
	state["occupants"] = maxi(count, 0)


func set_scrubber_powered(compartment_id: StringName, powered: bool) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_scrubber_powered")
	if state.is_empty():
		return
	state["scrubber_powered"] = powered


func set_scrubber_efficiency(compartment_id: StringName, efficiency: float) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_scrubber_efficiency")
	if state.is_empty():
		return
	state["scrubber_efficiency"] = clampf(efficiency, 0.0, 1.0)


func set_isolated(compartment_id: StringName, isolated: bool) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_isolated")
	if state.is_empty():
		return
	state["isolated"] = isolated


func set_leak_rate(compartment_id: StringName, rate_per_hour: float) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_leak_rate")
	if state.is_empty():
		return
	if not is_finite(rate_per_hour) or rate_per_hour < 0.0:
		push_error("AtmosphereSystem.set_leak_rate: rate_per_hour must be finite and non-negative.")
		return
	state["leak_rate_per_hour"] = rate_per_hour


func light_o2_candle(compartment_id: StringName) -> bool:
	var state: Dictionary = _require_state(compartment_id, "light_o2_candle")
	if state.is_empty():
		return false
	var remaining: int = state["candles_remaining"]
	if remaining <= 0:
		return false
	var config: CompartmentConfig = state["config"]
	state["candles_remaining"] = remaining - 1
	state["candle_burn_remaining_hours"] = float(state["candle_burn_remaining_hours"]) + config.o2_candle_burn_hours
	emit_sim_event(&"o2_candle_lit", {"compartment_id": compartment_id, "remaining": remaining - 1})
	return true


func set_filter_installed(compartment_id: StringName, installed: bool) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_filter_installed")
	if state.is_empty():
		return
	state["filter_installed"] = installed


func set_filter_condition(compartment_id: StringName, condition: float) -> void:
	var state: Dictionary = _require_state(compartment_id, "set_filter_condition")
	if state.is_empty():
		return
	if not is_finite(condition):
		push_error("AtmosphereSystem.set_filter_condition: condition must be finite.")
		return
	state["filter_condition"] = clampf(condition, 0.0, 1.0)


func get_filter_condition(compartment_id: StringName) -> float:
	var state: Dictionary = _require_state(compartment_id, "get_filter_condition")
	if state.is_empty():
		return 0.0
	return float(state["filter_condition"])


func connect_compartments(a: StringName, b: StringName) -> void:
	if a == b or not _compartments.has(a) or not _compartments.has(b):
		push_error("AtmosphereSystem.connect_compartments: unknown or identical compartment ids.")
		return
	_add_neighbor(a, b)
	_add_neighbor(b, a)


func get_status() -> Dictionary:
	var compartments: Dictionary = {}
	for compartment_id: StringName in _compartments:
		compartments[compartment_id] = _status_for(_compartments[compartment_id])
	return {"system_id": system_id, "compartments": compartments}


func repair_component(component_id: StringName, quality: float) -> bool:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null:
		push_error("AtmosphereSystem.repair_component: unknown component_id '%s'." % String(component_id))
		return false
	component.apply_repair(quality)
	_recompute_efficiency_multiplier()
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
		push_error("AtmosphereSystem.force_failure: unknown component_id '%s' or empty failure_mode_id." % String(component_id))
		return false
	if component.is_failed():
		return false
	component.failed_mode = failure_mode_id
	_apply_failure_effect(failure_mode_id)
	_emit_component_failed(component.component_id, failure_mode_id)
	return true


func _create_state(config: CompartmentConfig) -> Dictionary:
	var n_total: float = config.initial_pressure_kpa * PA_PER_KPA * config.volume_m3 / (R_GAS * TEMP_K)
	var o2_fraction: float = clampf(config.initial_o2_fraction, 0.0, 1.0)
	var co2_fraction: float = maxf(config.initial_co2_ppm, 0.0) * 1e-6
	var n_o2: float = n_total * o2_fraction
	var n_co2: float = n_total * co2_fraction
	var n_n2: float = maxf(n_total - n_o2 - n_co2, 0.0)
	var state: Dictionary = {
		"config": config,
		"n_o2": n_o2,
		"n_co2": n_co2,
		"n_n2": n_n2,
		"occupants": maxi(config.initial_occupants, 0),
		"scrubber_powered": false,
		"scrubber_efficiency": 1.0,
		"isolated": false,
		"leak_rate_per_hour": config.leak_rate_per_hour,
		"candles_remaining": maxi(config.o2_candles_stocked, 0),
		"candle_burn_remaining_hours": 0.0,
		"filter_condition": clampf(config.initial_filter_condition, 0.0, 1.0),
		"filter_installed": true,
	}
	state["last_pressure_kpa"] = _pressure_for(state)
	state["last_o2_fraction"] = _o2_fraction_for(state)
	state["last_co2_ppm"] = _co2_ppm_for(state)
	return state


func _tick_compartment(compartment_id: StringName, hours: float) -> void:
	var state: Dictionary = _compartments[compartment_id]
	var config: CompartmentConfig = state["config"]
	var occupants: int = state["occupants"]
	if occupants > 0:
		var o2_mol: float = float(occupants) * O2_KG_PER_HOUR_PER_OCCUPANT / MOLAR_MASS_O2 * hours
		var co2_mol: float = float(occupants) * CO2_KG_PER_HOUR_PER_OCCUPANT / MOLAR_MASS_CO2 * hours
		state["n_o2"] = maxf(float(state["n_o2"]) - o2_mol, 0.0)
		state["n_co2"] = maxf(float(state["n_co2"]) + co2_mol, 0.0)
	if bool(state["scrubber_powered"]) and bool(state["filter_installed"]):
		var efficiency: float = float(state["scrubber_efficiency"]) * float(state["filter_condition"]) * _efficiency_multiplier
		var capacity_mol: float = config.scrubber_capacity_kg_per_hour * efficiency * hours / MOLAR_MASS_CO2
		state["n_co2"] = maxf(float(state["n_co2"]) - minf(capacity_mol, float(state["n_co2"])), 0.0)
		state["filter_condition"] = maxf(float(state["filter_condition"]) - config.filter_wear_rate_per_hour * hours, 0.0)
	var remaining_burn: float = float(state["candle_burn_remaining_hours"])
	if remaining_burn > 0.0:
		var burn_hours: float = minf(hours, remaining_burn)
		var candle_kg_per_hour: float = config.o2_candle_kg / maxf(config.o2_candle_burn_hours, 0.001)
		state["n_o2"] = maxf(float(state["n_o2"]) + candle_kg_per_hour * burn_hours / MOLAR_MASS_O2, 0.0)
		state["candle_burn_remaining_hours"] = remaining_burn - burn_hours
	var leak_rate: float = float(state["leak_rate_per_hour"])
	if leak_rate > 0.0:
		var factor: float = exp(-leak_rate * hours)
		state["n_o2"] = maxf(float(state["n_o2"]) * factor, 0.0)
		state["n_co2"] = maxf(float(state["n_co2"]) * factor, 0.0)
		state["n_n2"] = maxf(float(state["n_n2"]) * factor, 0.0)


func _mix_connected(hours: float) -> void:
	var factor: float = 1.0 - exp(-MIX_RATE_PER_HOUR * hours)
	for id_a: StringName in _connections:
		var neighbors: Array[StringName] = _connections[id_a]
		for id_b: StringName in neighbors:
			if String(id_a) >= String(id_b) or not _compartments.has(id_b):
				continue
			var state_a: Dictionary = _compartments[id_a]
			var state_b: Dictionary = _compartments[id_b]
			if bool(state_a["isolated"]) or bool(state_b["isolated"]):
				continue
			_transfer_species(state_a, state_b, "n_o2", factor)
			_transfer_species(state_a, state_b, "n_co2", factor)
			_transfer_species(state_a, state_b, "n_n2", factor)


func _transfer_species(state_a: Dictionary, state_b: Dictionary, key: String, factor: float) -> void:
	var config_a: CompartmentConfig = state_a["config"]
	var config_b: CompartmentConfig = state_b["config"]
	var volume_a: float = config_a.volume_m3
	var volume_b: float = config_b.volume_m3
	var equilibrium_move: float = (float(state_a[key]) * volume_b - float(state_b[key]) * volume_a) / (volume_a + volume_b)
	if equilibrium_move == 0.0:
		return
	var moved: float = equilibrium_move * factor
	state_a[key] = float(state_a[key]) - moved
	state_b[key] = float(state_b[key]) + moved


func _emit_changes(compartment_id: StringName) -> void:
	var state: Dictionary = _compartments[compartment_id]
	var pressure_kpa: float = _pressure_for(state)
	if absf(pressure_kpa - float(state["last_pressure_kpa"])) >= PRESSURE_EMIT_DELTA_KPA:
		state["last_pressure_kpa"] = pressure_kpa
		_emit_pressure_changed(compartment_id, pressure_kpa)
	var o2_fraction: float = _o2_fraction_for(state)
	var co2_ppm: float = _co2_ppm_for(state)
	var co2_delta: float = absf(co2_ppm - float(state["last_co2_ppm"]))
	var o2_delta: float = absf(o2_fraction - float(state["last_o2_fraction"]))
	if co2_delta >= CO2_EMIT_DELTA_PPM or o2_delta >= O2_EMIT_DELTA_FRACTION:
		state["last_co2_ppm"] = co2_ppm
		state["last_o2_fraction"] = o2_fraction
		_emit_atmosphere_changed(compartment_id, o2_fraction, co2_ppm)


func _status_for(state: Dictionary) -> Dictionary:
	var config: CompartmentConfig = state["config"]
	return {
		"compartment_id": config.compartment_id,
		"pressure_kpa": _pressure_for(state),
		"o2_fraction": _o2_fraction_for(state),
		"co2_ppm": _co2_ppm_for(state),
		"occupants": state["occupants"],
		"scrubber_powered": state["scrubber_powered"],
		"scrubber_efficiency": state["scrubber_efficiency"],
		"leak_rate_per_hour": state["leak_rate_per_hour"],
		"isolated": state["isolated"],
		"candles_remaining": state["candles_remaining"],
		"candle_burn_remaining_hours": state["candle_burn_remaining_hours"],
		"filter_condition": state["filter_condition"],
		"filter_installed": state["filter_installed"],
	}


func _require_state(compartment_id: StringName, method_name: String) -> Dictionary:
	if not _compartments.has(compartment_id):
		push_error("AtmosphereSystem.%s: unknown compartment_id '%s'." % [method_name, String(compartment_id)])
		return {}
	return _compartments[compartment_id]


func _add_neighbor(a: StringName, b: StringName) -> void:
	if not _connections.has(a):
		var empty: Array[StringName] = []
		_connections[a] = empty
	var neighbors: Array[StringName] = _connections[a]
	if not neighbors.has(b):
		neighbors.append(b)


func _total_moles(state: Dictionary) -> float:
	return maxf(float(state["n_o2"]) + float(state["n_co2"]) + float(state["n_n2"]), 0.0)


func _pressure_for(state: Dictionary) -> float:
	var config: CompartmentConfig = state["config"]
	return _total_moles(state) * R_GAS * TEMP_K / config.volume_m3 / PA_PER_KPA


func _o2_fraction_for(state: Dictionary) -> float:
	var total: float = _total_moles(state)
	if total <= 0.0:
		return 0.0
	return clampf(float(state["n_o2"]) / total, 0.0, 1.0)


func _co2_ppm_for(state: Dictionary) -> float:
	var total: float = _total_moles(state)
	if total <= 0.0:
		return 0.0
	return float(state["n_co2"]) / total * 1e6


func _emit_pressure_changed(compartment_id: StringName, pressure_kpa: float) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"compartment_pressure_changed", compartment_id, pressure_kpa)


func _emit_atmosphere_changed(compartment_id: StringName, o2_fraction: float, co2_ppm: float) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"compartment_atmosphere_changed", compartment_id, o2_fraction, co2_ppm)


func save_state() -> Dictionary:
	var compartments: Dictionary = {}
	for compartment_id: StringName in _compartments:
		var state: Dictionary = _compartments[compartment_id]
		compartments[String(compartment_id)] = {
			"n_o2": float(state["n_o2"]),
			"n_co2": float(state["n_co2"]),
			"n_n2": float(state["n_n2"]),
			"occupants": int(state["occupants"]),
			"scrubber_powered": bool(state["scrubber_powered"]),
			"scrubber_efficiency": float(state["scrubber_efficiency"]),
			"isolated": bool(state["isolated"]),
			"leak_rate_per_hour": float(state["leak_rate_per_hour"]),
			"candles_remaining": int(state["candles_remaining"]),
			"candle_burn_remaining_hours": float(state["candle_burn_remaining_hours"]),
			"filter_condition": float(state["filter_condition"]),
			"filter_installed": bool(state["filter_installed"]),
			"last_pressure_kpa": float(state["last_pressure_kpa"]),
			"last_o2_fraction": float(state["last_o2_fraction"]),
			"last_co2_ppm": float(state["last_co2_ppm"]),
		}
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"compartments": compartments,
		"wear": _wear_save_entries(),
		"wear_rng_state": str(_wear_rng().state),
		"efficiency_multiplier": _efficiency_multiplier,
	}


func load_state(state: Dictionary) -> void:
	var compartments: Dictionary = state.get("compartments", {})
	for compartment_id: StringName in _compartments:
		var key: String = String(compartment_id)
		if not compartments.has(key):
			continue
		var loaded: Dictionary = compartments[key]
		var target: Dictionary = _compartments[compartment_id]
		for field_name: Variant in ["n_o2", "n_co2", "n_n2", "scrubber_efficiency", "leak_rate_per_hour", "candle_burn_remaining_hours", "filter_condition", "last_pressure_kpa", "last_o2_fraction", "last_co2_ppm"]:
			if loaded.has(field_name):
				target[field_name] = float(loaded[field_name])
		for field_name: Variant in ["occupants", "candles_remaining"]:
			if loaded.has(field_name):
				target[field_name] = int(loaded[field_name])
		for field_name: Variant in ["scrubber_powered", "isolated", "filter_installed"]:
			if loaded.has(field_name):
				target[field_name] = bool(loaded[field_name])
	_load_wear(state.get("wear", []))
	if state.has("wear_rng_state"):
		var rng: RandomNumberGenerator = _wear_rng()
		rng.state = int(state.get("wear_rng_state", rng.state))
	if state.has("efficiency_multiplier"):
		_efficiency_multiplier = clampf(float(state.get("efficiency_multiplier", 1.0)), 0.0, 1.0)
	else:
		_recompute_efficiency_multiplier()


func _tick_wear(delta_hours: float) -> void:
	if wear_components.is_empty():
		return
	var environment: Dictionary = {
		"heat": _heat_factor(),
		"load": _scrubber_duty(),
		"vibration": 0.0,
	}
	for component: WearComponent in wear_components:
		if component == null:
			continue
		var failed_mode_id: StringName = component.tick_sim(delta_hours, environment, _wear_rng())
		if failed_mode_id != &"":
			_apply_failure_effect(failed_mode_id)
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


func _scrubber_duty() -> float:
	for compartment_id: StringName in _compartments:
		if bool(_compartments[compartment_id]["scrubber_powered"]):
			return 1.0
	return 0.0


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


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)


func _apply_failure_effect(failure_mode_id: StringName) -> void:
	match failure_mode_id:
		&"bearing_whine":
			_efficiency_multiplier = 0.5
		&"blower_seize":
			_efficiency_multiplier = 0.0
		_:
			pass


func _recompute_efficiency_multiplier() -> void:
	var multiplier: float = 1.0
	for component: WearComponent in wear_components:
		if component == null or not component.is_failed():
			continue
		match component.failed_mode:
			&"bearing_whine":
				multiplier = minf(multiplier, 0.5)
			&"blower_seize":
				multiplier = minf(multiplier, 0.0)
			_:
				pass
	_efficiency_multiplier = multiplier


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
		_condition_bucket[component.component_id] = _condition_bucket_for(component.condition)


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
		})
	return entries
