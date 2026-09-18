## Three-day survivability scenario against the shipped balance data (§8.5 success test support).
## An attentive operator survives; total neglect warns within three days and kills by five.
extends SceneTree

const SCENARIO_HOURS: float = 72.0
const STEP_HOURS: float = 2.0
const FILTER_SWAP_THRESHOLD: float = 0.3

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_attentive_operator()
	_test_neglecting_operator()
	_finish()


func _test_attentive_operator() -> void:
	var samples: Array[Dictionary] = _run_scenario(true)
	_check(samples.size() == 36, "attentive: thirty-six samples across three days")

	var max_co2: float = 0.0
	var min_o2: float = 1.0
	var min_battery: float = 1.0
	var max_cognition: int = 0
	var any_brownout: bool = false
	var any_incapacitated: bool = false
	var any_damage: bool = false
	for sample: Dictionary in samples:
		max_co2 = maxf(max_co2, float(sample["co2_ppm"]))
		min_o2 = minf(min_o2, float(sample["o2_fraction"]))
		min_battery = minf(min_battery, float(sample["battery_fraction"]))
		max_cognition = maxi(max_cognition, int(sample["cognition"]))
		any_brownout = any_brownout or bool(sample["brownout"])
		any_incapacitated = any_incapacitated or bool(sample["incapacitated"])
		any_damage = any_damage or float(sample["condition"]) > 0.0

	_check(not any_incapacitated, "attentive: operator is never incapacitated")
	_check(not any_damage, "attentive: operator takes no exposure damage")
	_check(max_co2 < 3000.0, "attentive: CO2 stays well below cognitive thresholds (max %d ppm)" % int(max_co2))
	_check(min_o2 > 0.17, "attentive: O2 fraction stays above 17 percent (min %.3f)" % min_o2)
	_check(not any_brownout and min_battery > 0.5, "attentive: the bus never browns out and the battery stays charged")
	_check(max_cognition == 0, "attentive: cognition stays nominal")

	var final: Dictionary = samples[samples.size() - 1]
	_check(float(final["potable_l"]) > 50.0, "attentive: potable reserve holds (%.1f L)" % float(final["potable_l"]))
	_check(float(final["temperature_c"]) > 15.0 and float(final["temperature_c"]) < 25.0, "attentive: cabin temperature holds (%.1f C)" % float(final["temperature_c"]))
	_check(int(final["rations"]) == 3, "attentive: three rations consumed over three days (%d left)" % int(final["rations"]))


func _test_neglecting_operator() -> void:
	var samples: Array[Dictionary] = _run_scenario(false, 120.0)
	_check(samples.size() == 60, "neglect: sixty samples across five days")

	var max_co2: float = 0.0
	var max_cognition: int = 0
	var any_incapacitated: bool = false
	var warned_before_incapacitation: bool = false
	var severe_within_three_days: bool = false
	var cause: StringName = &""
	for sample: Dictionary in samples:
		max_co2 = maxf(max_co2, float(sample["co2_ppm"]))
		max_cognition = maxi(max_cognition, int(sample["cognition"]))
		if not any_incapacitated and int(sample["cognition"]) >= 2:
			warned_before_incapacitation = true
		if float(sample["hours"]) <= 72.0 and float(sample["co2_ppm"]) > 15000.0:
			severe_within_three_days = true
		if bool(sample["incapacitated"]):
			any_incapacitated = true
			if cause == &"":
				cause = StringName(sample["cause"])

	_check(severe_within_three_days, "neglect: severe cognition warnings arrive within the three-day window")
	_check(max_cognition >= 2, "neglect: cognition effects reach level 2 or worse")
	_check(max_co2 > 25000.0, "neglect: CO2 crosses the breathing damage threshold (max %d ppm)" % int(max_co2))
	_check(warned_before_incapacitation, "neglect: warnings arrive before incapacitation")
	_check(any_incapacitated, "neglect: total inaction is fatal within five days")
	_check(cause == &"carbon_dioxide", "neglect: the recorded cause is carbon dioxide")


func _run_scenario(attentive: bool, hours: float = SCENARIO_HOURS) -> Array[Dictionary]:
	var harness := SimHarness.new(self)
	harness.setup_clock()

	var life_support: PowerCircuit = load("res://src/data/power/circuit_life_support.tres")
	var scrubber_circuit: PowerCircuit = load("res://src/data/power/circuit_scrubber.tres")
	var lighting: PowerCircuit = load("res://src/data/power/circuit_lighting.tres")
	var circuits: Array[PowerCircuit] = [life_support, scrubber_circuit, lighting]
	var power: PowerSystem = harness.add_power(circuits, 4000.0, {&"rtg_main": 500.0})

	var stores: Stores = harness.add_stores({&"food_ration": 6})
	var main_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_main.tres")
	var quarters_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_quarters.tres")
	var defs: Array[CompartmentConfig] = [main_config, quarters_config]
	var atmosphere: AtmosphereSystem = harness.add_atmosphere(defs)
	atmosphere.connect_compartments(&"main", &"quarters")
	var thermal: ThermalSystem = harness.add_thermal(defs)
	var hull := HullSystem.new()
	hull.compartment_defs = defs
	root.add_child(hull)
	var water := WaterSystem.new()
	root.add_child(water)
	water.set_reclaimer_powered(true)
	var vitals := VitalsSystem.new()
	root.add_child(vitals)
	var scrubber := ScrubberUnit.new()
	scrubber.compartment_id = &"main"
	scrubber.circuit_id = &"scrubber"
	root.add_child(scrubber)
	atmosphere.set_occupants(&"main", 0)
	atmosphere.set_occupants(&"quarters", 1)

	if attentive:
		atmosphere.set_filter_condition(&"main", 1.0)

	var samples: Array[Dictionary] = []
	var elapsed: float = 0.0
	while elapsed < hours:
		harness.advance(STEP_HOURS)
		elapsed += STEP_HOURS
		if attentive:
			_service(atmosphere, thermal, hull, power)
		samples.append(_sample(elapsed, atmosphere, thermal, water, vitals, power, stores))

	stores.free()
	power.free()
	atmosphere.free()
	thermal.free()
	hull.free()
	water.free()
	vitals.free()
	scrubber.free()
	return samples


func _service(atmosphere: AtmosphereSystem, thermal: ThermalSystem, hull: HullSystem, power: PowerSystem) -> void:
	if float(atmosphere.get_compartment_status(&"main")["filter_condition"]) < FILTER_SWAP_THRESHOLD:
		atmosphere.set_filter_condition(&"main", 1.0)
		atmosphere.set_filter_installed(&"main", true)
	while hull.get_puncture_count(&"main") > 0:
		hull.patch_puncture(&"main", 0.9)
	for system: Node in [power, atmosphere, thermal, hull]:
		var wear: Dictionary = system.call("get_wear_status")
		for key: Variant in wear.keys():
			if bool(wear[key]["failed"]):
				system.call("repair_component", key, 1.0)


func _sample(elapsed: float, atmosphere: AtmosphereSystem, thermal: ThermalSystem, water: WaterSystem, vitals: VitalsSystem, power: PowerSystem, stores: Stores) -> Dictionary:
	var atmosphere_status: Dictionary = atmosphere.get_compartment_status(&"main")
	var thermal_status: Dictionary = thermal.get_compartment_status(&"main")
	var vitals_status: Dictionary = vitals.get_status()
	return {
		"hours": elapsed,
		"co2_ppm": float(atmosphere_status["co2_ppm"]),
		"o2_fraction": float(atmosphere_status["o2_fraction"]),
		"temperature_c": float(thermal_status["temperature_c"]),
		"potable_l": float(water.get_status()["potable_l"]),
		"condition": float(vitals_status["condition"]),
		"cognition": int(vitals_status["cognition_level"]),
		"incapacitated": bool(vitals_status["incapacitated"]),
		"cause": StringName(vitals_status["cause"]),
		"battery_fraction": power.get_battery_charge(),
		"brownout": power.is_brownout(),
		"rations": stores.get_count(&"food_ration"),
	}


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_survival_3day")
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
