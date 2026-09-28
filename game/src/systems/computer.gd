## Ship computer: the onboard record of scheduler and maintenance history, fed by the sim event bus.
## Owns only the record; every ship system remains the source of truth for its own state.
class_name ComputerSystem
extends ShipSystem

const MAX_ENTRIES: int = 200

@export var archive: Array[LogEntry] = []

var _entries: Array[Dictionary] = []
var _next_entry_id: int = 1


func _ready() -> void:
	system_id = &"computer"
	add_to_group(&"computer_system")
	super._ready()
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null and not event_bus.is_connected(&"sim_event", _on_sim_event):
		event_bus.connect(&"sim_event", _on_sim_event)
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null and not sim_clock.is_connected(&"day_changed", _on_day_changed):
		sim_clock.connect(&"day_changed", _on_day_changed)


## Appends a dated entry and returns its id. Public so authored content and systems can write history.
func record(text: String, kind: StringName = &"note") -> int:
	if text.is_empty():
		return 0
	var day: int = 0
	var hour: int = 0
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		day = int(sim_clock.call("get_day"))
		hour = int(sim_clock.call("get_hour"))
	var entry: Dictionary = {
		"id": _next_entry_id,
		"day": day,
		"hour": hour,
		"kind": kind,
		"text": text,
		"unread": true,
	}
	_next_entry_id += 1
	_entries.append(entry)
	while _entries.size() > MAX_ENTRIES:
		_entries.remove_at(0)
	return int(entry["id"])


## Newest first.
func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for i: int in range(_entries.size() - 1, -1, -1):
		entries.append(_entries[i].duplicate(true))
	return entries


func get_entry(entry_id: int) -> Dictionary:
	for entry: Dictionary in _entries:
		if int(entry["id"]) == entry_id:
			return entry.duplicate(true)
	return {}


func get_unread_count() -> int:
	var count: int = 0
	for entry: Dictionary in _entries:
		if bool(entry["unread"]):
			count += 1
	return count


func mark_read(entry_id: int) -> bool:
	for entry: Dictionary in _entries:
		if int(entry["id"]) == entry_id:
			if not bool(entry["unread"]):
				return false
			entry["unread"] = false
			return true
	return false


func mark_all_read() -> void:
	for entry: Dictionary in _entries:
		entry["unread"] = false


func get_archive() -> Array[LogEntry]:
	return archive.duplicate()


func get_status() -> Dictionary:
	return {
		"system_id": system_id,
		"entry_count": _entries.size(),
		"unread": get_unread_count(),
	}


func save_state() -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		entries.append({
			"id": int(entry["id"]),
			"day": int(entry["day"]),
			"hour": int(entry["hour"]),
			"kind": String(entry["kind"]),
			"text": String(entry["text"]),
			"unread": bool(entry["unread"]),
		})
	return {
		"system_id": "computer",
		"state_version": 1,
		"next_entry_id": _next_entry_id,
		"entries": entries,
	}


func load_state(state: Dictionary) -> void:
	_entries.clear()
	_next_entry_id = maxi(int(state.get("next_entry_id", 1)), 1)
	for raw: Variant in state.get("entries", []):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		_entries.append({
			"id": int(entry.get("id", _next_entry_id)),
			"day": int(entry.get("day", 0)),
			"hour": int(entry.get("hour", 0)),
			"kind": StringName(entry.get("kind", &"note")),
			"text": String(entry.get("text", "")),
			"unread": bool(entry.get("unread", false)),
		})
	while _entries.size() > MAX_ENTRIES:
		_entries.remove_at(0)


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	var text: String = _event_text(event_name, payload)
	if text.is_empty():
		return
	record(text, event_name)


func _on_day_changed(day: int) -> void:
	record("SHIP DAY %04d BEGINS" % day, &"scheduler")


func _event_text(event_name: StringName, payload: Dictionary) -> String:
	match event_name:
		&"component_failed":
			return "COMPONENT FAILED: %s MODE %s" % [_upper(payload.get("component_id", &"")), _upper(payload.get("failure_mode_id", &""))]
		&"component_repaired":
			return "COMPONENT REPAIRED: %s" % _upper(payload.get("component_id", &""))
		&"component_diagnosed":
			return "FAULT DIAGNOSED: %s MODE %s" % [_upper(payload.get("component_id", &"")), _upper(payload.get("failure_mode_id", &""))]
		&"circuit_shed":
			return "CIRCUIT SHED: %s" % _upper(payload.get("circuit_id", &""))
		&"circuit_restored":
			return "CIRCUIT RESTORED: %s" % _upper(payload.get("circuit_id", &""))
		&"breaker_toggled":
			return "BREAKER %s: %s" % ["ON" if bool(payload.get("on", false)) else "OFF", _upper(payload.get("circuit_id", &""))]
		&"hull_puncture":
			return "HULL PUNCTURE: %s" % _upper(payload.get("compartment_id", &""))
		&"hull_patched":
			return "HULL PATCHED: %s" % _upper(payload.get("compartment_id", &""))
		&"stores_low":
			return "STORES LOW: %s x%d" % [_upper(payload.get("part_id", &"")), int(payload.get("new_count", 0))]
		&"water_low":
			return "WATER LOW: %d L" % int(roundf(float(payload.get("potable_l", 0.0))))
		&"water_depleted":
			return "WATER DEPLETED"
		&"water_contaminated":
			return "WATER CONTAMINATION %d%%" % int(roundf(float(payload.get("contamination", 0.0)) * 100.0))
		&"water_purged":
			return "WATER LOOP PURGED"
		&"compartment_freeze_risk":
			return "FREEZE RISK %s: %s" % ["SET" if bool(payload.get("active", false)) else "CLEARED", _upper(payload.get("compartment_id", &""))]
		&"o2_candle_lit":
			return "O2 CANDLE LIT: %s" % _upper(payload.get("compartment_id", &""))
		&"airlock_cycle_started":
			return "AIRLOCK CYCLE: %s" % _upper(payload.get("mode", &""))
		&"airlock_depressurized":
			return "AIRLOCK DEPRESSURIZED"
		&"airlock_pressurized":
			return "AIRLOCK PRESSURIZED: %d KPA" % int(roundf(float(payload.get("pressure_kpa", 0.0))))
		&"airlock_vented":
			return "AIRLOCK VENTED TO SPACE"
		&"suit_equipped":
			return "EVA SUIT EQUIPPED"
		&"suit_stored":
			return "EVA SUIT STOWED"
		&"suit_refilled":
			return "EVA SUIT REFILLED"
		&"suit_o2_depleted":
			return "EVA SUIT O2 DEPLETED"
		&"course_plotted":
			return "COURSE PLOTTED: %s" % _destination_label(payload)
		&"course_cancelled":
			return "COURSE CANCELLED: %s" % _destination_label(payload)
		&"course_expired":
			return "COURSE EXPIRED: %s" % _destination_label(payload)
		&"transit_started":
			return "TRANSIT STARTED: %s" % _destination_label(payload)
		&"transit_day_advanced":
			return "TRANSIT DAY %d/%d: %s" % [int(payload.get("day", 0)), int(payload.get("days_total", 0)), _destination_label(payload)]
		&"transit_fuel_exhausted":
			return "TRANSIT FUEL EXHAUSTED: %s" % _destination_label(payload)
		&"destination_arrived":
			return "ARRIVED: %s" % _destination_label(payload)
		&"message_received":
			return "MESSAGE RECEIVED: %s" % _upper(payload.get("sender", ""))
		&"message_sent":
			return "MESSAGE SENT"
		&"construction_started":
			return "CONSTRUCTION STARTED: %s" % _upper(payload.get("module_id", &""))
		&"construction_completed":
			return "CONSTRUCTION COMPLETE: %s" % _upper(payload.get("module_id", &""))
		&"construction_cancelled":
			return "CONSTRUCTION CANCELLED: %s" % _upper(payload.get("module_id", &""))
		&"module_uninstalled":
			return "MODULE TORN DOWN: %s" % _upper(payload.get("module_id", &""))
		&"machine_fitted":
			return "MACHINE INSTALLED: %s" % _upper(payload.get("machine_id", &""))
		&"machine_removed":
			return "MACHINE REMOVED: %s" % _upper(payload.get("machine_id", &""))
		&"fabrication_started":
			return "FABRICATION STARTED: %s" % _upper(payload.get("recipe_id", &""))
		&"fabrication_completed":
			return "FABRICATION COMPLETE: %s x%d" % [_upper(payload.get("part_id", &"")), int(payload.get("count", 1))]
		&"approach_started":
			return "APPROACH STARTED: %s" % _upper(payload.get("id", &""))
		&"approach_complete":
			return "APPROACH COMPLETE: %s" % _upper(payload.get("id", &""))
		&"sample_taken":
			return "SAMPLE TAKEN: %s %.1f U" % [_upper(payload.get("resource", &"")), float(payload.get("units", 0.0))]
		&"anomaly_logged":
			return "ANOMALY LOGGED: %s %.1f U" % [_upper(payload.get("resource", &"")), float(payload.get("units", 0.0))]
		&"operator_incapacitated":
			return "OPERATOR INCAPACITATED: %s" % _upper(payload.get("cause", &""))
		&"mercy_recovery_used":
			return "EMERGENCY RECOVERY USED"
	return ""


func _destination_label(payload: Dictionary) -> String:
	if payload.has("display_name"):
		return String(payload["display_name"]).to_upper()
	var destination_id: StringName = StringName(payload.get("destination_id", &""))
	var nav: Node = _find_system(&"nav_system")
	if nav != null and nav.has_method(&"get_destination"):
		var destination: VoyageDestination = nav.call("get_destination", destination_id)
		if destination != null:
			return destination.display_name.to_upper()
	return _upper(destination_id)


func _upper(value: Variant) -> String:
	return String(value).to_upper()


## Group lookup that also works for root-child systems during --script SceneTree tests.
func _find_system(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree != null:
		var found: Node = tree.get_first_node_in_group(group_name)
		if found != null:
			return found
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		for child: Node in (main_loop as SceneTree).root.get_children():
			if child.is_in_group(group_name):
				return child
	return null
