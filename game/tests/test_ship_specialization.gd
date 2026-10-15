extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	await process_frame
	root.get_node("SimClock").call("set_paused", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var modules: ModuleSystem = main.get_node("Systems/ModuleSystem")
	var cargo: CargoSystem = main.get_node("Systems/CargoSystem")
	var power: PowerSystem = main.get_node("Systems/PowerSystem")
	var sector: SectorSystem = main.get_node("Systems/SectorSystem")
	var stores: Stores = main.get_node("Systems/Stores")
	var fabricator: FabricatorSystem = main.get_node("Systems/FabricatorSystem")
	var manager: Node = root.get_node("SaveManager")
	for key: Variant in power.generators:
		power.generators[key] = 2000.0
	cargo.add_material(&"metal", 60.0)
	cargo.add_material(&"ore", 20.0)
	cargo.add_material(&"ice", 5.0)
	_check(modules.start_build(&"utility_pod"), "one fixed-dock pod is paid from original materials")
	modules.sim_tick(12.0)
	_check(modules.is_installed(&"utility_pod"), "existing three-socket pod completes")
	var baseline_stock: Dictionary = cargo.get_materials()
	var initial_charge: float = power.battery_charge_wh
	var sockets: Array[StringName] = [&"hp_quarters:0", &"hp_quarters:1", &"hp_quarters:2"]
	var configurations: Array[Array] = [
		[&"survey_sensor", &"cargo_rack", &"battery_cabinet"],
		[&"work_bench", &"cargo_rack", &"cargo_rack"],
		[&"grow_rack", &"battery_cabinet", &"battery_cabinet"],
	]
	for index: int in configurations.size():
		for slot: int in sockets.size():
			var machine_id: StringName = configurations[index][slot]
			_check(modules.fit_machine(machine_id, sockets[slot]), "configuration pays to fit " + String(machine_id))
			modules.sim_tick(modules.get_machine(machine_id).build_hours)
		_check(power.battery_charge_wh == initial_charge, "commissioning capacity creates no stored energy")
		var effects: Dictionary = modules.get_effects()
		if index == 0:
			_check(sector.get_detection_range() == 1050.0 and cargo.get_capacity_units() == 145.0 and power.get_battery_capacity_wh() == 4900.0, "survey trades 20 W for contact reach, one rack and one battery")
			_check(effects["fitted_load_w"] == 20.0 and fabricator.job_hours_multiplier == 1.0, "survey has its own real draw and no fabrication bonus")
			_test_sensor(sector, modules, power)
		elif index == 1:
			_check(sector.get_detection_range() == 900.0 and cargo.get_capacity_units() == 170.0 and fabricator.job_hours_multiplier == 0.8, "salvage exchanges sensing for more hold and faster fabrication")
			_check(effects["fitted_load_w"] == 120.0 and power.get_battery_capacity_wh() == 4000.0, "salvage's bench costs power instead of adding battery capacity")
		else:
			_check(effects["active_rations_per_day"] == 2.0 and power.get_battery_capacity_wh() == 5800.0 and cargo.get_capacity_units() == 120.0, "endurance exchanges hold and sensing for food and two batteries")
			var food: int = stores.get_count(&"food_ration")
			modules.sim_tick(24.0)
			_check(stores.get_count(&"food_ration") == food + 2, "endurance produces actual stock")
			power.set_breaker(&"life_support", false)
			modules.sim_tick(24.0)
			_check(stores.get_count(&"food_ration") == food + 2 and modules.get_effects()["active_rations_per_day"] == 0.0, "endurance production stops without power")
			power.set_breaker(&"life_support", true)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(manager.call("save_to_dict")))
		var stock: Dictionary = cargo.get_materials()
		var food_at_save: int = stores.get_count(&"food_ration")
		var charge_at_save: float = power.battery_charge_wh
		var detection: float = sector.get_detection_range()
		_check(bool(manager.call("load_from_dict", saved)) and bool(manager.call("load_from_dict", saved)), "configuration reloads repeatedly through the actual SaveManager")
		_check(cargo.get_materials() == stock and stores.get_count(&"food_ration") == food_at_save and power.battery_charge_wh == charge_at_save, "repeated JSON restoration grants no stock or energy")
		_check(modules.get_effects() == effects and sector.get_detection_range() == detection, "saved equipment reconstructs the same capabilities once")
		var terminal: ComputerTerminal = ComputerTerminal.new()
		root.add_child(terminal)
		var readout: String = "\n".join(StatusProgram.new().build_readout(terminal))
		_check(readout.contains("SHIP CAPABILITIES") and readout.contains("CONTACT RANGE %.0f M" % detection) and readout.contains("GROWTH"), "physical STATUS reports the actual configuration")
		terminal.free()
		for socket: StringName in sockets:
			_check(modules.remove_machine(socket), "swapping removes real machinery with its full paid refund")
		_check(cargo.get_materials() == baseline_stock and power.battery_charge_wh == initial_charge, "swapping conserves the original materials and stored energy")
		_check(sector.get_detection_range() == 900.0, "removal clears sensing contribution")
	_check(modules.fit_machine(&"survey_sensor", sockets[0]), "sensor can enter a new paid fitting job")
	_check(sector.get_detection_range() == 900.0, "unfinished sensor grants no capability")
	_check(modules.cancel_machine_fit(sockets[0]) and cargo.get_materials() == baseline_stock, "cancelled sensor refunds its payment exactly")
	main.free()
	if _failures == 0:
		print("PASS: test_ship_specialization")
		quit(0)
	else:
		quit(1)


func _test_sensor(sector: SectorSystem, modules: ModuleSystem, power: PowerSystem) -> void:
	var saved_sector: Dictionary = sector.save_state()
	sector._active = [{"id": "survey_fixture", "kind": &"asteroid", "position": sector.get_ship_position() + Vector3.RIGHT * 950.0, "radius_m": 2.0, "seed": 1, "resource": &"ore", "yield_units": 1.0}]
	_check(sector.get_contacts().size() == 1 and String(sector.get_nearest_contact().get("id", "")) == "survey_fixture", "sensor reaches a real contact beyond the original shared range")
	_check(sector.get_contacts(900.0).is_empty(), "explicit distance filters retain their original meaning")
	power.set_breaker(&"fabricator", false)
	_check(sector.get_detection_range() == 900.0 and sector.get_contacts().is_empty(), "breaker off immediately removes the detection benefit")
	power.set_breaker(&"fabricator", true)
	_check(sector.get_detection_range() == 1050.0, "breaker restoration immediately restores fitted sensing")
	var saved_power: Dictionary = power.save_state()
	for key: Variant in power.generators:
		power.generators[key] = 0.0
	power.battery_max_discharge_w = 0.0
	power.sim_tick(0.001)
	_check(power.is_circuit_shed(&"fabricator") and sector.get_detection_range() == 900.0, "real load shedding removes sensing")
	power.load_state(saved_power)
	_check(sector.get_detection_range() == 1050.0 and modules.get_effects()["active_load_w"] == 20.0, "power-state restore reconciles sensing without refitting")
	sector.set_survey_source(&"modules", NAN)
	_check(sector.get_detection_range() == 1050.0, "invalid derived contribution leaves sensing unchanged")
	sector.load_state(saved_sector)


func _check(ok: bool, description: String) -> void:
	if not ok:
		_failures += 1
		push_error("FAIL: " + description)
