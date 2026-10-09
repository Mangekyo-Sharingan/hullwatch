## Wall-mounted watch report and onboard history, derived from the live simulators.
class_name MaintenanceBoard
extends ComputerTerminal


func _ready() -> void:
	terminal_title = "WARNING BOARD"
	programs = [&"watch", &"log"]
	default_program = &"watch"
	phosphor = CrtPanel.PHOSPHOR_GREEN
	ui_layer = 11
	super._ready()


func get_interaction_prompt() -> String:
	return "Close board" if is_open() else "Read board"


## The board's rows: newest first, straight from the ship computer.
func get_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var computer: Node = system(&"computer_system")
	if computer == null:
		return entries
	for entry: Dictionary in computer.call("get_entries"):
		entries.append(entry)
	return entries
