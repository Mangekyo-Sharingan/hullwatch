extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var expected: Array = TubeLayout.ROOM_COMPARTMENTS.values()
	var failed: bool = false
	for path: NodePath in [^"Systems/AtmosphereSystem", ^"Systems/ThermalSystem", ^"Systems/HullSystem"]:
		var system: Node = main.get_node(path)
		var rooms: Dictionary = {}
		for config: CompartmentConfig in system.get("compartment_defs"):
			if not bool(system.call("has_compartment", config.compartment_id)):
				failed = true
			rooms[config.compartment_id] = true
		if rooms.size() != expected.size():
			failed = true
		for id: Variant in rooms:
			if not expected.has(StringName(id)):
				failed = true
	main.free()
	print("FAIL: unmatched ship compartments" if failed else "PASS: test_ship_compartments")
	quit(1 if failed else 0)
