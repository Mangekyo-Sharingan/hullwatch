## Door regression: isolation toggling, slab collision/offset, save/load round trip.
extends SceneTree

var _failures: int = 0
var _spawned: Array[Node] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	await _test_door_toggle()
	await _test_door_save_load()
	await _test_generated_slab()
	_finish()


func _test_door_toggle() -> void:
	var atmosphere: AtmosphereSystem = _make_atmosphere()
	var door: Door = _make_door(&"main", &"corridor")
	await physics_frame

	_check(not door.is_open(), "door starts closed")
	_check(door.get_interaction_prompt() == "Open door", "closed prompt asks to open")
	_check(_isolated(atmosphere, &"main") and _isolated(atmosphere, &"corridor"), "closed door isolates both compartments")

	var slab: MeshInstance3D = door.get_node(^"Slab") as MeshInstance3D
	var slab_shape: CollisionShape3D = door.get_node(^"SlabShape") as CollisionShape3D
	_check(slab_shape != null and not slab_shape.disabled, "closed slab collision is active")

	door.interact(null)
	_check(door.is_open(), "interact opens the door")
	_check(door.get_interaction_prompt() == "Close door", "open prompt asks to close")
	_check(not _isolated(atmosphere, &"main") and not _isolated(atmosphere, &"corridor"), "open door un-isolates both compartments")
	_check(slab_shape.disabled, "open slab collision is disabled")
	_check(slab.position.is_equal_approx(door.open_offset), "open slab moved by open_offset")

	var frame: StaticBody3D = door.get_node_or_null(^"Frame") as StaticBody3D
	_check(frame != null, "doorway keeps an interaction frame")
	if frame != null:
		_check(frame.collision_layer == 2 and frame.collision_mask == 0, "frame is a sensor the body cannot hit")
		_check(String(frame.call("get_interaction_prompt")) == "Close door", "frame forwards the open-door prompt")
		frame.call("interact", null)
		_check(not door.is_open(), "interacting with the frame closes the open door")

	_check(not door.is_open(), "door stays closed after the frame interaction")
	_check(_isolated(atmosphere, &"main") and _isolated(atmosphere, &"corridor"), "re-closed door isolates both compartments")
	_check(not slab_shape.disabled, "closed slab collision is re-enabled")
	_check(slab.position.is_equal_approx(Vector3.ZERO), "closed slab returned to its base position")

	_despawn_all()


func _test_door_save_load() -> void:
	var atmosphere: AtmosphereSystem = _make_atmosphere()
	var door: Door = _make_door(&"main", &"corridor")
	door.interact(null)
	_check(door.is_open(), "door opened before save")

	var saved: Dictionary = door.save_state()
	_check(String(saved.get("system_id", "")) == "door", "save: system_id is door")
	_check(int(saved.get("state_version", 0)) == 1, "save: state_version is 1")
	_check(bool(saved.get("open", false)), "save: open state captured")

	var json_text: String = JSON.stringify(saved)
	var parsed: Variant = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "save: JSON round trip parses to Dictionary")

	door.load_state({"open": false})
	_check(not door.is_open(), "load: closed state applied")
	_check(_isolated(atmosphere, &"main"), "load: closed door re-isolates")

	if parsed is Dictionary:
		door.load_state(parsed)
	_check(door.is_open(), "load: open state restored from JSON")
	_check(not _isolated(atmosphere, &"main") and not _isolated(atmosphere, &"corridor"), "load: open door re-syncs isolation")

	_despawn_all()


## Generated doors carry the leaf in a Slab container, not as the Slab itself: an open
## joint door must still move and stow the whole container.
func _test_generated_slab() -> void:
	_make_atmosphere()
	var door: Door = Door.new()
	door.starts_open = true
	door.hide_when_open = true
	var slab := Node3D.new()
	slab.name = &"Slab"
	var leaf := MeshInstance3D.new()
	leaf.name = &"Leaf"
	leaf.mesh = BoxMesh.new()
	slab.add_child(leaf)
	door.add_child(slab)
	var slab_shape := CollisionShape3D.new()
	slab_shape.name = &"SlabShape"
	slab_shape.shape = BoxShape3D.new()
	door.add_child(slab_shape)
	_spawn(door)
	await physics_frame
	_check(door.is_open(), "generated door ships open")
	_check(not slab.visible, "open generated slab is stowed")
	door.interact(null)
	_check(slab.visible, "closed generated slab shows again")
	_check(slab.position.is_equal_approx(Vector3.ZERO), "closed generated slab sits in its doorway")
	_despawn_all()


func _make_atmosphere() -> AtmosphereSystem:
	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	var defs: Array[CompartmentConfig] = []
	for compartment_id: StringName in [&"main", &"corridor"]:
		var config: CompartmentConfig = CompartmentConfig.new()
		config.compartment_id = compartment_id
		config.volume_m3 = 50.0
		defs.append(config)
	atmosphere.compartment_defs = defs
	_spawn(atmosphere)
	return atmosphere


func _make_door(compartment_a: StringName, compartment_b: StringName) -> Door:
	var door: Door = Door.new()
	door.compartment_a = compartment_a
	door.compartment_b = compartment_b
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.name = &"Slab"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(3.0, 2.2, 0.16)
	slab.mesh = box_mesh
	door.add_child(slab)
	var slab_shape: CollisionShape3D = CollisionShape3D.new()
	slab_shape.name = &"SlabShape"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(3.0, 2.2, 0.16)
	slab_shape.shape = box_shape
	door.add_child(slab_shape)
	var frame: StaticBody3D = StaticBody3D.new()
	frame.name = &"Frame"
	frame.collision_layer = 2
	frame.collision_mask = 0
	frame.set_script(load("res://src/interactables/door_frame.gd") as Script)
	door.add_child(frame)
	var frame_shape: CollisionShape3D = CollisionShape3D.new()
	frame_shape.name = &"FrameShape"
	var frame_box: BoxShape3D = BoxShape3D.new()
	frame_box.size = Vector3(0.05, 2.2, 3.0)
	frame_shape.shape = frame_box
	frame.add_child(frame_shape)
	_spawn(door)
	return door


func _isolated(atmosphere: AtmosphereSystem, compartment_id: StringName) -> bool:
	return bool(atmosphere.get_compartment_status(compartment_id).get("isolated", false))


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_door")
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
