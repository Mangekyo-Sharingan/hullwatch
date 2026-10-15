extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await _test_zone_sets_occupants()
	_finish()


func _test_zone_sets_occupants() -> void:
	var atmosphere := AtmosphereSystem.new()
	var config := CompartmentConfig.new()
	config.compartment_id = &"main"
	config.volume_m3 = 60.0
	var defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = defs
	root.add_child(atmosphere)

	var zone := CompartmentZone.new()
	zone.compartment_id = &"main"
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(4.0, 4.0, 4.0)
	zone_shape.shape = zone_box
	zone.add_child(zone_shape)
	root.add_child(zone)

	var body := CharacterBody3D.new()
	body.add_to_group(&"player")
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	body_shape.shape = capsule
	body.add_child(body_shape)
	body.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(body)

	await physics_frame
	await physics_frame
	var status: Dictionary = atmosphere.get_compartment_status(&"main")
	_check(int(status["occupants"]) == 1, "zone reports the player as an occupant")

	body.position = Vector3(20.0, 1.0, 0.0)
	await physics_frame
	await physics_frame
	status = atmosphere.get_compartment_status(&"main")
	_check(int(status["occupants"]) == 0, "zone clears occupants when the player leaves")

	zone.push_occupancy()
	status = atmosphere.get_compartment_status(&"main")
	_check(int(status["occupants"]) == 0, "explicit occupancy refresh agrees with detection")
	root.remove_child(zone)
	zone.push_occupancy()
	_check(int(atmosphere.get_compartment_status(&"main")["occupants"]) == 0, "detached zone cannot write occupancy")
	root.add_child(zone)
	atmosphere.remove_compartment(&"main")
	zone.push_occupancy()
	_check(not atmosphere.has_compartment(&"main"), "retired zone cannot recreate its simulator compartment")

	atmosphere.free()
	zone.free()
	body.free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_occupancy")
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
