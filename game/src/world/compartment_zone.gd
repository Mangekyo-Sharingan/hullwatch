## Area3D that reports player presence to the atmosphere simulator as an occupant count.
## Zones drive the sim; they hold no authoritative state.
class_name CompartmentZone
extends Area3D

@export var compartment_id: StringName = &"main"


func _ready() -> void:
	add_to_group(&"compartment_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Scene zones replace scenario defaults, including rooms the operator never enters.
	push_occupancy()


func get_occupants() -> int:
	var count: int = 0
	for body: Node3D in get_overlapping_bodies():
		if body.is_in_group(&"player"):
			count += 1
	return count


func push_occupancy() -> void:
	_set_occupants(get_occupants())


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_set_occupants(get_occupants())
		_emit_sim_event(&"compartment_entered", {"compartment_id": compartment_id})


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_set_occupants(get_occupants())


func _set_occupants(count: int) -> void:
	if not is_inside_tree():
		return
	var atmosphere: Node = get_tree().get_first_node_in_group(&"atmosphere_system")
	# Teardown can remove the simulator compartment before physics delivers body_exited.
	if atmosphere != null and bool(atmosphere.call(&"has_compartment", compartment_id)):
		atmosphere.call("set_occupants", compartment_id, count)


func _emit_sim_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event_bus: Node = get_node_or_null(^"/root/EventBus")
	if event_bus != null:
		event_bus.call("emit_event", event_name, payload)
