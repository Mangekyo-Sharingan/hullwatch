## Code-built settings overlay. Toggles on the pause action and reads/writes through the
## GameSettings autoload (null-safe: the menu still renders if the autoload is absent).
extends CanvasLayer

const SETTINGS_PATH: NodePath = ^"/root/GameSettings"
const SENSITIVITY_STEP: float = 0.25
const VOLUME_STEP_DB: float = 5.0
const UI_SCALE_STEP: float = 0.05
const VALUE_LABEL_WIDTH: float = 96.0

var _open: bool = false
var _panel: PanelContainer
var _value_labels: Dictionary = {}


func _ready() -> void:
	layer = 20
	_build_ui()
	_connect_settings()
	visible = false
	_refresh_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()


func toggle() -> void:
	_set_open(not _open)


func is_menu_open() -> bool:
	return _open


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


func _on_step_pressed(key: StringName, direction: float) -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"set_value"):
		return
	var step: float = _step_for(key)
	settings.call(&"set_value", key, _setting_float(key, 0.0) + step * direction)


func _on_toggle_pressed(key: StringName) -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"set_value"):
		return
	settings.call(&"set_value", key, not _setting_bool(key, false))


func _on_reset_pressed() -> void:
	var settings: Node = _settings()
	if settings == null or not settings.has_method(&"reset_to_defaults"):
		return
	settings.call(&"reset_to_defaults")
	_refresh_labels()


func _on_close_pressed() -> void:
	_set_open(false)


func _refresh_labels() -> void:
	for key: Variant in _value_labels.keys():
		var label: Label = _value_labels[key]
		label.text = get_row_value_text(key)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.05, 0.95)
	style.border_color = Color(0.25, 0.38, 0.4, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.55, 0.78, 0.72, 1.0))
	rows.add_child(title)

	_add_stepper_row(rows, &"mouse_sensitivity_multiplier", "MOUSE SENSITIVITY")
	_add_toggle_row(rows, &"invert_y", "INVERT Y")
	_add_stepper_row(rows, &"master_volume_db", "MASTER VOLUME")
	_add_stepper_row(rows, &"ui_scale", "UI SCALE")
	_add_action_row(rows, "RESET DEFAULTS", _on_reset_pressed)
	_add_action_row(rows, "CLOSE (ESC)", _on_close_pressed)
	_panel = panel


func _add_stepper_row(parent: VBoxContainer, key: StringName, title: String) -> void:
	var row := _make_row(parent, key, title)
	var minus := Button.new()
	minus.text = "-"
	minus.pressed.connect(_on_step_pressed.bind(key, -1.0))
	row.add_child(minus)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(_on_step_pressed.bind(key, 1.0))
	row.add_child(plus)


func _add_toggle_row(parent: VBoxContainer, key: StringName, title: String) -> void:
	var row := _make_row(parent, key, title)
	var toggle := Button.new()
	toggle.text = "TOGGLE"
	toggle.pressed.connect(_on_toggle_pressed.bind(key))
	row.add_child(toggle)


func _add_action_row(parent: VBoxContainer, title: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = "Row_" + title.replace(" ", "_")
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	row.add_child(button)


func _make_row(parent: VBoxContainer, key: StringName, title: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + String(key)
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(VALUE_LABEL_WIDTH, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_value_labels[key] = value_label
	return row


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
