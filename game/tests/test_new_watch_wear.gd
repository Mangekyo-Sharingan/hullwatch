extends SceneTree


func _initialize() -> void:
	call_deferred("run_checks")


func run_checks() -> void:
	await process_frame
	root.get_node("SimClock").set_process(false)
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	var first: Node = scene.instantiate()
	root.add_child(first)
	var paths: Array[NodePath] = [^"Systems/PowerSystem", ^"Systems/AtmosphereSystem", ^"Systems/ThermalSystem", ^"Systems/HullSystem", ^"Systems/WaterSystem"]
	for path: NodePath in paths:
		var system: Node = first.get_node(path)
		for component: WearComponent in system.get("wear_components"):
			component.condition = 0.2
			component.scanned = true
			component.diagnosed = true
			system.call("force_failure", component.component_id, component.failure_modes[0].id)
	first.free()
	var second: Node = scene.instantiate()
	root.add_child(second)
	var failures: int = 0
	for path: NodePath in paths:
		var system: Node = second.get_node(path)
		for component: WearComponent in system.get("wear_components"):
			if component.is_failed() or component.scanned or component.diagnosed:
				print("FAIL: new watch inherited " + String(component.component_id))
				failures += 1
	second.free()
	if failures == 0:
		print("PASS: test_new_watch_wear")
	quit(0 if failures == 0 else 1)
