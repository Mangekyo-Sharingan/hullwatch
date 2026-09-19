## Raw-material hold: what the operator hauls back from EVA, in abstract units against a
## mass budget. Materials feed the fabricator (M9.3).
class_name CargoSystem
extends ShipSystem

const KIND_ICE: StringName = &"ice"
const KIND_ORE: StringName = &"ore"
const KIND_METAL: StringName = &"metal"
const KIND_EXOTIC: StringName = &"exotic"
const KNOWN_KINDS: Array[StringName] = [KIND_ICE, KIND_ORE, KIND_METAL, KIND_EXOTIC]

@export var capacity_units: float = 120.0

var _materials: Dictionary = {}


func _ready() -> void:
	system_id = &"cargo"
	add_to_group(&"cargo_system")
	super._ready()


## Accepts what fits; returns the units actually stowed.
func add_material(kind: StringName, units: float) -> float:
	if units <= 0.0 or not is_finite(units):
		return 0.0
	var accepted: float = minf(units, get_free_units())
	if accepted <= 0.0:
		return 0.0
	_materials[kind] = float(_materials.get(kind, 0.0)) + accepted
	emit_sim_event(&"cargo_stowed", {"kind": String(kind), "units": accepted, "total": float(_materials[kind])})
	return accepted


func consume_material(kind: StringName, units: float) -> bool:
	if units <= 0.0:
		return true
	if get_units(kind) < units - 0.0001:
		return false
	_materials[kind] = float(_materials[kind]) - units
	emit_sim_event(&"cargo_consumed", {"kind": String(kind), "units": units, "total": float(_materials[kind])})
	return true


func get_units(kind: StringName) -> float:
	return float(_materials.get(kind, 0.0))


func get_materials() -> Dictionary:
	return _materials.duplicate()


func get_used_units() -> float:
	var total: float = 0.0
	for value: Variant in _materials.values():
		total += float(value)
	return total


func get_free_units() -> float:
	return maxf(capacity_units - get_used_units(), 0.0)


func get_status() -> Dictionary:
	return {
		"system_id": system_id,
		"capacity_units": capacity_units,
		"used_units": get_used_units(),
		"free_units": get_free_units(),
		"materials": get_materials(),
	}


func save_state() -> Dictionary:
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"capacity_units": capacity_units,
		"materials": get_materials(),
	}


func load_state(state: Dictionary) -> void:
	capacity_units = maxf(float(state.get("capacity_units", capacity_units)), 0.0)
	_materials.clear()
	var materials: Dictionary = state.get("materials", {})
	for key: Variant in materials:
		var kind: StringName = StringName(String(key))
		var units: float = maxf(float(materials[key]), 0.0)
		if units > 0.0:
			_materials[kind] = units
