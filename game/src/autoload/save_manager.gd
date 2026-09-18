## Versioned save/load for simulator state. Collects state from systems by group and writes JSON slots.
## Autoload name: SaveManager. No class_name on purpose — it would conflict with the autoload.
extends Node

const SAVE_VERSION: int = 2
const SAVE_DIR: String = "user://saves"
const SLOT_COUNT: int = 3
const SYSTEM_GROUPS: Array[StringName] = [&"power_system", &"atmosphere_system", &"stores_system", &"thermal_system", &"hull_system", &"nav_system", &"vitals_system", &"water_system", &"comms_system"]

var _last_error: String = ""
var _meta: Dictionary = {}


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
		},
		"clock": clock_state,
		"systems": systems,
		"interactables": interactables,
	}


func load_from_dict(data: Dictionary) -> bool:
	_last_error = ""
	var version: int = int(data.get("save_version", 0))
	if version <= 0 or version > SAVE_VERSION:
		_last_error = "save_version_unsupported"
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
	var file: FileAccess = FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		_last_error = "write_failed"
		return false
	file.store_string(JSON.stringify(save_to_dict(), "\t"))
	file.close()
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
	return load_from_dict(parsed)


func has_save(slot: int = 1) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	return FileAccess.file_exists(_slot_path(slot))


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
