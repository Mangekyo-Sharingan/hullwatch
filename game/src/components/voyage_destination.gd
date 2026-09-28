## A fixed waypoint and its arrival data for the voyage system.
class_name VoyageDestination
extends Resource

@export var destination_id: StringName = &""
@export var display_name: String = ""
@export var kind: StringName = &"planet"
@export var transit_days: int = 1
@export var course_plot_hours: float = 1.0
@export var course_plot_fuel_kg: float = 5.0
@export var fuel_cost_kg: float = 1.0
@export var sector_seed: int = 1
@export var arrival_resource: StringName = &"ice"
@export var arrival_resource_units: float = 0.0
@export var arrival_stores: Dictionary = {}
@export_multiline var arrival_report: String = ""
@export var sun_direction: Vector3 = Vector3(0.2, 0.5, -0.84)
@export var sun_color: Color = Color.WHITE
@export var sun_size: float = 0.012
@export var planet_direction: Vector3 = Vector3(-0.55, 0.28, 0.62)
@export var planet_color: Color = Color(0.52, 0.58, 0.72, 1.0)
@export var planet_band_color: Color = Color(0.3, 0.34, 0.4, 1.0)
@export var planet_size: float = 0.055


func is_valid() -> bool:
	if not (
		destination_id != &""
		and not display_name.strip_edges().is_empty()
		and kind in [&"planet", &"star"]
		and transit_days > 0
		and is_finite(course_plot_hours)
		and course_plot_hours > 0.0
		and is_finite(course_plot_fuel_kg)
		and course_plot_fuel_kg >= 0.0
		and is_finite(fuel_cost_kg)
		and fuel_cost_kg > 0.0
		and sector_seed > 0
		and CargoSystem.KNOWN_KINDS.has(arrival_resource)
		and is_finite(arrival_resource_units)
		and arrival_resource_units >= 0.0
		and is_finite(planet_size)
		and planet_size > 0.0
		and is_finite(sun_size)
		and sun_size > 0.0
	):
		return false
	for part_id: Variant in arrival_stores:
		var count: Variant = arrival_stores[part_id]
		if String(part_id).is_empty() or not count is int or int(count) < 0:
			return false
	return true
