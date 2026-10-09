## Course plotting and destination transit; ship systems continue ticking during the voyage.
class_name NavSystem
extends ShipSystem

const HOURS_PER_DAY: float = 24.0
const MAX_STEP_HOURS: float = 1.0 / 600.0
const PLANET_ROUTE_BASE_CHANCE: float = 0.35

@export var destinations: Array[VoyageDestination] = []
@export var planet_destination_template: VoyageDestination = preload("res://src/data/destinations/destination_unregistered_planet.tres")
@export var fuel_mass_kg: float = 1200.0
@export var course_error_per_hour: float = 0.01
@export var approach_fuel_cost_kg: float = 25.0
@export var propulsion: PropulsionConfig = preload("res://src/data/propulsion/drive_pair.tres")

var current_destination_id: StringName = &""
var plotted_destination_id: StringName = &""
var course_error: float = 0.0
var transit_elapsed_hours: float = 0.0
var transit_active: bool = false
var _visited_destinations: Dictionary = {}
var _discovered_planet_destinations: Array[VoyageDestination] = []
var _planet_discovery_records: Array[Dictionary] = []
var _arrival_ordinal: int = 0
var xenonite_mass_kg: float = 0.0
var xenonite_consumed_kg: float = 0.0
var transit_actual_hours: float = 0.0
var wear_components: Array[WearComponent] = []
var _components_by_target: Dictionary = {}
var _service: Dictionary = {}
var _service_revision: int = 0
var _wear_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _thermal_hold: bool = false
var _tank_recovering: bool = false
var _uv_active: bool = false
var _drive_output_w: float = 0.0
var _drive_hold_reason: StringName = &""
var _firing: Dictionary = {"port": false, "starboard": false}
var _last_drive_state: Dictionary = {}
var _burn_hours: float = 0.0
var _power: PowerSystem
var _thermal: ThermalSystem


func _ready() -> void:
	system_id = &"nav"
	add_to_group(&"nav_system")
	_reset_propulsion()
	super._ready()
	_refresh_drive()


## Direct calls subdivide Nav only; coupled power/heat time skips use SimClock.fast_forward().
func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	# Direct scenario ticks need the same recovery/burn ordering as SimClock's 6 s ticks.
	if delta_hours > MAX_STEP_HOURS:
		var steps: int = floori(delta_hours / MAX_STEP_HOURS)
		for step: int in steps:
			sim_tick(MAX_STEP_HOURS)
		var remainder: float = delta_hours - float(steps) * MAX_STEP_HOURS
		if remainder > 1e-12:
			sim_tick(remainder)
		return
	_refresh_drive()
	if _uv_active:
		xenonite_mass_kg = minf(propulsion.tank_capacity_kg, xenonite_mass_kg + propulsion.replication_kg_per_hour * delta_hours)
	if _tank_recovering and xenonite_mass_kg >= propulsion.seed_mass_kg + propulsion.restart_mass_kg:
		_tank_recovering = false
		_refresh_drive()
	_burn_hours = 0.0
	if transit_active:
		_advance_transit(delta_hours)
	elif plotted_destination_id != &"":
		course_error = clampf(course_error + course_error_per_hour * delta_hours, 0.0, 1.0)
		if course_error >= 1.0 - 1e-9:
			course_error = 1.0
			var expired_destination: StringName = plotted_destination_id
			plotted_destination_id = &""
			emit_sim_event(&"course_expired", {"destination_id": expired_destination, "course_error": course_error})
	if _tick_drive_wear(delta_hours) or (not transit_active and _drive_output_w > 0.0) or _tank_recovering or (_uv_active and xenonite_mass_kg >= propulsion.tank_capacity_kg):
		_refresh_drive()


func get_destination(destination_id: StringName) -> VoyageDestination:
	for destination: VoyageDestination in destinations:
		if destination != null and destination.destination_id == destination_id:
			return destination
	for destination: VoyageDestination in _discovered_planet_destinations:
		if destination.destination_id == destination_id:
			return destination
	return null


func get_destinations() -> Array[VoyageDestination]:
	var available: Array[VoyageDestination] = destinations.duplicate()
	available.append_array(_discovered_planet_destinations)
	return available


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
	transit_actual_hours = 0.0
	transit_active = true
	course_error = 0.0
	_refresh_drive()
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
		"xenonite_mass_kg": xenonite_mass_kg,
		"xenonite_capacity_kg": propulsion.tank_capacity_kg,
		"xenonite_consumed_kg": xenonite_consumed_kg,
		"uv_active": _uv_active,
		"drive_output_w": _drive_output_w,
		"drive_heat_w": _drive_output_w * propulsion.heat_fraction + (propulsion.uv_watts if _uv_active else 0.0),
		"drive_hold_reason": _drive_hold_reason,
		"cassette_functional": {"port": _target_functional(&"port"), "starboard": _target_functional(&"starboard")},
		"cassette_firing": _firing.duplicate(),
		"functional_cassettes": _functional_cassettes(),
		"transit_actual_hours": transit_actual_hours,
		"transit_remaining_hours": (total_hours - transit_elapsed_hours) / _progress_rate() if _progress_rate() > 0.0 and _drive_hold_reason == &"" else INF,
	}


func save_state() -> Dictionary:
	var wear: Array[Dictionary] = []
	for component: WearComponent in wear_components:
		var entry: Dictionary = component.get_status()
		entry["component_id"] = String(component.component_id)
		entry["failed_mode"] = String(component.failed_mode)
		wear.append(entry)
	return {
		"system_id": "nav",
		"state_version": 4,
		"current_destination_id": String(current_destination_id),
		"plotted_destination_id": String(plotted_destination_id),
		"fuel_mass_kg": fuel_mass_kg,
		"course_error": course_error,
		"transit_elapsed_hours": transit_elapsed_hours,
		"transit_active": transit_active,
		"visited_destinations": _visited_destinations.duplicate(),
		"arrival_ordinal": _arrival_ordinal,
		"planet_discoveries": _planet_discovery_records.duplicate(true),
		"propulsion": {
			"mass_kg": xenonite_mass_kg,
			"consumed_kg": xenonite_consumed_kg,
			"actual_hours": transit_actual_hours,
			"service": _service.duplicate(true),
			"wear": wear,
			"rng_state": str(_wear_rng.state),
			"thermal_hold": _thermal_hold,
			"tank_recovering": _tank_recovering,
		},
	}


func load_state(state: Dictionary) -> void:
	_reset_propulsion()
	_load_propulsion(state.get("propulsion", {}))
	_arrival_ordinal = maxi(int(state.get("arrival_ordinal", 0)), 0)
	_restore_planet_discoveries(state.get("planet_discoveries", []))
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
	_refresh_drive()
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
	if _drive_output_w <= 0.0:
		transit_actual_hours += delta_hours
		return
	var total_hours: float = float(destination.transit_days) * HOURS_PER_DAY
	var previous_hours: float = transit_elapsed_hours
	var rate: float = _progress_rate()
	var burn_hours: float = minf(delta_hours, (total_hours - previous_hours) / rate)
	var available_wh: float = maxf(xenonite_mass_kg - propulsion.seed_mass_kg, 0.0) * propulsion.output_wh_per_kg
	burn_hours = minf(burn_hours, available_wh / _drive_output_w)
	var next_hours: float = minf(previous_hours + burn_hours * rate, total_hours)
	transit_actual_hours += burn_hours if next_hours >= total_hours - 1e-9 else delta_hours
	var fuel_due: float = destination.fuel_cost_kg * (next_hours - previous_hours) / total_hours
	if fuel_mass_kg < fuel_due - 0.0001:
		fuel_mass_kg = 0.0
		transit_active = false
		plotted_destination_id = &""
		emit_sim_event(&"transit_fuel_exhausted", {"destination_id": destination.destination_id, "elapsed_hours": previous_hours})
		return
	_burn_hours = burn_hours
	var consumed_kg: float = _drive_output_w * burn_hours / propulsion.output_wh_per_kg
	xenonite_consumed_kg += consumed_kg
	xenonite_mass_kg = maxf(propulsion.seed_mass_kg, xenonite_mass_kg - consumed_kg)
	if xenonite_mass_kg <= propulsion.seed_mass_kg + 1e-9:
		_tank_recovering = true
	fuel_mass_kg = maxf(fuel_mass_kg - fuel_due, 0.0)
	transit_elapsed_hours = next_hours
	var previous_day: int = int((previous_hours + 1e-9) / HOURS_PER_DAY)
	var current_day: int = int((next_hours + 1e-9) / HOURS_PER_DAY)
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
	_arrival_ordinal += 1
	var discovered_planet: VoyageDestination = _try_discover_planet(destination, _arrival_ordinal)
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
	if discovered_planet != null:
		_planet_discovery_records.append({
			"destination_id": String(discovered_planet.destination_id),
			"origin_destination_id": String(destination.destination_id),
			"arrival_ordinal": _arrival_ordinal,
		})
		_discovered_planet_destinations.append(discovered_planet)
		emit_sim_event(&"planet_route_discovered", {
			"destination_id": discovered_planet.destination_id,
			"display_name": discovered_planet.display_name,
			"origin_destination_id": destination.destination_id,
		})


func _try_discover_planet(origin: VoyageDestination, arrival_ordinal: int) -> VoyageDestination:
	var settings: Node = _get_autoload(&"GameSettings")
	if settings == null or not settings.has_method(&"get_value"):
		return null
	var raw_frequency: Variant = settings.call(&"get_value", &"planet_frequency")
	if not (raw_frequency is int or raw_frequency is float):
		return null
	var frequency: float = clampf(float(raw_frequency), 0.0, 3.0)
	var rng: RandomNumberGenerator = _planet_rng(origin, arrival_ordinal)
	if rng.randf() >= minf(PLANET_ROUTE_BASE_CHANCE * frequency, 1.0):
		return null
	return _make_planet_destination(origin, arrival_ordinal)


func _make_planet_destination(origin: VoyageDestination, arrival_ordinal: int) -> VoyageDestination:
	if planet_destination_template == null or not planet_destination_template.is_valid():
		return null
	var rng: RandomNumberGenerator = _planet_rng(origin, arrival_ordinal)
	# Mirror the discovery roll so the generated sector seed follows it in the same stream.
	rng.randf()
	var destination: VoyageDestination = planet_destination_template.duplicate(true) as VoyageDestination
	destination.destination_id = StringName("planet_orbit_%04d" % arrival_ordinal)
	destination.display_name = "UNREGISTERED PLANET %02d" % arrival_ordinal
	destination.sector_seed = rng.randi_range(1, 2000000000)
	return destination if destination.is_valid() else null


func _planet_rng(origin: VoyageDestination, arrival_ordinal: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var seed_text: String = "%s:%d:%d:planet-route" % [String(origin.destination_id), origin.sector_seed, arrival_ordinal]
	var stable_seed: int = int(seed_text.hash()) & 0x7fffffff
	rng.seed = maxi(stable_seed, 1)
	return rng


func _restore_planet_discoveries(saved_records: Variant) -> void:
	_discovered_planet_destinations.clear()
	_planet_discovery_records.clear()
	if not saved_records is Array:
		return
	for raw_record: Variant in saved_records:
		if not raw_record is Dictionary:
			continue
		var origin_id: StringName = StringName(String(raw_record.get("origin_destination_id", "")))
		var origin: VoyageDestination = get_destination(origin_id)
		var arrival_ordinal: int = int(raw_record.get("arrival_ordinal", 0))
		if origin == null or arrival_ordinal < 1:
			continue
		var destination: VoyageDestination = _make_planet_destination(origin, arrival_ordinal)
		if destination == null or String(raw_record.get("destination_id", "")) != String(destination.destination_id):
			continue
		_discovered_planet_destinations.append(destination)
		_planet_discovery_records.append({
			"destination_id": String(destination.destination_id),
			"origin_destination_id": String(origin.destination_id),
			"arrival_ordinal": arrival_ordinal,
		})


func _known_destination_id(destination_id: StringName) -> StringName:
	return destination_id if get_destination(destination_id) != null else &""


func _reset_propulsion() -> void:
	xenonite_mass_kg = propulsion.initial_mass_kg
	xenonite_consumed_kg = 0.0
	transit_actual_hours = 0.0
	_thermal_hold = false
	_tank_recovering = false
	_service.clear()
	_service_revision += 1
	_components_by_target.clear()
	for target: StringName in [&"port", &"starboard", &"tank"]:
		_service[target] = {"isolated": false, "housing_open": false}
		var components: Array[WearComponent] = []
		_components_by_target[target] = components
	wear_components.clear()
	for template: WearComponent in propulsion.components:
		var component: WearComponent = template.duplicate(true) as WearComponent
		wear_components.append(component)
		var target: StringName = StringName(String(component.component_id).get_slice("_", 0))
		(_components_by_target[target] as Array[WearComponent]).append(component)
	_wear_rng.seed = propulsion.wear_seed


func _load_propulsion(saved: Dictionary) -> void:
	xenonite_mass_kg = clampf(float(saved.get("mass_kg", propulsion.initial_mass_kg)), propulsion.seed_mass_kg, propulsion.tank_capacity_kg)
	xenonite_consumed_kg = maxf(float(saved.get("consumed_kg", 0.0)), 0.0)
	transit_actual_hours = maxf(float(saved.get("actual_hours", 0.0)), 0.0)
	_thermal_hold = bool(saved.get("thermal_hold", false))
	_tank_recovering = bool(saved.get("tank_recovering", false))
	var service: Dictionary = saved.get("service", {})
	for target: StringName in _service:
		var entry: Dictionary = service.get(String(target), {})
		_service[target] = {"isolated": bool(entry.get("isolated", false)), "housing_open": bool(entry.get("housing_open", false))}
		if bool(_service[target]["housing_open"]):
			_service[target]["isolated"] = true
	for entry: Dictionary in saved.get("wear", []):
		var component: WearComponent = _drive_component(StringName(entry.get("component_id", "")))
		if component == null:
			continue
		component.condition = clampf(float(entry.get("condition", 1.0)), 0.0, 1.0)
		component.hours_operated = maxf(float(entry.get("hours_operated", 0.0)), 0.0)
		component.failed_mode = StringName(entry.get("failed_mode", ""))
		component.diagnosed = bool(entry.get("diagnosed", false))
		component.scanned = bool(entry.get("scanned", false))
	if saved.has("rng_state"):
		_wear_rng.state = int(saved["rng_state"])


func _drive_component(component_id: StringName) -> WearComponent:
	for component: WearComponent in wear_components:
		if component.component_id == component_id:
			return component
	return null


func _target_components(target: StringName) -> Array[WearComponent]:
	return _components_by_target[target]


func _target_functional(target: StringName) -> bool:
	if not _service.has(target):
		return false
	var state: Dictionary = _service[target]
	if bool(state["isolated"]) or bool(state["housing_open"]):
		return false
	for component: WearComponent in _target_components(target):
		if component.is_failed() or component.condition <= 0.0:
			return false
	return true


func _functional_cassettes() -> int:
	return int(_target_functional(&"port")) + int(_target_functional(&"starboard"))


func _progress_rate() -> float:
	var count: int = _functional_cassettes()
	return 1.0 if count == 2 else (propulsion.single_progress_rate if count == 1 else 0.0)


func _group(group_name: StringName) -> Node:
	return get_tree().get_first_node_in_group(group_name) if is_inside_tree() else null


func _refresh_drive() -> void:
	if not is_instance_valid(_thermal):
		_thermal = _group(&"thermal_system") as ThermalSystem
	if _thermal != null and _thermal.has_compartment(propulsion.compartment_id):
		var temperature: float = _thermal.get_temperature(propulsion.compartment_id)
		if temperature >= propulsion.overheat_c:
			_thermal_hold = true
		elif temperature <= propulsion.resume_c:
			_thermal_hold = false
	var uv_requested: bool = _target_functional(&"tank") and xenonite_mass_kg < propulsion.tank_capacity_kg
	if not is_instance_valid(_power):
		_power = _group(&"power_system") as PowerSystem
	_uv_active = uv_requested
	if _power != null:
		_uv_active = false
		if _power.has_circuit(propulsion.uv_circuit):
			_power.set_circuit_source_load(propulsion.uv_circuit, &"propulsion", propulsion.uv_watts if uv_requested else 0.0)
			_uv_active = uv_requested and _power.is_breaker_on(propulsion.uv_circuit) and not _power.is_circuit_shed(propulsion.uv_circuit)
	_drive_hold_reason = &""
	var port_functional: bool = _target_functional(&"port")
	var starboard_functional: bool = _target_functional(&"starboard")
	var count: int = int(port_functional) + int(starboard_functional)
	if transit_active:
		if count == 0:
			_drive_hold_reason = &"cassette_offline"
		elif _thermal_hold:
			_drive_hold_reason = &"thermal_hold"
		elif _tank_recovering or xenonite_mass_kg <= propulsion.seed_mass_kg:
			_drive_hold_reason = &"tank_recovering"
	_drive_output_w = 0.0
	if transit_active and _drive_hold_reason == &"":
		_drive_output_w = propulsion.pair_output_w if count == 2 else propulsion.single_output_w
	_firing["port"] = _drive_output_w > 0.0 and port_functional
	_firing["starboard"] = _drive_output_w > 0.0 and starboard_functional
	if _thermal != null:
		_thermal.set_heat_source_gain(propulsion.compartment_id, &"propulsion", _drive_output_w * propulsion.heat_fraction + (propulsion.uv_watts if _uv_active else 0.0))
	var state: Dictionary = {"port": _firing["port"], "starboard": _firing["starboard"], "hold_reason": _drive_hold_reason, "uv_active": _uv_active, "service_revision": _service_revision}
	if state != _last_drive_state:
		var hold_changed: bool = _drive_hold_reason != StringName(_last_drive_state.get("hold_reason", &""))
		_last_drive_state = state
		emit_sim_event(&"drive_state_changed", {"cassette_firing": _firing.duplicate(), "hold_reason": _drive_hold_reason, "uv_active": _uv_active, "service": _service.duplicate(true), "hold_changed": hold_changed})


func _tick_drive_wear(delta_hours: float) -> bool:
	var changed: bool = false
	var operating_components: Array[WearComponent] = wear_components
	if _burn_hours <= 0.0:
		if not _uv_active:
			return false
		operating_components = _target_components(&"tank")
	for component: WearComponent in operating_components:
		var target: StringName = &"tank" if component.component_id == &"tank_uv" else StringName(String(component.component_id).get_slice("_", 0))
		var hours: float = delta_hours if target == &"tank" and _uv_active else (_burn_hours if target != &"tank" and _target_functional(target) else 0.0)
		if hours <= 0.0:
			continue
		component.load = 1.0
		var mode: StringName = component.tick_sim(hours, {"heat": float(_thermal_hold), "load": 1.0}, _wear_rng)
		if mode == &"" and component.condition <= 0.0 and not component.failure_modes.is_empty():
			mode = component.failure_modes[0].id
			component.failed_mode = mode
		if mode != &"":
			_notify_drive_failure(component, target)
			changed = true
	return changed


func _notify_drive_failure(component: WearComponent, target: StringName) -> void:
	component.diagnosed = false
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_failed", component.component_id, component.failed_mode)
	emit_sim_event(&"drive_cassette_failed", {"cassette_id": target})


func force_failure(component_id: StringName, failure_mode_id: StringName) -> bool:
	var component: WearComponent = _drive_component(component_id)
	if component == null or component.is_failed():
		return false
	for mode: FailureMode in component.failure_modes:
		if mode.id == failure_mode_id:
			component.failed_mode = mode.id
			_notify_drive_failure(component, StringName(String(component_id).get_slice("_", 0)))
			_refresh_drive()
			return true
	return false


func get_wear_status() -> Dictionary:
	var status: Dictionary = {}
	for component: WearComponent in wear_components:
		status[String(component.component_id)] = component.get_status()
	return status


func get_service_status(target: StringName) -> Dictionary:
	if not _service.has(target):
		return {}
	var status: Dictionary = _service[target].duplicate()
	status["functional"] = _target_functional(target)
	var components: Dictionary = {}
	for component: WearComponent in _target_components(target):
		components[String(component.component_id)] = component.get_status()
	status["components"] = components
	return status


func service_action(target: StringName, action: StringName, tool: StringName) -> bool:
	if not _service.has(target):
		return false
	var state: Dictionary = _service[target]
	var isolated: bool = bool(state["isolated"])
	var opened: bool = bool(state["housing_open"])
	match action:
		&"isolate":
			if isolated:
				return false
			state["isolated"] = true
		&"open":
			if not isolated or opened or tool != &"wrench":
				return _service_error(&"isolate_and_use_wrench")
			state["housing_open"] = true
		&"scan":
			if tool != &"scanner":
				return _service_error(&"no_tool")
			for component: WearComponent in _target_components(target):
				component.scan()
		&"diagnose":
			if not isolated or not opened or tool != &"multimeter":
				return _service_error(&"isolate_open_use_multimeter")
			for component: WearComponent in _target_components(target):
				var mode: StringName = component.diagnose()
				component.diagnosed = true
				if mode != &"":
					emit_sim_event(&"component_diagnosed", {"component_id": component.component_id, "failure_mode_id": mode})
		&"close":
			if not opened or tool != &"wrench":
				return _service_error(&"no_wrench")
			state["housing_open"] = false
		&"restore":
			if not isolated or opened or tool != &"multimeter":
				return _service_error(&"close_and_verify")
			for component: WearComponent in _target_components(target):
				if component.is_failed():
					return _service_error(&"service_fault_first")
			state["isolated"] = false
		_:
			var component: WearComponent = _drive_component(StringName(String(action).trim_prefix("service:")))
			if not String(action).begins_with("service:") or component == null or not _target_components(target).has(component):
				return false
			if not isolated or not opened or tool != &"wrench" or (component.is_failed() and not component.diagnosed) or (not component.is_failed() and not component.scanned):
				return _service_error(&"diagnose_before_service")
			component.apply_repair(propulsion.repair_quality)
			_refresh_drive()
			var clock: Node = _get_autoload(&"SimClock")
			if clock != null:
				clock.call("fast_forward", propulsion.repair_hours)
			emit_sim_event(&"component_repaired", {"component_id": component.component_id, "quality": propulsion.repair_quality})
	_service_revision += 1
	_refresh_drive()
	emit_sim_event(&"drive_service_changed", {"target": target, "action": action})
	return true


func _service_error(reason: StringName) -> bool:
	emit_sim_event(&"procedure_error", {"reason": reason})
	return false
