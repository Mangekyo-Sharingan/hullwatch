## Consumable and spare-parts inventory. First concrete ShipSystem; tick-ready but inert until drain lands.
class_name Stores
extends ShipSystem

const LOW_STOCK_THRESHOLD: int = 2

@export var initial_inventory: Dictionary = {}

var inventory: Dictionary = {}


func _ready() -> void:
	system_id = &"stores"
	add_to_group(&"stores_system")
	inventory = initial_inventory.duplicate()
	super._ready()


func sim_tick(_delta_hours: float) -> void:
	pass


func get_status() -> Dictionary:
	var total_count: int = 0
	for count: int in inventory.values():
		total_count += count
	return {"system_id": system_id, "parts": inventory.duplicate(), "total_count": total_count}


func add_part(part_id: StringName, count: int = 1) -> void:
	if part_id == &"" or count <= 0:
		push_error("Stores.add_part: part_id must be non-empty and count must be positive.")
		return
	var new_count: int = get_count(part_id) + count
	inventory[part_id] = new_count
	_emit_stores_changed(part_id, new_count)
	emit_sim_event(&"part_added", {"part_id": part_id, "count": count, "new_count": new_count})


func consume_part(part_id: StringName, count: int = 1) -> bool:
	if part_id == &"" or count <= 0:
		return false
	var available: int = get_count(part_id)
	if available < count:
		return false
	var new_count: int = available - count
	if new_count == 0:
		inventory.erase(part_id)
	else:
		inventory[part_id] = new_count
	_emit_stores_changed(part_id, new_count)
	emit_sim_event(&"part_consumed", {"part_id": part_id, "count": count, "new_count": new_count})
	if new_count <= LOW_STOCK_THRESHOLD:
		emit_sim_event(&"stores_low", {"part_id": part_id, "new_count": new_count})
	return true


func get_count(part_id: StringName) -> int:
	if not inventory.has(part_id):
		return 0
	return inventory[part_id]


func has_part(part_id: StringName, count: int = 1) -> bool:
	if count <= 0:
		return false
	return get_count(part_id) >= count


func get_low_stock() -> Array[StringName]:
	var low_stock: Array[StringName] = []
	for part_id: StringName in inventory:
		var count: int = inventory[part_id]
		if count > 0 and count <= LOW_STOCK_THRESHOLD:
			low_stock.append(part_id)
	return low_stock


func _emit_stores_changed(part_id: StringName, new_count: int) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"stores_changed", part_id, new_count)
