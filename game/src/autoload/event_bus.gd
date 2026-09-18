## Central signal hub for ship/world events. Systems emit; UI, audio, and VFX react.
## Rule: nodes never own authoritative state — they subscribe to these signals.
## Autoload name: EventBus. No class_name on purpose — it would conflict with the autoload.
extends Node

signal component_failed(component_id: StringName, failure_mode_id: StringName)
signal component_repaired(component_id: StringName, repair_quality: float)
signal component_condition_changed(component_id: StringName, condition: float)
signal power_brownout(bus_id: StringName, load_ratio: float)
signal power_restored(bus_id: StringName)
signal compartment_pressure_changed(compartment_id: StringName, pressure_kpa: float)
signal compartment_atmosphere_changed(compartment_id: StringName, o2_fraction: float, co2_ppm: float)
signal hull_puncture(compartment_id: StringName, severity: float)
signal course_changed(leg_id: StringName, delta_v_cost: float)
signal stores_changed(part_id: StringName, new_count: int)
signal sim_event(event_name: StringName, payload: Dictionary)
signal operator_condition_changed(condition: float, cause: StringName)
signal operator_incapacitated(cause: StringName)
signal cognition_effect_changed(level: int)
signal mercy_recovery_used(cause: StringName)
signal compartment_humidity_changed(compartment_id: StringName, humidity_fraction: float)

const LOG_LIMIT: int = 500

var event_log: Array[Dictionary] = []


func emit_event(event_name: StringName, payload: Dictionary = {}) -> void:
	sim_event.emit(event_name, payload)
	event_log.append({"msec": Time.get_ticks_msec(), "name": event_name, "payload": payload})
	if event_log.size() > LOG_LIMIT:
		event_log.pop_front()
