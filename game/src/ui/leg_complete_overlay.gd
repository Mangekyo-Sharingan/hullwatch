## Calm leg-completion overlay. Shows when the nav system reports the final waypoint reached.
extends CanvasLayer

const BASE_FONT_SIZE: int = 30

var _fade: ColorRect
var _label: Label
var _visible: bool = false
var _text: String = ""


func _ready() -> void:
	layer = 18
	_build_ui()
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)
	var event_bus: Node = get_node_or_null(^"/root/EventBus")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)


func _unhandled_input(event: InputEvent) -> void:
	if not _visible:
		return
	if event.is_action_pressed(&"interact"):
		dismiss()


func is_visible_overlay() -> bool:
	return _visible


func get_overlay_text() -> String:
	return _text


func _show_overlay(waypoint_id: StringName) -> void:
	_text = "LEG COMPLETE\n%s\n\nPRESS E TO CONTINUE" % String(waypoint_id).to_upper()
	_label.text = _text
	_fade.modulate.a = 1.0
	_visible = true


func dismiss() -> void:
	_visible = false
	_fade.modulate.a = 0.0
	var event_bus: Node = get_node_or_null(^"/root/EventBus")
	if event_bus != null:
		event_bus.call("emit_event", &"leg_acknowledged", {})
		event_bus.emit_signal(&"sim_event", &"leg_acknowledged", {})


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"leg_completed":
		_show_overlay(StringName(payload.get("waypoint_id", &"")))


func _build_ui() -> void:
	_fade = ColorRect.new()
	_fade.name = "LegFade"
	_fade.color = Color(0.01, 0.015, 0.02, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	_label = Label.new()
	_label.name = "LegText"
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	_label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.72, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _apply_ui_scale() -> void:
	if _label != null:
		_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()
