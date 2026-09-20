## Module tests: install gating, cargo cost, compartment registration, signals and save/load.
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
		event_bus.connect(&"module_installed", func(a: StringName, b: StringName) -> void: _events.append([a, b]))
		event_bus.connect(&"module_uninstalled", func(a: StringName, b: StringName) -> void: _events.append([a, b]))

	_check(modules.can_install(&"bogus") == ModuleSystem.REFUSAL_UNKNOWN_MODULE, "unknown module ids refuse")
	_check(modules.can_install(&"greenhouse") == ModuleSystem.REFUSAL_MISSING_MATERIALS, "an empty hold refuses the build")

	cargo.add_material(&"metal", 10.0)
	cargo.add_material(&"ore", 6.0)
	_check(modules.can_install(&"greenhouse") == &"", "stocked materials allow the build")

	_check(modules.install(&"greenhouse"), "install succeeds with materials")
	_check(is_equal_approx(cargo.get_units(&"metal"), 6.0), "metal cost is consumed")
	_check(is_equal_approx(cargo.get_units(&"ore"), 4.0), "ore cost is consumed")
	_check(modules.is_installed(&"greenhouse"), "the module reports installed")
	_check(modules.get_installed_at(&"hp_quarters") == &"greenhouse", "the hardpoint reports its module")
	_check(atmosphere.has_compartment(&"greenhouse"), "atmosphere registers the module compartment")
	_check(thermal.has_compartment(&"greenhouse"), "thermal registers the module compartment")
	_check(hull.has_compartment(&"greenhouse"), "hull registers the module compartment")
	_check(_events.size() == 1 and _events[0] == [&"greenhouse", &"hp_quarters"], "module_installed signal fires")

	_check(modules.can_install(&"greenhouse") == ModuleSystem.REFUSAL_ALREADY_INSTALLED, "a second copy of the same module refuses")
	_check(modules.can_install(&"greenhouse_twin") == ModuleSystem.REFUSAL_HARDPOINT_OCCUPIED, "an occupied hardpoint refuses")

	_check(modules.install(&"med_bay"), "a free module installs without cost")
	_check(is_equal_approx(cargo.get_units(&"metal"), 6.0), "a free module spends nothing")
	_check(modules.get_installed_modules() == ([&"greenhouse", &"med_bay"] as Array[StringName]), "installed list is stable")

	var saved: Dictionary = modules.save_state()
	_check(is_equal_approx(cargo.get_units(&"metal"), 6.0), "saving does not refund materials")

	_check(modules.uninstall(&"greenhouse"), "uninstall succeeds")
	_check(not atmosphere.has_compartment(&"greenhouse"), "uninstall removes the atmosphere compartment")
	_check(not thermal.has_compartment(&"greenhouse"), "uninstall removes the thermal compartment")
	_check(not hull.has_compartment(&"greenhouse"), "uninstall removes the hull compartment")
	_check(modules.get_installed_at(&"hp_quarters") == &"", "uninstall frees the hardpoint")
	_check(not modules.uninstall(&"greenhouse"), "uninstalling twice refuses")
	_check(modules.can_install(&"greenhouse") == &"", "a freed hardpoint can be rebuilt")

	modules.load_state(saved)
	_check(modules.get_installed_modules() == ([&"greenhouse", &"med_bay"] as Array[StringName]), "load restores the installed set")
	_check(atmosphere.has_compartment(&"greenhouse"), "load re-registers module compartments")
	_check(thermal.has_compartment(&"greenhouse"), "load re-registers into thermal")
	_check(hull.has_compartment(&"workshop") == false, "unstored modules stay unregistered")
	_check(modules.get_installed_at(&"hp_galley") == &"med_bay", "load restores hardpoint assignments")

	var status: Dictionary = modules.get_status()
	_check(int(status["installed_count"]) == 2, "status counts installed modules")

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
	greenhouse.compartment_config = _make_config(&"greenhouse", 24.0)

	var twin: ShipModule = ShipModule.new()
	twin.module_id = &"greenhouse_twin"
	twin.hardpoint_id = &"hp_quarters"
	twin.compartment_config = _make_config(&"greenhouse_twin", 24.0)

	var workshop: ShipModule = ShipModule.new()
	workshop.module_id = &"workshop"
	workshop.hardpoint_id = &"hp_life_support"
	workshop.cost = {"metal": 3.0}
	workshop.compartment_config = _make_config(&"workshop", 21.0)

	var med_bay: ShipModule = ShipModule.new()
	med_bay.module_id = &"med_bay"
	med_bay.hardpoint_id = &"hp_galley"
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

