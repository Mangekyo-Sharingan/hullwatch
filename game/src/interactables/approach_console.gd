## Cockpit contact board station: the SENSOR CONTACTS page of the ship computer.
class_name ApproachConsole
extends ComputerTerminal


func _ready() -> void:
	terminal_title = "CONTACT BOARD"
	programs = [&"approach", &"survey", &"nav", &"log"]
	default_program = &"approach"
	phosphor = CrtPanel.PHOSPHOR_GREEN
	ui_layer = 12
	super._ready()


func get_interaction_prompt() -> String:
	return "Close board" if is_open() else "Sensor contacts"
