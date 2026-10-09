## Cabin lights follow the live lighting breaker through EventBus events.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var lights: Array[Node] = main.find_children("CabinLight*", "OmniLight3D", true, false)
	var breaker: BreakerPanel = main.get_node("WorldLayout/Props/BreakerPanel") as BreakerPanel
	_check(not lights.is_empty(), "live scene has generated cabin lights")
	_check(_lights_visible(lights), "lights start on with the lighting circuit")
	breaker.interact(null)
	_check(not _lights_visible(lights), "lights turn off when the lighting breaker opens")
	breaker.interact(null)
	_check(_lights_visible(lights), "lights turn on when the lighting breaker closes")

	var power: PowerSystem = main.get_node("Systems/PowerSystem") as PowerSystem
	var generation_before: Dictionary = power.generators.duplicate()
	var discharge_before: float = power.battery_max_discharge_w
	for generator_id: Variant in generation_before:
		power.set_generation(StringName(generator_id), 0.0)
	power.battery_max_discharge_w = 0.0
	power.sim_tick(0.001)
	_check(power.is_circuit_shed(&"lighting"), "brownout shedding marks the lighting circuit shed")
	_check(not _lights_visible(lights), "cabin fixtures turn off when the circuit is automatically shed")
	power.set_generation(&"rtg_main", 10000.0)
	power.battery_max_discharge_w = discharge_before
	power.sim_tick(0.001)
	_check(not power.is_circuit_shed(&"lighting"), "restored generation clears the lighting shed state")
	_check(_lights_visible(lights), "cabin fixtures return when power restores the circuit")
	for generator_id: Variant in generation_before:
		power.set_generation(StringName(generator_id), float(generation_before[generator_id]))

	breaker.interact(null)
	var saved_power_state: Dictionary = power.save_state()
	breaker.interact(null)
	power.load_state(saved_power_state)
	await process_frame
	_check(not power.is_breaker_on(&"lighting"), "loading restores the saved lighting breaker state")
	_check(not _lights_visible(lights), "fixture visibility follows a restored breaker state")

	main.free()
	if _failures == 0:
		print("PASS: test_cabin_light")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _lights_visible(lights: Array[Node]) -> bool:
	for node: Node in lights:
		var light: OmniLight3D = node as OmniLight3D
		if not light.visible:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
