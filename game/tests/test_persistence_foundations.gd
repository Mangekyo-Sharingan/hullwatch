extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var clock: Node = root.get_node("SimClock")
	clock.call("set_paused", true)
	var manager: Node = root.get_node("SaveManager")
	var cargo: CargoSystem = main.get_node("Systems/CargoSystem") as CargoSystem
	var fabricator: FabricatorSystem = main.get_node("Systems/FabricatorSystem") as FabricatorSystem
	cargo.add_material(&"metal", 10.0)
	_check(fabricator.start(&"gasket") == &"", "paid fabrication starts")
	var baseline: Dictionary = manager.call("save_to_dict")
	var invalids: Array[Dictionary] = []
	for inventory: Variant in [[], {"water_charge": -1}, {"food_ration": 0.5}, {"sealant_charge": "2"}]:
		var bad: Dictionary = baseline.duplicate(true)
		bad["systems"]["stores"]["inventory"] = inventory
		invalids.append(bad)
	for stock: Variant in [{"unknown": 1.0}, {"metal": NAN}, {"metal": -1.0}, []]:
		var bad: Dictionary = baseline.duplicate(true)
		bad["systems"]["cargo"]["materials"] = stock
		invalids.append(bad)
	for terms: Variant in [[], {}, {"recipe_id": "gasket", "output_count": -1}]:
		var bad: Dictionary = baseline.duplicate(true)
		bad["systems"]["fabricator"]["job_terms"] = terms
		invalids.append(bad)
	var bad_charge: Dictionary = baseline.duplicate(true)
	bad_charge["systems"]["stores"]["cartridge_charges"] = {"cartridge": 2}
	invalids.append(bad_charge)
	var bad_time: Dictionary = baseline.duplicate(true)
	bad_time["clock"]["sim_seconds"] = -1.0
	invalids.append(bad_time)
	var bad_air: Dictionary = baseline.duplicate(true)
	bad_air["systems"]["atmosphere"]["compartments"]["main"]["n_o2"] = "invalid"
	invalids.append(bad_air)
	var bad_suit: Dictionary = baseline.duplicate(true)
	bad_suit["systems"]["airlock"]["suit_stored"] = true
	bad_suit["systems"]["airlock"]["suit_worn"] = true
	invalids.append(bad_suit)
	var survey_record: Dictionary = {"record_id": "73019:fixture", "field_seed": "73019", "object_id": "fixture", "kind": "asteroid", "observed_hours": 1.0, "distance_m": 30.0, "confidence": "contact", "resource": "", "sampled_units": 0.0, "observed_remaining_units": -1.0, "equipment_id": "", "equipment_condition": -1.0}
	invalids.append(_malformed(baseline, ["systems", "sector", "survey_records"], []))
	var missing_notebook: Dictionary = baseline.duplicate(true)
	missing_notebook["systems"]["sector"].erase("survey_records")
	invalids.append(missing_notebook)
	for field: String in survey_record:
		var missing: Dictionary = survey_record.duplicate(true)
		missing.erase(field)
		invalids.append(_malformed(baseline, ["systems", "sector", "survey_records"], {"73019:fixture": missing}))
	for mutation: Dictionary in [{"field_seed": 73019}, {"record_id": "different"}, {"kind": "unknown"}, {"confidence": "omniscient"}, {"observed_hours": -1.0}, {"distance_m": "30"}, {"resource": "unknown"}, {"sampled_units": -1.0}, {"observed_remaining_units": -2.0}, {"equipment_condition": 1.1}]:
		var record: Dictionary = survey_record.duplicate(true)
		record.merge(mutation, true)
		invalids.append(_malformed(baseline, ["systems", "sector", "survey_records"], {"73019:fixture": record}))

	invalids.append(_malformed(baseline, ["clock", "tick_index"], {}))
	invalids.append(_malformed(baseline, ["meta", "destination_id"], []))
	invalids.append(_malformed(baseline, ["systems", "nav", "propulsion", "wear"], [5]))
	invalids.append(_malformed(baseline, ["systems", "nav", "propulsion", "wear"], [{"component_id": "port_grid", "condition": {}}]))
	invalids.append(_malformed(baseline, ["systems", "water", "wear"], [{"component_id": "water_pump", "hours_operated": []}]))
	invalids.append(_malformed(baseline, ["systems", "nav", "propulsion", "service"], {"port": 5}))
	invalids.append(_malformed(baseline, ["systems", "computer", "entries"], [{"text": {}}]))
	invalids.append(_malformed(baseline, ["systems", "hull", "compartments", "module_utility"], {"punctures": [{}]}))
	invalids.append(_malformed(baseline, ["systems", "thermal", "compartments", "module_utility"], {"temperature_c": []}))
	var pod: Dictionary = baseline.duplicate(true)
	pod["systems"]["modules"]["installed"] = {"hp_quarters": "utility_pod"}
	pod["systems"]["modules"]["module_paid_costs"] = {"hp_quarters": {"metal": 8.0, "ore": 4.0}}
	invalids.append(_malformed(pod, ["systems", "atmosphere", "compartments", "module_utility"], {"n_o2": {}}))
	invalids.append(_malformed(pod, ["systems", "modules", "module_paid_costs"], {}))
	invalids.append(_malformed(pod, ["systems", "modules", "module_paid_costs"], {"hp_quarters": {}, "orphan": {}}))
	invalids.append(_malformed(baseline, ["systems", "modules", "installed"], {"wrong_port": "utility_pod"}))
	invalids.append(_malformed(baseline, ["systems", "modules", "jobs"], {"hp_quarters": {"module_id": [], "remaining_hours": 1.0, "total_hours": 2.0, "paid_cost": {}}}))
	invalids.append(_malformed(baseline, ["systems", "modules", "jobs"], {"wrong_port": {"module_id": "utility_pod", "remaining_hours": 1.0, "total_hours": 2.0, "paid_cost": {}}}))
	invalids.append(_malformed(baseline, ["systems", "modules", "machine_jobs"], {"hp_quarters:0": {"machine_id": "work_bench", "remaining_hours": 1.0, "total_hours": 2.0, "paid_cost": {}}}))
	invalids.append(_malformed(baseline, ["systems", "modules", "machines"], {"hp_quarters:0": "work_bench"}))
	var recovered: Dictionary = {"unit_id": "fixture", "machine_id": "battery_cabinet", "object_id": "fixture_contact", "sector_seed": "73019", "condition": 1.0, "diagnosed": true, "isolated": true, "location": "fitted", "socket_id": "hp_quarters:0", "position": {"x": 0.0, "y": 0.0, "z": 0.0}}
	for field: String in ["machine_id", "diagnosed", "sector_seed", "condition", "socket_id"]:
		var unit: Dictionary = recovered.duplicate(true)
		match field:
			"machine_id": unit[field] = "unknown"
			"diagnosed": unit[field] = false
			"sector_seed": unit[field] = {}
			"condition": unit[field] = 0.35
			"socket_id": unit[field] = []
		invalids.append(_malformed(pod, ["systems", "salvage", "units"], {"fixture": unit}))
	var carried_one: Dictionary = recovered.duplicate(true)
	carried_one["location"] = "carried"
	carried_one["socket_id"] = ""
	var carried_two: Dictionary = carried_one.duplicate(true)
	carried_two["unit_id"] = "other"
	invalids.append(_malformed(baseline, ["systems", "salvage", "units"], {"fixture": carried_one, "other": carried_two}))

	for bad: Dictionary in invalids:
		if float(bad["clock"].get("sim_seconds", 0.0)) >= 0.0:
			bad["clock"]["sim_seconds"] = 9999.0
		_check(not bool(manager.call("load_from_dict", bad)), "nested invalid ownership/resource payload refused")
		var after: Dictionary = manager.call("save_to_dict")
		_check(after["systems"] == baseline["systems"] and after["clock"] == baseline["clock"], "refusal preserves live resources, paid jobs and clock")
	var json_state: Dictionary = JSON.parse_string(JSON.stringify(baseline))
	_check(bool(manager.call("load_from_dict", json_state)), "valid paid job JSON restores")
	_check(bool(manager.call("load_from_dict", json_state)), "repeat restore remains valid")
	var repeated: Dictionary = manager.call("save_to_dict")
	_check(JSON.parse_string(JSON.stringify(repeated["systems"]["fabricator"])) == json_state["systems"]["fabricator"], "repeat restore preserves original fabrication terms")
	var paid_unknown: Dictionary = _malformed(json_state, ["systems", "modules", "jobs"], {"hp_quarters": {"module_id": "removed_content", "remaining_hours": 1.0, "total_hours": 2.0, "paid_cost": {"metal": 4.0}}})
	_check(bool(manager.call("load_from_dict", paid_unknown)), "missing-content paid job remains loadable for refund")
	var modules: ModuleSystem = main.get_node("Systems/ModuleSystem") as ModuleSystem
	_check(modules.cancel_build(&"hp_quarters"), "missing-content paid job refunds through owner")
	_check(bool(manager.call("load_from_dict", json_state)), "restore baseline after paid entitlement scenario")
	var adjacent_legacy: Dictionary = json_state.duplicate(true)
	adjacent_legacy["systems"]["modules"]["installed"] = {"hp_quarters": "utility_pod", "hp_life_support": "workshop"}
	adjacent_legacy["systems"]["modules"]["module_paid_costs"] = {
		"hp_quarters": modules.get_module(&"utility_pod").cost.duplicate(),
		"hp_life_support": modules.get_module(&"workshop").cost.duplicate(),
	}
	_check(bool(manager.call("load_from_dict", adjacent_legacy)), "legacy adjacent installed pods remain loadable")
	var adjacent_saved: Dictionary = JSON.parse_string(JSON.stringify(manager.call("save_to_dict")))
	_check(bool(manager.call("load_from_dict", adjacent_saved)), "current save preserves a legacy adjacent pod pair")
	_check(modules.get_installed_at(&"hp_quarters") == &"utility_pod" and modules.get_installed_at(&"hp_life_support") == &"workshop", "restore retains both legacy pods and their paid terms")
	_check(bool(manager.call("load_from_dict", json_state)), "restore baseline after legacy pair scenario")
	var legacy: Dictionary = json_state.duplicate(true)
	legacy["save_version"] = 7
	legacy["systems"]["fabricator"] = {"system_id": "fabricator", "state_version": 1, "job_recipe_id": "gasket", "job_remaining_hours": 0.5}
	legacy["systems"]["sector"] = {"system_id": "sector", "state_version": 1, "field_seed": 73019, "mined": {"exhausted": 0.0, "partial": 3.25}}
	main.free()
	await process_frame
	await physics_frame
	DirAccess.make_dir_recursive_absolute("user://saves")
	var file: FileAccess = FileAccess.open("user://saves/slot_3.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var summary: Dictionary = manager.call("get_slot_summary", 3)
	_check(bool(summary.get("valid", false)), "menu recognizes valid legacy mid-job slot without live simulators")
	for invalid: Dictionary in [
		{"state_version": [], "job_recipe_id": "gasket"},
		{"state_version": 1, "job_recipe_id": {}},
	]:
		var malformed: Dictionary = legacy.duplicate(true)
		malformed["systems"]["fabricator"] = invalid
		file = FileAccess.open("user://saves/slot_3.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(malformed))
		file.close()
		_check(not bool((manager.call("get_slot_summary", 3) as Dictionary).get("valid", true)), "menu rejects malformed standalone job structure without casting errors")
	DirAccess.remove_absolute("user://saves/slot_3.json")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	clock.call("set_paused", true)
	_check(bool(manager.call("load_from_dict", legacy)), "fresh main restores numeric-seed v7 and legacy paid job")
	_check(int(legacy["save_version"]) == 10 and legacy["systems"]["sector"]["field_seed"] == "73019", "legacy migration keeps explicit field and updates original dictionary")
	var migrated: Dictionary = manager.call("save_to_dict")
	_check(migrated["systems"]["sector"]["mined_fields"] == {"73019": {"exhausted": 0.0, "partial": 3.25}}, "legacy fresh-scene restore preserves depletion including zero")
	_check(migrated["systems"]["fabricator"]["job_terms"]["output_count"] == 2 and migrated["systems"]["fabricator"]["job_remaining_hours"] == 0.5, "legacy job infers paid terms once without consuming again")
	_check(bool(manager.call("load_from_dict", JSON.parse_string(JSON.stringify(migrated)))), "migrated current snapshot reloads coherently")
	main.free()
	await process_frame
	if _failures == 0:
		print("PASS: test_persistence_foundations")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(passed: bool, label: String) -> void:
	if passed:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _malformed(baseline: Dictionary, path: Array[String], value: Variant) -> Dictionary:
	var bad: Dictionary = baseline.duplicate(true)
	var target: Dictionary = bad
	for index: int in range(path.size() - 1):
		if not target.has(path[index]):
			target[path[index]] = {}
		target = target[path[index]]
	target[path[-1]] = value
	return bad
