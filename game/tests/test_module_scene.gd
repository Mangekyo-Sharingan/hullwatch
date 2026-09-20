## Scene integration (M10.3): a dock mount builds a module through the sim, the pod stands at
## its hardpoint with its compartment and link wired, teardown reverses it, and a save/load
## round trip rebuilds the pod from sim state alone.
extends SceneTree

const MODULE_ID: StringName = &"utility_pod"
const HARDPOINT_ID: StringName = &"hp_quarters"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var modules: Node = main.get_node("Systems/ModuleSystem")
	var cargo: Node = main.get_node("Systems/CargoSystem")
	var atmosphere: Node = main.get_node("Systems/AtmosphereSystem")
	var plate: ModuleMount = main.get_node("ShipGeometry/HullExterior/DockPlate_quarters") as ModuleMount
	_check(modules != null and cargo != null and atmosphere != null and plate != null, "module system, cargo and the dock plate are wired")
	if plate == null:
		main.free()
		_finish()
		return
	_check(plate.hardpoint_id == HARDPOINT_ID, "plate carries its hardpoint id")
	_check(plate is ModuleMount and plate.spawns, "hull plate is the dock mount")
	_check(plate.get_interaction_prompt() == "Dock mount", "empty mount prompt")
	_check(plate.get_actions().has(StringName("build:" + String(MODULE_ID))), "mount lists the catalog module for this dock")
	_check(not plate.get_actions().has(&"teardown"), "nothing to tear down yet")

	cargo.call("add_material", &"metal", 20.0)
	cargo.call("add_material", &"ore", 10.0)
	_check(plate.select_action(&"build:utility_pod"), "mount starts the nanite build")
	await process_frame
	_check(not bool(modules.call("is_installed", MODULE_ID)), "nothing stands while the nanites work")
	_check(plate.get_actions().has(&"cancel_build"), "the mount offers to cancel a running build")
	_check(main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") == null, "no pod on the hull yet")
	modules.call("sim_tick", 8.1)
	await process_frame
	_check(modules.call("get_installed_at", HARDPOINT_ID) == MODULE_ID, "the build lands after its hours")
	_check(bool(atmosphere.call("has_compartment", &"module_utility")), "pod compartment registered")
	var pod: Node3D = main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") as Node3D
	_check(pod != null, "pod stands in the world")
	if pod == null:
		main.free()
		_finish()
		return
	var hull_face: float = plate.global_position.x - 0.075
	_check(absf(pod.global_position.x - hull_face) < 0.01, "pod origin sits on the hull's outer face")
	_check(absf(pod.global_position.z - plate.global_position.z) < 2.5, "pod lines up with its dock")
	_check(is_equal_approx(pod.rotation_degrees.y, 180.0), "west dock pod faces outward")
	_check(not (plate.get_node(^"Mesh") as MeshInstance3D).visible, "plate hides while the pod stands")
	_check((plate.get_node(^"Shape") as CollisionShape3D).disabled, "plate stops colliding so the doorway is open")
	var zone: Node = pod.find_child("Zone", true, false)
	var link: Node = pod.find_child("Link", true, false)
	_check(zone != null and StringName(zone.get(&"compartment_id")) == &"module_utility", "pod zone carries the module compartment")
	_check(link != null and StringName(link.get(&"compartment_a")) == &"module_utility" and StringName(link.get(&"compartment_b")) == &"quarters", "pod link bridges into the parent room")
	var room: ModuleMount = pod.get_node_or_null(^"PodRoom") as ModuleMount
	_check(room != null and not room.spawns and room.hardpoint_id == HARDPOINT_ID, "pod room is the teardown mount")
	if room == null:
		main.free()
		_finish()
		return
	_check(room.get_actions().has(&"teardown"), "standing pod offers teardown")
	var sockets: Array[MachineSocket] = []
	for child: Node in pod.get_children():
		if child is MachineSocket:
			sockets.append(child as MachineSocket)
	_check(sockets.size() == 3, "the pod carries three machine sockets")
	_check(sockets[0].slot_id == &"hp_quarters:0" and sockets[2].slot_id == &"hp_quarters:2", "sockets are wired to their dock and index")
	_check(sockets[0].get_actions().size() > 0, "an empty socket offers machines to fit")
	cargo.call("add_material", &"ice", 4.0)
	_check(bool(modules.call("fit_machine", &"grow_rack", &"hp_quarters:0")), "a machine fits into the pod socket")
	modules.call("sim_tick", 6.0)
	var prop: Node3D = sockets[0].get_node_or_null(^"MachineProp") as Node3D
	_check(prop != null and prop.visible, "the socket shows the fitted machine")

	var saved: Dictionary = modules.call("save_state") as Dictionary
	_check(room.select_action(&"teardown"), "teardown uninstalls the module")
	await process_frame
	_check(is_equal_approx(float(cargo.call("get_units", &"metal")), 20.0), "teardown returns the metal")
	_check(is_equal_approx(float(cargo.call("get_units", &"ore")), 10.0), "teardown returns the ore")
	_check(main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") == null, "pod leaves the world")
	_check((plate.get_node(^"Mesh") as MeshInstance3D).visible, "plate comes back")
	_check(not (plate.get_node(^"Shape") as CollisionShape3D).disabled, "plate seals the dock again")
	_check(not bool(atmosphere.call("has_compartment", &"module_utility")), "pod compartment leaves with it")

	modules.call("load_state", saved)
	await process_frame
	_check(main.get_node_or_null("ShipGeometry/HullExterior/Pod_hp_quarters") != null, "loaded save rebuilds the pod")
	_check(bool(atmosphere.call("has_compartment", &"module_utility")), "loaded save restores the pod compartment")

	main.free()
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: ", label)
		return
	_failures += 1
	print("FAIL: ", label)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_module_scene")
	else:
		print("FAILURES: ", _failures, " in test_module_scene")
	quit(0 if _failures == 0 else 1)
