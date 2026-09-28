## One page of the ship computer terminal: a title, a readout, and a context action list.
## Programs hold page-local view state only; authoritative state lives in the simulators.
class_name ComputerProgram
extends RefCounted

var title: String = "PROGRAM"


func get_actions(_terminal: Node) -> Array[StringName]:
	return []


func get_action_label(_terminal: Node, action: StringName) -> String:
	return String(action).to_upper().replace("_", " ")


## Short suffix shown next to the program row, e.g. the unread count.
func get_badge(_terminal: Node) -> String:
	return ""


## The shell reports which action row the player is highlighting so the page can preview it.
func set_highlighted_action(_terminal: Node, _action: StringName) -> void:
	pass


func on_opened(_terminal: Node) -> void:
	pass


func build_readout(_terminal: Node) -> PackedStringArray:
	return []


func select_action(_terminal: Node, _action: StringName) -> bool:
	return false
