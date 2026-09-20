## Module effect tests (M10.4): the catalog's pods actually do something once built - rations,
## bench speed, hold capacity, battery capacity and recovery - and every contribution is undone
## again on teardown, including the circuit draw.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var event_bus: Node = root.get_node_or_null(^"EventBus")
	if event_bus == null:
		event_bus = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)

	var cargo: CargoSystem = CargoSystem.new()
	cargo.capacity_units = 1200.0
	root.add_child(cargo)
	var stores: Stores = Stores.new()
	root.add_child(stores)
	var power: PowerSystem = PowerSystem.new()
	power.battery_capacity_wh = 4000.0
	power.generators = {&"test_rtg": 1200.0}
	var circuits: Array[PowerCircuit] = []
	for definition: Array in [[&"life_support", 120.0, 3], [&"fabricator", 80.0, 5]]:
		var circuit: PowerCircuit = PowerCircuit.new()
		circuit.circuit_id = StringName(definition[0])
		circuit.nominal_load_w = float(definition[1])
		circuit.priority = int(definition[2])
		circuits.append(circuit)
	power.circuit_defs = circuits
	root.add_child(power)
	var fabricator: FabricatorSystem = FabricatorSystem.new()
	var recipe: FabricatorRecipe = FabricatorRecipe.new()
	recipe.recipe_id = &"test_part"
	recipe.material_kind = &"metal"
	recipe.material_units = 1.0
	recipe.output_part_id = &"gasket"
	recipe.hours = 4.0
	var recipes: Array[FabricatorRecipe] = [recipe]
	fabricator.recipes = recipes
	root.add_child(fabricator)
	var vitals: VitalsSystem = VitalsSystem.new()
	root.add_child(vitals)
	var modules: ModuleSystem = ModuleSystem.new()
	modules.catalog = _catalog()
	root.add_child(modules)
	await process_frame

	_check(modules.get_catalog().size() >= 5, "the shipped module catalog loads")
	cargo.add_material(&"metal", 200.0)
	cargo.add_material(&"ore", 200.0)
	cargo.add_material(&"ice", 200.0)

	# Greenhouse: rations per day, drawing on the life-support circuit.
	_build(modules, &"greenhouse")
	await process_frame
	_check(is_equal_approx(power.get_circuit_load(&"life_support"), 340.0), "the greenhouse draws on the life-support circuit")
	_check(is_equal_approx(float(modules.get_effects()["rations_per_day"]), 3.0), "the greens report 3 rations a day")
	var grown: int = stores.get_count(&"food_ration")
	modules.sim_tick(24.0)
	_check(stores.get_count(&"food_ration") == grown + 3, "a day of growth yields three rations")
	power.set_breaker(&"life_support", false)
	modules.sim_tick(48.0)
	_check(stores.get_count(&"food_ration") == grown + 3, "an unpowered greenhouse grows nothing")
	power.set_breaker(&"life_support", true)
	modules.sim_tick(8.0)
	_check(stores.get_count(&"food_ration") == grown + 4, "power restored, growth resumes")
	_check(modules.uninstall(&"greenhouse"), "the greenhouse tears down")
	_check(is_equal_approx(power.get_circuit_load(&"life_support"), 120.0), "teardown clears the circuit draw")
	modules.sim_tick(24.0)
	_check(stores.get_count(&"food_ration") == grown + 4, "a torn-down greenhouse grows nothing")

	# Workshop: the bench runs faster.
	_build(modules, &"workshop")
	_check(is_equal_approx(float(fabricator.get(&"job_hours_multiplier")), 0.65), "a workshop speeds the bench up by a third")
	_check(StringName(String(fabricator.call("start", &"test_part"))) == &"", "a bench job starts")
	_check(is_equal_approx(float(fabricator.call("get_job_remaining_hours")), 2.6), "the job is shorter with the workshop up")
	modules.uninstall(&"workshop")
	_check(is_equal_approx(float(fabricator.get(&"job_hours_multiplier")), 1.0), "teardown restores bench speed")

	# Expanded storage: more hold.
	var base_capacity: float = cargo.get_capacity_units()
	_build(modules, &"expanded_storage")
	_check(is_equal_approx(cargo.get_capacity_units(), base_capacity + 60.0), "an expanded hold adds 60 units")
	modules.uninstall(&"expanded_storage")
	_check(is_equal_approx(cargo.get_capacity_units(), base_capacity), "teardown returns the hold to its own size")

	# Aux battery: more capacity, same charge.
	var base_battery: float = power.get_battery_capacity_wh()
	_build(modules, &"aux_battery")
	_check(is_equal_approx(power.get_battery_capacity_wh(), base_battery + 2400.0), "an aux battery adds 2400 Wh")
	modules.uninstall(&"aux_battery")
	_check(is_equal_approx(power.get_battery_capacity_wh(), base_battery), "teardown returns battery capacity")

	# Med bay: faster recovery.
	var base_recovery: float = vitals.get_recovery_per_hour()
	_build(modules, &"med_bay")
	_check(is_equal_approx(vitals.get_recovery_per_hour(), base_recovery + 0.35), "a med bay speeds recovery")
	_check(is_equal_approx(power.get_circuit_load(&"life_support"), 270.0), "the med bay draws on life support too")
	modules.uninstall(&"med_bay")
	_check(is_equal_approx(vitals.get_recovery_per_hour(), base_recovery), "teardown returns recovery rate")
	_check(is_equal_approx(power.get_circuit_load(&"life_support"), 120.0), "teardown clears the last draw")

	var summary: Dictionary = modules.get_effects()
	_check(is_equal_approx(float(summary["cargo_units"]), 0.0) and is_equal_approx(float(summary["power_wh"]), 0.0), "nothing is left contributing")

	if _failures == 0:
		print("PASS: test_module_effects")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _build(modules: ModuleSystem, module_id: StringName) -> void:
	if not bool(modules.call("start_build", module_id)):
		_check(false, "build could start: " + String(module_id))
		return
	modules.sim_tick(99.0)
	_check(modules.is_installed(module_id), "the build landed: " + String(module_id))


## Loads the shipped catalog so the test covers the data the game actually uses.
func _catalog() -> Array[ShipModule]:
	var modules: Array[ShipModule] = []
	var dir: DirAccess = DirAccess.open("res://src/data/modules")
	if dir == null:
		return modules
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var module: ShipModule = load("res://src/data/modules/" + file_name) as ShipModule
		if module != null:
			modules.append(module)
	return modules


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
