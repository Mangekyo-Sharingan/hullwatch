class_name SalvageCase
extends Carriable

var unit_id: String = ""


func _ready() -> void:
	super._ready()
	item_id = &"recovered_equipment"
	item_name = "Recovered equipment case"


func _handle_interact(player: Node) -> void:
	var salvage: Node = _get_system(&"salvage_system")
	if salvage == null or player == null or not player.has_method("take_carriable"):
		return
	if is_carried() or String((salvage.call("get_unit", unit_id) as Dictionary).get("location", "")) != "world":
		return
	player.call("take_carriable", self)


func equip_to(holder: Node3D) -> void:
	var salvage: Node = _get_system(&"salvage_system")
	if salvage == null or not bool(salvage.call("take_unit", unit_id)):
		return
	super.equip_to(holder)


func unequip(drop_transform: Transform3D) -> void:
	super.unequip(drop_transform)
	var salvage: Node = _get_system(&"salvage_system")
	if salvage != null:
		var position: Vector3 = global_position
		var sector: Node = _get_system(&"sector_system")
		if sector != null:
			position += sector.call("get_ship_position") as Vector3
		salvage.call("drop_unit", unit_id, position)


func get_unit_id() -> String:
	return unit_id
