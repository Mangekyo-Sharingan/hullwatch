## Magnetic-boot hybrid first-person controller: gravity walking while boots are engaged, zero-g drift otherwise.
extends CharacterBody3D

const STAND_HEIGHT: float = 1.8
const CROUCH_HEIGHT: float = 1.2
const STAND_HEAD_Y: float = 1.6
const CROUCH_HEAD_Y: float = 1.0
const BOOTS_LOST_GRACE: float = 0.15
const NORMAL_EPSILON: float = 0.000001

@export var walk_speed: float = 3.0
@export var crouch_speed: float = 1.5
@export var acceleration: float = 12.0
@export var deceleration: float = 16.0
@export var boots_gravity: float = 12.0
@export var boots_range: float = 2.2
@export var push_off_speed: float = 1.6
@export var thruster_accel: float = 1.2
@export var free_damping: float = 0.05
@export var mouse_sensitivity: float = 0.002
@export var pitch_limit_deg: float = 89.0

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var _flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _boots_engaged: bool = true
var _boots_lost_time: float = 0.0
var _crouched: bool = false
var _pitch: float = 0.0


func _ready() -> void:
	var capsule: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
	if capsule != null:
		_collision_shape.shape = capsule.duplicate()
	up_direction = Vector3.UP
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	add_to_group(&"player")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_set_crouched(Input.is_action_pressed(&"crouch"))
	if _boots_engaged:
		_process_engaged(delta)
	else:
		_process_free(delta)
	move_and_slide()


func is_boots_engaged() -> bool:
	return _boots_engaged


func engage_boots() -> bool:
	var normal: Vector3 = _find_anchor_normal()
	if normal == Vector3.ZERO:
		return false
	_align_up(normal)
	up_direction = normal
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	velocity -= normal * velocity.dot(normal)
	_boots_engaged = true
	_boots_lost_time = 0.0
	return true


func disengage_boots() -> void:
	_boots_engaged = false
	_boots_lost_time = 0.0
	up_direction = Vector3.UP
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func push_off() -> bool:
	var normal: Vector3 = Vector3.ZERO
	for i: int in get_slide_collision_count():
		var collision: KinematicCollision3D = get_slide_collision(i)
		if collision != null and collision.get_normal().length_squared() > NORMAL_EPSILON:
			normal = collision.get_normal()
			break
	if normal == Vector3.ZERO:
		normal = _find_anchor_normal()
	if normal == Vector3.ZERO:
		return false
	velocity += normal * push_off_speed
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		rotate_object_local(Vector3.UP, -motion.relative.x * mouse_sensitivity)
		var pitch_limit: float = deg_to_rad(pitch_limit_deg)
		_pitch = clampf(_pitch - motion.relative.y * mouse_sensitivity, -pitch_limit, pitch_limit)
		_head.rotation.x = _pitch
	elif event.is_action_pressed(&"toggle_boots"):
		if _boots_engaged:
			disengage_boots()
		else:
			engage_boots()
	elif event.is_action_pressed(&"jump"):
		if _boots_engaged:
			_jump_from_surface()
		else:
			push_off()
	elif event.is_action_pressed(&"interact"):
		_try_interact()
	elif event.is_action_pressed(&"flashlight"):
		_flashlight.visible = not _flashlight.visible
	elif event.is_action_pressed(&"pause") and DisplayServer.get_name() != "headless":
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process_engaged(delta: float) -> void:
	velocity -= up_direction * boots_gravity * delta
	var wish_direction: Vector3 = _wish_direction(up_direction)
	var speed: float = crouch_speed if _crouched else walk_speed
	_apply_ground_movement(wish_direction, speed, delta)
	if _find_anchor_normal() == Vector3.ZERO:
		_boots_lost_time += delta
		if _boots_lost_time > BOOTS_LOST_GRACE:
			disengage_boots()
	else:
		_boots_lost_time = 0.0


func _process_free(delta: float) -> void:
	velocity *= maxf(0.0, 1.0 - free_damping * delta)
	var wish_direction: Vector3 = _wish_direction(Vector3.UP)
	if wish_direction != Vector3.ZERO:
		velocity += wish_direction * thruster_accel * delta


func _jump_from_surface() -> void:
	var up: Vector3 = up_direction
	disengage_boots()
	velocity -= up * velocity.dot(up)
	velocity += up * push_off_speed


func _apply_ground_movement(wish_direction: Vector3, speed: float, delta: float) -> void:
	var vertical_speed: float = velocity.dot(up_direction)
	var planar_velocity: Vector3 = velocity - up_direction * vertical_speed
	var rate: float = acceleration if wish_direction != Vector3.ZERO else deceleration
	var target: Vector3 = wish_direction * speed
	var planar_moved: Vector3 = planar_velocity.move_toward(target, rate * delta)
	velocity = planar_moved + up_direction * vertical_speed


func _wish_direction(plane_normal: Vector3) -> Vector3:
	var input_vector: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	if input_vector == Vector2.ZERO:
		return Vector3.ZERO
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var wish: Vector3 = right * input_vector.x + forward * -input_vector.y
	wish -= plane_normal * wish.dot(plane_normal)
	if wish.length_squared() <= NORMAL_EPSILON:
		return Vector3.ZERO
	return wish.normalized()


func _find_anchor_normal() -> Vector3:
	if is_on_floor():
		return get_floor_normal()
	if is_on_wall():
		return get_wall_normal()
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return Vector3.ZERO
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position, global_position - global_transform.basis.y * boots_range
	)
	query.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	return result["normal"]


func _align_up(normal: Vector3) -> void:
	var current_up: Vector3 = global_transform.basis.y.normalized()
	var axis: Vector3 = current_up.cross(normal)
	if axis.length_squared() <= NORMAL_EPSILON:
		return
	var angle: float = current_up.angle_to(normal)
	global_transform.basis = Basis(axis.normalized(), angle) * global_transform.basis
	global_transform = global_transform.orthonormalized()


func _set_crouched(crouched: bool) -> void:
	if crouched == _crouched:
		return
	if not crouched and _is_blocked_above():
		return
	_crouched = crouched
	var capsule: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	capsule.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
	_collision_shape.position.y = capsule.height * 0.5
	_head.position.y = CROUCH_HEAD_Y if crouched else STAND_HEAD_Y


func _is_blocked_above() -> bool:
	return test_move(global_transform, up_direction * (STAND_HEIGHT - CROUCH_HEIGHT))


func _try_interact() -> void:
	_interact_ray.force_raycast_update()
	if not _interact_ray.is_colliding():
		return
	var collider: Object = _interact_ray.get_collider()
	if collider != null and collider.has_method(&"interact"):
		collider.call(&"interact", self)
