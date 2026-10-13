## SHIP CONTROL: remote handling of breakers, compartment isolation, the airlock, and doors.
class_name ControlProgram
extends ComputerProgram

const PAGE_POWER: StringName = &"power"
const PAGE_LIGHTING: StringName = &"lighting"
const PAGE_ATMOSPHERE: StringName = &"atmosphere"
const PAGE_AIRLOCK: StringName = &"airlock"
const PAGE_DOORS: StringName = &"doors"

const PAGE_ACTIONS: Array[StringName] = [
	&"page:power",
	&"page:atmosphere",
	&"page:airlock",
	&"page:doors",
	&"page:lighting",
]
const PAGE_TITLES: Dictionary = {
	&"page:power": "POWER",
	&"page:atmosphere": "ATMOSPHERE",
	&"page:airlock": "AIRLOCK",
	&"page:doors": "HATCHES AND DOORS",
	&"page:lighting": "LIGHTING",
}
const PAGE_IDS: Dictionary = {
	&"page:power": PAGE_POWER,
	&"page:atmosphere": PAGE_ATMOSPHERE,
	&"page:airlock": PAGE_AIRLOCK,
	&"page:doors": PAGE_DOORS,
	&"page:lighting": PAGE_LIGHTING,
}
const CYCLE_LABELS: Dictionary = {
	&"airlock:depressurize": "START DEPRESSURIZE",
	&"airlock:pressurize": "START PRESSURIZE",
	&"airlock:vent": "VENT TO SPACE",
}

var _page: StringName = PAGE_POWER


func _init() -> void:
	title = "SHIP CONTROL"


func get_actions(terminal: Node) -> Array[StringName]:
	var actions: Array[StringName] = PAGE_ACTIONS.duplicate()
	if _page == PAGE_POWER:
		for circuit_id: String in _circuit_ids(terminal):
			actions.append(StringName("breaker:" + circuit_id))
	elif _page == PAGE_LIGHTING:
		for entry: Dictionary in _lighting_entries(terminal):
			actions.append(StringName("light:" + String(entry["id"])))
	elif _page == PAGE_ATMOSPHERE:
		for compartment_id: String in _compartment_ids(terminal):
			actions.append(StringName("isolate:" + compartment_id))
	elif _page == PAGE_AIRLOCK:
		actions.append(&"airlock:depressurize")
		actions.append(&"airlock:pressurize")
		actions.append(&"airlock:vent")
		actions.append(&"hatch:inner")
		actions.append(&"hatch:outer")
	else:
		for door: Door in _plain_doors(terminal):
			actions.append(StringName("door:" + String(door.name)))
	return actions


func get_action_label(terminal: Node, action: StringName) -> String:
	if PAGE_TITLES.has(action):
		return String(PAGE_TITLES[action])
	var text: String = String(action)
	if text.begins_with("breaker:"):
		return _breaker_label(terminal, text.trim_prefix("breaker:"))
	if text.begins_with("light:"):
		var fixture: Dictionary = _lighting_status(terminal).get(StringName(text.trim_prefix("light:")), {})
		return _light_label(fixture)
	if text.begins_with("isolate:"):
		return _isolation_label(terminal, text.trim_prefix("isolate:"))
	if CYCLE_LABELS.has(action):
		return String(CYCLE_LABELS[action])
	if text == "hatch:inner":
		return "INNER HATCH  %s" % _hatch_state(terminal, &"inner")
	if text == "hatch:outer":
		return "OUTER HATCH  %s" % _hatch_state(terminal, &"outer")
	if text.begins_with("door:"):
		return _door_label(terminal, text.trim_prefix("door:"))
	return super.get_action_label(terminal, action)


func get_badge(_terminal: Node) -> String:
	return ""


func build_readout(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("CONTROL - %s" % _page_title())
	if _page == PAGE_POWER:
		lines.append_array(_power_lines(terminal))
	elif _page == PAGE_LIGHTING:
		lines.append_array(_lighting_lines(terminal))
	elif _page == PAGE_ATMOSPHERE:
		lines.append_array(_atmosphere_lines(terminal))
	elif _page == PAGE_AIRLOCK:
		lines.append_array(_airlock_lines(terminal))
	else:
		lines.append_array(_door_lines(terminal))
	return lines


func select_action(terminal: Node, action: StringName) -> bool:
	if PAGE_IDS.has(action):
		_page = StringName(PAGE_IDS[action])
		return true
	var text: String = String(action)
	if text.begins_with("breaker:"):
		return _toggle_breaker(terminal, text.trim_prefix("breaker:"))
	if text.begins_with("light:"):
		var fixture_id: StringName = StringName(text.trim_prefix("light:"))
		var fixture: Dictionary = _lighting_status(terminal).get(fixture_id, {})
		var power: Node = _system(terminal, &"power_system")
		if fixture.is_empty() or power == null or not power.has_method(&"set_light_enabled"):
			return false
		return bool(power.call("set_light_enabled", fixture_id, not bool(fixture.get("enabled", false))))
	if text.begins_with("isolate:"):
		return _toggle_isolation(terminal, text.trim_prefix("isolate:"))
	if text.begins_with("airlock:"):
		return _request_cycle(terminal, StringName(text.trim_prefix("airlock:")))
	if text == "hatch:inner":
		return _request_hatch(terminal, &"inner")
	if text == "hatch:outer":
		return _request_hatch(terminal, &"outer")
	if text.begins_with("door:"):
		return _request_door(terminal, text.trim_prefix("door:"))
	return false


func _page_title() -> String:
	for action: StringName in PAGE_ACTIONS:
		if PAGE_IDS[action] == _page:
			return String(PAGE_TITLES[action])
	return String(_page).to_upper()


func _power_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var status: Dictionary = _power_status(terminal)
	if status.is_empty():
		lines.append("POWER -- OFFLINE")
		return lines
	lines.append("POWER  BATTERY %d%%  BUS %s" % [
		int(roundf(float(status.get("battery_fraction", 0.0)) * 100.0)),
		"BROWNOUT" if bool(status.get("brownout", false)) else "OK",
	])
	for circuit_id: String in _circuit_ids(terminal):
		lines.append("  %-11s %s" % [_circuit_label(circuit_id), _breaker_state(terminal, circuit_id)])
	return lines


func _lighting_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var circuit: Dictionary = _circuit_status(terminal, "lighting")
	lines.append("LIGHTING CIRCUIT  %.1f W  %s" % [float(circuit.get("demand_w", 0.0)), _breaker_state(terminal, "lighting")])
	var power: Dictionary = _power_status(terminal)
	if not power.is_empty():
		lines.append("BUS REQ %.0f W / GEN %.0f W" % [float(power.get("demand_w", 0.0)), float(power.get("generation_w", 0.0))])
		lines.append("BATTERY %.0f / %.0f Wh" % [float(power.get("battery_charge_wh", 0.0)), float(power.get("battery_capacity_wh", 0.0))])
	var entries: Array[Dictionary] = _lighting_entries(terminal)
	for entry: Dictionary in entries:
		lines.append(_light_label(entry["status"]))
	if entries.is_empty():
		lines.append("NO LIGHTS ONLINE")
	return lines


func _light_label(fixture: Dictionary) -> String:
	var state: String = "OFF"
	if bool(fixture.get("enabled", false)):
		state = "ON" if bool(fixture.get("powered", false)) else "NO POWER"
	return "%s  %s  %.1f W" % [String(fixture.get("label", "LIGHT")), state, float(fixture.get("watts", 0.0))]


func _atmosphere_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if _atmosphere_status(terminal).is_empty():
		lines.append("ATMOSPHERE -- OFFLINE")
		return lines
	for entry: Dictionary in _atmosphere_entries(terminal):
		var status: Dictionary = entry["status"]
		lines.append("%-14s %6.1f KPA  O2 %4.1f%%  %s" % [
			String(entry["id"]).to_upper(),
			float(status.get("pressure_kpa", 0.0)),
			float(status.get("o2_fraction", 0.0)) * 100.0,
			"ISOLATED" if bool(status.get("isolated", false)) else "OPEN",
		])
	return lines


func _airlock_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var status: Dictionary = _airlock_status(terminal)
	if status.is_empty():
		lines.append("AIRLOCK -- OFFLINE")
		return lines
	lines.append("STATE %s" % String(status.get("state", &"idle")).to_upper())
	lines.append("PRESSURE %.1f KPA" % float(status.get("pressure_kpa", 0.0)))
	lines.append("INNER HATCH  %s" % _hatch_state(terminal, &"inner"))
	lines.append("OUTER HATCH  %s" % _hatch_state(terminal, &"outer"))
	lines.append("SUIT %s" % ("WORN" if bool(status.get("suit_worn", false)) else "STOWED"))
	return lines


func _door_lines(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for door: Door in _plain_doors(terminal):
		lines.append("%s  %s" % [door.get_door_label(), "OPEN" if door.is_open() else "CLOSED"])
	if lines.is_empty():
		lines.append("NO DOORS ONLINE")
	return lines


func _toggle_breaker(terminal: Node, circuit_id: String) -> bool:
	var circuit: Dictionary = _circuit_status(terminal, circuit_id)
	if circuit.is_empty():
		return false
	var power: Node = _system(terminal, &"power_system")
	if power == null or not power.has_method(&"set_breaker"):
		return false
	return bool(power.call("set_breaker", StringName(circuit_id), not bool(circuit.get("breaker_on", false))))


func _toggle_isolation(terminal: Node, compartment_id: String) -> bool:
	var status: Dictionary = _compartment_status(terminal, compartment_id)
	if status.is_empty():
		return false
	var atmosphere: Node = _system(terminal, &"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"set_isolated"):
		return false
	atmosphere.call("set_isolated", StringName(compartment_id), not bool(status.get("isolated", false)))
	return true


func _request_cycle(terminal: Node, mode: StringName) -> bool:
	var airlock: Node = _system(terminal, &"airlock_system")
	if airlock == null or not airlock.has_method(&"request_cycle"):
		return false
	if bool(airlock.call("request_cycle", mode)):
		return true
	if airlock.has_method(&"get_cycle_refusal"):
		_emit_procedure_error(terminal, StringName(airlock.call("get_cycle_refusal", mode)))
	return false


func _request_hatch(terminal: Node, side: StringName) -> bool:
	var door: Door = _airlock_door(terminal, side)
	if door == null:
		return false
	return door.request_open(not door.is_open())


func _request_door(terminal: Node, node_name: String) -> bool:
	for door: Door in _plain_doors(terminal):
		if String(door.name) == node_name:
			return door.request_open(not door.is_open())
	return false


func _emit_procedure_error(terminal: Node, reason: StringName) -> void:
	if reason == &"":
		return
	var bus: Node = null
	if terminal != null and terminal.is_inside_tree():
		bus = terminal.get_node_or_null(^"/root/EventBus")
	if bus == null:
		var loop: MainLoop = Engine.get_main_loop()
		if loop is SceneTree:
			bus = (loop as SceneTree).root.get_node_or_null(^"/root/EventBus")
	if bus != null and bus.has_method(&"emit_event"):
		bus.call("emit_event", &"procedure_error", {"reason": reason})


func _breaker_label(terminal: Node, circuit_id: String) -> String:
	var state: String = _breaker_state(terminal, circuit_id)
	if state.is_empty():
		return _circuit_label(circuit_id)
	return "%s  %s" % [_circuit_label(circuit_id), state]


func _isolation_label(terminal: Node, compartment_id: String) -> String:
	var status: Dictionary = _compartment_status(terminal, compartment_id)
	if status.is_empty():
		return compartment_id.to_upper()
	var state: String = "ISOLATED" if bool(status.get("isolated", false)) else "OPEN"
	return "%s  %s" % [compartment_id.to_upper(), state]


func _door_label(terminal: Node, node_name: String) -> String:
	for door: Door in _plain_doors(terminal):
		if String(door.name) == node_name:
			return "%s  %s" % [door.get_door_label(), "OPEN" if door.is_open() else "CLOSED"]
	return node_name.to_upper().replace("_", " ")


func _hatch_state(terminal: Node, side: StringName) -> String:
	var status: Dictionary = _airlock_status(terminal)
	var key: String = "inner_open" if side == &"inner" else "outer_open"
	return "OPEN" if bool(status.get(key, false)) else "SHUT"


func _breaker_state(terminal: Node, circuit_id: String) -> String:
	var circuit: Dictionary = _circuit_status(terminal, circuit_id)
	if circuit.is_empty():
		return ""
	if not bool(circuit.get("breaker_on", false)):
		return "OFF"
	if bool(circuit.get("shed", false)):
		return "SHED"
	return "ON"


func _circuit_status(terminal: Node, circuit_id: String) -> Dictionary:
	for entry: Dictionary in _power_entries(terminal):
		if String(entry["id"]) == circuit_id:
			return entry["status"]
	return {}


func _compartment_status(terminal: Node, compartment_id: String) -> Dictionary:
	for entry: Dictionary in _atmosphere_entries(terminal):
		if String(entry["id"]) == compartment_id:
			return entry["status"]
	return {}


func _circuit_ids(terminal: Node) -> Array[String]:
	return _entry_ids(_power_entries(terminal))


func _compartment_ids(terminal: Node) -> Array[String]:
	return _entry_ids(_atmosphere_entries(terminal))


func _power_entries(terminal: Node) -> Array[Dictionary]:
	return _entries(_power_status(terminal), "circuits")


func _lighting_entries(terminal: Node) -> Array[Dictionary]:
	return _entries({"fixtures": _lighting_status(terminal)}, "fixtures")


func _lighting_status(terminal: Node) -> Dictionary:
	var power: Node = _system(terminal, &"power_system")
	if power == null or not power.has_method(&"get_lighting_status"):
		return {}
	var status: Dictionary = power.call("get_lighting_status")
	return status


func _atmosphere_entries(terminal: Node) -> Array[Dictionary]:
	return _entries(_atmosphere_status(terminal), "compartments")


func _entries(status: Dictionary, key: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var source: Variant = status.get(key, {})
	if source is Dictionary:
		for source_key: Variant in (source as Dictionary).keys():
			entries.append({"id": String(source_key), "status": (source as Dictionary)[source_key]})
	entries.sort_custom(_sort_entries)
	return entries


func _entry_ids(entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(String(entry["id"]))
	return ids


func _plain_doors(terminal: Node) -> Array[Door]:
	var doors: Array[Door] = []
	for node: Node in _ship_doors(terminal):
		var door: Door = node as Door
		if door != null and door.airlock_id == &"":
			doors.append(door)
	return doors


func _airlock_door(terminal: Node, side: StringName) -> Door:
	for node: Node in _ship_doors(terminal):
		var door: Door = node as Door
		if door != null and door.airlock_id != &"" and door.airlock_side == side:
			return door
	return null


func _ship_doors(terminal: Node) -> Array[Node]:
	var doors: Array[Node] = []
	if terminal == null:
		return doors
	var tree: SceneTree = terminal.get_tree()
	if tree == null:
		return doors
	for node: Node in tree.get_nodes_in_group(&"ship_door"):
		doors.append(node)
	doors.sort_custom(_sort_doors)
	return doors


func _sort_doors(a: Node, b: Node) -> bool:
	return String(a.name) < String(b.name)


func _sort_entries(a: Dictionary, b: Dictionary) -> bool:
	return String(a["id"]) < String(b["id"])


func _system(terminal: Node, group_name: StringName) -> Node:
	if terminal == null:
		return null
	return terminal.call("system", group_name) as Node


func _power_status(terminal: Node) -> Dictionary:
	var power: Node = _system(terminal, &"power_system")
	if power == null or not power.has_method(&"get_status"):
		return {}
	var status: Dictionary = power.call("get_status")
	return status


func _atmosphere_status(terminal: Node) -> Dictionary:
	var atmosphere: Node = _system(terminal, &"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"get_status"):
		return {}
	var status: Dictionary = atmosphere.call("get_status")
	return status


func _airlock_status(terminal: Node) -> Dictionary:
	var airlock: Node = _system(terminal, &"airlock_system")
	if airlock == null or not airlock.has_method(&"get_status"):
		return {}
	var status: Dictionary = airlock.call("get_status")
	return status


func _circuit_label(circuit_id: String) -> String:
	return "DRIVE FEED UV" if circuit_id == "xenonite_uv" else circuit_id.to_upper()
