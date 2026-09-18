## Cockpit comms terminal: inbox on the left, message body on the right, sendable reports below.
## Latency is the point — replies take weeks, and some never come.
class_name CommsTerminal
extends Interactable

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer


func get_interaction_prompt() -> String:
	return "Close comms" if is_open() else "Read comms"


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func close() -> void:
	if _menu != null:
		_menu.close()
	if _root != null:
		_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func get_menu() -> ScrollMenu:
	return _menu


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if not is_open():
		return lines
	var comms: Node = _get_system(&"comms_system")
	if comms == null:
		lines.append("COMMS OFFLINE")
		return lines
	var index: int = _menu.get_highlighted_index()
	var inbox: Array = comms.call("get_inbox")
	var outbound: Array = comms.call("get_outbound")
	if index < outbound.size():
		var outbound_entry: Dictionary = outbound[index]
		lines.append("OUTBOUND DRAFT  -  %s" % String(outbound_entry["sender"]))
		lines.append("")
		for body_line: String in String(outbound_entry["body"]).split("\n"):
			lines.append(body_line)
		return lines
	var inbox_index: int = index - outbound.size()
	if inbox_index < 0 or inbox_index >= inbox.size():
		return lines
	var entry: Dictionary = inbox[inbox_index]
	lines.append("DAY %d  -  %s" % [int(entry["day"]), String(entry["sender"])])
	lines.append(String(entry["date_text"]))
	lines.append("")
	for body_line: String in String(entry["body"]).split("\n"):
		lines.append(body_line)
	return lines


func _handle_interact(_player: Node) -> void:
	if is_open():
		close()
		return
	_ensure_ui()
	if _menu == null:
		return
	_refresh_menu()
	_menu.open()
	_refresh_content()
	if _root != null:
		_root.visible = true


func _on_selected(index: int) -> void:
	var comms: Node = _get_system(&"comms_system")
	if comms == null:
		return
	var outbound: Array = comms.call("get_outbound")
	if index < outbound.size():
		comms.call("send_message", outbound[index]["id"])
		_refresh_menu()
		_refresh_content()
		return
	var inbox: Array = comms.call("get_inbox")
	var inbox_index: int = index - outbound.size()
	if inbox_index >= 0 and inbox_index < inbox.size():
		comms.call("mark_read", inbox[inbox_index]["id"])
		_refresh_menu()
		_refresh_content()


func _refresh_menu() -> void:
	if _menu == null:
		return
	var items: PackedStringArray = PackedStringArray()
	var comms: Node = _get_system(&"comms_system")
	if comms != null:
		var outbound: Array = comms.call("get_outbound")
		for entry: Dictionary in outbound:
			items.append("[SEND] %s" % String(entry["body"]).split("\n")[0].left(54))
		var inbox: Array = comms.call("get_inbox")
		for entry: Dictionary in inbox:
			var marker: String = "* " if bool(entry["unread"]) else "  "
			items.append("%sDAY %d - %s" % [marker, int(entry["day"]), String(entry["sender"])])
	if items.is_empty():
		items.append("(no traffic)")
	_menu.set_items(items)


func _on_highlighted(_index: int) -> void:
	_refresh_content()


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "CommsView"
	layer.layer = 12
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Comms"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Traffic"
	row.add_child(_menu)
	_menu.setup("COMMS", PackedStringArray(["NO TRAFFIC"]))
	if not _menu.option_selected.is_connected(_on_selected):
		_menu.option_selected.connect(_on_selected)
	if not _menu.option_highlighted.is_connected(_on_highlighted):
		_menu.option_highlighted.connect(_on_highlighted)
	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(460.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.03, 0.62)
	style.border_color = Color(0.2, 0.5, 0.35, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_content = Label.new()
	_content.name = "MessageBody"
	_content.add_theme_font_size_override("font_size", 14)
	_content.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55, 1.0))
	content_panel.add_child(_content)
	_root = row
