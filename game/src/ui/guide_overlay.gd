## CRT-styled HUD overlay for the vocal guide.
## Displays the active orientation objective, transmission status, and synthesized voice transcripts.
class_name GuideOverlay
extends CanvasLayer

const BASE_HEADER_SIZE: int = 13
const BASE_OBJECTIVE_SIZE: int = 15
const BASE_BODY_SIZE: int = 14

const COLOR_AMBER: Color = Color(1.0, 0.78, 0.35, 1.0)
const COLOR_GREEN: Color = Color(0.45, 1.0, 0.55, 1.0)
const COLOR_TEXT: Color = Color(0.9, 0.92, 0.88, 1.0)
const COLOR_BG: Color = Color(0.04, 0.06, 0.05, 0.82)
const COLOR_BORDER: Color = Color(0.25, 0.45, 0.35, 0.8)

var _panel: PanelContainer
var _header_label: Label
var _indicator_label: Label
var _objective_label: Label
var _transcript_label: Label

var _blink_accumulator: float = 0.0
var _is_transmitting: bool = false
var _fade_timer: float = 0.0
var _fading_out: bool = false


func _ready() -> void:
	layer = 15
	_build_ui()
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)

	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)

	visible = false


func _process(delta: float) -> void:
	if not visible:
		return

	if _is_transmitting:
		_blink_accumulator += delta
		var alpha: float = 0.5 + 0.5 * sin(_blink_accumulator * 8.0)
		_indicator_label.modulate.a = alpha
	else:
		_indicator_label.modulate.a = 1.0

	if _fading_out:
		_fade_timer -= delta
		if _fade_timer <= 0.0:
			_fading_out = false
			visible = false
		else:
			_panel.modulate.a = clampf(_fade_timer / 1.5, 0.0, 1.0)


func get_objective_text() -> String:
	return _objective_label.text if _objective_label != null else ""


func get_transcript_text() -> String:
	return _transcript_label.text if _transcript_label != null else ""


func is_overlay_visible() -> bool:
	return visible


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "GuidePanel"
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -460.0
	_panel.offset_top = 24.0
	_panel.offset_right = -24.0
	_panel.offset_bottom = 190.0

	var style_box := StyleBoxFlat.new()
	style_box.bg_color = COLOR_BG
	style_box.border_color = COLOR_BORDER
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(3)
	style_box.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style_box)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 6)
	_panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	vbox.add_child(top_row)

	_header_label = Label.new()
	_header_label.name = "Header"
	_header_label.text = "[ VOCAL ADVISORY // ORIENTATION ]"
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_label.add_theme_color_override("font_color", COLOR_AMBER)
	_header_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_header_label.add_theme_constant_override("outline_size", 2)
	top_row.add_child(_header_label)

	_indicator_label = Label.new()
	_indicator_label.name = "Indicator"
	_indicator_label.text = "● AUDIO COMM"
	_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_indicator_label.add_theme_color_override("font_color", COLOR_AMBER)
	_indicator_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_indicator_label.add_theme_constant_override("outline_size", 2)
	top_row.add_child(_indicator_label)

	_objective_label = Label.new()
	_objective_label.name = "Objective"
	_objective_label.text = "▶ OBJECTIVE: STANDBY"
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.add_theme_color_override("font_color", COLOR_GREEN)
	_objective_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_objective_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_objective_label)

	_transcript_label = Label.new()
	_transcript_label.name = "Transcript"
	_transcript_label.text = ""
	_transcript_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transcript_label.add_theme_color_override("font_color", COLOR_TEXT)
	_transcript_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_transcript_label.add_theme_constant_override("outline_size", 2)
	vbox.add_child(_transcript_label)


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	match event_name:
		&"voice_guide_spoken":
			_handle_spoken(payload)
		&"voice_guide_step_completed":
			_handle_step_completed(payload)
		&"voice_guide_completed":
			_handle_completed(payload)


func _handle_spoken(payload: Dictionary) -> void:
	visible = true
	_panel.modulate.a = 1.0
	_fading_out = false

	var title: String = String(payload.get("title", ""))
	var objective: String = String(payload.get("objective", ""))
	var text: String = String(payload.get("text", ""))
	var is_conclusion: bool = bool(payload.get("is_conclusion", false))

	if not title.is_empty():
		_header_label.text = "[ %s ]" % title
	if not objective.is_empty():
		_objective_label.text = "▶ %s" % objective
	_transcript_label.text = "\"%s\"" % text

	_is_transmitting = true
	_blink_accumulator = 0.0
	_indicator_label.text = "● AUDIO COMM"
	_indicator_label.add_theme_color_override("font_color", COLOR_AMBER)

	var speak_duration: float = float(payload.get("duration", 0.0))
	if speak_duration <= 0.0:
		speak_duration = maxf(float(text.length()) * 0.065, 2.5)
	get_tree().create_timer(speak_duration).timeout.connect(func() -> void:
		_is_transmitting = false
		if is_instance_valid(_indicator_label):
			_indicator_label.text = "STANDBY"
			_indicator_label.modulate.a = 0.7
	)

	if is_conclusion:
		_fading_out = true
		_fade_timer = speak_duration + 4.0


func _handle_step_completed(_payload: Dictionary) -> void:
	_indicator_label.text = "✔ COMPLETED"
	_indicator_label.add_theme_color_override("font_color", COLOR_GREEN)
	_indicator_label.modulate.a = 1.0
	_is_transmitting = false


func _handle_completed(_payload: Dictionary) -> void:
	_header_label.text = "[ ORIENTATION PROTOCOL FINISHED ]"
	_indicator_label.text = "OFFLINE"
	_indicator_label.add_theme_color_override("font_color", COLOR_AMBER)
	_objective_label.text = "ALL SYSTEMS TRANSFERRED TO OPERATOR"
	_fading_out = true
	_fade_timer = 5.0


func _apply_ui_scale() -> void:
	if _header_label != null:
		_header_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_HEADER_SIZE))
	if _indicator_label != null:
		_indicator_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_HEADER_SIZE))
	if _objective_label != null:
		_objective_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_OBJECTIVE_SIZE))
	if _transcript_label != null:
		_transcript_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_BODY_SIZE))


func _on_ui_scale_changed(key: StringName, _value: Variant) -> void:
	if key == &"ui_scale":
		_apply_ui_scale()


func _get_autoload(autoload_name: StringName) -> Node:
	if is_inside_tree():
		return get_node_or_null(NodePath("/root/" + String(autoload_name)))
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var scene_root: Window = (main_loop as SceneTree).root
		if scene_root != null:
			for child: Node in scene_root.get_children():
				if child.name == autoload_name:
					return child
	return null
