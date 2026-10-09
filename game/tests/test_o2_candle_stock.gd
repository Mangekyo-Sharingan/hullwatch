extends SceneTree

var _failures: int = 0
var _events: Array[StringName] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.get_node(^"SimClock").set_process(false)
	root.get_node(^"EventBus").connect(&"sim_event", _on_event)
	var config: CompartmentConfig = CompartmentConfig.new()
	config.compartment_id = &"main"
	config.o2_candles_stocked = 1
	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	atmosphere.compartment_defs = [config]
	root.add_child(atmosphere)
	if not atmosphere.has_method(&"add_o2_candle"):
		_check(false, "parent AtmosphereSystem.add_o2_candle interface available")
		atmosphere.free()
		_finish()
		return
	var stores: Stores = Stores.new()
	stores.initial_inventory = {}
	root.add_child(stores)
	var cargo: CargoSystem = CargoSystem.new()
	root.add_child(cargo)
	var circuit: PowerCircuit = PowerCircuit.new()
	circuit.circuit_id = &"fabricator"
	circuit.nominal_load_w = 80.0
	var power: PowerSystem = PowerSystem.new()
	power.circuit_defs = [circuit]
	root.add_child(power)
	var recipe: FabricatorRecipe = load("res://src/data/fabrication/recipe_o2_candle.tres") as FabricatorRecipe
	var fabricator: FabricatorSystem = FabricatorSystem.new()
	fabricator.recipes = [recipe]
	root.add_child(fabricator)
	cargo.add_material(recipe.material_kind, recipe.material_units)
	_check(fabricator.start(recipe.recipe_id) == &"", "real oxygen candle recipe starts")
	fabricator.sim_tick(recipe.hours)
	_check(stores.get_count(&"o2_candle") == 1, "fabricated candle enters correct Stores item")
	var rack: O2Candle = O2Candle.new()
	root.add_child(rack)
	_check(rack.get_interaction_prompt() == "Light O2 candle (2 left)", "rack shows authored plus fabricated stock")
	rack.interact(null)
	_check(stores.get_count(&"o2_candle") == 1 and int(atmosphere.get_compartment_status(&"main")["candles_remaining"]) == 0, "authored stock consumed first without touching Stores")
	var burn: float = float(atmosphere.get_compartment_status(&"main")["candle_burn_remaining_hours"])
	var saved_atmosphere: Dictionary = atmosphere.save_state()
	var saved_stores: Dictionary = stores.save_state()
	rack.interact(null)
	_check(stores.get_count(&"o2_candle") == 0, "physical rack consumes one fabricated candle")
	_check(is_equal_approx(float(atmosphere.get_compartment_status(&"main")["candle_burn_remaining_hours"]), burn + config.o2_candle_burn_hours), "fabricated candle ignites through atmosphere burn state")
	_check(_events.count(&"o2_candle_lit") == 2, "each valid ignition emits existing feedback once")
	rack.interact(null)
	_check(_events.count(&"o2_candle_lit") == 2 and _events.back() == &"procedure_error", "empty rack reports error without extra ignition")
	atmosphere.load_state(JSON.parse_string(JSON.stringify(saved_atmosphere)) as Dictionary)
	stores.load_state(JSON.parse_string(JSON.stringify(saved_stores)) as Dictionary)
	rack.interact(null)
	_check(stores.get_count(&"o2_candle") == 0 and is_equal_approx(float(atmosphere.get_compartment_status(&"main")["candle_burn_remaining_hours"]), burn + config.o2_candle_burn_hours), "saved exhausted rack and fabricated stock continue exactly")
	stores.add_part(&"o2_candle", 1)
	rack.compartment_id = &"missing"
	var before: Dictionary = atmosphere.save_state()
	rack.interact(null)
	_check(stores.get_count(&"o2_candle") == 1 and atmosphere.save_state() == before, "invalid compartment cannot consume or ignite stored candle")
	rack.compartment_id = &"main"
	rack.enabled = false
	rack.interact(null)
	_check(stores.get_count(&"o2_candle") == 1, "disabled rack cannot consume stock")
	for node: Node in [rack, fabricator, power, cargo, stores, atmosphere]:
		node.free()
	_finish()


func _on_event(event_name: StringName, _payload: Dictionary) -> void:
	_events.append(event_name)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _finish() -> void:
	print("PASS: test_o2_candle_stock" if _failures == 0 else "FAILURES: %d" % _failures)
	quit(0 if _failures == 0 else 1)
