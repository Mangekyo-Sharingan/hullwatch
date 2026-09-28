## Archive terminal: a ship computer station that opens on its own archived volume.
class_name LogTerminal
extends ComputerTerminal

@export var log_entry: LogEntry


func _ready() -> void:
	terminal_title = "ARCHIVE TERMINAL"
	programs = [&"log"]
	default_program = &"log"
	phosphor = CrtPanel.PHOSPHOR_GREEN
	ui_layer = 13
	super._ready()


func get_interaction_prompt() -> String:
	return "Close log" if is_open() else "Read log"


func get_archive_hint() -> LogEntry:
	return log_entry
