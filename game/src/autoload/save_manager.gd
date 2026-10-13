## Versioned save/load for simulator state. Collects state from systems by group and writes JSON slots.
## Autoload name: SaveManager. No class_name on purpose — it would conflict with the autoload.
extends Node

const SAVE_VERSION: int = 8
const SAVE_DIR: String = "user://saves"
const SLOT_COUNT: int = 3
const GAME_SCENE: String = "res://scenes/main.tscn"
const MENU_SCENE: String = "res://scenes/main_menu.tscn"
## module_system loads first so module compartments exist before the life-support systems merge
## their saved per-compartment state into them.
const SYSTEM_GROUPS: Array[StringName] = [&"module_system", &"salvage_system", &"power_system", &"atmosphere_system", &"stores_system", &"thermal_system", &"hull_system", &"nav_system", &"vitals_system", &"water_system", &"comms_system", &"airlock_system", &"sector_system", &"cargo_system", &"fabricator_system", &"computer_system", &"voice_guide_system"]

var _last_error: String = ""
var _meta: Dictionary = {}
var active_slot: int = 1


func get_last_error() -> String:
	return _last_error


func save_to_dict() -> Dictionary:
	_last_error = ""
	var systems: Dictionary = {}
	for group_name: StringName in SYSTEM_GROUPS:
		var system: Node = _find_system(group_name)
		if system == null or not system.has_method(&"save_state"):
			continue
		var state: Dictionary = system.call("save_state")
		systems[_system_key(system, group_name)] = state
	var interactables: Dictionary = {}
	for node: Node in _find_saveables():
		if not node.has_method(&"save_state"):
			continue
		interactables[String(node.get_path())] = node.call("save_state")
	var clock_state: Dictionary = {}
	var sim_clock: Node = get_node_or_null(^"/root/SimClock")
	if sim_clock != null and sim_clock.has_method(&"save_state"):
		clock_state = sim_clock.call("save_state")
	return {
		"save_version": SAVE_VERSION,
		"meta": {
			"created_unix": int(Time.get_unix_time_from_system()),
			"play_hours": float(clock_state.get("sim_seconds", 0.0)) / 3600.0,
			"day": int(floor(float(clock_state.get("sim_seconds", 0.0)) / 86400.0)) + 1,
			"destination_id": String((systems.get("nav", {}) as Dictionary).get("current_destination_id", "")),
		},
		"clock": clock_state,
		"systems": systems,
		"interactables": interactables,
	}


func load_from_dict(data: Dictionary) -> bool:
	_last_error = ""
	var raw_version: Variant = data.get("save_version", 0)
	var version: int = int(raw_version) if (raw_version is int or raw_version is float) and is_finite(float(raw_version)) else 0
	if version <= 0 or version > SAVE_VERSION:
		_last_error = "save_version_unsupported"
		return false
	if not _validate_save(data):
		_last_error = "invalid_save_data"
		return false
	data = _migrate(data)
	var meta: Variant = data.get("meta", {})
	if meta is Dictionary:
		_meta = meta
	else:
		_meta = {}
	var clock_state: Dictionary = data.get("clock", {})
	var sim_clock: Node = get_node_or_null(^"/root/SimClock")
	if sim_clock != null and sim_clock.has_method(&"load_state") and not clock_state.is_empty():
		sim_clock.call("load_state", clock_state)
	var systems: Dictionary = data.get("systems", {})
	for group_name: StringName in SYSTEM_GROUPS:
		var system: Node = _find_system(group_name)
		if system == null or not system.has_method(&"load_state"):
			continue
		var key: String = _system_key(system, group_name)
		if not systems.has(key):
			if group_name in [&"computer_system", &"salvage_system"]:
				system.call("load_state", {})
			continue
		system.call("load_state", systems[key])
	var interactables: Dictionary = data.get("interactables", {})
	if not interactables.is_empty():
		for node: Node in _find_saveables():
			if not node.has_method(&"load_state"):
				continue
			var path_key: String = String(node.get_path())
			if interactables.has(path_key):
				node.call("load_state", interactables[path_key])
	return true


func save_to_slot(slot: int = 1) -> bool:
	_last_error = ""
	if slot < 1 or slot > SLOT_COUNT:
		_last_error = "slot_out_of_range"
		return false
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if directory_error != OK:
		_last_error = "directory_failed"
		return false
	var temporary_path: String = _slot_path(slot) + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		_last_error = "write_failed"
		return false
	file.store_string(JSON.stringify(save_to_dict(), "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_last_error = "write_failed"
		DirAccess.remove_absolute(temporary_path)
		return false
	if DirAccess.rename_absolute(temporary_path, _slot_path(slot)) != OK:
		_last_error = "replace_failed"
		return false
	active_slot = slot
	return true


func load_from_slot(slot: int = 1) -> bool:
	_last_error = ""
	if slot < 1 or slot > SLOT_COUNT:
		_last_error = "slot_out_of_range"
		return false
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		_last_error = "file_not_found"
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_last_error = "read_failed"
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_last_error = "parse_error"
		push_error("SaveManager.load_from_slot: corrupt save file '%s'." % path)
		return false
	var loaded: bool = load_from_dict(parsed)
	if loaded:
		active_slot = slot
	return loaded


func has_save(slot: int = 1) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	return FileAccess.file_exists(_slot_path(slot))


func get_slot_summary(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"slot": slot, "exists": false, "valid": false, "error": "slot_out_of_range"}
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"slot": slot, "exists": false, "valid": false, "error": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"slot": slot, "exists": true, "valid": false, "error": "read_failed"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {"slot": slot, "exists": true, "valid": false, "error": "parse_error"}
	var data: Dictionary = parsed
	var raw_version: Variant = data.get("save_version", 0)
	var version: int = int(raw_version) if (raw_version is int or raw_version is float) and is_finite(float(raw_version)) else 0
	if version <= 0 or version > SAVE_VERSION:
		return {"slot": slot, "exists": true, "valid": false, "error": "save_version_unsupported"}
	if not _validate_save(data):
		return {"slot": slot, "exists": true, "valid": false, "error": "invalid_save_data"}
	var meta: Dictionary = data.get("meta", {})
	var clock: Dictionary = data.get("clock", {})
	var play_hours: float = float(meta.get("play_hours", float(clock.get("sim_seconds", 0.0)) / 3600.0))
	var day: int = int(meta.get("day", floori(play_hours / 24.0) + 1))
	var nav: Dictionary = (data.get("systems", {}) as Dictionary).get("nav", {})
	var destination_id: String = String(meta.get("destination_id", nav.get("current_destination_id", "")))
	return {
		"slot": slot,
		"exists": true,
		"valid": true,
		"error": "",
		"created_unix": int(meta.get("created_unix", data.get("created_unix", 0))),
		"play_hours": play_hours,
		"day": maxi(day, 1),
		"destination_id": destination_id,
	}


func get_latest_valid_slot() -> int:
	var latest_slot: int = 0
	var latest_time: int = -1
	for slot: int in range(1, SLOT_COUNT + 1):
		var summary: Dictionary = get_slot_summary(slot)
		if not bool(summary.get("valid", false)):
			continue
		var created_unix: int = int(summary.get("created_unix", 0))
		if created_unix > latest_time:
			latest_time = created_unix
			latest_slot = slot
	return latest_slot


func start_new_game(slot: int) -> void:
	_last_error = ""
	if slot < 1 or slot > SLOT_COUNT:
		_last_error = "slot_out_of_range"
		return
	active_slot = slot
	var sim_clock: Node = get_node_or_null(^"/root/SimClock")
	if sim_clock != null and sim_clock.has_method(&"reset_clock"):
		sim_clock.call(&"reset_clock")
	var tree: SceneTree = get_tree()
	tree.paused = false
	var change_error: Error = tree.change_scene_to_file(GAME_SCENE)
	if change_error != OK:
		_last_error = "game_scene_failed"
		return
	await tree.scene_changed
	if not save_to_slot(slot):
		push_error("SaveManager.start_new_game: initial save failed (%s)." % _last_error)


func load_game_scene(slot: int) -> void:
	_last_error = ""
	var summary: Dictionary = get_slot_summary(slot)
	if not bool(summary.get("valid", false)):
		_last_error = String(summary.get("error", "file_not_found"))
		return
	var tree: SceneTree = get_tree()
	tree.paused = false
	var change_error: Error = tree.change_scene_to_file(GAME_SCENE)
	if change_error != OK:
		_last_error = "game_scene_failed"
		return
	await tree.scene_changed
	if load_from_slot(slot):
		var clock: Node = get_node_or_null(^"/root/SimClock")
		if clock != null:
			clock.call("set_paused", false)
		return
	var load_error: String = _last_error
	if tree.change_scene_to_file(MENU_SCENE) == OK:
		await tree.scene_changed
	_last_error = load_error


func delete_save(slot: int = 1) -> bool:
	_last_error = ""
	if slot < 1 or slot > SLOT_COUNT:
		_last_error = "slot_out_of_range"
		return false
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		_last_error = "file_not_found"
		return false
	var directory: DirAccess = DirAccess.open(SAVE_DIR)
	if directory == null:
		_last_error = "directory_failed"
		return false
	var remove_error: Error = directory.remove(_slot_path(slot).trim_prefix(SAVE_DIR + "/"))
	if remove_error != OK:
		_last_error = "delete_failed"
		return false
	return true


func return_to_menu() -> bool:
	if not save_to_slot(active_slot):
		return false
	var tree: SceneTree = get_tree()
	tree.paused = false
	var sim_clock: Node = get_node_or_null(^"/root/SimClock")
	if sim_clock != null and sim_clock.has_method(&"set_paused"):
		sim_clock.call(&"set_paused", false)
	return tree.change_scene_to_file(MENU_SCENE) == OK


func _validate_save(data: Dictionary) -> bool:
	for key: String in ["meta", "clock", "systems", "interactables"]:
		if not (data.get(key, {}) is Dictionary):
			return false
	for key: String in ["systems", "interactables"]:
		var states: Dictionary = data.get(key, {})
		for state: Variant in states.values():
			if not (state is Dictionary):
				return false
			if key == "systems":
				var covers: Variant = state.get("maintenance_covers", {})
				if not (covers is Dictionary):
					return false
				for opened: Variant in covers.values():
					if not (opened is bool):
						return false
	var systems: Dictionary = data.get("systems", {})
	var modules: Dictionary = systems.get("modules", {})
	var remainder: Variant = modules.get("ration_hours", 0.0)
	if not (remainder is int or remainder is float) or not is_finite(float(remainder)) or float(remainder) < 0.0:
		return false
	var sector: Dictionary = systems.get("sector", {})
	var fields: Variant = sector.get("mined_fields", {})
	if not (fields is Dictionary):
		return false
	if sector.has("mined") and not _valid_deposit_stock(sector["mined"]):
		return false
	for field: Variant in fields:
		if not (field is String) or not String(field).is_valid_int() or str(int(field)) != field:
			return false
		if not _valid_deposit_stock(fields[field]):
			return false
	var meta: Dictionary = data.get("meta", {})
	var clock: Dictionary = data.get("clock", {})
	for key: String in ["created_unix", "play_hours", "day"]:
		var value: Variant = meta.get(key, 0)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	var seconds: Variant = clock.get("sim_seconds", 0.0)
	if not (seconds is int or seconds is float) or not is_finite(float(seconds)):
		return false
	return true


func _valid_deposit_stock(mined: Variant) -> bool:
	if not (mined is Dictionary):
		return false
	for contact: Variant in mined:
		var units: Variant = mined[contact]
		if not (contact is String) or String(contact).is_empty() or not (units is int or units is float) or not is_finite(float(units)) or float(units) < 0.0:
			return false
	return true


func _slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


## Version migration hook: shape changes between versions land here, keyed by source version.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = int(data.get("save_version", 0))
	if version == 1:
		var play_hours: float = 0.0
		var old_clock: Variant = data.get("clock", {})
		if old_clock is Dictionary:
			play_hours = float(old_clock.get("sim_seconds", 0.0)) / 3600.0
		data["meta"] = {
			"created_unix": int(data.get("created_unix", 0)),
			"play_hours": play_hours,
		}
		data.erase("created_unix")
		data["save_version"] = 2
		version = 2
	if version == 2:
		data["save_version"] = 3
		version = 3
	if version == 3:
		var systems: Dictionary = data.get("systems", {})
		if systems.has("nav"):
			var nav: Dictionary = systems["nav"]
			if not nav.has("propulsion"):
				nav["propulsion"] = {}
		data["save_version"] = 4
		version = 4
	if version == 4:
		var systems: Dictionary = data.get("systems", {})
		systems["salvage"] = {"system_id": "salvage", "state_version": 1, "units": {}}
		data["systems"] = systems
		data["save_version"] = 5
		version = 5
	if version == 5:
		var systems: Dictionary = data.get("systems", {})
		if systems.has("nav"):
			var nav: Dictionary = systems["nav"]
			nav["state_version"] = 4
			nav["arrival_ordinal"] = 0
			nav["planet_discoveries"] = []
		data["systems"] = systems
		data["save_version"] = 6
		version = 6
	if version == 6:
		var systems: Dictionary = data.get("systems", {})
		if systems.has("power"):
			var power: Dictionary = systems["power"]
			power["light_enabled"] = {}
		data["save_version"] = 7
		version = 7
	if version == 7:
		var systems: Dictionary = data.get("systems", {})
		if systems.has("sector"):
			var sector: Dictionary = systems["sector"]
			sector["mined_fields"] = {str(int(sector.get("field_seed", 20260918))): sector.get("mined", {}).duplicate()}
			sector["field_seed"] = str(int(sector.get("field_seed", 20260918)))
			sector["state_version"] = 2
			sector.erase("mined")
		if systems.has("modules"):
			var modules: Dictionary = systems["modules"]
			modules["ration_hours"] = 0.0
			modules["state_version"] = 4
		data["save_version"] = 8
	return data


func _find_system(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)


func _find_saveables() -> Array[Node]:
	var tree: SceneTree = get_tree()
	if tree == null:
		return []
	return tree.get_nodes_in_group(&"saveable")


func _system_key(system: Node, group_name: StringName) -> String:
	if system.get(&"system_id") != null:
		var system_id: StringName = system.get(&"system_id")
		if system_id != &"":
			return String(system_id)
	return String(group_name).trim_suffix("_system")
