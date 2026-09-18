## Wall test point for diagnostic tools: a multimeter pinpoints fault modes, a scanner logs wear.
## Without the right tool the probe refuses — faults stay symptoms until investigated.
class_name DiagnosticProbe
extends Interactable

@export var system_group: StringName = &"power_system"
@export var multimeter_item_id: StringName = &"multimeter"
@export var scanner_item_id: StringName = &"scanner"

var _carried_id: StringName = &""


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
