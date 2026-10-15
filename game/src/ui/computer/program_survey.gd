extends ComputerProgram

const APPROACH_PREFIX: String = "approach_record:"

var _selected: String = ""
var _highlighted: String = ""


func _init() -> void:
	title = "SURVEY NOTEBOOK"


func get_actions(terminal: Node) -> Array[StringName]:
	var actions: Array[StringName] = []
	for record: Dictionary in _records(terminal):
		actions.append(StringName(record["record_id"]))
	var record: Dictionary = _shown_record(terminal)
	if not _live_contact(terminal, record).is_empty():
		actions.append(StringName(APPROACH_PREFIX + String(record["record_id"])))
	return actions


func get_action_label(terminal: Node, action: StringName) -> String:
	if String(action).begins_with(APPROACH_PREFIX):
		return "APPROACH RECORDED CONTACT"
	for record: Dictionary in _records(terminal):
		if String(record["record_id"]) == String(action):
			return "%s %s  %s" % ["CURRENT" if _current_field(terminal, record) else "ARCHIVED", String(record["kind"]).to_upper(), String(record["object_id"])]
	return String(action)


func set_highlighted_action(_terminal: Node, action: StringName) -> void:
	_highlighted = String(action).trim_prefix(APPROACH_PREFIX)


func build_readout(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = []
	var record: Dictionary = _shown_record(terminal)
	if record.is_empty():
		lines.append("NO RECORDED OBSERVATIONS")
		lines.append("Carry the field scanner and ping a contact.")
		lines.append("A contact reading cannot identify its material.")
		return lines
	lines.append("%s FIELD %s" % ["CURRENT" if _current_field(terminal, record) else "ARCHIVED", String(record["field_seed"])])
	lines.append("%s  %s" % [String(record["kind"]).to_upper(), String(record["object_id"])])
	lines.append("LAST OBSERVATION %.2f SHIP HOURS" % float(record["observed_hours"]))
	lines.append("EVIDENCE: %s" % String(record["confidence"]).to_upper())
	if String(record["resource"]) == "":
		lines.append("COMPOSITION UNCONFIRMED; SAMPLE REQUIRED")
		lines.append("REMAINING SUPPLY UNKNOWN")
	else:
		lines.append("SAMPLE CONFIRMED: %s  %.1f UNITS COLLECTED" % [String(record["resource"]).to_upper(), float(record["sampled_units"])])
		lines.append("LAST MEASURED REMAINDER %.1f UNITS (MAY HAVE CHANGED)" % float(record["observed_remaining_units"]))
	if String(record["equipment_id"]) != "":
		lines.append("DIAGNOSED EQUIPMENT %s  %.0f%% AT INSPECTION" % [String(record["equipment_id"]).to_upper(), float(record["equipment_condition"]) * 100.0])
	else:
		lines.append("RECOVERABLE EQUIPMENT UNCONFIRMED")
	var contact: Dictionary = _live_contact(terminal, record)
	if contact.is_empty():
		lines.append("NO CURRENT RANGE READING; FIND THIS FIELD AGAIN")
	else:
		lines.append("CURRENT RANGE %.0f M" % float(contact["distance_m"]))
		var nav: Node = terminal.call("system", &"nav_system") as Node
		if nav != null:
			lines.append("APPROACH %.0f KG XENON / TOTAL STOCK %.0f KG" % [float(nav.get("approach_fuel_cost_kg")), float(nav.get("fuel_mass_kg"))])
		var cargo: Node = terminal.call("system", &"cargo_system") as Node
		if cargo != null:
			lines.append("HOLD ROOM %.1f UNITS" % float(cargo.call("get_free_units")))
		var airlock: Node = terminal.call("system", &"airlock_system") as Node
		if airlock != null:
			lines.append("SUIT O2 %.2f H; ALLOW TIME TO RETURN" % float(airlock.get("suit_o2_hours")))
	lines.append("Collect a sample to confirm composition.")
	return lines


func select_action(terminal: Node, action: StringName) -> bool:
	var record_id: String = String(action).trim_prefix(APPROACH_PREFIX)
	for record: Dictionary in _records(terminal):
		if String(record["record_id"]) != record_id:
			continue
		_selected = record_id
		_highlighted = ""
		if String(action).begins_with(APPROACH_PREFIX):
			if _live_contact(terminal, record).is_empty():
				return false
			return ApproachProgram.new().select_action(terminal, StringName(record["object_id"]))
		return true
	return false


func _records(terminal: Node) -> Array:
	var sector: Node = terminal.call("system", &"sector_system") as Node
	return sector.call("get_survey_records") as Array if sector != null else []


func _shown_record(terminal: Node) -> Dictionary:
	var records: Array = _records(terminal)
	var selected: String = _highlighted if _highlighted != "" else _selected
	for record: Dictionary in records:
		if String(record["record_id"]) == selected:
			return record
	return records[0] as Dictionary if not records.is_empty() else {}


func _current_field(terminal: Node, record: Dictionary) -> bool:
	var sector: Node = terminal.call("system", &"sector_system") as Node
	return sector != null and String(record.get("field_seed", "")) == str(int(sector.get("field_seed")))


func _live_contact(terminal: Node, record: Dictionary) -> Dictionary:
	if record.is_empty() or not _current_field(terminal, record):
		return {}
	var sector: Node = terminal.call("system", &"sector_system") as Node
	for contact: Dictionary in sector.call("get_contacts"):
		if String(contact["id"]) == String(record["object_id"]):
			return contact
	return {}
