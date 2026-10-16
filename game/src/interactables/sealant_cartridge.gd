## Reusable physical shell; Stores owns its one-patch charge at the stable home path.
class_name SealantCartridge
extends Carriable


func _ready() -> void:
	super._ready()
	var stores: Node = _get_system(&"stores_system")
	if stores != null:
		stores.call("ensure_cartridge", StringName(get_save_key()), 1 if enabled else 0)


func get_charge_count() -> int:
	var stores: Node = _get_system(&"stores_system")
	if stores == null or not enabled:
		return 0
	return int(stores.call("get_cartridge_charges", StringName(get_save_key())))


func consume_charge() -> bool:
	var stores: Node = _get_system(&"stores_system")
	return enabled and stores != null and bool(stores.call("consume_cartridge_charge", StringName(get_save_key())))


func get_item_name() -> String:
	return "Sealant cartridge (%s)" % ("charged" if get_charge_count() > 0 else "empty")


func get_interaction_prompt() -> String:
	return "" if is_carried() else "Take %s" % get_item_name()


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	var stores: Node = _get_system(&"stores_system")
	if stores != null:
		stores.call("ensure_cartridge", StringName(get_save_key()), 1 if enabled and bool(stores.get("cartridge_legacy_restore")) else 0)
		if not enabled:
			stores.call("consume_cartridge_charge", StringName(get_save_key()))
