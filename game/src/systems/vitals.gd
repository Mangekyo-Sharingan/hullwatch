## Deterministic operator physiology simulator: breathing atmosphere and cold exposure drive condition, incapacitation, and cognition.
class_name VitalsSystem
extends ShipSystem

const CONDITION_EMIT_DELTA: float = 0.05
const MILD_DAMAGE_SCALE: float = 0.25

@export var o2_breathing_threshold: float = 0.16
@export var co2_breathing_ppm: float = 25000.0
@export var cold_threshold_c: float = 10.0
@export var cold_severe_c: float = 3.0
@export var damage_per_hour: float = 0.4
@export var recovery_per_hour: float = 0.25
@export var cognition_co2_ppm: float = 5000.0
@export var cognition_co2_severe_ppm: float = 15000.0
@export var cognition_cold_c: float = 12.0
@export var dehydration_damage_per_hour: float = 0.2
@export var food_part_id: StringName = &"food_ration"
@export var rations_per_occupant_per_day: float = 1.0
@export var starvation_damage_per_hour: float = 0.15
@export var vacuum_damage_per_hour: float = 0.5
@export var suit_temperature_c: float = 21.0

var condition: float = 0.0

var _incapacitated: bool = false
var _recovery_sources: Dictionary = {}
var _cause: StringName = &""
var _cognition_level: int = 0
var _manned_compartment: StringName = &""
var _last_emitted_bucket: int = 0
var _ration_accumulator: float = 0.0


func _ready() -> void:
	system_id = &"vitals"
	add_to_group(&"vitals_system")
	super._ready()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("VitalsSystem.sim_tick: delta_hours must be finite and positive.")
		return
	var environment: Dictionary = _read_environment()
	if environment.is_empty():
		return
	_resolve_vacuum_protection(environment, delta_hours)
	_tick_rations(environment, delta_hours)
	_tick_condition(environment, delta_hours)
	_tick_cognition(environment)


func get_status() -> Dictionary:
	return {
		"system_id": system_id,
		"condition": condition,
		"cause": _cause,
		"incapacitated": _incapacitated,
		"cognition_level": _cognition_level,
		"manned_compartment": _manned_compartment,
	}


func get_cognition_level() -> int:
	return _cognition_level


func get_cause() -> StringName:
	return _cause


## Clears the loss state. Called by the mercy-recovery path, never by normal sim ticks.
func resuscitate() -> void:
	condition = 0.0
	_incapacitated = false
	_cause = &""
	_last_emitted_bucket = _bucket_for(condition)


func save_state() -> Dictionary:
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"condition": condition,
		"incapacitated": _incapacitated,
		"cause": String(_cause),
		"cognition_level": _cognition_level,
		"last_emitted_bucket": _last_emitted_bucket,
		"ration_accumulator": _ration_accumulator,
	}


func load_state(state: Dictionary) -> void:
	condition = clampf(float(state.get("condition", condition)), 0.0, 1.0)
	_incapacitated = bool(state.get("incapacitated", _incapacitated))
	_cause = StringName(String(state.get("cause", _cause)))
	_cognition_level = clampi(int(state.get("cognition_level", _cognition_level)), 0, 3)
	_last_emitted_bucket = int(state.get("last_emitted_bucket", _bucket_for(condition)))
	_ration_accumulator = maxf(float(state.get("ration_accumulator", _ration_accumulator)), 0.0)


func _read_environment() -> Dictionary:
	var atmosphere: Node = _first_node_in_group(&"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"get_status"):
		_manned_compartment = &""
		return {}
	var atmosphere_status: Variant = atmosphere.call("get_status")
	if not (atmosphere_status is Dictionary):
		_manned_compartment = &""
		return {}
	var compartments: Variant = (atmosphere_status as Dictionary).get("compartments", {})
	if not (compartments is Dictionary):
		_manned_compartment = &""
		return {}
	var manned_id: StringName = &""
	var manned_status: Dictionary = {}
	for key: Variant in (compartments as Dictionary):
		var candidate: Variant = (compartments as Dictionary)[key]
		if not (candidate is Dictionary):
			continue
		if int((candidate as Dictionary).get("occupants", 0)) > 0:
			manned_id = StringName(String(key))
			manned_status = candidate
			break
	if manned_id == &"":
		_manned_compartment = &""
		var player: Node = _first_node_in_group(&"player")
		if player != null and player.has_method(&"is_exterior") and bool(player.call("is_exterior")):
			return {
				"compartment_id": &"", "o2_fraction": 0.0, "co2_ppm": 0.0,
				"pressure_kpa": 0.0, "temperature_c": suit_temperature_c,
				"occupants": 1, "dehydrated": _read_dehydrated(), "starving": _read_starving(),
			}
		return {}
	var thermal: Node = _first_node_in_group(&"thermal_system")
	if thermal == null or not thermal.has_method(&"get_compartment_status"):
		_manned_compartment = &""
		return {}
	if thermal.has_method(&"has_compartment") and not bool(thermal.call("has_compartment", manned_id)):
		_manned_compartment = &""
		return {}
	var thermal_status: Variant = thermal.call("get_compartment_status", manned_id)
	if not (thermal_status is Dictionary) or (thermal_status as Dictionary).is_empty():
		_manned_compartment = &""
		return {}
	_manned_compartment = manned_id
	return {
		"compartment_id": manned_id,
		"o2_fraction": float(manned_status.get("o2_fraction", 1.0)),
		"co2_ppm": float(manned_status.get("co2_ppm", 0.0)),
		"pressure_kpa": float(manned_status.get("pressure_kpa", 101.325)),
		"temperature_c": float((thermal_status as Dictionary).get("temperature_c", 21.0)),
		"occupants": maxi(int(manned_status.get("occupants", 0)), 0),
		"dehydrated": _read_dehydrated(),
		"starving": _read_starving(),
	}


func _resolve_vacuum_protection(environment: Dictionary, delta_hours: float) -> void:
	environment["vacuum_protected"] = false
	var pressure_kpa: float = float(environment.get("pressure_kpa", 101.325))
	if pressure_kpa >= AtmosphereSystem.VACUUM_PRESSURE_KPA:
		return
	var airlock: Node = _first_node_in_group(&"airlock_system")
	if airlock == null or not airlock.has_method(&"consume_suit_o2"):
		return
	environment["vacuum_protected"] = bool(airlock.call("consume_suit_o2", delta_hours))


func _read_dehydrated() -> bool:
	var water: Node = _first_node_in_group(&"water_system")
	if water == null or not water.has_method(&"get_status"):
		return false
	var water_status: Variant = water.call("get_status")
	if not (water_status is Dictionary):
		return false
	return float((water_status as Dictionary).get("potable_l", 1.0)) <= 0.0


func _read_starving() -> bool:
	var stores: Node = _first_node_in_group(&"stores_system")
	if stores == null or not stores.has_method(&"get_count"):
		return false
	return int(stores.call(&"get_count", food_part_id)) <= 0


func _tick_rations(environment: Dictionary, delta_hours: float) -> void:
	var occupants: int = int(environment.get("occupants", 0))
	_ration_accumulator += float(occupants) * rations_per_occupant_per_day * delta_hours / 24.0
	while _ration_accumulator >= 1.0:
		var stores: Node = _first_node_in_group(&"stores_system")
		# Stores are optional in headless scenarios: without one there is nothing to
		# draw from, so the pending ration is dropped and food logic is skipped.
		if stores == null or not stores.has_method(&"consume_part") or not stores.has_method(&"get_count"):
			_ration_accumulator = 0.0
			return
		if bool(stores.call(&"consume_part", food_part_id, 1)):
			_ration_accumulator -= 1.0
			emit_sim_event(&"ration_consumed", {"remaining": int(stores.call(&"get_count", food_part_id))})
		else:
			_ration_accumulator = 1.0
			break


## Installed hardware (a med bay) speeds recovery; sources are re-applied on load.
func set_recovery_source(source_id: StringName, per_hour: float) -> void:
	if per_hour <= 0.0:
		_recovery_sources.erase(source_id)
		return
	_recovery_sources[source_id] = per_hour


func get_recovery_per_hour() -> float:
	var total: float = recovery_per_hour
	for value: Variant in _recovery_sources.values():
		total += float(value)
	return total


func _tick_condition(environment: Dictionary, delta_hours: float) -> void:
	if _incapacitated:
		return
	var exposure: Dictionary = _classify_exposure(environment)
	var new_cause: StringName = exposure["cause"]
	var rate_per_hour: float = -get_recovery_per_hour()
	if bool(exposure["severe"]):
		rate_per_hour = damage_per_hour
		if new_cause == &"dehydration":
			rate_per_hour = dehydration_damage_per_hour
		elif new_cause == &"starvation":
			rate_per_hour = starvation_damage_per_hour
		elif new_cause == &"vacuum":
			rate_per_hour = vacuum_damage_per_hour
	elif bool(exposure["mild"]):
		rate_per_hour = damage_per_hour * MILD_DAMAGE_SCALE
	var cause_changed: bool = new_cause != _cause
	_cause = new_cause
	condition = clampf(condition + rate_per_hour * delta_hours, 0.0, 1.0)
	_emit_condition_if_due(cause_changed)
	if condition >= 1.0:
		_incapacitate()


func _tick_cognition(environment: Dictionary) -> void:
	var level: int = _level_for(environment)
	if level == _cognition_level:
		return
	_cognition_level = level
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"cognition_effect_changed", level)
	emit_sim_event(&"cognition_effect_changed", {"level": level})


func _classify_exposure(environment: Dictionary) -> Dictionary:
	var o2_fraction: float = float(environment["o2_fraction"])
	var co2_ppm: float = float(environment["co2_ppm"])
	var temperature_c: float = float(environment["temperature_c"])
	var pressure_kpa: float = float(environment.get("pressure_kpa", 101.325))
	var in_vacuum: bool = pressure_kpa < AtmosphereSystem.VACUUM_PRESSURE_KPA
	var protected: bool = bool(environment.get("vacuum_protected", false))
	if in_vacuum and not protected:
		return {"cause": &"vacuum", "severe": true, "mild": false}
	if not in_vacuum and o2_fraction < o2_breathing_threshold:
		return {"cause": &"oxygen", "severe": true, "mild": false}
	if not in_vacuum and co2_ppm > co2_breathing_ppm:
		return {"cause": &"carbon_dioxide", "severe": true, "mild": false}
	if temperature_c < cold_severe_c:
		return {"cause": &"hypothermia", "severe": true, "mild": false}
	if temperature_c < cold_threshold_c:
		return {"cause": &"hypothermia", "severe": false, "mild": true}
	if bool(environment.get("dehydrated", false)):
		return {"cause": &"dehydration", "severe": true, "mild": false}
	if bool(environment.get("starving", false)):
		return {"cause": &"starvation", "severe": true, "mild": false}
	return {"cause": &"", "severe": false, "mild": false}


func _level_for(environment: Dictionary) -> int:
	var o2_fraction: float = float(environment["o2_fraction"])
	var co2_ppm: float = float(environment["co2_ppm"])
	var temperature_c: float = float(environment["temperature_c"])
	var pressure_kpa: float = float(environment.get("pressure_kpa", 101.325))
	var in_vacuum: bool = pressure_kpa < AtmosphereSystem.VACUUM_PRESSURE_KPA
	var protected: bool = bool(environment.get("vacuum_protected", false))
	if in_vacuum and not protected:
		return 3
	var breathing_trouble: bool = not in_vacuum and (o2_fraction < o2_breathing_threshold or co2_ppm > co2_breathing_ppm)
	if condition >= 0.7 or breathing_trouble or bool(environment.get("dehydrated", false)) or bool(environment.get("starving", false)):
		return 3
	if not in_vacuum and (co2_ppm >= cognition_co2_severe_ppm or temperature_c <= cold_threshold_c):
		return 2
	if not in_vacuum and (co2_ppm >= cognition_co2_ppm or temperature_c <= cognition_cold_c):
		return 1
	return 0


func _incapacitate() -> void:
	if _incapacitated:
		return
	_incapacitated = true
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"operator_incapacitated", _cause)
	emit_sim_event(&"operator_incapacitated", {
		"cause": _cause,
		"condition": condition,
		"compartment_id": _manned_compartment,
	})


func _emit_condition_if_due(cause_changed: bool) -> void:
	var bucket: int = _bucket_for(condition)
	if bucket == _last_emitted_bucket and not cause_changed:
		return
	_last_emitted_bucket = bucket
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"operator_condition_changed", condition, _cause)
	emit_sim_event(&"operator_condition_changed", {"condition": condition, "cause": _cause})


func _bucket_for(value: float) -> int:
	return int(floor(value / CONDITION_EMIT_DELTA + 1e-9))


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)
