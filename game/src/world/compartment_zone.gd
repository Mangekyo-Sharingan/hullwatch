## Area3D that reports player presence to the atmosphere simulator as an occupant count.
## Zones drive the sim; they hold no authoritative state.
class_name CompartmentZone
extends Area3D

@export var compartment_id: StringName = &"main"


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


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


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		_set_occupants(get_occupants())


func _set_occupants(count: int) -> void:
	var atmosphere: Node = get_tree().get_first_node_in_group(&"atmosphere_system")
	if atmosphere != null:
		atmosphere.call("set_occupants", compartment_id, count)
