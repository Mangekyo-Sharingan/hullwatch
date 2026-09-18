## Interaction-only sensor in a doorway. An open door's slab slides away and takes its
## collision with it, so this frame keeps the doorway targetable and forwards to the door.
## It sits on the sensor layer and never blocks movement.
class_name DoorFrame
extends Interactable


func _enter_tree() -> void:
	pass


func get_interaction_prompt() -> String:
	var door: Node = get_parent()
	if door != null and door.has_method(&"get_interaction_prompt"):
		return String(door.call("get_interaction_prompt"))
	return ""


func _handle_interact(player: Node) -> void:
	var door: Node = get_parent()
	if door != null and door.has_method(&"interact"):
		door.call("interact", player)
