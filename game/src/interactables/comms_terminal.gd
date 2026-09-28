## Cockpit comms station: the ship computer's comms traffic program over the shared CRT shell.
class_name CommsTerminal
extends ComputerTerminal


func _ready() -> void:
	terminal_title = "COMMS TERMINAL"
	programs = [&"comms", &"log"]
	default_program = &"comms"
	phosphor = CrtPanel.PHOSPHOR_GREEN
	ui_layer = 12
	super._ready()


func get_interaction_prompt() -> String:
	return "Close comms" if is_open() else "Read comms"
