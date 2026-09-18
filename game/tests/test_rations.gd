## Ration stock economy: the crew draws from Stores, and starvation mirrors dehydration as a vitals cause.
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

	_test_one_occupant_consumption()
	_test_two_occupants_consumption()
	_test_no_occupants()
	_test_stores_absent()
	_test_starvation_incapacitates()
	_test_restock_recovers()
	_test_dehydration_priority()
	_test_save_load_accumulator()

	_finish()


func _test_one_occupant_consumption() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var stores: Stores = _harness.add_stores({&"food_ration": 6})
	_spawned.append(stores)
	_build_world(1)
	_harness.advance(24.0)
	_check(stores.get_count(&"food_ration") == 5, "one occupant: 24 h consumes exactly one ration (6 to 5)")
	var consumed: Array[Dictionary] = _harness.events_named(&"ration_consumed")
	_check(consumed.size() == 1, "one occupant: ration_consumed emitted once in 24 h")
	if consumed.size() == 1:
		_check(int(consumed[0]["payload"].get("remaining", -1)) == 5, "one occupant: event payload reports the remaining stock")
	_harness.advance(24.0)
	_check(stores.get_count(&"food_ration") == 4, "one occupant: 48 h consumes two rations (6 to 4)")
	_check(_harness.events_named(&"ration_consumed").size() == 2, "one occupant: the second day emits a second ration_consumed")
	_despawn_all()


func _test_two_occupants_consumption() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var stores: Stores = _harness.add_stores({&"food_ration": 6})
	_spawned.append(stores)
	_build_world(2)
	_harness.advance(24.0)
	_check(stores.get_count(&"food_ration") == 4, "two occupants: 24 h consumes two rations")
	_check(_harness.events_named(&"ration_consumed").size() == 2, "two occupants: one ration_consumed event per ration")
	_despawn_all()


func _test_no_occupants() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var stores: Stores = _harness.add_stores({&"food_ration": 6})
	_spawned.append(stores)
	_build_world(0)
	_harness.advance(24.0)
	_check(stores.get_count(&"food_ration") == 6, "no occupants: stock is untouched")
	_check(_harness.events_named(&"ration_consumed").is_empty(), "no occupants: no ration_consumed events")
	_check(is_equal_approx(float(_vitals.get_status()["condition"]), 0.0), "no occupants: no starvation damage")
	_despawn_all()


func _test_stores_absent() -> void:
	_harness.clear_events()
	_typed_events.clear()
	_build_world(1)
	_harness.advance(24.0)
	var status: Dictionary = _vitals.get_status()
	_check(is_equal_approx(float(status["condition"]), 0.0), "stores absent: condition stays nominal over 24 h")
	_check(not bool(status["incapacitated"]), "stores absent: no starvation incapacitation")
	_check(_harness.events_named(&"ration_consumed").is_empty(), "stores absent: no ration_consumed events")
	_despawn_all()


func _test_starvation_incapacitates() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var stores: Stores = _harness.add_stores({})
	_spawned.append(stores)
	_build_world(1)
	_harness.advance(1.0)
	_check(_vitals.get_cause() == &"starvation", "starvation: empty stock reports the starvation cause")
	_check(_vitals.get_cognition_level() == 3, "starvation: severe condition forces cognition level 3")
	_harness.advance(7.0)
	var status: Dictionary = _vitals.get_status()
	_check(float(status["condition"]) >= 1.0, "starvation: empty stock damages the operator to incapacitation")
	_check(bool(status["incapacitated"]), "starvation: operator incapacitated")
	_check(StringName(status["cause"]) == &"starvation", "starvation: incapacitation cause is starvation")
	var typed: Array[Dictionary] = _typed_named(&"operator_incapacitated")
	_check(typed.size() == 1, "starvation: EventBus operator_incapacitated emitted once")
	if typed.size() == 1:
		_check(StringName(typed[0]["args"][0]) == &"starvation", "starvation: EventBus event carries the starvation cause")
	_check(_harness.events_named(&"operator_incapacitated").size() == 1, "starvation: sim operator_incapacitated emitted once")
	_check(_harness.events_named(&"ration_consumed").is_empty(), "starvation: no ration drawn from an empty stock")
	_despawn_all()


func _test_restock_recovers() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var stores: Stores = _harness.add_stores({})
	_spawned.append(stores)
	_build_world(1)
	_harness.advance(2.0)
	var damaged: float = float(_vitals.get_status()["condition"])
	_check(damaged > 0.05, "restock: empty stock damages the operator")
	_check(_vitals.get_cause() == &"starvation", "restock: precondition is starvation")
	stores.add_part(&"food_ration", 3)
	_harness.clear_events()
	_harness.advance(26.0)
	_check(_vitals.get_cause() != &"starvation", "restock: cause clears once food is aboard")
	_check(float(_vitals.get_status()["condition"]) < damaged, "restock: damage stops and condition recovers")
	_check(stores.get_count(&"food_ration") == 2, "restock: consumption resumes (one ration drawn by hour 24)")
	_check(_harness.events_named(&"ration_consumed").size() == 1, "restock: ration_consumed fires again after the restock")
	_despawn_all()


func _test_dehydration_priority() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var stores: Stores = _harness.add_stores({})
	_spawned.append(stores)
	_build_world(1)
	_add_water(0.0)
	_harness.advance(1.0)
	_check(_vitals.get_cause() == &"dehydration", "priority: dehydration outranks starvation when both stores are empty")
	_check(_vitals.get_cognition_level() == 3, "priority: cognition stays forced to level 3")
	_check(float(_vitals.get_status()["condition"]) > 0.0, "priority: damage accrues from the winning cause")
	_despawn_all()


func _test_save_load_accumulator() -> void:
	_harness.clear_events()
	_typed_events.clear()
	var reference_stores: Stores = _harness.add_stores({&"food_ration": 6})
	_spawned.append(reference_stores)
	_build_world(1)
	_harness.advance(24.0)
	var reference_consumed: int = 6 - reference_stores.get_count(&"food_ration")
	_check(reference_consumed == 1, "save: continuous 24 h reference run consumes one ration")
	_despawn_all()

	_harness.clear_events()
	_typed_events.clear()
	var stores: Stores = _harness.add_stores({&"food_ration": 6})
	_spawned.append(stores)
	_build_world(1)
	_harness.advance(12.0)
	_check(stores.get_count(&"food_ration") == 6, "save: half a day leaves the stock untouched")
	var saved_stores: Dictionary = stores.save_state()
	var saved_vitals: Dictionary = _vitals.save_state()
	_check(absf(float(saved_vitals.get("ration_accumulator", -1.0)) - 0.5) < 0.001, "save: accumulator is halfway through a ration at 12 h")
	_check(saved_vitals.has("condition") and saved_vitals.has("cause") and saved_vitals.has("cognition_level") and saved_vitals.has("last_emitted_bucket"), "save: existing vitals keys remain")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved_vitals))
	_check(parsed is Dictionary, "save: vitals state survives JSON serialization")
	var parsed_dict: Dictionary = parsed if parsed is Dictionary else {}
	_harness.advance(12.0)
	_check(stores.get_count(&"food_ration") == 5, "save: the second 12 h draws the ration")
	stores.load_state(saved_stores)
	_vitals.load_state(parsed_dict)
	_harness.advance(12.0)
	var split_consumed: int = 6 - stores.get_count(&"food_ration")
	_check(split_consumed == reference_consumed, "save: restored accumulator matches the continuous 24 h run")
	_check(stores.get_count(&"food_ration") == 5, "save: reloaded run ends on the reference stock")
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


func _build_world(occupants: int) -> void:
	var config: CompartmentConfig = _make_config(&"main", 0.21, 400.0, 21.0, occupants)
	var defs: Array[CompartmentConfig] = [config]
	_atmosphere = _harness.add_atmosphere(defs)
	_spawned.append(_atmosphere)
	_thermal = _harness.add_thermal(defs)
	_spawned.append(_thermal)
	_vitals = VitalsSystem.new()
	_spawned.append(_vitals)
	root.add_child(_vitals)


func _add_water(potable_l: float) -> WaterSystem:
	var water := WaterSystem.new()
	water.potable_l = potable_l
	water.greywater_l = 0.0
	water.set_reclaimer_powered(false)
	_spawned.append(water)
	root.add_child(water)
	return water


func _bus() -> Node:
	return root.get_node_or_null(^"/root/EventBus")


func _connect_typed_signals() -> void:
	var bus: Node = _bus()
	if bus == null:
		return
	bus.connect(&"operator_incapacitated", _on_operator_incapacitated)


func _on_operator_incapacitated(cause: StringName) -> void:
	_typed_events.append({"name": &"operator_incapacitated", "args": [cause]})


func _typed_named(event_name: StringName) -> Array[Dictionary]:
	var matched: Array[Dictionary] = []
	for event: Dictionary in _typed_events:
		if event["name"] == event_name:
			matched.append(event)
	return matched


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_rations")
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
