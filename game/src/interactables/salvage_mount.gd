class_name SalvageMount
extends Interactable

@export var unit_id: String = ""
@export var action: StringName = &"detach"


func get_interaction_prompt() -> String:
	var salvage: Node = _get_system(&"salvage_system")
	if salvage == null:
		return "Recovery mount offline"
	var unit: Dictionary = salvage.call("get_unit", unit_id)
	if String(unit.get("location", "")) != "mounted":
		return "Empty recovery mount"
	if action == &"isolate":
		return "Recovery supply isolated" if bool(unit.get("isolated", false)) else "Isolate recovery supply"
	return "Unbolt recovered equipment (wrench)" if bool(unit.get("isolated", false)) else "Equipment energized - isolate supply first"


func _handle_interact(player: Node) -> void:
	var salvage: Node = _get_system(&"salvage_system")
	if salvage == null:
		return
	if action == &"isolate":
		salvage.call("isolate_unit", unit_id)
		return
	var tool: StringName = &""
	if player != null and player.has_method("get_carried_item_id"):
		tool = StringName(player.call("get_carried_item_id"))
	var sector: Node = _get_system(&"sector_system")
	var position: Vector3 = global_position + Vector3(0.0, 0.0, -0.6)
	if sector != null:
		position += sector.call("get_ship_position") as Vector3
	salvage.call("release_unit", unit_id, tool, position)
