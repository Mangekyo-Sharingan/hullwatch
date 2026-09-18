## Scenario: a hull puncture and O2 candle burn raise humidity past the condensation threshold,
## the RTG then trips and sheds the scrubber, and repair recovers the air.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var harness: SimHarness = SimHarness.new(self)
	harness.setup_clock()

	var life_support: PowerCircuit = load("res://src/data/power/circuit_life_support.tres")
	var scrubber_circuit: PowerCircuit = load("res://src/data/power/circuit_scrubber.tres")
	var lighting: PowerCircuit = load("res://src/data/power/circuit_lighting.tres")
	var circuits: Array[PowerCircuit] = [life_support, scrubber_circuit, lighting]
	var power: PowerSystem = harness.add_power(circuits, 4000.0, {&"rtg_main": 500.0})
	power.battery_max_discharge_w = 0.0
	var rtg_wear: WearComponent = load("res://src/data/wear/rtg_main.tres") as WearComponent
	var power_wear: Array[WearComponent] = [rtg_wear]
	power.wear_components = power_wear

	var main_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_main.tres")
	var defs: Array[CompartmentConfig] = [main_config]
	var atmosphere: AtmosphereSystem = harness.add_atmosphere(defs)
	atmosphere.set_occupants(&"main", 0)
	var thermal: ThermalSystem = harness.add_thermal(defs)
	var hull: HullSystem = HullSystem.new()
	hull.compartment_defs = defs
	root.add_child(hull)
	var unit: ScrubberUnit = ScrubberUnit.new()
	unit.compartment_id = &"main"
	unit.circuit_id = &"scrubber"
	root.add_child(unit)
	await process_frame

	unit.interact(null)
	_check(not unit.is_powered(), "scrubber deliberately left off before the cascade")
	_check(not bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "scrubber power is gated off in the sim")

	harness.clear_events()
	_check(hull.add_puncture(&"main", 1.0), "hull puncture accepted")
	_check(atmosphere.light_o2_candle(&"main"), "first O2 candle lit")
	_check(atmosphere.light_o2_candle(&"main"), "second stocked candle lit")

	harness.advance(10.0)
	var humidity_fraction: float = float(atmosphere.get_compartment_status(&"main")["humidity_fraction"])
	_check(humidity_fraction > 0.7, "candle burn lifts humidity above the condensation threshold (%.3f)" % humidity_fraction)
	var wear_humidity: float = float(power.get_wear_environment().get("humidity", 0.0))
	_check(wear_humidity > 0.7, "power wear environment reads the humid compartment (%.3f)" % wear_humidity)

	var rise_sequence: PackedStringArray = harness.event_sequence()
	var puncture_index: int = rise_sequence.find("hull_puncture")
	var humidity_index: int = rise_sequence.find("compartment_humidity_changed")
	_check(puncture_index >= 0 and humidity_index >= 0 and puncture_index < humidity_index, "hull_puncture precedes compartment_humidity_changed")

	harness.clear_events()
	_check(power.force_failure(&"rtg_main", &"rtg_open_circuit"), "forced rtg_open_circuit accepted")
	harness.advance(0.5)
	_check(power.get_generation_w() == 0.0, "open circuit zeroes generation")
	_check(power.is_brownout(), "brownout follows the RTG trip")
	_check(power.is_circuit_shed(&"lighting"), "lighting circuit is shed under the brownout")
	var failure_sequence: PackedStringArray = harness.event_sequence()
	var failed_index: int = failure_sequence.find("component_failed")
	var shed_index: int = failure_sequence.find("circuit_shed")
	_check(failed_index >= 0 and shed_index >= 0 and failed_index < shed_index, "component_failed precedes circuit_shed")

	harness.clear_events()
	_check(power.repair_component(&"rtg_main", 1.0), "repair_component accepted")
	unit.set(&"_ready_to_power", true)
	unit.interact(null)
	_check(unit.is_powered(), "scrubber switched back on after repair")

	harness.advance(8.0)
	var recovered_fraction: float = float(atmosphere.get_compartment_status(&"main")["humidity_fraction"])
	_check(recovered_fraction < 0.7, "humidity falls below the condensation threshold after recovery (%.3f)" % recovered_fraction)
	_check(not power.is_circuit_shed(&"lighting"), "lighting circuit comes back after repair")
	_check(not power.is_brownout(), "brownout clears after repair")
	_check(bool(atmosphere.get_compartment_status(&"main")["scrubber_powered"]), "scrubber runs once its circuit is restored")

	var recovery_sequence: PackedStringArray = harness.event_sequence()
	var repaired_index: int = recovery_sequence.find("component_repaired")
	var recovery_humidity_index: int = recovery_sequence.find("compartment_humidity_changed")
	_check(repaired_index >= 0 and recovery_humidity_index >= 0 and repaired_index < recovery_humidity_index, "component_repaired precedes humidity recovery")

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
		print("PASS: test_scenario_humidity")
		quit(0)
	else:
		print("FAIL: test_scenario_humidity (%d checks failed)" % _failures)
		quit(1)
