## Fixed-tick simulation clock. All ship systems advance on its ticks.
## Time scale: 1 real second = 60 sim seconds, so one 24h game day lasts 24 real minutes.
## Autoload name: SimClock. No class_name on purpose — it would conflict with the autoload.
extends Node

signal ticked(delta_hours: float, tick_index: int)
signal hour_advanced(hour: int)
signal day_changed(day: int)

const TICK_RATE: int = 10
const TIME_SCALE: float = 60.0
const SECONDS_PER_DAY: float = 86400.0
const MAX_CATCHUP_TICKS: int = 5

var is_paused: bool = false
var tick_index: int = 0
var sim_seconds: float = 0.0

var _accumulator: float = 0.0
var _last_hour: int = 0
var _last_day: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if is_paused:
		return
	_accumulator += delta
	var tick_interval: float = 1.0 / float(TICK_RATE)
	var ticks_run: int = 0
	while _accumulator >= tick_interval and ticks_run < MAX_CATCHUP_TICKS:
		_accumulator -= tick_interval
		_run_tick()
		ticks_run += 1
	if ticks_run == MAX_CATCHUP_TICKS:
		_accumulator = 0.0


func set_paused(paused: bool) -> void:
	is_paused = paused


func reset_clock() -> void:
	is_paused = false
	tick_index = 0
	sim_seconds = 0.0
	_accumulator = 0.0
	_last_hour = 0
	_last_day = 1


func get_total_hours() -> float:
	return sim_seconds / 3600.0


func get_hour() -> int:
	return int(sim_seconds / 3600.0) % 24


func get_day() -> int:
	return int(sim_seconds / SECONDS_PER_DAY) + 1


## Simulate a block of time in one call (sleep, time skips). Emits normal tick signals.
func fast_forward(hours: float) -> void:
	if hours <= 0.0:
		return
	var delta_hours: float = _delta_hours_per_tick()
	var ticks: int = int(round(hours / delta_hours))
	for i: int in ticks:
		_run_tick()


func _delta_hours_per_tick() -> float:
	return TIME_SCALE / float(TICK_RATE) / 3600.0


func _run_tick() -> void:
	tick_index += 1
	sim_seconds += TIME_SCALE / float(TICK_RATE)
	ticked.emit(_delta_hours_per_tick(), tick_index)
	var hour: int = get_hour()
	if hour != _last_hour:
		_last_hour = hour
		hour_advanced.emit(hour)
	var day: int = get_day()
	if day != _last_day:
		_last_day = day
		day_changed.emit(day)


func save_state() -> Dictionary:
	return {
		"sim_seconds": sim_seconds,
		"tick_index": tick_index,
		"last_hour": _last_hour,
		"last_day": _last_day,
	}


func load_state(state: Dictionary) -> void:
	sim_seconds = maxf(float(state.get("sim_seconds", 0.0)), 0.0)
	tick_index = maxi(int(state.get("tick_index", 0)), 0)
	_last_hour = clampi(int(state.get("last_hour", 0)), 0, 23)
	_last_day = maxi(int(state.get("last_day", 1)), 1)
	_accumulator = 0.0
