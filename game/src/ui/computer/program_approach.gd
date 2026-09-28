## SENSOR CONTACTS: list nearby field objects and command a close approach or resume drift.
## The maneuver belongs to SectorSystem, the fuel to NavSystem.
class_name ApproachProgram
extends ComputerProgram

const MAX_ROWS: int = 5


func _init() -> void:
	title = "SENSOR CONTACTS"


func get_actions(terminal: Node) -> Array[StringName]:
	var actions: Array[StringName] = []
	var sector: Node = terminal.call("system", &"sector_system")
	if sector == null:
		return actions
	var contacts: Array = sector.call("get_contacts")
	for i: int in mini(contacts.size(), MAX_ROWS):
		var contact: Dictionary = contacts[i]
		actions.append(StringName(String(contact.get("id", ""))))
	if bool(sector.call("is_holding")):
		actions.append(&"resume")
	return actions


func get_action_label(terminal: Node, action: StringName) -> String:
	if action == &"resume":
		return "RESUME DRIFT"
	var contact: Dictionary = _find_contact(terminal, action)
	if contact.is_empty():
		return String(action)
	return "APPROACH %s  %s  %d M" % [
		String(contact.get("kind", "")).to_upper(),
		String(contact.get("id", "")),
		int(roundf(float(contact.get("distance_m", 0.0)))),
	]


func build_readout(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var sector: Node = terminal.call("system", &"sector_system")
	if sector == null:
		lines.append("SENSOR BOARD OFFLINE")
		return lines
	var nav: Node = terminal.call("system", &"nav_system")
	if nav != null:
		lines.append("FUEL %d KG" % int(roundf(float(nav.call("get_status")["fuel_mass_kg"]))))
	if bool(sector.call("is_holding")):
		lines.append("HOLDING NEAR %s" % String(sector.call("get_approach_target_id")))
	else:
		lines.append("DRIFTING")
	var contacts: Array = sector.call("get_contacts")
	if contacts.is_empty():
		lines.append("NO CONTACTS IN RANGE")
	else:
		for i: int in mini(contacts.size(), MAX_ROWS):
			var contact: Dictionary = contacts[i]
			lines.append("%s  %s  %d M" % [
				String(contact.get("kind", "")).to_upper(),
				String(contact.get("id", "")),
				int(roundf(float(contact.get("distance_m", 0.0)))),
			])
	return lines


func select_action(terminal: Node, action: StringName) -> bool:
	var sector: Node = terminal.call("system", &"sector_system")
	if sector == null:
		return false
	if action == &"resume":
		sector.call("resume_drift")
		return true
	if _find_contact(terminal, action).is_empty():
		return false
	var nav: Node = terminal.call("system", &"nav_system")
	if nav == null:
		return false
	var cost: float = float(nav.get(&"approach_fuel_cost_kg"))
	if not bool(nav.call("spend_fuel", cost)):
		terminal.call("_emit_sim_event", &"procedure_error", {"reason": &"no_fuel"})
		return false
	return bool(sector.call("begin_approach", String(action)))


func _find_contact(terminal: Node, action: StringName) -> Dictionary:
	var sector: Node = terminal.call("system", &"sector_system")
	if sector == null:
		return {}
	var contacts: Array = sector.call("get_contacts")
	for entry: Dictionary in contacts:
		if String(entry.get("id", "")) == String(action):
			return entry
	return {}
