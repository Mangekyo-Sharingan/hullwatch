## M4 extras: O2 candle procedure, destination overlay, multi-destination nav chain.
extends SceneTree

var _failures: int = 0
var _procedure_errors: int = 0
var _last_error_reason: StringName = &""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var event_bus: Node = _find_root_child(&"EventBus")
	if event_bus == null:
		event_bus = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
	event_bus.connect(&"sim_event", _on_sim_event)

	_test_o2_candle()
	await _test_leg_overlay()
	_test_nav_leg_completed()

	_finish()


func _test_o2_candle() -> void:
	_procedure_errors = 0
	var atmosphere := AtmosphereSystem.new()
	var config := CompartmentConfig.new()
	config.compartment_id = &"main"
	config.volume_m3 = 60.0
	config.o2_candles_stocked = 1
	var defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = defs
	root.add_child(atmosphere)

	var rack := O2Candle.new()
	rack.compartment_id = &"main"
	root.add_child(rack)

	_check(rack.get_interaction_prompt().contains("1 left"), "candle prompt shows the stock")
	rack.interact(null)
	var status: Dictionary = atmosphere.get_compartment_status(&"main")
	_check(int(status["candles_remaining"]) == 0, "lighting a candle consumes stock")
	_check(float(status["candle_burn_remaining_hours"]) > 0.0, "lighted candle starts burning")
	rack.interact(null)
	_check(_procedure_errors == 1 and _last_error_reason == &"no_candles", "empty rack refuses with a procedure error")

	atmosphere.free()
	rack.free()


func _test_leg_overlay() -> void:
	var overlay: CanvasLayer = load("res://src/ui/leg_complete_overlay.gd").new()
	root.add_child(overlay)
	await process_frame
	_check(not overlay.call("is_visible_overlay"), "leg overlay starts hidden")

	var event_bus: Node = _find_root_child(&"EventBus")
	event_bus.call("emit_event", &"destination_arrived", {
		"destination_id": &"leg_end",
		"display_name": "Leg End",
		"arrival_report": "Reference confirmed.",
	})
	_check(overlay.call("is_visible_overlay"), "leg overlay appears on completion")
	_check(String(overlay.call("get_overlay_text")).contains("LEG END"), "leg overlay names the destination")

	overlay.call("dismiss")
	_check(not overlay.call("is_visible_overlay"), "leg overlay dismisses")
	root.remove_child(overlay)
	overlay.free()


func _test_nav_leg_completed() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav := NavSystem.new()
	var destinations: Array[VoyageDestination] = [
		load("res://src/data/destinations/destination_arden_ii.tres"),
		load("res://src/data/destinations/destination_kestrel_system.tres"),
	]
	nav.destinations = destinations
	root.add_child(nav)

	_check(nav.plot_course(&"arden_ii") and nav.begin_burn(), "first destination transit starts")
	nav.sim_tick(48.0)
	var arrivals: Array[Dictionary] = harness.events_named(&"destination_arrived")
	_check(arrivals.size() == 1, "first arrival is emitted once")
	if arrivals.size() == 1:
		_check(StringName(arrivals[0]["payload"]["destination_id"]) == &"arden_ii", "first arrival names its destination")
	_check(nav.plot_course(&"kestrel_system") and nav.begin_burn(), "second destination transit starts")
	nav.sim_tick(96.0)
	arrivals = harness.events_named(&"destination_arrived")
	_check(arrivals.size() == 2, "second arrival extends the route once")
	if arrivals.size() == 2:
		_check(StringName(arrivals[1]["payload"]["destination_id"]) == &"kestrel_system", "second arrival names the final destination")
	_check(bool(nav.get_status()["arrived"]), "nav reports arrival at the final destination")

	nav.free()


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
		print("PASS: test_m4_extras")
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
