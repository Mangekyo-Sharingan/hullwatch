## Carryable prop: an interactable the player can take, hold, drop, or have consumed by a procedure.
## Carried state is presentation-only; the authoritative sim never reads it.
class_name Carriable
extends Interactable

@export var item_id: StringName = &"sealant"
@export var item_name: String = "Sealant cartridge"

var _carried: bool = false
var _home_parent: Node = null
var _home_transform: Transform3D = Transform3D.IDENTITY


func get_item_id() -> StringName:
	return item_id


func get_item_name() -> String:
	return item_name


func is_carried() -> bool:
	return _carried


func equip_to(holder: Node3D) -> void:
	if _carried or holder == null:
		return
	_home_parent = get_parent()
	_home_transform = transform
	_carried = true
	_set_collisions_disabled(true)
	_reparent_to(holder)


func unequip(drop_transform: Transform3D) -> void:
	if not _carried:
		return
	_carried = false
	var home: Node = _home_parent
	_home_parent = null
	_reparent_to(home)
	global_transform = drop_transform if drop_transform.is_finite() else _home_transform
	_set_collisions_disabled(false)


func get_interaction_prompt() -> String:
	if _carried:
		return ""
	return "Take %s" % item_name


func _handle_interact(player: Node) -> void:
	if _carried or player == null:
		return
	if player.has_method(&"take_carriable"):
		player.call(&"take_carriable", self)


# why: carrying is transient player state — a load starts the player empty-handed and the item is
# restored to its saved home transform. Persisting the carried flag could duplicate an item or
# strand one under a camera that no longer exists, so only the identity is stored.
func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["item_id"] = String(item_id)
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)
	if state.has("item_id"):
		item_id = StringName(state["item_id"])


func _set_collisions_disabled(disabled: bool) -> void:
	for shape: CollisionShape3D in _find_collision_shapes():
		shape.disabled = disabled


func _find_collision_shapes() -> Array[CollisionShape3D]:
	var shapes: Array[CollisionShape3D] = []
	for child: Node in find_children("*", "CollisionShape3D", true, false):
		shapes.append(child as CollisionShape3D)
	return shapes


func _reparent_to(new_parent: Node) -> void:
	if new_parent == null or not is_instance_valid(new_parent):
		return
	if get_parent() == new_parent:
		return
	if is_inside_tree() and new_parent.is_inside_tree():
		reparent(new_parent, false)
		return
	var current: Node = get_parent()
	if current != null:
		current.remove_child(self)
	new_parent.add_child(self)
