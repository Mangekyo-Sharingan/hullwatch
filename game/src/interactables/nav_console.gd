## Cockpit star chart station: the NAV page of the ship computer.
class_name NavConsole
extends ComputerTerminal


func _ready() -> void:
	terminal_title = "NAV CONSOLE"
	programs = [&"nav", &"approach", &"status", &"control", &"log"]
	default_program = &"nav"
	phosphor = CrtPanel.PHOSPHOR_GREEN
	ui_layer = 12
	super._ready()


func get_interaction_prompt() -> String:
	if is_open():
		return "Close star chart"
	var nav: Node = system(&"nav_system")
	if nav == null:
		return "Open star chart"
	var status: Dictionary = nav.call("get_status")
	if bool(status["transit_active"]):
		return "Review transit"
	if StringName(status["plotted_destination_id"]) != &"":
		return "Confirm course"
	return "Open star chart"
