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


func _ready() -> void:
	system_id = &"sector"
	add_to_group(&"sector_system")
	super._ready()
	_rebuild_active()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	_drift_distance_m += drift_speed_m_per_hour * delta_hours
	var chunk: int = int(floor(_drift_distance_m / CHUNK_SIZE_M))
	if chunk != _base_chunk:
		_base_chunk = chunk
		_rebuild_active()
	_update_contacts()


func get_ship_position() -> Vector3:
	return drift_axis.normalized() * _drift_distance_m


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
				if content >= CONTENT_PER_TEN_THOUSAND:
					continue
				var entry: Dictionary = _make_object(cx, cy, cz, axis, right, up)
				_active.append(entry)


func _make_object(cx: int, cy: int, cz: int, axis: Vector3, right: Vector3, up: Vector3) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = chunk_hash(cx, cy, cz)
	var chunk_center: Vector3 = axis * (float(cx) * CHUNK_SIZE_M) + right * (float(cy) * CHUNK_SIZE_M) + up * (float(cz) * CHUNK_SIZE_M)
	var offset: Vector3 = right * rng.randf_range(-CHUNK_SIZE_M * 0.4, CHUNK_SIZE_M * 0.4) + up * rng.randf_range(-CHUNK_SIZE_M * 0.4, CHUNK_SIZE_M * 0.4) + axis * rng.randf_range(-CHUNK_SIZE_M * 0.4, CHUNK_SIZE_M * 0.4)
	var roll: float = rng.randf()
	var kind: StringName = KIND_ASTEROID
	if roll > 0.90:
		kind = KIND_ANOMALY
	elif roll > 0.70:
		kind = KIND_DEBRIS
	var radius: float = 6.0
	match kind:
		KIND_ASTEROID:
			radius = rng.randf_range(4.0, 12.0)
		KIND_DEBRIS:
			radius = rng.randf_range(2.0, 5.0)
		KIND_ANOMALY:
			radius = rng.randf_range(3.0, 7.0)
	return {
		"id": "c_%d_%d_%d" % [cx, cy, cz],
		"kind": kind,
		"position": chunk_center + offset,
		"radius_m": radius,
		"seed": int(rng.seed),
	}


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
	}


func load_state(state: Dictionary) -> void:
	field_seed = int(state.get("field_seed", field_seed))
	_drift_distance_m = maxf(float(state.get("drift_distance_m", _drift_distance_m)), 0.0)
	_base_chunk = int(floor(_drift_distance_m / CHUNK_SIZE_M))
	_rebuild_active()
	_contact_ids.clear()
	_update_contacts()
