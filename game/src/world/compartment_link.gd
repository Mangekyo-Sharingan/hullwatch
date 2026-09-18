## Connects two atmosphere compartments for gas mixing. Skips silently when either side is absent.
class_name CompartmentLink
extends Node

@export var compartment_a: StringName = &""
@export var compartment_b: StringName = &""


func _ready() -> void:
	if compartment_a == &"" or compartment_b == &"" or compartment_a == compartment_b:
		return
	var atmosphere: Node = _get_atmosphere()
	if atmosphere == null or not atmosphere.has_method(&"has_compartment") or not atmosphere.has_method(&"connect_compartments"):
		return
	if not bool(atmosphere.call(&"has_compartment", compartment_a)):
		return
	if not bool(atmosphere.call(&"has_compartment", compartment_b)):
		return
	atmosphere.call(&"connect_compartments", compartment_a, compartment_b)


func _get_atmosphere() -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"atmosphere_system")
