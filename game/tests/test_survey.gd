extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	await process_frame
	root.get_node("SimClock").call("set_paused", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var sector: SectorSystem = main.get_node("Systems/SectorSystem")
	var streamer: FieldStreamer = main.get_node("FieldStreamer")
	var nav: NavSystem = main.get_node("Systems/NavSystem")
	var salvage: SalvageSystem = main.get_node("Systems/SalvageSystem")
	var cargo: CargoSystem = main.get_node("Systems/CargoSystem")
	var player: Node = get_first_node_in_group(&"player")
	var original_seed: int = sector.field_seed
	var target: Dictionary = {}
	for hour: int in 168:
		sector.sim_tick(1.0)
		for contact: Dictionary in sector.get_contacts():
			if String(contact["kind"]) == "asteroid":
				target = contact
				break
		if not target.is_empty():
			break
	_check(not target.is_empty(), "seeded field provides an investigable asteroid")
	if target.is_empty():
		main.free()
		_finish()
		return
	var object_id: String = String(target["id"])
	sector.begin_approach(object_id)
	sector.sim_tick(1.0)
	streamer.sync_now()
	_check(not sector.record_survey(object_id), "recording refuses without the physical scanner")
	var bus: Node = root.get_node("EventBus")
	bus.call("emit_event", &"scanner_ping", {"id": object_id, "distance_m": 30.0})
	_check(sector.get_survey_records().is_empty(), "a synthetic ping without carried scanner records nothing")
	var scanner: Carriable = _tool(main, &"scanner")
	_check(scanner != null and bool(player.call("take_carriable", scanner)), "actual field scanner enters the carry slot")
	var action: InputEventAction = InputEventAction.new()
	action.action = &"primary"
	action.pressed = true
	player.call("_unhandled_input", action)
	var records: Array[Dictionary] = sector.get_survey_records()
	_check(records.size() == 1, "physical primary scanner action records one contact")
	if records.is_empty():
		main.free()
		_finish()
		return
	var record_id: String = str(original_seed) + ":" + object_id
	var record: Dictionary = records[0]
	_check(record["record_id"] == record_id and record["field_seed"] is String, "notebook identity namespaces actual contact by exact seed text")
	_check(record["confidence"] == "contact" and record["resource"] == "" and record["observed_remaining_units"] == -1.0, "contact ping exposes no unseen composition or stock")
	_check(not sector.record_survey("unseen"), "unknown contacts cannot be invented by the notebook API")
	var console: ApproachConsole = main.find_child("ContactConsole", true, false) as ApproachConsole
	_check(console != null and console.programs.has(&"survey"), "physical SENSOR CONTACTS station includes the notebook")
	console.interact(player)
	_check(console.set_program(&"survey") and console.select_action(StringName(record_id)), "physical terminal browses the recorded opportunity")
	var lines: String = "\n".join(console.build_readout())
	_check(lines.contains("COMPOSITION UNCONFIRMED") and lines.contains("APPROACH") and lines.contains("HOLD ROOM") and lines.contains("SUIT O2"), "reading combines uncertainty with actual preparation budgets")
	var initial_fuel: float = nav.fuel_mass_kg
	_check(console.select_action(StringName("approach_record:" + record_id)), "recorded live opportunity can command existing paid approach")
	_check(nav.fuel_mass_kg == initial_fuel - nav.approach_fuel_cost_kg, "notebook approach debits actual xenon exactly once")
	console.close()
	var canister: SampleCanister = _tool(main, &"sample_canister") as SampleCanister
	_check(canister != null and bool(player.call("take_carriable", canister)), "sampling uses the actual physical canister")
	player.call("equip_suit_cutter")
	var object: SpaceObject = streamer.get_object_node(object_id) as SpaceObject
	_check(object != null, "surveyed target is the streamed interactable")
	var before: float = sector.get_remaining_yield(object_id)
	object.interact(player)
	record = _record(sector, record_id)
	_check(canister.get_load_units() > 0.0 and record["confidence"] == "sampled" and record["resource"] == String(target["resource"]), "real sampling confirms observed composition")
	_check(record["sampled_units"] == canister.get_load_units() and record["observed_remaining_units"] == before - canister.get_load_units(), "sample evidence matches actual removed units and finite remainder")
	var after_sample: Dictionary = sector.save_state()
	object.interact(player)
	_check(sector.save_state() == after_sample, "a full canister grants no repeated sample or notebook evidence")
	var unit_id: String = salvage.register_unit("diagnosis_fixture", original_seed)
	_check(salvage.isolate_unit(unit_id) and salvage.release_unit(unit_id, &"wrench", Vector3.ZERO) and salvage.take_unit(unit_id) and salvage.stow_unit(unit_id), "equipment evidence starts from actual recovered ownership")
	_check(salvage.diagnosis_unit(unit_id, &"multimeter"), "equipment inspection uses existing real diagnosis path")
	var equipment_record: Dictionary = _record(sector, str(original_seed) + ":diagnosis_fixture")
	_check(equipment_record["confidence"] == "diagnosed" and equipment_record["equipment_id"] == String(salvage.definition.machine.machine_id), "diagnosis adds only the inspected equipment")
	var survey_at_save: Array[Dictionary] = sector.get_survey_records()
	var origin_state: Dictionary = sector.save_state()
	nav._arrive(nav.get_destination(&"arden_ii"))
	_check(sector.get_survey_records() == survey_at_save, "arrival archives existing knowledge without erasing it")
	console.interact(player)
	console.set_program(&"survey")
	console.select_action(StringName(record_id))
	lines = "\n".join(console.build_readout())
	_check(lines.contains("ARCHIVED FIELD") and lines.contains("NO CURRENT RANGE READING") and not lines.contains("HOLD ROOM"), "archived field exposes no live unseen opportunity budget")
	_check(not console.select_action(StringName("approach_record:" + record_id)), "archived record cannot burn fuel toward another field")
	console.close()
	sector._on_destination_arrived(&"origin", &"star", original_seed, &"", 0.0, {})
	_check(sector.get_survey_records() == survey_at_save and sector.save_state()["mined_fields"] == origin_state["mined_fields"], "revisit preserves knowledge and measured field depletion")
	var manager: Node = root.get_node("SaveManager")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(manager.call("save_to_dict")))
	var stock: Dictionary = cargo.get_materials()
	_check(bool(manager.call("load_from_dict", saved)) and bool(manager.call("load_from_dict", saved)), "whole-scene JSON loads retain notebook evidence repeatedly")
	_check(JSON.stringify(sector.get_survey_records()) == JSON.stringify(survey_at_save) and cargo.get_materials() == stock, "restoring knowledge generates no resources")
	_test_malformed(sector)
	var legacy: Dictionary = sector.save_state()
	legacy["state_version"] = 2
	legacy.erase("survey_records")
	sector.load_state(legacy)
	_check(sector.get_survey_records().is_empty(), "legacy field restore explicitly clears newer notebook state")
	main.free()
	_finish()


func _test_malformed(sector: SectorSystem) -> void:
	var saved: Dictionary = sector.save_state()
	var key: String = String((saved["survey_records"] as Dictionary).keys()[0])
	for invalid: Dictionary in [
		{"field_seed": "001"}, {"record_id": "wrong"}, {"distance_m": -1.0},
		{"observed_hours": NAN}, {"resource": "unknown"}, {"sampled_units": -1.0},
		{"observed_remaining_units": -2.0}, {"observed_remaining_units": -0.5}, {"equipment_condition": -0.5}, {"equipment_condition": 2.0}, {"kind": "invented"},
		{"confidence": "invented"}, {"invented_hazard": "unsupported"},
	]:
		var malformed: Dictionary = saved.duplicate(true)
		(malformed["survey_records"][key] as Dictionary).merge(invalid, true)
		sector.load_state(malformed)
		_check(sector.save_state() == saved, "malformed notebook refuses before altering field or claims")
	var missing: Dictionary = saved.duplicate(true)
	(missing["survey_records"][key] as Dictionary).erase("sampled_units")
	sector.load_state(missing)
	_check(sector.save_state() == saved, "omitted evidence fields are rejected atomically")
	missing = saved.duplicate(true)
	missing.erase("survey_records")
	sector.load_state(missing)
	_check(sector.save_state() == saved, "current field state cannot omit its notebook owner")


func _record(sector: SectorSystem, record_id: String) -> Dictionary:
	for record: Dictionary in sector.get_survey_records():
		if String(record["record_id"]) == record_id:
			return record
	return {}


func _tool(main: Node, item_id: StringName) -> Carriable:
	for node: Node in main.find_children("*", "Carriable", true, false):
		var item: Carriable = node as Carriable
		if item.item_id == item_id:
			return item
	return null


func _check(ok: bool, description: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_survey")
		quit(0)
	else:
		quit(1)
