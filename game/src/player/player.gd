## Magnetic-boot hybrid first-person controller: gravity walking while boots are engaged, zero-g drift otherwise.
extends CharacterBody3D

const STAND_HEIGHT: float = 1.75
const CROUCH_HEIGHT: float = 1.15
const STAND_HEAD_Y: float = 1.55
const CROUCH_HEAD_Y: float = 0.95
const BOOTS_LOST_GRACE: float = 0.15
const NORMAL_EPSILON: float = 0.000001
const BASE_MOUSE_SENSITIVITY: float = 0.002
const STRIDE_LENGTH_M: float = 1.2
const HOLD_OFFSET: Vector3 = Vector3(0.32, -0.26, -0.55)
const DROP_DISTANCE_M: float = 1.1
const DROP_FALLBACK_DISTANCE_M: float = 1.0
const DROP_FALLBACK_LIFT_M: float = 0.3
const TETHER_ATTACH_RANGE: float = 6.0
const SEATED_HEAD_Y: float = 1.18
const SEATED_RAY_LENGTH: float = 3.6
const SEAT_MOTION_SPEED: float = 2.4
const SEAT_MOTION_MIN_SECONDS: float = 0.38
const SEAT_MOTION_MAX_SECONDS: float = 0.72

@export var walk_speed: float = 3.0
@export var crouch_speed: float = 1.5
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0
@export var boots_gravity: float = 12.0
@export var boots_range: float = 2.2
@export var push_off_speed: float = 1.6
@export var thruster_accel: float = 2.4
@export var brake_accel: float = 4.0
@export var surface_reach: float = 0.65
@export var roll_speed: float = 1.2
@export var free_damping: float = 0.05
@export var mouse_sensitivity: float = BASE_MOUSE_SENSITIVITY
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
var _invert_y: bool = false
var _step_distance: float = 0.0
var _step_index: int = 0
var _carried_item: Node = null
var _suit_cutter: bool = false
var _tether_anchor: Node3D = null
var _tethered: bool = false
var _tether_strain_armed: bool = true
var _pilot_seat: PilotChair = null
var _seat_transitioning: bool = false
var _seated: bool = false
var _standing_ray_target: Vector3 = Vector3.ZERO
var _standing_ray_enabled: bool = true
var _seat_tween: Tween


func _ready() -> void:
	var capsule: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
	if capsule != null:
		_collision_shape.shape = capsule.duplicate()
	up_direction = Vector3.UP
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.1
	add_to_group(&"player")
	_apply_settings()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if _seat_transitioning or is_pilot_seated():
		velocity = Vector3.ZERO
		return
	_set_crouched(_boots_engaged and Input.is_action_pressed(&"crouch"))
	_head.position.y = lerpf(_head.position.y, CROUCH_HEAD_Y if _crouched else STAND_HEAD_Y, minf(delta * 12.0, 1.0))
	if _boots_engaged:
		_process_engaged(delta)
	else:
		_process_free(delta)
	move_and_slide()
	_apply_tether()
	if _boots_engaged and is_on_floor():
		advance_footsteps(get_planar_speed() * delta)


func is_boots_engaged() -> bool:
	return _boots_engaged


func is_exterior() -> bool:
	var atmosphere: Node = get_tree().get_first_node_in_group(&"atmosphere_system")
	if atmosphere == null:
		return false
	var compartments: Dictionary = atmosphere.call("get_status").get("compartments", {})
	for compartment: Dictionary in compartments.values():
		if int(compartment.get("occupants", 0)) > 0:
			return false
	return true


func is_invert_y() -> bool:
	return _invert_y


func advance_footsteps(distance_m: float) -> int:
	if not is_finite(distance_m) or distance_m <= 0.0:
		return 0
	_step_distance += distance_m
	var steps: int = 0
	while _step_distance >= STRIDE_LENGTH_M:
		_step_distance -= STRIDE_LENGTH_M
		_emit_sim_event(&"footstep", {"variant": _step_index % 3})
		_step_index += 1
		steps += 1
	return steps


func get_step_count() -> int:
	return _step_index


func get_planar_speed() -> float:
	var vertical_speed: float = velocity.dot(up_direction)
	return (velocity - up_direction * vertical_speed).length()


func is_pilot_seated() -> bool:
	return _seated and _pilot_seat != null and is_instance_valid(_pilot_seat)


func get_pilot_seat() -> PilotChair:
	return _pilot_seat if is_pilot_seated() else null


func get_seated_target() -> CollisionObject3D:
	if not is_pilot_seated():
		return null
	_interact_ray.force_raycast_update()
	return _interact_ray.get_collider() as CollisionObject3D if _interact_ray.is_colliding() else null


func enter_pilot_seat(chair: PilotChair) -> bool:
	if is_pilot_seated() or _seat_transitioning or chair == null or not is_instance_valid(chair):
		return false
	if global_position.distance_to(chair.global_position) > PilotChair.APPROACH_RADIUS + 0.3:
		return false
	_pilot_seat = chair
	_seat_transitioning = true
	_seated = false
	_standing_ray_target = _interact_ray.target_position
	_standing_ray_enabled = _interact_ray.enabled
	_interact_ray.enabled = false
	velocity = Vector3.ZERO
	_collision_shape.set_deferred(&"disabled", true)
	_interact_ray.add_exception(chair)
	if not chair.boarding_ready.is_connected(_on_pilot_chair_ready):
		chair.boarding_ready.connect(_on_pilot_chair_ready, CONNECT_ONE_SHOT)
	chair.set_occupied(true)
	return true


func exit_pilot_seat() -> void:
	if not is_pilot_seated():
		return
	var chair: PilotChair = _pilot_seat
	_seated = false
	_seat_transitioning = true
	_interact_ray.enabled = false
	chair.set_occupied(false)
	_start_seat_motion(chair.get_exit_world_position(), rotation.y, STAND_HEAD_Y, _finish_seat_exit)


func _on_pilot_chair_ready(chair: PilotChair) -> void:
	if not _seat_transitioning or chair != _pilot_seat or not is_instance_valid(chair):
		return
	var start_head_y: float = _head.position.y
	_set_crouched(false)
	_head.position.y = start_head_y
	var seated_yaw: float = chair.get_seated_yaw()
	_start_seat_motion(chair.get_seat_world_position(), seated_yaw, SEATED_HEAD_Y, _finish_seat_entry)


func _start_seat_motion(target_position: Vector3, target_yaw: float, target_head_y: float, finished: Callable) -> void:
	if _seat_tween != null and _seat_tween.is_valid():
		_seat_tween.kill()
	var duration: float = clampf(global_position.distance_to(target_position) / SEAT_MOTION_SPEED, SEAT_MOTION_MIN_SECONDS, SEAT_MOTION_MAX_SECONDS)
	var start_yaw: float = rotation.y
	var start_pitch: float = _head.rotation.x
	_seat_tween = create_tween().set_parallel(true)
	_seat_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_seat_tween.tween_property(self, ^"global_position", target_position, duration)
	_seat_tween.tween_property(self, ^"rotation:x", 0.0, duration)
	_seat_tween.tween_property(self, ^"rotation:z", 0.0, duration)
	_seat_tween.tween_method(_set_yaw_between.bind(start_yaw, target_yaw), 0.0, 1.0, duration)
	_seat_tween.tween_property(_head, ^"position:y", target_head_y, duration)
	_seat_tween.tween_property(_head, ^"rotation:x", 0.0 if target_head_y == SEATED_HEAD_Y else start_pitch, duration)
	_seat_tween.finished.connect(finished)


func _set_yaw_between(progress: float, start_yaw: float, target_yaw: float) -> void:
	rotation.y = lerp_angle(start_yaw, target_yaw, progress)


func _finish_seat_entry() -> void:
	if _pilot_seat == null or not is_instance_valid(_pilot_seat):
		_finish_seat_exit()
		return
	_seat_transitioning = false
	_seated = true
	_pitch = 0.0
	_head.rotation.x = 0.0
	_interact_ray.target_position = Vector3(0.0, 0.0, -SEATED_RAY_LENGTH)
	_interact_ray.enabled = true


func _finish_seat_exit() -> void:
	var chair: PilotChair = _pilot_seat
	_pilot_seat = null
	_seat_transitioning = false
	_collision_shape.set_deferred(&"disabled", false)
	_interact_ray.target_position = _standing_ray_target
	_interact_ray.enabled = _standing_ray_enabled
	if is_instance_valid(chair):
		_interact_ray.remove_exception(chair)


func engage_boots() -> bool:
	var normal: Vector3 = _find_anchor_normal()
	if normal == Vector3.ZERO:
		return false
	if not _align_up(normal):
		return false
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
	var normal: Vector3 = _nearby_surface_normal()
	if normal == Vector3.ZERO:
		return false
	# Remove incoming momentum so a push always carries us away from the surface.
	velocity += normal * (push_off_speed - minf(velocity.dot(normal), 0.0))
	return true


func equip_suit_cutter() -> bool:
	if _suit_cutter:
		return false
	_suit_cutter = true
	_emit_sim_event(&"tool_equipped", {"tool": &"cutter"})
	return true


func has_suit_cutter() -> bool:
	return _suit_cutter


func reset_tools_for_load() -> void:
	if _seat_tween != null and _seat_tween.is_valid():
		_seat_tween.kill()
	if _pilot_seat != null and is_instance_valid(_pilot_seat):
		_pilot_seat.set_occupied(false)
		_seated = false
		_finish_seat_exit()
	_set_crouched(false)
	_head.position.y = STAND_HEAD_Y
	drop_carried()
	for child: Node in _camera.get_children():
		if child.has_method(&"return_home"):
			child.call("return_home")
	_suit_cutter = false


## The node held items and suit-clipped gear ride: the eye camera.
func get_hold_anchor() -> Node3D:
	return _camera


func take_carriable(item: Node) -> bool:
	if item == null or not is_instance_valid(item):
		return false
	if _carried_item == item:
		return true
	if not item.has_method(&"equip_to"):
		return false
	if item.has_method(&"is_carried") and bool(item.call(&"is_carried")):
		return false
	if has_carried_item():
		drop_carried()
	item.call(&"equip_to", _camera)
	var node: Node3D = item as Node3D
	if node != null:
		node.position = HOLD_OFFSET
		node.rotation = Vector3.ZERO
	_add_carry_exception(item)
	_carried_item = item
	_emit_sim_event(&"item_taken", {"item_id": get_carried_item_id()})
	return true


func drop_carried() -> Node:
	var item: Node = get_carried()
	if item == null:
		return null
	var item_id: StringName = get_carried_item_id()
	var drop_transform: Transform3D = _compute_drop_transform(item)
	_remove_carry_exception(item)
	_carried_item = null
	if item.has_method(&"unequip"):
		item.call(&"unequip", drop_transform)
	_emit_sim_event(&"item_dropped", {"item_id": item_id})
	return item


func get_carried() -> Node:
	if _carried_item != null and not is_instance_valid(_carried_item):
		_carried_item = null
	return _carried_item


func has_carried_item() -> bool:
	return get_carried() != null


func get_carried_item_id() -> StringName:
	var item: Node = get_carried()
	if item == null or not item.has_method(&"get_item_id"):
		return &""
	return StringName(item.call(&"get_item_id"))


func consume_carried() -> bool:
	var item: Node = get_carried()
	if item == null:
		return false
	var item_id: StringName = get_carried_item_id()
	_remove_carry_exception(item)
	_carried_item = null
	# Scene props without a simulator record of their absence park disabled so a
	# reload cannot resurrect them; dynamically spawned units (with an owning
	# record elsewhere) are freed as before.
	if item.has_method(&"mark_consumed"):
		item.call(&"mark_consumed")
	else:
		item.free()
	_emit_sim_event(&"item_consumed", {"item_id": item_id})
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _seat_transitioning:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_apply_look_motion(motion.relative)
	elif is_pilot_seated():
		if event.is_action_pressed(&"leave_seat"):
			exit_pilot_seat()
		elif event.is_action_pressed(&"interact"):
			_try_interact()
		elif event.is_action_pressed(&"flashlight"):
			_flashlight.visible = not _flashlight.visible
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
	elif event.is_action_pressed(&"secondary"):
		if has_carried_item():
			drop_carried()
	elif event.is_action_pressed(&"flashlight"):
		_flashlight.visible = not _flashlight.visible
	elif event.is_action_pressed(&"primary"):
		_scan_ping()
	elif event.is_action_pressed(&"toggle_tether"):
		_toggle_tether()


func _apply_look_motion(relative: Vector2) -> void:
	rotate_object_local(Vector3.UP, -relative.x * mouse_sensitivity)
	var pitch_limit: float = deg_to_rad(pitch_limit_deg)
	var direction: float = 1.0 if not _invert_y else -1.0
	_pitch = clampf(_pitch - relative.y * mouse_sensitivity * direction, -pitch_limit, pitch_limit)
	_head.rotation.x = _pitch


func attach_tether(anchor: Node3D) -> bool:
	if anchor == null or not is_instance_valid(anchor):
		return false
	_tether_anchor = anchor
	_tethered = true
	_tether_strain_armed = true
	_emit_sim_event(&"tether_attached", {"anchor": String(anchor.name)})
	return true


func release_tether() -> void:
	if not _tethered:
		return
	_tethered = false
	_tether_anchor = null
	_tether_strain_armed = true
	_emit_sim_event(&"tether_released", {})


func is_tethered() -> bool:
	return _tethered


func get_tether_distance() -> float:
	if not _tethered or _tether_anchor == null or not is_instance_valid(_tether_anchor):
		return 0.0
	return global_position.distance_to(_tether_anchor.global_position)


func get_tether_extension_ratio() -> float:
	if not _tethered or _tether_anchor == null or not is_instance_valid(_tether_anchor):
		return 0.0
	var limit: float = float(_tether_anchor.get(&"max_length"))
	if limit <= 0.0:
		limit = 14.0
	return clampf(get_tether_distance() / limit, 0.0, 1.0)


func _toggle_tether() -> void:
	if _tethered:
		release_tether()
		return
	var anchor: Node3D = _nearest_anchor()
	if anchor != null:
		attach_tether(anchor)


func _nearest_anchor() -> Node3D:
	var best: Node3D = null
	var best_distance: float = TETHER_ATTACH_RANGE
	for node: Node in get_tree().get_nodes_in_group(&"tether_anchor"):
		var anchor: Node3D = node as Node3D
		if anchor == null:
			continue
		var distance: float = anchor.global_position.distance_to(global_position)
		if distance <= best_distance:
			best_distance = distance
			best = anchor
	return best


func _apply_tether() -> void:
	if not _tethered:
		return
	if _tether_anchor == null or not is_instance_valid(_tether_anchor):
		release_tether()
		return
	var extension_ratio: float = get_tether_extension_ratio()
	if extension_ratio < 0.8:
		_tether_strain_armed = true
	elif extension_ratio >= 0.9 and _tether_strain_armed:
		_tether_strain_armed = false
		_emit_sim_event(&"tether_strained", {"ratio": extension_ratio})
	var to_anchor: Vector3 = _tether_anchor.global_position - global_position
	var distance: float = to_anchor.length()
	if distance <= 0.0001:
		return
	var limit: float = float(_tether_anchor.get(&"max_length"))
	if limit <= 0.0:
		limit = 14.0
	if distance <= limit:
		return
	var direction_out: Vector3 = to_anchor / distance
	move_and_collide(direction_out * (distance - limit))
	var outward_speed: float = velocity.dot(-direction_out)
	if outward_speed > 0.0:
		velocity += direction_out * outward_speed


func _scan_ping() -> void:
	if get_carried_item_id() != &"scanner":
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var sector: Node = tree.get_first_node_in_group(&"sector_system")
	if sector == null or not sector.has_method(&"get_nearest_contact"):
		return
	var contact: Dictionary = sector.call("get_nearest_contact")
	if contact.is_empty():
		_emit_sim_event(&"scanner_ping", {"distance_m": -1.0, "kind": &""})
		return
	_emit_sim_event(&"scanner_ping", {
		"distance_m": float(contact.get("distance_m", 0.0)),
		"kind": contact.get("kind", &""),
		"id": contact.get("id", ""),
	})


func _apply_settings() -> void:
	var settings: Node = get_node_or_null(^"/root/GameSettings")
	if settings == null or not settings.has_method(&"get_value"):
		return
	mouse_sensitivity = BASE_MOUSE_SENSITIVITY * float(
		settings.call(&"get_value", &"mouse_sensitivity_multiplier")
	)
	_invert_y = bool(settings.call(&"get_value", &"invert_y"))
	if settings.has_signal(&"settings_changed") and not settings.is_connected(&"settings_changed", _on_setting_changed):
		settings.connect(&"settings_changed", _on_setting_changed)


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"mouse_sensitivity_multiplier":
		mouse_sensitivity = BASE_MOUSE_SENSITIVITY * float(value)
	elif key == &"invert_y":
		_invert_y = bool(value)


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
	var roll: float = Input.get_axis(&"roll_left", &"roll_right")
	if roll != 0.0:
		var center: Vector3 = global_transform * _collision_shape.position
		rotate_object_local(Vector3.FORWARD, roll * roll_speed * delta)
		global_position = center - global_basis * _collision_shape.position
	if Input.is_action_pressed(&"brake"):
		velocity = velocity.move_toward(Vector3.ZERO, brake_accel * delta)
		return
	velocity *= maxf(0.0, 1.0 - free_damping * delta)
	var wish_direction: Vector3 = _free_wish_direction()
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


func _free_wish_direction() -> Vector3:
	var input_vector: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var vertical: float = Input.get_action_strength(&"jump") - Input.get_action_strength(&"crouch")
	var wish: Vector3 = _camera.global_transform.basis.x * input_vector.x + _camera.global_transform.basis.z * input_vector.y
	wish += global_transform.basis.y * vertical
	return wish.limit_length(1.0)


func _surface_ray(origin: Vector3, direction: Vector3, reach: float) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * reach)
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _find_anchor_normal() -> Vector3:
	# Prefer the deck even when drift has left a wall contact cached by move_and_slide.
	for direction: Vector3 in [Vector3.DOWN, -global_basis.y]:
		var hit: Dictionary = _surface_ray(global_position + global_basis.y * 0.05, direction, boots_range)
		if not hit.is_empty():
			return hit["normal"]
	return _nearby_surface_normal()


func _nearby_surface_normal() -> Vector3:
	var best_distance: float = INF
	var normal: Vector3 = Vector3.ZERO
	var capsule: CapsuleShape3D = _collision_shape.shape as CapsuleShape3D
	for height: float in [capsule.radius, capsule.height * 0.5, capsule.height - capsule.radius]:
		var origin: Vector3 = global_position + global_basis.y * height
		for x: int in range(-1, 2):
			for y: int in range(-1, 2):
				for z: int in range(-1, 2):
					var direction: Vector3 = Vector3(x, y, z).normalized()
					if direction == Vector3.ZERO:
						continue
					var hit: Dictionary = _surface_ray(origin, direction, surface_reach + capsule.radius)
					if hit.is_empty():
						continue
					var distance: float = origin.distance_to(hit["position"])
					if distance < best_distance:
						best_distance = distance
						normal = hit["normal"]
	return normal


func _align_up(normal: Vector3) -> bool:
	var current_up: Vector3 = global_basis.y.normalized()
	if current_up.dot(normal) > 0.9999:
		return true
	var axis: Vector3 = current_up.cross(normal)
	if axis.length_squared() <= NORMAL_EPSILON:
		axis = global_basis.x
	var target: Transform3D = global_transform
	target.basis = (Basis(axis.normalized(), current_up.angle_to(normal)) * target.basis).orthonormalized()
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var clearance: CapsuleShape3D = _collision_shape.shape.duplicate() as CapsuleShape3D
	clearance.radius -= 0.02
	clearance.height -= 0.04
	query.shape = clearance
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	# Center rotation fits low cabins; the feet pivot lets an EVA operator turn away from a close hull.
	var fitted: bool = false
	for pivot: Vector3 in [_collision_shape.position, Vector3.ZERO]:
		var center: Vector3 = global_transform * pivot
		var clear: bool = true
		for step: int in range(1, 9):
			var pose: Transform3D = global_transform
			pose.basis = global_basis.slerp(target.basis, float(step) / 8.0).orthonormalized()
			pose.origin = center - pose.basis * pivot
			query.transform = pose * _collision_shape.transform
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				clear = false
				break
		if clear:
			target.origin = center - target.basis * pivot
			fitted = true
			break
	if not fitted:
		return false
	var view: Transform3D = _camera.global_transform
	global_transform = target
	_camera.global_transform = view
	var alignment: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	alignment.tween_property(_camera, ^"quaternion", Quaternion.IDENTITY, 0.25)
	alignment.tween_property(_camera, ^"position", Vector3.ZERO, 0.25)
	return true


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


func _is_blocked_above() -> bool:
	return test_move(global_transform, up_direction * (STAND_HEIGHT - CROUCH_HEIGHT))


func _try_interact() -> void:
	_interact_ray.force_raycast_update()
	if not _interact_ray.is_colliding():
		return
	var collider: Object = _interact_ray.get_collider()
	if collider != null and collider.has_method(&"interact"):
		collider.call(&"interact", self)


func _add_carry_exception(item: Node) -> void:
	var collision_item: CollisionObject3D = item as CollisionObject3D
	if collision_item != null:
		_interact_ray.add_exception(collision_item)


func _remove_carry_exception(item: Node) -> void:
	var collision_item: CollisionObject3D = item as CollisionObject3D
	if collision_item != null and is_instance_valid(_interact_ray):
		_interact_ray.remove_exception(collision_item)


func _compute_drop_transform(item: Node) -> Transform3D:
	var up: Vector3 = up_direction
	var forward: Vector3 = -_camera.global_transform.basis.z.normalized()
	var origin: Vector3 = _camera.global_position
	var basis: Basis = Basis.IDENTITY
	var node: Node3D = item as Node3D
	if node != null and node.global_transform.is_finite():
		basis = node.global_transform.basis
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state != null:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, origin + forward * DROP_DISTANCE_M
		)
		var exclusions: Array[RID] = [get_rid()]
		var collision_item: CollisionObject3D = item as CollisionObject3D
		if collision_item != null:
			exclusions.append(collision_item.get_rid())
		query.exclude = exclusions
		if space_state.intersect_ray(query).is_empty():
			return Transform3D(basis, origin + forward * DROP_DISTANCE_M)
	# why: an obstacle inside the drop line makes the clean spot unsafe (floor, wall, machinery),
	# so fall back to a short reach in front of the body, lifted along the boots' up direction.
	var reach: Vector3 = forward - up * forward.dot(up)
	if reach.length_squared() <= NORMAL_EPSILON:
		var body_forward: Vector3 = -global_transform.basis.z
		reach = body_forward - up * body_forward.dot(up)
	if reach.length_squared() <= NORMAL_EPSILON:
		reach = Vector3.ZERO
	else:
		reach = reach.normalized()
	return Transform3D(basis, global_position + up * DROP_FALLBACK_LIFT_M + reach * DROP_FALLBACK_DISTANCE_M)


func _emit_sim_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.call("emit_event", event_name, payload)


func _get_autoload(autoload_name: StringName) -> Node:
	if is_inside_tree():
		return get_node_or_null(NodePath("/root/" + String(autoload_name)))
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_root: Window = (main_loop as SceneTree).root
		if scene_root != null:
			for child: Node in scene_root.get_children():
				if child.name == autoload_name:
					return child
	return null
