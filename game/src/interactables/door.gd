## Sliding pressure door between two compartments. Toggles atmospheric isolation when opened or closed.
class_name Door
extends Interactable

@export var compartment_a: StringName = &""
@export var compartment_b: StringName = &""
@export var open_offset: Vector3 = Vector3(0, 2.1, 0)
@export var airlock_id: StringName = &""
@export var airlock_side: StringName = &""

var _open: bool = false
var _slab: MeshInstance3D
var _slab_shape: CollisionShape3D
var _slab_base_position: Vector3 = Vector3.ZERO
var _slab_shape_base_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	_slab = get_node_or_null(^"Slab") as MeshInstance3D
	_slab_shape = get_node_or_null(^"SlabShape") as CollisionShape3D
	if _slab != null:
		_slab_base_position = _slab.position
	if _slab_shape != null:
		_slab_shape_base_position = _slab_shape.position
	_apply_open_state()


func is_open() -> bool:
	return _open


func get_interaction_prompt() -> String:
	if _open:
		return "Close door"
	return "Open door"


func _handle_interact(_player: Node) -> void:
	if airlock_id != &"":
		var airlock: Node = _get_system(&"airlock_system")
		if airlock != null and airlock.has_method(&"request_door"):
			if bool(airlock.call("request_door", airlock_side, not _open)):
				_set_open(not _open)
			else:
				_emit_airlock_refusal(airlock)
			return
	_set_open(not _open)


func _emit_airlock_refusal(airlock: Node) -> void:
	var reason: StringName = &"airlock_interlock"
	if airlock.has_method(&"get_door_refusal"):
		reason = StringName(airlock.call("get_door_refusal", airlock_side, not _open))
	_emit_sim_event(&"procedure_error", {"reason": reason, "airlock_id": airlock_id})


func _set_open(open: bool) -> void:
	_open = open
	_apply_open_state()


func _apply_open_state() -> void:
	var offset: Vector3 = open_offset if _open else Vector3.ZERO
	if _slab != null:
		_slab.position = _slab_base_position + offset
	if _slab_shape != null:
		_slab_shape.position = _slab_shape_base_position + offset
		_slab_shape.disabled = _open
	_sync_isolation()


func _sync_isolation() -> void:
	if airlock_id != &"":
		return
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"set_isolated"):
		return
	for compartment_id: StringName in [compartment_a, compartment_b]:
		if compartment_id == &"":
			continue
		if atmosphere.has_method(&"has_compartment") and not bool(atmosphere.call(&"has_compartment", compartment_id)):
			continue
		atmosphere.call(&"set_isolated", compartment_id, not _open)


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "door"
	state["state_version"] = 1
	state["open"] = _open
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_set_open(bool(state.get("open", _open)))
	var airlock: Node = _get_system(&"airlock_system")
	if airlock != null and airlock.has_method(&"force_door_state"):
		airlock.call("force_door_state", airlock_side, _open)
