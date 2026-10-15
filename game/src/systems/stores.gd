## Consumable and spare-parts inventory. First concrete ShipSystem; tick-ready but inert until drain lands.
class_name Stores
extends ShipSystem

const LOW_STOCK_THRESHOLD: int = 2

@export var initial_inventory: Dictionary = {}
@export var sealant_charge_part_id: StringName = &"sealant_charge"

var inventory: Dictionary = {}
var cartridge_charges: Dictionary = {}
var cartridge_legacy_restore: bool = false


func _ready() -> void:
	system_id = &"stores"
	add_to_group(&"stores_system")
	inventory = initial_inventory.duplicate()
	super._ready()
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null and not event_bus.is_connected(&"destination_arrived", _on_destination_arrived):
		event_bus.connect(&"destination_arrived", _on_destination_arrived)


func sim_tick(_delta_hours: float) -> void:
	pass


func get_status() -> Dictionary:
	var total_count: int = 0
	for count: int in inventory.values():
		total_count += count
	return {"system_id": system_id, "parts": inventory.duplicate(), "total_count": total_count, "cartridge_charges": cartridge_charges.duplicate()}


func add_part(part_id: StringName, count: int = 1) -> void:
	if part_id == &"" or count <= 0:
		push_error("Stores.add_part: part_id must be non-empty and count must be positive.")
		return
	var new_count: int = get_count(part_id) + count
	inventory[part_id] = new_count
	_emit_stores_changed(part_id, new_count)
	emit_sim_event(&"part_added", {"part_id": part_id, "count": count, "new_count": new_count})


func _on_destination_arrived(_destination_id: StringName, _kind: StringName, _sector_seed: int, _resource_id: StringName, _resource_units: float, arrival_stores: Dictionary) -> void:
	for key: Variant in arrival_stores:
		var count: int = int(arrival_stores[key])
		if count > 0:
			add_part(StringName(String(key)), count)


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


func ensure_cartridge(cartridge_id: StringName, initial_charges: int = 1) -> void:
	if cartridge_id != &"" and not cartridge_charges.has(String(cartridge_id)):
		cartridge_charges[String(cartridge_id)] = clampi(initial_charges, 0, 1)


func get_cartridge_charges(cartridge_id: StringName) -> int:
	return int(cartridge_charges.get(String(cartridge_id), 0))


func refill_cartridge(cartridge_id: StringName) -> bool:
	if not cartridge_charges.has(String(cartridge_id)) or get_cartridge_charges(cartridge_id) != 0 or not has_part(sealant_charge_part_id):
		return false
	# Commit the shell before inventory notifications so callbacks cannot refill it twice.
	cartridge_charges[String(cartridge_id)] = 1
	if not consume_part(sealant_charge_part_id):
		cartridge_charges[String(cartridge_id)] = 0
		return false
	emit_sim_event(&"sealant_cartridge_refilled", {"cartridge_id": String(cartridge_id), "charges": 1})
	return true


func consume_cartridge_charge(cartridge_id: StringName) -> bool:
	if get_cartridge_charges(cartridge_id) != 1:
		return false
	cartridge_charges[String(cartridge_id)] = 0
	emit_sim_event(&"sealant_charge_consumed", {"cartridge_id": String(cartridge_id), "charges": 0})
	return true


func _emit_stores_changed(part_id: StringName, new_count: int) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"stores_changed", part_id, new_count)


func save_state() -> Dictionary:
	var parts: Dictionary = {}
	for part_id: StringName in inventory:
		parts[String(part_id)] = int(inventory[part_id])
	return {"system_id": String(system_id), "state_version": 2, "inventory": parts, "cartridge_charges": cartridge_charges.duplicate()}


func load_state(state: Dictionary) -> void:
	var parts: Dictionary = state.get("inventory", {})
	inventory.clear()
	for key: Variant in parts:
		var part_id: StringName = StringName(key)
		var count: int = int(parts[key])
		if part_id != &"" and count > 0:
			inventory[part_id] = count

	# Clear runtime charges even for legacy loads; each legacy prop then restores
	# its original charge or consumed tombstone rather than inheriting this watch.
	cartridge_legacy_restore = int(state.get("state_version", 1)) < 2
	cartridge_charges.clear()
	if not cartridge_legacy_restore:
		var saved: Variant = state.get("cartridge_charges", {})
		if saved is Dictionary:
			for key: Variant in saved:
				var charge: Variant = saved[key]
				if key is String and not String(key).is_empty() and (charge is int or charge is float) and is_finite(float(charge)) and float(charge) in [0.0, 1.0]:
					cartridge_charges[String(key)] = int(charge)
