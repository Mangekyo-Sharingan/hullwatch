extends SceneTree

var _failures: int = 0
var _last_refusal: StringName = &""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.get_node("EventBus").connect(&"sim_event", func(event_name: StringName, payload: Dictionary) -> void:
		if event_name == &"procedure_error":
			_last_refusal = StringName(payload.get("reason", &""))
	)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var clock: Node = root.get_node("SimClock")
	clock.call("set_paused", true)
	var salvage: SalvageSystem = main.get_node("Systems/SalvageSystem")
	var modules: ModuleSystem = main.get_node("Systems/ModuleSystem")
	var cargo: CargoSystem = main.get_node("Systems/CargoSystem")
	var power: PowerSystem = main.get_node("Systems/PowerSystem")
	var sector: SectorSystem = main.get_node("Systems/SectorSystem")
	var streamer: FieldStreamer = main.get_node("FieldStreamer")
	var player: Node3D = get_first_node_in_group(&"player") as Node3D
	cargo.add_material(&"metal", 100.0)
	cargo.add_material(&"ore", 10.0)
	_check(modules.start_build(&"utility_pod"), "pod construction starts")
	modules.sim_tick(100.0)
	_check(modules.get_installed_at(&"hp_quarters") == &"utility_pod", "real pod stands")
	var wreck: SalvageWreck = null
	for step: int in 20:
		streamer.sync_now()
		for entry: Dictionary in sector.get_active_objects():
			if StringName(entry["kind"]) == &"debris":
				wreck = streamer.get_object_node(String(entry["id"])) as SalvageWreck
				break
		if wreck != null:
			break
		sector.sim_tick(1.0)
	_check(wreck != null, "streamed debris presents a recovery wreck")
	if wreck == null:
		main.free()
		_finish()
		return
	var mount: SalvageMount = wreck.get_node("RecoveryMount") as SalvageMount
	var isolation: SalvageMount = wreck.get_node("IsolationControl") as SalvageMount
	var unit_id: String = mount.unit_id
	var wrench: Carriable = _tool(main, &"wrench")
	var meter: Carriable = _tool(main, &"multimeter")
	_check(wrench != null and meter != null, "authored tools available")
	player.call("take_carriable", wrench)
	mount.interact(player)
	_check(String(salvage.get_unit(unit_id)["location"]) == "mounted", "energized unit refuses release")
	isolation.interact(player)
	mount.interact(player)
	streamer.sync_now()
	_check(String(salvage.get_unit(unit_id)["location"]) == "world", "isolate then wrench releases unit")
	var item: SalvageCase = streamer.get_node_or_null(NodePath("RecoveryCase_" + unit_id.replace(":", "_"))) as SalvageCase
	_check(item != null, "physical case created")
	item.interact(player)
	_check(player.call("get_carried") == item, "physical case occupies normal carry slot")
	var manager: Node = root.get_node("SaveManager")
	var carried_save: Dictionary = manager.call("save_to_dict")
	_check(bool(manager.call("load_from_dict", carried_save)), "carried state loads")
	streamer.sync_now()
	_check(String(salvage.get_unit(unit_id)["location"]) == "carried", "reload preserves original carried ownership")
	_check(salvage.restore_carried_unit(player), "reload restores the original case to the existing carry slot")
	item = streamer.get_node_or_null(NodePath("RecoveryCase_" + unit_id.replace(":", "_"))) as SalvageCase
	if item == null:
		item = player.call("get_carried") as SalvageCase
	_check(salvage.restore_carried_unit(player) and player.call("get_carried") == item, "repeated carry restoration retains one same instance")
	var port: CargoPort = main.find_child("CargoPort", true, false) as CargoPort
	_check(port != null, "real cargo port available")
	var capacity: float = cargo.capacity_units
	cargo.capacity_units = cargo.get_used_units()
	port.interact(player)
	_check(player.call("get_carried") == item, "full hold refuses stow without losing case")
	cargo.capacity_units = capacity
	port.interact(player)
	_check(String(salvage.get_unit(unit_id)["location"]) == "stowed", "cargo port stows original unit")
	var held: float = cargo.get_used_units()
	_check(not salvage.repair_unit(unit_id, &"wrench"), "repair refuses before diagnosis")
	_check(not salvage.fit_unit(unit_id, &"hp_quarters:0"), "damaged unit cannot supply effect")
	var socket: MachineSocket = null
	for node: Node in main.find_children("*", "MachineSocket", true, false):
		if (node as MachineSocket).slot_id == &"hp_quarters:0":
			socket = node as MachineSocket
	_check(socket != null, "real socket spawned in pod")
	player.call("take_carriable", meter)
	_check(socket.select_action(StringName(MachineSocket.ACTION_DIAGNOSE_PREFIX + unit_id)), "socket diagnoses with real multimeter")
	player.call("take_carriable", wrench)
	var metal: float = cargo.get_units(&"metal")
	_check(socket.select_action(StringName(MachineSocket.ACTION_REPAIR_PREFIX + unit_id)), "socket repairs with wrench")
	_check(is_equal_approx(cargo.get_units(&"metal"), metal - salvage.definition.repair_units), "repair debits configured material once")
	_check(not salvage.repair_unit(unit_id, &"wrench"), "repeated repair refuses free mutation")
	var before: float = power.get_battery_capacity_wh()
	var charge: float = power.battery_charge_wh
	_check(socket.select_action(StringName(MachineSocket.ACTION_RECOVERED_FIT_PREFIX + unit_id)), "repaired unit fits real socket")
	_check(is_equal_approx(power.get_battery_capacity_wh(), before + salvage.definition.machine.effect_amount), "recovered battery adds actual capacity")
	_check(is_equal_approx(power.battery_charge_wh, charge), "fitting creates no stored energy")
	_check((modules.save_state()["machines"] as Dictionary).is_empty(), "module save does not clone salvage as built machinery")
	power.battery_charge_wh = before + salvage.definition.machine.effect_amount * 0.5
	var stored_charge: float = power.battery_charge_wh
	var fitted_save: Dictionary = manager.call("save_to_dict")
	_check(bool(manager.call("load_from_dict", fitted_save)), "fitted unit save restores")
	_check(is_equal_approx(power.get_battery_capacity_wh(), before + salvage.definition.machine.effect_amount), "fitted effect restored once")
	_check(not modules.fit_machine(&"battery_cabinet", &"hp_quarters:0"), "construction cannot overwrite recovered unit")
	cargo.capacity_units = cargo.get_used_units()
	_check(not modules.remove_machine(&"hp_quarters:0"), "full hold blocks removal")
	_check(not modules.uninstall(&"utility_pod"), "full hold blocks pod teardown without dropping unit")
	cargo.capacity_units = capacity
	var unit_before: Dictionary = salvage.get_unit(unit_id)
	_check(not salvage.remove_unit(&"hp_quarters:0"), "direct recovered removal refuses excess charge")
	_check(_last_refusal == &"battery_capacity_in_use", "recovered energy refusal reports battery capacity cause")
	_check(not salvage.release_pod(&"hp_quarters"), "direct pod release preflights excess charge")
	_check(_last_refusal == &"battery_capacity_in_use", "shared release reports battery capacity cause")
	_check(salvage.get_unit(unit_id) == unit_before and power.battery_charge_wh == stored_charge, "energy refusal preserves recovered identity, condition and charge")
	power.battery_charge_wh = charge
	_check(modules.remove_machine(&"hp_quarters:0"), "removal returns same instance")
	_check(power.battery_charge_wh == charge, "recovered removal preserves exact charge")
	_check(not salvage.remove_unit(&"hp_quarters:0"), "recovered removal cannot repeat")
	_check(is_equal_approx(power.get_battery_capacity_wh(), before), "removal reverses capacity once")
	_check(is_equal_approx(cargo.get_units(&"metal"), metal - salvage.definition.repair_units), "removal gives no new-machine refund")
	_check(salvage.register_unit(wreck.object_id, sector.field_seed) == unit_id, "same wreck identity remains consumed")
	_check(salvage.scrap_unit(unit_id), "dismantling grants defined salvage")
	_check(not salvage.scrap_unit(unit_id), "dismantling cannot repeat")
	_check(is_equal_approx(cargo.get_units(&"metal"), metal - salvage.definition.repair_units + salvage.definition.scrap_units), "scrap gives configured amount")
	_check(cargo.get_used_units() < held, "dismantled case frees equipment reservation")
	main.free()
	await process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check(bool(manager.call("load_from_dict", fitted_save)), "fresh scene restores fitted save")
	power = main.get_node("Systems/PowerSystem") as PowerSystem
	salvage = main.get_node("Systems/SalvageSystem") as SalvageSystem
	modules = main.get_node("Systems/ModuleSystem") as ModuleSystem
	cargo = main.get_node("Systems/CargoSystem") as CargoSystem
	streamer = main.get_node("FieldStreamer") as FieldStreamer
	sector = main.get_node("Systems/SectorSystem") as SectorSystem
	_check(is_equal_approx(power.battery_charge_wh, stored_charge), "fresh load restores recovered capacity before clamping stored energy")
	_check(salvage.get_unit_at(&"hp_quarters:0") == unit_id, "fresh load retains unique fitted instance")
	_check(not modules.remove_machine(&"hp_quarters:0") and power.battery_charge_wh == stored_charge, "fresh loaded energy still blocks unsafe removal")
	power.battery_charge_wh = charge
	_check(modules.remove_machine(&"hp_quarters:0"), "fresh unit can be removed")
	cargo.capacity_units = cargo.get_used_units() - 10.0
	var scrap_before: float = cargo.get_units(&"metal")
	_check(not salvage.scrap_unit(unit_id), "overfull hold refuses scrap without losing output")
	_check(String(salvage.get_unit(unit_id)["location"]) == "stowed" and cargo.get_units(&"metal") == scrap_before, "failed dismantle preserves original and materials")
	cargo.capacity_units = capacity
	streamer.sync_now()
	sector.call("_on_destination_arrived", &"kestrel_system", &"star", 158407, &"", 0.0, {})
	streamer.sync_now()
	for entry: Dictionary in sector.get_active_objects():
		var new_wreck: SalvageWreck = streamer.get_object_node(String(entry["id"])) as SalvageWreck
		if new_wreck != null:
			var new_mount: SalvageMount = new_wreck.get_node("RecoveryMount") as SalvageMount
			_check(int(salvage.get_unit(new_mount.unit_id)["sector_seed"]) == 158407, "arrival rebuilds wreck with current sector provenance")
	var old_save: Dictionary = fitted_save.duplicate(true)
	old_save["save_version"] = 4
	(old_save["systems"] as Dictionary).erase("salvage")
	_check(bool(manager.call("load_from_dict", old_save)), "v4 save migrates with empty salvage state")
	streamer.sync_now()
	for entry: Dictionary in sector.get_active_objects():
		var restored_wreck: SalvageWreck = streamer.get_object_node(String(entry["id"])) as SalvageWreck
		if restored_wreck != null:
			var restored_mount: SalvageMount = restored_wreck.get_node("RecoveryMount") as SalvageMount
			_check(not salvage.get_unit(restored_mount.unit_id).is_empty(), "older load reconciles existing mounted equipment")
	main.free()
	_test_atomic_pod_returns()
	_test_seed_and_carry_ownership()
	_finish()


func _test_seed_and_carry_ownership() -> void:
	var cargo: CargoSystem = CargoSystem.new()
	root.add_child(cargo)
	var salvage: SalvageSystem = SalvageSystem.new()
	salvage.definition = load("res://src/data/salvage/salvage_battery.tres") as SalvageDefinition
	root.add_child(salvage)
	var seed: int = 9223372036854775000
	var unit_id: String = salvage.register_unit("large_seed_case", seed)
	_check(salvage.isolate_unit(unit_id) and salvage.release_unit(unit_id, &"wrench", Vector3.ZERO), "seed: physical unit releases")
	_check(salvage.take_unit(unit_id), "seed: physical unit enters carried ownership")
	_check(cargo.get_used_units() == 0.0, "carry: equipment outside the hold reserves no hold space")
	var saved: Dictionary = salvage.save_state()
	_check(int(saved["state_version"]) == 2 and saved["units"][unit_id]["sector_seed"] is String, "seed: save serializes full-width provenance as text")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved))
	salvage.load_state(parsed)
	_check(int(salvage.get_unit(unit_id)["sector_seed"]) == seed, "seed: JSON preserves all 64-bit provenance digits")
	_check(String(salvage.get_unit(unit_id)["location"]) == "carried" and cargo.get_used_units() == 0.0, "carry: load preserves carried location without a hold reservation")
	_check(salvage.stow_unit(unit_id), "carry: explicit stow moves unit into the hold")
	_check(cargo.get_used_units() == salvage.definition.cargo_units, "carry: stowing reserves exactly configured equipment space")
	saved = salvage.save_state()
	salvage.load_state(saved)
	salvage.load_state(saved)
	_check(cargo.get_used_units() == salvage.definition.cargo_units, "carry: repeated stowed load rebuilds one reservation")
	salvage.free()
	cargo.free()


func _test_atomic_pod_returns() -> void:
	var cargo: CargoSystem = CargoSystem.new()
	cargo.capacity_units = 200.0
	root.add_child(cargo)
	cargo.add_material(&"metal", 90.0)
	cargo.add_material(&"ore", 30.0)
	var power: PowerSystem = PowerSystem.new()
	power.wear_components = [load("res://src/data/wear/battery_main.tres").duplicate(true) as WearComponent]
	root.add_child(power)
	_check(power.force_failure(&"battery_main", &"cell_fade"), "fixture uses actual worn battery capacity")
	var base_wh: float = power.get_battery_capacity_wh()
	var modules: ModuleSystem = ModuleSystem.new()
	modules.catalog = [load("res://src/data/modules/module_aux_battery.tres") as ShipModule]
	modules.machine_catalog = [load("res://src/data/machines/machine_cargo_rack.tres") as ShipMachine, load("res://src/data/machines/machine_battery_cabinet.tres") as ShipMachine]
	root.add_child(modules)
	var salvage: SalvageSystem = SalvageSystem.new()
	salvage.definition = load("res://src/data/salvage/salvage_battery.tres") as SalvageDefinition
	root.add_child(salvage)
	_check(modules.start_build(&"aux_battery"), "aggregate fixture builds battery pod with real cost")
	modules.sim_tick(15.0)
	var ids: Array[String] = []
	for index: int in 2:
		var unit_id: String = salvage.register_unit("aggregate_%d" % index, 123)
		ids.append(unit_id)
		_check(salvage.isolate_unit(unit_id) and salvage.release_unit(unit_id, &"wrench", Vector3.ZERO), "aggregate unit isolated and released")
		_check(salvage.take_unit(unit_id) and salvage.stow_unit(unit_id), "aggregate unit transported into hold")
		_check(salvage.diagnosis_unit(unit_id, &"multimeter") and salvage.repair_unit(unit_id, &"wrench"), "aggregate unit serviced with paid material")
		_check(salvage.fit_unit(unit_id, StringName("hp_engine_bay:%d" % index), &"wrench"), "aggregate unit fits same instance")
	_check(modules.fit_machine(&"cargo_rack", &"hp_engine_bay:2"), "aggregate pod adds built storage fitting")
	modules.sim_tick(4.0)
	var stored_charge: float = base_wh + 100.0
	power.battery_charge_wh = stored_charge
	var saved_units: Dictionary = salvage.save_state()
	var saved_modules: Dictionary = modules.save_state()
	var saved_cargo: Dictionary = cargo.get_materials()
	_check(not salvage.release_pod(&"hp_engine_bay"), "combined charge refuses release though either recovered unit alone fits")
	_check(_last_refusal == &"battery_capacity_in_use", "combined release reports battery capacity cause")
	_check(not modules.uninstall(&"aux_battery") and _last_refusal == &"battery_capacity_in_use", "whole compound pod propagates battery capacity cause")
	_check(salvage.save_state() == saved_units and modules.save_state() == saved_modules and cargo.get_materials() == saved_cargo and power.battery_charge_wh == stored_charge, "multi-unit charge refusal mutates nothing")
	power.battery_charge_wh = base_wh
	var roomy_capacity: float = cargo.capacity_units
	cargo.capacity_units = cargo.get_used_units()
	_check(not salvage.release_pod(&"hp_engine_bay"), "shared release includes pod refund, built costs, recovered reservations and final storage shrink")
	_check(_last_refusal == &"salvage_hold_full", "cargo refusal keeps cargo-specific feedback")
	_check(not modules.uninstall(&"aux_battery"), "whole pod uses same aggregate cargo preflight")
	_check(salvage.save_state() == saved_units and modules.save_state() == saved_modules and cargo.get_materials() == saved_cargo, "aggregate cargo refusal preserves every unit and fitting")
	cargo.capacity_units = roomy_capacity
	_check(modules.remove_machine(&"hp_engine_bay:2"), "built storage can be removed after freeing room")
	_check(modules.fit_machine(&"battery_cabinet", &"hp_engine_bay:2"), "aggregate pod starts paid fitting job")
	saved_modules = modules.save_state()
	saved_cargo = cargo.get_materials()
	cargo.capacity_units = cargo.get_used_units() + 31.0
	_check(not salvage.release_pod(&"hp_engine_bay"), "shared pod release also includes pending fitting refund")
	_check(modules.save_state() == saved_modules and salvage.save_state() == saved_units and cargo.get_materials() == saved_cargo, "pending refund refusal keeps job and both recovered units")
	cargo.capacity_units = roomy_capacity
	_check(modules.uninstall(&"aux_battery"), "aggregate retry returns pod, pending fitting and both units")
	_check(power.battery_charge_wh == base_wh and power.get_battery_capacity_wh() == base_wh, "aggregate teardown preserves worn charge exactly")
	for unit_id: String in ids:
		var prior: Dictionary = (saved_units["units"] as Dictionary)[unit_id]
		var returned: Dictionary = salvage.get_unit(unit_id)
		_check(returned["location"] == "stowed" and returned["condition"] == prior["condition"] and returned["diagnosed"] == prior["diagnosed"], "returned equipment retains identity and service state")
	_check(cargo.get_units(&"metal") == float(saved_cargo[&"metal"]) + 12.0 and cargo.get_units(&"ore") == float(saved_cargo[&"ore"]) + 8.0, "aggregate teardown refunds only exact paid built costs")
	_check(cargo.get_used_units() == float(saved_cargo[&"metal"]) + float(saved_cargo[&"ore"]) + 32.0, "both recovered units reserve cargo once alongside refunds")
	saved_cargo = cargo.get_materials()
	saved_units = salvage.save_state()
	_check(not modules.uninstall(&"aux_battery") and salvage.release_pod(&"hp_engine_bay"), "repeat teardown refuses and repeat release is empty")
	_check(cargo.get_materials() == saved_cargo and salvage.save_state() == saved_units, "repeat teardown cannot duplicate refunds or equipment")
	salvage.free()
	modules.free()
	power.free()
	cargo.free()


func _tool(main: Node, item_id: StringName) -> Carriable:
	for node: Node in main.find_children("*", "Carriable", true, false):
		var item: Carriable = node as Carriable
		if item.get_item_id() == item_id:
			return item
	return null


func _check(ok: bool, description: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_salvage")
		quit(0)
	else:
		quit(1)
