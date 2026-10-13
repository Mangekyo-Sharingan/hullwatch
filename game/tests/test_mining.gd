## Mining tests: seeded yields, cutter + canister gating, extraction persistence and the
## hull cargo port.
extends SceneTree

const CANISTER_CAPACITY: float = 6.0

var _failures: int = 0
var _errors: Array[Dictionary] = []
var _stowed: Array[Dictionary] = []


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
	_test_partial_stow(player, canister, port, cargo, StringName(String(entry["resource"])))
	_test_canister_boundaries(canister)

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


func _test_partial_stow(player: Node, canister: SampleCanister, port: CargoPort, cargo: CargoSystem, kind: StringName) -> void:
	_check(is_equal_approx(canister.load_amount(kind, CANISTER_CAPACITY), CANISTER_CAPACITY), "reload for partial transfer")
	cargo.add_material(CargoSystem.KIND_METAL, cargo.get_free_units() - 1.25)
	var total: float = cargo.get_used_units() + canister.get_load_units()
	var held_before: float = cargo.get_units(kind)
	_errors.clear()
	_stowed.clear()
	port.interact(player)
	_check(_errors.is_empty(), "near-full hold accepts a partial load")
	_check(is_equal_approx(cargo.get_units(kind) - held_before, 1.25), "hold accepts exactly the available fractional room")
	_check(is_equal_approx(canister.get_load_units(), 4.75) and canister.get_load_kind() == kind, "partial stow preserves remainder and kind")
	_check(is_equal_approx(cargo.get_used_units() + canister.get_load_units(), total), "partial stow conserves total material")
	_check(_stowed.size() == 1 and is_equal_approx(float(_stowed[0]["units"]), 1.25) and StringName(_stowed[0]["kind"]) == kind, "stow event reports accepted amount and kind")

	var restored: SampleCanister = SampleCanister.new()
	root.add_child(restored)
	restored.load_state(JSON.parse_string(JSON.stringify(canister.save_state())) as Dictionary)
	_check(is_equal_approx(restored.get_load_units(), 4.75) and restored.get_load_kind() == kind, "JSON save/load preserves remaining units and kind")
	restored.free()

	for attempt: int in 3:
		_errors.clear()
		port.interact(player)
		_check(_error_reason(&"cargo_full"), "full hold refuses retry %d" % attempt)
		_check(is_equal_approx(canister.get_load_units(), 4.75) and canister.get_load_kind() == kind and is_equal_approx(cargo.get_used_units() + canister.get_load_units(), total), "full hold retry preserves material %d" % attempt)
	_check(_stowed.size() == 1, "full hold retries emit no successful stows")

	_check(cargo.consume_material(CargoSystem.KIND_METAL, 4.75), "clear exactly enough room for remainder")
	held_before = cargo.get_units(kind)
	_errors.clear()
	port.interact(player)
	_check(_errors.is_empty() and canister.is_empty() and canister.get_load_kind() == &"", "retry transfers exact remainder and clears kind")
	_check(is_equal_approx(cargo.get_units(kind) - held_before, 4.75), "all remaining sampled material arrives exactly once")
	_check(is_equal_approx(cargo.get_used_units() + canister.get_load_units(), total - 4.75), "retry conserves material after room is cleared")
	_check(_stowed.size() == 2 and is_equal_approx(float(_stowed[1]["units"]), 4.75), "retry event reports exact remaining amount")
	var used_before: float = cargo.get_used_units()
	_errors.clear()
	port.interact(player)
	_check(_error_reason(&"no_sample") and is_equal_approx(cargo.get_used_units(), used_before) and _stowed.size() == 2, "empty retry cannot duplicate material")

	for material: StringName in CargoSystem.KNOWN_KINDS:
		cargo.consume_material(material, cargo.get_units(material))
	cargo.capacity_units = 0.0
	canister.load_amount(kind, 2.0)
	_errors.clear()
	port.interact(player)
	_check(_error_reason(&"cargo_full") and is_equal_approx(canister.get_load_units(), 2.0) and canister.get_load_kind() == kind and cargo.get_used_units() == 0.0 and _stowed.size() == 2, "zero-capacity receiver preserves load")
	canister.unload()


func _test_canister_boundaries(canister: SampleCanister) -> void:
	canister.load_amount(CargoSystem.KIND_ICE, 3.5)
	for invalid: float in [NAN, -1.0, 0.0, INF, -INF]:
		_check(canister.remove_amount(invalid) == 0.0 and canister.get_load_units() == 3.5 and canister.get_load_kind() == CargoSystem.KIND_ICE, "invalid removal leaves stock unchanged: %s" % invalid)
	_check(canister.remove_amount(1.25) == 1.25 and canister.get_load_units() == 2.25 and canister.get_load_kind() == CargoSystem.KIND_ICE, "partial removal returns actual amount and retains kind")
	_check(canister.remove_amount(9.0) == 2.25 and canister.is_empty() and canister.get_load_kind() == &"", "overdraw removes only held stock and clears kind")
	_check(canister.remove_amount(1.0) == 0.0, "empty removal returns zero")
	for invalid: float in [NAN, -1.0, 0.0, INF, -INF]:
		_check(canister.load_amount(CargoSystem.KIND_ICE, invalid) == 0.0 and canister.is_empty() and canister.get_load_kind() == &"", "invalid load leaves canister empty: %s" % invalid)
	for kind: StringName in [&"", &"unknown"]:
		_check(canister.load_amount(kind, 1.0) == 0.0 and canister.is_empty() and canister.get_load_kind() == &"", "invalid material kind is refused")
	for capacity: float in [NAN, -1.0, 0.0, INF, -INF]:
		canister.capacity_units = capacity
		_check(canister.load_amount(CargoSystem.KIND_ICE, 1.0) == 0.0 and canister.is_empty() and canister.get_load_kind() == &"", "invalid or zero capacity takes no stock: %s" % capacity)
	canister.capacity_units = CANISTER_CAPACITY
	_check(canister.load_amount(CargoSystem.KIND_ICE, 9.0) == CANISTER_CAPACITY, "valid load remains capacity bounded")
	_check(canister.load_amount(CargoSystem.KIND_ORE, 1.0) == 0.0 and canister.get_load_kind() == CargoSystem.KIND_ICE and canister.get_load_units() == CANISTER_CAPACITY, "loaded canister refuses replacement")
	var unloaded: Dictionary = canister.unload()
	_check(unloaded["kind"] == CargoSystem.KIND_ICE and float(unloaded["units"]) == CANISTER_CAPACITY and canister.is_empty() and canister.get_load_kind() == &"", "unload keeps its return contract and clears stock")


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"procedure_error":
		_errors.append(payload)
	elif event_name == &"sample_stowed":
		_stowed.append(payload)


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
