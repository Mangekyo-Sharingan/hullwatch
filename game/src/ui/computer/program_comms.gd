## COMMS TRAFFIC: send the operator's drafts and read what mission control sends back.
## Latency is the point — replies take weeks, and some never come.
class_name CommsProgram
extends ComputerProgram

var _highlighted: StringName = &""


func _init() -> void:
	title = "COMMS TRAFFIC"


func get_actions(terminal: Node) -> Array[StringName]:
	var actions: Array[StringName] = []
	var comms: Node = terminal.call("system", &"comms_system")
	if comms == null:
		return actions
	for entry: Dictionary in comms.call("get_outbound"):
		actions.append(StringName(String(entry["id"])))
	for entry: Dictionary in comms.call("get_inbox"):
		actions.append(StringName(String(entry["id"])))
	return actions


func get_action_label(terminal: Node, action: StringName) -> String:
	var comms: Node = terminal.call("system", &"comms_system")
	if comms == null:
		return String(action)
	for entry: Dictionary in comms.call("get_outbound"):
		if StringName(String(entry["id"])) == action:
			return "[SEND] %s" % String(entry["body"]).split("\n")[0].left(54)
	for entry: Dictionary in comms.call("get_inbox"):
		if StringName(String(entry["id"])) == action:
			var marker: String = "* " if bool(entry["unread"]) else "  "
			return "%sDAY %d - %s" % [marker, int(entry["day"]), String(entry["sender"])]
	return String(action)


func get_badge(terminal: Node) -> String:
	var comms: Node = terminal.call("system", &"comms_system")
	if comms == null:
		return ""
	var unread: int = int(comms.call("get_unread_count"))
	return str(unread) if unread > 0 else ""


func set_highlighted_action(_terminal: Node, action: StringName) -> void:
	_highlighted = action


func build_readout(terminal: Node) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var comms: Node = terminal.call("system", &"comms_system")
	if comms == null:
		lines.append("COMMS OFFLINE")
		return lines
	var shown: StringName = _highlighted
	if shown == &"":
		var actions: Array[StringName] = get_actions(terminal)
		if actions.is_empty():
			lines.append("NO TRAFFIC")
			return lines
		shown = actions[0]
	var outbound: Array = comms.call("get_outbound")
	for entry: Dictionary in outbound:
		if StringName(String(entry["id"])) == shown:
			lines.append("OUTBOUND DRAFT  -  %s" % String(entry["sender"]))
			lines.append("")
			for body_line: String in String(entry["body"]).split("\n"):
				lines.append(body_line)
			return lines
	var inbox: Array = comms.call("get_inbox")
	for entry: Dictionary in inbox:
		if StringName(String(entry["id"])) == shown:
			lines.append("DAY %d  -  %s" % [int(entry["day"]), String(entry["sender"])])
			lines.append(String(entry["date_text"]))
			lines.append("")
			for body_line: String in String(entry["body"]).split("\n"):
				lines.append(body_line)
			return lines
	lines.append("NO TRAFFIC")
	return lines


func select_action(terminal: Node, action: StringName) -> bool:
	var comms: Node = terminal.call("system", &"comms_system")
	if comms == null:
		return false
	for entry: Dictionary in comms.call("get_outbound"):
		if StringName(String(entry["id"])) == action:
			comms.call("send_message", action)
			return true
	for entry: Dictionary in comms.call("get_inbox"):
		if StringName(String(entry["id"])) == action:
			comms.call("mark_read", action)
			return true
	return false
