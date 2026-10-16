extends StatusProgram

const SERVICE_GUIDES: Dictionary = {
	&"power_system": "BREAKER CABINET / POWER TEST POINT; MANUAL: POWER",
	&"atmosphere_system": "SCRUBBER / AIR TEST POINT; MANUAL: LIFE SUPPORT",
	&"thermal_system": "THERMAL TEST POINT; MANUAL: THERMAL",
	&"hull_system": "HULL PATCH / HULL TEST POINT; MANUAL: DAMAGE CONTROL",
	&"water_system": "WATER RECLAIMER / WATER TEST POINT; MANUAL: DIAGNOSTICS",
	&"nav_system": "STERN EVA SERVICE PANELS; MANUAL: PROPULSION",
}


func _init() -> void:
	title = "WATCH REPORT"


func build_readout(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray([
		"STANDING ORDERS / CONATUS FINITUS",
		"CHECK STATUS; TAKE SCANNER + MULTIMETER FROM TOOL RACKS.",
		"GALLEY MANUAL: DIAGNOSE / ISOLATE / SERVICE / VERIFY.",
		"TRIAGE, THEN QUARTERS BUNK TO END WATCH. SHIP RUNS DURING SLEEP.",
		"SHIP LOG > OPERATOR HANDOVER: FULL INSTRUCTIONS.",
		"",
		"CURRENT CONCERNS",
	])
	lines.append_array(_safety_lines(terminal))
	lines.append("")
	lines.append("INSPECTION / SERVICE")
	lines.append_array(_inspection_lines(terminal))
	lines.append("TOOLS: SCANNER WEAR / MULTIMETER FAULTS / WRENCH REFIT")
	for line: String in _nav_lines(terminal):
		if line.begins_with("NAV ") or line.begins_with("DRIVE HOLD") or line.begins_with("ETA ") or line.begins_with("DRIVE FEED "):
			lines.append(line)
	lines.append("")
	lines.append("RESERVES / POWER")
	var power: PackedStringArray = _power_lines(terminal)
	if not power.is_empty():
		lines.append(power[0])
		for line: String in power:
			if line.ends_with("SHED"):
				lines.append(line)
	var water: Node = terminal.call("system", &"water_system")
	if water != null:
		var reserve: Dictionary = water.call("get_status")
		lines.append("POTABLE WATER %.1f/%.1f L" % [float(reserve["potable_l"]), float(reserve["potable_capacity_l"])])
		if float(reserve["potable_l"]) <= 0.0:
			lines.append("NO POTABLE WATER: CHECK RECLAIMER / FILTER CARTRIDGE")
		elif float(reserve["potable_fraction"]) < WaterSystem.LOW_FRACTION_THRESHOLD:
			lines.append("LOW POTABLE WATER: CHECK RECLAIMER / PLAN SUPPLIES")
	var stores: Node = terminal.call("system", &"stores_system")
	if stores != null:
		lines.append("RATIONS %d / GASKETS %d" % [int(stores.call("get_count", &"food_ration")), int(stores.call("get_count", &"gasket"))])
		if int(stores.call("get_count", &"food_ration")) == 0:
			lines.append("NO RATIONS: CHECK GALLEY / ARRIVAL SUPPLIES")
		for part: StringName in stores.call("get_low_stock"):
			lines.append("LOW STOCK: %s; CHECK STORES / FABRICATOR" % String(part).to_upper())
	lines.append("")
	lines.append("OVERNIGHT / CURRENT WATCH LOG")
	lines.append_array(_recent_lines(terminal))
	lines.append("STATUS: ALL READINGS / SHIP LOG: FULL HISTORY")
	lines.append("AFTER SERVICE: VERIFY STATUS BEFORE ENDING WATCH")
	lines.append("E/ESC: CLOSE")
	return lines


func _safety_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var atmosphere: Node = terminal.call("system", &"atmosphere_system")
	if atmosphere == null:
		return PackedStringArray(["ATMOSPHERE OFFLINE: READINGS UNAVAILABLE"])
	var status: Dictionary = atmosphere.call("get_status")
	var compartments: Dictionary = status["compartments"]
	var ids: Array = compartments.keys()
	ids.sort()
	var scrubbers: Dictionary = {}
	for node: Node in terminal.get_tree().get_nodes_in_group(&"saveable"):
		if node is ScrubberUnit:
			var unit: ScrubberUnit = node as ScrubberUnit
			scrubbers[unit.compartment_id] = bool(scrubbers.get(unit.compartment_id, false)) or (unit.is_powered() and unit.is_circuit_available())
	var hull: Node = terminal.call("system", &"hull_system")
	var hull_rooms: Dictionary = {}
	if hull != null:
		var hull_status: Dictionary = hull.call("get_status")
		hull_rooms = hull_status["compartments"]
	var vitals: Node = terminal.call("system", &"vitals_system")
	var current_room: StringName = StringName(terminal.call("get_status_compartment_id"))
	if vitals != null:
		var operator: Dictionary = vitals.call("get_status")
		if StringName(operator["manned_compartment"]) != &"":
			current_room = StringName(operator["manned_compartment"])
	var thermal: Node = terminal.call("system", &"thermal_system")
	var abnormal: int = 0
	for key: Variant in ids:
		var air: Dictionary = compartments[key]
		var warnings: PackedStringArray = PackedStringArray()
		if float(air["pressure_kpa"]) < AtmosphereSystem.VACUUM_PRESSURE_KPA:
			warnings.append("VACUUM: SUIT REQUIRED / CHECK ISOLATION")
		if vitals != null:
			if float(air["o2_fraction"]) < float(vitals.get("o2_breathing_threshold")):
				warnings.append("LOW O2: CHECK O2 SUPPLY; MANUAL: LIFE SUPPORT")
			if float(air["co2_ppm"]) >= float(vitals.get("cognition_co2_ppm")):
				warnings.append("HIGH CO2: CHECK SCRUBBER / BREAKER / FILTER")
		var shell: Dictionary = hull_rooms.get(key, {})
		if not shell.is_empty() and (int(shell["puncture_count"]) > 0 or float(shell["total_leak_rate_per_hour"]) > float(shell["base_leak_rate_per_hour"])):
			warnings.append("LEAK ABOVE BASELINE: CHECK COMPARTMENT HULL PATCH")
		if scrubbers.has(key):
			if not bool(scrubbers[key]) or not bool(air["scrubber_powered"]) or float(air["scrubber_efficiency"]) <= 0.0:
				warnings.append("SCRUBBER UNAVAILABLE: CHECK BREAKER / AIR TEST POINT")
			if not bool(air["filter_installed"]):
				warnings.append("FILTER MISSING: SCRUBBER REPLACEMENT PROCEDURE")
		var temperature: String = ""
		if thermal != null and bool(thermal.call("has_compartment", StringName(key))):
			var heat: Dictionary = thermal.call("get_compartment_status", StringName(key))
			temperature = " / %+.1f C" % float(heat["temperature_c"])
			if bool(heat["freeze_risk"]) or (vitals != null and float(heat["temperature_c"]) < float(vitals.get("cold_threshold_c"))):
				warnings.append("COLD: CHECK LIFE SUPPORT / HEATER; MANUAL: THERMAL")
		if not warnings.is_empty():
			abnormal += 1
		if not warnings.is_empty() or StringName(key) == current_room:
			lines.append("%s: O2 %.1f%% / CO2 %.0f PPM / %.1f KPA%s" % [String(key).to_upper(), float(air["o2_fraction"]) * 100.0, float(air["co2_ppm"]), float(air["pressure_kpa"]), temperature])
			for warning: String in warnings:
				lines.append("  " + warning)
	lines.insert(0, "ROOMS: %d CHECKED / %d NEED ATTENTION" % [ids.size(), abnormal])
	if thermal == null:
		lines.append("THERMAL OFFLINE: READINGS UNAVAILABLE")
	return lines


func _inspection_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for group: StringName in SERVICE_GUIDES:
		var system: Node = terminal.call("system", group)
		if system == null or not system.has_method(&"get_wear_status"):
			continue
		var wear: Dictionary = system.call("get_wear_status")
		var ids: Array = wear.keys()
		ids.sort()
		var needs_scan: bool = false
		var unscanned_targets: Dictionary = {}
		for key: Variant in ids:
			var component: Dictionary = wear[key]
			needs_scan = needs_scan or not bool(component.get("scanned", false))
			if group == &"nav_system" and not bool(component.get("scanned", false)):
				unscanned_targets[String(key).get_slice("_", 0)] = true
			if bool(component.get("diagnosed", false)) and bool(component["failed"]):
				lines.append("DIAGNOSED %s: %s" % [String(key).to_upper(), _component_state_text(component)])
				lines.append("  " + String(SERVICE_GUIDES[group]))
				if group == &"nav_system":
					var target: String = String(key).get_slice("_", 0).to_upper()
					lines.append("  %s: ISOLATE / WRENCH OPEN / MULTIMETER DIAGNOSE / WRENCH SERVICE / CLOSE / MULTIMETER RESTORE" % target)
				else:
					lines.append_array(_refit_lines(system, StringName(key)))
					if group == &"hull_system":
						lines.append("  SEAM FITTINGS ONLY; DO NOT ALTER GROWN FRAME")
			elif bool(component.get("scanned", false)):
				lines.append("SCANNED %s: %s; %s" % [String(key).to_upper(), _condition_text(component), "DIAGNOSIS REQUIRED" if bool(component["failed"]) else "NO DIAGNOSED FAULT"])
				if group != &"nav_system" and float(component["condition"]) < 1.0:
					lines.append("  " + String(SERVICE_GUIDES[group]))
					lines.append_array(_refit_lines(system, StringName(key)))
		if needs_scan:
			if group == &"nav_system":
				for target: String in unscanned_targets:
					lines.append("INSPECTION NOT LOGGED: %s STERN EVA SERVICE PANEL" % target.to_upper())
			else:
				lines.append("INSPECTION NOT LOGGED: " + String(SERVICE_GUIDES[group]))
	if lines.is_empty():
		lines.append("NO INSPECTION RECORDS AVAILABLE")
	return lines


func _refit_lines(system: Node, component_id: StringName) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray(["  MULTIMETER DIAGNOSE; SCANNER LOGS WEAR"])
	if not system.has_method(&"get_maintenance_status"):
		return lines
	var service: Dictionary = system.call("get_maintenance_status", component_id)
	if service.is_empty():
		return lines
	var circuit: String = String(service["circuit"])
	if circuit == "all_bus":
		lines.append("  ALL BUS BREAKERS OFF")
	elif not circuit.is_empty():
		lines.append("  BREAKER OFF: " + circuit.replace("_", " ").to_upper())
	lines.append("  WRENCH: OPEN / REFIT / CLOSE; %s / %.2f H" % [String(service["part"]).to_upper(), float(service["hours"])])
	lines.append("  ISOLATED %s; COVER %s; VERIFY STATUS AFTER RESTORATION" % ["YES" if bool(service["isolated"]) else "NO", "OPEN" if bool(service["housing_open"]) else "CLOSED"])
	return lines


func _recent_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var computer: Node = terminal.call("system", &"computer_system")
	var clock: Node = terminal.call("_get_autoload", &"SimClock")
	if computer == null or clock == null:
		return PackedStringArray(["WATCH HISTORY UNAVAILABLE"])
	var day: int = int(clock.call("get_day"))
	for entry: Dictionary in computer.call("get_entries"):
		if int(entry["day"]) < day - 1 or int(entry["day"]) > day:
			continue
		# Automatic failure history predates tool gating; the watch must not repeat its fault details.
		if StringName(entry["kind"]) == &"component_failed":
			continue
		lines.append(LogProgram.history_line(entry))
		if lines.size() >= 4:
			break
	if lines.is_empty():
		lines.append("NO RECENT WATCH ENTRIES")
	return lines
