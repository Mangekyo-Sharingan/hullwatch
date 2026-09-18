## Close approach tests: fuel-gated approach to a contact, standoff hold with the drift
## stopped, resume, seven-day end-to-end reachability and mid-hold save/load.
extends SceneTree

var _failures: int = 0
var _errors: Array[Dictionary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var event_bus: Node = root.get_node_or_null(^"EventBus")
	if event_bus == null:
		event_bus = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
	event_bus.connect(&"sim_event", _on_sim_event)

	var sector: SectorSystem = _make_sector()
	var nav: NavSystem = NavSystem.new()
	nav.fuel_mass_kg = 1200.0
	root.add_child(nav)
	var console: ApproachConsole = ApproachConsole.new()
	root.add_child(console)
	await process_frame

	for i: int in 168:
		sector.sim_tick(1.0)
		if not sector.get_contacts().is_empty():
			break
	var contacts: Array[Dictionary] = sector.get_contacts()
	_check(not contacts.is_empty(), "seven days of drift brings a contact into range")
	if contacts.is_empty():
		_finish()
		return
	var contact_id: String = String(contacts[0]["id"])
	var cost: float = float(nav.get(&"approach_fuel_cost_kg"))
	var fuel_before: float = nav.fuel_mass_kg
	_check(console.select_action(StringName(contact_id)), "board command starts the approach")
	_check(absf(nav.fuel_mass_kg - (fuel_before - cost)) < 0.001, "approach spends its fuel")

	var target_distance: float = 1e9
	for i: int in 240:
		sector.sim_tick(0.1)
		var contacts_now: Array[Dictionary] = sector.get_contacts()
		for entry: Dictionary in contacts_now:
			if String(entry["id"]) == contact_id:
				target_distance = float(entry["distance_m"])
		if bool(sector.call("is_holding")):
			break
	_check(bool(sector.call("is_holding")), "the ship settles at standoff")
	_check(target_distance <= SectorSystem.STANDOFF_M + 1.0, "standoff distance holds (%.1f m)" % target_distance)

	var drift_before: float = sector.get_drift_distance()
	sector.sim_tick(1.0)
	_check(absf(sector.get_drift_distance() - drift_before) < 0.001, "station-keeping stops the drift")

	_check(console.select_action(&"resume"), "board command resumes the drift")
	sector.sim_tick(1.0)
	_check(sector.get_drift_distance() > drift_before, "drift resumes after release")
	_check(not bool(sector.call("is_holding")), "station-keeping is cleared")

	for i: int in 168:
		sector.sim_tick(1.0)
		if not sector.get_contacts().is_empty():
			break
	var fresh: Array[Dictionary] = sector.get_contacts()
	_check(not fresh.is_empty(), "drift brings a fresh contact into range")
	if fresh.is_empty():
		_finish()
		return
	var fresh_id: String = String(fresh[0]["id"])

	_errors.clear()
	nav.fuel_mass_kg = 0.0
	var refused: bool = not console.select_action(StringName(fresh_id))
	_check(refused and not _errors.is_empty() and StringName(_errors[0].get("reason", &"")) == &"no_fuel", "approach refuses without fuel")

	nav.fuel_mass_kg = 1200.0
	_check(console.select_action(StringName(fresh_id)), "second approach is accepted")
	for i: int in 240:
		sector.sim_tick(0.1)
		if bool(sector.call("is_holding")):
			break
	_check(bool(sector.call("is_holding")), "second approach holds again")
	var saved: Dictionary = sector.save_state()
	var restored: SectorSystem = _make_sector()
	restored.field_seed = 1
	restored.load_state(saved)
	_check(bool(restored.call("is_holding")), "save/load keeps station-keeping")
	_check(String(restored.call("get_approach_target_id")) == fresh_id, "save/load keeps the held contact")
	_check(restored.get_ship_position().distance_to(sector.get_ship_position()) < 0.001, "save/load keeps the ship position")

	sector.free()
	restored.free()
	nav.free()
	console.free()
	event_bus.disconnect(&"sim_event", _on_sim_event)
	_finish()


func _make_sector() -> SectorSystem:
	var sector: SectorSystem = SectorSystem.new()
	sector.field_seed = 20260918
	sector.drift_axis = Vector3.FORWARD
	sector.drift_speed_m_per_hour = 1500.0
	root.add_child(sector)
	return sector


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"procedure_error":
		_errors.append(payload)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_approach")
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
