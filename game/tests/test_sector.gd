## Sector field tests: determinism, ~98% emptiness, stream bounds, contact ordering, save.
extends SceneTree

var _failures: int = 0
var _entered_events: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_hash_density()
	_test_determinism()
	_test_stream_bounds()
	_test_contacts()
	_test_save_load()
	_test_field_depletion()
	_finish()


func _test_hash_density() -> void:
	var system: SectorSystem = _make_sector(20260918)
	var content: int = 0
	var total: int = 0
	for cx: int in range(0, 40):
		for cy: int in range(-10, 11):
			for cz: int in range(-10, 11):
				total += 1
				if system.chunk_hash(cx, cy, cz) % 10000 < SectorSystem.CONTENT_PER_TEN_THOUSAND:
					content += 1
	var ratio: float = float(content) / float(total)
	_check(ratio > 0.01 and ratio < 0.03, "content density stays near 2%% (got %.2f%%)" % (ratio * 100.0))
	system.free()


func _test_determinism() -> void:
	var a: SectorSystem = _make_sector(424242)
	var b: SectorSystem = _make_sector(424242)
	for i: int in 168:
		a.sim_tick(1.0)
		b.sim_tick(1.0)
	var ids_a: PackedStringArray = _ids(a)
	var ids_b: PackedStringArray = _ids(b)
	_check(ids_a.size() > 0, "a seeded field produces objects over seven days (%d active)" % ids_a.size())
	_check(ids_a == ids_b, "same seed and drift produce identical active objects")
	var positions_match: bool = true
	var objects_a: Array[Dictionary] = a.get_active_objects()
	var objects_b: Array[Dictionary] = b.get_active_objects()
	for i: int in objects_a.size():
		if (objects_a[i]["position"] as Vector3).distance_to(objects_b[i]["position"] as Vector3) > 0.0001:
			positions_match = false
	_check(positions_match, "object positions match exactly")
	var other: SectorSystem = _make_sector(999)
	for i: int in 168:
		other.sim_tick(1.0)
	_check(_ids(other) != ids_a, "a different seed produces a different field")
	a.free()
	b.free()
	other.free()


func _test_stream_bounds() -> void:
	var system: SectorSystem = _make_sector(777)
	var max_along: float = (SectorSystem.STREAM_CHUNKS_AHEAD + 1) * SectorSystem.CHUNK_SIZE_M
	var max_lateral: float = (SectorSystem.LATERAL_CHUNKS + 0.5) * SectorSystem.CHUNK_SIZE_M
	var ok: bool = true
	for i: int in 72:
		system.sim_tick(1.0)
		var ship: Vector3 = system.get_ship_position()
		for entry: Dictionary in system.get_active_objects():
			var relative: Vector3 = (entry["position"] as Vector3) - ship
			var along: float = relative.dot(Vector3.FORWARD)
			var lateral: Vector3 = relative - Vector3.FORWARD * along
			if along > max_along or along < -max_lateral or lateral.length() > max_lateral * 1.45:
				ok = false
	_check(ok, "active objects stay inside the stream corridor")
	_check(system.get_active_objects().size() < 60, "active set stays bounded (%d objects)" % system.get_active_objects().size())
	system.free()


func _test_contacts() -> void:
	var system: SectorSystem = _make_sector(31337)
	var event_bus: Node = root.get_node_or_null(^"EventBus")
	if event_bus == null:
		event_bus = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
	_entered_events = 0
	event_bus.connect(&"sim_event", _on_sim_event)
	for i: int in 168:
		system.sim_tick(1.0)
	_check(_entered_events > 0, "contacts enter range during seven days (%d entries)" % _entered_events)
	var contacts: Array[Dictionary] = system.get_contacts()
	var sorted_ok: bool = true
	var in_range: bool = true
	var previous: float = -1.0
	var ship: Vector3 = system.get_ship_position()
	for contact: Dictionary in contacts:
		var distance: float = float(contact["distance_m"])
		if distance < previous:
			sorted_ok = false
		previous = distance
		if (contact["position"] as Vector3).distance_to(ship) > SectorSystem.CONTACT_RANGE_M + 0.001:
			in_range = false
	_check(sorted_ok, "contacts are sorted by distance")
	_check(in_range, "contacts respect the contact range")
	system.free()


func _test_save_load() -> void:
	var a: SectorSystem = _make_sector(5150)
	for i: int in 100:
		a.sim_tick(1.0)
	var saved: Dictionary = a.save_state()
	var settings: Node = root.get_node_or_null(^"/root/GameSettings")
	var expected_asteroid_frequency: float = float(settings.call("get_value", &"asteroid_frequency")) if settings != null else a.get_encounter_frequency(&"asteroid_frequency")
	var expected_anomaly_frequency: float = float(settings.call("get_value", &"anomaly_frequency")) if settings != null else a.get_encounter_frequency(&"anomaly_frequency")
	saved["asteroid_frequency"] = 0.0 if expected_asteroid_frequency > 0.0 else 3.0
	saved["anomaly_frequency"] = 0.0 if expected_anomaly_frequency > 0.0 else 3.0
	var b: SectorSystem = _make_sector(1)
	b.load_state(saved)
	_check(_ids(a) == _ids(b), "save/load reproduces the active field")
	_check(is_equal_approx(b.get_drift_distance(), a.get_drift_distance()), "save/load restores the drift distance")
	_check(is_equal_approx(b.get_encounter_frequency(&"asteroid_frequency"), expected_asteroid_frequency), "save/load keeps current player field-rate preference over legacy slot data")
	_check(is_equal_approx(b.get_encounter_frequency(&"anomaly_frequency"), expected_anomaly_frequency), "save/load keeps current player anomaly preference over legacy slot data")
	_check(not a.save_state().has("asteroid_frequency") and not a.save_state().has("anomaly_frequency"), "new sector saves leave global encounter preferences in settings")
	a.free()
	b.free()


func _test_field_depletion() -> void:
	var a: SectorSystem = _make_sector(20260918)
	a.sim_tick(1.0 / 600.0)
	for step: int in 168:
		if not a.get_active_objects().is_empty():
			break
		a.sim_tick(1.0)
	var objects: Array[Dictionary] = a.get_active_objects()
	_check(not objects.is_empty(), "depletion: seeded field supplies a real deposit")
	if objects.is_empty():
		a.free()
		return
	var contact: Dictionary = objects[0]
	var id: String = String(contact["id"])
	var original: float = a.get_remaining_yield(id)
	var first_seed: int = a.field_seed
	var first_drift: float = a.get_drift_distance()
	var paid: float = a.record_mined(id, original / 2.0)
	var snapshot: Dictionary = a.save_state()
	_check(is_equal_approx(paid, original / 2.0), "depletion: extraction debits the real deposit")
	_check(a.record_mined(id, NAN) == 0.0 and a.record_mined(id, INF) == 0.0 and a.record_mined("unknown", 1.0) == 0.0 and a.save_state() == snapshot, "depletion: invalid or unknown extraction changes no stock")
	a.sim_tick(20.0)
	a.load_state(JSON.parse_string(JSON.stringify(snapshot)))
	_check(is_equal_approx(a.get_remaining_yield(id), original - paid), "depletion: stream-out and JSON reload retain partial deposit")
	var second_seed: int = first_seed + 1
	var second_yield: float = 0.0
	for attempt: int in 1000:
		a._on_destination_arrived(&"other", &"star", second_seed, &"", 0.0, {})
		a.sim_tick(first_drift / a.drift_speed_m_per_hour if first_drift > 0.0 else 0.001)
		second_yield = a.get_remaining_yield(id)
		if second_yield > 0.0:
			break
		second_seed += 1
	_check(second_yield > 0.0, "depletion: another seeded field contains the same coordinate ID")
	var second_paid: float = a.record_mined(id, second_yield)
	_check(second_paid > 0.0 and is_equal_approx(second_paid, second_yield) and a.get_remaining_yield(id) == 0.0, "depletion: second field's deposit exhausts independently")
	a._on_destination_arrived(&"first", &"star", first_seed, &"", 0.0, {})
	a.sim_tick(first_drift / a.drift_speed_m_per_hour if first_drift > 0.0 else 0.001)
	_check(is_equal_approx(a.get_remaining_yield(id), original - paid), "depletion: A to B to A does not replenish the first deposit")
	a._on_settings_changed(&"asteroid_frequency", 0.0)
	a._on_settings_changed(&"asteroid_frequency", 1.0)
	_check(is_equal_approx(a.get_remaining_yield(id), original - paid), "depletion: rebuilding encounters does not reset extraction")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.save_state()))
	var b: SectorSystem = _make_sector(1)
	b.load_state(saved)
	_check(b.save_state() == a.save_state(), "depletion: fresh simulator preserves every field claim")
	b._on_destination_arrived(&"other", &"star", second_seed, &"", 0.0, {})
	var second_claims: Dictionary = b.save_state()["mined_fields"].get(str(second_seed), {})
	_check(b.get_remaining_yield(id) == 0.0 and second_claims.has(id), "depletion: exhausted zero survives save and return")
	var legacy: Dictionary = snapshot.duplicate(true)
	legacy["state_version"] = 1
	legacy["mined"] = {id: original - paid}
	legacy.erase("mined_fields")
	b.load_state(legacy)
	_check(is_equal_approx(b.get_remaining_yield(id), original - paid) and (b.save_state()["mined_fields"] as Dictionary).size() == 1, "depletion: legacy map belongs only to its saved field and replaces stale claims")
	b.field_seed = 9007199254740993
	var wide: Dictionary = JSON.parse_string(JSON.stringify(b.save_state()))
	b.load_state(wide)
	_check(b.field_seed == 9007199254740993, "depletion: string seed retains 64-bit identity through JSON")
	a.free()
	b.free()


func _on_sim_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name == &"sector_contact_entered":
		_entered_events += 1


func _make_sector(seed_value: int) -> SectorSystem:
	var system: SectorSystem = SectorSystem.new()
	system.field_seed = seed_value
	system.drift_axis = Vector3.FORWARD
	system.drift_speed_m_per_hour = 1500.0
	root.add_child(system)
	return system


func _ids(system: SectorSystem) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for entry: Dictionary in system.get_active_objects():
		ids.append(String(entry["id"]))
	ids.sort()
	return ids


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_sector")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
