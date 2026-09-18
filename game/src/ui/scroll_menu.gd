## Semi-transparent list menu: the wheel (or arrows) moves the highlight, a wheel click (or Enter) selects.
## Works with the mouse captured (diegetic panels) and with a visible cursor (settings overlay).
class_name ScrollMenu
extends PanelContainer

signal option_selected(index: int)
signal option_highlighted(index: int)

const HINT_TEXT: String = "WHEEL: BROWSE    WHEEL CLICK: SELECT"
const COLOR_HIGHLIGHT: Color = Color(1.0, 0.85, 0.55, 1.0)
const COLOR_NORMAL: Color = Color(0.72, 0.76, 0.7, 1.0)
const COLOR_SELECTED: Color = Color(0.55, 0.78, 0.72, 1.0)
const BASE_TITLE_FONT_SIZE: int = 16
const BASE_HINT_FONT_SIZE: int = 11
const BASE_ROW_FONT_SIZE: int = 14

var _items: PackedStringArray = PackedStringArray()
var _index: int = 0
var _selected: int = -1
var _wrap: bool = true
var _list: VBoxContainer
var _title_label: Label
var _hint_label: Label
var _rows: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(340.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.05, 0.62)
	style.border_color = Color(0.62, 0.5, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_content_margin_all(14.0)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	_title_label = Label.new()
	_title_label.name = "MenuTitle"
	_title_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_TITLE_FONT_SIZE))
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1.0))
	column.add_child(_title_label)
	_list = VBoxContainer.new()
	_list.name = "Options"
	_list.add_theme_constant_override("separation", 2)
	column.add_child(_list)
	_hint_label = Label.new()
	_hint_label.name = "Hint"
	_hint_label.text = HINT_TEXT
	_hint_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_HINT_FONT_SIZE))
	_hint_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.55, 1.0))
	column.add_child(_hint_label)
	visible = false
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)


func setup(title: String, items: PackedStringArray, wrap: bool = true) -> void:
	_title_label.text = title
	_wrap = wrap
	_index = 0
	_selected = -1
	set_items(items)


func set_items(items: PackedStringArray) -> void:
	_items = items
	_index = clampi(_index, 0, maxi(items.size() - 1, 0))
	_rebuild_rows()


func set_hint(text: String) -> void:
	_hint_label.text = text


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func get_items() -> PackedStringArray:
	return _items


func get_highlighted_index() -> int:
	if _items.is_empty():
		return -1
	return _index


func get_selected_index() -> int:
	return _selected


func get_row_font_size() -> int:
	if _rows.is_empty():
		return UiScale.size(self, BASE_ROW_FONT_SIZE)
	return _rows[0].get_theme_font_size(&"font_size")


func get_highlighted_text() -> String:
	if _items.is_empty():
		return ""
	return _items[_index]


func move_selection(delta: int) -> void:
	if _items.is_empty():
		return
	if _wrap:
		_index = wrapi(_index + delta, 0, _items.size())
	else:
		_index = clampi(_index + delta, 0, _items.size() - 1)
	_refresh_rows()
	option_highlighted.emit(_index)


func confirm() -> void:
	if _items.is_empty():
		return
	_selected = _index
	_refresh_rows()
	option_selected.emit(_index)


func _gui_input(event: InputEvent) -> void:
	if not _handle_event(event):
		return
	accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if _handle_event(event):
		get_viewport().set_input_as_handled()


func _handle_event(event: InputEvent) -> bool:
	if not is_open():
		return false
	if event.is_action_pressed(&"menu_next") or event.is_action_pressed(&"ui_down"):
		move_selection(1)
		return true
	if event.is_action_pressed(&"menu_prev") or event.is_action_pressed(&"ui_up"):
		move_selection(-1)
		return true
	if event.is_action_pressed(&"menu_select") or event.is_action_pressed(&"ui_accept"):
		confirm()
		return true
	return false


func _rebuild_rows() -> void:
	for row: Label in _rows:
		row.queue_free()
	_rows.clear()
	for item: String in _items:
		var row := Label.new()
		row.name = "Option%d" % _rows.size()
		row.add_theme_font_size_override("font_size", UiScale.size(self, BASE_ROW_FONT_SIZE))
		_list.add_child(row)
		_rows.append(row)
	_refresh_rows()


func _refresh_rows() -> void:
	for i: int in _rows.size():
		var row: Label = _rows[i]
		var prefix: String = "> " if i == _index else "  "
		var marker: String = "* " if i == _selected else ""
		row.text = "%s%s%s" % [prefix, marker, _items[i]]
		if i == _selected:
			row.add_theme_color_override("font_color", COLOR_SELECTED)
		elif i == _index:
			row.add_theme_color_override("font_color", COLOR_HIGHLIGHT)
		else:
			row.add_theme_color_override("font_color", COLOR_NORMAL)


func _apply_ui_scale() -> void:
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_TITLE_FONT_SIZE))
	if _hint_label != null:
		_hint_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_HINT_FONT_SIZE))
	for row: Label in _rows:
		if row != null:
			row.add_theme_font_size_override("font_size", UiScale.size(self, BASE_ROW_FONT_SIZE))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()
