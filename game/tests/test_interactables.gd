extends SceneTree

var _failures: int = 0
var _procedure_errors: int = 0
var _last_error_reason: StringName = &""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()

	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	event_bus.connect(&"sim_event", _on_sim_event)

	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_scrubber_procedure()
	_test_scrubber_no_stock()
	_test_breaker_panel()
	_test_bunk()

	_finish()


func _test_scrubber_procedure() -> void:
	var power: PowerSystem = _make_power()
	var atmosphere: AtmosphereSystem = _make_atmosphere()
	var stores: Stores = _make_stores(1)
	var unit: ScrubberUnit = _make_scrubber()

	_check(unit.is_powered() and not unit.is_housing_open() and unit.has_filter(), "scrubber starts powered with filter")
	var status: Dictionary = atmosphere.get_compartment_status(&"main")
	_check(bool(status["scrubber_powered"]) and bool(status["filter_installed"]), "unit syncs scrubber state to sim")

	unit.interact(null)
	_check(not unit.is_powered(), "first step powers down")
	status = atmosphere.get_compartment_status(&"main")
	_check(not bool(status["scrubber_powered"]), "power down reaches sim")

	unit.interact(null)
	_check(unit.is_housing_open(), "second step opens housing")
	_check(unit.get_interaction_prompt() == "Remove filter", "prompt asks for filter removal")

	unit.interact(null)
	_check(not unit.has_filter(), "third step removes filter")
	status = atmosphere.get_compartment_status(&"main")
	_check(not bool(status["filter_installed"]), "filter removal reaches sim")

	unit.interact(null)
	_check(unit.has_filter() and stores.get_count(&"filter_co2") == 0, "install consumes a filter from stores")
	_check(not unit.is_seal_seated(), "seal is unseated after install")
	status = atmosphere.get_compartment_status(&"main")
	_check(bool(status["filter_installed"]) and absf(float(status["filter_condition"]) - 1.0) < 1e-9, "installed filter is fresh in sim")

	unit.interact(null)
	_check(unit.is_seal_seated(), "seal seated")
	_check(unit.get_interaction_prompt() == "Close housing", "prompt asks to close")

	unit.interact(null)
	_check(not unit.is_housing_open(), "housing closed")
	_check(unit.get_interaction_prompt() == "Power up", "prompt asks to power up")

	unit.interact(null)
	_check(unit.is_powered(), "unit powered back on")
	status = atmosphere.get_compartment_status(&"main")
	_check(bool(status["scrubber_powered"]), "power up reaches sim")

	power.free()
	atmosphere.free()
	stores.free()
	unit.free()


func _test_scrubber_no_stock() -> void:
	_procedure_errors = 0
	var atmosphere: AtmosphereSystem = _make_atmosphere()
	var stores: Stores = _make_stores(0)
	var unit: ScrubberUnit = _make_scrubber()

	unit.interact(null)
	unit.interact(null)
	unit.interact(null)
	unit.interact(null)
	_check(not unit.has_filter(), "install without stock leaves housing empty")
	_check(_procedure_errors == 1 and _last_error_reason == &"no_filter_stock", "no-stock procedure error emitted")
	_check(unit.get_interaction_prompt() == "Install filter", "prompt still asks for filter")

	atmosphere.free()
	stores.free()
	unit.free()


func _test_breaker_panel() -> void:
	var power: PowerSystem = _make_power()
	var panel := BreakerPanel.new()
	panel.circuit_id = &"lighting"
	root.add_child(panel)

	_check(power.is_breaker_on(&"lighting"), "breaker starts on")
	panel.interact(null)
	_check(not power.is_breaker_on(&"lighting"), "panel toggles breaker off")
	panel.interact(null)
	_check(power.is_breaker_on(&"lighting"), "panel toggles breaker on")

	power.free()
	panel.free()


func _test_bunk() -> void:
	var sim_clock: Node = _find_root_child(&"SimClock")
	if sim_clock == null:
		_check(false, "test SimClock present")
		return
	var bunk := Bunk.new()
	bunk.sleep_hours = 8.0
	root.add_child(bunk)

	bunk.interact(null)
	var hours: float = sim_clock.call("get_total_hours")
	_check(absf(hours - 8.0) < 0.01, "bunk fast-forwards the sim clock by sleep_hours")
	_check(int(sim_clock.call("get_day")) == 1, "8h sleep from midnight stays on day 1")

	bunk.free()


func _make_power() -> PowerSystem:
	var power := PowerSystem.new()
	var scrubber_circuit := PowerCircuit.new()
	scrubber_circuit.circuit_id = &"scrubber"
	scrubber_circuit.nominal_load_w = 400.0
	scrubber_circuit.priority = 1
	var lighting := PowerCircuit.new()
	lighting.circuit_id = &"lighting"
	lighting.display_name = "Lighting"
	lighting.nominal_load_w = 200.0
	lighting.priority = 2
	var defs: Array[PowerCircuit] = [scrubber_circuit, lighting]
	power.circuit_defs = defs
	root.add_child(power)
	return power


func _make_atmosphere() -> AtmosphereSystem:
	var atmosphere := AtmosphereSystem.new()
	var config := CompartmentConfig.new()
	config.compartment_id = &"main"
	config.volume_m3 = 60.0
	var defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = defs
	root.add_child(atmosphere)
	return atmosphere


func _make_stores(filter_count: int) -> Stores:
	var stores := Stores.new()
	stores.initial_inventory = {&"filter_co2": filter_count}
	root.add_child(stores)
	return stores


func _make_scrubber() -> ScrubberUnit:
	var unit := ScrubberUnit.new()
	root.add_child(unit)
	return unit


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"procedure_error":
		_procedure_errors += 1
		_last_error_reason = payload.get("reason", &"")


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_interactables")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
