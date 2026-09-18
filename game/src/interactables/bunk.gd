## Bunk: ends the day and fast-forwards the sim clock while systems keep ticking.
## Hands the transition to a SleepTransition node when one is present so the player sees the day pass.
class_name Bunk
extends Interactable

@export var sleep_hours: float = 8.0

var _sleeping: bool = false


func _handle_interact(_player: Node) -> void:
	if _sleeping:
		return
	_sleeping = true
	_emit_sim_event(&"sleep_started", {"hours": sleep_hours})
	var transition: Node = _get_system(&"sleep_transition")
	if transition != null:
		await transition.call("run_sleep", sleep_hours)
	else:
		var sim_clock: Node = _get_autoload(&"SimClock")
		if sim_clock != null:
			sim_clock.call("fast_forward", sleep_hours)
	_emit_sim_event(&"slept", {"hours": sleep_hours, "day": _get_day()})
	_sleeping = false


func is_sleeping() -> bool:
	return _sleeping


func _get_day() -> int:
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock == null:
		return 0
	return int(sim_clock.call("get_day"))
