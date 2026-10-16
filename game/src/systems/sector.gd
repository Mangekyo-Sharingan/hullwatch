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
var _mined_fields: Dictionary = {}
var _survey_sources: Dictionary = {}
var _survey_records: Dictionary = {}
var asteroid_frequency: float = 1.0
var anomaly_frequency: float = 1.0


func _ready() -> void:
	system_id = &"sector"
	add_to_group(&"sector_system")
	super._ready()
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null and not event_bus.is_connected(&"destination_arrived", _on_destination_arrived):
		event_bus.connect(&"destination_arrived", _on_destination_arrived)
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_survey_event)
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
func get_contacts(max_range_m: float = -1.0) -> Array[Dictionary]:
	if max_range_m < 0.0:
		max_range_m = get_detection_range()
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


func set_survey_source(source_id: StringName, range_m: float) -> void:
	if source_id == &"" or not is_finite(range_m) or range_m < 0.0:
		return
	if is_equal_approx(float(_survey_sources.get(source_id, 0.0)), range_m):
		return
	if range_m == 0.0:
		_survey_sources.erase(source_id)
	else:
		_survey_sources[source_id] = range_m
	_update_contacts()


func get_detection_range() -> float:
	var range_m: float = CONTACT_RANGE_M
	for contribution: Variant in _survey_sources.values():
		range_m += float(contribution)
	return range_m


func record_survey(object_id: String) -> bool:
	var player: Node = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	if player == null or not player.has_method(&"get_carried_item_id") or StringName(player.call(&"get_carried_item_id")) != &"scanner":
		return false
	for contact: Dictionary in get_contacts():
		if String(contact["id"]) == object_id:
			_observe_contact(contact, str(field_seed))
			return true
	return false


func get_survey_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in _survey_records.values():
		records.append(record.duplicate(true))
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["record_id"]) < String(b["record_id"]))
	return records


func _observe_contact(contact: Dictionary, field: String) -> Dictionary:
	var object_id: String = String(contact["id"])
	var record_id: String = field + ":" + object_id
	if not _survey_records.has(record_id):
		_survey_records[record_id] = {"record_id": record_id, "field_seed": field, "object_id": object_id,
			"kind": String(contact["kind"]), "observed_hours": 0.0, "distance_m": 0.0,
			"confidence": "contact", "resource": "", "sampled_units": 0.0,
			"observed_remaining_units": -1.0, "equipment_id": "", "equipment_condition": -1.0}
	var record: Dictionary = _survey_records[record_id]
	var clock: Node = _get_autoload(&"SimClock")
	record["observed_hours"] = float(clock.call(&"get_total_hours")) if clock != null else 0.0
	if contact.has("distance_m"):
		record["distance_m"] = float(contact["distance_m"])
	return record


func _on_survey_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"scanner_ping":
		record_survey(String(payload.get("id", "")))
	elif event_name in [&"sample_taken", &"anomaly_logged"]:
		var units: Variant = payload.get("units", 0.0)
		var remaining: Variant = payload.get("remaining", -1.0)
		if not (units is int or units is float) or not is_finite(float(units)) or float(units) <= 0.0 or not (remaining is int or remaining is float) or not is_finite(float(remaining)) or float(remaining) < 0.0:
			return
		for contact: Dictionary in get_active_objects():
			if String(contact["id"]) != String(payload.get("object_id", "")):
				continue
			var resource: String = String(payload.get("resource", ""))
			if StringName(resource) not in CargoSystem.KNOWN_KINDS or resource != String(contact["resource"]):
				return
			contact["distance_m"] = (contact["position"] as Vector3).distance_to(get_ship_position())
			var record: Dictionary = _observe_contact(contact, str(field_seed))
			record["resource"] = resource
			record["sampled_units"] = float(record["sampled_units"]) + float(units)
			record["observed_remaining_units"] = float(remaining)
			if String(record["confidence"]) != "diagnosed":
				record["confidence"] = "sampled"
			return
	elif event_name == &"salvage_diagnosed":
		var salvage: Node = get_tree().get_first_node_in_group(&"salvage_system") if is_inside_tree() else null
		if salvage == null:
			return
		var unit_id: String = String(payload.get("unit_id", ""))
		var unit: Dictionary = salvage.call(&"get_unit", unit_id)
		if unit.is_empty() or not bool(unit.get("diagnosed", false)):
			return
		# The durable unit id keeps origin provenance when its current field changes in transport.
		var field: String = unit_id.get_slice(":", 0)
		if not field.is_valid_int():
			return
		var record: Dictionary = _observe_contact({"id": unit["object_id"], "kind": "debris"}, field)
		record["confidence"] = "diagnosed"
		record["equipment_id"] = String(unit["machine_id"])
		record["equipment_condition"] = float(unit["condition"])


static func valid_survey_records(records: Variant) -> bool:
	if not records is Dictionary:
		return false
	for key: Variant in records:
		var record: Variant = records[key]
		if not key is String or not record is Dictionary or (record as Dictionary).size() != 12:
			return false
		for field: String in ["record_id", "field_seed", "object_id", "kind", "confidence", "resource", "equipment_id"]:
			if not record.get(field) is String:
				return false
		if String(record["object_id"]).is_empty() or not String(record["field_seed"]).is_valid_int() or str(int(record["field_seed"])) != String(record["field_seed"]) or String(record["record_id"]) != String(key) or String(key) != String(record["field_seed"]) + ":" + String(record["object_id"]):
			return false
		if String(record["kind"]) not in ["asteroid", "debris", "anomaly"] or String(record["confidence"]) not in ["contact", "sampled", "diagnosed"] or (String(record["resource"]) != "" and StringName(record["resource"]) not in CargoSystem.KNOWN_KINDS):
			return false
		for field: String in ["observed_hours", "distance_m", "sampled_units", "observed_remaining_units", "equipment_condition"]:
			var value: Variant = record.get(field)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < (0.0 if field in ["observed_hours", "distance_m", "sampled_units"] else -1.0):
				return false
		if float(record["equipment_condition"]) > 1.0:
			return false
		if String(record["resource"]) == "" and (float(record["sampled_units"]) != 0.0 or float(record["observed_remaining_units"]) != -1.0):
			return false
		if String(record["resource"]) != "" and (float(record["sampled_units"]) <= 0.0 or float(record["observed_remaining_units"]) < 0.0):
			return false
		if String(record["equipment_id"]) == "" and float(record["equipment_condition"]) != -1.0:
			return false
		if String(record["equipment_id"]) != "" and (float(record["equipment_condition"]) < 0.0 or String(record["confidence"]) != "diagnosed"):
			return false
		if String(record["confidence"]) == "contact" and (String(record["resource"]) != "" or String(record["equipment_id"]) != ""):
			return false
		if String(record["confidence"]) == "sampled" and (String(record["resource"]) == "" or float(record["sampled_units"]) <= 0.0 or float(record["observed_remaining_units"]) < 0.0):
			return false
		if String(record["confidence"]) == "diagnosed" and (String(record["equipment_id"]) == "" or float(record["equipment_condition"]) < 0.0):
			return false
	return true


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
	var mined: Dictionary = _mined_fields.get(str(field_seed), {})
	if mined.has(object_id):
		return float(mined[object_id])
	for entry: Dictionary in _active:
		if String(entry["id"]) == object_id:
			return float(entry.get("yield_units", 0.0))
	return 0.0


## Records extraction; clamps at zero and returns the units actually removed.
func record_mined(object_id: String, units: float) -> float:
	if not is_finite(units) or units <= 0.0:
		return 0.0
	var remaining: float = get_remaining_yield(object_id)
	var removed: float = minf(units, remaining)
	if removed > 0.0:
		var field: String = str(field_seed)
		if not _mined_fields.has(field):
			_mined_fields[field] = {}
		_mined_fields[field][object_id] = maxf(remaining - removed, 0.0)
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
		"state_version": 3,
		"field_seed": str(field_seed),
		"drift_distance_m": _drift_distance_m,
		"offset": {"x": _offset.x, "y": _offset.y, "z": _offset.z},
		"holding": _holding,
		"approach_target_id": _approach_target_id,
		"mined_fields": _mined_fields.duplicate(true),
		"survey_records": _survey_records.duplicate(true),
	}


func load_state(state: Dictionary) -> void:
	if int(state.get("state_version", 1)) >= 3 and not state.has("survey_records"):
		return
	var records: Variant = state.get("survey_records", {}) if int(state.get("state_version", 1)) >= 3 else {}
	if not valid_survey_records(records):
		return
	_survey_records = records.duplicate(true)
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
	_mined_fields.clear()
	var fields: Variant = state.get("mined_fields", {})
	if int(state.get("state_version", 1)) < 2:
		fields = {str(field_seed): state.get("mined", {})}
	if fields is Dictionary:
		for field: Variant in fields:
			var mined: Variant = fields[field]
			if not (field is String) or not (mined is Dictionary):
				continue
			var restored: Dictionary = {}
			for key: Variant in mined:
				var units: Variant = mined[key]
				if key is String and (units is int or units is float) and is_finite(float(units)) and float(units) >= 0.0:
					restored[key] = float(units)
			_mined_fields[field] = restored
	_base_chunk = int(floor(_drift_distance_m / CHUNK_SIZE_M))
	_rebuild_active()
	_contact_ids.clear()
	_update_contacts()
