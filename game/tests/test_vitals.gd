extends SceneTree

var _failures: int = 0
var _harness: SimHarness
var _spawned: Array[Node] = []
var _typed_events: Array[Dictionary] = []
var _vitals: VitalsSystem
var _atmosphere: AtmosphereSystem
var _thermal: ThermalSystem


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_harness = SimHarness.new(self)
	_harness.setup_clock()
	_connect_typed_signals()

	_test_incapacitation_carbon_dioxide()
	_test_incapacitation_oxygen()
	_test_incapacitation_hypothermia()
	_test_recovery_when_nominal()
	_test_cognition_climb()
	_test_cognition_condition_driven()
	_test_resuscitate()
	_test_save_load()
	_test_missing_systems()
	_test_indicators()
	_test_loss_overlay()

	_finish()


func _test_incapacitation_carbon_dioxide() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.21, 30000.0, 21.0, 1)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	for i: int in 8:
		_harness.advance(0.5)
	var status: Dictionary = _vitals.get_status()
	_check(float(status["condition"]) >= 1.0, "co2: severe CO2 degrades condition to incapacitation")
	_check(bool(status["incapacitated"]), "co2: operator incapacitated")
	_check(StringName(status["cause"]) == &"carbon_dioxide", "co2: cause is carbon_dioxide")
	_check(_typed_named(&"operator_incapacitated").size() == 1, "co2: typed operator_incapacitated emitted once")
	_check(_harness.events_named(&"operator_incapacitated").size() == 1, "co2: sim operator_incapacitated emitted once")
	_check(_typed_named(&"operator_condition_changed").size() >= 4, "co2: condition changes reported")
	_despawn_all()


func _test_incapacitation_oxygen() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.05, 400.0, 21.0, 1)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	for i: int in 8:
		_harness.advance(0.5)
	var status: Dictionary = _vitals.get_status()
	_check(bool(status["incapacitated"]), "oxygen: low O2 incapacitates")
	_check(StringName(status["cause"]) == &"oxygen", "oxygen: cause is oxygen")
	_despawn_all()


func _test_incapacitation_hypothermia() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.21, 400.0, 0.0, 1, 0.0, 0.0)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	_thermal.set_heater_powered(&"main", false)
	for i: int in 8:
		_harness.advance(0.5)
	var status: Dictionary = _vitals.get_status()
	_check(bool(status["incapacitated"]), "cold: severe cold incapacitates")
	_check(StringName(status["cause"]) == &"hypothermia", "cold: cause is hypothermia")
	_despawn_all()


func _test_recovery_when_nominal() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var cold: CompartmentConfig = _make_config(&"main", 0.21, 400.0, 5.0, 1, 0.0, 0.0)
	var warm: CompartmentConfig = _make_config(&"safe", 0.21, 400.0, 21.0, 0, 0.0, 0.0)
	var defs: Array[CompartmentConfig] = [cold, warm]
	_add_world(defs)
	_thermal.set_heater_powered(&"main", false)
	_harness.advance(2.0)
	var damaged: float = float(_vitals.get_status()["condition"])
	_check(damaged > 0.05, "recovery: mild cold degrades condition")
	_check(damaged < 0.7, "recovery: mild exposure stays below incapacitation")
	_check(_vitals.get_cognition_level() == 2, "recovery: mild cold lifts cognition to level 2")
	_atmosphere.set_occupants(&"main", 0)
	_atmosphere.set_occupants(&"safe", 1)
	_harness.advance(1.0)
	var recovered: float = float(_vitals.get_status()["condition"])
	_check(recovered < damaged, "recovery: nominal conditions lower condition")
	_check(is_equal_approx(recovered, 0.0), "recovery: recovery reaches zero")
	_check(_vitals.get_cognition_level() == 0, "recovery: cognition returns to level 0")
	_despawn_all()


func _test_cognition_climb() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.30, 4000.0, 21.0, 10)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	var observed: Array[int] = [_vitals.get_cognition_level()]
	for i: int in 14:
		_harness.advance(0.5)
		var level: int = _vitals.get_cognition_level()
		if level != observed[observed.size() - 1]:
			observed.append(level)
	var expected: Array[int] = [0, 1, 2, 3]
	_check(observed == expected, "cognition: levels step 0 to 1 to 2 to 3 as CO2 climbs")
	var typed_levels: Array[int] = _typed_levels()
	var typed_expected: Array[int] = [1, 2, 3]
	_check(typed_levels == typed_expected, "cognition: typed effect changes reported once per step")
	_despawn_all()


func _test_cognition_condition_driven() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.21, 400.0, 5.0, 1, 0.0, 0.0)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	_thermal.set_heater_powered(&"main", false)
	_harness.advance(5.0)
	_check(float(_vitals.get_status()["condition"]) < 0.7, "condition: below level 3 threshold at 5 h")
	_check(_vitals.get_cognition_level() == 2, "condition: level 2 from mild cold before threshold")
	_harness.advance(3.0)
	_check(float(_vitals.get_status()["condition"]) >= 0.7, "condition: crosses 0.7 after 8 h")
	_check(_vitals.get_cognition_level() == 3, "condition: level 3 once condition reaches 0.7")
	_despawn_all()


func _test_resuscitate() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.21, 400.0, 21.0, 1)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	_vitals.load_state({
		"condition": 1.0,
		"incapacitated": true,
		"cause": "oxygen",
		"cognition_level": 3,
		"last_emitted_bucket": 20,
	})
	_check(bool(_vitals.get_status()["incapacitated"]), "resuscitate: loaded loss state present")
	_vitals.resuscitate()
	var status: Dictionary = _vitals.get_status()
	_check(is_equal_approx(float(status["condition"]), 0.0), "resuscitate: condition reset")
	_check(not bool(status["incapacitated"]), "resuscitate: incapacitation cleared")
	_check(StringName(status["cause"]) == &"", "resuscitate: cause cleared")
	_harness.advance(0.1)
	_check(_vitals.get_cognition_level() == 0, "resuscitate: cognition returns to nominal on the next tick")
	_despawn_all()


func _test_save_load() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.21, 400.0, 5.0, 1, 0.0, 0.0)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	_thermal.set_heater_powered(&"main", false)
	_harness.advance(2.0)
	var saved: Dictionary = _vitals.save_state()
	_check(saved["system_id"] == "vitals", "save: system_id is vitals")
	_check(int(saved["state_version"]) == 1, "save: state_version is 1")
	var json_text: String = JSON.stringify(saved)
	var parsed: Variant = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "save: JSON round trip parses to Dictionary")
	var parsed_dict: Dictionary = parsed if parsed is Dictionary else {}
	var saved_condition: float = float(parsed_dict.get("condition", -1.0))
	var saved_cognition: int = int(parsed_dict.get("cognition_level", -1))
	_check(saved_condition > 0.0, "save: condition captured")
	_check(saved_cognition == 2, "save: cognition captured at level 2")
	_harness.advance(1.0)
	_check(absf(float(_vitals.get_status()["condition"]) - saved_condition) > 0.01, "save: state diverges before load")
	_vitals.load_state(parsed_dict)
	var status: Dictionary = _vitals.get_status()
	_check(is_equal_approx(float(status["condition"]), saved_condition), "save: condition restored from JSON")
	_check(int(status["cognition_level"]) == saved_cognition, "save: cognition restored from JSON")
	_despawn_all()


func _test_missing_systems() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.21, 400.0, 5.0, 1, 0.0, 0.0)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	_thermal.set_heater_powered(&"main", false)
	_harness.advance(1.0)
	var damaged: float = float(_vitals.get_status()["condition"])
	_check(damaged > 0.0, "missing: precondition established")
	_atmosphere.free()
	_thermal.free()
	_harness.advance(1.0)
	var status: Dictionary = _vitals.get_status()
	_check(is_equal_approx(float(status["condition"]), damaged), "missing: condition unchanged without atmosphere or thermal")
	_check(StringName(status["manned_compartment"]) == &"", "missing: manned compartment cleared")
	_check(not bool(status["incapacitated"]), "missing: no spurious incapacitation")
	_despawn_all()


func _test_indicators() -> void:
	var bus: Node = _bus()
	if bus == null:
		_check(false, "indicators: EventBus available")
		return
	var indicators: CanvasLayer = load("res://src/ui/indicators.gd").new()
	root.add_child(indicators)
	_spawned.append(indicators)
	_check(is_equal_approx(float(indicators.call(&"get_vignette_intensity")), 0.0), "indicators: nominal leaves the vignette clear")
	bus.emit_signal(&"cognition_effect_changed", 1)
	_check(is_equal_approx(float(indicators.call(&"get_vignette_intensity")), 0.25), "indicators: level 1 intensity 0.25")
	bus.emit_signal(&"cognition_effect_changed", 2)
	_check(is_equal_approx(float(indicators.call(&"get_vignette_intensity")), 0.5), "indicators: level 2 intensity 0.5")
	bus.emit_signal(&"cognition_effect_changed", 3)
	_check(is_equal_approx(float(indicators.call(&"get_vignette_intensity")), 0.8), "indicators: level 3 intensity 0.8")
	bus.emit_signal(&"cognition_effect_changed", 0)
	_check(is_equal_approx(float(indicators.call(&"get_vignette_intensity")), 0.0), "indicators: recovery clears the vignette")
	_despawn_all()


func _test_loss_overlay() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var config: CompartmentConfig = _make_config(&"main", 0.05, 400.0, 21.0, 1)
	var defs: Array[CompartmentConfig] = [config]
	_add_world(defs)
	var overlay: CanvasLayer = load("res://src/ui/loss_overlay.gd").new()
	root.add_child(overlay)
	_spawned.append(overlay)
	_check(not bool(overlay.call(&"is_visible_overlay")), "overlay: hidden before incapacitation")
	_harness.advance(3.0)
	_check(bool(overlay.call(&"is_visible_overlay")), "overlay: appears when the operator is incapacitated")
	_check(String(overlay.call(&"get_cause_text")) == "OXYGEN", "overlay: names the incapacitation cause")
	_press_interact()
	_check(not bool(overlay.call(&"is_visible_overlay")), "overlay: hides after the mercy press")
	var status: Dictionary = _vitals.get_status()
	_check(is_equal_approx(float(status["condition"]), 0.0), "overlay: mercy resuscitates the operator")
	_check(not bool(status["incapacitated"]), "overlay: mercy clears incapacitation")
	var typed_mercy: Array[Dictionary] = _typed_named(&"mercy_recovery_used")
	_check(typed_mercy.size() == 1, "overlay: typed mercy_recovery_used emitted")
	if typed_mercy.size() == 1:
		_check(StringName(typed_mercy[0]["args"][0]) == &"oxygen", "overlay: mercy carries the cause")
	_check(_harness.events_named(&"mercy_recovery_used").size() == 1, "overlay: sim mercy_recovery_used emitted")
	_despawn_all()


func _make_config(
	compartment_id: StringName,
	o2_fraction: float = 0.21,
	co2_ppm: float = 400.0,
	temperature_c: float = 21.0,
	occupants: int = 1,
	hull_conductance_w_per_k: float = 3.0,
	occupant_heat_w: float = 100.0
) -> CompartmentConfig:
	var config: CompartmentConfig = _harness.make_compartment(compartment_id)
	config.initial_o2_fraction = o2_fraction
	config.initial_co2_ppm = co2_ppm
	config.initial_temperature_c = temperature_c
	config.initial_occupants = occupants
	config.hull_conductance_w_per_k = hull_conductance_w_per_k
	config.occupant_heat_w = occupant_heat_w
	return config


func _add_world(configs: Array[CompartmentConfig]) -> void:
	_atmosphere = _harness.add_atmosphere(configs)
	_spawned.append(_atmosphere)
	_thermal = _harness.add_thermal(configs)
	_spawned.append(_thermal)
	_vitals = VitalsSystem.new()
	_spawned.append(_vitals)
	root.add_child(_vitals)


func _press_interact() -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	root.push_input(event)


func _bus() -> Node:
	return root.get_node_or_null(^"/root/EventBus")


func _connect_typed_signals() -> void:
	var bus: Node = _bus()
	if bus == null:
		return
	bus.connect(&"operator_condition_changed", _on_operator_condition_changed)
	bus.connect(&"operator_incapacitated", _on_operator_incapacitated)
	bus.connect(&"cognition_effect_changed", _on_cognition_effect_changed)
	bus.connect(&"mercy_recovery_used", _on_mercy_recovery_used)


func _on_operator_condition_changed(condition: float, cause: StringName) -> void:
	_typed_events.append({"name": &"operator_condition_changed", "args": [condition, cause]})


func _on_operator_incapacitated(cause: StringName) -> void:
	_typed_events.append({"name": &"operator_incapacitated", "args": [cause]})


func _on_cognition_effect_changed(level: int) -> void:
	_typed_events.append({"name": &"cognition_effect_changed", "args": [level]})


func _on_mercy_recovery_used(cause: StringName) -> void:
	_typed_events.append({"name": &"mercy_recovery_used", "args": [cause]})


func _typed_named(event_name: StringName) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for event: Dictionary in _typed_events:
		if event["name"] == event_name:
			matched.append(event)
	return matched


func _typed_levels() -> Array[int]:
	var levels: Array[int] = []
	for event: Dictionary in _typed_named(&"cognition_effect_changed"):
		levels.append(int(event["args"][0]))
	return levels


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_vitals")
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
