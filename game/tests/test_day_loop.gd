extends SceneTree

var _failures: int = 0


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
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_filter_swap_loop()

	_finish()


func _test_filter_swap_loop() -> void:
	var atmosphere := AtmosphereSystem.new()
	var config := CompartmentConfig.new()
	config.compartment_id = &"main"
	config.volume_m3 = 60.0
	config.initial_occupants = 1
	config.initial_filter_condition = 0.15
	var defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = defs
	root.add_child(atmosphere)

	var stores := Stores.new()
	stores.initial_inventory = {&"filter_co2": 1}
	root.add_child(stores)

	var unit := ScrubberUnit.new()
	root.add_child(unit)

	var sim_clock: Node = _find_root_child(&"SimClock")
	var status: Dictionary = atmosphere.get_compartment_status(&"main")
	_check(int(status["occupants"]) == 1, "occupant from config feeds CO2 production")
	_check(absf(float(status["filter_condition"]) - 0.15) < 1e-9, "compartment starts with a worn filter")

	sim_clock.call("fast_forward", 4.0)
	status = atmosphere.get_compartment_status(&"main")
	var loaded_ppm: float = float(status["co2_ppm"])
	var worn_condition: float = float(status["filter_condition"])
	_check(loaded_ppm > 1000.0, "CO2 climbs while the filter is worn")
	_check(worn_condition < 0.15 and worn_condition > 0.12, "filter wears while scrubbing")

	_swap_filter(unit)
	status = atmosphere.get_compartment_status(&"main")
	_check(absf(float(status["filter_condition"]) - 1.0) < 1e-9, "swap installs a fresh filter")

	var panel := StatusPanel.new()
	root.add_child(panel)
	var readout: String = "\n".join(panel.build_readout())
	_check(readout.contains("SCRUBBER ON"), "readout shows the scrubber running after repair")
	_check(readout.contains("FILTER 100%"), "readout shows the fresh filter")
	_check(not readout.contains("FILTER 15%"), "readout no longer shows the worn filter")

	var before_ppm: float = float(status["co2_ppm"])
	sim_clock.call("fast_forward", 2.0)
	status = atmosphere.get_compartment_status(&"main")
	_check(float(status["co2_ppm"]) < before_ppm, "fresh filter pulls CO2 back down")

	atmosphere.free()
	stores.free()
	unit.free()
	panel.free()


func _swap_filter(unit: ScrubberUnit) -> void:
	unit.interact(null)
	unit.interact(null)
	unit.interact(null)
	unit.interact(null)
	unit.interact(null)
	unit.interact(null)
	unit.interact(null)
	_check(unit.is_powered(), "filter swap procedure completes powered up")


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_day_loop")
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
