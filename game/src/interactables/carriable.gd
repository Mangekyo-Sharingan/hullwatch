## Carryable prop: an interactable the player can take, hold, drop, or have consumed by a procedure.
## Carried state is presentation-only; the authoritative sim never reads it.
class_name Carriable
extends Interactable

## Usage moments: the sim event that means the item in hand just did its job, and the item ids
## whose authored "use" animation it should play. Items with no entry never animate.
const USE_EVENTS: Dictionary = {
	&"salvage_released": [&"wrench"],
	&"salvage_diagnosed": [&"multimeter"],
	&"salvage_repaired": [&"wrench"],
	&"probe_diagnosis": [&"multimeter"],
	&"diagnosis_clear": [&"multimeter"],
	&"probe_scanned": [&"scanner"],
	&"scanner_ping": [&"scanner"],
	&"anomaly_logged": [&"scanner"],
	&"canister_loaded": [&"sample_canister"],
	&"sample_taken": [&"sample_canister", &"cutter"],
	&"sample_stowed": [&"sample_canister"],
	&"hull_sealant_applied": [&"sealant"],
	&"scrubber_housing_opened": [&"wrench"],
	&"scrubber_housing_closed": [&"wrench"],
}

@export var item_id: StringName = &"sealant"
@export var item_name: String = "Sealant cartridge"

var _carried: bool = false
var _home_parent: Node = null
var _home_transform: Transform3D = Transform3D.IDENTITY


func _ready() -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)


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
	align_model_for_hand()


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


## The authored kit ships each tool's whole use cycle as one "use_*" animation (the export
## merges the moving parts' tracks); the item plays it, once, when the sim says the tool did
## its job.
func play_use_animation() -> void:
	var animator: AnimationPlayer = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null:
		return
	for animation_name: StringName in animator.get_animation_list():
		if not String(animation_name).begins_with("use"):
			continue
		var animation: Animation = animator.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_NONE
		animator.play(animation_name)
		animator.seek(0.0, true)


## World placement yaws the model nose-to-wall; the hand wants the authored orientation, so the
## model turns back to its own axes while the item is held.
func align_model_for_hand() -> void:
	var model: Node3D = get_node_or_null(^"Model") as Node3D
	if model != null:
		model.rotation = Vector3.ZERO


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if not _carried:
		return
	var items: Variant = USE_EVENTS.get(event_name)
	if items is Array and (items as Array).has(item_id):
		play_use_animation()


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
