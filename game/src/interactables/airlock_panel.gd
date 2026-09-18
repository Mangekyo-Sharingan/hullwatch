## Airlock control panel: a menu of cycle actions (pump, vent, pressurize) plus live lock status.
class_name AirlockPanel
extends Interactable

const ACTION_LABELS: Dictionary = {
	&"depressurize": "Depressurize the lock (pump air back to storage)",
	&"vent": "Vent the lock to space (lose the air)",
	&"pressurize": "Pressurize the lock (draw air from storage)",
}

var _menu: ScrollMenu
var _content: Label
var _root: HBoxContainer
var _actions: Array[StringName] = []


func get_interaction_prompt() -> String:
	return "Close panel" if is_open() else "Airlock controls"


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
	if airlock == null or not airlock.has_method(&"request_cycle"):
		return false
	var started: bool = bool(airlock.call("request_cycle", action))
	if not started:
		_emit_sim_event(&"procedure_error", {
			"reason": _cycle_refusal(action),
			"airlock_id": _airlock_id(),
		})
	_refresh_menu()
	_refresh_content()
	return started


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var status: Dictionary = _status()
	if status.is_empty():
		lines.append("LOCK OFFLINE")
		return lines
	lines.append("STATE: %s" % String(status.get("state", &"idle")).to_upper())
	lines.append("PRESSURE: %.1f kPa" % float(status.get("pressure_kpa", 0.0)))
	lines.append("INNER HATCH: %s" % ("OPEN" if bool(status.get("inner_open", false)) else "CLOSED"))
	lines.append("OUTER HATCH: %s" % ("OPEN" if bool(status.get("outer_open", false)) else "CLOSED"))
	if bool(status.get("suit_worn", false)):
		lines.append("SUIT: WORN  %.1f h O2" % float(status.get("suit_o2_hours", 0.0)))
	elif bool(status.get("suit_stored", true)):
		lines.append("SUIT: STOWED  %.1f h O2" % float(status.get("suit_o2_hours", 0.0)))
	else:
		lines.append("SUIT: MISSING")
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
	var pressure_kpa: float = float(status.get("pressure_kpa", 0.0))
	var state: StringName = status.get("state", &"idle")
	var inner_open: bool = bool(status.get("inner_open", false))
	var outer_open: bool = bool(status.get("outer_open", false))
	_actions.clear()
	if state == &"idle":
		if pressure_kpa > AtmosphereSystem.VACUUM_PRESSURE_KPA:
			if not inner_open:
				_actions.append(&"depressurize")
				_actions.append(&"vent")
		elif not outer_open:
			_actions.append(&"pressurize")
	var items: PackedStringArray = PackedStringArray()
	for action: StringName in _actions:
		items.append(String(ACTION_LABELS.get(action, String(action))))
	if items.is_empty():
		items.append("(cycle in progress)")
	_menu.set_items(items)


func _refresh_content() -> void:
	if _content != null:
		_content.text = "\n".join(build_readout())


func _emit_sim_event_to_bus(event_name: StringName, payload: Dictionary) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.call("emit_event", event_name, payload)


func _cycle_refusal(action: StringName) -> StringName:
	var status: Dictionary = _status()
	if status.is_empty():
		return &"airlock_offline"
	if StringName(status.get("state", &"idle")) != &"idle":
		return &"airlock_cycling"
	var inner_open: bool = bool(status.get("inner_open", false))
	var outer_open: bool = bool(status.get("outer_open", false))
	if action == &"pressurize":
		if outer_open:
			return &"airlock_interlock"
		return &"airlock_pressurized"
	if inner_open:
		return &"airlock_interlock"
	return &"airlock_depressurized"


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
	layer.name = "AirlockView"
	layer.layer = 12
	add_child(layer)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	var row := HBoxContainer.new()
	row.name = "Airlock"
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_menu = ScrollMenu.new()
	_menu.name = "Actions"
	row.add_child(_menu)
	_menu.setup("AIRLOCK CONTROL", PackedStringArray(["(cycle in progress)"]))
	if not _menu.option_selected.is_connected(_on_selected):
		_menu.option_selected.connect(_on_selected)
	var content_panel := PanelContainer.new()
	content_panel.custom_minimum_size = Vector2(360.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.05, 0.62)
	style.border_color = Color(0.3, 0.55, 0.65, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	content_panel.add_theme_stylebox_override("panel", style)
	row.add_child(content_panel)
	_content = Label.new()
	_content.name = "LockStatus"
	_content.add_theme_font_size_override("font_size", 14)
	_content.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	content_panel.add_child(_content)
	_root = row
