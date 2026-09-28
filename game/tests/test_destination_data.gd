extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var destinations: Array[VoyageDestination] = [
		load("res://src/data/destinations/destination_arden_ii.tres"),
		load("res://src/data/destinations/destination_kestrel_system.tres"),
	]
	_check(destinations.size() == 2, "two destination resources load")
	_check(destinations[0].kind == &"planet", "Arden II is a planet destination")
	_check(destinations[1].kind == &"star", "Kestrel is a star destination")
	var ids: Dictionary = {}
	for destination: VoyageDestination in destinations:
		_check(destination.is_valid(), "destination data is valid: " + String(destination.destination_id))
		_check(not ids.has(destination.destination_id), "destination id is unique")
		ids[destination.destination_id] = true

	var invalid: VoyageDestination = VoyageDestination.new()
	_check(not invalid.is_valid(), "empty destination data is rejected")
	invalid.destination_id = &"test"
	invalid.display_name = "Test"
	invalid.kind = &"planet"
	invalid.transit_days = 1
	invalid.fuel_cost_kg = 1.0
	invalid.sector_seed = 1
	invalid.arrival_resource = &"ice"
	invalid.arrival_resource_units = 1.0
	invalid.planet_size = 0.1
	_check(invalid.is_valid(), "well-formed destination data is accepted")
	invalid.destination_id = &""
	_check(not invalid.is_valid(), "empty destination id is rejected")
	invalid.destination_id = &"test"
	invalid.display_name = "  "
	_check(not invalid.is_valid(), "empty destination name is rejected")
	invalid.display_name = "Test"
	invalid.kind = &"comet"
	_check(not invalid.is_valid(), "unsupported destination kind is rejected")
	invalid.kind = &"planet"
	invalid.transit_days = 0
	_check(not invalid.is_valid(), "non-positive transit duration is rejected")
	invalid.transit_days = 1
	invalid.fuel_cost_kg = INF
	_check(not invalid.is_valid(), "non-finite fuel cost is rejected")
	invalid.fuel_cost_kg = 1.0
	invalid.sector_seed = 0
	_check(not invalid.is_valid(), "non-positive sector seed is rejected")
	invalid.sector_seed = 1
	invalid.arrival_resource = &"helium"
	_check(not invalid.is_valid(), "unsupported cargo kind is rejected")
	invalid.arrival_resource = &"ice"
	invalid.arrival_resource_units = INF
	_check(not invalid.is_valid(), "non-finite arrival units are rejected")
	invalid.arrival_resource_units = 1.0
	invalid.planet_size = INF
	_check(not invalid.is_valid(), "non-finite planet size is rejected")

	if _failures == 0:
		print("PASS: test_destination_data")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAILED: " + label)
