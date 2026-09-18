## Headless tests: airlock cycles, door interlock, gas conservation, pump power gating,
## suit O2, vacuum exposure through vitals, and state persistence.
extends SceneTree

var _harness: SimHarness
var _spawned: Array[Node] = []
var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_harness = SimHarness.new(self)
	_harness.setup_clock()
	await _test_interlock_and_cycle()
	await _test_vent_dumps_gas()
	await _test_pump_requires_power()
	await _test_suit_and_vacuum_exposure()
	await _test_save_load()
	if _failures == 0:
		print("PASS: test_airlock")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _build_world(with_power: bool = true, with_thermal: bool = false) -> Dictionary:
	var storage: CompartmentConfig = _harness.make_compartment(&"storage", 41.0)
	var lock_config: CompartmentConfig = _harness.make_compartment(&"airlock", 8.0)
	var defs: Array[CompartmentConfig] = [storage, lock_config]
	var atmosphere: AtmosphereSystem = _harness.add_atmosphere(defs)
	_spawned.append(atmosphere)
	if with_power:
		var circuits: Array[PowerCircuit] = [_harness.make_circuit(&"airlock", 60.0, 3)]
		var power: PowerSystem = _harness.add_power(circuits, 4000.0, {&"rtg_main": 500.0})
		_spawned.append(power)
	if with_thermal:
		var thermal: ThermalSystem = _harness.add_thermal(defs)
		_spawned.append(thermal)
	var airlock: AirlockSystem = AirlockSystem.new()
	airlock.compartment_id = &"airlock"
	airlock.interior_compartment_id = &"storage"
	root.add_child(airlock)
	_spawned.append(airlock)
	return {"atmosphere": atmosphere, "airlock": airlock}


func _test_interlock_and_cycle() -> void:
	var world: Dictionary = _build_world()
	var atmosphere: AtmosphereSystem = world["atmosphere"]
	var airlock: AirlockSystem = world["airlock"]
	_check(is_equal_approx(_pressure(atmosphere, &"airlock"), 101.325), "airlock starts pressurized")
	_check(not airlock.request_door(&"outer", true), "outer door refused while pressurized")
	_check(airlock.get_door_refusal(&"outer", true) == &"airlock_pressurized", "refusal names pressure")
	_check(airlock.request_door(&"inner", true), "inner door opens while pressurized")
	_check(not airlock.request_door(&"outer", true), "outer refused while inner open")
	_check(airlock.get_door_refusal(&"outer", true) == &"airlock_interlock", "refusal names interlock")
	_check(airlock.request_door(&"inner", false), "inner door closes")
	var gas_before: float = _total_gas(atmosphere)
	_check(airlock.request_cycle(&"depressurize"), "depressurize cycle starts")
	_harness.advance(0.5)
	_check(airlock.get_state_name() == &"idle", "depressurize finishes")
	_check(atmosphere.is_vacuum(&"airlock"), "airlock reads vacuum")
	_check(_harness.events_named(&"airlock_depressurized").size() == 1, "depressurized event emitted")
	var gas_after: float = _total_gas(atmosphere)
	_check(absf(gas_after - gas_before) <= 1e-6 * maxf(gas_before, 1.0), "pump conserves gas")
	_check(airlock.request_door(&"outer", true), "outer door opens in vacuum")
	_check(not airlock.request_door(&"inner", true), "inner refused while outer open")
	_check(airlock.get_door_refusal(&"inner", true) == &"airlock_interlock", "inner refusal names interlock")
	_check(airlock.request_door(&"outer", false), "outer door closes")
	_check(airlock.request_cycle(&"pressurize"), "pressurize cycle starts")
	_harness.advance(0.5)
	_check(not atmosphere.is_vacuum(&"airlock"), "airlock repressurizes")
	_check(_pressure(atmosphere, &"airlock") > 90.0, "airlock back to working pressure")
	_check(_harness.events_named(&"airlock_pressurized").size() == 1, "pressurized event emitted")
	_check(airlock.request_door(&"inner", true), "inner opens after repressurize")
	await _teardown()


func _test_vent_dumps_gas() -> void:
	var world: Dictionary = _build_world()
	var atmosphere: AtmosphereSystem = world["atmosphere"]
	var airlock: AirlockSystem = world["airlock"]
	var gas_before: float = _total_gas(atmosphere)
	_check(airlock.request_cycle(&"vent"), "vent cycle starts")
	var vent_events: Array[Dictionary] = _harness.events_named(&"airlock_vented")
	var lost: float = 0.0
	if not vent_events.is_empty():
		lost = float(vent_events[0]["payload"]["moles_lost"])
	_check(lost > 0.0, "vent reports lost moles")
	_check(atmosphere.is_vacuum(&"airlock"), "vent leaves vacuum")
	_harness.advance(0.05)
	_check(airlock.get_state_name() == &"idle", "vent finishes")
	var gas_after: float = _total_gas(atmosphere)
	_check(absf((gas_before - gas_after) - lost) <= 1e-6 * maxf(gas_before, 1.0), "vented gas is gone from the ship")
	_check(not airlock.request_cycle(&"vent"), "venting vacuum is refused")
	await _teardown()


func _test_pump_requires_power() -> void:
	var world: Dictionary = _build_world()
	var atmosphere: AtmosphereSystem = world["atmosphere"]
	var airlock: AirlockSystem = world["airlock"]
	var power: PowerSystem = root.get_node_or_null(NodePath("PowerSystem"))
	if power == null:
		for node: Node in _spawned:
			if node is PowerSystem:
				power = node
	power.set_breaker(&"airlock", false)
	_check(airlock.request_cycle(&"depressurize"), "cycle still starts unpowered")
	_harness.advance(0.2)
	_check(absf(_pressure(atmosphere, &"airlock") - 101.325) < 0.5, "pump stalls without power")
	var stall_reasons: int = 0
	for event: Dictionary in _harness.events_named(&"procedure_error"):
		if StringName(String(event["payload"].get("reason", ""))) == &"airlock_pump_stalled":
			stall_reasons += 1
	_check(stall_reasons == 1, "stall reported once")
	power.set_breaker(&"airlock", true)
	_harness.advance(0.5)
	_check(atmosphere.is_vacuum(&"airlock"), "pump resumes when power returns")
	await _teardown()


func _test_suit_and_vacuum_exposure() -> void:
	var world: Dictionary = _build_world(true, true)
	var atmosphere: AtmosphereSystem = world["atmosphere"]
	var airlock: AirlockSystem = world["airlock"]
	var vitals: VitalsSystem = VitalsSystem.new()
	root.add_child(vitals)
	_spawned.append(vitals)
	atmosphere.set_occupants(&"storage", 1)
	atmosphere.vent_gas(&"storage")
	_harness.advance(0.5)
	_check(vitals.get_cause() == &"vacuum", "no suit: vacuum is the cause")
	_check(vitals.condition > 0.0, "no suit: exposure damages the operator")
	_check(vitals.get_cognition_level() == 3, "no suit: cognition spikes")
	vitals.resuscitate()
	_check(airlock.equip_suit(), "suit equips from the locker")
	airlock.suit_o2_hours = 2.0
	_harness.advance(0.5)
	_check(vitals.get_cause() == &"", "suit protects from vacuum")
	_check(airlock.suit_o2_hours < 1.99 and airlock.suit_o2_hours > 1.0, "suit O2 drains while worn")
	airlock.suit_o2_hours = 0.005
	_harness.advance(0.2)
	_check(_harness.events_named(&"suit_o2_depleted").size() >= 1, "depleted tank reported once")
	_check(vitals.get_cause() == &"vacuum", "empty suit tank exposes again")
	await _teardown()


func _test_save_load() -> void:
	var world: Dictionary = _build_world()
	var airlock: AirlockSystem = world["airlock"]
	airlock.request_cycle(&"depressurize")
	_harness.advance(0.5)
	airlock.request_door(&"outer", true)
	airlock.equip_suit()
	airlock.suit_o2_hours = 1.25
	var state: Dictionary = airlock.save_state()
	var restored: AirlockSystem = AirlockSystem.new()
	root.add_child(restored)
	_spawned.append(restored)
	restored.load_state(state)
	_check(restored.get_state_name() == &"idle", "state restores")
	_check(not restored.inner_open, "inner door restores")
	_check(restored.outer_open, "outer door restores")
	_check(restored.suit_worn and not restored.suit_stored, "suit restores")
	_check(is_equal_approx(restored.suit_o2_hours, 1.25), "suit O2 restores")
	await _teardown()


func _pressure(atmosphere: AtmosphereSystem, id: StringName) -> float:
	return float(atmosphere.get_compartment_status(id).get("pressure_kpa", 0.0))


func _total_gas(atmosphere: AtmosphereSystem) -> float:
	var total: float = 0.0
	for id: StringName in [&"airlock", &"storage"]:
		var moles: Dictionary = atmosphere.get_gas_moles(id)
		for key: String in ["o2", "co2", "n2"]:
			total += float(moles.get(key, 0.0))
	return total


func _teardown() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_harness.clear_events()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
