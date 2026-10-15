## Hull cutter: a tool that clips to the suit instead of taking the hand, so the operator
## can carry a sample canister while cutting.
class_name CutterTool
extends Carriable

## Rides the suit's chest on the operator's left (the carry slot is on the right), angled
## across the body and low enough to clear the eye line.
const SUIT_CLIP_OFFSET: Vector3 = Vector3(-0.30, -0.20, -0.42)
const SUIT_CLIP_ROTATION: Vector3 = Vector3(0.0, 35.0, -12.0)


func get_interaction_prompt() -> String:
	return "Take hull cutter"


func _handle_interact(player: Node) -> void:
	if player != null and player.has_method(&"equip_suit_cutter") and bool(player.call("equip_suit_cutter")):
		_clip_to_suit(player)
		_emit_sim_event(&"tool_equipped", {"item_id": get_item_id()})
		return
	super._handle_interact(player)


## The player's carry slot stays free for a sample canister: the cutter only rides the view.
func _clip_to_suit(player: Node) -> void:
	if not player.has_method(&"get_hold_anchor"):
		return
	var anchor: Node3D = player.call("get_hold_anchor") as Node3D
	if anchor == null:
		return
	equip_to(anchor)
	position = SUIT_CLIP_OFFSET
	rotation_degrees = SUIT_CLIP_ROTATION


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["clipped"] = is_carried()
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if enabled and bool(state.get("clipped", false)) and player != null:
		player.call("equip_suit_cutter")
		_clip_to_suit(player)
