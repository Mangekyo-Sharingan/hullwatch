## Scene integration: the airlock room, doors, panel and suit locker are wired to the sim,
## and a full cycle runs through the generated props in the real main scene.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	_check(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var atmosphere: Node = main.get_node("Systems/AtmosphereSystem")
	var airlock: Node = main.get_node("Systems/AirlockSystem")
	var panel: AirlockPanel = main.get_node("WorldLayout/Props/AirlockPanel") as AirlockPanel
	var locker: SuitLocker = main.get_node("WorldLayout/Props/SuitLocker") as SuitLocker
	var inner: Door = main.get_node("WorldLayout/Props/DoorAirlockInner") as Door
	var engine_bay_inner: Door = main.get_node("WorldLayout/Props/DoorJoint_airlock_engine_bay_a") as Door
	var outer: Door = main.get_node("WorldLayout/Props/DoorAirlockOuter") as Door
	_check(airlock != null and panel != null and locker != null and inner != null and engine_bay_inner != null and outer != null, "airlock system and interactables are wired")
	if airlock == null or panel == null or locker == null or inner == null or engine_bay_inner == null or outer == null:
		main.free()
		_finish()
		return
	_check(bool(atmosphere.call("has_compartment", &"airlock")), "airlock compartment is registered")
	_check(inner.get(&"airlock_side") == &"inner" and outer.get(&"airlock_side") == &"outer", "doors carry their airlock sides")
	_check(inner.get(&"airlock_id") == &"airlock_main" and outer.get(&"airlock_id") == &"airlock_main", "doors carry the airlock id")
	_check(engine_bay_inner.is_open() and engine_bay_inner.get(&"airlock_id") == &"airlock_main" and engine_bay_inner.get(&"airlock_side") == &"inner", "open engine-bay hatch is registered as a second inner door")
	_check(bool(airlock.call("get_status")["inner_open"]), "airlock summary includes every open inner door")
	_check(float(airlock.call("get_status")["pressure_kpa"]) > 90.0, "lock ships pressurized")

	inner.interact(null)
	_check(inner.is_open(), "inner door opens while pressurized")
	var frame: Node = inner.get_node_or_null(^"Frame")
	_check(frame != null, "inner doorway keeps its sensor frame")
	if frame != null:
		_check(String(frame.call("get_interaction_prompt")) == "Close door", "open inner door is targetable and says close")
	_check(not panel.select_action(&"depressurize"), "panel refuses to pump while the inner door is open")
	inner.interact(null)
	_check(not inner.is_open(), "inner door closes")
	_check(not panel.select_action(&"depressurize"), "pump refuses while the second inner door is open")
	engine_bay_inner.interact(null)
	_check(not engine_bay_inner.is_open(), "second inner door closes")
	_check(panel.select_action(&"depressurize"), "panel starts the pump")
	inner.interact(null)
	engine_bay_inner.interact(null)
	_check(not inner.is_open() and not engine_bay_inner.is_open(), "both inner doors refuse opening during pump-down")

	var sim_clock: Node = root.get_node_or_null("SimClock")
	_check(sim_clock != null, "sim clock autoload present")
	sim_clock.call("fast_forward", 0.5)
	var status: Dictionary = airlock.call("get_status")
	_check(StringName(status["state"]) == &"idle", "pump finishes")
	_check(float(status["pressure_kpa"]) < 1.0, "lock reaches vacuum")

	outer.interact(null)
	_check(outer.is_open(), "outer door opens on vacuum")
	inner.interact(null)
	engine_bay_inner.interact(null)
	_check(not inner.is_open() and not engine_bay_inner.is_open(), "both inner doors refuse while the outer door is open")
	outer.interact(null)
	_check(not outer.is_open(), "outer door closes")
	_check(panel.select_action(&"pressurize"), "panel starts repressurize")
	inner.interact(null)
	engine_bay_inner.interact(null)
	_check(not inner.is_open() and not engine_bay_inner.is_open(), "both inner doors refuse opening during pump-up")
	sim_clock.call("fast_forward", 0.5)
	status = airlock.call("get_status")
	_check(float(status["pressure_kpa"]) > 90.0, "lock repressurized")
	inner.interact(null)
	_check(inner.is_open(), "inner door opens again")
	inner.interact(null)

	_check(locker.select_action(&"refill"), "suit refills from ship air")
	_check(float(airlock.call("get_status")["suit_o2_hours"]) > 3.0, "suit tank charged")
	_check(locker.select_action(&"equip"), "suit equips from the locker")
	_check(bool(airlock.call("get_status")["suit_worn"]), "suit is worn")
	_check(not locker.select_action(&"refill"), "refill requires the suit stowed")
	_check(locker.select_action(&"store"), "suit stows")
	_check(not bool(airlock.call("get_status")["suit_worn"]), "suit no longer worn after stowing")
	_check(panel.build_readout().size() > 0 and locker.build_readout().size() > 0, "panel and locker build readouts")

	main.free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_airlock_scene")
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
