## Scenario: degraded generation sheds the scrubber circuit, CO2 climbs, recovery restores it.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var harness := SimHarness.new(self)
	harness.setup_clock()

	var life_support: PowerCircuit = harness.make_circuit(&"life_support", 150.0, 0)
	var scrubber_circuit: PowerCircuit = harness.make_circuit(&"scrubber", 400.0, 1)
	var power: PowerSystem = harness.add_power([life_support, scrubber_circuit], 4000.0, {&"rtg_main": 500.0})
	power.battery_max_discharge_w = 150.0

	var config: CompartmentConfig = harness.make_compartment(&"main")
	config.initial_occupants = 1
	config.initial_filter_condition = 0.9
	var defs: Array[CompartmentConfig] = [config]
	var atmosphere: AtmosphereSystem = harness.add_atmosphere(defs)

	var unit := ScrubberUnit.new()
	unit.circuit_id = &"scrubber"
	root.add_child(unit)
	await process_frame

	_check(bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "scrubber runs while the bus is healthy")

	power.set_generation(&"rtg_main", 100.0)
	harness.advance(0.5)
	var shed_events: Array[Dictionary] = harness.events_named(&"circuit_shed")
	_check(shed_events.size() == 1, "degraded generation sheds exactly one circuit")
	if shed_events.size() == 1:
		_check(StringName(shed_events[0]["payload"]["circuit_id"]) == &"scrubber", "shedding picks the scrubber by priority")
	_check(not bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "shed circuit stops scrubbing in the sim")

	var drained_ppm: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	harness.advance(4.0)
	var climbed_ppm: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	_check(climbed_ppm > drained_ppm + 100.0, "CO2 climbs while the scrubber is shed")

	power.set_generation(&"rtg_main", 500.0)
	harness.advance(0.5)
	var restored: Array[Dictionary] = harness.events_named(&"circuit_restored")
	_check(restored.size() >= 1, "recovered generation restores the circuit")
	_check(bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "restored circuit resumes scrubbing")

	harness.advance(1.0)
	_check(float(atmosphere.get_compartment_status(&"main")["co2_ppm"]) < climbed_ppm, "CO2 falls again after recovery")

	var sequence: PackedStringArray = harness.event_sequence()
	_check(sequence.has("circuit_shed") and sequence.has("circuit_restored"), "harness captured a traceable event chain")
	_check(sequence.find("circuit_shed") < sequence.find("circuit_restored"), "events are ordered shed before restored")

	unit.free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_scenario_power_night")
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
