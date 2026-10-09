## Deterministic near-infinite field around the drifting ship: a chunk corridor along the
## drift axis, ~98% empty, seeded from (field seed, chunk coordinates). Objects are pure
## data; a scene streamer (M8.2) binds visuals to whatever the sim has active.
class_name SectorSystem
extends ShipSystem

const CHUNK_SIZE_M: float = 200.0
const LATERAL_CHUNKS: int = 2
const STREAM_CHUNKS_AHEAD: int = 3
const STREAM_CHUNKS_BEHIND: int = 1
const CONTENT_PER_TEN_THOUSAND: int = 200
const CONTACT_RANGE_M: float = 900.0
const STANDOFF_M: float = 30.0
const APPROACH_SPEED_M_PER_HOUR: float = 6000.0
const KIND_ASTEROID: StringName = &"asteroid"
const KIND_DEBRIS: StringName = &"debris"
const KIND_ANOMALY: StringName = &"anomaly"

@export var field_seed: int = 20260918
@export var drift_speed_m_per_hour: float = 1500.0
@export var drift_axis: Vector3 = Vector3.FORWARD

var _drift_distance_m: float = 0.0
var _base_chunk: int = -999999
var _active: Array[Dictionary] = []
var _contact_ids: Dictionary = {}
var _offset: Vector3 = Vector3.ZERO
var _holding: bool = false
var _approach_target_id: String = ""
var _mined: Dictionary = {}
var asteroid_frequency: float = 1.0
var anomaly_frequency: float = 1.0


func _ready() -> void:
	system_id = &"sector"
	add_to_group(&"sector_system")
	super._ready()
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null and not event_bus.is_connected(&"destination_arrived", _on_destination_arrived):
		event_bus.connect(&"destination_arrived", _on_destination_arrived)
	var settings: Node = _get_autoload(&"GameSettings")
	if settings != null:
		asteroid_frequency = float(settings.call(&"get_value", &"asteroid_frequency"))
		anomaly_frequency = float(settings.call(&"get_value", &"anomaly_frequency"))
		if settings.has_signal(&"settings_changed") and not settings.is_connected(&"settings_changed", _on_settings_changed):
			settings.connect(&"settings_changed", _on_settings_changed)
	_rebuild_active()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	if _approach_target_id != "":
		_tick_approach(delta_hours)
	if not _holding:
		_drift_distance_m += drift_speed_m_per_hour * delta_hours
	var chunk: int = int(floor(_drift_distance_m / CHUNK_SIZE_M))
	if chunk != _base_chunk:
		_base_chunk = chunk
		_rebuild_active()
	_update_contacts()


## Closes the gap to an active contact and parks at standoff, matching its velocity.
func begin_approach(contact_id: String) -> bool:
	for entry: Dictionary in _active:
		if String(entry["id"]) == contact_id:
			_approach_target_id = contact_id
			_holding = false
			emit_sim_event(&"approach_started", {"id": contact_id, "kind": String(entry["kind"])})
			return true
	return false


func resume_drift() -> void:
	if not _holding and _approach_target_id == "":
		return
	_holding = false
	_approach_target_id = ""
	emit_sim_event(&"drift_resumed", {})


func is_holding() -> bool:
	return _holding


func get_approach_target_id() -> String:
	return _approach_target_id


func get_ship_position() -> Vector3:
	return drift_axis.normalized() * _drift_distance_m + _offset


func get_drift_distance() -> float:
	return _drift_distance_m


## Active stream objects, with world positions and kinds. Duplicated for safety.
func get_active_objects() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry: Dictionary in _active:
		copy.append(entry.duplicate())
	return copy


## Active objects within `max_range_m` of the ship, nearest first.
func get_contacts(max_range_m: float = CONTACT_RANGE_M) -> Array[Dictionary]:
	var ship: Vector3 = get_ship_position()
	var found: Array[Dictionary] = []
	for entry: Dictionary in _active:
		var distance: float = (entry["position"] as Vector3).distance_to(ship)
		if distance <= max_range_m:
			var contact: Dictionary = entry.duplicate()
			contact["distance_m"] = distance
			found.append(contact)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance_m"]) < float(b["distance_m"]))
	return found


func get_chunk_size() -> float:
	return CHUNK_SIZE_M


func get_encounter_frequency(key: StringName) -> float:
	match key:
		&"asteroid_frequency":
			return asteroid_frequency
		&"anomaly_frequency":
			return anomaly_frequency
	return 1.0


## Nearest active contact, or an empty dictionary when nothing is in range.
func get_nearest_contact() -> Dictionary:
	var contacts: Array[Dictionary] = get_contacts()
	if contacts.is_empty():
		return {}
	return contacts[0]


## Deterministic integer hash of chunk coordinates + the field seed.
func chunk_hash(cx: int, cy: int, cz: int) -> int:
	var h: int = field_seed
	h = h * 374761393 + cx * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	h = h * 374761393 + cy * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	h = h * 374761393 + cz * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h)


func _tick_approach(delta_hours: float) -> void:
	var target: Dictionary = {}
	for entry: Dictionary in _active:
		if String(entry["id"]) == _approach_target_id:
			target = entry
			break
	if target.is_empty():
		_approach_target_id = ""
		return
	var position: Vector3 = get_ship_position()
	var target_position: Vector3 = target["position"]
	var bearing: Vector3 = position - target_position
	if bearing.length() < 0.001:
		bearing = Vector3.UP
	bearing = bearing.normalized()
	var desired: Vector3 = target_position + bearing * STANDOFF_M
	var step: float = APPROACH_SPEED_M_PER_HOUR * delta_hours
	var next: Vector3 = position.move_toward(desired, step)
	_offset = next - drift_axis.normalized() * _drift_distance_m
	if next.distance_to(desired) < 0.5 or next.distance_to(target_position) <= STANDOFF_M + 0.5:
		_holding = true
		emit_sim_event(&"approach_complete", {
			"id": _approach_target_id,
			"distance_m": next.distance_to(target_position),
		})


func _rebuild_active() -> void:
	_active.clear()
	var axis: Vector3 = drift_axis.normalized()
	var right: Vector3 = axis.cross(Vector3.UP)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up: Vector3 = right.cross(axis).normalized()
	for cx: int in range(_base_chunk - STREAM_CHUNKS_BEHIND, _base_chunk + STREAM_CHUNKS_AHEAD + 1):
		for cy: int in range(-LATERAL_CHUNKS, LATERAL_CHUNKS + 1):
			for cz: int in range(-LATERAL_CHUNKS, LATERAL_CHUNKS + 1):
				var content: int = chunk_hash(cx, cy, cz) % 10000
				var content_limit: int = roundi(float(CONTENT_PER_TEN_THOUSAND) * asteroid_frequency)
				if content >= content_limit:
					continue
				var entry: Dictionary = _make_object(cx, cy, cz, axis, right, up)
				_active.append(entry)


func _on_destination_arrived(_destination_id: StringName, _kind: StringName, next_seed: int, _resource_id: StringName, _resource_units: float, _arrival_stores: Dictionary) -> void:
	field_seed = next_seed
	_drift_distance_m = 0.0
	_offset = Vector3.ZERO
	_holding = false
	_approach_target_id = ""
	_mined.clear()
	_base_chunk = -999999
	_contact_ids.clear()
	_rebuild_active()
	_update_contacts()


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == &"asteroid_frequency":
		asteroid_frequency = clampf(float(value), 0.0, 3.0)
	elif key == &"anomaly_frequency":
		anomaly_frequency = clampf(float(value), 0.0, 3.0)
	else:
		return
	_rebuild_active()


func _make_object(cx: int, cy: int, cz: int, axis: Vector3, right: Vector3, up: Vector3) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = chunk_hash(cx, cy, cz)
	var chunk_center: Vector3 = axis * (float(cx) * CHUNK_SIZE_M) + right * (float(cy) * CHUNK_SIZE_M) + up * (float(cz) * CHUNK_SIZE_M)
	var offset: Vector3 = right * rng.randf_range(-CHUNK_SIZE_M * 0.4, CHUNK_SIZE_M * 0.4) + up * rng.randf_range(-CHUNK_SIZE_M * 0.4, CHUNK_SIZE_M * 0.4) + axis * rng.randf_range(-CHUNK_SIZE_M * 0.4, CHUNK_SIZE_M * 0.4)
	var roll: float = rng.randf() * (9.0 + anomaly_frequency)
	var kind: StringName = KIND_ASTEROID
	if roll >= 9.0:
		kind = KIND_ANOMALY
	elif roll >= 7.0:
		kind = KIND_DEBRIS
	var radius: float = 6.0
	var resource: StringName = &"ore"
	var yield_units: float = 0.0
	match kind:
		KIND_ASTEROID:
			radius = rng.randf_range(4.0, 12.0)
			var resource_roll: float = rng.randf()
			if resource_roll < 0.4:
				resource = &"ice"
			elif resource_roll < 0.8:
				resource = &"ore"
			else:
				resource = &"metal"
			yield_units = rng.randf_range(8.0, 20.0)
		KIND_DEBRIS:
			radius = rng.randf_range(2.0, 5.0)
			resource = &"metal"
			yield_units = rng.randf_range(2.0, 5.0)
		KIND_ANOMALY:
			radius = rng.randf_range(3.0, 7.0)
			resource = &"exotic"
			yield_units = rng.randf_range(4.0, 8.0)
	return {
		"id": "c_%d_%d_%d" % [cx, cy, cz],
		"kind": kind,
		"position": chunk_center + offset,
		"radius_m": radius,
		"seed": int(rng.seed),
		"resource": resource,
		"yield_units": yield_units,
	}


## Remaining extractable units for an object id; unknown ids read as zero.
func get_remaining_yield(object_id: String) -> float:
	if _mined.has(object_id):
		return float(_mined[object_id])
	for entry: Dictionary in _active:
		if String(entry["id"]) == object_id:
			return float(entry.get("yield_units", 0.0))
	return 0.0


## Records extraction; clamps at zero and returns the units actually removed.
func record_mined(object_id: String, units: float) -> float:
	if units <= 0.0:
		return 0.0
	var remaining: float = get_remaining_yield(object_id)
	var removed: float = minf(units, remaining)
	_mined[object_id] = maxf(remaining - removed, 0.0)
	return removed


func _update_contacts() -> void:
	var current: Dictionary = {}
	for entry: Dictionary in get_contacts():
		var id: String = String(entry["id"])
		current[id] = true
		if not _contact_ids.has(id):
			emit_sim_event(&"sector_contact_entered", {"id": id, "kind": String(entry["kind"]), "distance_m": entry["distance_m"]})
	for id: String in _contact_ids:
		if not current.has(id):
			emit_sim_event(&"sector_contact_left", {"id": id})
	_contact_ids = current


func save_state() -> Dictionary:
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"field_seed": field_seed,
		"drift_distance_m": _drift_distance_m,
		"offset": {"x": _offset.x, "y": _offset.y, "z": _offset.z},
		"holding": _holding,
		"approach_target_id": _approach_target_id,
		"mined": _mined.duplicate(),
	}


func load_state(state: Dictionary) -> void:
	field_seed = int(state.get("field_seed", field_seed))
	_drift_distance_m = maxf(float(state.get("drift_distance_m", _drift_distance_m)), 0.0)
	var offset_data: Dictionary = state.get("offset", {})
	_offset = Vector3(
		float(offset_data.get("x", 0.0)),
		float(offset_data.get("y", 0.0)),
		float(offset_data.get("z", 0.0))
	)
	_holding = bool(state.get("holding", false))
	_approach_target_id = String(state.get("approach_target_id", ""))
	_mined.clear()
	var mined: Dictionary = state.get("mined", {})
	for key: Variant in mined:
		_mined[String(key)] = maxf(float(mined[key]), 0.0)
	_base_chunk = int(floor(_drift_distance_m / CHUNK_SIZE_M))
	_rebuild_active()
	_contact_ids.clear()
	_update_contacts()
