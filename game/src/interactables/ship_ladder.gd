## Generated ladder access between a section deck and its mezzanine.
class_name ShipLadder
extends Interactable

@export var deck_height: float = 2.2


func _handle_interact(player: Node) -> void:
	if player != null and player.has_method(&"begin_ladder_climb"):
		player.call(&"begin_ladder_climb", self)


func get_upper_exit_position() -> Vector3:
	return global_position + Vector3(0.0, deck_height, 0.55)
