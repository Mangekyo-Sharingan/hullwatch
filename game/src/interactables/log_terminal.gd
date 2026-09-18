## Console terminal that displays one archived operator log entry.
class_name LogTerminal
extends Interactable

const BASE_FONT_SIZE: int = 14

@export var log_entry: LogEntry

var _open: bool = false
var _ui: CanvasLayer
var _label: Label


func _ready() -> void:
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)


func get_interaction_prompt() -> String:
	return "Close log" if _open else "Read log"


func _handle_interact(_player: Node) -> void:
	_open = not _open
	_ensure_ui()
	if _ui != null:
		_ui.visible = _open
	if _open:
		_refresh()


func is_open() -> bool:
	return _open


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if log_entry == null:
		return lines
	lines.append(log_entry.date_text)
	lines.append(log_entry.title)
	lines.append("")
	for body_line: String in log_entry.body.split("\n"):
		lines.append(body_line)
	return lines


func _refresh() -> void:
	if _label != null:
		_label.text = "\n".join(build_readout())


func _apply_ui_scale() -> void:
	if _label != null:
		_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()


func _ensure_ui() -> void:
	if _ui != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "LogView"
	layer.layer = 13
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.05, 0.03, 0.96)
	style.border_color = Color(0.2, 0.5, 0.35, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(20.0)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	_label.add_theme_color_override("font_color", Color(0.45, 0.85, 0.55, 1.0))
	panel.add_child(_label)
	layer.visible = false
	_ui = layer
