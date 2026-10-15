## Versioned save/load for simulator state. Collects state from systems by group and writes JSON slots.
## Autoload name: SaveManager. No class_name on purpose — it would conflict with the autoload.
extends Node

const SAVE_VERSION: int = 10
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
		interactables[_node_key(node)] = node.call("save_state")
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
	var player: Node = _find_system(&"player")
	if player != null and player.has_method(&"reset_tools_for_load"):
		player.call(&"reset_tools_for_load")
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
			var path_key: String = _node_key(node)
			if interactables.has(path_key):
				node.call("load_state", interactables[path_key])
	# Occupancy follows the physical operator, including legacy phantom-count saves.
	for zone: Node in get_tree().get_nodes_in_group(&"compartment_zone"):
		zone.call(&"push_occupancy")
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
	if not _valid_payload(data) or not _integer(data.get("save_version", 0)):
		return false
	for key: String in ["meta", "clock", "systems", "interactables"]:
		if not (data.get(key, {}) is Dictionary):
			return false
	if not _valid_shape(data.get("meta", {}), {"created_unix": 0, "play_hours": 0.0, "day": 0, "destination_id": ""}) or not _valid_shape(data.get("clock", {}), {"sim_seconds": 0.0, "tick_index": 0, "last_hour": 0, "last_day": 0}):
		return false
	for key: String in ["systems", "interactables"]:
		var states: Dictionary = data.get(key, {})
		for state: Variant in states.values():
			if not (state is Dictionary):
				return false
			if key == "interactables":
				if not _valid_shape(state, {"system_id": "", "state_version": 1, "enabled": false, "item_id": "", "stage": 0, "open": false, "deployed": false, "clipped": false, "kind": "", "units": 0.0}):
					return false
				if state.has("world_pose") and not Carriable.is_valid_saved_pose(state["world_pose"]):
					return false
			if key == "systems":
				var covers: Variant = state.get("maintenance_covers", {})
				if not (covers is Dictionary):
					return false
				for opened: Variant in covers.values():
					if not (opened is bool):
						return false
	var systems: Dictionary = data.get("systems", {})
	if not _valid_system_records(systems):
		return false
	for group_name: StringName in SYSTEM_GROUPS:
		var system: Node = _find_system(group_name)
		if system == null or not system.has_method(&"save_state"):
			continue
		var key: String = _system_key(system, group_name)
		if systems.has(key) and not _valid_shape(systems[key], system.call("save_state")):
			return false
	var stores: Dictionary = systems.get("stores", {})
	if not _valid_quantity_map(stores.get("inventory", {}), [], true):
		return false
	if not _valid_quantity_map(stores.get("cartridge_charges", {}), [], true, 1.0):
		return false
	var cargo: Dictionary = systems.get("cargo", {})
	if not _valid_quantity_map(cargo.get("materials", {}), CargoSystem.KNOWN_KINDS):
		return false
	if not _nonnegative(cargo.get("capacity_units", 0.0)):
		return false
	if not _valid_fabricator(systems.get("fabricator", {})) or not _valid_modules(systems.get("modules", {})) or not _valid_salvage(systems):
		return false
	var nav: Dictionary = systems.get("nav", {})
	var caches: Variant = nav.get("pending_cache_materials", {})
	if not caches is Dictionary:
		return false
	for destination: Variant in caches:
		var cache: Variant = caches[destination]
		if not cache is Dictionary or not cache.get("resource_id", null) is String or StringName(cache["resource_id"]) not in CargoSystem.KNOWN_KINDS or not _nonnegative(cache.get("remaining_units", null)) or float(cache["remaining_units"]) <= 0.0:
			return false
	for system_key: String in ["water", "vitals", "airlock", "nav", "power"]:
		var state: Dictionary = systems.get(system_key, {})
		for field: String in ["potable_l", "greywater_l", "condition", "ration_accumulator", "suit_o2_hours", "fuel_mass_kg", "transit_elapsed_hours", "battery_charge_wh", "battery_capacity_wh"]:
			if state.has(field) and not _nonnegative(state[field]):
				return false
	var airlock: Dictionary = systems.get("airlock", {})
	if bool(airlock.get("suit_stored", false)) and bool(airlock.get("suit_worn", false)):
		return false
	for node: Node in _find_saveables():
		var saved: Dictionary = data.get("interactables", {})
		var key: String = _node_key(node)
		if saved.has(key) and node.has_method(&"save_state") and not _valid_shape(saved[key], node.call("save_state")):
			return false
		if saved.has(key) and node is SampleCanister:
			var entry: Dictionary = saved[key]
			var units: Variant = entry.get("units", 0.0)
			if not _nonnegative(units) or (float(units) > 0.0 and StringName(entry.get("kind", "")) not in CargoSystem.KNOWN_KINDS):
				return false
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
	if float(seconds) < 0.0:
		return false
	return true


func _valid_payload(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if value is float:
		return is_finite(value)
	if value is Dictionary:
		for key: Variant in value:
			if not (key is String or key is StringName) or not _valid_payload(value[key], depth + 1):
				return false
	elif value is Array:
		for item: Variant in value:
			if not _valid_payload(item, depth + 1):
				return false
	elif not (value == null or value is bool or value is int or value is String or value is StringName):
		return false
	return true


func _valid_shape(value: Variant, example: Variant, field: String = "") -> bool:
	if example is Dictionary:
		if not value is Dictionary:
			return false
		for key: Variant in example:
			if value.has(key) and not _valid_shape(value[key], example[key], String(key)):
				return false
	elif example is Array:
		if not value is Array:
			return false
	elif example is float or example is int:
		return (value is float or value is int) and is_finite(float(value)) and (not example is int or float(value) == floor(float(value)))
	elif example is String or example is StringName:
		return value is String or value is StringName or (field in ["field_seed", "sector_seed", "rng_state", "wear_rng_state", "hull_rng_state"] and _integer(value))
	elif example is bool:
		return value is bool
	return true


func _nonnegative(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0


func _valid_quantity_map(value: Variant, kinds: Array = [], integral: bool = false, maximum: float = INF) -> bool:
	if not value is Dictionary:
		return false
	for key: Variant in value:
		var units: Variant = value[key]
		if not (key is String or key is StringName) or String(key).is_empty() or (not kinds.is_empty() and StringName(key) not in kinds) or not _nonnegative(units):
			return false
		if float(units) > maximum or (integral and float(units) != floor(float(units))):
			return false
	return true


func _valid_fabricator(state: Dictionary) -> bool:
	if not _valid_shape(state, {"state_version": 1, "job_recipe_id": "", "job_remaining_hours": 0.0}) or not _nonnegative(state.get("job_remaining_hours", 0.0)):
		return false
	var terms: Variant = state.get("job_terms", {})
	if not terms is Dictionary:
		return false
	var recipe_id: StringName = StringName(state.get("job_recipe_id", ""))
	if terms.is_empty():
		if recipe_id == &"":
			return float(state.get("job_remaining_hours", 0.0)) == 0.0
		var fabricator: Node = _find_system(&"fabricator_system")
		# Slot summaries run in the menu; resolve legacy catalog references once the world exists.
		return int(state.get("state_version", 1)) < 2 and (fabricator == null or fabricator.call("get_recipe", recipe_id) != null)
	return terms.get("recipe_id", null) is String and not String(terms["recipe_id"]).is_empty() and terms.get("output_part_id", null) is String and not String(terms["output_part_id"]).is_empty() and terms.get("material_kind", null) is String and StringName(terms["material_kind"]) in CargoSystem.KNOWN_KINDS and _nonnegative(terms.get("material_units", null)) and float(terms["material_units"]) > 0.0 and _nonnegative(terms.get("total_hours", null)) and float(terms["total_hours"]) > 0.0 and _integer(terms.get("output_count", null)) and float(terms["output_count"]) >= 1.0 and String(recipe_id) == String(terms["recipe_id"]) and float(state.get("job_remaining_hours", 0.0)) <= float(terms["total_hours"])


func _valid_modules(state: Dictionary) -> bool:
	if not _valid_shape(state, {"state_version": 1}):
		return false
	var modules: Node = _find_system(&"module_system")
	for field: String in ["installed", "machines", "jobs", "machine_jobs", "module_paid_costs", "machine_paid_costs"]:
		if not state.get(field, {}) is Dictionary:
			return false
	var installed: Dictionary = state.get("installed", {})
	for field: String in ["installed", "machines"]:
		var fitted: Dictionary = state.get(field, {})
		var cost_field: String = "module_paid_costs" if field == "installed" else "machine_paid_costs"
		var costs: Dictionary = state.get(cost_field, {})
		if (int(state.get("state_version", 1)) >= 5 or state.has(cost_field)) and (costs.size() != fitted.size() or not fitted.keys().all(func(key: Variant) -> bool: return costs.has(key))):
			return false
		for key: Variant in fitted:
			if String(key).is_empty() or not fitted[key] is String or String(fitted[key]).is_empty():
				return false
			if costs.has(key) and not _valid_quantity_map(costs[key], CargoSystem.KNOWN_KINDS):
				return false
			if field == "machines" and not _valid_socket(String(key), installed):
				return false
			if modules != null:
				var resource: Resource = modules.call("get_module" if field == "installed" else "get_machine", StringName(fitted[key])) as Resource
				if resource == null or (field == "installed" and String(resource.get("hardpoint_id")) != String(key)):
					return false
	for field: String in ["jobs", "machine_jobs"]:
		var pending: Dictionary = state.get(field, {})
		var id_field: String = "module_id" if field == "jobs" else "machine_id"
		for key: Variant in pending:
			var job: Variant = pending[key]
			if String(key).is_empty() or not job is Dictionary or not job.get(id_field, null) is String or String(job[id_field]).is_empty() or not _nonnegative(job.get("remaining_hours", null)) or not _nonnegative(job.get("total_hours", null)):
				return false
			if float(job["total_hours"]) <= 0.0 or float(job["remaining_hours"]) > float(job["total_hours"]) or not _valid_quantity_map(job.get("paid_cost", {}), CargoSystem.KNOWN_KINDS):
				return false
			if int(state.get("state_version", 1)) >= 5 and not job.has("paid_cost"):
				return false
			if (state.get("installed" if field == "jobs" else "machines", {}) as Dictionary).has(key) or (field == "machine_jobs" and not _valid_socket(String(key), installed)):
				return false
			if modules != null:
				var resource: Resource = modules.call("get_module" if field == "jobs" else "get_machine", StringName(job[id_field])) as Resource
				if (resource == null and not job.has("paid_cost")) or (field == "jobs" and resource != null and String(resource.get("hardpoint_id")) != String(key)):
					return false
	return true


func _valid_salvage(systems: Dictionary) -> bool:
	var state: Dictionary = systems.get("salvage", {})
	var units: Variant = state.get("units", {})
	if not units is Dictionary:
		return false
	var modules: Dictionary = systems.get("modules", {})
	var salvage: Node = _find_system(&"salvage_system")
	var definition: Resource = salvage.get("definition") as Resource if salvage != null else null
	var sockets: Dictionary = {}
	var carried: int = 0
	for key: Variant in units:
		var unit: Variant = units[key]
		if String(key).is_empty() or not unit is Dictionary or not _nonnegative(unit.get("condition", null)) or float(unit["condition"]) > 1.0:
			return false
		for field: String in ["unit_id", "machine_id", "object_id", "socket_id"]:
			if not unit.get(field, null) is String:
				return false
		if String(unit["unit_id"]) != String(key) or String(unit["machine_id"]).is_empty() or String(unit["object_id"]).is_empty() or not _valid_seed(unit.get("sector_seed", null), int(state.get("state_version", 1)) < 2):
			return false
		for field: String in ["diagnosed", "isolated"]:
			if not unit.get(field, null) is bool:
				return false
		if definition != null and String(unit["machine_id"]) != String((definition.get("machine") as Resource).get("machine_id")):
			return false
		var location: Variant = unit.get("location", null)
		if location not in ["mounted", "world", "carried", "stowed", "fitted", "scrapped"] or not unit.get("position", null) is Dictionary:
			return false
		for axis: String in ["x", "y", "z"]:
			if not _number(unit["position"].get(axis, null)):
				return false
		if location == "carried":
			carried += 1
		if location == "fitted":
			var socket: String = unit["socket_id"]
			if not _valid_socket(socket, modules.get("installed", {})) or sockets.has(socket) or (modules.get("machines", {}) as Dictionary).has(socket) or (modules.get("machine_jobs", {}) as Dictionary).has(socket) or not bool(unit["diagnosed"]) or (definition != null and float(unit["condition"]) < float(definition.get("repaired_condition"))):
				return false
			sockets[socket] = true
		elif String(unit["socket_id"]) != "":
			return false
	return carried <= 1


func _valid_socket(socket: String, installed: Dictionary) -> bool:
	var pieces: PackedStringArray = socket.split(":")
	return pieces.size() == 2 and not pieces[0].is_empty() and pieces[1].is_valid_int() and str(int(pieces[1])) == pieces[1] and int(pieces[1]) >= 0 and int(pieces[1]) <= 2 and installed.has(pieces[0])


func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floor(float(value))


func _valid_seed(value: Variant, numeric_legacy: bool = true) -> bool:
	return (value is String and String(value).is_valid_int() and str(int(value)) == value) or (numeric_legacy and _integer(value))


func _valid_rows(value: Variant, schema: Dictionary, required: String = "") -> bool:
	if not value is Array:
		return false
	for row: Variant in value:
		if not row is Dictionary or not _valid_shape(row, schema) or (required != "" and (not row.get(required, null) is String or String(row[required]).is_empty())):
			return false
		if required == "component_id":
			for field: String in ["condition", "hours_operated", "load"]:
				if row.has(field) and not _nonnegative(row[field]):
					return false
			if float(row.get("condition", 1.0)) > 1.0:
				return false
	return true


func _valid_system_records(systems: Dictionary) -> bool:
	var wear_schema: Dictionary = {"component_id": "", "condition": 1.0, "hours_operated": 0.0, "load": 0.0, "failed_mode": "", "diagnosed": false, "scanned": false}
	var scalars: Dictionary = {"system_id": "", "state_version": 1, "current_destination_id": "", "plotted_destination_id": "", "plotted_waypoint": "", "current_leg": 0, "fuel_mass_kg": 0.0, "course_error": 0.0, "transit_elapsed_hours": 0.0, "transit_active": false, "arrival_ordinal": 0, "visited_destinations": {}, "potable_l": 0.0, "greywater_l": 0.0, "contamination": 0.0, "reclaimer_powered": false, "reclaimer_servicing": false, "water_low_latched": false, "water_depleted_latched": false, "water_contaminated_latched": false, "condition": 0.0, "incapacitated": false, "cause": "", "cognition_level": 0, "last_emitted_bucket": 0, "ration_accumulator": 0.0, "state": 0, "inner_open": false, "outer_open": false, "suit_stored": false, "suit_worn": false, "suit_o2_hours": 0.0, "battery_charge_wh": 0.0, "battery_capacity_wh": 0.0, "battery_max_discharge_w": 0.0, "brownout": false, "served_w": 0.0, "drift_distance_m": 0.0, "offset": {"x": 0.0, "y": 0.0, "z": 0.0}, "holding": false, "approach_target_id": "", "next_entry_id": 0, "current_step_index": 0, "is_active": false, "is_completed": false, "efficiency_multiplier": 0.0}
	for key: Variant in systems:
		var state: Dictionary = systems[key]
		if not _valid_shape(state, scalars) or (state.has("state_version") and int(state["state_version"]) < 1) or not _valid_rows(state.get("wear", []), wear_schema, "component_id"):
			return false
		for field: String in ["wear_rng_state", "hull_rng_state"]:
			if state.has(field) and not _valid_seed(state[field]):
				return false
		var restores: Variant = state.get("failure_restore", {})
		if not restores is Dictionary:
			return false
		for restore: Variant in restores.values():
			if not restore is Dictionary or not _valid_shape(restore, {"kind": "", "target": "", "value": 0.0}):
				return false
	for key: String in ["atmosphere", "thermal", "hull"]:
		var rooms: Variant = (systems.get(key, {}) as Dictionary).get("compartments", {})
		if not rooms is Dictionary:
			return false
		var schema: Dictionary = {"n_o2": 0.0, "n_co2": 0.0, "n_n2": 0.0, "scrubber_efficiency": 0.0, "leak_rate_per_hour": 0.0, "candle_burn_remaining_hours": 0.0, "filter_condition": 0.0, "humidity_g": 0.0, "last_pressure_kpa": 0.0, "last_o2_fraction": 0.0, "last_co2_ppm": 0.0, "last_humidity_fraction": 0.0, "occupants": 0, "candles_remaining": 0, "scrubber_powered": false, "isolated": false, "filter_installed": false, "temperature_c": 0.0, "heater_powered": false, "heater_on": false, "constant_gain_w": 0.0, "punctures": []}
		for room: Variant in rooms.values():
			if not room is Dictionary or not _valid_shape(room, schema):
				return false
			for field: String in ["n_o2", "n_co2", "n_n2", "scrubber_efficiency", "leak_rate_per_hour", "candle_burn_remaining_hours", "filter_condition", "humidity_g", "last_pressure_kpa", "last_o2_fraction", "last_co2_ppm", "last_humidity_fraction", "occupants", "candles_remaining"]:
				if room.has(field) and not _nonnegative(room[field]):
					return false
			if key == "hull":
				for puncture: Variant in room.get("punctures", []):
					if not _nonnegative(puncture) or float(puncture) <= 0.0:
						return false
	var power: Dictionary = systems.get("power", {})
	for field: String in ["generators", "load_overrides"]:
		if not _valid_quantity_map(power.get(field, {})):
			return false
	for field: String in ["breakers", "shed", "light_enabled"]:
		if not _valid_bool_map(power.get(field, {})):
			return false
	if not _valid_bool_map((systems.get("nav", {}) as Dictionary).get("visited_destinations", {})):
		return false
	var sector: Dictionary = systems.get("sector", {})
	if sector.has("field_seed") and not _valid_seed(sector["field_seed"], int(sector.get("state_version", 1)) < 2):
		return false
	if (int(sector.get("state_version", 1)) >= 3 and not sector.has("survey_records")) or not SectorSystem.valid_survey_records(sector.get("survey_records", {})):
		return false
	var nav: Dictionary = systems.get("nav", {})
	var propulsion: Variant = nav.get("propulsion", {})
	if not propulsion is Dictionary or not _valid_shape(propulsion, {"mass_kg": 0.0, "consumed_kg": 0.0, "actual_hours": 0.0, "thermal_hold": false, "tank_recovering": false, "service": {}, "wear": []}) or not _valid_rows(propulsion.get("wear", []), wear_schema, "component_id"):
		return false
	if propulsion.has("rng_state") and not _valid_seed(propulsion["rng_state"]):
		return false
	for service: Variant in propulsion.get("service", {}).values():
		if not service is Dictionary or not _valid_shape(service, {"isolated": false, "housing_open": false}):
			return false
	if not _valid_rows(nav.get("planet_discoveries", []), {"origin_destination_id": "", "destination_id": "", "arrival_ordinal": 0}, "destination_id") or not _valid_rows((systems.get("computer", {}) as Dictionary).get("entries", []), {"id": 0, "day": 0, "hour": 0, "kind": "", "text": "", "unread": false}):
		return false
	var comms: Dictionary = systems.get("comms", {})
	if not _valid_rows(comms.get("pending", []), {"id": "", "day": 0}, "id") or not _valid_quantity_map(comms.get("arrived_days", {}), [], true):
		return false
	for field: String in ["arrived", "unread", "sent"]:
		if not _valid_string_list(comms.get(field, [])):
			return false
	return _valid_string_list((systems.get("voice_guide", {}) as Dictionary).get("completed_steps", []))


func _valid_bool_map(value: Variant) -> bool:
	return value is Dictionary and value.values().all(func(item: Variant) -> bool: return item is bool)


func _valid_string_list(value: Variant) -> bool:
	return value is Array and value.all(func(item: Variant) -> bool: return item is String or item is StringName)


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
		version = 8
	if version == 8:
		# Individual owners infer unavailable historical paid terms once from the
		# current catalog; keep their legacy version until that restore occurs.
		data["save_version"] = 9
		version = 9
	if version == 9:
		var systems: Dictionary = data.get("systems", {})
		if systems.has("sector"):
			var sector: Dictionary = systems["sector"]
			sector["survey_records"] = sector.get("survey_records", {})
			sector["state_version"] = 3
		data["save_version"] = 10
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


## Save key of an interactable; movable nodes report their home path (see get_save_key).
func _node_key(node: Node) -> String:
	if node.has_method(&"get_save_key"):
		return String(node.call(&"get_save_key"))
	return String(node.get_path())


func _system_key(system: Node, group_name: StringName) -> String:
	if system.get(&"system_id") != null:
		var system_id: StringName = system.get(&"system_id")
		if system_id != &"":
			return String(system_id)
	return String(group_name).trim_suffix("_system")
