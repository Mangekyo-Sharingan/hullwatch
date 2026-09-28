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
