## Base class for every ship simulator. Subclasses override sim_tick() for fixed-tick logic.
## Autoloads are resolved by node path and null-checked so headless script tests run without them.
class_name ShipSystem
extends Node

var system_id: StringName = &""


func _ready() -> void:
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null and not sim_clock.is_connected(&"ticked", _on_ticked):
		sim_clock.connect(&"ticked", _on_ticked)


func sim_tick(_delta_hours: float) -> void:
	pass


func get_status() -> Dictionary:
	return {}


func emit_sim_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.call("emit_event", event_name, payload)


## Root children fallback exists because --script SceneTree tests run before the root is in the active tree.
func _get_autoload(autoload_name: StringName) -> Node:
	if is_inside_tree():
		return get_node_or_null(NodePath("/root/" + String(autoload_name)))
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_root: Window = (main_loop as SceneTree).root
		if scene_root != null:
			for child: Node in scene_root.get_children():
				if child.name == autoload_name:
					return child
	return null


func _on_ticked(delta_hours: float, _tick_index: int) -> void:
	sim_tick(delta_hours)
