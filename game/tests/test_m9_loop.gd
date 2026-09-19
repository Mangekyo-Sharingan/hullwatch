## M9 loop scenario: gather from the drifting field, run the fabricator, and keep the
## ship's consumable stock replaced across a month of ship days, on mined inputs alone.
extends SceneTree

var _failures: int = 0
var _completed: Array[Dictionary] = []
var _objects: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var event_bus: Node = root.get_node_or_null(^"EventBus")
	if event_bus == null:
		event_bus = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
	event_bus.connect(&"sim_event", _on_sim_event)

	var sector: SectorSystem = SectorSystem.new()
	sector.field_seed = 20260918
	sector.drift_axis = Vector3.FORWARD
	root.add_child(sector)
	var cargo: CargoSystem = CargoSystem.new()
	root.add_child(cargo)
	var stores: Stores = Stores.new()
	root.add_child(stores)
	var power: PowerSystem = PowerSystem.new()
	var circuits: Array[PowerCircuit] = []
	var circuit: PowerCircuit = PowerCircuit.new()
	circuit.circuit_id = &"fabricator"
	circuit.nominal_load_w = 80.0
	circuits.append(circuit)
	power.circuit_defs = circuits
	root.add_child(power)
	var fabricator: FabricatorSystem = FabricatorSystem.new()
	fabricator.recipes = _recipes()
	root.add_child(fabricator)
	await process_frame
	power.set_breaker(&"fabricator", true)

	var player: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	_check(bool(player.call("equip_suit_cutter")), "the cutter clips to the suit")
	var canister: SampleCanister = SampleCanister.new()
	canister.item_id = &"sample_canister"
	canister.item_name = "Sample canister"
	root.add_child(canister)
	player.call("take_carriable", canister)
	var port: CargoPort = CargoPort.new()
	root.add_child(port)
	await process_frame

	var gathered: bool = false
	for day: int in 30:
		for hour: int in 24:
			sector.sim_tick(1.0)
			_mine_contacts(sector, player, canister, port)
		gathered = (
			cargo.get_units(&"ice") >= 10.0
			and cargo.get_units(&"ore") >= 12.0
			and cargo.get_units(&"metal") >= 3.0
		)
		if gathered:
			print("PASS: the field supplied ice, ore and metal within %d days" % (day + 1))
			break
	if not gathered:
		_check(false, "the field supplies ice, ore and metal within 30 days")
		_finish()
		return

	_check(StringName(String(fabricator.call("start", &"co2_filter"))) == &"", "the CO2 filter job starts on ore")
	_run_hours(fabricator, 3.0)
	_check(stores.get_count(&"filter_co2") == 1, "a replacement CO2 filter reaches stores")
	_check(stores.consume_part(&"filter_co2"), "the scrubber wears the filter out")
	_check(stores.get_count(&"filter_co2") == 0, "stores run dry")
	_check(StringName(String(fabricator.call("start", &"co2_filter"))) == &"", "the loop refabricates from fresh ore")
	_run_hours(fabricator, 3.0)
	_check(stores.get_count(&"filter_co2") == 1, "the stock is restored")

	_check(StringName(String(fabricator.call("start", &"water_filter"))) == &"", "the water filter job starts on ice")
	_run_hours(fabricator, 2.0)
	_check(stores.get_count(&"water_filter") == 1, "a replacement water filter reaches stores")
	var metal_before: float = cargo.get_units(&"metal")
	_check(StringName(String(fabricator.call("start", &"gasket"))) == &"", "the gasket job starts on metal")
	_run_hours(fabricator, 2.0)
	_check(stores.get_count(&"gasket") == 2, "gaskets stack in stores")
	_check(_completed.size() == 4, "four fabrication jobs completed in the month")

	_check(is_equal_approx(cargo.get_units(&"metal"), metal_before - 3.0), "the month's mining fed the fabricator alone")
	_check(cargo.get_units(&"ice") >= 6.0 and cargo.get_units(&"ore") >= 2.0, "raw stock remains in the hold")

	sector.free()
	cargo.free()
	stores.free()
	power.free()
	fabricator.free()
	# The canister rides the player while carried and frees with it.
	player.free()
	port.free()
	for object: Node in _objects.values():
		object.free()
	event_bus.disconnect(&"sim_event", _on_sim_event)
	_finish()


func _mine_contacts(sector: SectorSystem, player: Node, canister: SampleCanister, port: CargoPort) -> void:
	for entry: Dictionary in sector.get_contacts():
		if StringName(entry.get("kind", &"")) == &"anomaly":
			continue
		var id: String = String(entry.get("id", ""))
		var object: SpaceObject = _objects.get(id) as SpaceObject
		if object == null:
			object = SpaceObject.new()
			object.setup(entry)
			root.add_child(object)
			_objects[id] = object
		if object.get_remaining() <= 0.0:
			continue
		if not bool(canister.call("is_empty")):
			continue
		object.interact(player)
		if not bool(canister.call("is_empty")):
			port.interact(player)


func _run_hours(fabricator: FabricatorSystem, hours: float) -> void:
	var tick: float = 0.25
	var remaining: float = hours
	while remaining > 0.0:
		var step: float = minf(tick, remaining)
		fabricator.sim_tick(step)
		remaining -= step


func _recipes() -> Array[FabricatorRecipe]:
	var recipes: Array[FabricatorRecipe] = []
	for path: String in [
		"res://src/data/fabrication/recipe_water_filter.tres",
		"res://src/data/fabrication/recipe_o2_candle.tres",
		"res://src/data/fabrication/recipe_co2_filter.tres",
		"res://src/data/fabrication/recipe_gasket.tres",
	]:
		var recipe: FabricatorRecipe = load(path) as FabricatorRecipe
		if recipe != null:
			recipes.append(recipe)
	return recipes


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"fabrication_completed":
		_completed.append(payload)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_m9_loop")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	_failures += 1
	print("FAIL: ", label)
