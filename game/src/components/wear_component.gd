class_name WearComponent
extends Resource

@export var component_id: StringName = &""
@export var display_name: String = ""
@export var condition: float = 1.0
@export var hours_operated: float = 0.0
@export var wear_rate_per_hour: float = 0.002
@export var load: float = 1.0
@export var failure_modes: Array[FailureMode] = []

var failed_mode: StringName = &""
var diagnosed: bool = false
var scanned: bool = false


func get_probability_per_hour(mode: FailureMode, environment: Dictionary) -> float:
	if mode == null or condition > mode.max_condition:
		return 0.0
	var env_mult: float = 1.0
	for key: Variant in mode.environmental_factors:
		var v: float = clampf(float(environment.get(key, 0.0)), 0.0, 1.0)
		env_mult *= 1.0 + (float(mode.environmental_factors[key]) - 1.0) * v
	return mode.wear_multiplier * env_mult / maxf(mode.base_mtbf_hours, 0.001)


func tick_sim(hours: float, environment: Dictionary, rng: RandomNumberGenerator) -> StringName:
	if hours <= 0.0 or is_failed():
		return &""
	hours_operated += hours
	condition = maxf(0.0, condition - wear_rate_per_hour * load * hours)
	for mode: FailureMode in failure_modes:
		if mode == null:
			continue
		var p_tick: float = 1.0 - exp(-get_probability_per_hour(mode, environment) * hours)
		if rng.randf() < p_tick:
			failed_mode = mode.id
			return failed_mode
	return &""


func apply_repair(quality: float) -> void:
	condition = clampf(condition + (1.0 - condition) * clampf(quality, 0.0, 1.0), 0.0, 1.0)
	if condition > 0.0:
		failed_mode = &""
	diagnosed = true


func is_failed() -> bool:
	return failed_mode != &""


func diagnose() -> StringName:
	if is_failed():
		diagnosed = true
		return failed_mode
	return &""


func scan() -> void:
	scanned = true


func get_status() -> Dictionary:
	return {
		"component_id": component_id,
		"condition": condition,
		"hours_operated": hours_operated,
		"load": load,
		"failed_mode": failed_mode,
		"failed": is_failed(),
		"diagnosed": diagnosed,
		"scanned": scanned,
	}
