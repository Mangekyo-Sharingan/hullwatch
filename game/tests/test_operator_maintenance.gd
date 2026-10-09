extends SceneTree

var failures: int = 0

class Operator extends Node:
	var tool: StringName = &"wrench"
	func get_carried_item_id() -> StringName:
		return tool

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL: " + message)

func run_checks() -> void:
	await process_frame
	var harness: SimHarness = SimHarness.new(self)
	harness.setup_clock()
	var power: PowerSystem = PowerSystem.new()
	power.circuit_defs = [harness.make_circuit(&"lighting", 200.0, 1)]
	power.generators = {&"rtg_main": 500.0}
	power.wear_components = [load("res://src/data/wear/rtg_main.tres") as WearComponent]
	root.add_child(power)
	var stores: Stores = harness.add_stores({&"gasket": 2})
	var probe: DiagnosticProbe = DiagnosticProbe.new()
	root.add_child(probe)
	var operator: Operator = Operator.new()
	root.add_child(operator)
	await process_frame
	check(power.force_failure(&"rtg_main", &"rtg_open_circuit"), "force external power fault")
	check(not power.maintenance_action(&"rtg_main", &"open", &"wrench"), "live bus prevents opening")
	power.set_breaker(&"lighting", false)
	check(not power.maintenance_action(&"rtg_main", &"open", &"scanner"), "wrench required for cover")
	check(power.maintenance_action(&"rtg_main", &"open", &"wrench"), "isolated cover opens")
	check(not power.maintenance_action(&"rtg_main", &"repair", &"wrench"), "hidden fault cannot be repaired before diagnosis")
	check(stores.get_count(&"gasket") == 2, "refused repair preserves parts")
	operator.tool = &"multimeter"
	probe.interact(operator)
	operator.tool = &"wrench"
	probe.interact(operator)
	check(probe.is_open(), "wrench opens physical service menu")
	var actions: PackedStringArray = probe.get_actions()
	var refit: int = -1
	for index: int in actions.size():
		if actions[index].begins_with("REFIT RTG MAIN"):
			refit = index
	check(refit >= 0, "diagnosed fault offers refit")
	if refit >= 0:
		check(probe.select_action(refit), "physical menu repairs diagnosed hardware")
	check(power.get_generation_w() > 400.0, "repair restores real generation")
	check(stores.get_count(&"gasket") == 1, "refit consumes fabricated part")
	check(absf(harness.hours() - 0.25) < 0.01, "refit advances shared simulation clock")
	var manager: Node = root.get_node("SaveManager")
	var saved: Dictionary = manager.call("save_to_dict")
	check(power.maintenance_action(&"rtg_main", &"close", &"wrench"), "cover closes")
	check(bool(manager.call("load_from_dict", saved)), "watch restores service state")
	check(bool(power.get_maintenance_status(&"rtg_main")["housing_open"]), "saved open cover remains open")
	check(power.maintenance_action(&"rtg_main", &"close", &"wrench"), "restored cover closes")
	probe.close()
	check(not probe.is_open(), "service menu dismisses")
	if failures == 0:
		print("PASS: test_operator_maintenance")
	quit(0 if failures == 0 else 1)
