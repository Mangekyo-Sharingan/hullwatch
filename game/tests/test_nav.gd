extends SceneTree

var _failures: int = 0
var _spawned: Array[Node] = []
var _course_changed: Array[Dictionary] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_test_absent_safe()
	_test_plot_emits_events()
	_test_burn_consumes_and_advances()
	_test_burn_without_course()
	_test_no_fuel_plot_refusal()
	_test_no_fuel_burn_refusal()
	_test_course_expiry()
	_test_save_load()
	_test_console_prompt_flow()
	_test_arrival()

	_despawn_all()
	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var node: Node = _find_root_child(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()

	_finish()


func _test_absent_safe() -> void:
	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()
	_check(_find_root_child(&"EventBus") == null, "absent-safe: no EventBus present")
	_check(_find_root_child(&"SimClock") == null, "absent-safe: no SimClock present")
	var nav: NavSystem = _spawn_nav()
	_check(nav.plot_course(&"relay_cache"), "absent-safe: plot works without autoloads")
	_check(nav.begin_burn(), "absent-safe: burn works without autoloads")
	_check(nav.current_leg == 1, "absent-safe: leg advanced without SimClock")
	_despawn_all()


func _test_plot_emits_events() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var event_bus: Node = _find_root_child(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"course_changed", _on_course_changed)
	_course_changed.clear()
	var nav: NavSystem = _spawn_nav()
	_check(nav.plot_course(&"relay_cache"), "plot: known waypoint accepted")
	var status: Dictionary = nav.get_status()
	_check(StringName(status["plotted_waypoint"]) == &"relay_cache", "plot: plotted waypoint recorded")
	_check(int(status["current_leg"]) == 0, "plot: current leg starts at zero")
	_check(StringName(status["current_waypoint"]) == &"relay_cache", "plot: current waypoint is the next leg")
	_check(not bool(status["arrived"]), "plot: not arrived")
	var plotted_events: Array[Dictionary] = harness.events_named(&"course_plotted")
	_check(plotted_events.size() == 1, "plot: course_plotted sim event emitted")
	if plotted_events.size() == 1:
		var payload: Dictionary = plotted_events[0]["payload"]
		_check(StringName(payload["waypoint_id"]) == &"relay_cache", "plot: sim payload waypoint_id")
		_check(is_equal_approx(float(payload["delta_v_cost"]), 60.0), "plot: sim payload delta_v_cost")
	_check(_course_changed.size() == 1, "plot: typed course_changed emitted once")
	if _course_changed.size() == 1:
		_check(_course_changed[0]["leg_id"] == &"relay_cache", "plot: typed leg_id")
		_check(is_equal_approx(float(_course_changed[0]["delta_v_cost"]), 60.0), "plot: typed delta_v_cost")
	_check(not nav.plot_course(&"unknown_waypoint"), "plot: unknown waypoint refused")
	_check(_course_changed.size() == 1, "plot: refusal emits no course_changed")
	_despawn_all()


func _test_burn_consumes_and_advances() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	var hours_before: float = harness.hours()
	_check(nav.plot_course(&"relay_cache"), "burn: course plotted")
	_check(nav.begin_burn(), "burn: begin_burn succeeds with course and fuel")
	_check(is_equal_approx(nav.fuel_mass_kg, 1140.0), "burn: fuel consumed by burn_fuel_kg")
	_check(nav.current_leg == 1, "burn: leg index advanced")
	_check(nav.plotted_waypoint == &"", "burn: plotted course cleared")
	_check(is_equal_approx(harness.hours() - hours_before, nav.burn_hours), "burn: sim clock advanced by burn_hours")
	var burn_events: Array[Dictionary] = harness.events_named(&"burn_completed")
	_check(burn_events.size() == 1, "burn: burn_completed emitted once")
	if burn_events.size() == 1:
		var payload: Dictionary = burn_events[0]["payload"]
		_check(StringName(payload["waypoint_id"]) == &"relay_cache", "burn: payload waypoint_id")
		_check(int(payload["leg_index"]) == 1, "burn: payload leg_index follows the advanced leg")
		_check(is_equal_approx(float(payload["fuel_remaining"]), 1140.0), "burn: payload fuel_remaining")
	_check(not nav.plot_course(&"relay_cache"), "burn: plotting a completed waypoint refused")
	_check(not nav.begin_burn(), "burn: second burn without a new course refused")
	_despawn_all()


func _test_burn_without_course() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	_check(not nav.begin_burn(), "no_course: burn refused")
	_check(nav.current_leg == 0, "no_course: leg unchanged")
	_check(is_equal_approx(nav.fuel_mass_kg, 1200.0), "no_course: fuel unchanged")
	_check(harness.hours() == 0.0, "no_course: clock unchanged")
	_despawn_all()


func _test_no_fuel_plot_refusal() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	nav.fuel_mass_kg = 10.0
	_check(not nav.plot_course(&"relay_cache"), "no_fuel: plot refused when fuel is short")
	_check(nav.plotted_waypoint == &"", "no_fuel: nothing plotted")
	var console: NavConsole = _spawn_console(&"drift_marker")
	console.interact(null)
	var errors: Array[Dictionary] = harness.events_named(&"procedure_error")
	_check(errors.size() == 1, "no_fuel: console emits procedure_error when plotting without fuel")
	if errors.size() == 1:
		_check(StringName(errors[0]["payload"]["reason"]) == &"no_fuel", "no_fuel: plot reason is no_fuel")
	_check(nav.plotted_waypoint == &"", "no_fuel: console refusal leaves nothing plotted")
	_despawn_all()


func _test_no_fuel_burn_refusal() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	_check(nav.plot_course(&"relay_cache"), "no_fuel_burn: plotted while fuelled")
	nav.fuel_mass_kg = 10.0
	var console: NavConsole = _spawn_console(&"relay_cache")
	_check(console.get_interaction_prompt() == "Begin burn", "no_fuel_burn: prompt offers burn")
	console.interact(null)
	var errors: Array[Dictionary] = harness.events_named(&"procedure_error")
	_check(errors.size() == 1, "no_fuel_burn: console emits procedure_error")
	if errors.size() == 1:
		_check(StringName(errors[0]["payload"]["reason"]) == &"no_fuel", "no_fuel_burn: reason is no_fuel")
	_check(nav.plotted_waypoint == &"relay_cache", "no_fuel_burn: course stays plotted")
	_check(not nav.begin_burn(), "no_fuel_burn: direct burn refused")
	_check(is_equal_approx(nav.fuel_mass_kg, 10.0), "no_fuel_burn: fuel unchanged")
	_despawn_all()


func _test_course_expiry() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	nav.course_error_per_hour = 0.1
	_check(nav.plot_course(&"relay_cache"), "expiry: course plotted")
	harness.advance(5.0)
	_check(nav.plotted_waypoint == &"relay_cache", "expiry: course survives five hours of drift")
	_check(float(nav.get_status()["course_error"]) > 0.4, "expiry: course error accumulates")
	harness.advance(6.0)
	_check(nav.plotted_waypoint == &"", "expiry: course cleared once drift saturates")
	_check(is_equal_approx(float(nav.get_status()["course_error"]), 1.0), "expiry: course error pinned at one")
	_check(harness.events_named(&"course_expired").size() == 1, "expiry: course_expired emitted once")
	_check(nav.current_leg == 0, "expiry: leg not advanced by drift")
	_despawn_all()


func _test_save_load() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	_check(nav.plot_course(&"relay_cache"), "save: course plotted")
	harness.advance(2.0)
	var saved: Dictionary = nav.save_state()
	_check(saved["system_id"] == "nav", "save: system_id is nav")
	_check(int(saved["state_version"]) == 1, "save: state_version is 1")
	_check(int(saved["current_leg"]) == 0, "save: current_leg captured")
	_check(String(saved["plotted_waypoint"]) == "relay_cache", "save: plotted waypoint captured as String")
	_check(is_equal_approx(float(saved["fuel_mass_kg"]), 1200.0), "save: fuel captured")
	_check(absf(float(saved["course_error"]) - 0.02) < 0.001, "save: course error captured")
	var json_text: String = JSON.stringify(saved)
	var parsed: Variant = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "save: JSON round trip parses to Dictionary")
	var parsed_dict: Dictionary = {}
	if parsed is Dictionary:
		parsed_dict = parsed
	_check(nav.begin_burn(), "save: burn mutates state after save")
	harness.advance(5.0)
	nav.load_state(parsed_dict)
	var status: Dictionary = nav.get_status()
	_check(int(status["current_leg"]) == 0, "load: leg restored from JSON")
	_check(StringName(status["plotted_waypoint"]) == &"relay_cache", "load: plotted waypoint restored")
	_check(is_equal_approx(float(status["fuel_mass_kg"]), 1200.0), "load: fuel restored")
	_check(absf(float(status["course_error"]) - 0.02) < 0.001, "load: course error restored")
	nav.load_state({})
	_check(int(nav.get_status()["current_leg"]) == 0, "load: missing keys tolerated")
	_despawn_all()


func _test_console_prompt_flow() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	var console: NavConsole = _spawn_console(&"drift_marker")
	_check(console.get_interaction_prompt() == "Plot course", "console: starts on plot")
	console.interact(null)
	_check(StringName(nav.get_status()["plotted_waypoint"]) == &"drift_marker", "console: interact plots its waypoint")
	_check(console.get_interaction_prompt() == "Begin burn", "console: plotted course offers burn")
	console.interact(null)
	_check(nav.current_leg == 1, "console: burn advances leg")
	_check(console.get_interaction_prompt() == "Course complete", "console: arrival offers complete")
	console.interact(null)
	_check(nav.current_leg == 1, "console: complete interaction is inert")
	_despawn_all()


func _test_arrival() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	for waypoint_id: StringName in nav.waypoints:
		_check(nav.plot_course(waypoint_id), "arrival: plotted %s" % String(waypoint_id))
		_check(nav.begin_burn(), "arrival: burned to %s" % String(waypoint_id))
	var status: Dictionary = nav.get_status()
	_check(bool(status["arrived"]), "arrival: arrived after the final leg")
	_check(StringName(status["current_waypoint"]) == &"", "arrival: no current waypoint")
	_check(int(status["current_leg"]) == nav.waypoints.size(), "arrival: leg index at route end")
	_check(is_equal_approx(nav.fuel_mass_kg, 1020.0), "arrival: three burns consumed fuel")
	_check(not nav.plot_course(&"leg_end"), "arrival: plotting after arrival refused")
	_despawn_all()


func _on_course_changed(leg_id: StringName, delta_v_cost: float) -> void:
	_course_changed.append({"leg_id": leg_id, "delta_v_cost": delta_v_cost})


func _spawn_nav() -> NavSystem:
	var nav := NavSystem.new()
	_spawn(nav)
	return nav


func _spawn_console(waypoint_id: StringName) -> NavConsole:
	var console := NavConsole.new()
	console.waypoint_id = waypoint_id
	_spawn(console)
	return console


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_nav")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


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
