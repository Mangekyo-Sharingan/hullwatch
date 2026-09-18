## Deterministic ship-wide water simulator: potable draw, greywater recovery, contamination.
class_name WaterSystem
extends ShipSystem

const GREYWATER_RECOVERY_FRACTION: float = 0.8
const LOW_FRACTION_THRESHOLD: float = 0.25
const LOW_FRACTION_REARM: float = 0.3
const DEPLETED_REARM_L: float = 1.0
const CONTAMINATION_ALERT: float = 0.5
const CONTAMINATION_REARM: float = 0.4

@export var potable_l: float = 120.0
@export var potable_capacity_l: float = 150.0
@export var greywater_l: float = 40.0
@export var consumption_l_per_occupant_hour: float = 0.06
@export var reclaimer_capacity_l_per_hour: float = 2.0
@export var reclaimer_efficiency: float = 0.65
@export var contamination: float = 0.0
@export var contamination_per_hour: float = 0.002
@export var circuit_id: StringName = &"life_support"
@export var wear_components: Array[WearComponent] = []
@export var wear_seed: int = 20260923

var reclaimer_powered: bool = true

var _low_latched: bool = false
var _depleted_latched: bool = false
var _contaminated_latched: bool = false
var _rng: RandomNumberGenerator
var _condition_bucket: Dictionary = {}
var _failure_restore: Dictionary = {}
var _capacity_multiplier: float = 1.0
var _wear_environment: Dictionary = {}
var _processing_duty: float = 0.0


func _ready() -> void:
	system_id = &"water"
	add_to_group(&"water_system")
	_wear_rng()
	super._ready()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("WaterSystem.sim_tick: delta_hours must be finite and positive.")
		return
	_tick_consumption(delta_hours)
	_tick_reclaimer(delta_hours)
	_update_event_flags()
	_tick_wear(delta_hours)


func set_reclaimer_powered(powered: bool) -> void:
	reclaimer_powered = powered


func purge() -> bool:
	if contamination <= 0.0:
		return false
	contamination = 0.0
	if _contaminated_latched:
		_contaminated_latched = false
	emit_sim_event(&"water_purged", {})
	return true


func install_cartridge() -> bool:
	contamination = maxf(contamination - 0.5, 0.0)
	if _contaminated_latched and contamination < CONTAMINATION_REARM:
		_contaminated_latched = false
	emit_sim_event(&"water_cartridge_installed", {"contamination": contamination})
	return true


func get_status() -> Dictionary:
	return {
		"system_id": system_id,
		"potable_l": potable_l,
		"potable_capacity_l": potable_capacity_l,
		"potable_fraction": _potable_fraction(),
		"greywater_l": greywater_l,
		"contamination": contamination,
		"reclaimer_powered": reclaimer_powered,
		"reclaimer_active": _is_reclaimer_effective() and greywater_l > 0.0 and _capacity_multiplier > 0.0,
		"efficiency": reclaimer_efficiency * (1.0 - contamination),
		"capacity_multiplier": _capacity_multiplier,
	}


func repair_component(component_id: StringName, quality: float) -> bool:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null:
		push_error("WaterSystem.repair_component: unknown component_id '%s'." % String(component_id))
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
		push_error("WaterSystem.force_failure: unknown component_id '%s' or empty failure_mode_id." % String(component_id))
		return false
	if component.is_failed():
		return false
	component.failed_mode = failure_mode_id
	_apply_failure_effect(component, failure_mode_id)
	_emit_component_failed(component.component_id, failure_mode_id)
	return true


func get_wear_environment() -> Dictionary:
	return _wear_environment


func save_state() -> Dictionary:
	return {
		"system_id": "water",
		"state_version": 1,
		"potable_l": potable_l,
		"greywater_l": greywater_l,
		"contamination": contamination,
		"reclaimer_powered": reclaimer_powered,
		"water_low_latched": _low_latched,
		"water_depleted_latched": _depleted_latched,
		"water_contaminated_latched": _contaminated_latched,
		"wear": _wear_save_entries(),
		"wear_rng_state": str(_wear_rng().state),
		"failure_restore": _failure_restore_save(),
	}


func load_state(state: Dictionary) -> void:
	potable_l = clampf(float(state.get("potable_l", potable_l)), 0.0, maxf(potable_capacity_l, 0.0))
	greywater_l = maxf(float(state.get("greywater_l", greywater_l)), 0.0)
	contamination = clampf(float(state.get("contamination", contamination)), 0.0, 1.0)
	reclaimer_powered = bool(state.get("reclaimer_powered", reclaimer_powered))
	_low_latched = bool(state.get("water_low_latched", _low_latched))
	_depleted_latched = bool(state.get("water_depleted_latched", _depleted_latched))
	_contaminated_latched = bool(state.get("water_contaminated_latched", _contaminated_latched))
	_load_wear(state.get("wear", []))
	_load_failure_restore(state.get("failure_restore", {}))
	if state.has("wear_rng_state"):
		_wear_rng().state = int(str(state.get("wear_rng_state", _wear_rng().state)))
	_reapply_failed_effects()


func _tick_consumption(delta_hours: float) -> void:
	var occupants: int = _read_total_occupants()
	if occupants <= 0:
		return
	var demand_l: float = float(occupants) * consumption_l_per_occupant_hour * delta_hours
	var consumed_l: float = minf(demand_l, potable_l)
	potable_l = maxf(potable_l - consumed_l, 0.0)
	greywater_l = maxf(greywater_l + consumed_l * GREYWATER_RECOVERY_FRACTION, 0.0)


func _tick_reclaimer(delta_hours: float) -> void:
	_processing_duty = 0.0
	if not _is_reclaimer_effective() or greywater_l <= 0.0:
		return
	var capacity_l_per_hour: float = reclaimer_capacity_l_per_hour * _capacity_multiplier
	var processed_l: float = minf(capacity_l_per_hour * delta_hours, greywater_l)
	if processed_l <= 0.0:
		return
	_processing_duty = 1.0
	greywater_l = maxf(greywater_l - processed_l, 0.0)
	var efficiency: float = reclaimer_efficiency * (1.0 - contamination)
	potable_l = minf(potable_l + processed_l * efficiency, potable_capacity_l)
	contamination = clampf(contamination + contamination_per_hour * delta_hours, 0.0, 1.0)


func _update_event_flags() -> void:
	var fraction: float = _potable_fraction()
	if not _low_latched and fraction < LOW_FRACTION_THRESHOLD:
		_low_latched = true
		emit_sim_event(&"water_low", {"potable_l": potable_l, "potable_fraction": fraction})
	elif _low_latched and fraction > LOW_FRACTION_REARM:
		_low_latched = false
	if not _depleted_latched and potable_l <= 0.0:
		_depleted_latched = true
		emit_sim_event(&"water_depleted", {"potable_l": potable_l})
	elif _depleted_latched and potable_l > DEPLETED_REARM_L:
		_depleted_latched = false
	if not _contaminated_latched and contamination > CONTAMINATION_ALERT:
		_contaminated_latched = true
		emit_sim_event(&"water_contaminated", {"contamination": contamination})
	elif _contaminated_latched and contamination < CONTAMINATION_REARM:
		_contaminated_latched = false


func _potable_fraction() -> float:
	if potable_capacity_l <= 0.0:
		return 0.0
	return clampf(potable_l / potable_capacity_l, 0.0, 1.0)


func _read_total_occupants() -> int:
	var atmosphere: Node = _first_node_in_group(&"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method("get_status"):
		return 0
	var atmosphere_status: Variant = atmosphere.call("get_status")
	if not (atmosphere_status is Dictionary):
		return 0
	var compartments: Variant = (atmosphere_status as Dictionary).get("compartments", {})
	if not (compartments is Dictionary):
		return 0
	var total: int = 0
	for value: Variant in (compartments as Dictionary).values():
		if value is Dictionary:
			total += maxi(int((value as Dictionary).get("occupants", 0)), 0)
	return total


func _is_reclaimer_effective() -> bool:
	if not reclaimer_powered:
		return false
	var power: Node = _first_node_in_group(&"power_system")
	if power == null or not power.has_method("is_breaker_on") or not power.has_method("is_circuit_shed"):
		return true
	if power.has_method("has_circuit") and not bool(power.call("has_circuit", circuit_id)):
		return false
	return bool(power.call("is_breaker_on", circuit_id)) and not bool(power.call("is_circuit_shed", circuit_id))


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)


func _tick_wear(delta_hours: float) -> void:
	_wear_environment = {
		"load": clampf(_processing_duty, 0.0, 1.0),
		"heat": _heat_factor(),
		"humidity": 0.0,
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


func _apply_failure_effect(component: WearComponent, failure_mode_id: StringName) -> void:
	match failure_mode_id:
		&"pump_impeller_wear":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "capacity_multiplier", "target": "", "value": _capacity_multiplier}
			_capacity_multiplier = 0.3
		&"pump_seize":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "capacity_multiplier", "target": "", "value": _capacity_multiplier}
			_capacity_multiplier = 0.0
		_:
			pass


func _restore_failure_effect(component_id: StringName) -> void:
	if not _failure_restore.has(component_id):
		return
	var restore: Dictionary = _failure_restore[component_id]
	match String(restore.get("kind", "")):
		"capacity_multiplier":
			_capacity_multiplier = clampf(float(restore.get("value", _capacity_multiplier)), 0.0, 1.0)
		_:
			pass
	_failure_restore.erase(component_id)


func _reapply_failed_effects() -> void:
	_capacity_multiplier = 1.0
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
