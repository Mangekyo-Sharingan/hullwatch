## Machine fitting tests (M10.4 / operator answer Q3): pods are bare rooms, machines are what
## do the work, any pod's socket takes any machine, machines stack, removal refunds and returns
## the effect, vital machinery refuses to move, and fitting survives save/load mid-job.
extends SceneTree

var _failures: int = 0
var _last_refusal: StringName = &""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var event_bus: Node = root.get_node_or_null(^"EventBus")
	if event_bus == null:
		event_bus = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
	event_bus.connect(&"sim_event", func(event_name: StringName, payload: Dictionary) -> void:
		if event_name == &"procedure_error":
			_last_refusal = StringName(payload.get("reason", &""))
	)

	var cargo: CargoSystem = CargoSystem.new()
	cargo.capacity_units = 2000.0
	root.add_child(cargo)
	var stores: Stores = Stores.new()
	root.add_child(stores)
	var power: PowerSystem = PowerSystem.new()
	power.battery_capacity_wh = 4000.0
	power.generators = {&"test_rtg": 1500.0}
	var circuits: Array[PowerCircuit] = []
	for definition: Array in [[&"life_support", 120.0, 3], [&"fabricator", 80.0, 5], [&"scrubber", 60.0, 2]]:
		var circuit: PowerCircuit = PowerCircuit.new()
		circuit.circuit_id = StringName(definition[0])
		circuit.nominal_load_w = float(definition[1])
		circuit.priority = int(definition[2])
		circuits.append(circuit)
	power.circuit_defs = circuits
	root.add_child(power)
	var fabricator: FabricatorSystem = FabricatorSystem.new()
	root.add_child(fabricator)
	var vitals: VitalsSystem = VitalsSystem.new()
	root.add_child(vitals)
	var modules: ModuleSystem = ModuleSystem.new()
	var module_catalog: Array[ShipModule] = []
	for resource: Variant in _load_resources("res://src/data/modules"):
		module_catalog.append(resource as ShipModule)
	modules.catalog = module_catalog
	var machine_catalog: Array[ShipMachine] = []
	for resource: Variant in _load_resources("res://src/data/machines"):
		machine_catalog.append(resource as ShipMachine)
	modules.machine_catalog = machine_catalog
	root.add_child(modules)
	await process_frame

	cargo.add_material(&"metal", 200.0)
	cargo.add_material(&"ore", 200.0)
	cargo.add_material(&"ice", 200.0)
	_check(modules.get_machine_catalog().size() >= 5, "the machine catalog loads")

	# A bare pod first: no machines, no function.
	modules.start_build(&"utility_pod")
	modules.sim_tick(99.0)
	_check(modules.is_installed(&"utility_pod"), "a bare pod stands")
	_check(is_equal_approx(float(modules.get_effects()["rations_per_day"]), 0.0), "a bare pod grows nothing")

	var ice_before: float = cargo.get_units(&"ice")
	_check(StringName(String(modules.call("can_fit_machine", &"grow_rack", &"hp_quarters:0"))) == &"", "an empty socket takes a grow rack")
	_check(modules.fit_machine(&"grow_rack", &"hp_quarters:0"), "the fitting job starts")
	_check(is_equal_approx(cargo.get_units(&"ice"), ice_before - 1.0), "the fitting cost is committed")
	_check(modules.get_machine_at(&"hp_quarters:0") == &"", "nothing is fitted while nanites work")
	modules.sim_tick(5.1)
	_check(modules.get_machine_at(&"hp_quarters:0") == &"grow_rack", "the machine lands in its socket")
	_check(is_equal_approx(float(modules.get_effects()["rations_per_day"]), 2.0), "the rack grows two rations a day")
	_check(is_equal_approx(power.get_circuit_load(&"life_support"), 210.0), "the rack draws on life support")

	var grown: int = stores.get_count(&"food_ration")
	modules.sim_tick(24.0)
	_check(stores.get_count(&"food_ration") == grown + 2, "the rack yields its rations")

	# A second machine in the next socket: effects stack.
	_check(modules.fit_machine(&"grow_rack", &"hp_quarters:1"), "a second socket takes another rack")
	modules.sim_tick(5.1)
	_check(is_equal_approx(float(modules.get_effects()["rations_per_day"]), 4.0), "machines stack")
	var capacity_before: float = cargo.capacity_units
	cargo.capacity_units = cargo.get_used_units() + 3.0
	var modules_before: Dictionary = modules.save_state()
	var cargo_before: Dictionary = cargo.get_materials()
	_check(not modules.remove_machine(&"hp_quarters:1"), "removal refuses a partially fitting full refund")
	_check(modules.save_state() == modules_before and cargo.get_materials() == cargo_before, "refused removal preserves machine and all stock")
	_check(is_equal_approx(power.get_circuit_load(&"life_support"), 300.0), "refused removal preserves live draw")
	cargo.capacity_units = capacity_before
	_check(modules.remove_machine(&"hp_quarters:1"), "a portable machine comes back out")
	cargo_before = cargo.get_materials()
	_check(not modules.remove_machine(&"hp_quarters:1") and cargo.get_materials() == cargo_before, "repeat removal cannot refund twice")
	_check(is_equal_approx(float(modules.get_effects()["rations_per_day"]), 2.0), "removal takes the effect with it")
	_check(is_equal_approx(power.get_circuit_load(&"life_support"), 210.0), "removal clears the draw")

	# Any machine in any socket: a cargo rack in the same pod, and a second pod for the rest.
	var capacity: float = cargo.get_capacity_units()
	_check(modules.fit_machine(&"cargo_rack", &"hp_quarters:1"), "the same pod takes a cargo rack")
	modules.sim_tick(4.1)
	_check(is_equal_approx(cargo.get_capacity_units(), capacity + 25.0), "the rack adds hold space")
	cargo.capacity_units = cargo.get_used_units()
	modules_before = modules.save_state()
	cargo_before = cargo.get_materials()
	_check(not modules.remove_machine(&"hp_quarters:1"), "storage removal checks refund against final smaller capacity")
	_check(modules.save_state() == modules_before and cargo.get_materials() == cargo_before, "refused storage shrink preserves cargo and fitting")
	cargo.capacity_units = capacity_before

	# Vital machinery is bolted down.
	_check(modules.fit_machine(&"scrubber_spare", &"hp_quarters:2"), "a spare scrubber can be fitted")
	modules.sim_tick(9.0)
	_check(modules.get_machine_at(&"hp_quarters:2") == &"scrubber_spare", "the spare is in place")
	_check(not modules.remove_machine(&"hp_quarters:2"), "a non-portable machine refuses to be moved")
	_check(modules.get_machine_at(&"hp_quarters:2") == &"scrubber_spare", "and it stays fitted")

	_check(modules.start_build(&"storage_pod"), "a second pod builds")
	modules.sim_tick(99.0)
	_check(modules.get_installed_at(&"hp_galley") == &"storage_pod", "the second pod stands")

	# Occupied sockets refuse; a fitting can be cancelled and refunded.
	var metal_before: float = cargo.get_units(&"metal")
	_check(StringName(String(modules.call("can_fit_machine", &"work_bench", &"hp_quarters:1"))) == &"slot_occupied", "an occupied socket refuses")
	_check(modules.fit_machine(&"med_bed", &"hp_galley:0"), "a fitting can start in a free socket")
	_check(not modules.remove_machine(&"hp_galley:0"), "a socket mid-fit reports nothing to remove")
	cargo.capacity_units = cargo.get_used_units() - 25.0 + 3.0
	modules_before = modules.save_state()
	cargo_before = cargo.get_materials()
	_check(not modules.cancel_machine_fit(&"hp_galley:0"), "fitting cancellation refuses an incomplete aggregate refund")
	_check(modules.save_state() == modules_before and cargo.get_materials() == cargo_before, "refused fitting cancellation keeps paid job and stock")
	cargo.capacity_units = capacity_before
	_check(modules.cancel_machine_fit(&"hp_galley:0"), "a running fitting can be cancelled")
	_check(is_equal_approx(cargo.get_units(&"metal"), metal_before), "cancelling refunds the material")
	cargo_before = cargo.get_materials()
	_check(not modules.cancel_machine_fit(&"hp_galley:0") and cargo.get_materials() == cargo_before, "repeat fitting cancellation cannot refund twice")

	# Save/load with machines fitted and one fitting in flight.
	_check(modules.fit_machine(&"work_bench", &"hp_galley:0"), "a bench fitting starts")
	var saved: Dictionary = modules.save_state()
	modules.sim_tick(2.0)
	_check(is_equal_approx(float(modules.get_machine_job(&"hp_galley:0").get("remaining", 0.0)), 2.0), "the fitting job ticks down")
	modules.load_state(saved)
	_check(modules.get_machine_at(&"hp_quarters:0") == &"grow_rack", "load restores a fitted machine")
	_check(modules.get_machine_at(&"hp_quarters:2") == &"scrubber_spare", "load restores the fixed machinery")
	_check(is_equal_approx(float(modules.get_machine_job(&"hp_galley:0").get("remaining", 0.0)), 4.0), "a fitting in flight survives save/load")
	_check(is_equal_approx(float(modules.get_effects()["rations_per_day"]), 2.0), "load restores the machine effects")
	_check(is_equal_approx(cargo.get_capacity_units(), capacity + 25.0), "load restores machine hold space")
	modules.sim_tick(4.1)
	_check(modules.get_machine_at(&"hp_galley:0") == &"work_bench", "the restored fitting completes")

	# Pod teardown takes its own machines with it and leaves the other pod alone.
	var metal_at_teardown: float = cargo.get_units(&"metal")
	cargo.capacity_units = cargo.get_used_units()
	modules_before = modules.save_state()
	cargo_before = cargo.get_materials()
	_check(not modules.uninstall(&"utility_pod"), "pod teardown checks all refunds against capacity after cargo rack removal")
	_check(modules.save_state() == modules_before and cargo.get_materials() == cargo_before, "refused aggregate teardown keeps all machines and stock")
	cargo.capacity_units = capacity_before
	_check(modules.uninstall(&"utility_pod"), "the pod tears down with machines inside")
	_check(modules.get_machine_at(&"hp_quarters:0") == &"", "the pod's machines go with it")
	_check(is_equal_approx(float(modules.get_effects()["rations_per_day"]), 0.0), "the racks stop growing")
	_check(is_equal_approx(cargo.get_capacity_units(), capacity), "the cargo rack's space goes too")
	_check(cargo.get_units(&"metal") > metal_at_teardown - 0.001, "the machines are refunded with the pod")
	_check(modules.get_installed_at(&"hp_galley") == &"storage_pod", "the other pod is untouched")

	_check(modules.fit_machine(&"battery_cabinet", &"hp_galley:1"), "built battery fitting starts")
	modules.sim_tick(7.0)
	var base_wh: float = power.get_battery_capacity_wh() - modules.get_machine(&"battery_cabinet").effect_amount
	power.battery_charge_wh = base_wh + 1.0
	modules_before = modules.save_state()
	cargo_before = cargo.get_materials()
	_check(not modules.remove_machine(&"hp_galley:1"), "built battery removal refuses excess stored charge")
	_check(_last_refusal == &"battery_capacity_in_use", "built removal reports battery capacity cause")
	_check(not modules.uninstall(&"storage_pod"), "pod teardown refuses excess charge from built battery")
	_check(_last_refusal == &"battery_capacity_in_use", "built pod teardown reports battery capacity cause")
	_check(modules.save_state() == modules_before and cargo.get_materials() == cargo_before and power.battery_charge_wh == base_wh + 1.0, "energy refusal preserves fitting, refund and charge")
	power.battery_charge_wh = base_wh - 1.0
	_check(modules.remove_machine(&"hp_galley:1"), "spending charge permits built battery removal retry")
	_check(power.battery_charge_wh == base_wh - 1.0 and power.get_battery_capacity_wh() == base_wh, "built battery removal preserves exact energy")
	cargo_before = cargo.get_materials()
	_check(not modules.remove_machine(&"hp_galley:1") and cargo.get_materials() == cargo_before, "built battery refunds exactly once")

	if _failures == 0:
		print("PASS: test_machine_fitting")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _load_resources(dir_path: String) -> Array:
	var resources: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return resources
	for file_name: String in dir.get_files():
		if file_name.ends_with(".tres"):
			var resource: Resource = load(dir_path + "/" + file_name)
			if resource != null:
				resources.append(resource)
	return resources


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
