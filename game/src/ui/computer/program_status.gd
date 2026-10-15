## STATUS REPORT: the wall panel's readout, assembled from the live simulators.
## Holds no state; every line comes from a system, the clock, or the station's compartment export.
class_name StatusProgram
extends ComputerProgram


func _init() -> void:
	title = "STATUS REPORT"


func build_readout(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var sim_clock: Node = terminal.call("_get_autoload", &"SimClock") as Node
	if sim_clock != null:
		lines.append("DAY %d  %02d:00" % [int(sim_clock.call("get_day")), int(sim_clock.call("get_hour"))])
	else:
		lines.append("CLOCK OFFLINE")
	lines.append("")
	lines.append_array(_power_lines(terminal))
	lines.append("")
	lines.append_array(_atmosphere_lines(terminal))
	var water: PackedStringArray = _water_lines(terminal)
	if not water.is_empty():
		lines.append("")
		lines.append_array(water)
	var thermal: PackedStringArray = _thermal_lines(terminal)
	if not thermal.is_empty():
		lines.append("")
		lines.append_array(thermal)
	var hull: PackedStringArray = _hull_lines(terminal)
	if not hull.is_empty():
		lines.append("")
		lines.append_array(hull)
	var components: PackedStringArray = _components_lines(terminal)
	if not components.is_empty():
		lines.append("")
		lines.append_array(components)
	var nav: PackedStringArray = _nav_lines(terminal)
	if not nav.is_empty():
		lines.append("")
		lines.append_array(nav)
	lines.append("")
	lines.append_array(_stores_lines(terminal))
	var cargo: PackedStringArray = _cargo_lines(terminal)
	if not cargo.is_empty():
		lines.append("")
		lines.append_array(cargo)
	var capabilities: PackedStringArray = _capability_lines(terminal)
	if not capabilities.is_empty():
		lines.append("")
		lines.append_array(capabilities)
	lines.append("")
	lines.append("E/ESC: CLOSE")
	return lines


func _capability_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var modules: Node = terminal.call("system", &"module_system") as Node
	if modules == null:
		return lines
	var effects: Dictionary = modules.call("get_effects")
	lines.append("SHIP CAPABILITIES")
	var sector: Node = terminal.call("system", &"sector_system") as Node
	if sector != null:
		lines.append("  CONTACT RANGE %.0f M" % float(sector.call("get_detection_range")))
	lines.append("  FITTED LOAD %.0f W ACTIVE / %.0f W INSTALLED" % [float(effects["active_load_w"]), float(effects["fitted_load_w"])])
	var power: Node = terminal.call("system", &"power_system") as Node
	if power != null:
		lines.append("  BATTERY %.0f / %.0f WH" % [float(power.get("battery_charge_wh")), float(power.call("get_battery_capacity_wh"))])
	var fabricator: Node = terminal.call("system", &"fabricator_system") as Node
	if fabricator != null:
		lines.append("  BENCH %.0f%% JOB TIME (WHEN POWERED)" % (100.0 * float(fabricator.get("job_hours_multiplier"))))
	lines.append("  GROWTH %.1f / %.1f RATIONS/DAY" % [float(effects["active_rations_per_day"]), float(effects["rations_per_day"])])
	lines.append("  SURVEY: SENSOR + CARGO RACK + BATTERY")
	lines.append("  SALVAGE: WORK BENCH + TWO CARGO RACKS")
	lines.append("  ENDURANCE: GROW RACK + TWO BATTERIES")
	return lines


func _cargo_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var cargo: Node = terminal.call("system", &"cargo_system") as Node
	if cargo == null or not cargo.has_method(&"get_status"):
		return lines
	var status: Dictionary = cargo.call("get_status")
	lines.append("CARGO  %d/%d UNITS" % [
		int(roundf(float(status["used_units"]))),
		int(roundf(float(status["capacity_units"]))),
	])
	var materials: Dictionary = status["materials"]
	var reservations: Dictionary = status.get("reserved_units", {})
	if float(reservations.get(&"salvage", 0.0)) > 0.0:
		lines.append("  RECOVERED EQUIPMENT %.0f UNITS" % float(reservations[&"salvage"]))
	if materials.is_empty() and reservations.is_empty():
		lines.append("  EMPTY")
	else:
		var kinds: Array = materials.keys()
		kinds.sort()
		for kind: Variant in kinds:
			lines.append("  %s %d" % [String(kind).to_upper(), int(roundf(float(materials[kind])))])
	return lines


func _water_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var water: Node = terminal.call("system", &"water_system") as Node
	if water == null:
		return lines
	var status: Dictionary = water.call("get_status")
	lines.append("WATER  POTABLE %d/%d L  GREYWATER %d L" % [
		int(roundf(float(status["potable_l"]))),
		int(roundf(float(status["potable_capacity_l"]))),
		int(roundf(float(status["greywater_l"]))),
	])
	var reclaimer: String = "OFF"
	if bool(status["reclaimer_active"]):
		reclaimer = "ACTIVE"
	elif bool(status["reclaimer_powered"]):
		reclaimer = "ON"
	lines.append("  RECLAIMER %s  CONTAM %d%%  EFF %d%%" % [
		reclaimer,
		int(roundf(float(status["contamination"]) * 100.0)),
		int(roundf(float(status["efficiency"]) * 100.0)),
	])
	return lines


func _thermal_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var thermal: Node = terminal.call("system", &"thermal_system") as Node
	if thermal == null:
		lines.append("THERMAL -- OFFLINE")
		return lines
	var compartment_id: StringName = StringName(terminal.call("get_status_compartment_id"))
	if not bool(thermal.call("has_compartment", compartment_id)):
		lines.append("THERMAL -- NO %s COMPARTMENT" % String(compartment_id).to_upper())
		return lines
	var status: Dictionary = thermal.call("get_compartment_status", compartment_id)
	var heater_state: String = "OFF"
	if bool(status["heater_powered"]):
		heater_state = "HEATING" if bool(status["heater_active"]) else "STANDBY"
	lines.append("THERMAL  %s %+.1f C  HEATER %s" % [
		String(compartment_id).to_upper(),
		float(status["temperature_c"]),
		heater_state,
	])
	if bool(status["freeze_risk"]):
		lines.append("  FREEZE RISK")
	return lines


func _hull_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var hull: Node = terminal.call("system", &"hull_system") as Node
	if hull == null:
		lines.append("HULL -- OFFLINE")
		return lines
	var compartment_id: StringName = StringName(terminal.call("get_status_compartment_id"))
	var status: Dictionary = hull.call("get_status")
	var compartments: Dictionary = status["compartments"]
	if not compartments.has(compartment_id):
		lines.append("HULL -- NO %s COMPARTMENT" % String(compartment_id).to_upper())
		return lines
	var compartment: Dictionary = compartments[compartment_id]
	lines.append("HULL  %s  PUNCTURES %d  LEAK %.3f/H" % [
		String(compartment_id).to_upper(),
		int(compartment["puncture_count"]),
		float(compartment["total_leak_rate_per_hour"]),
	])
	return lines


func _nav_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var nav: Node = terminal.call("system", &"nav_system") as Node
	if nav != null:
		var status: Dictionary = nav.call("get_status")
		if bool(status["transit_active"]):
			var destination: VoyageDestination = nav.call("get_destination", status["plotted_destination_id"])
			var destination_name: String = String(status["plotted_destination_id"]).to_upper()
			if destination != null:
				destination_name = destination.display_name.to_upper()
			lines.append("NAV  IN TRANSIT TO %s" % destination_name)
			lines.append("  XENON %d KG  %d%% COMPLETE" % [int(roundf(float(status["fuel_mass_kg"]))), int(roundf(float(status["transit_progress"]) * 100.0))])
		elif StringName(status["plotted_destination_id"]) != &"":
			var destination: VoyageDestination = nav.call("get_destination", status["plotted_destination_id"])
			var destination_name: String = String(status["plotted_destination_id"]).to_upper()
			var travel_days: int = 0
			if destination != null:
				destination_name = destination.display_name.to_upper()
				travel_days = destination.transit_days
			lines.append("NAV  COURSE SET TO %s  NOMINAL %d DAYS (PAIR)" % [destination_name, travel_days])
			lines.append("  ION DRIVE STANDBY  XENON %d KG  DRIFT %d%%" % [
				int(roundf(float(status["fuel_mass_kg"]))),
				int(roundf(float(status["course_error"]) * 100.0)),
			])
		else:
			var current_id: StringName = status["current_destination_id"]
			var position: String = "OUTER DRIFT CORRIDOR"
			if current_id != &"":
				var current: VoyageDestination = nav.call("get_destination", current_id)
				if current != null:
					position = current.display_name.to_upper()
			lines.append("NAV  POSITION %s" % position)
			lines.append("  ION DRIVE IDLE  XENON %d KG  DRIFT %d%%" % [
				int(roundf(float(status["fuel_mass_kg"]))),
				int(roundf(float(status["course_error"]) * 100.0)),
			])
		lines.append_array(NavProgram.drive_readout(status))
	var sector: Node = terminal.call("system", &"sector_system") as Node
	if sector != null and sector.has_method(&"get_contacts"):
		var contacts: Array = sector.call("get_contacts")
		if contacts.is_empty():
			lines.append("  CONTACTS NONE IN RANGE")
		else:
			lines.append("  CONTACTS %d  NEAREST %d M" % [
				contacts.size(),
				int(roundf(float((contacts[0] as Dictionary).get("distance_m", 0.0)))),
			])
			for i: int in mini(contacts.size(), 3):
				var contact: Dictionary = contacts[i]
				lines.append("    %s  %s  %d M" % [
					String(contact.get("kind", "")).to_upper(),
					String(contact.get("id", "")),
					int(roundf(float(contact.get("distance_m", 0.0)))),
				])
	return lines


func _components_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var entries: PackedStringArray = PackedStringArray()
	for group_name: StringName in [&"power_system", &"atmosphere_system", &"thermal_system", &"hull_system", &"water_system", &"nav_system"]:
		var system: Node = terminal.call("system", group_name) as Node
		if system == null or not system.has_method(&"get_wear_status"):
			continue
		var wear: Dictionary = system.call("get_wear_status")
		var component_ids: Array = wear.keys()
		component_ids.sort()
		for key: Variant in component_ids:
			var component_id: StringName = key
			var status: Dictionary = wear[component_id]
			if group_name == &"nav_system" and not bool(status.get("scanned", false)) and not bool(status.get("diagnosed", false)):
				continue
			var state: String = _component_state_text(status)
			if group_name == &"nav_system" and not bool(status.get("diagnosed", false)):
				state = "DIAGNOSIS REQUIRED"
			entries.append("%-16s %s %s" % [
				String(component_id).to_upper(),
				_condition_text(status),
				state,
			])
	if not entries.is_empty():
		lines.append("COMPONENTS")
		for entry: String in entries:
			lines.append("  " + entry)
		lines.append("  (scanner logs wear, multimeter faults)")
	return lines


func _condition_text(status: Dictionary) -> String:
	if not bool(status.get("scanned", false)):
		return "  --"
	return "%3d%%" % int(roundf(float(status["condition"]) * 100.0))


func _component_state_text(status: Dictionary) -> String:
	if not bool(status["failed"]):
		return "OK"
	if not bool(status.get("diagnosed", false)):
		return "FAULT (UNDIAGNOSED)"
	return "FAIL %s" % String(status["failed_mode"]).to_upper()


func _power_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var power: Node = terminal.call("system", &"power_system") as Node
	if power == null:
		lines.append("POWER -- OFFLINE")
		return lines
	var status: Dictionary = power.call("get_status")
	var battery_pct: int = int(roundf(float(status["battery_fraction"]) * 100.0))
	var bus_state: String = "BROWNOUT" if bool(status["brownout"]) else "OK"
	lines.append("POWER  BATTERY %d%%  BUS %s" % [battery_pct, bus_state])
	var circuits: Dictionary = status["circuits"]
	var circuit_ids: Array = circuits.keys()
	circuit_ids.sort()
	for key: Variant in circuit_ids:
		var circuit_id: StringName = key
		var circuit: Dictionary = circuits[circuit_id]
		var state: String = "ON"
		if not bool(circuit["breaker_on"]):
			state = "OFF"
		elif bool(circuit["shed"]):
			state = "SHED"
		var label: String = "DRIVE FEED UV" if circuit_id == &"xenonite_uv" else String(circuit_id).to_upper()
		lines.append("  %-11s %s" % [label, state])
	return lines


func _atmosphere_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var compartment_id: StringName = StringName(terminal.call("get_status_compartment_id"))
	var atmosphere: Node = terminal.call("system", &"atmosphere_system") as Node
	if atmosphere == null or not bool(atmosphere.call("has_compartment", compartment_id)):
		lines.append("ATMOSPHERE -- OFFLINE")
		return lines
	var status: Dictionary = atmosphere.call("get_compartment_status", compartment_id)
	lines.append("ATMOSPHERE  %s" % String(compartment_id).to_upper())
	lines.append("  O2 %5.1f%%   CO2 %6.0f PPM" % [float(status["o2_fraction"]) * 100.0, float(status["co2_ppm"])])
	lines.append("  PRESSURE %6.1f KPA  LEAK %.3f/H" % [float(status["pressure_kpa"]), float(status["leak_rate_per_hour"])])
	var scrubber: String = "ON" if bool(status["scrubber_powered"]) else "OFF"
	var filter_text: String = "MISSING"
	if bool(status["filter_installed"]):
		filter_text = "%d%%" % int(roundf(float(status["filter_condition"]) * 100.0))
	lines.append("  SCRUBBER %s  FILTER %s" % [scrubber, filter_text])
	return lines


func _stores_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var stores: Node = terminal.call("system", &"stores_system") as Node
	if stores == null:
		lines.append("STORES -- OFFLINE")
		return lines
	var status: Dictionary = stores.call("get_status")
	var parts: Dictionary = status["parts"]
	var part_ids: Array = parts.keys()
	part_ids.sort()
	var entries: PackedStringArray = PackedStringArray()
	for key: Variant in part_ids:
		var part_id: StringName = key
		entries.append("%s x%d" % [String(part_id).to_upper(), int(parts[part_id])])
	lines.append("STORES  " + "  ".join(entries))
	return lines
