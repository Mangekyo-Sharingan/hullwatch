## Wall-mounted verification panel. Opens a diegetic readout assembled from the live simulators; holds no state.
class_name StatusPanel
extends Interactable

const REFRESH_SECONDS: float = 0.25

@export var compartment_id: StringName = &"main"

var _open: bool = false
var _ui: CanvasLayer
var _label: Label
var _refresh_accumulator: float = 0.0


func get_interaction_prompt() -> String:
	return "Close panel" if _open else "Read panel"


func _process(delta: float) -> void:
	if not _open:
		return
	_refresh_accumulator += delta
	if _refresh_accumulator >= REFRESH_SECONDS:
		_refresh_accumulator = 0.0
		_refresh()


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
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		lines.append("DAY %d  %02d:00" % [int(sim_clock.call("get_day")), int(sim_clock.call("get_hour"))])
	else:
		lines.append("CLOCK OFFLINE")
	lines.append("")
	lines.append_array(_power_lines())
	lines.append("")
	lines.append_array(_atmosphere_lines())
	var components: PackedStringArray = _components_lines()
	if not components.is_empty():
		lines.append("")
		lines.append_array(components)
	lines.append("")
	lines.append_array(_stores_lines())
	return lines


func _components_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var entries: PackedStringArray = PackedStringArray()
	for group_name: StringName in [&"power_system", &"atmosphere_system"]:
		var system: Node = _get_system(group_name)
		if system == null or not system.has_method(&"get_wear_status"):
			continue
		var wear: Dictionary = system.call("get_wear_status")
		var component_ids: Array = wear.keys()
		component_ids.sort()
		for key: Variant in component_ids:
			var component_id: StringName = key
			var status: Dictionary = wear[component_id]
			var state: String = "OK"
			if bool(status["failed"]):
				state = "FAIL %s" % String(status["failed_mode"]).to_upper()
			entries.append("%-16s %3d%% %s" % [String(component_id).to_upper(), int(roundf(float(status["condition"]) * 100.0)), state])
	if not entries.is_empty():
		lines.append("COMPONENTS")
		for entry: String in entries:
			lines.append("  " + entry)
	return lines


func _power_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var power: Node = _get_system(&"power_system")
	if power == null:
		lines.append("POWER -- OFFLINE")
		return lines
	var status: Dictionary = power.call("get_status")
	var battery_pct: int = int(roundf(float(status["battery_fraction"]) * 100.0))
	var bus_state: String = "BROWNOUT" if bool(status["brownout"]) else "OK"
	lines.append("POWER  BATTERY %d%%  BUS %s" % [battery_pct, bus_state])
	var circuits: Dictionary = status["circuits"]
	var circuit_ids: Array = circuits.keys()
	circuit_ids.sort()
	for key: Variant in circuit_ids:
		var circuit_id: StringName = key
		var circuit: Dictionary = circuits[circuit_id]
		var state: String = "ON"
		if not bool(circuit["breaker_on"]):
			state = "OFF"
		elif bool(circuit["shed"]):
			state = "SHED"
		lines.append("  %-11s %s" % [String(circuit_id).to_upper(), state])
	return lines


func _atmosphere_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var atmosphere: Node = _get_system(&"atmosphere_system")
	if atmosphere == null or not bool(atmosphere.call("has_compartment", compartment_id)):
		lines.append("ATMOSPHERE -- OFFLINE")
		return lines
	var status: Dictionary = atmosphere.call("get_compartment_status", compartment_id)
	lines.append("ATMOSPHERE  %s" % String(compartment_id).to_upper())
	lines.append("  O2 %5.1f%%   CO2 %6.0f PPM" % [float(status["o2_fraction"]) * 100.0, float(status["co2_ppm"])])
	lines.append("  PRESSURE %6.1f KPA  LEAK %.3f/H" % [float(status["pressure_kpa"]), float(status["leak_rate_per_hour"])])
	var scrubber: String = "ON" if bool(status["scrubber_powered"]) else "OFF"
	var filter_text: String = "MISSING"
	if bool(status["filter_installed"]):
		filter_text = "%d%%" % int(roundf(float(status["filter_condition"]) * 100.0))
	lines.append("  SCRUBBER %s  FILTER %s" % [scrubber, filter_text])
	return lines


func _stores_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var stores: Node = _get_system(&"stores_system")
	if stores == null:
		lines.append("STORES -- OFFLINE")
		return lines
	var status: Dictionary = stores.call("get_status")
	var parts: Dictionary = status["parts"]
	var part_ids: Array = parts.keys()
	part_ids.sort()
	var entries: PackedStringArray = PackedStringArray()
	for key: Variant in part_ids:
		var part_id: StringName = key
		entries.append("%s x%d" % [String(part_id).to_upper(), int(parts[part_id])])
	lines.append("STORES  " + "  ".join(entries))
	return lines


func _refresh() -> void:
	if _label != null:
		_label.text = "\n".join(build_readout())


func _ensure_ui() -> void:
	if _ui != null:
		return
	var layer := CanvasLayer.new()
	layer.name = "Readout"
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.05, 0.92)
	style.border_color = Color(0.25, 0.38, 0.4, 1.0)
	style.set_border_width_all(2)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.55, 0.78, 0.72, 1.0))
	panel.add_child(_label)
	layer.visible = false
	_ui = layer
