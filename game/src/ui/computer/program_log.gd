## SHIP LOG: the onboard scheduler history plus the archived operator volumes.
class_name LogProgram
extends ComputerProgram

const MAX_HISTORY_ROWS: int = 16

var _view: StringName = &""
var _highlighted: StringName = &""


func _init() -> void:
	title = "SHIP LOG"


func get_actions(terminal: Node) -> Array[StringName]:
	var actions: Array[StringName] = [&"history"]
	for entry: LogEntry in _volumes(terminal):
		actions.append(entry.id)
	return actions


func get_action_label(terminal: Node, action: StringName) -> String:
	if action == &"history":
		return "ONBOARD HISTORY"
	var volume: LogEntry = _find_volume(terminal, action)
	if volume != null:
		return volume.title
	return String(action).to_upper().replace("_", " ")


func get_badge(terminal: Node) -> String:
	var computer: Node = terminal.call("system", &"computer_system")
	if computer == null:
		return ""
	var unread: int = int(computer.call("get_unread_count"))
	return str(unread) if unread > 0 else ""


func set_highlighted_action(_terminal: Node, action: StringName) -> void:
	_highlighted = action


func on_opened(terminal: Node) -> void:
	if _view == &"":
		var hint: LogEntry = terminal.call("get_archive_hint") as LogEntry
		_view = hint.id if hint != null else &"history"
	if _view == &"history":
		_mark_all_read(terminal)


func build_readout(terminal: Node) -> PackedStringArray:
	var shown: StringName = _highlighted if _highlighted != &"" else _view
	if shown == &"":
		shown = &"history"
	var lines: PackedStringArray = PackedStringArray()
	var volume: LogEntry = _find_volume(terminal, shown)
	if volume != null:
		lines.append(volume.date_text)
		lines.append(volume.title)
		lines.append("")
		for body_line: String in volume.body.split("\n"):
			lines.append(body_line)
	else:
		lines.append("ONBOARD HISTORY")
		lines.append("")
		var computer: Node = terminal.call("system", &"computer_system")
		var entries: Array = []
		if computer != null:
			entries = computer.call("get_entries")
		if entries.is_empty():
			lines.append("NO ENTRIES")
		else:
			var rows: int = mini(entries.size(), MAX_HISTORY_ROWS)
			for i: int in rows:
				var entry: Dictionary = entries[i]
				var marker: String = "* " if bool(entry["unread"]) else "  "
				lines.append("%sDAY %04d  %02d:00  %s" % [
					marker,
					int(entry["day"]),
					int(entry["hour"]),
					String(entry["text"]),
				])
			if entries.size() > rows:
				lines.append("  ... %d OLDER ENTRIES" % (entries.size() - rows))
	lines.append("")
	lines.append("E/ESC: CLOSE")
	return lines


func select_action(terminal: Node, action: StringName) -> bool:
	if action == &"history":
		_view = &"history"
		_mark_all_read(terminal)
		return true
	if _find_volume(terminal, action) != null:
		_view = action
		return true
	return false


func _volumes(terminal: Node) -> Array[LogEntry]:
	var volumes: Array[LogEntry] = []
	var seen: Dictionary = {}
	var hint: LogEntry = terminal.call("get_archive_hint") as LogEntry
	if hint != null:
		volumes.append(hint)
		seen[hint.id] = true
	var computer: Node = terminal.call("system", &"computer_system")
	if computer != null:
		for entry: LogEntry in computer.call("get_archive"):
			if entry == null or seen.has(entry.id):
				continue
			volumes.append(entry)
			seen[entry.id] = true
	return volumes


func _find_volume(terminal: Node, volume_id: StringName) -> LogEntry:
	for entry: LogEntry in _volumes(terminal):
		if entry.id == volume_id:
			return entry
	return null


func _mark_all_read(terminal: Node) -> void:
	var computer: Node = terminal.call("system", &"computer_system")
	if computer != null and computer.has_method(&"mark_all_read"):
		computer.call("mark_all_read")
