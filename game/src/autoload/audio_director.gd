## Placeholder audio mixer. Turns EventBus signals into procedural cues. Autoload name: AudioDirector.
extends Node

const EVENT_CUES: Dictionary = {
	&"breaker_toggled": &"relay",
	&"circuit_shed": &"relay",
	&"circuit_restored": &"relay",
	&"scrubber_power_changed": &"relay",
	&"scrubber_housing_opened": &"thunk",
	&"scrubber_housing_closed": &"thunk",
	&"filter_removed": &"click",
	&"filter_installed": &"click",
	&"seal_seated": &"thunk",
	&"procedure_error": &"buzz",
	&"stores_low": &"buzz",
	&"component_failed": &"alarm",
	&"sleep_started": &"drone",
	&"slept": &"thunk",
}

const HUM_HEALTHY_DB: float = -14.0
const HUM_BROWNOUT_DB: float = -30.0
const HUM_SMOOTH_DB_PER_SECOND: float = 24.0
const SCRUBBER_ON_DB: float = -22.0
const SCRUBBER_OFF_DB: float = -60.0
const ALARM_ACTIVE_DB: float = -8.0
const ALARM_SILENT_DB: float = -60.0
const ALARM_HOLD_SECONDS: float = 2.0
const SFX_POOL_SIZE: int = 4

var _hum: AudioStreamPlayer
var _scrubber: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []

var _hum_target_db: float = HUM_HEALTHY_DB
var _alarm_hold_seconds: float = 0.0
var _sfx_index: int = 0
var _last_cue: StringName = &""
var _cue_count: int = 0
var _scrubber_audible: bool = false


func _ready() -> void:
	_hum = _make_loop_player(ProcAudio.make_hum(1.0), HUM_HEALTHY_DB)
	_scrubber = _make_loop_player(ProcAudio.make_fan_loop(1.0), SCRUBBER_OFF_DB)
	_alarm = _make_loop_player(ProcAudio.make_alarm(1.5), ALARM_SILENT_DB)
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		add_child(player)
		_sfx_pool.append(player)
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		if not event_bus.is_connected(&"power_brownout", _on_power_brownout):
			event_bus.connect(&"power_brownout", _on_power_brownout)
		if not event_bus.is_connected(&"power_restored", _on_power_restored):
			event_bus.connect(&"power_restored", _on_power_restored)
		if not event_bus.is_connected(&"sim_event", _on_sim_event):
			event_bus.connect(&"sim_event", _on_sim_event)


func _process(delta: float) -> void:
	_hum.volume_db = move_toward(_hum.volume_db, _hum_target_db, HUM_SMOOTH_DB_PER_SECOND * delta)
	if _alarm_hold_seconds > 0.0:
		_alarm_hold_seconds = maxf(_alarm_hold_seconds - delta, 0.0)
	_alarm.volume_db = ALARM_ACTIVE_DB if _alarm_hold_seconds > 0.0 else ALARM_SILENT_DB
	_poll_scrubber()


func play_cue(cue: StringName) -> void:
	var resolved: StringName = cue
	if EVENT_CUES.has(resolved):
		resolved = EVENT_CUES[resolved]
	match resolved:
		&"relay", &"click":
			_play_sfx(ProcAudio.make_click())
		&"thunk":
			_play_sfx(ProcAudio.make_thunk())
		&"buzz":
			_play_sfx(ProcAudio.make_buzz())
		&"drone":
			_play_sfx(ProcAudio.make_drone())
		&"alarm":
			_alarm_hold_seconds = ALARM_HOLD_SECONDS
		_:
			push_error("AudioDirector.play_cue: unknown cue '%s'." % String(cue))
			return
	_last_cue = cue
	_cue_count += 1


func get_debug_state() -> Dictionary:
	return {
		"hum_target_db": _hum_target_db,
		"scrubber_audible": _scrubber_audible,
		"last_cue": _last_cue,
		"cue_count": _cue_count,
		"alarm_active": _alarm_hold_seconds > 0.0,
	}


func get_sfx_pool_size() -> int:
	return _sfx_pool.size()


func _make_loop_player(stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()
	return player


func _play_sfx(stream: AudioStream) -> void:
	if _sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.play()


func _poll_scrubber() -> void:
	var atmosphere: AtmosphereSystem = get_tree().get_first_node_in_group(&"atmosphere_system") as AtmosphereSystem
	if atmosphere == null or not atmosphere.has_compartment(&"main"):
		_scrubber_audible = false
		_scrubber.volume_db = SCRUBBER_OFF_DB
		return
	var status: Dictionary = atmosphere.get_compartment_status(&"main")
	var powered: bool = bool(status.get("scrubber_powered", false))
	var installed: bool = bool(status.get("filter_installed", false))
	var condition: float = clampf(float(status.get("filter_condition", 0.0)), 0.0, 1.0)
	_scrubber_audible = powered
	if powered:
		_scrubber.volume_db = SCRUBBER_ON_DB
		_scrubber.pitch_scale = (0.7 + 0.5 * condition) if installed else 0.6
	else:
		_scrubber.volume_db = SCRUBBER_OFF_DB


func _on_power_brownout(_bus_id: StringName, _load_ratio: float) -> void:
	_hum_target_db = HUM_BROWNOUT_DB


func _on_power_restored(_bus_id: StringName) -> void:
	_hum_target_db = HUM_HEALTHY_DB


func _on_sim_event(event_name: StringName, _payload: Dictionary) -> void:
	if not EVENT_CUES.has(event_name):
		return
	var cue: StringName = EVENT_CUES[event_name]
	play_cue(cue)


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
