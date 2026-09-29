## Floor-mounted pilot station. The chair turns toward an approaching operator and faces
## the window while occupied; its folded seat remains compatible with older saves.
class_name PilotChair
extends Interactable

const DEPLOY_ANIMATION: StringName = &"deploy"
const APPROACH_RADIUS: float = 1.8
const SWIVEL_SPEED: float = 2.8
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


func _ready() -> void:
	_model = get_node_or_null(^"Model") as Node3D
	_animator = find_child("AnimationPlayer", true, false) as AnimationPlayer
	_ensure_collision()
	if _animator != null and _animator.has_animation(DEPLOY_ANIMATION):
		_animator.play(DEPLOY_ANIMATION)
		_animator.seek(_animator.get_animation(DEPLOY_ANIMATION).length, true)
		_animator.pause()
	_apply_swivel()


func _process(delta: float) -> void:
	var target: float = PI if not _occupied and _operator_nearby() else 0.0
	var next_angle: float = move_toward(_swivel_angle, target, SWIVEL_SPEED * delta)
	if not is_equal_approx(next_angle, _swivel_angle):
		_swivel_angle = next_angle
		_apply_swivel()


func get_interaction_prompt() -> String:
	return "Pilot seat occupied" if _occupied else "Take pilot seat"


func is_deployed() -> bool:
	return true


func is_occupied() -> bool:
	return _occupied


func set_occupied(occupied: bool) -> void:
	_occupied = occupied
	if occupied:
		_swivel_angle = 0.0
		_apply_swivel()


func get_seat_world_position() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, 0.50)


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
	_swivel_angle = 0.0
	_apply_swivel()
