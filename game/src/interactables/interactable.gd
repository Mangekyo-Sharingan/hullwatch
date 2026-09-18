## Base class for anything the player can interact with. Interactables drive simulators; they never hold authoritative sim state.
class_name Interactable
extends StaticBody3D

signal interacted(player: Node)

@export var display_name: String = ""
@export var enabled: bool = true


func interact(player: Node) -> void:
	if not enabled:
		return
	interacted.emit(player)
	_handle_interact(player)


func get_interaction_prompt() -> String:
	return display_name


func _handle_interact(_player: Node) -> void:
	pass


func _get_system(group_name: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group_name)


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


func _emit_sim_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.call("emit_event", event_name, payload)


func _enter_tree() -> void:
	add_to_group(&"saveable")


func save_state() -> Dictionary:
	return {"enabled": enabled}


func load_state(state: Dictionary) -> void:
	if state.has("enabled"):
		enabled = bool(state["enabled"])
