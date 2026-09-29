## Renders the low-thrust ion wake from real navigation state; it owns no drive state.
class_name IonDriveFx
extends Node3D

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


func _on_sim_event(event_name: StringName, _payload: Dictionary) -> void:
	if event_name == &"transit_started":
		_set_burning(true)
	elif event_name in [&"destination_arrived", &"transit_fuel_exhausted"]:
		_set_burning(false)


func _on_navigation_state_restored(in_transit: bool) -> void:
	_set_burning(in_transit)


func _sync_with_nav() -> void:
	var nav: Node = get_tree().get_first_node_in_group(&"nav_system")
	if nav != null and nav.has_method(&"get_status"):
		var status: Dictionary = nav.call("get_status")
		_set_burning(bool(status.get("transit_active", false)))


func _set_burning(burning: bool) -> void:
	for plume: MeshInstance3D in _plumes:
		plume.visible = burning
