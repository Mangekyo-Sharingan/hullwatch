## EVA suit locker inside the airlock: equip, stow or refill the suit's O2 tank.
class_name SuitLocker
extends Interactable

const ACTION_LABELS: Dictionary = {
	&"equip": "Take the EVA suit",
	&"store": "Stow the EVA suit",
	&"refill": "Refill the O2 tank from ship air",
}

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _actions: Array[StringName] = []


func get_interaction_prompt() -> String:
	return "Close locker" if is_open() else "EVA suit locker"


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func close() -> void:
	if _menu != null:
		_menu.close()


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func get_menu() -> ScrollMenu:
	return _menu


func get_actions() -> Array[StringName]:
	return _actions


func select_action(action: StringName) -> bool:
	var airlock: Node = _get_system(&"airlock_system")
	if airlock == null:
		return false
	var performed: bool = false
	match action:
		&"equip":
			performed = bool(airlock.call("equip_suit")) if airlock.has_method(&"equip_suit") else false
		&"store":
			performed = bool(airlock.call("store_suit")) if airlock.has_method(&"store_suit") else false
		&"refill":
			performed = float(airlock.call("refill_suit")) > 0.0 if airlock.has_method(&"refill_suit") else false
	if not performed:
		_emit_sim_event(&"procedure_error", {
			"reason": _refusal(action),
			"airlock_id": _airlock_id(),
		})
	_refresh_menu()
	_refresh_content()
	return performed


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var status: Dictionary = _status()
	if status.is_empty():
		lines.append("LOCKER OFFLINE")
		return lines
	if bool(status.get("suit_worn", false)):
		lines.append("SUIT: WORN")
	elif bool(status.get("suit_stored", true)):
		lines.append("SUIT: STOWED")
	else:
		lines.append("SUIT: MISSING")
	lines.append("O2 TANK: %.2f h" % float(status.get("suit_o2_hours", 0.0)))
	lines.append("")
	lines.append("The suit feeds the tank to your breathing line while")
	lines.append("the lock or the hull outside has no pressure. Watch it.")
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


func _on_selected(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	select_action(_actions[index])


func _refresh_menu() -> void:
	if _menu == null:
		return
	var status: Dictionary = _status()
	_actions.clear()
	if bool(status.get("suit_stored", true)):
		_actions.append(&"equip")
		if float(status.get("suit_o2_hours", 0.0)) < _capacity():
			_actions.append(&"refill")
	if bool(status.get("suit_worn", false)):
		_actions.append(&"store")
	var items: PackedStringArray = PackedStringArray()
	for action: StringName in _actions:
		items.append(String(ACTION_LABELS.get(action, String(action))))
	if items.is_empty():
		items.append("(nothing to do)")
	_menu.set_items(items)


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _refusal(action: StringName) -> StringName:
	var status: Dictionary = _status()
	if status.is_empty():
		return &"airlock_offline"
	match action:
		&"equip":
			return &"suit_unavailable"
		&"store":
			return &"suit_not_worn"
		&"refill":
			return &"suit_refill_unavailable"
	return &"suit_unavailable"


func _capacity() -> float:
	var airlock: Node = _get_system(&"airlock_system")
	if airlock == null:
		return 4.0
	return float(airlock.get(&"suit_o2_capacity_hours"))


func _status() -> Dictionary:
	var airlock: Node = _get_system(&"airlock_system")
	if airlock == null or not airlock.has_method(&"get_status"):
		return {}
	var status: Variant = airlock.call("get_status")
	if not (status is Dictionary):
		return {}
	return status


func _airlock_id() -> StringName:
	return StringName(String(_status().get("airlock_id", &"")))


func _ensure_ui() -> void:
	if _root != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "LockerView"
	layer.layer = 12
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Locker"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Actions"
	row.add_child(_menu)
	_menu.setup("SUIT LOCKER", PackedStringArray(["(nothing to do)"]))
	if not _menu.option_selected.is_connected(_on_selected):
		_menu.option_selected.connect(_on_selected)
	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(340.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.02, 0.62)
	style.border_color = Color(0.65, 0.55, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_content = Label.new()
	_content.name = "SuitStatus"
	_content.add_theme_font_size_override("font_size", 14)
	_content.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6, 1.0))
	content_panel.add_child(_content)
	_root = row
