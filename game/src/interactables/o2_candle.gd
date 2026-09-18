## Emergency O2 candle rack: lights one candle, slowly releasing oxygen into the compartment.
class_name O2Candle
extends Interactable

@export var compartment_id: StringName = &"main"


func get_interaction_prompt() -> String:
	return "Light O2 candle (%d left)" % _candles_remaining()


func _handle_interact(_player: Node) -> void:
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere == null:
		return
	if not bool(atmosphere.call("light_o2_candle", compartment_id)):
		_emit_sim_event(&"procedure_error", {"reason": &"no_candles", "compartment_id": compartment_id})


func _candles_remaining() -> int:
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere == null or not bool(atmosphere.call("has_compartment", compartment_id)):
		return 0
	var status: Dictionary = atmosphere.call("get_compartment_status", compartment_id)
	return int(status["candles_remaining"])
