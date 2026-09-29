## Interior kit regression: the remaining procedural props and the Kenney kit decorations
## carry authored glTF models, the interior door leaf is a single base-aligned mesh that
## fits a bulkhead doorway at ~1:1, and the generated layout mounts all of them.
extends SceneTree

const LAYOUT_PATH: String = "res://scenes/world_layout.tscn"

const MODELS: Dictionary = {
	"hw_bunk": "res://assets/models/hullwatch/interior/hw_bunk.glb",
	"hw_manual_stand": "res://assets/models/hullwatch/interior/hw_manual_stand.glb",
	"hw_hull_patch": "res://assets/models/hullwatch/interior/hw_hull_patch.glb",
	"hw_o2_rack": "res://assets/models/hullwatch/interior/hw_o2_rack.glb",
	"hw_probe": "res://assets/models/hullwatch/interior/hw_probe.glb",
	"hw_cargo_port": "res://assets/models/hullwatch/interior/hw_cargo_port.glb",
	"hw_airlock_panel": "res://assets/models/hullwatch/interior/hw_airlock_panel.glb",
	"hw_door_interior": "res://assets/models/hullwatch/interior/hw_door_interior.glb",
	"hw_container": "res://assets/models/hullwatch/interior/hw_container.glb",
	"hw_computer": "res://assets/models/hullwatch/interior/hw_computer.glb",
}

## Layout prop -> model root it must mount (probes share one model).
const PROP_MODELS: Dictionary = {
	"Bunk": "hw_bunk",
	"ManualBinder": "hw_manual_stand",
	"HullPatch": "hw_hull_patch",
	"O2CandleRack": "hw_o2_rack",
	"ProbePower": "hw_probe",
	"ProbeAtmosphere": "hw_probe",
	"ProbeThermal": "hw_probe",
	"ProbeHull": "hw_probe",
	"ProbeWater": "hw_probe",
	"CargoPort": "hw_cargo_port",
	"AirlockPanel": "hw_airlock_panel",
	"SuitLocker": "hw_locker",
	"ContainerProp": "hw_container",
	"ComputerProp": "hw_computer",
}

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_models()
	_test_door_leaf()
	_test_layout_props()
	_finish()


## Every kit model loads with real parts; the suit locker reuses the dressing-kit locker.
func _test_models() -> void:
	for root_name: String in MODELS:
		var path: String = MODELS[root_name]
		if not ResourceLoader.exists(path):
			_check(false, "interior model exists: " + path)
			continue
		var packed: PackedScene = load(path) as PackedScene
		_check(packed != null, "interior model loads: " + root_name)
		if packed == null:
			continue
		var model: Node3D = packed.instantiate() as Node3D
		root.add_child(model)
		var want_parts: int = 1 if root_name == "hw_door_interior" else 2
		_check(model.find_children("*", "MeshInstance3D", true, false).size() >= want_parts, "interior model has parts: " + root_name)
		model.free()
	if ResourceLoader.exists("res://assets/models/hullwatch/props/hw_locker.glb"):
		var locker: PackedScene = load("res://assets/models/hullwatch/props/hw_locker.glb") as PackedScene
		var locker_model: Node3D = (locker as PackedScene).instantiate() as Node3D
		root.add_child(locker_model)
		_check(locker_model.find_children("*", "MeshInstance3D", true, false).size() >= 2, "suit locker reuses the authored locker")
		locker_model.free()
	else:
		_check(false, "suit locker reuses the authored locker")


## The door leaf is one mesh sitting on y = 0 at doorway scale, so the fitter's
## bottom-centre pivot lands it exactly in the doorway.
func _test_door_leaf() -> void:
	var packed: PackedScene = load(MODELS["hw_door_interior"]) as PackedScene
	_check(packed != null, "door leaf loads")
	if packed == null:
		return
	var door: Node3D = packed.instantiate() as Node3D
	root.add_child(door)
	var leaf: MeshInstance3D = door.find_child("hw_door_interior", true, false) as MeshInstance3D
	_check(leaf != null and leaf.mesh != null, "door leaf is a single named mesh")
	if leaf == null or leaf.mesh == null:
		door.free()
		return
	var box: AABB = leaf.get_aabb()
	_check(absf(box.position.y) <= 0.01, "door leaf sits on y = 0")
	_check(absf(box.size.x - 0.9) <= 0.02 and absf(box.size.y - 1.85) <= 0.02, "door leaf is doorway-sized")
	door.free()


## The generated layout mounts the right model on every converted prop, and every
## bulkhead door slab uses the authored leaf (not a box fallback).
func _test_layout_props() -> void:
	var packed: PackedScene = load(LAYOUT_PATH) as PackedScene
	_check(packed != null, "world layout loads")
	if packed == null:
		return
	var layout: Node3D = packed.instantiate() as Node3D
	root.add_child(layout)
	_check(layout.get_node_or_null(^"Props/DisplayProp") == null, "static placeholder display is not generated")
	for prop_name: String in PROP_MODELS:
		var prop: Node3D = layout.get_node_or_null(NodePath("Props/" + prop_name)) as Node3D
		if prop == null:
			_check(false, "interior prop exists: " + prop_name)
			continue
		var want: String = PROP_MODELS[prop_name]
		var found: bool = false
		for child: Node in prop.find_children("*", "Node3D", true, false):
			if String((child as Node).name).begins_with(want):
				found = true
				break
		_check(found, "prop mounts its model: %s (%s)" % [prop_name, want])
		if prop.find_children("*", "MeshInstance3D", true, false).is_empty():
			_check(false, "prop model has meshes: " + prop_name)
	var doors: int = 0
	for prop: Node in layout.get_node("Props").get_children():
		if not String(prop.name).begins_with("DoorJoint_"):
			continue
		doors += 1
		var slab: Node = prop.get_node_or_null(^"Slab")
		var authored: bool = slab != null and slab.find_children("*", "MeshInstance3D", true, false).size() > 0
		if authored:
			var leaf: MeshInstance3D = slab.find_child("Leaf", true, false) as MeshInstance3D
			authored = leaf != null and leaf.mesh != null and not (leaf.mesh is BoxMesh)
		_check(authored, "bulkhead door uses the authored leaf: " + String(prop.name))
	_check(doors > 0, "bulkhead doors exist (%d)" % doors)
	layout.free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_interior_kit")
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
