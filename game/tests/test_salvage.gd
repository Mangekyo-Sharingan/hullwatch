extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
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
	_check(int(carried_save["save_version"]) == 5, "save version includes salvage")
	_check(bool(manager.call("load_from_dict", carried_save)), "carried state loads")
	streamer.sync_now()
	_check(String(salvage.get_unit(unit_id)["location"]) == "world", "reload releases the original case without duplication")
	item = streamer.get_node_or_null(NodePath("RecoveryCase_" + unit_id.replace(":", "_"))) as SalvageCase
	item.interact(player)
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
	_check(modules.remove_machine(&"hp_quarters:0"), "removal returns same instance")
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
	_finish()


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
