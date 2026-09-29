## Course plotting and destination transit; ship systems continue ticking during the voyage.
class_name NavSystem
extends ShipSystem

const HOURS_PER_DAY: float = 24.0

@export var destinations: Array[VoyageDestination] = []
@export var fuel_mass_kg: float = 1200.0
@export var course_error_per_hour: float = 0.01
@export var approach_fuel_cost_kg: float = 25.0

var current_destination_id: StringName = &""
var plotted_destination_id: StringName = &""
var course_error: float = 0.0
var transit_elapsed_hours: float = 0.0
var transit_active: bool = false
var _visited_destinations: Dictionary = {}


func _ready() -> void:
	system_id = &"nav"
	add_to_group(&"nav_system")
	super._ready()


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	if transit_active:
		_advance_transit(delta_hours)
	elif plotted_destination_id != &"":
		course_error = clampf(course_error + course_error_per_hour * delta_hours, 0.0, 1.0)
		if course_error >= 1.0 - 1e-9:
			course_error = 1.0
			var expired_destination: StringName = plotted_destination_id
			plotted_destination_id = &""
			emit_sim_event(&"course_expired", {"destination_id": expired_destination, "course_error": course_error})


func get_destination(destination_id: StringName) -> VoyageDestination:
	for destination: VoyageDestination in destinations:
		if destination != null and destination.destination_id == destination_id:
			return destination
	return null


func get_destinations() -> Array[VoyageDestination]:
	return destinations.duplicate()


func has_visited(destination_id: StringName) -> bool:
	return bool(_visited_destinations.get(String(destination_id), false))


func plot_course(destination_id: StringName) -> bool:
	var destination: VoyageDestination = get_destination(destination_id)
	if destination == null or not destination.is_valid() or transit_active or plotted_destination_id != &"":
		return false
	if destination_id == current_destination_id or fuel_mass_kg < destination.fuel_cost_kg + destination.course_plot_fuel_kg:
		return false
	if not spend_fuel(destination.course_plot_fuel_kg):
		return false
	plotted_destination_id = destination_id
	course_error = 0.0
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"course_changed", destination_id, destination.fuel_cost_kg)
	emit_sim_event(&"course_plotted", {
		"destination_id": destination_id,
		"fuel_cost_kg": destination.fuel_cost_kg,
		"transit_days": destination.transit_days,
		"course_plot_hours": destination.course_plot_hours,
	})
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		sim_clock.call("fast_forward", destination.course_plot_hours)
	return true


func cancel_course() -> bool:
	if transit_active or plotted_destination_id == &"":
		return false
	var cancelled_destination: StringName = plotted_destination_id
	plotted_destination_id = &""
	course_error = 0.0
	emit_sim_event(&"course_cancelled", {"destination_id": cancelled_destination})
	return true


func begin_transit() -> bool:
	var destination: VoyageDestination = get_destination(plotted_destination_id)
	if destination == null or not destination.is_valid() or transit_active:
		return false
	if fuel_mass_kg < destination.fuel_cost_kg:
		return false
	transit_elapsed_hours = 0.0
	transit_active = true
	course_error = 0.0
	emit_sim_event(&"transit_started", {
		"destination_id": destination.destination_id,
		"transit_days": destination.transit_days,
		"fuel_cost_kg": destination.fuel_cost_kg,
	})
	return true


func begin_burn() -> bool:
	return begin_transit()


func spend_fuel(kg: float) -> bool:
	if not is_finite(kg) or kg <= 0.0:
		return kg <= 0.0
	var reserved_fuel: float = 0.0
	if transit_active or plotted_destination_id != &"":
		var destination: VoyageDestination = get_destination(plotted_destination_id)
		if destination != null:
			var total_hours: float = float(destination.transit_days) * HOURS_PER_DAY
			if transit_active:
				reserved_fuel = destination.fuel_cost_kg * (1.0 - transit_elapsed_hours / total_hours)
			else:
				reserved_fuel = destination.fuel_cost_kg
	if fuel_mass_kg - kg < reserved_fuel - 0.0001:
		return false
	fuel_mass_kg -= kg
	emit_sim_event(&"fuel_spent", {"kg": kg, "fuel_remaining": fuel_mass_kg})
	return true


func get_status() -> Dictionary:
	var plotted: VoyageDestination = get_destination(plotted_destination_id)
	var total_hours: float = 0.0
	if plotted != null:
		total_hours = float(plotted.transit_days) * HOURS_PER_DAY
	var phase: StringName = &"idle"
	if transit_active:
		phase = &"transit"
	elif plotted_destination_id != &"":
		phase = &"course_plotted"
	return {
		"system_id": system_id,
		"phase": phase,
		"current_leg": _visited_destinations.size(),
		"current_destination_id": current_destination_id,
		"current_waypoint": current_destination_id,
		"plotted_destination_id": plotted_destination_id,
		"plotted_waypoint": plotted_destination_id,
		"fuel_mass_kg": fuel_mass_kg,
		"course_error": course_error,
		"transit_active": transit_active,
		"transit_elapsed_hours": transit_elapsed_hours,
		"transit_total_hours": total_hours,
		"transit_progress": transit_elapsed_hours / total_hours if total_hours > 0.0 else 0.0,
		"transit_day": mini(int(transit_elapsed_hours / HOURS_PER_DAY) + 1, int(total_hours / HOURS_PER_DAY)),
		"arrived": current_destination_id != &"" and not transit_active,
	}


func save_state() -> Dictionary:
	return {
		"system_id": "nav",
		"state_version": 2,
		"current_destination_id": String(current_destination_id),
		"plotted_destination_id": String(plotted_destination_id),
		"fuel_mass_kg": fuel_mass_kg,
		"course_error": course_error,
		"transit_elapsed_hours": transit_elapsed_hours,
		"transit_active": transit_active,
		"visited_destinations": _visited_destinations.duplicate(),
	}


func load_state(state: Dictionary) -> void:
	if state.has("current_destination_id"):
		current_destination_id = _known_destination_id(StringName(String(state["current_destination_id"])))
	else:
		var old_leg: int = clampi(int(state.get("current_leg", 0)), 0, destinations.size() + 1)
		var last_arrival: int = mini(old_leg - 1, destinations.size() - 1)
		current_destination_id = destinations[last_arrival].destination_id if last_arrival >= 0 else &""
	plotted_destination_id = _known_destination_id(StringName(String(state.get("plotted_destination_id", ""))))
	if plotted_destination_id == &"" and String(state.get("plotted_waypoint", "")) != "":
		var next_index: int = int(state.get("current_leg", 0))
		if next_index >= 0 and next_index < destinations.size():
			plotted_destination_id = destinations[next_index].destination_id
	fuel_mass_kg = maxf(float(state.get("fuel_mass_kg", fuel_mass_kg)), 0.0)
	course_error = clampf(float(state.get("course_error", 0.0)), 0.0, 1.0)
	transit_elapsed_hours = maxf(float(state.get("transit_elapsed_hours", 0.0)), 0.0)
	transit_active = bool(state.get("transit_active", false)) and plotted_destination_id != &""
	_visited_destinations.clear()
	var visited: Dictionary = state.get("visited_destinations", {})
	for key: Variant in visited:
		var destination_id: StringName = _known_destination_id(StringName(String(key)))
		if destination_id != &"" and bool(visited[key]):
			_visited_destinations[String(destination_id)] = true
	if current_destination_id != &"" and not _visited_destinations.has(String(current_destination_id)):
		_visited_destinations[String(current_destination_id)] = true
	if transit_active:
		var destination: VoyageDestination = get_destination(plotted_destination_id)
		if destination == null:
			transit_active = false
			plotted_destination_id = &""
		else:
			transit_elapsed_hours = clampf(transit_elapsed_hours, 0.0, float(destination.transit_days) * HOURS_PER_DAY)
	else:
		transit_elapsed_hours = 0.0
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"navigation_state_restored", transit_active)
	if event_bus != null and current_destination_id != &"":
		event_bus.emit_signal(&"destination_state_restored", current_destination_id)


func _advance_transit(delta_hours: float) -> void:
	var destination: VoyageDestination = get_destination(plotted_destination_id)
	if destination == null:
		transit_active = false
		plotted_destination_id = &""
		return
	var total_hours: float = float(destination.transit_days) * HOURS_PER_DAY
	var previous_hours: float = transit_elapsed_hours
	var next_hours: float = minf(previous_hours + delta_hours, total_hours)
	var fuel_due: float = destination.fuel_cost_kg * (next_hours - previous_hours) / total_hours
	if fuel_mass_kg < fuel_due - 0.0001:
		fuel_mass_kg = 0.0
		transit_active = false
		plotted_destination_id = &""
		emit_sim_event(&"transit_fuel_exhausted", {"destination_id": destination.destination_id, "elapsed_hours": previous_hours})
		return
	fuel_mass_kg = maxf(fuel_mass_kg - fuel_due, 0.0)
	transit_elapsed_hours = next_hours
	var previous_day: int = int(previous_hours / HOURS_PER_DAY)
	var current_day: int = int(next_hours / HOURS_PER_DAY)
	for day: int in range(previous_day + 1, current_day + 1):
		emit_sim_event(&"transit_day_advanced", {
			"destination_id": destination.destination_id,
			"day": day,
			"days_total": destination.transit_days,
		})
	if transit_elapsed_hours >= total_hours - 1e-9:
		_arrive(destination)


func _arrive(destination: VoyageDestination) -> void:
	var first_visit: bool = not has_visited(destination.destination_id)
	current_destination_id = destination.destination_id
	_visited_destinations[String(destination.destination_id)] = true
	transit_active = false
	transit_elapsed_hours = float(destination.transit_days) * HOURS_PER_DAY
	plotted_destination_id = &""
	course_error = 0.0
	var resource_id: StringName = destination.arrival_resource if first_visit else &""
	var resource_units: float = destination.arrival_resource_units if first_visit else 0.0
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"destination_arrived", destination.destination_id, destination.kind, destination.sector_seed, resource_id, resource_units, destination.arrival_stores if first_visit else {})
	var arrival_report: String = destination.arrival_report
	if not first_visit:
		arrival_report = "Reference restored. No additional stores were transferred."
	emit_sim_event(&"destination_arrived", {
		"destination_id": destination.destination_id,
		"display_name": destination.display_name,
		"kind": destination.kind,
		"sector_seed": destination.sector_seed,
		"resource_id": resource_id,
		"resource_units": resource_units,
		"arrival_report": arrival_report,
		"first_visit": first_visit,
		"arrival_stores": destination.arrival_stores if first_visit else {},
	})


func _known_destination_id(destination_id: StringName) -> StringName:
	return destination_id if get_destination(destination_id) != null else &""
