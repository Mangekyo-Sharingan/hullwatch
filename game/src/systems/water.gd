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

var reclaimer_powered: bool = true

var _low_latched: bool = false
var _depleted_latched: bool = false
var _contaminated_latched: bool = false


func _ready() -> void:
	system_id = &"water"
	add_to_group(&"water_system")
	super._ready()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("WaterSystem.sim_tick: delta_hours must be finite and positive.")
		return
	_tick_consumption(delta_hours)
	_tick_reclaimer(delta_hours)
	_update_event_flags()


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
		"reclaimer_active": _is_reclaimer_effective() and greywater_l > 0.0,
		"efficiency": reclaimer_efficiency * (1.0 - contamination),
	}


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
	}


func load_state(state: Dictionary) -> void:
	potable_l = clampf(float(state.get("potable_l", potable_l)), 0.0, maxf(potable_capacity_l, 0.0))
	greywater_l = maxf(float(state.get("greywater_l", greywater_l)), 0.0)
	contamination = clampf(float(state.get("contamination", contamination)), 0.0, 1.0)
	reclaimer_powered = bool(state.get("reclaimer_powered", reclaimer_powered))
	_low_latched = bool(state.get("water_low_latched", _low_latched))
	_depleted_latched = bool(state.get("water_depleted_latched", _depleted_latched))
	_contaminated_latched = bool(state.get("water_contaminated_latched", _contaminated_latched))


func _tick_consumption(delta_hours: float) -> void:
	var occupants: int = _read_total_occupants()
	if occupants <= 0:
		return
	var demand_l: float = float(occupants) * consumption_l_per_occupant_hour * delta_hours
	var consumed_l: float = minf(demand_l, potable_l)
	potable_l = maxf(potable_l - consumed_l, 0.0)
	greywater_l = maxf(greywater_l + consumed_l * GREYWATER_RECOVERY_FRACTION, 0.0)


func _tick_reclaimer(delta_hours: float) -> void:
	if not _is_reclaimer_effective() or greywater_l <= 0.0:
		return
	var processed_l: float = minf(reclaimer_capacity_l_per_hour * delta_hours, greywater_l)
	if processed_l <= 0.0:
		return
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
