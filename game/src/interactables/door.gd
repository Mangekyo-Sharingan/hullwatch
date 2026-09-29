## Sliding pressure door between two compartments. Opens or closes only its own gas path.
class_name Door
extends Interactable

const SLIDE_DURATION_SECONDS: float = 0.58
const MIN_SLIDE_DURATION_SECONDS: float = 0.12

@export var compartment_a: StringName = &""
@export var compartment_b: StringName = &""
@export var open_offset: Vector3 = Vector3(0, 2.1, 0)
@export var airlock_id: StringName = &""
@export var starts_open: bool = false
@export var hide_when_open: bool = false
@export var airlock_side: StringName = &""

var _open: bool = false
## The slab is a container: a single MeshInstance3D leaf on legacy doors, the fitted
## authored leaf on generated ones. Either way it moves and hides as one node.
var _slab: Node3D
var _slab_shape: CollisionShape3D
var _slab_base_position: Vector3 = Vector3.ZERO
var _slab_shape_base_position: Vector3 = Vector3.ZERO
var _motion_tween: Tween


func _ready() -> void:
	add_to_group(&"ship_door")
	_slab = get_node_or_null(^"Slab") as Node3D
	_slab_shape = get_node_or_null(^"SlabShape") as CollisionShape3D
	if _slab != null:
		_slab_base_position = _slab.position
	if _slab_shape != null:
		_slab_shape_base_position = _slab_shape.position
	_open = starts_open
	_apply_open_state(false)


func is_open() -> bool:
	return _open


func get_interaction_prompt() -> String:
	if _open:
		return "Close door"
	return "Open door"


## Human name for the ship computer: the authored name, else the joined compartments.
func get_door_label() -> String:
	if not display_name.is_empty():
		return display_name
	var parts: PackedStringArray = PackedStringArray()
	for side: StringName in [compartment_a, compartment_b]:
		if side == &"":
			continue
		parts.append(String(side).to_upper().replace("_", " "))
	return " - ".join(parts)


func _handle_interact(_player: Node) -> void:
	request_open(not _open)


## Shared toggle for players and the ship computer; a refusal is reported as a sim event.
func request_open(open: bool) -> bool:
	if open == _open:
		return true
	if airlock_id != &"":
		var airlock: Node = _get_system(&"airlock_system")
		if airlock != null and airlock.has_method(&"request_door"):
			if not bool(airlock.call("request_door", airlock_side, open, _airlock_door_id())):
				_emit_airlock_refusal(airlock, open)
				return false
	_set_open(open)
	return true


func _emit_airlock_refusal(airlock: Node, open: bool) -> void:
	var reason: StringName = &"airlock_interlock"
	if airlock.has_method(&"get_door_refusal"):
		reason = StringName(airlock.call("get_door_refusal", airlock_side, open, _airlock_door_id()))
	_emit_sim_event(&"procedure_error", {"reason": reason, "airlock_id": airlock_id})


func _set_open(open: bool) -> void:
	_open = open
	_apply_open_state(true)


func _apply_open_state(animate: bool) -> void:
	var target_offset: Vector3 = open_offset if _open else Vector3.ZERO
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	if animate and not _door_offset().is_equal_approx(target_offset):
		if _slab != null:
			_slab.visible = true
		if _slab_shape != null and not _open:
			_slab_shape.disabled = false
		var start_offset: Vector3 = _door_offset()
		var travel_fraction: float = clampf(start_offset.distance_to(target_offset) / maxf(open_offset.length(), 0.001), 0.0, 1.0)
		var duration: float = maxf(MIN_SLIDE_DURATION_SECONDS, SLIDE_DURATION_SECONDS * travel_fraction)
		_motion_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_motion_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		_motion_tween.tween_method(_set_motion_progress.bind(start_offset, target_offset), 0.0, 1.0, duration)
		_motion_tween.finished.connect(_finish_motion.bind(_open))
	else:
		_set_door_offset(target_offset)
		_finish_open_state()
	_sync_connection()
	_sync_airlock_state()


func _door_offset() -> Vector3:
	if _slab != null:
		return _slab.position - _slab_base_position
	if _slab_shape != null:
		return _slab_shape.position - _slab_shape_base_position
	return Vector3.ZERO


func _set_motion_progress(progress: float, start_offset: Vector3, target_offset: Vector3) -> void:
	_set_door_offset(start_offset.lerp(target_offset, progress))


func _set_door_offset(offset: Vector3) -> void:
	if _slab != null:
		_slab.position = _slab_base_position + offset
	if _slab_shape != null:
		_slab_shape.position = _slab_shape_base_position + offset


func _finish_motion(open: bool) -> void:
	if open != _open:
		return
	_set_door_offset(open_offset if open else Vector3.ZERO)
	_finish_open_state()
	_motion_tween = null


func _finish_open_state() -> void:
	if _slab != null:
		_slab.visible = not _open or not hide_when_open
	if _slab_shape != null:
		_slab_shape.disabled = _open


func _sync_connection() -> void:
	if compartment_a == &"" or compartment_b == &"" or compartment_a == compartment_b:
		return
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"set_connection_open"):
		return
	if atmosphere.has_method(&"has_compartment"):
		if not bool(atmosphere.call(&"has_compartment", compartment_a)) or not bool(atmosphere.call(&"has_compartment", compartment_b)):
			return
	atmosphere.call(&"set_connection_open", compartment_a, compartment_b, _open)


func _sync_airlock_state() -> void:
	if airlock_id == &"" or (airlock_side != &"inner" and airlock_side != &"outer"):
		return
	var airlock: Node = _get_system(&"airlock_system")
	if airlock != null and airlock.has_method(&"set_door_state"):
		airlock.call(&"set_door_state", _airlock_door_id(), airlock_side, _open)


func _airlock_door_id() -> StringName:
	return StringName(String(get_path()))


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "door"
	state["state_version"] = 1
	state["open"] = _open
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_open = bool(state.get("open", _open))
	_apply_open_state(false)
