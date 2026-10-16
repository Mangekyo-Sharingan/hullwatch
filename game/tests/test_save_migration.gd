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
	_test_v5_migration()
	_test_fresh_v3_shape()
	_test_v3_round_trip()
	_test_missing_meta_tolerance()
	_test_missing_computer_history()
	_test_version_refusal()
	_test_v7_survival_migration()
	_test_v9_survey_migration()
	_test_v10_text_orientation_migration()

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
	_check(float((v2["meta"] as Dictionary).get("play_hours", 0.0)) == 12.5, "v2 meta is preserved")
	_check(int(((v2["systems"] as Dictionary)["nav"] as Dictionary).get("current_leg", 0)) == 1, "v2 system state is preserved")


func _test_v5_migration() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	var v5: Dictionary = {
		"save_version": 5,
		"systems": {"nav": {"state_version": 3, "current_destination_id": "arden_ii", "visited_destinations": {"arden_ii": true}}},
		"interactables": {},
	}
	_check(bool(save_manager.call("load_from_dict", v5)), "v5 dict loads through migration")
	var nav: Dictionary = (v5["systems"] as Dictionary)["nav"]
	_check(int(nav.get("state_version", 0)) == 4, "migrated nav state advances to v4")
	_check(int(nav.get("arrival_ordinal", -1)) == 0, "migrated nav starts with no generated arrivals")
	_check((nav.get("planet_discoveries", []) as Array).is_empty(), "migrated nav starts with no generated routes")
	_check(String(nav.get("current_destination_id", "")) == "arden_ii", "v5 destination remains preserved")


func _test_fresh_v3_shape() -> void:
	var save_manager: Node = _find_root_child(&"SaveManager")
	if save_manager == null:
		return
	var data: Dictionary = save_manager.call("save_to_dict")
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


func _test_v7_survival_migration() -> void:
	var manager: Node = _find_root_child(&"SaveManager")
	var sector: SectorSystem = SectorSystem.new()
	root.add_child(sector)
	var legacy: Dictionary = {
		"save_version": 7,
		"clock": {"sim_seconds": 18000.0},
		"systems": {
			"sector": {"state_version": 1, "field_seed": 73019, "mined": {"exhausted": 0.0, "partial": 3.25}},
			"modules": {"state_version": 3},
		},
		"interactables": {},
	}
	_check(bool(manager.call("load_from_dict", legacy)), "survival migration: v7 slot loads")
	_check(int(legacy["systems"]["sector"]["state_version"]) == 3, "survival migration: sector survey shape")
	_check(legacy["systems"]["sector"]["mined_fields"] == {"73019": {"exhausted": 0.0, "partial": 3.25}} and not legacy["systems"]["sector"].has("mined"), "survival migration: legacy depletion stays scoped to its field with zero intact")
	_check(legacy["systems"]["modules"]["ration_hours"] == 0.0 and int(legacy["systems"]["modules"]["state_version"]) == 4, "survival migration: legacy production has explicit zero remainder")
	_check(sector.get_remaining_yield("exhausted") == 0.0 and is_equal_approx(sector.get_remaining_yield("partial"), 3.25), "survival migration: actual simulator retains remaining stock")
	var saved: Dictionary = manager.call("save_to_dict")
	_check(bool(manager.call("load_from_dict", JSON.parse_string(JSON.stringify(saved)))), "survival migration: new shape reloads without a second migration")
	var before: Dictionary = sector.save_state()
	var clock_before: Dictionary = _sim_clock().call("save_state")
	var invalid_fields: Array = [[], {"bad_seed": {}}, {"73019": []}, {"73019": {"partial": -1.0}}, {"73019": {"partial": NAN}}, {"73019": {"partial": "3"}}]
	for fields: Variant in invalid_fields:
		var invalid: Dictionary = saved.duplicate(true)
		invalid["clock"] = {"sim_seconds": 999.0}
		invalid["systems"]["sector"]["mined_fields"] = fields
		_check(not bool(manager.call("load_from_dict", invalid)) and String(manager.call("get_last_error")) == "invalid_save_data", "survival migration: malformed depletion refuses before restore")
		_check(sector.save_state() == before and _sim_clock().call("save_state") == clock_before, "survival migration: refused payload preserves sector and clock")
	for remainder: Variant in [-1.0, INF, "half"]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid["systems"]["modules"] = {"ration_hours": remainder}
		_check(not bool(manager.call("load_from_dict", invalid)) and sector.save_state() == before and _sim_clock().call("save_state") == clock_before, "survival migration: invalid production remainder changes no state")
	sector.free()


func _test_v9_survey_migration() -> void:
	var sector: SectorSystem = SectorSystem.new()
	root.add_child(sector)
	var manager: Node = _find_root_child(&"SaveManager")
	var legacy: Dictionary = {"save_version": 9, "clock": {"sim_seconds": 7200.0}, "systems": {"sector": {"system_id": "sector", "state_version": 2, "field_seed": "73019", "mined_fields": {"73019": {"partial": 3.25, "exhausted": 0.0}}}}, "interactables": {}}
	_check(bool(manager.call("load_from_dict", legacy)), "survey migration: v9 loads")
	_check(legacy["systems"]["sector"]["survey_records"] == {}, "survey migration: old knowledge starts empty without fabricated evidence")
	_check(is_equal_approx(sector.get_remaining_yield("partial"), 3.25) and sector.get_remaining_yield("exhausted") == 0.0, "survey migration: field depletion is preserved")
	var saved: Dictionary = manager.call("save_to_dict")
	_check(bool(manager.call("load_from_dict", JSON.parse_string(JSON.stringify(saved)))), "survey migration: current envelope repeats without loss")
	sector.free()


func _test_v10_text_orientation_migration() -> void:
	var manager: Node = _find_root_child(&"SaveManager")
	var legacy: Dictionary = {
		"save_version": 10,
		"clock": {"sim_seconds": 18000.0},
		"systems": {
			"voice_guide": {"current_step_index": 2, "is_active": true, "is_completed": false, "completed_steps": ["status_check"]},
			"stores": {"inventory": {"gasket": 2}},
		},
		"interactables": {
			"/root/Main/Systems/VoiceGuideSystem": {"current_step_index": 2, "is_active": true},
			"/root/Main/WorldLayout/Scrubber": {"stage": 1},
		},
	}
	_check(bool(manager.call("load_from_dict", legacy)), "voiced watch migrates to text-only orientation")
	_check(not legacy["systems"].has("voice_guide") and not legacy["interactables"].has("/root/Main/Systems/VoiceGuideSystem"), "retired guide state is discarded from both save collections")
	_check(legacy["systems"]["stores"]["inventory"]["gasket"] == 2 and legacy["interactables"]["/root/Main/WorldLayout/Scrubber"]["stage"] == 1, "orientation migration preserves supplies and in-progress maintenance")
	_check(is_equal_approx(float(_sim_clock().call("get_total_hours")), 5.0), "orientation migration preserves watch time")
	_check(bool(manager.call("load_from_dict", legacy)), "migrated watch loads again without retired guide")


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
