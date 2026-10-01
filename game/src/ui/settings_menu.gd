## Code-built settings overlay on a semi-transparent scroll menu. Wheel browses, wheel click
## selects (steps/toggles the highlighted row), right click decreases a stepped row.
## Reads/writes through the GameSettings autoload (null-safe: renders without it too).
extends CanvasLayer

signal closed

const SETTINGS_PATH: NodePath = ^"/root/GameSettings"
const SENSITIVITY_STEP: float = 0.25
const VOLUME_STEP_DB: float = 5.0
const UI_SCALE_STEP: float = 0.05
const FILTER_INTENSITY_STEP: float = 0.1
const ENCOUNTER_FREQUENCY_STEP: float = 0.25
const MENU_HINT: String = "WHEEL: BROWSE   CLICK: SELECT / +   RIGHT CLICK: -   ESC: CLOSE"

const ROW_SENSITIVITY: int = 0
const ROW_INVERT: int = 1
const ROW_VOLUME: int = 2
const ROW_UI_SCALE: int = 3
const ROW_ANALOGUE_FILTER: int = 4
const ROW_FILTER_INTENSITY: int = 5
const ROW_ASTEROID_FREQUENCY: int = 6
const ROW_ANOMALY_FREQUENCY: int = 7
const ROW_RESET: int = 8
const ROW_CLOSE: int = 9

var _open: bool = false
var managed_by_controller: bool = false
var capture_mouse_when_closed: bool = true
var _menu: ScrollMenu


func _ready() -> void:
	layer = 20
	_build_ui()
	_connect_settings()
	visible = false
	_refresh_labels()
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)


func _unhandled_input(event: InputEvent) -> void:
	if managed_by_controller:
		return
	if event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed(&"secondary"):
		_decrease_highlighted()


func toggle() -> void:
	_set_open(not _open)


func open() -> void:
	_set_open(true)


func close() -> void:
	_set_open(false)


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
		&"analogue_filter_enabled":
			text = "ON" if _setting_bool(key, true) else "OFF"
		&"analogue_filter_intensity":
			text = "%d%%" % int(roundf(_setting_float(key, 1.0) * 100.0))
		&"asteroid_frequency", &"anomaly_frequency":
			text = "x%.2f" % _option_float(key, 1.0)
	return text


func _set_open(open: bool) -> void:
	var was_open: bool = _open
	_open = open
	visible = open
	if _menu != null:
		if open:
			_menu.open()
		else:
			_menu.close()
	if DisplayServer.get_name() != "headless":
		if open:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif capture_mouse_when_closed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if was_open and not open:
		closed.emit()


func _connect_settings() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_signal(&"settings_changed"):
		return
	if not settings.is_connected(&"settings_changed", _on_settings_changed):
		settings.connect(&"settings_changed", _on_settings_changed)


func _on_settings_changed(_key: StringName, _value: Variant) -> void:
	_refresh_labels()


func _apply_ui_scale() -> void:
	if _menu != null:
		_menu._apply_ui_scale()


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()


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
		ROW_ANALOGUE_FILTER:
			_toggle_analogue_filter()
		ROW_FILTER_INTENSITY:
			_step(&"analogue_filter_intensity", 1.0)
		ROW_ASTEROID_FREQUENCY:
			_step(&"asteroid_frequency", 1.0)
		ROW_ANOMALY_FREQUENCY:
			_step(&"anomaly_frequency", 1.0)
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
		ROW_FILTER_INTENSITY:
			_step(&"analogue_filter_intensity", -1.0)
		ROW_ASTEROID_FREQUENCY:
			_step(&"asteroid_frequency", -1.0)
		ROW_ANOMALY_FREQUENCY:
			_step(&"anomaly_frequency", -1.0)


func _step(key: StringName, direction: float) -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"set_value"):
		return
	var step: float = _step_for(key)
	settings.call(&"set_value", key, _option_float(key, 0.0) + step * direction)
	settings.call(&"save_settings")


func _toggle_invert() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"set_value"):
		return
	settings.call(&"set_value", &"invert_y", not _setting_bool(&"invert_y", false))
	settings.call(&"save_settings")


func _toggle_analogue_filter() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"set_value"):
		return
	settings.call(&"set_value", &"analogue_filter_enabled", not _setting_bool(&"analogue_filter_enabled", true))
	settings.call(&"save_settings")


func _reset() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"reset_to_defaults"):
		return
	settings.call(&"reset_to_defaults")
	settings.call(&"save_settings")
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
	items.append("ANALOGUE FILTER      %s" % get_row_value_text(&"analogue_filter_enabled"))
	items.append("FILTER INTENSITY     %s" % get_row_value_text(&"analogue_filter_intensity"))
	items.append("ASTEROID FIELD RATE  %s" % get_row_value_text(&"asteroid_frequency"))
	items.append("ANOMALY FREQUENCY    %s" % get_row_value_text(&"anomaly_frequency"))
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
		&"analogue_filter_intensity":
			return FILTER_INTENSITY_STEP
		&"asteroid_frequency", &"anomaly_frequency":
			return ENCOUNTER_FREQUENCY_STEP
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


func _option_float(key: StringName, fallback: float) -> float:
	if key == &"asteroid_frequency" or key == &"anomaly_frequency":
		var sector: Node = get_tree().get_first_node_in_group(&"sector_system")
		if sector != null and sector.has_method(&"get_encounter_frequency"):
			return float(sector.call(&"get_encounter_frequency", key))
	return _setting_float(key, fallback)


func _setting_bool(key: StringName, fallback: bool) -> bool:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"get_value"):
		return fallback
	var value: Variant = settings.call(&"get_value", key)
	if not (value is bool):
		return fallback
	return bool(value)
