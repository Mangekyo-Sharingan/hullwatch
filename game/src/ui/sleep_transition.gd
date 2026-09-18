## Sleep transition: fades to black, advances the sim clock, holds a day summary, fades back in.
class_name SleepTransition
extends CanvasLayer

@export var fade_out_seconds: float = 0.6
@export var fade_in_seconds: float = 0.8
@export var summary_hold_seconds: float = 2.5

var _fade: ColorRect
var _label: Label
var _summary: String = ""


func _ready() -> void:
	add_to_group(&"sleep_transition")
	layer = 20
	_build_ui()


func run_sleep(hours: float) -> void:
	await _fade_to(1.0, fade_out_seconds)
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		sim_clock.call("fast_forward", hours)
	_summary = _format_summary(hours, sim_clock)
	_label.text = _summary
	_label.modulate.a = 1.0
	await _wait(summary_hold_seconds)
	await _fade_to(0.0, fade_in_seconds)
	_label.modulate.a = 0.0


func get_summary_text() -> String:
	return _summary


func _format_summary(hours: float, sim_clock: Node) -> String:
	if sim_clock == null:
		return "SLEPT %s" % _format_hours(hours)
	return "DAY %d  %02d:00\nSLEPT %s" % [
		int(sim_clock.call("get_day")),
		int(sim_clock.call("get_hour")),
		_format_hours(hours),
	]


func _format_hours(hours: float) -> String:
	var rounded: float = roundf(hours)
	if absf(hours - rounded) < 0.05:
		return "%d HOURS" % int(rounded)
	return "%.1f HOURS" % hours


func _fade_to(alpha: float, seconds: float) -> void:
	if seconds <= 0.0:
		_fade.modulate.a = alpha
		return
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "modulate:a", alpha, seconds)
	await tween.finished


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


func _build_ui() -> void:
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)
	_label = Label.new()
	_label.name = "Summary"
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_color", Color(0.55, 0.78, 0.72, 1.0))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.0
	add_child(_label)


## Root children fallback exists because --script SceneTree tests run before the root is in the active tree.
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
