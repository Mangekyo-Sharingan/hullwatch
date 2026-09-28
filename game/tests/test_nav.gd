## Deterministic navigation checks: plot costs, course drift, transit, arrival and persistence.
extends SceneTree

var _failures: int = 0
var _spawned: Array[Node] = []
var _course_changed: Array[Dictionary] = []


func _initialize() -> void:
	await process_frame
	_test_absent_safe()
	_test_plot_and_arrival()
	_test_course_expiry()
	_test_save_load_and_legacy_state()
	_test_console_flow()
	_despawn_all()
	_finish()


func _test_absent_safe() -> void:
	_remove_root_child(&"EventBus")
	_remove_root_child(&"SimClock")
	var nav: NavSystem = _spawn_nav()
	_check(nav.plot_course(&"arden_ii"), "absent-safe: plot works without autoloads")
	_check(nav.begin_transit(), "absent-safe: transit starts without autoloads")
	nav.sim_tick(24.0)
	_check(is_equal_approx(nav.transit_elapsed_hours, 24.0), "absent-safe: transit advances without SimClock")
	_despawn_all()


func _test_plot_and_arrival() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	_course_changed.clear()
	var event_bus: Node = _find_root_child(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"course_changed", _on_course_changed)
	var nav: NavSystem = _spawn_nav()
	var sector := SectorSystem.new()
	_spawn(sector)
	var cargo := CargoSystem.new()
	_spawn(cargo)
	var stores := Stores.new()
	stores.initial_inventory = {}
	_spawn(stores)
	var start_seed: int = sector.field_seed
	_check(nav.plot_course(&"arden_ii"), "plot: known planet accepted")
	_check(nav.plotted_destination_id == &"arden_ii", "plot: destination recorded")
	_check(is_equal_approx(nav.fuel_mass_kg, 1195.0), "plot: course-setting fuel consumed")
	_check(is_equal_approx(harness.hours(), 1.0), "plot: course-setting time advances the whole simulation")
	_check(_course_changed.size() == 1, "plot: typed course_changed emitted")
	_check(is_equal_approx(float(_course_changed[0]["fuel_cost_kg"]), 180.0), "plot: typed signal carries transit fuel budget")
	_check(not nav.plot_course(&"kestrel_system"), "plot: a course must be cancelled before replacing it")
	_check(nav.begin_transit(), "transit: plotted course starts")
	_check(bool(nav.get_status()["transit_active"]), "transit: active state is visible")
	_check(is_equal_approx(nav.fuel_mass_kg, 1195.0), "transit: fuel is consumed over the route")
	for _day: int in range(2):
		nav.sim_tick(24.0)
	_check(not bool(nav.get_status()["transit_active"]), "arrival: transit ends at the destination")
	_check(nav.current_destination_id == &"arden_ii", "arrival: current destination updates")
	_check(is_equal_approx(nav.fuel_mass_kg, 1015.0), "arrival: route fuel is consumed exactly")
	_check(sector.field_seed == 73019, "arrival: sector seed swaps to the planet field")
	_check(is_equal_approx(sector.get_drift_distance(), 0.0), "arrival: field drift resets at the new sector")
	_check(is_equal_approx(cargo.get_units(&"ice"), 4.0), "arrival: destination material reaches cargo")
	_check(stores.get_count(&"food_ration") == 3, "arrival: finite ration cache reaches stores")
	_check(stores.get_count(&"filter_co2") == 1, "arrival: life-support cache reaches stores")
	_check(harness.events_named(&"destination_arrived").size() == 1, "arrival: one destination event is emitted")
	_check(harness.events_named(&"transit_day_advanced").size() == 2, "transit: each full day is recorded")
	_despawn_all()


func _test_course_expiry() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	nav.course_error_per_hour = 0.1
	_check(nav.plot_course(&"kestrel_system"), "expiry: long route plotted")
	_check(float(nav.get_status()["course_error"]) > 0.19, "expiry: plotting time adds measurable drift")
	harness.advance(5.0)
	_check(nav.plotted_destination_id == &"kestrel_system", "expiry: course survives before error saturates")
	harness.advance(4.0)
	_check(nav.plotted_destination_id == &"", "expiry: course clears when drift saturates")
	_check(harness.events_named(&"course_expired").size() == 1, "expiry: one course-expired event is emitted")
	_despawn_all()


func _test_save_load_and_legacy_state() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	_check(nav.plot_course(&"arden_ii"), "save: course plotted")
	_check(nav.begin_transit(), "save: transit started")
	nav.sim_tick(24.0)
	var saved: Dictionary = nav.save_state()
	_check(int(saved["state_version"]) == 2, "save: current state version recorded")
	nav.sim_tick(12.0)
	nav.load_state(saved)
	_check(nav.transit_active, "load: active transit restored")
	_check(is_equal_approx(nav.transit_elapsed_hours, 24.0), "load: elapsed transit restored")
	_check(is_equal_approx(nav.fuel_mass_kg, 1105.0), "load: fuel restored")
	nav.load_state({"state_version": 1, "current_leg": 1, "plotted_waypoint": "drift_marker", "fuel_mass_kg": 900.0, "course_error": 0.2})
	_check(nav.current_destination_id == &"arden_ii", "migration: prior completed leg maps to first destination")
	_check(nav.plotted_destination_id == &"kestrel_system", "migration: prior plotted leg maps to the next destination")
	_check(is_equal_approx(nav.fuel_mass_kg, 900.0), "migration: legacy fuel is preserved")
	_despawn_all()


func _test_console_flow() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var nav: NavSystem = _spawn_nav()
	var console := NavConsole.new()
	_spawn(console)
	_check(console.get_interaction_prompt() == "Open star chart", "console: prompts the star chart")
	console.interact(null)
	_check(console.is_open(), "console: interaction opens the chart")
	_check(console.get_actions() == [&"arden_ii", &"kestrel_system"], "console: lists available destinations")
	_check(console.select_action(&"arden_ii"), "console: selection plots route")
	_check(console.get_actions() == [&"begin_transit", &"cancel_course"], "console: plotted route requires confirmation")
	_check(console.get_interaction_prompt() == "Close star chart", "console: open prompt offers close")
	_check(console.select_action(&"begin_transit"), "console: confirmation begins travel")
	_check(bool(nav.get_status()["transit_active"]), "console: autopilot engages")
	_check(" ".join(console.build_readout()).contains("SHIP SYSTEMS REMAIN ON DUTY"), "console: readout explains live transit")
	console.close()
	_check(not console.is_open(), "console: chart closes")
	_despawn_all()


func _spawn_nav() -> NavSystem:
	var nav := NavSystem.new()
	var arden: VoyageDestination = load("res://src/data/destinations/destination_arden_ii.tres")
	var kestrel: VoyageDestination = load("res://src/data/destinations/destination_kestrel_system.tres")
	nav.destinations = [arden, kestrel]
	_spawn(nav)
	return nav


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _remove_root_child(node_name: StringName) -> void:
	var node: Node = _find_root_child(node_name)
	if node != null:
		root.remove_child(node)
		node.free()


func _on_course_changed(destination_id: StringName, fuel_cost_kg: float) -> void:
	_course_changed.append({"destination_id": destination_id, "fuel_cost_kg": fuel_cost_kg})


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_nav")
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
