## Wall-mounted maintenance board: accumulates watch events so the ship's attrition is readable at a glance.
class_name MaintenanceBoard
extends Interactable

const MAX_ENTRIES: int = 24
const BASE_FONT_SIZE: int = 14
const WATCHED: Array[StringName] = [
	&"component_failed",
	&"component_repaired",
	&"stores_low",
	&"procedure_error",
	&"hull_puncture",
	&"hull_patched",
	&"circuit_shed",
	&"circuit_restored",
	&"compartment_freeze_risk",
	&"operator_incapacitated",
	&"mercy_recovery_used",
]

var _entries: Array[Dictionary] = []
var _open: bool = false
var _ui: CanvasLayer
var _label: Label


func _ready() -> void:
	_apply_ui_scale()
	UiScale.connect_settings(self, _on_ui_scale_changed)
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)


func get_interaction_prompt() -> String:
	return "Close board" if _open else "Read board"


func _handle_interact(_player: Node) -> void:
	_open = not _open
	_ensure_ui()
	if _ui != null:
		_ui.visible = _open
	if _open:
		_refresh()


func is_open() -> bool:
	return _open


func get_entries() -> Array[Dictionary]:
	return _entries.duplicate(true)


func build_readout() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("MAINTENANCE BOARD")
	lines.append("")
	if _entries.is_empty():
		lines.append("NO ENTRIES")
		return lines
	for entry: Dictionary in _entries:
		lines.append("DAY %d  %s  %s" % [int(entry["day"]), String(entry["name"]).to_upper(), String(entry["payload"])])
	return lines


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if not WATCHED.has(event_name):
		return
	_entries.push_front({"name": event_name, "payload": _format_payload(payload), "day": _current_day()})
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	if _open:
		_refresh()


func _format_payload(payload: Dictionary) -> String:
	if payload.is_empty():
		return ""
	var keys: Array = payload.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in keys:
		parts.append("%s=%s" % [String(key), str(payload[key])])
	return " ".join(parts)


func _current_day() -> int:
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock == null:
		return 0
	return int(sim_clock.call("get_day"))


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
	layer.name = "BoardEntries"
	layer.layer = 11
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.06, 0.95)
	style.border_color = Color(0.55, 0.42, 0.2, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", UiScale.size(self, BASE_FONT_SIZE))
	_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6, 1.0))
	panel.add_child(_label)
	layer.visible = false
	_ui = layer
