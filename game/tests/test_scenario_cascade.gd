## Scenario: a degraded RTG sheds the scrubber, CO2 climbs, and repair restores the air.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var harness: SimHarness = SimHarness.new(self)
	harness.setup_clock()

	var life_support: PowerCircuit = harness.make_circuit(&"life_support", 150.0, 0)
	var scrubber_circuit: PowerCircuit = harness.make_circuit(&"scrubber", 300.0, 1)
	var power: PowerSystem = harness.add_power([life_support, scrubber_circuit], 4000.0, {&"rtg_main": 500.0})
	power.battery_max_discharge_w = 150.0
	var rtg_wear: WearComponent = load("res://src/data/wear/rtg_main.tres") as WearComponent
	var wear_components: Array[WearComponent] = [rtg_wear]
	power.wear_components = wear_components

	var config: CompartmentConfig = harness.make_compartment(&"main")
	config.initial_occupants = 1
	config.initial_filter_condition = 0.9
	var defs: Array[CompartmentConfig] = [config]
	var atmosphere: AtmosphereSystem = harness.add_atmosphere(defs)

	var unit: ScrubberUnit = ScrubberUnit.new()
	unit.circuit_id = &"scrubber"
	root.add_child(unit)
	await process_frame

	_check(bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "scrubber runs while the bus is healthy")

	harness.clear_events()
	var healthy_generation_w: float = power.get_generation_w()
	_check(power.force_failure(&"rtg_main", &"rtg_degraded"), "forced rtg_degraded accepted")
	_check(absf(power.get_generation_w() - healthy_generation_w * 0.2) < 1e-6, "degraded RTG runs at 20 percent output")

	harness.advance(0.5)
	_check(power.is_brownout(), "brownout follows the degraded RTG")
	_check(power.is_circuit_shed(&"scrubber"), "scrubber circuit is shed under the degraded RTG")
	var shed_events: Array[Dictionary] = harness.events_named(&"circuit_shed")
	_check(shed_events.size() == 1, "exactly one circuit shed")
	if shed_events.size() == 1:
		_check(StringName(shed_events[0]["payload"]["circuit_id"]) == &"scrubber", "shedding picks the scrubber by priority")
	_check(not bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "shed circuit stops scrubbing in the sim")

	var sequence: PackedStringArray = harness.event_sequence()
	var failed_index: int = sequence.find("component_failed")
	var brownout_index: int = sequence.find("power_brownout")
	var shed_index: int = sequence.find("circuit_shed")
	_check(failed_index >= 0 and shed_index >= 0 and failed_index < shed_index, "component_failed precedes circuit_shed")
	_check(brownout_index >= 0 and shed_index >= 0 and brownout_index < shed_index, "power_brownout precedes circuit_shed")

	var climbed_from_ppm: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	harness.advance(4.0)
	var climbed_ppm: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	_check(climbed_ppm > climbed_from_ppm + 100.0, "CO2 climbs while the scrubber is shed")

	_check(power.repair_component(&"rtg_main", 1.0), "repair_component accepted")
	_check(absf(power.get_generation_w() - healthy_generation_w) < 1e-6, "repair restores RTG output")
	harness.advance(0.5)
	_check(not power.is_circuit_shed(&"scrubber"), "circuit restored after repair")
	_check(not power.is_brownout(), "brownout clears after repair")
	_check(bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "restored circuit resumes scrubbing")

	var sequence_after: PackedStringArray = harness.event_sequence()
	var repaired_index: int = sequence_after.find("component_repaired")
	var restored_index: int = sequence_after.find("circuit_restored")
	_check(repaired_index >= 0 and restored_index >= 0 and repaired_index < restored_index, "component_repaired precedes circuit_restored")

	harness.advance(1.0)
	_check(float(atmosphere.get_compartment_status(&"main")["co2_ppm"]) < climbed_ppm, "CO2 falls again after recovery")

	unit.free()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_scenario_cascade")
		quit(0)
	else:
		print("FAIL: test_scenario_cascade (%d checks failed)" % _failures)
		quit(1)
