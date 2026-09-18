## Code-built settings overlay on a semi-transparent scroll menu. Wheel browses, wheel click
## selects (steps/toggles the highlighted row), right click decreases a stepped row.
## Reads/writes through the GameSettings autoload (null-safe: renders without it too).
extends CanvasLayer

const SETTINGS_PATH: NodePath = ^"/root/GameSettings"
const SENSITIVITY_STEP: float = 0.25
const VOLUME_STEP_DB: float = 5.0
const UI_SCALE_STEP: float = 0.05
const MENU_HINT: String = "WHEEL: BROWSE   CLICK: SELECT / +   RIGHT CLICK: -"

const ROW_SENSITIVITY: int = 0
const ROW_INVERT: int = 1
const ROW_VOLUME: int = 2
const ROW_UI_SCALE: int = 3
const ROW_RESET: int = 4
const ROW_CLOSE: int = 5

var _open: bool = false
var _menu: ScrollMenu


func _ready() -> void:
	layer = 20
	_build_ui()
	_connect_settings()
	visible = false
	_refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()
	elif _open and event.is_action_pressed(&"secondary"):
		_decrease_highlighted()


func toggle() -> void:
	_set_open(not _open)


func is_menu_open() -> bool:
	return _open


func get_menu() -> ScrollMenu:
	return _menu


## Current display text for a settings row, or "" when the key is unknown.
func get_row_value_text(key: StringName) -> String:
	var text: String = ""
	match key:
		&"mouse_sensitivity_multiplier":
			text = "%.2fx" % _setting_float(key, 1.0)
		&"invert_y":
			text = "ON" if _setting_bool(key, false) else "OFF"
		&"master_volume_db":
			text = "%d dB" % int(roundf(_setting_float(key, 0.0)))
		&"ui_scale":
			text = "%d%%" % int(roundf(_setting_float(key, 1.0) * 100.0))
	return text


func _set_open(open: bool) -> void:
	_open = open
	visible = open
	if _menu != null:
		if open:
			_menu.open()
		else:
			_menu.close()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func _connect_settings() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_signal(&"settings_changed"):
		return
	if not settings.is_connected(&"settings_changed", _on_settings_changed):
		settings.connect(&"settings_changed", _on_settings_changed)


func _on_settings_changed(_key: StringName, _value: Variant) -> void:
	_refresh_labels()


func _on_option_selected(index: int) -> void:
	match index:
		ROW_SENSITIVITY:
			_step(&"mouse_sensitivity_multiplier", 1.0)
		ROW_INVERT:
			_toggle_invert()
		ROW_VOLUME:
			_step(&"master_volume_db", 1.0)
		ROW_UI_SCALE:
			_step(&"ui_scale", 1.0)
		ROW_RESET:
			_reset()
		ROW_CLOSE:
			_set_open(false)


func _decrease_highlighted() -> void:
	if _menu == null:
		return
	match _menu.get_highlighted_index():
		ROW_SENSITIVITY:
			_step(&"mouse_sensitivity_multiplier", -1.0)
		ROW_VOLUME:
			_step(&"master_volume_db", -1.0)
		ROW_UI_SCALE:
			_step(&"ui_scale", -1.0)


func _step(key: StringName, direction: float) -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"set_value"):
		return
	var step: float = _step_for(key)
	settings.call(&"set_value", key, _setting_float(key, 0.0) + step * direction)


func _toggle_invert() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"set_value"):
		return
	settings.call(&"set_value", &"invert_y", not _setting_bool(&"invert_y", false))


func _reset() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"reset_to_defaults"):
		return
	settings.call(&"reset_to_defaults")
	_refresh_labels()


func _refresh_labels() -> void:
	if _menu == null:
		return
	_menu.set_items(_menu_items())


func _menu_items() -> PackedStringArray:
	var items: PackedStringArray = PackedStringArray()
	items.append("MOUSE SENSITIVITY    %s" % get_row_value_text(&"mouse_sensitivity_multiplier"))
	items.append("INVERT Y             %s" % get_row_value_text(&"invert_y"))
	items.append("MASTER VOLUME        %s" % get_row_value_text(&"master_volume_db"))
	items.append("UI SCALE             %s" % get_row_value_text(&"ui_scale"))
	items.append("RESET DEFAULTS")
	items.append("CLOSE (ESC)")
	return items


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "MenuCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_menu = ScrollMenu.new()
	_menu.name = "SettingsMenu"
	center.add_child(_menu)
	_menu.setup("SETTINGS", _menu_items())
	_menu.set_hint(MENU_HINT)
	_menu.option_selected.connect(_on_option_selected)
	_menu.close()


func _step_for(key: StringName) -> float:
	match key:
		&"mouse_sensitivity_multiplier":
			return SENSITIVITY_STEP
		&"master_volume_db":
			return VOLUME_STEP_DB
		&"ui_scale":
			return UI_SCALE_STEP
	return 0.0


func _settings() -> Node:
	return get_node_or_null(SETTINGS_PATH)


func _setting_float(key: StringName, fallback: float) -> float:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"get_value"):
		return fallback
	var value: Variant = settings.call(&"get_value", key)
	if not (value is float or value is int):
		return fallback
	return float(value)


func _setting_bool(key: StringName, fallback: bool) -> bool:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"get_value"):
		return fallback
	var value: Variant = settings.call(&"get_value", key)
	if not (value is bool):
		return fallback
	return bool(value)
