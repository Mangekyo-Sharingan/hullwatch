extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	var event_bus: Node = _find_root_child(&"EventBus")
	if event_bus != null:
		root.remove_child(event_bus)
		event_bus.free()
	_check(_find_root_child(&"EventBus") == null, "EventBus absent-safe: no EventBus autoload present")

	var stores_script: GDScript = load("res://src/systems/stores.gd")
	var stores: Node = stores_script.new() if stores_script != null else null
	_check(stores != null, "stores instantiates without autoloads")
	if stores == null:
		_finish()
		return
	root.add_child(stores)

	stores.call("add_part", &"filter_co2", 3)
	_check(stores.call("get_count", &"filter_co2") == 3, "add_part adds and get_count reflects it")

	var before_invalid: Dictionary = stores.get("inventory").duplicate()
	stores.call("add_part", &"filter_co2", 0)
	stores.call("add_part", &"", 1)
	stores.call("add_part", &"", 0)
	_check(stores.get("inventory") == before_invalid, "invalid add_part is rejected without state change")

	var consumed: bool = stores.call("consume_part", &"filter_co2", 2)
	_check(consumed and stores.call("get_count", &"filter_co2") == 1, "consume_part succeeds when sufficient")

	var before_failed: Dictionary = stores.get("inventory").duplicate()
	consumed = stores.call("consume_part", &"filter_co2", 5)
	_check(not consumed, "consume_part fails when insufficient")
	_check(stores.get("inventory") == before_failed and stores.call("get_count", &"filter_co2") == 1, "failed consume leaves inventory unchanged")

	consumed = stores.call("consume_part", &"filter_co2", 1)
	var inventory: Dictionary = stores.get("inventory")
	_check(consumed and stores.call("get_count", &"filter_co2") == 0, "consume_part to zero results in count 0")
	_check(not inventory.has(&"filter_co2"), "consume_part to zero removes part from inventory")

	stores.call("add_part", &"sealant", 2)
	_check(stores.call("has_part", &"sealant"), "has_part true when stocked")
	_check(stores.call("has_part", &"sealant", 2), "has_part true at exact count")
	_check(not stores.call("has_part", &"sealant", 3), "has_part false above available count")
	_check(not stores.call("has_part", &"filter_hepa"), "has_part false for missing part")

	stores.call("add_part", &"filter_hepa", 3)
	stores.call("add_part", &"gasket", 2)
	stores.call("add_part", &"fuse", 1)
	var low_stock: Array[StringName] = stores.call("get_low_stock")
	_check(low_stock.size() == 3, "get_low_stock selects only at/below-threshold parts")
	_check(low_stock.has(&"sealant") and low_stock.has(&"gasket") and low_stock.has(&"fuse"), "get_low_stock contains threshold and below-threshold parts")
	_check(not low_stock.has(&"filter_hepa"), "get_low_stock excludes above-threshold parts")
	_check(not low_stock.has(&"filter_co2"), "get_low_stock excludes zero-count parts")

	stores.call("add_part", &"sealant", 3)
	low_stock = stores.call("get_low_stock")
	_check(not low_stock.has(&"sealant"), "adding above threshold removes part from low stock")

	stores.call("consume_part", &"fuse", 1)
	var low_after_zero: Array[StringName] = stores.call("get_low_stock")
	_check(not low_after_zero.has(&"fuse"), "consumed-to-zero part absent from low stock")

	_test_cartridge_stock(stores)
	_finish()


func _test_cartridge_stock(stores: Node) -> void:
	stores.call("ensure_cartridge", &"shell_a", 1)
	stores.call("ensure_cartridge", &"shell_a", 1)
	_check(stores.call("get_cartridge_charges", &"shell_a") == 1, "shell registration is idempotent")
	_check(stores.call("consume_cartridge_charge", &"shell_a"), "charged shell pays one patch")
	stores.call("ensure_cartridge", &"shell_a", 1)
	_check(stores.call("get_cartridge_charges", &"shell_a") == 0, "registration cannot replenish an existing empty shell")
	_check(not stores.call("consume_cartridge_charge", &"shell_a"), "empty shell cannot pay another patch")
	_check(not stores.call("refill_cartridge", &"shell_a"), "refill without packaged stock refuses")
	stores.call("add_part", &"sealant_charge", 2)
	_check(not stores.call("refill_cartridge", &"unknown"), "unknown shell cannot withdraw supplies")
	_check(stores.call("refill_cartridge", &"shell_a"), "one package refills an empty known shell")
	_check(stores.call("get_count", &"sealant_charge") == 1 and stores.call("get_cartridge_charges", &"shell_a") == 1, "refill commits one debit and one charge")
	_check(not stores.call("refill_cartridge", &"shell_a") and stores.call("get_count", &"sealant_charge") == 1, "full-shell retry preserves packaged stock")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(stores.call("save_state"))) as Dictionary
	_check(int(saved["state_version"]) == 2, "Stores version2 includes shell ledger")
	stores.call("consume_cartridge_charge", &"shell_a")
	stores.call("load_state", saved)
	_check(stores.call("get_cartridge_charges", &"shell_a") == 1 and stores.call("get_count", &"sealant_charge") == 1, "JSON restores shell and packaged stock separately")
	stores.call("load_state", {"state_version": 1, "inventory": {"gasket": 2}})
	_check(stores.call("get_cartridge_charges", &"shell_a") == 0 and bool(stores.get("cartridge_legacy_restore")), "legacy inventory load clears runtime shell ledger for prop restoration")
	stores.call("load_state", {"state_version": 2, "inventory": {}, "cartridge_charges": {"valid": 0, "invalid": 2, "fraction": 0.5, "boolean": true, "text": "1", "": 1}})
	_check(stores.get("cartridge_charges") == {"valid": 0}, "invalid charge counts and identities cannot grant supplies")


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_stores")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
