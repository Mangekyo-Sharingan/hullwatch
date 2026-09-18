## Integration: hidden faults, probe diagnosis with a carried multimeter, wear scanning,
## and the wrench gate on the scrubber housing.
extends SceneTree

var _failures: int = 0
var _procedure_errors: int = 0
var _last_error_reason: StringName = &""


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
	event_bus.connect(&"sim_event", _on_sim_event)

	await _test_hidden_faults_and_probes()
	await _test_wrench_gate()

	_finish()


func _test_hidden_faults_and_probes() -> void:
	var power := PowerSystem.new()
	var lighting := PowerCircuit.new()
	lighting.circuit_id = &"lighting"
	lighting.nominal_load_w = 200.0
	var defs: Array[PowerCircuit] = [lighting]
	power.circuit_defs = defs
	var wear := WearComponent.new()
	wear.component_id = &"test_rtg"
	wear.condition = 1.0
	var wear_defs: Array[WearComponent] = [wear]
	power.wear_components = wear_defs
	root.add_child(power)

	var player: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame
	var multimeter := Carriable.new()
	multimeter.item_id = &"multimeter"
	multimeter.item_name = "Multimeter"
	root.add_child(multimeter)
	_check(bool(player.call("take_carriable", multimeter)), "tools: multimeter taken")

	var probe := DiagnosticProbe.new()
	probe.system_group = &"power_system"
	root.add_child(probe)

	var panel := StatusPanel.new()
	panel.compartment_id = &"main"
	root.add_child(panel)

	_check(power.call("force_failure", &"test_rtg", &"rtg_degraded"), "fault: forced on the test component")
	var readout: String = "\n".join(panel.build_readout())
	_check(readout.contains("FAULT (UNDIAGNOSED)"), "panel hides the mode until diagnosed")
	_check(not readout.contains("RTG_DEGRADED"), "panel does not leak the failure mode")
	_check(readout.contains("--"), "panel hides condition until scanned")

	_procedure_errors = 0
	probe.interact(player)
	_check(_procedure_errors == 0, "probe: diagnosing needs no error")
	var status: Dictionary = power.call("get_wear_status")
	_check(bool(status["test_rtg"]["diagnosed"]), "probe: fault diagnosed with the multimeter")
	readout = "\n".join(panel.build_readout())
	_check(readout.contains("FAIL RTG_DEGRADED"), "panel reveals the mode after diagnosis")

	var scanner := Carriable.new()
	scanner.item_id = &"scanner"
	scanner.item_name = "Wear scanner"
	root.add_child(scanner)
	_check(bool(player.call("take_carriable", scanner)), "tools: scanner swapped in")
	probe.interact(player)
	status = power.call("get_wear_status")
	_check(bool(status["test_rtg"]["scanned"]), "probe: scanner logs wear")
	readout = "\n".join(panel.build_readout())
	_check(readout.contains("100%"), "panel shows condition after scanning")

	_check(bool(player.call("drop_carried") != null), "tools: scanner dropped")
	_procedure_errors = 0
	probe.interact(player)
	_check(_procedure_errors == 1 and _last_error_reason == &"no_tool", "probe without a tool refuses")

	power.free()
	player.free()
	probe.free()
	panel.free()


func _test_wrench_gate() -> void:
	_procedure_errors = 0
	var unit := ScrubberUnit.new()
	unit.compartment_id = &"main"
	root.add_child(unit)
	var player: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame

	_check(unit.is_powered(), "wrench: unit starts powered")
	unit.interact(player)
	_check(_procedure_errors == 0, "wrench: powering down needs no tool")
	_procedure_errors = 0
	unit.interact(player)
	_check(_procedure_errors == 1 and _last_error_reason == &"no_wrench", "wrench: opening the housing requires the wrench")
	_check(not unit.is_housing_open(), "wrench: housing stays closed without the tool")

	var wrench := Carriable.new()
	wrench.item_id = &"wrench"
	wrench.item_name = "Wrench"
	root.add_child(wrench)
	_check(bool(player.call("take_carriable", wrench)), "wrench: taken")
	unit.interact(player)
	_check(unit.is_housing_open(), "wrench: housing opens with the wrench in hand")

	unit.free()
	player.free()


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"procedure_error":
		_procedure_errors += 1
		_last_error_reason = payload.get("reason", &"")


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_diagnostics")
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
