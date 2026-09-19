## Anomaly salvage: the field scanner reads anomalies straight into the cargo hold,
## refuses without the scanner or with a full hold, and depletes the deposit.
extends SceneTree

var _failures: int = 0
var _errors: Array[Dictionary] = []
var _logged: Array[Dictionary] = []


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

	var sector: SectorSystem = SectorSystem.new()
	sector.field_seed = 20260918
	sector.drift_axis = Vector3.FORWARD
	root.add_child(sector)
	var cargo: CargoSystem = CargoSystem.new()
	root.add_child(cargo)
	await process_frame

	var entry: Dictionary = {}
	for i: int in 720:
		sector.sim_tick(1.0)
		for contact: Dictionary in sector.get_contacts():
			if StringName(contact.get("kind", &"")) == &"anomaly":
				entry = contact
				break
		if not entry.is_empty():
			break
	_check(not entry.is_empty(), "an anomaly contact drifts into range")
	if entry.is_empty():
		_finish()
		return
	_check(StringName(entry.get("resource", &"")) == &"exotic", "anomalies carry exotic material")

	var anomaly: SpaceObject = SpaceObject.new()
	anomaly.setup(entry)
	root.add_child(anomaly)
	var player: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	_errors.clear()
	anomaly.interact(player)
	_check(_error_reason(&"no_scanner"), "reading refuses without the scanner")

	var scanner: Carriable = Carriable.new()
	scanner.item_id = &"scanner"
	scanner.item_name = "Field scanner"
	root.add_child(scanner)
	player.call("take_carriable", scanner)
	var before: float = sector.get_remaining_yield(String(entry["id"]))
	_logged.clear()
	anomaly.interact(player)
	_check(_logged.size() == 1, "a survey reading is logged")
	_check(_logged.size() == 1 and float(_logged[0].get("units", 0.0)) > 0.0, "the reading yields units")
	var taken: float = cargo.get_units(&"exotic")
	_check(taken > 0.0, "exotic material reaches the hold")
	_check(is_equal_approx(anomaly.get_remaining(), before - taken), "the reading drains the anomaly")

	cargo.add_material(&"ice", cargo.get_free_units())
	_errors.clear()
	anomaly.interact(player)
	_check(_error_reason(&"cargo_full"), "a full hold refuses salvage")
	cargo.consume_material(&"ice", cargo.get_units(&"ice"))

	var guard: int = 0
	while anomaly.get_remaining() > 0.0 and guard < 12:
		anomaly.interact(player)
		guard += 1
	_check(is_zero_approx(anomaly.get_remaining()), "study drains the anomaly")
	_errors.clear()
	anomaly.interact(player)
	_check(_error_reason(&"depleted"), "a spent anomaly reports depleted")

	sector.free()
	cargo.free()
	anomaly.free()
	# The scanner rides the player while carried and frees with it.
	player.free()
	event_bus.disconnect(&"sim_event", _on_sim_event)
	_finish()


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"procedure_error":
		_errors.append(payload)
	elif event_name == &"anomaly_logged":
		_logged.append(payload)


func _error_reason(reason: StringName) -> bool:
	for payload: Dictionary in _errors:
		if StringName(payload.get("reason", &"")) == reason:
			return true
	return false


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_anomaly_salvage")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	_failures += 1
	print("FAIL: ", label)
