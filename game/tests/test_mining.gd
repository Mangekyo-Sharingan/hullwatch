## Mining tests: seeded yields, cutter + canister gating, extraction persistence and the
## hull cargo port.
extends SceneTree

const CANISTER_CAPACITY: float = 6.0

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

	var sector: SectorSystem = SectorSystem.new()
	sector.field_seed = 20260918
	sector.drift_axis = Vector3.FORWARD
	root.add_child(sector)
	var cargo: CargoSystem = CargoSystem.new()
	root.add_child(cargo)
	await process_frame
	for i: int in 168:
		sector.sim_tick(1.0)
		if not sector.get_contacts().is_empty():
			break
	var contacts: Array[Dictionary] = sector.get_contacts()
	_check(not contacts.is_empty(), "a contact exists to mine")
	if contacts.is_empty():
		_finish()
		return
	var entry: Dictionary = contacts[0]
	_check(entry.has("resource") and entry.has("yield_units"), "contacts carry resource and yield data")
	_check(float(entry["yield_units"]) > 0.0, "yield starts positive")

	var object: SpaceObject = SpaceObject.new()
	object.setup(entry)
	root.add_child(object)
	var player: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	_errors.clear()
	object.interact(player)
	_check(_error_reason(&"no_cutter"), "mining refuses without the cutter")

	_check(bool(player.call("equip_suit_cutter")), "the cutter clips to the suit")
	_check(bool(player.call("has_suit_cutter")), "the suit carries the cutter")
	_errors.clear()
	object.interact(player)
	_check(_error_reason(&"no_canister"), "mining refuses without an empty canister")

	var canister: SampleCanister = SampleCanister.new()
	canister.item_id = &"sample_canister"
	canister.item_name = "Sample canister"
	root.add_child(canister)
	player.call("take_carriable", canister)
	var before: float = sector.get_remaining_yield(String(entry["id"]))
	_errors.clear()
	object.interact(player)
	_check(_errors.is_empty(), "mining succeeds with cutter and canister")
	_check(not bool(canister.call("is_empty")), "the canister takes a load")
	_check(is_equal_approx(float(canister.call("get_load_units")), CANISTER_CAPACITY), "the load fills the canister")
	_check(is_equal_approx(sector.get_remaining_yield(String(entry["id"])), before - CANISTER_CAPACITY), "extraction drains the deposit")

	object.interact(player)
	_check(_error_reason(&"no_canister"), "a full canister is not reusable")

	var port: CargoPort = CargoPort.new()
	root.add_child(port)
	await process_frame
	_errors.clear()
	port.interact(player)
	_check(_errors.is_empty(), "the cargo port stows the load")
	_check(is_equal_approx(cargo.get_units(StringName(String(entry["resource"]))), CANISTER_CAPACITY), "cargo holds the stowed units")
	_check(bool(canister.call("is_empty")), "the canister empties on stowing")

	var saved: Dictionary = sector.save_state()
	var restored: SectorSystem = SectorSystem.new()
	root.add_child(restored)
	restored.load_state(saved)
	_check(is_equal_approx(restored.get_remaining_yield(String(entry["id"])), before - CANISTER_CAPACITY), "save/load keeps extraction progress")

	sector.free()
	restored.free()
	cargo.free()
	object.free()
	player.free()
	port.free()
	event_bus.disconnect(&"sim_event", _on_sim_event)
	_finish()


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"procedure_error":
		_errors.append(payload)


func _error_reason(reason: StringName) -> bool:
	for payload: Dictionary in _errors:
		if StringName(payload.get("reason", &"")) == reason:
			return true
	return false


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_mining")
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
