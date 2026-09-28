## Tool kit regression: the six carriable tools carry an authored glTF model with a "use"
## animation each, the world layout mounts those models on the tool props, every tool id has a
## usage event that fires the animation, and taking a tool turns its model from the wall-facing
## placement yaw into the held orientation.
extends SceneTree

const LAYOUT_PATH: String = "res://scenes/world_layout.tscn"

const TOOLS: Dictionary = {
	&"multimeter": "res://assets/models/hullwatch/tools/hw_multimeter.glb",
	&"wrench": "res://assets/models/hullwatch/tools/hw_wrench.glb",
	&"scanner": "res://assets/models/hullwatch/tools/hw_scanner.glb",
	&"sealant": "res://assets/models/hullwatch/tools/hw_sealant.glb",
	&"cutter": "res://assets/models/hullwatch/tools/hw_cutter.glb",
	&"sample_canister": "res://assets/models/hullwatch/tools/hw_canister.glb",
}

## One tool prop per item id (the cutter and one canister also live on the EVA platform).
const TOOL_PROPS: Dictionary = {
	&"multimeter": "MultimeterTool",
	&"wrench": "WrenchTool",
	&"scanner": "ScannerTool",
	&"sealant": "SealantCartridge1",
	&"cutter": "CutterTool",
	&"sample_canister": "SampleCanister2",
}

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_remove_root_child(&"EventBus")
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)

	_test_models()
	_test_use_events()
	_test_held_orientation()
	_test_layout_props()

	await process_frame
	_finish()


## Every tool ships a model with meshes, a use animation, and playing all use animations at
## once actually moves the parts (one animation per moving part, mixed by the player).
func _test_models() -> void:
	for item_id: StringName in TOOLS:
		var path: String = TOOLS[item_id]
		if not ResourceLoader.exists(path):
			_check(false, "tool model exists: " + path)
			continue
		var packed: PackedScene = load(path) as PackedScene
		_check(packed != null, "tool model loads: " + path)
		if packed == null:
			continue
		var model: Node3D = packed.instantiate() as Node3D
		root.add_child(model)
		_check(model.find_children("*", "MeshInstance3D", true, false).size() >= 3, "tool model has parts: " + item_id)
		var animator: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if animator == null:
			_check(false, "tool model has an animation player: " + item_id)
			model.free()
			continue
		var use_animations: Array[StringName] = []
		for animation_name: StringName in animator.get_animation_list():
			if String(animation_name).begins_with("use"):
				use_animations.append(animation_name)
		_check(not use_animations.is_empty(), "tool model has a use animation: " + item_id)
		var before: Array[Transform3D] = _pose(model)
		for animation_name: StringName in use_animations:
			animator.play(animation_name)
		animator.advance(0.3)
		var moved: int = _moved_count(before, _pose(model))
		_check(moved >= 2, "use animations move the parts together: %s (%d)" % [String(item_id), moved])
		model.free()


## Every tool id is reachable from at least one sim event, so a used tool animates.
func _test_use_events() -> void:
	var covered: Dictionary = {}
	for event_name: StringName in Carriable.USE_EVENTS:
		for item_id: Variant in Carriable.USE_EVENTS[event_name]:
			covered[StringName(item_id)] = true
	for item_id: StringName in TOOLS:
		_check(covered.has(item_id), "a usage event fires this tool: " + item_id)


## The placement yaw is a world detail: on equip the model turns back to its authored axes.
func _test_held_orientation() -> void:
	var item := Carriable.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	item.add_child(shape)
	var model := Node3D.new()
	model.name = "Model"
	model.rotation_degrees.y = -90.0
	item.add_child(model)
	root.add_child(item)
	var holder := Node3D.new()
	root.add_child(holder)
	item.equip_to(holder)
	_check(model.rotation.is_equal_approx(Vector3.ZERO), "equipping clears the placement yaw")
	item.free()
	holder.free()


## The generated layout mounts the authored model on each tool prop, and the prop can play
## its use animation (non-looping) once the item is in hand.
func _test_layout_props() -> void:
	var packed: PackedScene = load(LAYOUT_PATH) as PackedScene
	_check(packed != null, "world layout loads")
	if packed == null:
		return
	var layout: Node3D = packed.instantiate() as Node3D
	root.add_child(layout)
	for item_id: StringName in TOOL_PROPS:
		var prop_name: String = TOOL_PROPS[item_id]
		var prop: Node3D = layout.get_node_or_null(NodePath("Props/" + prop_name)) as Node3D
		if prop == null:
			_check(false, "tool prop exists: " + prop_name)
			continue
		_check(StringName(prop.get("item_id")) == item_id, "tool prop carries its item id: " + prop_name)
		var model: Node3D = prop.get_node_or_null(^"Model") as Node3D
		if model == null or model.find_children("*", "MeshInstance3D", true, false).is_empty():
			_check(false, "tool prop mounts its model: " + prop_name)
			continue
		var animator: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_check(animator != null, "tool prop model has an animation player: " + prop_name)
		prop.call(&"play_use_animation")
		var playing: bool = animator != null and animator.is_playing()
		_check(playing, "tool prop plays its use animation: " + prop_name)
		if animator != null:
			var looping: bool = false
			for animation_name: StringName in animator.get_animation_list():
				var animation: Animation = animator.get_animation(animation_name)
				if animation != null and animation.loop_mode != Animation.LOOP_NONE:
					looping = true
			_check(not looping, "tool use animations do not loop: " + prop_name)
	layout.free()


func _pose(node: Node) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for child: Node in node.find_children("*", "Node3D", true, false):
		poses.append((child as Node3D).transform)
	return poses


func _moved_count(before: Array[Transform3D], after: Array[Transform3D]) -> int:
	var moved: int = 0
	for index: int in mini(before.size(), after.size()):
		if not before[index].is_equal_approx(after[index]):
			moved += 1
	return moved


func _remove_root_child(node_name: StringName) -> void:
	for child: Node in root.get_children():
		if child.name == node_name:
			root.remove_child(child)
			child.free()
			return


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_tool_kit")
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
