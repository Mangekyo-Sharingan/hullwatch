## Headless checks for the diagnostics layer: diagnose/scan gating, events, and persistence.
extends SceneTree

var _failures: int = 0
var _diagnosed_events: Array[Dictionary] = []
var _sim_events: Array[Dictionary] = []
var _spawned: Array[Node] = []


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
	event_bus.connect(&"component_diagnosed", _on_component_diagnosed)
	event_bus.connect(&"sim_event", _on_sim_event)

	_test_power_diagnose_flow()
	_test_power_save_load_round_trip()
	_test_old_save_defaults_false()
	_test_water_scanned_round_trip()
	_test_api_on_all_five_systems()

	_despawn_all()
	_finish()


func _test_power_diagnose_flow() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(modes, 41)
	_check(power.force_failure(&"rtg_main", &"rtg_degraded"), "power: force_failure accepted")
	var status: Dictionary = power.get_wear_status()
	_check(status.has("rtg_main"), "power: wear status carries the component")
	if not status.has("rtg_main"):
		return
	_check(not bool(status["rtg_main"]["diagnosed"]), "power: forced failure starts undiagnosed")
	_check(not bool(status["rtg_main"]["scanned"]), "power: forced failure starts unscanned")
	var undiagnosed: Array[StringName] = power.get_undiagnosed_failures()
	_check(undiagnosed.size() == 1 and undiagnosed[0] == &"rtg_main", "power: undiagnosed list carries the component")
	_check(power.diagnose_component(&"missing") == &"", "power: diagnose rejects an unknown component")

	_diagnosed_events.clear()
	_sim_events.clear()
	var mode: StringName = power.diagnose_component(&"rtg_main")
	_check(mode == &"rtg_degraded", "power: diagnose returns the failure mode")
	_check(bool(power.get_wear_status()["rtg_main"]["diagnosed"]), "power: diagnose flips diagnosed")
	_check(_diagnosed_events.size() == 1, "power: typed component_diagnosed emitted once")
	if _diagnosed_events.size() == 1:
		_check(_diagnosed_events[0]["component_id"] == &"rtg_main", "power: typed signal carries the component")
		_check(_diagnosed_events[0]["failure_mode_id"] == &"rtg_degraded", "power: typed signal carries the mode")
	var diagnosed_payloads: Array[Dictionary] = _sim_event_payloads(&"component_diagnosed")
	_check(diagnosed_payloads.size() == 1, "power: component_diagnosed sim event emitted once")
	if diagnosed_payloads.size() == 1:
		_check(StringName(diagnosed_payloads[0].get("component_id", &"")) == &"rtg_main", "power: sim event carries the component")
		_check(StringName(diagnosed_payloads[0].get("failure_mode_id", &"")) == &"rtg_degraded", "power: sim event carries the mode")
	_check(power.get_undiagnosed_failures().is_empty(), "power: diagnosed failure leaves the undiagnosed list")

	var again: StringName = power.diagnose_component(&"rtg_main")
	_check(again == &"rtg_degraded", "power: repeat diagnose returns the mode")
	_check(_diagnosed_events.size() == 1, "power: repeat diagnose does not re-emit the typed signal")
	_check(_sim_event_payloads(&"component_diagnosed").size() == 1, "power: repeat diagnose does not re-emit the sim event")

	_sim_events.clear()
	var conditions: Dictionary = power.scan_system()
	_check(bool(power.get_wear_status()["rtg_main"]["scanned"]), "power: scan flips scanned")
	_check(conditions.has("rtg_main"), "power: scan returns a condition per component")
	if conditions.has("rtg_main"):
		_check(absf(float(conditions["rtg_main"]) - float(power.get_wear_status()["rtg_main"]["condition"])) < 1e-9, "power: scan condition matches the sim")
	var scanned_payloads: Array[Dictionary] = _sim_event_payloads(&"components_scanned")
	_check(scanned_payloads.size() == 1, "power: components_scanned sim event emitted once")
	if scanned_payloads.size() == 1:
		_check(String(scanned_payloads[0].get("system_id", "")) == "power", "power: scan event carries the system id")

	_check(power.repair_component(&"rtg_main", 1.0), "power: repair accepted")
	var repaired: Dictionary = power.get_wear_status()["rtg_main"]
	_check(not bool(repaired["failed"]), "power: repair clears the failure")
	_check(bool(repaired["diagnosed"]), "power: repair leaves diagnosed true")

	_diagnosed_events.clear()
	_sim_events.clear()
	_check(power.diagnose_component(&"rtg_main") == &"", "power: healthy diagnose returns empty")
	_check(_diagnosed_events.is_empty(), "power: healthy diagnose emits no typed signal")
	_check(_sim_event_payloads(&"component_diagnosed").is_empty(), "power: healthy diagnose emits no sim event")


func _test_power_save_load_round_trip() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(modes, 42)
	power.force_failure(&"rtg_main", &"rtg_degraded")
	power.diagnose_component(&"rtg_main")
	power.scan_system()
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(power.save_state(), "\t"))
	_check(parsed_value is Dictionary, "save: power state is JSON-safe")
	if not (parsed_value is Dictionary):
		return
	var restored: PowerSystem = _spawn_power_with_wear(modes, 777)
	restored.load_state(parsed_value)
	var restored_status: Dictionary = restored.get_wear_status()
	_check(restored_status.has("rtg_main"), "save: restored power has the component")
	if not restored_status.has("rtg_main"):
		return
	_check(String(restored_status["rtg_main"]["failed_mode"]) == "rtg_degraded", "save: failure mode round trips")
	_check(bool(restored_status["rtg_main"]["failed"]), "save: failure round trips")
	_check(bool(restored_status["rtg_main"]["diagnosed"]), "save: diagnosed round trips")
	_check(bool(restored_status["rtg_main"]["scanned"]), "save: scanned round trips")
	_check(restored.get_undiagnosed_failures().is_empty(), "save: restored failure stays diagnosed")


func _test_old_save_defaults_false() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"rtg_degraded", 1000000.0, 0.0)]
	var power: PowerSystem = _spawn_power_with_wear(modes, 43)
	power.force_failure(&"rtg_main", &"rtg_degraded")
	power.diagnose_component(&"rtg_main")
	power.scan_system()
	var saved: Dictionary = power.save_state()
	var entries: Variant = saved.get("wear", [])
	if entries is Array:
		for entry: Variant in (entries as Array):
			if entry is Dictionary:
				(entry as Dictionary).erase("diagnosed")
				(entry as Dictionary).erase("scanned")
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(saved, "\t"))
	_check(parsed_value is Dictionary, "old save: stripped state is JSON-safe")
	if not (parsed_value is Dictionary):
		return
	var restored: PowerSystem = _spawn_power_with_wear(modes, 778)
	restored.wear_components[0].diagnosed = true
	restored.wear_components[0].scanned = true
	restored.load_state(parsed_value)
	var restored_status: Dictionary = restored.get_wear_status()
	_check(restored_status.has("rtg_main"), "old save: restored power has the component")
	if not restored_status.has("rtg_main"):
		return
	_check(bool(restored_status["rtg_main"]["failed"]), "old save: failure still loads")
	_check(not bool(restored_status["rtg_main"]["diagnosed"]), "old save: missing diagnosed defaults to false")
	_check(not bool(restored_status["rtg_main"]["scanned"]), "old save: missing scanned defaults to false")


func _test_water_scanned_round_trip() -> void:
	var modes: Array[FailureMode] = [_make_mode(&"pump_impeller_wear", 1000000.0, 0.0)]
	var water: WaterSystem = _spawn_water_with_wear(modes, 44)
	var conditions: Dictionary = water.scan_system()
	_check(conditions.has("water_pump_main"), "water: scan returns the pump condition")
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(water.save_state(), "\t"))
	_check(parsed_value is Dictionary, "save: water state is JSON-safe")
	if not (parsed_value is Dictionary):
		return
	var restored: WaterSystem = _spawn_water_with_wear(modes, 779)
	restored.load_state(parsed_value)
	var restored_status: Dictionary = restored.get_wear_status()
	_check(restored_status.has("water_pump_main"), "save: restored water has the pump")
	if not restored_status.has("water_pump_main"):
		return
	_check(bool(restored_status["water_pump_main"]["scanned"]), "save: scanned round trips for water")
	_check(not bool(restored_status["water_pump_main"]["diagnosed"]), "save: water stays undiagnosed")


func _test_api_on_all_five_systems() -> void:
	var specs: Array[Dictionary] = [
		{"label": "power", "path": "res://src/data/wear/rtg_main.tres"},
		{"label": "atmosphere", "path": "res://src/data/wear/scrubber_blower_main.tres"},
		{"label": "thermal", "path": "res://src/data/wear/heater_main.tres"},
		{"label": "hull", "path": "res://src/data/wear/hull_plating_main.tres"},
		{"label": "water", "path": "res://src/data/wear/water_pump_main.tres"},
	]
	var answered: int = 0
	for spec: Dictionary in specs:
		var label: String = String(spec["label"])
		var component: WearComponent = load(String(spec["path"])) as WearComponent
		_check(component != null, "%s: wear resource loads" % label)
		if component == null:
			continue
		_check(not component.failure_modes.is_empty(), "%s: wear resource has a failure mode" % label)
		if component.failure_modes.is_empty():
			continue
		var first_mode: FailureMode = component.failure_modes[0]
		_check(first_mode != null, "%s: first failure mode is non-null" % label)
		if first_mode == null:
			continue
		var component_id: StringName = component.component_id
		var mode_id: StringName = first_mode.id
		_check(component_id != &"" and mode_id != &"", "%s: resource ids are non-empty" % label)
		var system: ShipSystem = _spawn_system(label, component)
		_check(system != null, "%s: system spawned with wear" % label)
		if system == null:
			continue
		_check(system.force_failure(component_id, mode_id), "%s: force_failure accepted" % label)
		_check(system.get_undiagnosed_failures().has(component_id), "%s: failure starts undiagnosed" % label)
		_diagnosed_events.clear()
		var returned: StringName = system.diagnose_component(component_id)
		_check(returned == mode_id, "%s: diagnose returns the runtime mode id" % label)
		_check(_diagnosed_events.size() == 1, "%s: diagnose emits the typed signal once" % label)
		_check(system.get_undiagnosed_failures().is_empty(), "%s: diagnosed failure leaves the list" % label)
		var status: Dictionary = system.get_wear_status()
		if status.has(String(component_id)):
			_check(bool(status[String(component_id)]["diagnosed"]), "%s: wear status reports diagnosed" % label)
		answered += 1
	_check(answered == specs.size(), "diagnostics: all five systems answered the API")


func _spawn_system(label: String, component: WearComponent) -> ShipSystem:
	var components: Array[WearComponent] = [component]
	var system: ShipSystem = null
	match label:
		"power":
			var power: PowerSystem = PowerSystem.new()
			power.wear_components = components
			system = power
		"atmosphere":
			var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
			atmosphere.wear_components = components
			system = atmosphere
		"thermal":
			var thermal: ThermalSystem = ThermalSystem.new()
			thermal.wear_components = components
			system = thermal
		"hull":
			var hull: HullSystem = HullSystem.new()
			hull.wear_components = components
			system = hull
		"water":
			var water: WaterSystem = WaterSystem.new()
			water.wear_components = components
			system = water
	if system != null:
		_spawn(system)
	return system


func _spawn_power_with_wear(modes: Array[FailureMode], seed_value: int) -> PowerSystem:
	var component: WearComponent = _make_component(&"rtg_main", modes, 0.0002, 1.0)
	var components: Array[WearComponent] = [component]
	var circuits: Array[PowerCircuit] = [_make_circuit(&"life_support", 150.0, 0)]
	var power: PowerSystem = PowerSystem.new()
	power.wear_seed = seed_value
	power.circuit_defs = circuits
	power.generators = {&"rtg_main": 500.0}
	power.wear_components = components
	_spawn(power)
	return power


func _spawn_water_with_wear(modes: Array[FailureMode], seed_value: int) -> WaterSystem:
	var component: WearComponent = _make_component(&"water_pump_main", modes, 0.00015, 1.0)
	var components: Array[WearComponent] = [component]
	var water: WaterSystem = WaterSystem.new()
	water.wear_seed = seed_value
	water.wear_components = components
	_spawn(water)
	return water


func _make_component(component_id: StringName, modes: Array[FailureMode], wear_rate: float, load_value: float) -> WearComponent:
	var component: WearComponent = WearComponent.new()
	component.component_id = component_id
	component.wear_rate_per_hour = wear_rate
	component.load = load_value
	component.failure_modes = modes
	return component


func _make_mode(mode_id: StringName, mtbf_hours: float, max_condition: float = 1.0) -> FailureMode:
	var mode: FailureMode = FailureMode.new()
	mode.id = mode_id
	mode.base_mtbf_hours = mtbf_hours
	mode.max_condition = max_condition
	return mode


func _make_circuit(circuit_id: StringName, load_w: float, priority: int) -> PowerCircuit:
	var circuit: PowerCircuit = PowerCircuit.new()
	circuit.circuit_id = circuit_id
	circuit.nominal_load_w = load_w
	circuit.priority = priority
	return circuit


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _sim_event_payloads(event_name: StringName) -> Array[Dictionary]:
	var payloads: Array[Dictionary] = []
	for entry: Dictionary in _sim_events:
		if StringName(entry["event_name"]) == event_name:
			var payload: Variant = entry["payload"]
			if payload is Dictionary:
				payloads.append(payload)
	return payloads


func _on_component_diagnosed(component_id: StringName, failure_mode_id: StringName) -> void:
	_diagnosed_events.append({"component_id": component_id, "failure_mode_id": failure_mode_id})


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	_sim_events.append({"event_name": event_name, "payload": payload.duplicate(true)})


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_diagnostics_api")
		quit(0)
	else:
		print("FAIL: test_diagnostics_api (%d checks failed)" % _failures)
		quit(1)
