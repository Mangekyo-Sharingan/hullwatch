extends SceneTree

var _failures: int = 0


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
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_status_panel_readout()
	await _test_sleep_transition()
	await _test_hud_prompt()

	_finish()


func _test_status_panel_readout() -> void:
	var power := PowerSystem.new()
	var lighting := PowerCircuit.new()
	lighting.circuit_id = &"lighting"
	lighting.nominal_load_w = 200.0
	var defs: Array[PowerCircuit] = [lighting]
	power.circuit_defs = defs
	root.add_child(power)

	var atmosphere := AtmosphereSystem.new()
	var config := CompartmentConfig.new()
	config.compartment_id = &"main"
	config.volume_m3 = 60.0
	var compartment_defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = compartment_defs
	root.add_child(atmosphere)

	var stores := Stores.new()
	stores.initial_inventory = {&"filter_co2": 2}
	root.add_child(stores)

	var panel := StatusPanel.new()
	root.add_child(panel)

	var lines: PackedStringArray = panel.build_readout()
	var text: String = "\n".join(lines)
	_check(text.contains("DAY 1  00:00"), "readout shows the ship clock")
	_check(text.contains("BATTERY 100%"), "readout shows battery charge")
	_check(_line_with(lines, "LIGHTING").ends_with("ON"), "readout shows the lighting breaker on")
	_check(text.contains("CO2"), "readout shows CO2 levels")
	_check(text.contains("FILTER 100%"), "readout shows filter condition")
	_check(text.contains("FILTER_CO2 x2"), "readout shows stores stock")

	power.set_breaker(&"lighting", false)
	lines = panel.build_readout()
	_check(_line_with(lines, "LIGHTING").ends_with("OFF"), "readout reflects a breaker trip")

	_check(panel.get_interaction_prompt() == "Read panel", "panel prompt invites a read")
	panel.interact(null)
	_check(panel.is_open() and panel.get_interaction_prompt() == "Close panel", "panel opens on interact")
	panel.interact(null)
	_check(not panel.is_open(), "panel closes on second interact")

	power.free()
	atmosphere.free()
	stores.free()
	panel.free()


func _test_sleep_transition() -> void:
	var transition := SleepTransition.new()
	transition.fade_out_seconds = 0.02
	transition.fade_in_seconds = 0.02
	transition.summary_hold_seconds = 0.02
	root.add_child(transition)

	var sim_clock: Node = _find_root_child(&"SimClock")
	await transition.run_sleep(8.0)
	_check(absf(float(sim_clock.call("get_total_hours")) - 8.0) < 0.01, "sleep transition advances the clock")
	var summary: String = transition.get_summary_text()
	_check(summary.contains("DAY 1") and summary.contains("08:00"), "summary shows the wake day and hour")
	_check(summary.contains("8 HOURS"), "summary shows the slept duration")

	var bunk := Bunk.new()
	bunk.sleep_hours = 8.0
	root.add_child(bunk)
	bunk.interact(null)
	var frames_waited: int = 0
	while bunk.is_sleeping() and frames_waited < 600:
		await process_frame
		frames_waited += 1
	_check(not bunk.is_sleeping(), "bunk hands the transition the sleep request")
	_check(absf(float(sim_clock.call("get_total_hours")) - 16.0) < 0.01, "bunk sleep also advances the clock")

	bunk.free()
	transition.free()


func _test_hud_prompt() -> void:
	var player: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame

	var unit := ScrubberUnit.new()
	unit.position = Vector3(0.0, 1.6, -2.0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.2, 0.5)
	shape.shape = box
	unit.add_child(shape)
	root.add_child(unit)
	await physics_frame
	await physics_frame

	var hud: CanvasLayer = load("res://src/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	await process_frame
	_check(hud.call("get_prompt_text") == "Power down", "hud shows the focused interactable prompt")

	unit.interact(null)
	await process_frame
	await process_frame
	_check(hud.call("get_prompt_text") == "Open housing", "hud prompt follows interactable state")

	player.free()
	unit.free()
	hud.free()


func _line_with(lines: PackedStringArray, needle: String) -> String:
	for line: String in lines:
		if line.contains(needle):
			return line
	return ""


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_ui")
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
