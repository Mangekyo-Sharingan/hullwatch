## Sleep transition: fades to black, advances the sim clock, holds a day summary, fades back in.
class_name SleepTransition
extends CanvasLayer

@export var fade_out_seconds: float = 0.6
@export var fade_in_seconds: float = 0.8
@export var summary_hold_seconds: float = 4.0

var _fade: ColorRect
var _label: Label
var _summary: String = ""


func _ready() -> void:
	add_to_group(&"sleep_transition")
	layer = 20
	_build_ui()


func run_sleep(hours: float) -> void:
	await _fade_to(1.0, fade_out_seconds)
	var before: Dictionary = _watch_readings()
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		sim_clock.call("fast_forward", hours)
	_summary = _format_summary(hours, sim_clock, before, _watch_readings())
	_label.text = _summary
	_label.modulate.a = 1.0
	await _wait(summary_hold_seconds)
	await _fade_to(0.0, fade_in_seconds)
	_label.modulate.a = 0.0


func get_summary_text() -> String:
	return _summary


func _format_summary(hours: float, sim_clock: Node, before: Dictionary, after: Dictionary) -> String:
	if sim_clock == null:
		return "SLEPT %s" % _format_hours(hours)
	var lines: PackedStringArray = [
		"OVERNIGHT WATCH  //  DAY %d  %02d:00" % [int(sim_clock.call("get_day")), int(sim_clock.call("get_hour"))],
		"SLEPT %s" % _format_hours(hours),
	]
	if before.has("battery_fraction") and after.has("battery_fraction"):
		lines.append("BATTERY  %.0f%% TO %.0f%%" % [
			float(before["battery_fraction"]) * 100.0,
			float(after["battery_fraction"]) * 100.0,
		])
	if before.has("pressure_kpa") and after.has("pressure_kpa"):
		lines.append("QUARTERS PRESSURE  %.1f TO %.1f KPA" % [
			float(before["pressure_kpa"]), float(after["pressure_kpa"]),
		])
	if before.has("co2_ppm") and after.has("co2_ppm"):
		lines.append("QUARTERS CO2  %.0f TO %.0f PPM" % [
			float(before["co2_ppm"]), float(after["co2_ppm"]),
		])
	if lines.size() > 2:
		lines.append("CHECK STATUS PANEL / MAINTENANCE BOARD")
	return "\n".join(lines)


func _watch_readings() -> Dictionary:
	var readings: Dictionary = {}
	var power: Node = get_tree().get_first_node_in_group(&"power_system")
	if power != null and power.has_method(&"get_status"):
		var power_status: Dictionary = power.call("get_status")
		if power_status.has("battery_fraction"):
			readings["battery_fraction"] = power_status["battery_fraction"]
	var atmosphere: Node = get_tree().get_first_node_in_group(&"atmosphere_system")
	if atmosphere != null and bool(atmosphere.call("has_compartment", &"quarters")):
		var air_status: Dictionary = atmosphere.call("get_compartment_status", &"quarters")
		for key: String in ["pressure_kpa", "co2_ppm"]:
			if air_status.has(key):
				readings[key] = air_status[key]
	return readings


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
