## Carry/pickup: Carriable equip/unequip contract, player carry slot, HUD carry line, sim events.
extends SceneTree

var _failures: int = 0
var _taken: Array[StringName] = []
var _dropped: Array[StringName] = []
var _consumed: Array[StringName] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var existing: Node = _find_root_child(&"EventBus")
	if existing != null:
		root.remove_child(existing)
		existing.free()
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	event_bus.connect(&"sim_event", _on_sim_event)

	_test_carriable_contract()

	var player: CharacterBody3D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	await process_frame

	var first: Carriable = _make_carriable(&"sealant", "Sealant cartridge", Vector3(0.0, 0.0, -2.0))
	var second: Carriable = _make_carriable(&"filter_co2", "CO2 filter", Vector3(1.5, 0.0, -2.0))
	await physics_frame

	var hud: CanvasLayer = load("res://src/ui/hud.gd").new()
	root.add_child(hud)
	await process_frame
	await process_frame
	_check(String(hud.call(&"get_carry_text")) == "", "hud carry line starts hidden")

	var camera: Node = player.get_node("Head/Camera3D")
	_check(player.take_carriable(first), "take_carriable accepts a free carriable")
	_check(player.has_carried_item(), "player reports carrying")
	_check(player.get_carried() == first, "get_carried returns the taken item")
	_check(player.get_carried_item_id() == &"sealant", "carried item id matches")
	_check(first.is_carried(), "carriable reports carried")
	_check(first.get_parent() == camera, "carried item is reparented under the camera")
	_check(first.position.is_equal_approx(Vector3(0.32, -0.26, -0.55)), "carried item sits at the hold offset")
	_check(_collisions_disabled(first), "carried item collision is disabled")
	_check(_taken == [&"sealant"], "item_taken event captured with the item id")
	await process_frame
	await process_frame
	_check(String(hud.call(&"get_carry_text")).contains("SEALANT CARTRIDGE"), "hud shows the carried item name")
	_check(String(hud.call(&"get_carry_text")).contains("[RIGHT CLICK: DROP]"), "hud carry line shows the drop hint")

	_check(player.take_carriable(second), "taking a second item succeeds")
	_check(player.get_carried() == second, "the second item is now carried")
	_check(not first.is_carried(), "swap releases the first item")
	_check(first.get_parent() != camera, "swap reparents the first item home")
	_check(not _collisions_disabled(first), "swap restores the first item collision")
	_check(_dropped == [&"sealant"], "swap emits item_dropped for the first item")
	_check(_taken == [&"sealant", &"filter_co2"], "item_taken events follow the swap")

	var dropped: Node = player.drop_carried()
	_check(dropped == second, "drop_carried returns the dropped item")
	_check(not player.has_carried_item(), "carry slot is empty after drop")
	_check(not second.is_carried(), "dropped item reports not carried")
	_check(second.get_parent() != camera, "drop restores the home parent")
	_check(not _collisions_disabled(second), "drop restores collision")
	_check(_dropped == [&"sealant", &"filter_co2"], "item_dropped event captured for the dropped item")
	await process_frame
	await process_frame
	_check(String(hud.call(&"get_carry_text")) == "", "hud carry line clears after drop")

	_check(player.take_carriable(second), "dropped item can be taken again")
	_check(player.consume_carried(), "consume_carried consumes the held item")
	_check(is_instance_valid(second) and not second.enabled and not second.visible, "consumed scene prop parks disabled, not freed")
	_check(second.get_parent() != camera, "consumed item leaves the carry anchor")
	_check(not player.has_carried_item(), "carry slot is empty after consume")
	_check(_consumed == [&"filter_co2"], "item_consumed event captured with the item id")
	_check(not player.consume_carried(), "consume_carried is a no-op with an empty slot")
	_check(player.drop_carried() == null, "drop_carried with nothing carried returns null")

	await _test_drop_beside_shelf(player)
	_test_stick_look(player)
	player.free()
	first.free()
	hud.free()
	_finish()


func _test_carriable_contract() -> void:
	var item := Carriable.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	shape.shape = box
	item.add_child(shape)
	root.add_child(item)
	_check(item.get_item_id() == &"sealant", "carriable default item id")
	_check(item.get_interaction_prompt() == "Take Sealant cartridge", "free carriable prompts take")
	_check(not item.is_carried(), "carriable starts free")

	var holder := Node3D.new()
	root.add_child(holder)
	item.equip_to(holder)
	_check(item.is_carried(), "equip_to marks the item carried")
	_check(item.get_parent() == holder, "equip_to reparents under the holder")
	_check(_collisions_disabled(item), "equip_to disables collision")
	_check(item.get_interaction_prompt() == "", "carried carriable has no take prompt")

	var drop_target := Transform3D(Basis.IDENTITY, Vector3(3.0, 0.5, 0.0))
	item.unequip(drop_target)
	_check(not item.is_carried(), "unequip marks the item free")
	_check(item.get_parent() == root, "unequip restores the home parent")
	_check(item.global_transform.origin.is_equal_approx(drop_target.origin), "unequip applies the drop transform")
	_check(not _collisions_disabled(item), "unequip restores collision")
	_check(item.get_interaction_prompt() == "Take Sealant cartridge", "prompt returns after unequip")

	var state: Dictionary = item.save_state()
	_check(state.has("enabled") and String(state.get("item_id", "")) == "sealant", "save_state carries base keys and item_id")
	item.item_id = &"other"
	item.load_state(state)
	_check(item.get_item_id() == &"sealant", "load_state restores item_id")

	item.free()
	holder.free()


## A tool dropped while facing nearby shelving must stay in reach, not inside the shelf's collision.
func _test_drop_beside_shelf(player: CharacterBody3D) -> void:
	var shelf: StaticBody3D = StaticBody3D.new()
	var shelf_shape: CollisionShape3D = CollisionShape3D.new()
	var shelf_box: BoxShape3D = BoxShape3D.new()
	shelf_box.size = Vector3(0.4, 1.8, 0.98)
	shelf_shape.shape = shelf_box
	shelf.add_child(shelf_shape)
	root.add_child(shelf)
	shelf.global_position = Vector3(10.0, 0.95, 0.0)
	var tool: Carriable = _make_carriable(&"multimeter", "Multimeter", Vector3(8.0, 0.0, 0.0))
	player.global_position = Vector3(9.3, 0.0, 0.0)
	player.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	player.get_node("Head").rotation.x = -0.35
	await physics_frame
	await physics_frame
	_check(player.take_carriable(tool), "shelf drop: tool can be taken")
	player.drop_carried()
	await physics_frame
	var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	query.position = tool.global_position
	query.collision_mask = 1
	query.exclude = [tool.get_rid(), player.get_rid()]
	_check(player.get_world_3d().direct_space_state.intersect_point(query, 1).is_empty(), "shelf drop: dropped tool is not inside the shelf collision")
	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractRay") as RayCast3D
	player.get_node("Head").look_at(tool.global_position, Vector3.UP)
	ray.force_raycast_update()
	_check(ray.get_collider() == tool, "shelf drop: interaction ray reaches the tool before the shelf")
	tool.free()
	shelf.free()
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO


## The right stick turns the view the way the mouse does, and a half push turns less than half
## as fast, which is what makes small adjustments aimable on a panel row.
func _test_stick_look(player: CharacterBody3D) -> void:
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	player.set("_pitch", 0.0)
	player.call("apply_stick_look", Vector2(1.0, 0.0), 0.1)
	var full_turn: float = player.rotation.y
	_check(full_turn < 0.0, "stick look: pushing right turns the view right")
	player.rotation = Vector3.ZERO
	player.call("apply_stick_look", Vector2(0.5, 0.0), 0.1)
	_check(absf(player.rotation.y) < absf(full_turn) * 0.5, "stick look: a half push turns less than half as fast")
	player.call("apply_stick_look", Vector2(0.0, -1.0), 0.1)
	_check(float(player.get_node("Head").rotation.x) > 0.0, "stick look: pushing up raises the view")
	player.call("apply_stick_look", Vector2(0.0, 1.0), 10.0)
	_check(float(player.get_node("Head").rotation.x) >= -deg_to_rad(89.01), "stick look: pitch stays inside the limit")
	player.rotation = Vector3.ZERO
	player.get_node("Head").rotation = Vector3.ZERO
	player.set("_pitch", 0.0)


func _make_carriable(id: StringName, name: String, position: Vector3) -> Carriable:
	var item := Carriable.new()
	item.item_id = id
	item.item_name = name
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	shape.shape = box
	item.add_child(shape)
	root.add_child(item)
	item.position = position
	return item


func _collisions_disabled(item: Node) -> bool:
	for child: Node in item.get_children():
		if child is CollisionShape3D:
			return (child as CollisionShape3D).disabled
	return false


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	match event_name:
		&"item_taken":
			_taken.append(StringName(payload.get("item_id", &"")))
		&"item_dropped":
			_dropped.append(StringName(payload.get("item_id", &"")))
		&"item_consumed":
			_consumed.append(StringName(payload.get("item_id", &"")))


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_carry")
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
