## Wall-mounted verification panel: a ship computer station on its own status report.
## The readout itself lives in the STATUS REPORT program; the panel supplies the compartment.
class_name StatusPanel
extends ComputerTerminal

@export var compartment_id: StringName = &"main"


func _ready() -> void:
	terminal_title = "STATUS PANEL"
	programs = [&"status", &"log"]
	default_program = &"status"
	phosphor = CrtPanel.PHOSPHOR_AMBER
	ui_layer = 10
	base_font_size = 18
	super._ready()


func get_interaction_prompt() -> String:
	return "Close panel" if is_open() else "Read panel"


func get_status_compartment_id() -> StringName:
	return compartment_id


func _on_terminal_opened() -> void:
	_emit_sim_event(&"status_panel_opened", {"compartment_id": compartment_id})
