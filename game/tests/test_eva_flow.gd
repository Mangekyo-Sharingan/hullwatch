## M7.7 end-to-end: suit up, cycle out, auto-clip the tether, try to drift away,
## return, repressurize and stow - through the real main scene and its systems.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main_scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_check(main_scene != null, "main scene loads")
	if main_scene == null:
		_finish()
		return
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var airlock: Node = main.get_node("Systems/AirlockSystem")
	var panel: AirlockPanel = main.get_node("WorldLayout/Props/AirlockPanel") as AirlockPanel
	var locker: SuitLocker = main.get_node("WorldLayout/Props/SuitLocker") as SuitLocker
	var inner: Door = main.get_node("WorldLayout/Props/DoorAirlockInner") as Door
	var engine_bay_inner: Door = main.get_node("WorldLayout/Props/DoorJoint_airlock_engine_bay_a") as Door
	var outer: Door = main.get_node("WorldLayout/Props/DoorAirlockOuter") as Door
	var player: CharacterBody3D = main.get_node("Player") as CharacterBody3D
	_check(airlock != null and panel != null and locker != null and inner != null and engine_bay_inner != null and outer != null and player != null, "the EVA cast is wired")
	if airlock == null or panel == null or locker == null or inner == null or engine_bay_inner == null or outer == null or player == null:
		main.free()
		_finish()
		return
	var sim_clock: Node = root.get_node_or_null("SimClock")
	_check(sim_clock != null, "sim clock autoload present")

	_check(locker.select_action(&"refill"), "suit tank fills from ship air")
	_check(locker.select_action(&"equip"), "suit is worn")
	engine_bay_inner.interact(null)
	_check(not engine_bay_inner.is_open(), "the second inner hatch closes for cycling")
	_check(panel.select_action(&"depressurize"), "lock pumps down with the inner hatch closed")
	sim_clock.call("fast_forward", 0.5)
	_check(float(airlock.call("get_status")["pressure_kpa"]) < 1.0, "lock reaches vacuum")

	outer.interact(null)
	_check(outer.is_open(), "outer hatch opens on vacuum")
	await create_timer(Door.SLIDE_DURATION_SECONDS + 0.1).timeout
	_check(
		_capsule_segment_clear(player, Vector2(0.0, -0.65), Vector2(-3.6, -0.65)),
		"standing capsule can walk through the open radial hatch onto the EVA platform"
	)
	player.global_position = Vector3(-3.6, 0.2, -0.65)
	await physics_frame
	await physics_frame
	await physics_frame
	_check(bool(player.call("is_tethered")), "stepping onto the platform auto-clips the tether")

	player.global_position = Vector3(-40.0, 0.2, -1.2)
	await physics_frame
	await physics_frame
	var distance: float = float(player.call("get_tether_distance"))
	_check(distance <= 14.05, "the taut line holds the operator (%.2f m)" % distance)

	player.global_position = Vector3(0.0, 0.2, -0.65)
	await physics_frame
	player.call("release_tether")
	outer.interact(null)
	_check(not outer.is_open(), "outer hatch closes")
	_check(panel.select_action(&"pressurize"), "lock repressurizes")
	sim_clock.call("fast_forward", 0.5)
	_check(float(airlock.call("get_status")["pressure_kpa"]) > 90.0, "lock is habitable again")
	inner.interact(null)
	_check(inner.is_open(), "inner hatch opens home")
	inner.interact(null)
	_check(locker.select_action(&"store"), "suit stows in the locker")
	engine_bay_inner.interact(null)
	_check(engine_bay_inner.is_open(), "the second inner hatch reopens after the EVA")

	var save_manager: Node = root.get_node_or_null("SaveManager")
	if save_manager != null:
		var snapshot: Dictionary = save_manager.call("save_to_dict")
		var systems: Dictionary = snapshot.get("systems", {})
		_check(systems.has("airlock"), "save snapshot carries the airlock state")
		if systems.has("airlock"):
			_check(bool((systems["airlock"] as Dictionary).has("suit_worn")), "airlock save captures the suit")
	var event_bus: Node = root.get_node_or_null("EventBus")
	if event_bus != null:
		var names: PackedStringArray = PackedStringArray()
		for entry: Dictionary in event_bus.get("event_log"):
			names.append(String(entry["name"]))
		_check(names.has("tether_attached"), "tether_attached was logged")
		_check(names.has("tether_released"), "tether_released was logged")

	main.free()
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_eva_flow")
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


func _capsule_segment_clear(player: CharacterBody3D, start: Vector2, finish: Vector2) -> bool:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.75
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	var steps: int = ceili(start.distance_to(finish) / 0.12)
	for step: int in steps + 1:
		var point: Vector2 = start.lerp(finish, float(step) / float(maxi(steps, 1)))
		query.transform = Transform3D(Basis(), Vector3(point.x, 0.925, point.y))
		var overlaps: Array[Dictionary] = space.intersect_shape(query, 1)
		if not overlaps.is_empty():
			var blocker: Node = overlaps[0].get("collider") as Node
			print("Capsule EVA path blocked at %s by %s" % [point, blocker.get_path() if blocker != null else "unknown"])
			return false
	return true
