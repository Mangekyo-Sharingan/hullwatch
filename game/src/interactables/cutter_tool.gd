## Hull cutter: a tool that clips to the suit instead of taking the hand, so the operator
## can carry a sample canister while cutting.
class_name CutterTool
extends Carriable


func get_interaction_prompt() -> String:
	return "Take hull cutter"


func _handle_interact(player: Node) -> void:
	if player != null and player.has_method(&"equip_suit_cutter") and bool(player.call("equip_suit_cutter")):
		_emit_sim_event(&"tool_equipped", {"item_id": get_item_id()})
		queue_free()
		return
	super._handle_interact(player)
