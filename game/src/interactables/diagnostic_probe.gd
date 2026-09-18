## Wall test point for diagnostic tools: a multimeter pinpoints fault modes, a scanner logs wear.
## Without the right tool the probe refuses — faults stay symptoms until investigated.
class_name DiagnosticProbe
extends Interactable

@export var system_group: StringName = &"power_system"
@export var multimeter_item_id: StringName = &"multimeter"
@export var scanner_item_id: StringName = &"scanner"


func get_interaction_prompt() -> String:
	return "Probe %s" % _system_group_label()


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
