## Cabin fixture powered by the ship's lighting circuit.
extends OmniLight3D

const CIRCUIT_ID: StringName = &"lighting"

var _event_bus: Node


func _ready() -> void:
	_event_bus = get_node_or_null("/root/EventBus")
	if _event_bus != null:
		_event_bus.connect(&"sim_event", _on_sim_event)
	call_deferred(&"_sync_power")


func _exit_tree() -> void:
	if _event_bus != null and _event_bus.is_connected(&"sim_event", _on_sim_event):
		_event_bus.disconnect(&"sim_event", _on_sim_event)


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"power_state_restored":
		_sync_power()
		return
	if event_name not in [&"breaker_toggled", &"circuit_shed", &"circuit_restored"]:
		return
	if StringName(payload.get("circuit_id", &"")) != CIRCUIT_ID:
		return
	_sync_power()


func _sync_power() -> void:
	var power: Node = get_tree().get_first_node_in_group(&"power_system")
	visible = power != null and bool(power.call(&"is_breaker_on", CIRCUIT_ID)) and not bool(power.call(&"is_circuit_shed", CIRCUIT_ID))
