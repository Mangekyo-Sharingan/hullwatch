extends SceneTree

var _failures: int = 0
var _tick_count: int = 0
var _last_tick_index: int = 0


func _initialize() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_instance: Node = null
	if main_scene != null:
		main_instance = main_scene.instantiate()
		root.add_child(main_instance)
	_check(main_instance != null, "scene loads")

	var sim_clock_script: GDScript = load("res://src/autoload/sim_clock.gd")
	var event_bus_script: GDScript = load("res://src/autoload/event_bus.gd")
	var sim_clock: Node = sim_clock_script.new() if sim_clock_script != null else null
	var event_bus: Node = event_bus_script.new() if event_bus_script != null else null
	if sim_clock != null:
		root.add_child(sim_clock)
	if event_bus != null:
		root.add_child(event_bus)
	_check(sim_clock != null, "sim_clock instantiates")
	_check(event_bus != null, "event_bus instantiates")

	if sim_clock != null:
		sim_clock.connect(&"ticked", _on_clock_ticked)
		var seconds_before: float = sim_clock.get("sim_seconds")
		sim_clock.call("fast_forward", 1.0)
		var seconds_after: float = sim_clock.get("sim_seconds")
		_check(_tick_count == 600, "ticked fired 600 times")
		_check(_last_tick_index == 600, "tick_index == 600")
		_check(absf(seconds_after - seconds_before - 3600.0) <= 0.001, "sim_seconds advanced 3600.0")

	var stores_script: GDScript = load("res://src/systems/stores.gd")
	var stores: Node = stores_script.new() if stores_script != null else null
	_check(stores != null, "stores instantiates")
	if stores != null:
		root.add_child(stores)
		stores.call("add_part", &"filter_co2", 3)
		_check(stores.call("get_count", &"filter_co2") == 3, "stores add_part")

	_check(InputMap.has_action(&"move_forward"), "input map has move_forward")
	_check(InputMap.has_action(&"interact"), "input map has interact")
	_check(InputMap.has_action(&"toggle_boots"), "input map has toggle_boots")
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	_check(player_scene != null, "player scene loads")

	if _failures == 0:
		print("PASS: smoke_test")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _on_clock_ticked(_delta_hours: float, tick_index: int) -> void:
	_tick_count += 1
	_last_tick_index = tick_index


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
