## Waypoint-to-waypoint travel: plot a course, burn fuel over real sim time, arrive on the next leg.
## Drift risk (spec 4.4): an uncorrected plotted course accumulates error and expires if left too long.
class_name NavSystem
extends ShipSystem

@export var waypoints: Array[StringName] = [&"relay_cache", &"drift_marker", &"leg_end"]
@export var fuel_mass_kg: float = 1200.0
@export var burn_fuel_kg: float = 60.0
@export var burn_hours: float = 1.0
@export var course_error_per_hour: float = 0.01

var current_leg: int = 0
var plotted_waypoint: StringName = &""
var course_error: float = 0.0


func _ready() -> void:
	system_id = &"nav"
	add_to_group(&"nav_system")
	super._ready()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	if plotted_waypoint == &"":
		return
	course_error = clampf(course_error + course_error_per_hour * delta_hours, 0.0, 1.0)
	if course_error >= 1.0 - 1e-9:
		course_error = 1.0
		var expired_waypoint: StringName = plotted_waypoint
		plotted_waypoint = &""
		emit_sim_event(&"course_expired", {"waypoint_id": expired_waypoint, "course_error": course_error})


func plot_course(waypoint_id: StringName) -> bool:
	var index: int = waypoints.find(waypoint_id)
	if index == -1:
		push_error("NavSystem.plot_course: unknown waypoint_id '%s'." % String(waypoint_id))
		return false
	if index < current_leg:
		push_error("NavSystem.plot_course: already at waypoint '%s'." % String(waypoint_id))
		return false
	if fuel_mass_kg < burn_fuel_kg:
		return false
	plotted_waypoint = waypoint_id
	course_error = 0.0
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"course_changed", waypoint_id, burn_fuel_kg)
	emit_sim_event(&"course_plotted", {"waypoint_id": waypoint_id, "delta_v_cost": burn_fuel_kg})
	return true


func begin_burn() -> bool:
	if plotted_waypoint == &"":
		push_error("NavSystem.begin_burn: no course plotted.")
		return false
	if fuel_mass_kg < burn_fuel_kg:
		return false
	var burned_waypoint: StringName = plotted_waypoint
	fuel_mass_kg = maxf(fuel_mass_kg - burn_fuel_kg, 0.0)
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		sim_clock.call("fast_forward", burn_hours)
	current_leg = mini(current_leg + 1, waypoints.size())
	plotted_waypoint = &""
	course_error = 0.0
	emit_sim_event(&"burn_completed", {
		"waypoint_id": burned_waypoint,
		"leg_index": current_leg,
		"fuel_remaining": fuel_mass_kg,
	})
	return true


func get_status() -> Dictionary:
	var arrived: bool = current_leg >= waypoints.size()
	var current_waypoint: StringName = &""
	if current_leg >= 0 and current_leg < waypoints.size():
		current_waypoint = waypoints[current_leg]
	return {
		"system_id": system_id,
		"current_leg": current_leg,
		"current_waypoint": current_waypoint,
		"plotted_waypoint": plotted_waypoint,
		"fuel_mass_kg": fuel_mass_kg,
		"course_error": course_error,
		"arrived": arrived,
	}


func save_state() -> Dictionary:
	return {
		"system_id": "nav",
		"state_version": 1,
		"current_leg": current_leg,
		"plotted_waypoint": String(plotted_waypoint),
		"fuel_mass_kg": fuel_mass_kg,
		"course_error": course_error,
	}


func load_state(state: Dictionary) -> void:
	if state.has("current_leg"):
		current_leg = clampi(int(state["current_leg"]), 0, waypoints.size())
	if state.has("plotted_waypoint"):
		plotted_waypoint = StringName(String(state["plotted_waypoint"]))
	if state.has("fuel_mass_kg"):
		fuel_mass_kg = maxf(float(state["fuel_mass_kg"]), 0.0)
	if state.has("course_error"):
		course_error = clampf(float(state["course_error"]), 0.0, 1.0)
