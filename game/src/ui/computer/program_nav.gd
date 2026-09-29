## STAR CHART: plot a course to a listed destination and commit to its transit.
class_name NavProgram
extends ComputerProgram

var _highlighted: StringName = &""


func _init() -> void:
	title = "STAR CHART"


func get_actions(terminal: Node) -> Array[StringName]:
	var actions: Array[StringName] = []
	var nav: Node = terminal.call("system", &"nav_system")
	if nav == null:
		return actions
	var status: Dictionary = nav.call("get_status")
	if bool(status["transit_active"]):
		return actions
	if StringName(status["plotted_destination_id"]) != &"":
		actions.append(&"begin_transit")
		actions.append(&"cancel_course")
		return actions
	var current_id: StringName = status["current_destination_id"]
	for destination: VoyageDestination in nav.call("get_destinations"):
		if destination == null or not destination.is_valid() or destination.destination_id == current_id:
			continue
		actions.append(destination.destination_id)
	return actions


func get_action_label(terminal: Node, action: StringName) -> String:
	if action == &"begin_transit":
		return "BEGIN TRANSIT"
	if action == &"cancel_course":
		return "CANCEL COURSE"
	var nav: Node = terminal.call("system", &"nav_system")
	if nav != null:
		var destination: VoyageDestination = nav.call("get_destination", action)
		if destination != null:
			var visited: String = "  [VISITED]" if bool(nav.call("has_visited", destination.destination_id)) else ""
			return "%s  %d DAYS  XENON %d KG%s" % [
				destination.display_name.to_upper(),
				destination.transit_days,
				int(roundf(destination.fuel_cost_kg)),
				visited,
			]
	return String(action)


func set_highlighted_action(terminal: Node, action: StringName) -> void:
	var nav: Node = terminal.call("system", &"nav_system")
	if nav == null or nav.call("get_destination", action) == null:
		_highlighted = &""
		return
	_highlighted = action


func build_readout(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var nav: Node = terminal.call("system", &"nav_system")
	if nav == null:
		lines.append("NAVIGATION COMPUTER OFFLINE")
		return lines
	var status: Dictionary = nav.call("get_status")
	lines.append("XENON RESERVE  %d KG" % int(roundf(float(status["fuel_mass_kg"]))))
	if bool(status["transit_active"]):
		var destination: VoyageDestination = nav.call("get_destination", status["plotted_destination_id"])
		if destination != null:
			lines.append("AUTOPILOT  %s" % destination.display_name.to_upper())
			lines.append("DAY %d / %d" % [int(status["transit_day"]), destination.transit_days])
			lines.append("TRANSIT %d%%" % int(roundf(float(status["transit_progress"]) * 100.0)))
		lines.append("SHIP SYSTEMS REMAIN ON DUTY")
		return lines
	if StringName(status["plotted_destination_id"]) != &"":
		var plotted: VoyageDestination = nav.call("get_destination", status["plotted_destination_id"])
		if plotted != null:
			lines.append("COURSE LOCKED  %s" % plotted.display_name.to_upper())
			lines.append("TRANSIT  %d DAYS" % plotted.transit_days)
			lines.append("PLOT  %.0f H  XENON %d KG" % [plotted.course_plot_hours, int(roundf(plotted.course_plot_fuel_kg))])
			lines.append("TRANSIT XENON  %d KG" % int(roundf(plotted.fuel_cost_kg)))
			lines.append("DRIFT ERROR  %d%%" % int(roundf(float(status["course_error"]) * 100.0)))
			lines.append("SELECT BEGIN TRANSIT WHEN READY")
		return lines
	if StringName(status["current_destination_id"]) == &"":
		lines.append("POSITION  OUTER DRIFT CORRIDOR")
	else:
		var current: VoyageDestination = nav.call("get_destination", status["current_destination_id"])
		if current != null:
			lines.append("POSITION  %s" % current.display_name.to_upper())
		lines.append("SELECT A DESTINATION TO PLOT COURSE")
	if _highlighted != &"":
		var selected: VoyageDestination = nav.call("get_destination", _highlighted)
		if selected != null:
			lines.append("")
			lines.append("CLASS  %s" % selected.kind.to_upper())
			lines.append("TRANSIT  %d DAYS" % selected.transit_days)
			lines.append("XENON  %d KG" % int(roundf(selected.fuel_cost_kg)))
	return lines


func select_action(terminal: Node, action: StringName) -> bool:
	var nav: Node = terminal.call("system", &"nav_system")
	if nav == null:
		return false
	var changed: bool = false
	match action:
		&"begin_transit":
			changed = bool(nav.call("begin_transit"))
			if not changed:
				terminal.call("_emit_sim_event", &"procedure_error", {"reason": &"transit_unavailable"})
		&"cancel_course":
			changed = bool(nav.call("cancel_course"))
		_:
			changed = bool(nav.call("plot_course", action))
			if not changed:
				var destination: VoyageDestination = nav.call("get_destination", action)
				var reason: StringName = &"no_fuel"
				if destination == null:
					reason = &"invalid_destination"
				terminal.call("_emit_sim_event", &"procedure_error", {"reason": reason})
	return changed
