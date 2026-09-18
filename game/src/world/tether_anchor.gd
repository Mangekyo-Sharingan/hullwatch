## Anchor point for the EVA tether. The operator clips to the nearest anchor and stays
## inside its length; past that the line pulls taut and clamps the drift.
class_name TetherAnchor
extends Node3D

@export var max_length: float = 14.0


func _enter_tree() -> void:
	add_to_group(&"tether_anchor")
