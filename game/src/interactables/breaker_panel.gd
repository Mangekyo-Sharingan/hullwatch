## Wall breaker panel: toggles one power circuit's breaker.
class_name BreakerPanel
extends Interactable

@export var circuit_id: StringName = &"lighting"


func _handle_interact(_player: Node) -> void:
	var power: Node = _get_system(&"power_system")
	if power == null:
		return
	var new_state: bool = not bool(power.call("is_breaker_on", circuit_id))
	power.call("set_breaker", circuit_id, new_state)
