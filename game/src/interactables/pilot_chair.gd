## Floor-mounted pilot station. The chair turns toward an approaching operator and faces
## the window while occupied; its folded seat remains compatible with older saves.
class_name PilotChair
extends Interactable

signal boarding_ready(chair: PilotChair)

const DEPLOY_ANIMATION: StringName = &"deploy"
const STOW_ANIMATION: StringName = &"stow"
const APPROACH_RADIUS: float = 1.8
const SWIVEL_SPEED: float = 2.8
const SWIVEL_EPSILON: float = 0.015
const BASE_SIZE: Vector3 = Vector3(0.68, 0.32, 0.68)
const BACK_SIZE: Vector3 = Vector3(0.72, 0.92, 0.16)
const SEAT_SIZE: Vector3 = Vector3(0.82, 0.54, 0.64)

var _animator: AnimationPlayer
var _model: Node3D
var _base_shape: CollisionShape3D
var _back_shape: CollisionShape3D
var _seat_shape: CollisionShape3D
var _occupied: bool = false
var _swivel_angle: float = 0.0
var _seat_stowed: bool = true
var _seat_animating: bool = false
var _boarding: bool = false
var _boarding_deploying: bool = false
var _departing: bool = false


func _ready() -> void:
	_model = get_node_or_null(^"Model") as Node3D
	_animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_ensure_collision()
	_set_seat_stowed(true)
	if _animator != null and _animator.has_animation(DEPLOY_ANIMATION):
		_animator.animation_finished.connect(_on_animation_finished)
	else:
		_set_seat_stowed(false)
	_apply_swivel()


func _process(delta: float) -> void:
	if _seat_animating or (_occupied and not _boarding):
		return
	var nearby: bool = _operator_nearby()
	if _departing and not nearby:
		_departing = false
	if _boarding:
		if _boarding_deploying:
			if not _seat_animating and not _seat_stowed:
				_boarding = false
				_boarding_deploying = false
				boarding_ready.emit(self)
			return
		if not _seat_stowed:
			_play_seat_animation(false)
			return
		if not _is_at_angle(0.0):
			_advance_chair_to_angle(0.0, delta)
			return
		if not _boarding_deploying:
			_boarding_deploying = true
			_play_seat_animation(true)
		return
	var target: float = PI if nearby and not _departing else 0.0
	if not _is_at_angle(target):
		if not _seat_stowed:
			_play_seat_animation(false)
			return
		_advance_chair_to_angle(target, delta)
		return
	if _seat_stowed and not _departing:
		_play_seat_animation(true)


func get_interaction_prompt() -> String:
	return "Pilot seat occupied" if _occupied else "Take pilot seat"


func is_deployed() -> bool:
	return true


func is_occupied() -> bool:
	return _occupied


func set_occupied(occupied: bool) -> void:
	_occupied = occupied
	if occupied:
		_departing = false
		_boarding = true
		_boarding_deploying = false
	else:
		_boarding = false
		_boarding_deploying = false
		_departing = true


func get_seat_world_position() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, 0.50)


func get_seated_yaw() -> float:
	return global_rotation.y + PI


func get_exit_world_position() -> Vector3:
	return global_transform * Vector3(0.95, 0.0, -0.58)


func _handle_interact(player: Node) -> void:
	if _occupied or player == null or not player.has_method(&"enter_pilot_seat"):
		return
	player.call(&"enter_pilot_seat", self)


func _operator_nearby() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var player: Node3D = tree.get_first_node_in_group(&"player") as Node3D
	return player != null and player.global_position.distance_to(global_position) <= APPROACH_RADIUS


func _advance_chair_to_angle(target: float, delta: float) -> void:
	var difference: float = wrapf(target - _swivel_angle, -PI, PI)
	var step: float = minf(absf(difference), SWIVEL_SPEED * delta)
	if is_zero_approx(step):
		return
	_swivel_angle = wrapf(_swivel_angle + signf(difference) * step, -PI, PI)
	if absf(difference) <= SWIVEL_SPEED * delta:
		_swivel_angle = target
	_apply_swivel()


func _is_at_angle(target: float) -> bool:
	return absf(wrapf(target - _swivel_angle, -PI, PI)) <= SWIVEL_EPSILON


func _play_seat_animation(deploy: bool) -> void:
	var animation: StringName = DEPLOY_ANIMATION if deploy else STOW_ANIMATION
	if _animator == null or not _animator.has_animation(animation):
		_set_seat_stowed(not deploy)
		return
	_seat_animating = true
	_animator.play(animation)


func _on_animation_finished(animation: StringName) -> void:
	if animation == DEPLOY_ANIMATION:
		_set_seat_stowed(false)
	elif animation == STOW_ANIMATION:
		_set_seat_stowed(true)
	else:
		return
	_seat_animating = false


func _set_seat_stowed(stowed: bool) -> void:
	_seat_stowed = stowed
	if _seat_shape != null:
		_seat_shape.set_deferred(&"disabled", stowed)


func _apply_swivel() -> void:
	if _model != null:
		_model.rotation.y = _swivel_angle
	if _back_shape != null:
		_back_shape.position = Vector3(0.0, 1.04, -0.09).rotated(Vector3.UP, _swivel_angle)
		_back_shape.rotation.y = _swivel_angle
	if _seat_shape != null:
		_seat_shape.position = Vector3(0.0, 0.58, 0.34).rotated(Vector3.UP, _swivel_angle)
		_seat_shape.rotation.y = _swivel_angle


func _ensure_collision() -> void:
	_base_shape = get_node_or_null(^"BaseShape") as CollisionShape3D
	if _base_shape == null:
		_base_shape = _make_box_shape(&"BaseShape", BASE_SIZE, Vector3(0.0, 0.16, 0.0))
	_back_shape = get_node_or_null(^"BackShape") as CollisionShape3D
	if _back_shape == null:
		_back_shape = _make_box_shape(&"BackShape", BACK_SIZE, Vector3(0.0, 1.04, -0.09))
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
	add_child(collider)
	return collider


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["deployed"] = true
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	_occupied = false
	_boarding = false
	_boarding_deploying = false
	_departing = false
	_swivel_angle = 0.0
	_set_seat_stowed(false)
	_seat_animating = false
	if _animator != null and _animator.has_animation(DEPLOY_ANIMATION):
		_animator.play(DEPLOY_ANIMATION)
		_animator.seek(_animator.get_animation(DEPLOY_ANIMATION).length, true)
		_animator.pause()
	_apply_swivel()
