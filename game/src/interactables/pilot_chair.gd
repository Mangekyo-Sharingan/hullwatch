## Wall-mounted cockpit seat that folds clear when stowed.
class_name PilotChair
extends Interactable

const DEPLOY_ANIMATION: StringName = &"deploy"
const STOW_ANIMATION: StringName = &"stow"
const FRAME_SIZE: Vector3 = Vector3(0.84, 1.48, 0.13)
const SEAT_SIZE: Vector3 = Vector3(0.82, 0.54, 0.64)

var _deployed: bool = false
var _animator: AnimationPlayer
var _frame_shape: CollisionShape3D
var _seat_shape: CollisionShape3D


func _ready() -> void:
	_animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_ensure_collision()
	if _animator != null and not _animator.animation_finished.is_connected(_on_animation_finished):
		_animator.animation_finished.connect(_on_animation_finished)
	_apply_collision()


func get_interaction_prompt() -> String:
	return "Stow pilot chair" if _deployed else "Deploy pilot chair"


func is_deployed() -> bool:
	return _deployed


func _handle_interact(_player: Node) -> void:
	if _animator != null and _animator.is_playing():
		return
	_set_deployed(not _deployed, true)


func _set_deployed(deployed: bool, animate: bool) -> void:
	_deployed = deployed
	var animation: StringName = DEPLOY_ANIMATION if deployed else STOW_ANIMATION
	if _animator == null or not _animator.has_animation(animation):
		_apply_collision()
		return
	if animate:
		_animator.play(animation)
	else:
		_animator.play(animation)
		_animator.seek(_animator.get_animation(animation).length, true)
		_animator.pause()
		_apply_collision()


func _on_animation_finished(animation: StringName) -> void:
	if animation == DEPLOY_ANIMATION or animation == STOW_ANIMATION:
		_apply_collision()


func _apply_collision() -> void:
	if _frame_shape != null:
		_frame_shape.disabled = false
	if _seat_shape != null:
		_seat_shape.disabled = not _deployed


func _ensure_collision() -> void:
	_frame_shape = get_node_or_null(^"FrameShape") as CollisionShape3D
	if _frame_shape == null:
		_frame_shape = _make_box_shape(&"FrameShape", FRAME_SIZE, Vector3(0.0, FRAME_SIZE.y * 0.5, -0.1))
	_seat_shape = get_node_or_null(^"SeatShape") as CollisionShape3D
	if _seat_shape == null:
		_seat_shape = _make_box_shape(&"SeatShape", SEAT_SIZE, Vector3(0.0, 0.58, 0.34))


func _make_box_shape(shape_name: StringName, size: Vector3, center: Vector3) -> CollisionShape3D:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = shape_name
	collider.shape = shape
	collider.position = center
	collider.disabled = shape_name == &"SeatShape" and not _deployed
	add_child(collider)
	return collider


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["deployed"] = _deployed
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_set_deployed(bool(state.get("deployed", false)), false)
