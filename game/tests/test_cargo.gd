## Cargo tests: capacity enforcement, add/consume conservation, events and save/load.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var cargo: CargoSystem = CargoSystem.new()
	cargo.capacity_units = 10.0
	root.add_child(cargo)
	_check(cargo.add_material(&"unknown", 1.0) == 0.0, "unknown material is refused")
	_check(cargo.add_material(&"ice", NAN) == 0.0, "nonfinite credit is refused")
	_check(cargo.add_material(&"ice", INF) == 0.0, "infinite credit is refused")
	_check(not cargo.consume_material(&"ice", -1.0), "negative debit is refused")
	_check(not cargo.consume_material(&"ice", NAN), "nonfinite debit is refused")
	_check(cargo.get_used_units() == 0.0, "invalid transfers leave an empty hold unchanged")

	_check(is_equal_approx(cargo.get_free_units(), 10.0), "empty hold shows full capacity")
	_check(is_equal_approx(cargo.add_material(&"ice", 4.0), 4.0), "ice stows fully when it fits")
	_check(is_equal_approx(cargo.get_units(&"ice"), 4.0), "ice units are held")
	_check(is_equal_approx(cargo.add_material(&"ore", 8.0), 6.0), "an oversized load is capped to the free space")
	_check(is_equal_approx(cargo.get_used_units(), 10.0), "the hold reports full")
	_check(is_equal_approx(cargo.add_material(&"metal", 2.0), 0.0), "a full hold refuses more material")

	_check(cargo.consume_material(&"ice", 3.0), "consuming available material succeeds")
	_check(is_equal_approx(cargo.get_units(&"ice"), 1.0), "consumption subtracts exactly")
	_check(not cargo.consume_material(&"metal", 1.0), "consuming absent material refuses")
	_check(not cargo.consume_material(&"ore", 99.0), "consuming beyond stock refuses")
	_check(is_equal_approx(cargo.get_units(&"ore"), 6.0), "refused consumption changes nothing")

	var status: Dictionary = cargo.get_status()
	_check(int(status["capacity_units"]) == 10, "status reports the capacity")
	_check(absf(float(status["used_units"]) - 7.0) < 0.001, "status reports used units after consumption")

	var saved: Dictionary = cargo.save_state()
	var restored: CargoSystem = CargoSystem.new()
	restored.capacity_units = 1.0
	root.add_child(restored)
	restored.load_state(saved)
	_check(is_equal_approx(restored.get_units(&"ice"), 1.0), "save/load restores ice")
	_check(is_equal_approx(restored.get_units(&"ore"), 6.0), "save/load restores ore")
	_check(absf(restored.capacity_units - 10.0) < 0.001, "save/load restores the capacity")
	for invalid: Dictionary in [
		{"materials": {"unknown": 1.0}}, {"materials": {"ice": -1.0}},
		{"materials": {"ice": NAN}}, {"capacity_units": INF}, {"materials": []},
	]:
		var before: Dictionary = restored.save_state()
		restored.load_state(invalid)
		_check(restored.save_state() == before, "invalid cargo load refuses before changing existing stock")
	restored.set_reserved_source(&"equipment", 2.0)
	_check(restored.get_used_units() == 9.0, "material accounting includes existing equipment reservations")
	_check(not restored.consume_material(&"ore", 6.00001), "debit cannot make a negative remainder")

	cargo.free()
	restored.free()
	if _failures == 0:
		print("PASS: test_cargo")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
