extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()

	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_round_trip()
	_test_version_refusal()
	_test_slot_round_trip()

	_finish()


func _test_round_trip() -> void:
	var stores := Stores.new()
	stores.initial_inventory = {&"filter_co2": 3}
	root.add_child(stores)

	var atmosphere := AtmosphereSystem.new()
	var config := CompartmentConfig.new()
	config.compartment_id = &"main"
	config.volume_m3 = 60.0
	var defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = defs
	root.add_child(atmosphere)

	var unit := ScrubberUnit.new()
	root.add_child(unit)

	unit.interact(null)
	unit.interact(null)
	_check(not unit.is_powered() and unit.is_housing_open(), "scrubber set to a non-default procedure stage")
	atmosphere.set_filter_condition(&"main", 0.4)
	var sim_clock: Node = _find_root_child(&"SimClock")
	sim_clock.call("fast_forward", 3.0)

	var save_manager: Node = _find_root_child(&"SaveManager")
	_check(save_manager != null, "save manager autoload present")
	if save_manager == null:
		return
	var data: Dictionary = save_manager.call("save_to_dict")
	_check(data["systems"].has("stores") and data["systems"].has("atmosphere"), "systems serialize into the save")
	var unit_path: String = String(unit.get_path())
	_check(data["interactables"].has(unit_path), "interactables serialize by node path")
	var clock_data: Dictionary = data["clock"]
	_check(absf(float(clock_data["sim_seconds"]) - 3.0 * 3600.0) < 0.01, "clock serializes sim seconds")

	sim_clock.call("fast_forward", 5.0)
	stores.consume_part(&"filter_co2", 1)
	atmosphere.set_filter_condition(&"main", 0.05)
	unit.interact(null)
	_check(not bool(atmosphere.get_compartment_status(&"main")["filter_installed"]), "sim state mutated after save")

	_check(bool(save_manager.call("load_from_dict", data)), "load_from_dict succeeds")
	_check(absf(float(sim_clock.call("get_total_hours")) - 3.0) < 0.001, "clock restored")
	_check(absf(atmosphere.get_filter_condition(&"main") - 0.4) < 0.001, "filter condition restored")
	_check(stores.get_count(&"filter_co2") == 3, "stores inventory restored")
	_check(not unit.is_powered() and unit.is_housing_open(), "scrubber node state restored")
	var status: Dictionary = atmosphere.get_compartment_status(&"main")
	_check(not bool(status["scrubber_powered"]), "scrubber power re-synced to the sim after load")
	_check(bool(status["filter_installed"]), "scrubber filter re-synced to the sim after load")

	stores.free()
	atmosphere.free()
	unit.free()


func _test_version_refusal() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		_check(false, "save manager available for version refusal")
		return
	_check(not bool(save_manager.call("load_from_dict", {"save_version": 999})), "future save version is refused")
	_check(String(save_manager.call("get_last_error")) == "save_version_unsupported", "refusal reports the reason")
	var before: Dictionary = save_manager.call("save_to_dict")
	for malformed: Dictionary in [{"save_version": 4, "systems": []}, {"save_version": 4, "systems": {"nav": []}}, {"save_version": 4, "clock": {"sim_seconds": "bad"}}, {"save_version": 4, "meta": {"day": []}}]:
		_check(not bool(save_manager.call("load_from_dict", malformed)), "malformed save refused before state mutation")
		_check(String(save_manager.call("get_last_error")) == "invalid_save_data", "malformed save reports data error")
	var after: Dictionary = save_manager.call("save_to_dict")
	_check(before["clock"] == after["clock"] and before["systems"] == after["systems"], "malformed input preserves current watch")


func _test_slot_round_trip() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		_check(false, "save manager available for slot round trip")
		return
	save_manager.call("delete_save", 3)
	_check(bool(save_manager.call("save_to_slot", 3)), "save writes a slot file")
	_check(bool(save_manager.call("has_save", 3)), "slot file is detectable")
	var sim_clock: Node = _find_root_child(&"SimClock")
	sim_clock.call("fast_forward", 1.0)
	_check(bool(save_manager.call("load_from_slot", 3)), "slot loads back")
	_check(absf(float(sim_clock.call("get_total_hours")) - 3.0) < 0.001, "slot restores the clock")
	_check(bool(save_manager.call("delete_save", 3)), "slot deletes")
	_check(not bool(save_manager.call("has_save", 3)), "deleted slot is gone")
	save_manager.call("delete_save", 2)
	_check(not bool(save_manager.call("load_from_slot", 2)), "missing slot fails cleanly")
	_check(String(save_manager.call("get_last_error")) == "file_not_found", "missing slot reports the reason")


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_save_load")
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
