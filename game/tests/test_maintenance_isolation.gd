extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	await process_frame
	root.get_node("SimClock").set("is_paused", true)
	var power: PowerSystem = PowerSystem.new()
	for circuit_id: StringName in [&"lighting", &"life_support"]:
		var circuit: PowerCircuit = PowerCircuit.new()
		circuit.circuit_id = circuit_id
		power.circuit_defs.append(circuit)
	power.wear_components = [load("res://src/data/wear/lighting_ballast.tres").duplicate(true) as WearComponent,
		load("res://src/data/wear/rtg_main.tres").duplicate(true) as WearComponent]
	root.add_child(power)
	_check(power.set_breaker(&"lighting", false), "lighting switches off")
	_check(power.maintenance_action(&"lighting_ballast", &"open", &"wrench"), "isolated lighting cover opens")
	var saved: Dictionary = power.save_state()
	_check(power.maintenance_action(&"lighting_ballast", &"close", &"wrench"), "cover closes after direct snapshot")
	_check(bool((saved["maintenance_covers"] as Dictionary).get("lighting_ballast", false)), "direct snapshot keeps its own copy of the open cover")
	_check(power.set_breaker(&"lighting", true), "closed cover energizes before direct restore")
	power.load_state(JSON.parse_string(JSON.stringify(saved)) as Dictionary)
	_check(bool(power.get_maintenance_status(&"lighting_ballast")["housing_open"]) and not power.is_breaker_on(&"lighting"), "direct JSON load restores open cover and isolated breaker")
	_check(not power.set_breaker(&"lighting", true) and not power.is_breaker_on(&"lighting"), "open cover blocks circuit energizing")
	_check(power.set_breaker(&"life_support", true), "unrelated circuit remains available")
	_check(power.set_breaker(&"lighting", false), "open cover still permits switching off")
	_check(power.maintenance_action(&"lighting_ballast", &"close", &"wrench"), "lighting cover closes")
	_check(power.set_breaker(&"lighting", true), "closed cover permits energizing")

	var thermal: ThermalSystem = ThermalSystem.new()
	thermal.wear_components = [load("res://src/data/wear/heater_main.tres").duplicate(true) as WearComponent]
	root.add_child(thermal)
	_check(power.set_breaker(&"life_support", false), "heater circuit switches off")
	_check(thermal.maintenance_action(&"heater_main", &"open", &"wrench"), "cross-system heater cover opens")
	_check(not power.set_breaker(&"life_support", true) and not power.is_breaker_on(&"life_support"), "thermal cover blocks power breaker")
	_check(thermal.maintenance_action(&"heater_main", &"close", &"wrench"), "heater cover closes")
	_check(power.set_breaker(&"life_support", true), "closed thermal cover permits energizing")

	for circuit_id: StringName in [&"lighting", &"life_support"]:
		_check(power.set_breaker(circuit_id, false), "bus circuit switches off")
	_check(power.maintenance_action(&"rtg_main", &"open", &"wrench"), "isolated all-bus cover opens")
	for circuit_id: StringName in [&"lighting", &"life_support"]:
		_check(not power.set_breaker(circuit_id, true) and not power.is_breaker_on(circuit_id), "all-bus cover blocks every breaker")
	_check(power.maintenance_action(&"rtg_main", &"close", &"wrench"), "all-bus cover closes")
	_check(power.set_breaker(&"lighting", true), "closed all-bus cover permits energizing")
	saved.erase("maintenance_covers")
	power.maintenance_covers["lighting_ballast"] = true
	power.load_state(saved)
	_check(power.maintenance_covers.is_empty(), "legacy direct load clears stale open covers")
	thermal.free()
	power.free()
	if _failures == 0:
		print("PASS: test_maintenance_isolation")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: " + message)
