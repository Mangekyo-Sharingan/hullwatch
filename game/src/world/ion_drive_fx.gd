## Renders the low-thrust ion wake from real navigation state; it owns no drive state.
class_name IonDriveFx
extends Node3D

@export var cassette_id: StringName = &"port"

var _plumes: Array[MeshInstance3D] = []


func _ready() -> void:
	for candidate: Node in find_children("IonPlume", "MeshInstance3D", true, false):
		_plumes.append(candidate as MeshInstance3D)
	_set_burning(false)
	var event_bus: Node = get_node_or_null(^"/root/EventBus")
	if event_bus != null and event_bus.has_signal(&"sim_event"):
		var callback: Callable = Callable(self, "_on_sim_event")
		if not event_bus.is_connected(&"sim_event", callback):
			event_bus.connect(&"sim_event", callback)
		var restore_callback: Callable = Callable(self, "_on_navigation_state_restored")
		if event_bus.has_signal(&"navigation_state_restored") and not event_bus.is_connected(&"navigation_state_restored", restore_callback):
			event_bus.connect(&"navigation_state_restored", restore_callback)
	call_deferred("_sync_with_nav")


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if event_name == &"drive_state_changed":
		_set_burning(bool((payload.get("cassette_firing", {}) as Dictionary).get(String(cassette_id), false)))
	elif event_name in [&"transit_started", &"destination_arrived", &"transit_fuel_exhausted"]:
		_sync_with_nav()


func _on_navigation_state_restored(_in_transit: bool) -> void:
	_sync_with_nav()


func _sync_with_nav() -> void:
	var nav: Node = get_tree().get_first_node_in_group(&"nav_system")
	if nav != null and nav.has_method(&"get_status"):
		var status: Dictionary = nav.call("get_status")
		_set_burning(bool((status.get("cassette_firing", {}) as Dictionary).get(String(cassette_id), false)))


func _set_burning(burning: bool) -> void:
	for plume: MeshInstance3D in _plumes:
		plume.visible = burning
