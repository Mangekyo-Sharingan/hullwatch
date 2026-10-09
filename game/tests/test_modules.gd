## Module tests: build gating, nanite build jobs, cargo cost and refunds, compartment
## registration, signals, and save/load including a build in flight.
extends SceneTree

var _failures: int = 0
var _events: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	root.add_child(atmosphere)
	var thermal: ThermalSystem = ThermalSystem.new()
	root.add_child(thermal)
	var hull: HullSystem = HullSystem.new()
	root.add_child(hull)
	var cargo: CargoSystem = CargoSystem.new()
	cargo.capacity_units = 50.0
	root.add_child(cargo)
	var modules: ModuleSystem = ModuleSystem.new()
	modules.catalog = _catalog()
	root.add_child(modules)

	var event_bus: Node = root.get_node_or_null(^"EventBus")
	_check(event_bus != null, "EventBus autoload is present")
	if event_bus != null:
		event_bus.connect(&"module_installed", func(a: StringName, b: StringName) -> void: _events.append([&"installed", a, b]))
		event_bus.connect(&"module_uninstalled", func(a: StringName, b: StringName) -> void: _events.append([&"uninstalled", a, b]))
		event_bus.connect(&"construction_started", func(a: StringName, b: StringName) -> void: _events.append([&"building", a, b]))

	_check(modules.can_install(&"bogus") == ModuleSystem.REFUSAL_UNKNOWN_MODULE, "unknown module ids refuse")
	_check(modules.can_install(&"greenhouse") == ModuleSystem.REFUSAL_MISSING_MATERIALS, "an empty hold refuses the build")

	cargo.add_material(&"metal", 10.0)
	cargo.add_material(&"ore", 6.0)
	_check(modules.can_install(&"greenhouse") == &"", "stocked materials allow the build")

	_check(modules.start_build(&"greenhouse"), "the build starts with materials")
	_check(is_equal_approx(cargo.get_units(&"metal"), 6.0), "metal cost is committed up front")
	_check(is_equal_approx(cargo.get_units(&"ore"), 4.0), "ore cost is committed up front")
	_check(not modules.is_installed(&"greenhouse"), "nothing stands while the nanites work")
	_check(modules.is_building(&"greenhouse"), "the module reports building")
	_check(not atmosphere.has_compartment(&"greenhouse"), "no compartment before the build lands")
	var job: Dictionary = modules.get_job(&"hp_quarters")
	_check(is_equal_approx(float(job.get("remaining", 0.0)), 4.0), "the job carries the module's build hours")
	_check(modules.can_install(&"greenhouse_twin") == ModuleSystem.REFUSAL_HARDPOINT_OCCUPIED, "a dock under construction refuses another module")

	modules.sim_tick(1.5)
	_check(is_equal_approx(float(modules.get_job(&"hp_quarters").get("remaining", 0.0)), 2.5), "ticking the clock advances the build")
	modules.sim_tick(2.5)
	_check(modules.is_installed(&"greenhouse"), "the module stands when the job lands")
	_check(modules.get_installed_at(&"hp_quarters") == &"greenhouse", "the hardpoint reports its module")
	_check(modules.get_job(&"hp_quarters").is_empty(), "the job clears on completion")
	_check(atmosphere.has_compartment(&"greenhouse"), "atmosphere registers the module compartment")
	_check(thermal.has_compartment(&"greenhouse"), "thermal registers the module compartment")
	_check(hull.has_compartment(&"greenhouse"), "hull registers the module compartment")
	_check(is_equal_approx(cargo.get_units(&"metal"), 6.0), "completion spends nothing more")
	_check(_events.size() == 2 and _events[0] == [&"building", &"greenhouse", &"hp_quarters"], "construction_started fires first")
	_check(_events[1] == [&"installed", &"greenhouse", &"hp_quarters"], "module_installed fires on completion")

	_check(modules.can_install(&"greenhouse") == ModuleSystem.REFUSAL_ALREADY_INSTALLED, "a second copy of the same module refuses")

	_check(modules.start_build(&"med_bay"), "a free module builds without cost")
	_check(is_equal_approx(cargo.get_units(&"metal"), 6.0), "a free module spends nothing")
	modules.sim_tick(9.0)
	_check(modules.get_installed_modules() == ([&"greenhouse", &"med_bay"] as Array[StringName]), "installed list is stable")

	var saved: Dictionary = modules.save_state()

	_check(modules.uninstall(&"greenhouse"), "uninstall succeeds")
	_check(is_equal_approx(cargo.get_units(&"metal"), 10.0), "teardown refunds the full metal cost")
	_check(is_equal_approx(cargo.get_units(&"ore"), 6.0), "teardown refunds the full ore cost")
	_check(not atmosphere.has_compartment(&"greenhouse"), "uninstall removes the atmosphere compartment")
	_check(not thermal.has_compartment(&"greenhouse"), "uninstall removes the thermal compartment")
	_check(not hull.has_compartment(&"greenhouse"), "uninstall removes the hull compartment")
	_check(modules.get_installed_at(&"hp_quarters") == &"", "uninstall frees the hardpoint")
	_check(not modules.uninstall(&"greenhouse"), "uninstalling twice refuses")
	_check(modules.can_install(&"greenhouse") == &"", "a freed hardpoint can be rebuilt")

	cargo.consume_material(&"metal", 10.0)
	cargo.add_material(&"metal", 4.0)
	_check(modules.start_build(&"greenhouse"), "a rebuild starts again")
	_check(modules.cancel_build(&"hp_quarters"), "a running build can be cancelled")
	_check(is_equal_approx(cargo.get_units(&"metal"), 4.0), "cancelling refunds the committed metal")
	_check(modules.get_job(&"hp_quarters").is_empty() and not modules.is_installed(&"greenhouse"), "a cancelled build leaves nothing behind")
	_check(not modules.cancel_build(&"hp_quarters"), "cancelling nothing refuses")

	modules.load_state(saved)
	_check(modules.get_installed_modules() == ([&"greenhouse", &"med_bay"] as Array[StringName]), "load restores the installed set")
	_check(atmosphere.has_compartment(&"greenhouse"), "load re-registers module compartments")
	_check(thermal.has_compartment(&"greenhouse"), "load re-registers into thermal")
	_check(hull.has_compartment(&"workshop") == false, "unstored modules stay unregistered")
	_check(modules.get_installed_at(&"hp_engine_bay") == &"med_bay", "load restores hardpoint assignments")

	_check(modules.can_install(&"workshop") == ModuleSystem.REFUSAL_HARDPOINT_CLEARANCE, "adjacent port pods cannot be installed together")
	_check(not modules.start_build(&"workshop"), "a port clearance conflict refuses construction")
	_check(modules.uninstall(&"greenhouse"), "removing the adjacent pod clears the port")
	_check(modules.start_build(&"workshop"), "a build can start after the neighboring dock is cleared")
	var in_flight: Dictionary = modules.save_state()
	modules.sim_tick(0.5)
	_check(is_equal_approx(float(modules.get_job(&"hp_life_support").get("remaining", 0.0)), 5.5), "the workshop job ticks down")
	modules.load_state(in_flight)
	_check(is_equal_approx(float(modules.get_job(&"hp_life_support").get("remaining", 0.0)), 6.0), "a build in flight survives save/load")
	_check(not modules.is_installed(&"workshop"), "a restored job is still building")
	modules.sim_tick(6.0)
	_check(modules.is_installed(&"workshop"), "the restored job completes")

	var status: Dictionary = modules.get_status()
	_check(int(status["installed_count"]) == 2, "status counts installed modules")
	_check(int(status["building_count"]) == 0, "status counts no jobs once they land")

	if _failures == 0:
		print("PASS: test_modules")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _catalog() -> Array[ShipModule]:
	var greenhouse: ShipModule = ShipModule.new()
	greenhouse.module_id = &"greenhouse"
	greenhouse.display_name = "Greenhouse"
	greenhouse.hardpoint_id = &"hp_quarters"
	greenhouse.cost = {"metal": 4.0, "ore": 2.0}
	greenhouse.build_hours = 4.0
	greenhouse.compartment_config = _make_config(&"greenhouse", 24.0)

	var twin: ShipModule = ShipModule.new()
	twin.module_id = &"greenhouse_twin"
	twin.hardpoint_id = &"hp_quarters"
	twin.compartment_config = _make_config(&"greenhouse_twin", 24.0)

	var workshop: ShipModule = ShipModule.new()
	workshop.module_id = &"workshop"
	workshop.hardpoint_id = &"hp_life_support"
	workshop.cost = {"metal": 3.0}
	workshop.build_hours = 6.0
	workshop.compartment_config = _make_config(&"workshop", 21.0)

	var med_bay: ShipModule = ShipModule.new()
	med_bay.module_id = &"med_bay"
	med_bay.hardpoint_id = &"hp_engine_bay"
	med_bay.compartment_config = _make_config(&"med_bay", 18.0)

	var modules: Array[ShipModule] = [greenhouse, twin, workshop, med_bay]
	return modules


func _make_config(compartment_id: StringName, volume_m3: float) -> CompartmentConfig:
	var config: CompartmentConfig = CompartmentConfig.new()
	config.compartment_id = compartment_id
	config.volume_m3 = volume_m3
	return config


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
