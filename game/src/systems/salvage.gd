class_name SalvageSystem
extends ShipSystem

@export var definition: SalvageDefinition

var _units: Dictionary = {}


func _ready() -> void:
	system_id = &"salvage"
	add_to_group(&"salvage_system")
	super._ready()


func register_unit(object_id: String, sector_seed: int) -> String:
	if object_id.is_empty() or definition == null or definition.machine == null:
		return ""
	var unit_id: String = "%d:%s:%s" % [sector_seed, object_id, String(definition.salvage_id)]
	# ponytail: one record per encountered mount; store only changed mounts if long-run saves become large.
	if not _units.has(unit_id):
		_units[unit_id] = {"unit_id": unit_id, "object_id": object_id, "sector_seed": sector_seed,
			"machine_id": String(definition.machine.machine_id), "location": "mounted",
			"isolated": false, "diagnosed": false, "condition": definition.initial_condition,
			"socket_id": "", "position": {"x": 0.0, "y": 0.0, "z": 0.0}}
	return unit_id


func get_unit(unit_id: String) -> Dictionary:
	return (_units.get(unit_id, {}) as Dictionary).duplicate(true)


func get_units(location: StringName = &"") -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	for key: String in _units:
		var unit: Dictionary = _units[key]
		if location == &"" or StringName(unit["location"]) == location:
			units.append(unit.duplicate(true))
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["unit_id"]) < String(b["unit_id"]))
	return units


func get_machine(unit_id: String) -> ShipMachine:
	return definition.machine if _units.has(unit_id) and definition != null else null


func get_unit_at(socket_id: StringName) -> String:
	for unit: Dictionary in get_units(&"fitted"):
		if StringName(unit["socket_id"]) == socket_id:
			return String(unit["unit_id"])
	return ""


func get_fitted_machines() -> Dictionary:
	var machines: Dictionary = {}
	for key: String in _units:
		var unit: Dictionary = _units[key]
		if String(unit["location"]) == "fitted":
			machines[String(unit["socket_id"])] = String(unit["machine_id"])
	return machines


func isolate_unit(unit_id: String) -> bool:
	if not _at(unit_id, &"mounted"):
		return _refuse(&"not_mounted", unit_id)
	_units[unit_id]["isolated"] = true
	_changed(unit_id, &"salvage_isolated")
	return true


func release_unit(unit_id: String, tool: StringName, position: Vector3) -> bool:
	if not _at(unit_id, &"mounted") or not bool(_units[unit_id]["isolated"]):
		return _refuse(&"isolate_salvage_first", unit_id)
	if tool != &"wrench" or not position.is_finite():
		return _refuse(&"needs_wrench", unit_id)
	_units[unit_id]["location"] = "world"
	_set_position(unit_id, position)
	_changed(unit_id, &"salvage_released")
	return true


func take_unit(unit_id: String) -> bool:
	if not _at(unit_id, &"world") or not get_units(&"carried").is_empty():
		return _refuse(&"salvage_not_available", unit_id)
	_units[unit_id]["location"] = "carried"
	_changed(unit_id, &"salvage_taken")
	return true


func drop_unit(unit_id: String, position: Vector3) -> bool:
	if not _at(unit_id, &"carried") or not position.is_finite():
		return false
	_units[unit_id]["location"] = "world"
	var sector: Node = _system(&"sector_system")
	if sector != null:
		_units[unit_id]["sector_seed"] = int(sector.get("field_seed"))
	_set_position(unit_id, position)
	_changed(unit_id, &"salvage_dropped")
	return true


func stow_unit(unit_id: String) -> bool:
	var cargo: Node = _system(&"cargo_system")
	if not _at(unit_id, &"carried") or cargo == null or float(cargo.call("get_free_units")) < definition.cargo_units:
		return _refuse(&"salvage_hold_full", unit_id)
	_units[unit_id]["location"] = "stowed"
	_changed(unit_id, &"salvage_stowed")
	return true


func diagnosis_unit(unit_id: String, tool: StringName) -> bool:
	if not _at(unit_id, &"stowed") or tool != &"multimeter":
		return _refuse(&"salvage_diagnosis_needs_multimeter", unit_id)
	_units[unit_id]["diagnosed"] = true
	_changed(unit_id, &"salvage_diagnosed")
	return true


func repair_unit(unit_id: String, tool: StringName) -> bool:
	if not _at(unit_id, &"stowed") or not bool(_units[unit_id]["diagnosed"]):
		return _refuse(&"diagnose_salvage_first", unit_id)
	if tool != &"wrench":
		return _refuse(&"needs_wrench", unit_id)
	if float(_units[unit_id]["condition"]) >= definition.repaired_condition:
		return _refuse(&"salvage_already_repaired", unit_id)
	var cargo: Node = _system(&"cargo_system")
	if cargo == null or not bool(cargo.call("consume_material", definition.repair_material, definition.repair_units)):
		return _refuse(&"missing_repair_material", unit_id)
	_units[unit_id]["condition"] = definition.repaired_condition
	_changed(unit_id, &"salvage_repaired")
	return true


func fit_unit(unit_id: String, socket_id: StringName, tool: StringName = &"") -> bool:
	if not _at(unit_id, &"stowed") or not bool(_units[unit_id]["diagnosed"]) or float(_units[unit_id]["condition"]) < definition.repaired_condition:
		return _refuse(&"salvage_not_ready", unit_id)
	if tool != &"wrench":
		return _refuse(&"needs_wrench", unit_id)
	var modules: Node = _system(&"module_system")
	var pieces: PackedStringArray = String(socket_id).split(":")
	if modules == null or not _valid_socket(String(socket_id)):
		return _refuse(&"invalid_socket", unit_id)
	if StringName(modules.call("get_installed_at", StringName(pieces[0]))) == &"" or StringName(modules.call("get_machine_at", socket_id)) != &"" or not (modules.call("get_machine_job", socket_id) as Dictionary).is_empty():
		return _refuse(&"socket_unavailable", unit_id)
	_units[unit_id]["location"] = "fitted"
	_units[unit_id]["socket_id"] = String(socket_id)
	_changed(unit_id, &"salvage_fitted")
	_emit_machine(&"machine_fitted", unit_id, socket_id)
	return true


func remove_unit(socket_id: StringName) -> bool:
	var unit_id: String = get_unit_at(socket_id)
	var cargo: Node = _system(&"cargo_system")
	if unit_id.is_empty() or cargo == null or float(cargo.call("get_free_units")) < definition.cargo_units:
		return _refuse(&"salvage_hold_full", unit_id)
	_units[unit_id]["location"] = "stowed"
	_units[unit_id]["socket_id"] = ""
	_changed(unit_id, &"salvage_removed")
	_emit_machine(&"machine_removed", unit_id, socket_id)
	return true


func release_pod(hardpoint_id: StringName) -> bool:
	var targets: Array[StringName] = []
	for unit: Dictionary in get_units(&"fitted"):
		if String(unit["socket_id"]).begins_with(String(hardpoint_id) + ":"):
			targets.append(StringName(unit["socket_id"]))
	var cargo: Node = _system(&"cargo_system")
	if not targets.is_empty() and (cargo == null or float(cargo.call("get_free_units")) < definition.cargo_units * targets.size()):
		return _refuse(&"salvage_hold_full", "")
	for socket_id: StringName in targets:
		remove_unit(socket_id)
	return true


func scrap_unit(unit_id: String) -> bool:
	var cargo: Node = _system(&"cargo_system")
	if not _at(unit_id, &"stowed") or cargo == null:
		return _refuse(&"stow_salvage_first", unit_id)
	if float(cargo.call("get_capacity_units")) - float(cargo.call("get_used_units")) + definition.cargo_units < definition.scrap_units:
		return _refuse(&"salvage_hold_full", unit_id)
	_units[unit_id]["location"] = "scrapped"
	_refresh_cargo()
	cargo.call("add_material", definition.scrap_material, definition.scrap_units)
	_changed(unit_id, &"salvage_scrapped")
	return true


func get_status() -> Dictionary:
	return {"system_id": system_id, "units": get_units()}


func save_state() -> Dictionary:
	var units: Dictionary = _units.duplicate(true)
	var player: Node = _system(&"player")
	for key: String in units:
		if String(units[key]["location"]) == "carried" and player is Node3D:
			var position: Vector3 = (player as Node3D).global_position + Vector3.UP
			if player.has_method("get_carried"):
				var carried: Node = player.call("get_carried") as Node
				if carried is Node3D and carried.has_method("get_unit_id"):
					position = (carried as Node3D).global_position
			var sector: Node = _system(&"sector_system")
			if sector != null:
				units[key]["sector_seed"] = int(sector.get("field_seed"))
				position += sector.call("get_ship_position") as Vector3
			units[key]["position"] = {"x": position.x, "y": position.y, "z": position.z}
	return {"system_id": String(system_id), "state_version": 1, "units": units}


func load_state(state: Dictionary) -> void:
	var player: Node = _system(&"player")
	if player != null and player.has_method("get_carried"):
		var carried: Node = player.call("get_carried") as Node
		if carried != null and carried.has_method("get_unit_id"):
			player.call("drop_carried")
	_units.clear()
	var units: Variant = state.get("units", {})
	var sockets: Dictionary = {}
	if units is Dictionary and definition != null and definition.machine != null:
		for key: Variant in units:
			var raw: Variant = units[key]
			if not raw is Dictionary:
				continue
			var unit: Dictionary = (raw as Dictionary).duplicate(true)
			var location: String = String(unit.get("location", ""))
			if not ["mounted", "world", "carried", "stowed", "fitted", "scrapped"].has(location) or String(unit.get("machine_id", "")) != String(definition.machine.machine_id):
				continue
			var raw_condition: Variant = unit.get("condition", 0.0)
			if not (raw_condition is int or raw_condition is float):
				continue
			var condition: float = float(raw_condition)
			if not is_finite(condition) or not unit.get("position", {}) is Dictionary:
				continue
			var position: Dictionary = unit["position"]
			var valid_position: bool = true
			for axis: String in ["x", "y", "z"]:
				var coordinate: Variant = position.get(axis, 0.0)
				if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)):
					valid_position = false
			if not valid_position:
				continue
			unit["condition"] = clampf(condition, 0.0, 1.0)
			unit["unit_id"] = String(key)
			unit["diagnosed"] = bool(unit.get("diagnosed", false))
			unit["isolated"] = bool(unit.get("isolated", false))
			unit["socket_id"] = String(unit.get("socket_id", ""))
			unit["sector_seed"] = int(unit.get("sector_seed", 0))
			unit["object_id"] = String(unit.get("object_id", ""))
			if location == "carried":
				unit["location"] = "world"
			if location == "fitted":
				var socket: String = String(unit["socket_id"])
				var modules: Node = _system(&"module_system")
				if not _valid_socket(socket) or not bool(unit["diagnosed"]) or condition < definition.repaired_condition or sockets.has(socket) or modules == null or StringName(modules.call("get_installed_at", StringName(socket.get_slice(":", 0)))) == &"" or StringName(modules.call("get_machine_at", StringName(socket))) != &"" or not (modules.call("get_machine_job", StringName(socket)) as Dictionary).is_empty():
					unit["location"] = "stowed"
					unit["socket_id"] = ""
				else:
					sockets[socket] = true
			_units[String(key)] = unit
	_refresh_cargo()
	_changed("", &"salvage_state_restored")


func _valid_socket(socket: String) -> bool:
	var pieces: PackedStringArray = socket.split(":")
	return pieces.size() == 2 and pieces[1].is_valid_int() and int(pieces[1]) >= 0 and int(pieces[1]) <= 2


func _at(unit_id: String, location: StringName) -> bool:
	return _units.has(unit_id) and StringName(_units[unit_id]["location"]) == location


func _set_position(unit_id: String, position: Vector3) -> void:
	_units[unit_id]["position"] = {"x": position.x, "y": position.y, "z": position.z}


func _refresh_cargo() -> void:
	var cargo: Node = _system(&"cargo_system")
	if cargo != null:
		cargo.call("set_reserved_source", &"salvage", get_units(&"stowed").size() * definition.cargo_units if definition != null else 0.0)


func _changed(unit_id: String, event_name: StringName) -> void:
	_refresh_cargo()
	emit_sim_event(event_name, {"unit_id": unit_id})
	var bus: Node = _get_autoload(&"EventBus")
	if bus != null:
		bus.emit_signal(&"salvage_changed", unit_id)


func _emit_machine(signal_name: StringName, unit_id: String, socket_id: StringName) -> void:
	var bus: Node = _get_autoload(&"EventBus")
	if bus != null:
		bus.emit_signal(signal_name, definition.machine.machine_id, socket_id)


func _refuse(reason: StringName, unit_id: String) -> bool:
	emit_sim_event(&"procedure_error", {"reason": reason, "unit_id": unit_id})
	return false


func _system(group_name: StringName) -> Node:
	return get_tree().get_first_node_in_group(group_name) if is_inside_tree() else null
