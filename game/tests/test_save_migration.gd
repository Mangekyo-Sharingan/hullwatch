## Save v1/v2 -> v3 migration test: prior formats keep loading without losing clock data.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var existing: Node = _find_root_child(&"SimClock")
	if existing != null:
		root.remove_child(existing)
		existing.free()
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_v1_migration()
	_test_v2_migration()
	_test_fresh_v3_shape()
	_test_v3_round_trip()
	_test_missing_meta_tolerance()
	_test_missing_computer_history()
	_test_version_refusal()

	_finish()


func _test_v1_migration() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	_check(save_manager != null, "save manager autoload present")
	if save_manager == null:
		return
	var v1: Dictionary = {
		"save_version": 1,
		"created_unix": 1234567890,
		"clock": {"sim_seconds": 7200.0, "tick_index": 1200, "last_hour": 2, "last_day": 1},
		"systems": {},
		"interactables": {},
	}
	_check(bool(save_manager.call("load_from_dict", v1)), "v1 dict loads through migration")
	_check(int(v1.get("save_version", 0)) == 5, "migrated v1 dict is version 5")
	_check(not v1.has("created_unix"), "old root created_unix key is removed")
	var meta: Dictionary = v1.get("meta", {})
	_check(absf(float(meta.get("play_hours", -1.0)) - 2.0) < 0.001, "migrated meta.play_hours is 2.0")
	_check(int(meta.get("created_unix", 0)) == 1234567890, "migrated meta.created_unix preserved")
	_check(absf(float(_sim_clock().call("get_total_hours")) - 2.0) < 0.001, "migrated v1 clock restored")


func _test_v2_migration() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	var v2: Dictionary = {
		"save_version": 2,
		"meta": {"created_unix": 7654321, "play_hours": 12.5},
		"clock": {"sim_seconds": 45000.0, "tick_index": 750, "last_hour": 12, "last_day": 1},
		"systems": {"nav": {"current_leg": 1}},
		"interactables": {},
	}
	_check(bool(save_manager.call("load_from_dict", v2)), "v2 dict loads through migration")
	_check(int(v2.get("save_version", 0)) == 5, "migrated v2 dict is version 5")
	_check(float((v2["meta"] as Dictionary).get("play_hours", 0.0)) == 12.5, "v2 meta is preserved")
	_check(int(((v2["systems"] as Dictionary)["nav"] as Dictionary).get("current_leg", 0)) == 1, "v2 system state is preserved")


func _test_fresh_v3_shape() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	var data: Dictionary = save_manager.call("save_to_dict")
	_check(int(data.get("save_version", 0)) == 5, "fresh save dict is version 5")
	_check(not data.has("created_unix"), "fresh save has no root created_unix")
	var meta: Dictionary = data.get("meta", {})
	_check(meta.has("created_unix"), "fresh meta carries created_unix")
	_check(meta.has("play_hours"), "fresh meta carries play_hours")
	_check(absf(float(meta.get("play_hours", -1.0)) - 12.5) < 0.001, "fresh meta.play_hours reflects the migrated clock")


func _test_v3_round_trip() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	var sim_clock: Node = _sim_clock()
	sim_clock.call("load_state", {"sim_seconds": 7200.0})
	var data: Dictionary = save_manager.call("save_to_dict")
	sim_clock.call("load_state", {"sim_seconds": 0.0})
	_check(bool(save_manager.call("load_from_dict", data)), "v3 dict loads")
	_check(absf(float(sim_clock.call("get_total_hours")) - 2.0) < 0.001, "v3 round trip restores the clock")


func _test_missing_meta_tolerance() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	var data: Dictionary = {
		"save_version": 2,
		"clock": {"sim_seconds": 3600.0},
		"systems": {},
		"interactables": {},
	}
	_check(bool(save_manager.call("load_from_dict", data)), "v2 dict without meta loads")
	_check(int(data.get("save_version", 0)) == 5, "v2 dict without meta migrates to version 5")
	_check(absf(float(_sim_clock().call("get_total_hours")) - 1.0) < 0.001, "v2 dict without meta restores the clock")


func _test_missing_computer_history() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	var computer := ComputerSystem.new()
	root.add_child(computer)
	computer.record("STALE HISTORY")
	var legacy: Dictionary = {"save_version": 3, "systems": {}, "interactables": {}}
	_check(bool(save_manager.call("load_from_dict", legacy)), "legacy save without a computer log loads")
	_check(computer.get_entries().is_empty(), "legacy load clears history absent from that save")
	computer.free()


func _test_version_refusal() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	_check(not bool(save_manager.call("load_from_dict", {"save_version": 999})), "future save version is refused")
	_check(String(save_manager.call("get_last_error")) == "save_version_unsupported", "refusal reports the reason")


func _sim_clock() -> Node:
	return _find_root_child(&"SimClock")


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_save_migration")
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
