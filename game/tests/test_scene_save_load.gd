## Robustness: full-scene save/load round trip through the real main scene and SaveManager.
extends SceneTree

const SLOT: int = 3

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var sim_clock: Node = _find_root_child(&"SimClock")
	var save_manager: Node = _find_root_child(&"SaveManager")
	_check(sim_clock != null and save_manager != null, "scene: clock and save manager available")
	if sim_clock == null or save_manager == null:
		_finish()
		return
	save_manager.call("delete_save", SLOT)

	var power: PowerSystem = main.get_node("Systems/PowerSystem")
	var atmosphere: AtmosphereSystem = main.get_node("Systems/AtmosphereSystem")
	var stores: Stores = main.get_node("Systems/Stores")
	var breaker: BreakerPanel = main.get_node("Props/BreakerPanel")

	sim_clock.call("fast_forward", 6.0)
	breaker.interact(null)
	power.call("force_failure", &"rtg_main", &"rtg_degraded")
	_check(not power.is_breaker_on(&"lighting"), "scene: lighting breaker toggled off")
	_check(power.get_generation_w() < 500.0, "scene: rtg derated by the failure")

	var hours_before: float = float(sim_clock.call("get_total_hours"))
	var co2_before: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	var rations_before: int = stores.get_count(&"food_ration")
	_check(bool(save_manager.call("save_to_slot", SLOT)), "scene: save writes a slot")

	sim_clock.call("fast_forward", 4.0)
	breaker.interact(null)
	power.call("repair_component", &"rtg_main", 1.0)
	_check(power.is_breaker_on(&"lighting") and power.get_generation_w() > 400.0, "scene: state mutated after the save")

	_check(bool(save_manager.call("load_from_slot", SLOT)), "scene: load succeeds")
	await process_frame
	_check(absf(float(sim_clock.call("get_total_hours")) - hours_before) < 0.01, "scene: clock restored (%.2f h)" % hours_before)
	_check(not power.is_breaker_on(&"lighting"), "scene: breaker state restored")
	_check(power.get_generation_w() < 500.0, "scene: rtg failure effect restored (%.0f W)" % power.get_generation_w())
	var co2_after: float = float(atmosphere.get_compartment_status(&"main")["co2_ppm"])
	_check(absf(co2_after - co2_before) < 50.0, "scene: compartment CO2 restored")
	_check(stores.get_count(&"food_ration") == rations_before, "scene: ration stock restored")

	sim_clock.call("fast_forward", 1.0)
	_check(not atmosphere.get_compartment_status(&"main").is_empty(), "scene: simulation continues after load")

	save_manager.call("delete_save", SLOT)
	main.free()
	_finish()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_scene_save_load")
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
