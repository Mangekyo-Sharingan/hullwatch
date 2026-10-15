## Sample canister: a carriable that holds one extraction load (resource kind + units)
## until it is stowed at the ship's cargo port.
class_name SampleCanister
extends Carriable

@export var capacity_units: float = 6.0

var _kind: StringName = &""
var _units: float = 0.0


func is_empty() -> bool:
	return _units <= 0.0


func get_capacity() -> float:
	return capacity_units


func get_load() -> Dictionary:
	return {"kind": _kind, "units": _units}


func get_load_kind() -> StringName:
	return _kind


func get_load_units() -> float:
	return _units


## Loads up to the canister capacity; returns the units taken.
func load_amount(kind: StringName, units: float) -> float:
	if not is_empty() or not is_finite(units) or units <= 0.0 or not CargoSystem.KNOWN_KINDS.has(kind):
		return 0.0
	if not is_finite(capacity_units) or capacity_units < 0.0:
		return 0.0
	var taken: float = minf(units, capacity_units)
	if taken <= 0.0:
		return 0.0
	_kind = kind
	_units = taken
	_emit_sim_event(&"canister_loaded", {"kind": String(kind), "units": taken, "item_id": get_item_id()})
	return taken


func remove_amount(units: float) -> float:
	if not is_finite(units) or units <= 0.0 or is_empty():
		return 0.0
	var removed: float = minf(units, _units)
	_units -= removed
	if is_empty():
		_kind = &""
	return removed


## Empties the canister; returns what it held.
func unload() -> Dictionary:
	var load: Dictionary = get_load()
	remove_amount(_units)
	return load


func get_item_name() -> String:
	if is_empty():
		return "Sample canister (empty)"
	return "Sample canister (%s %.0f)" % [String(_kind).to_upper(), _units]


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "sample_canister"
	state["state_version"] = 1
	state["kind"] = String(_kind)
	state["units"] = _units
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	var saved_units: Variant = state.get("units", 0.0)
	_units = float(saved_units) if (saved_units is int or saved_units is float) and is_finite(float(saved_units)) else 0.0
	_kind = StringName(String(state.get("kind", "")))
	if _units <= 0.0 or not CargoSystem.KNOWN_KINDS.has(_kind):
		_kind = &""
		_units = 0.0
