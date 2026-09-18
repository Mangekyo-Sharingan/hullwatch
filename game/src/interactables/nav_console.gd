## Bridge console between the operator and NavSystem: plot a course to its waypoint, then begin the burn.
class_name NavConsole
extends Interactable

@export var waypoint_id: StringName = &"relay_cache"


func get_interaction_prompt() -> String:
	var nav: Node = _get_system(&"nav_system")
	if nav == null:
		return display_name
	var status: Dictionary = nav.call("get_status")
	if StringName(status.get("plotted_waypoint", &"")) != &"":
		return "Begin burn"
	if StringName(status.get("current_waypoint", &"")) == waypoint_id:
		return "Course complete"
	return "Plot course"


func _handle_interact(_player: Node) -> void:
	var nav: Node = _get_system(&"nav_system")
	if nav == null:
		return
	var status: Dictionary = nav.call("get_status")
	var burn_fuel: float = float(nav.get("burn_fuel_kg"))
	if StringName(status.get("plotted_waypoint", &"")) != &"":
		if float(status.get("fuel_mass_kg", 0.0)) < burn_fuel:
			_emit_sim_event(&"procedure_error", {"reason": &"no_fuel"})
			return
		nav.call("begin_burn")
		return
	if StringName(status.get("current_waypoint", &"")) == waypoint_id:
		return
	if _is_waypoint_reached(nav, status):
		return
	if float(status.get("fuel_mass_kg", 0.0)) < burn_fuel:
		_emit_sim_event(&"procedure_error", {"reason": &"no_fuel"})
		return
	nav.call("plot_course", waypoint_id)


func save_state() -> Dictionary:
	var state: Dictionary = super.save_state()
	state["system_id"] = "nav_console"
	state["state_version"] = 1
	return state


func load_state(state: Dictionary) -> void:
	super.load_state(state)


func _is_waypoint_reached(nav: Node, status: Dictionary) -> bool:
	var waypoints: Array = nav.get("waypoints")
	var index: int = waypoints.find(waypoint_id)
	return index >= 0 and index < int(status.get("current_leg", 0))
