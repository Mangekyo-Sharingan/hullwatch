## Hull cargo port on the EVA platform: stows a loaded sample canister into the hold.
class_name CargoPort
extends Interactable

func get_interaction_prompt() -> String:
	var player: Node = _first_player()
	var canister: Node = _carried_canister(player)
	if canister != null and not bool(canister.call("is_empty")):
		var load: Dictionary = canister.call("get_load")
		return "Stow %s %.0f" % [String(load["kind"]).to_upper(), float(load["units"])]
	return "Cargo port"


func _handle_interact(player: Node) -> void:
	var canister: Node = _carried_canister(player)
	if canister == null or bool(canister.call("is_empty")):
		_emit_sim_event(&"procedure_error", {"reason": &"no_sample"})
		return
	var cargo: Node = _get_system(&"cargo_system")
	if cargo == null:
		return
	var load: Dictionary = canister.call("get_load")
	var accepted: float = float(cargo.call("add_material", StringName(String(load["kind"])), float(load["units"])))
	if accepted <= 0.0:
		_emit_sim_event(&"procedure_error", {"reason": &"cargo_full"})
		return
	canister.call("unload")
	_emit_sim_event(&"sample_stowed", {"kind": String(load["kind"]), "units": accepted})


func _first_player() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group(&"player")


func _carried_canister(player: Node) -> Node:
	if player == null or not player.has_method(&"get_carried"):
		return null
	var item: Node = player.call("get_carried") as Node
	if item == null or not item.has_method(&"is_empty"):
		return null
	return item
