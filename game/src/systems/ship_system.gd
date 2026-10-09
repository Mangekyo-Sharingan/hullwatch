## Base class for every ship simulator. Subclasses override sim_tick() for fixed-tick logic.
## Autoloads are resolved by node path and null-checked so headless script tests run without them.
class_name ShipSystem
extends Node

var system_id: StringName = &""
var maintenance_covers: Dictionary = {}


func _ready() -> void:
	add_to_group(&"ship_system")
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null and not sim_clock.is_connected(&"ticked", _on_ticked):
		sim_clock.connect(&"ticked", _on_ticked)


func sim_tick(_delta_hours: float) -> void:
	pass


func get_status() -> Dictionary:
	return {}


func emit_sim_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.call("emit_event", event_name, payload)


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


func _on_ticked(delta_hours: float, _tick_index: int) -> void:
	sim_tick(delta_hours)


func _maintenance_component(component_id: StringName) -> WearComponent:
	if not has_method(&"get_wear_status") or not has_method(&"repair_component"):
		return null
	var components: Array = get("wear_components")
	for component: WearComponent in components:
		if component != null and component.component_id == component_id:
			return component
	return null


func get_maintenance_status(component_id: StringName) -> Dictionary:
	var component: WearComponent = _maintenance_component(component_id)
	if component == null:
		return {}
	var isolated: bool = true
	var power: Node = get_tree().get_first_node_in_group(&"power_system")
	if component.service_circuit != &"":
		isolated = false
		if power != null:
			if component.service_circuit == &"all_bus":
				isolated = true
				var circuits: Dictionary = power.call("get_status").get("circuits", {})
				for circuit: Dictionary in circuits.values():
					if bool(circuit.get("breaker_on", true)):
						isolated = false
			elif bool(power.call("has_circuit", component.service_circuit)):
				isolated = not bool(power.call("is_breaker_on", component.service_circuit))
	return {"housing_open": bool(maintenance_covers.get(String(component_id), false)), "isolated": isolated, "circuit": String(component.service_circuit), "part": String(component.service_part), "hours": component.service_hours}


func maintenance_action(component_id: StringName, action: StringName, tool: StringName) -> bool:
	var component: WearComponent = _maintenance_component(component_id)
	if component == null or tool != &"wrench":
		return false
	var status: Dictionary = get_maintenance_status(component_id)
	var opened: bool = bool(status["housing_open"])
	if action == &"close" and opened:
		maintenance_covers.erase(String(component_id))
	elif action == &"open" and not opened and bool(status["isolated"]):
		maintenance_covers[String(component_id)] = true
	elif action == &"repair" and opened and bool(status["isolated"]):
		if (component.is_failed() and not component.diagnosed) or (not component.is_failed() and (not component.scanned or component.condition >= 1.0)):
			return false
		var stores: Node = get_tree().get_first_node_in_group(&"stores_system")
		if component.service_part != &"" and (stores == null or not bool(stores.call("consume_part", component.service_part, 1))):
			return false
		if not bool(call("repair_component", component_id, component.service_quality)):
			if stores != null and component.service_part != &"":
				stores.call("add_part", component.service_part, 1)
			return false
		var clock: Node = _get_autoload(&"SimClock")
		if clock != null:
			clock.call("fast_forward", component.service_hours)
	else:
		return false
	emit_sim_event(&"maintenance_action", {"system_id": String(system_id), "component_id": String(component_id), "action": String(action)})
	return true


func restore_maintenance_covers(state: Dictionary) -> void:
	maintenance_covers.clear()
	var saved: Variant = state.get("maintenance_covers", {})
	if not (saved is Dictionary):
		return
	for component_id: Variant in saved:
		if saved[component_id] is bool and bool(saved[component_id]) and _maintenance_component(StringName(component_id)) != null:
			maintenance_covers[String(component_id)] = true
