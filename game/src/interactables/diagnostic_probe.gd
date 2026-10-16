## Wall test point for diagnostic tools: a multimeter pinpoints fault modes, a scanner logs wear.
## Without the right tool the probe refuses — faults stay symptoms until investigated.
class_name DiagnosticProbe
extends Interactable

@export var system_group: StringName = &"power_system"
@export var multimeter_item_id: StringName = &"multimeter"
@export var scanner_item_id: StringName = &"scanner"

var _carried_id: StringName = &""
var _operator: Node
var _menu: ScrollMenu
var _actions: Array[Dictionary] = []


func _ready() -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)


func get_interaction_prompt() -> String:
	var base: String = "Probe %s" % _system_group_label()
	if _carried_id == multimeter_item_id:
		return "%s  [MULTIMETER]" % base
	if _carried_id == scanner_item_id:
		return "%s  [SCANNER]" % base
	if _carried_id == &"wrench":
		return "Service %s [WRENCH]" % _system_group_label()
	return "%s  [NEEDS TOOL]" % base


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"item_taken":
		_carried_id = StringName(payload.get("item_id", &""))
	elif event_name == &"item_dropped" and _carried_id == StringName(payload.get("item_id", &"")):
		_carried_id = &""


func _handle_interact(player: Node) -> void:
	var system: Node = _get_system(system_group)
	if system == null:
		return
	var carried: StringName = _carried_item_id(player)
	if carried == &"wrench":
		_operator = player
		open()
		return
	if carried == multimeter_item_id:
		_diagnose(system)
		return
	if carried == scanner_item_id:
		system.call("scan_system")
		_emit_sim_event(&"probe_scanned", {"system": system_group})
		return
	_emit_sim_event(&"procedure_error", {"reason": &"no_tool", "system": system_group})


func _diagnose(system: Node) -> void:
	var failures: Array = system.call("get_undiagnosed_failures")
	if failures.is_empty():
		_emit_sim_event(&"diagnosis_clear", {"system": system_group})
		return
	var component_id: StringName = failures[0]
	var mode: StringName = StringName(system.call("diagnose_component", component_id))
	_emit_sim_event(&"probe_diagnosis", {"system": system_group, "component_id": component_id, "failure_mode_id": mode})


func _carried_item_id(player: Node) -> StringName:
	if player == null or not player.has_method(&"get_carried_item_id"):
		return &""
	return StringName(player.call("get_carried_item_id"))


func _system_group_label() -> String:
	return String(system_group).trim_suffix("_system").to_upper()


func _unhandled_input(event: InputEvent) -> void:
	if PanelDismiss.should_dismiss(event, is_open()):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _menu == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 12
		add_child(layer)
		var center: CenterContainer = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(center)
		_menu = ScrollMenu.new()
		center.add_child(_menu)
		_menu.setup("EXTERNAL HARDWARE — " + _system_group_label(), PackedStringArray())
		_menu.option_selected.connect(select_action)
	_refresh_service()
	_menu.open()


func close() -> void:
	if _menu != null:
		_menu.close()


func is_open() -> bool:
	return _menu != null and _menu.is_open()


func get_actions() -> PackedStringArray:
	_actions.clear()
	var labels: PackedStringArray = PackedStringArray()
	var system: Node = _get_system(system_group)
	if system == null or not system.has_method(&"get_maintenance_status"):
		return labels
	var wear: Dictionary = system.call("get_wear_status")
	for component_id: String in wear:
		var condition: Dictionary = wear[component_id]
		var status: Dictionary = system.call("get_maintenance_status", StringName(component_id))
		if status.is_empty():
			continue
		var name_text: String = component_id.replace("_", " ").to_upper()
		var action: StringName = &""
		var label: String = ""
		if not bool(status["housing_open"]):
			if bool(status["isolated"]):
				action = &"open"
				label = "OPEN %s COVER" % name_text
			else:
				label = "%s: SWITCH OFF %s" % [name_text, String(status["circuit"]).replace("_", " ").to_upper()]
		else:
			var known: bool = bool(condition["diagnosed"]) if bool(condition["failed"]) else bool(condition["scanned"])
			if known and (bool(condition["failed"]) or float(condition["condition"]) < 1.0):
				_actions.append({"component": component_id, "action": &"repair"})
				labels.append("REFIT %s — 1 %s / %.0f MIN" % [name_text, String(status["part"]).to_upper(), float(status["hours"]) * 60.0])
			else:
				_actions.append({})
				labels.append("%s: %s" % [name_text, "TRACE / SCAN FIRST" if not known else "NO REFIT REQUIRED"])
			action = &"close"
			label = "CLOSE %s COVER" % name_text
		_actions.append({"component": component_id, "action": action})
		labels.append(label)
	_actions.append({"action": &"dismiss"})
	labels.append(InputHints.expand("DISMISS ({close_spaced})"))
	return labels


func select_action(index: int) -> bool:
	if index < 0 or index >= _actions.size():
		return false
	var selected: Dictionary = _actions[index]
	var action: StringName = StringName(selected.get("action", &""))
	if action == &"dismiss":
		close()
		return true
	var system: Node = _get_system(system_group)
	var success: bool = system != null and action != &"" and bool(system.call("maintenance_action", StringName(selected.get("component", &"")), action, _carried_item_id(_operator)))
	if not success:
		_emit_sim_event(&"procedure_error", {"reason": &"check_tool_isolation_parts", "system": system_group})
	_refresh_service()
	return success


func _refresh_service() -> void:
	if _menu != null:
		_menu.set_items(get_actions())
