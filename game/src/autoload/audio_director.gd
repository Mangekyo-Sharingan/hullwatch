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
	&"probe_scanned": &"beep",
	&"probe_diagnosis": &"beep",
	&"diagnosis_clear": &"beep",
	&"message_received": &"beep",
	&"scanner_ping": &"beep",
	&"sleep_started": &"drone",
	&"slept": &"thunk",
	&"footstep": &"footstep",
	&"tether_strained": &"tether_warning",
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
const FOOTSTEP_POOL_SIZE: int = 4
const BREATH_START_DB: float = -34.0
const BREATH_MIN_DB: float = -40.0
const BREATH_MAX_DB: float = -16.0
const BREATH_PITCH_MIN: float = 0.9
const BREATH_PITCH_MAX: float = 1.15
const BREATH_SMOOTH_DB_PER_SECOND: float = 180.0
const BREATH_SMOOTH_PITCH_PER_SECOND: float = 3.0
const BREATH_MIN_SMOOTH_DELTA: float = 1.0 / 60.0
const OUTSIDE_HUM_REDUCTION_DB: float = -10.0
const OUTSIDE_SCRUBBER_REDUCTION_DB: float = -14.0
const OUTSIDE_BREATH_BOOST_DB: float = 10.0
const TETHER_WARNING_DB: float = -12.0

var _hum: AudioStreamPlayer
var _scrubber: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _footstep_pool: Array[AudioStreamPlayer] = []

var _hum_target_db: float = HUM_HEALTHY_DB
var _alarm_hold_seconds: float = 0.0
var _sfx_index: int = 0
var _footstep_index: int = 0
var _last_cue: StringName = &""
var _cue_count: int = 0
var _scrubber_audible: bool = false
var _exertion: float = 0.0
var _effective_exertion: float = 0.0
var _breath_db: float = BREATH_START_DB
var _breath_target_db: float = BREATH_START_DB
var _outside_suited: bool = false
var _last_tether_ratio: float = 0.0


func _ready() -> void:
	_hum = _make_loop_player(ProcAudio.make_hum(1.0), HUM_HEALTHY_DB)
	_scrubber = _make_loop_player(ProcAudio.make_fan_loop(1.0), SCRUBBER_OFF_DB)
	_alarm = _make_loop_player(ProcAudio.make_alarm(1.5), ALARM_SILENT_DB)
	_breath = _make_loop_player(ProcAudio.make_breath_loop(), BREATH_START_DB)
	_breath.pitch_scale = BREATH_PITCH_MIN
	for i: int in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		add_child(player)
		_sfx_pool.append(player)
	for i: int in FOOTSTEP_POOL_SIZE:
		var stepper := AudioStreamPlayer.new()
		stepper.name = "Footstep%d" % i
		add_child(stepper)
		_footstep_pool.append(stepper)
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		if not event_bus.is_connected(&"power_brownout", _on_power_brownout):
			event_bus.connect(&"power_brownout", _on_power_brownout)
		if not event_bus.is_connected(&"power_restored", _on_power_restored):
			event_bus.connect(&"power_restored", _on_power_restored)
		if not event_bus.is_connected(&"sim_event", _on_sim_event):
			event_bus.connect(&"sim_event", _on_sim_event)


func _process(delta: float) -> void:
	_poll_outside_mix()
	_hum.volume_db = move_toward(_hum.volume_db, _hum_mix_target_db(), HUM_SMOOTH_DB_PER_SECOND * delta)
	if _alarm_hold_seconds > 0.0:
		_alarm_hold_seconds = maxf(_alarm_hold_seconds - delta, 0.0)
	_alarm.volume_db = ALARM_ACTIVE_DB if _alarm_hold_seconds > 0.0 else ALARM_SILENT_DB
	_poll_scrubber()
	_poll_breath(delta)


func play_cue(cue: StringName, tension_ratio: float = 0.9) -> void:
	var resolved: StringName = cue
	if EVENT_CUES.has(resolved):
		resolved = EVENT_CUES[resolved]
	match resolved:
		&"relay", &"click":
			_play_sfx(ProcAudio.make_click())
		&"thunk":
			_play_sfx(ProcAudio.make_thunk())
		&"beep":
			_play_sfx(ProcAudio.make_beep())
		&"buzz":
			_play_sfx(ProcAudio.make_buzz())
		&"drone":
			_play_sfx(ProcAudio.make_drone())
		&"tether_warning":
			_last_tether_ratio = clampf(tension_ratio, 0.0, 1.0)
			var warning_pitch: float = lerpf(520.0, 680.0, inverse_lerp(0.9, 1.0, clampf(tension_ratio, 0.9, 1.0)))
			_play_sfx(ProcAudio.make_beep(warning_pitch, 0.18), TETHER_WARNING_DB)
		&"alarm":
			_alarm_hold_seconds = ALARM_HOLD_SECONDS
		&"footstep":
			play_footstep()
		_:
			push_error("AudioDirector.play_cue: unknown cue '%s'." % String(cue))
			return
	_record_cue(cue)


func play_footstep(variant: int = 0) -> void:
	if _footstep_pool.is_empty():
		return
	var player: AudioStreamPlayer = _footstep_pool[_footstep_index]
	_footstep_index = (_footstep_index + 1) % _footstep_pool.size()
	player.stream = ProcAudio.make_footstep(variant)
	player.play()


func set_exertion(level: float) -> void:
	_exertion = clampf(level, 0.0, 1.0)


func get_exertion() -> float:
	return _exertion


func get_debug_state() -> Dictionary:
	return {
		"hum_target_db": _hum_target_db,
		"scrubber_audible": _scrubber_audible,
		"last_cue": _last_cue,
		"cue_count": _cue_count,
		"alarm_active": _alarm_hold_seconds > 0.0,
		"exertion": _effective_exertion,
		"breath_db": _breath_db,
		"breath_target_db": _breath_target_db,
		"outside_suited": _outside_suited,
		"hum_mix_target_db": _hum_mix_target_db(),
		"scrubber_volume_db": _scrubber.volume_db,
		"last_tether_ratio": _last_tether_ratio,
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


func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _sfx_pool.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
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
		_scrubber.volume_db = SCRUBBER_ON_DB + (OUTSIDE_SCRUBBER_REDUCTION_DB if _outside_suited else 0.0)
		_scrubber.pitch_scale = (0.7 + 0.5 * condition) if installed else 0.6
	else:
		_scrubber.volume_db = SCRUBBER_OFF_DB


func _on_power_brownout(_bus_id: StringName, _load_ratio: float) -> void:
	_hum_target_db = HUM_BROWNOUT_DB


func _on_power_restored(_bus_id: StringName) -> void:
	_hum_target_db = HUM_HEALTHY_DB


func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if not EVENT_CUES.has(event_name):
		return
	if event_name == &"footstep":
		play_footstep(int(payload.get("variant", 0)))
		_record_cue(event_name)
		return
	var cue: StringName = EVENT_CUES[event_name]
	play_cue(cue, float(payload.get("ratio", 0.9)))


func _record_cue(cue: StringName) -> void:
	_last_cue = cue
	_cue_count += 1


func _poll_breath(delta: float) -> void:
	_effective_exertion = maxf(_exertion, _vitals_exertion_floor())
	_breath_target_db = lerpf(BREATH_MIN_DB, BREATH_MAX_DB, _effective_exertion)
	if _outside_suited:
		_breath_target_db = clampf(_breath_target_db + OUTSIDE_BREATH_BOOST_DB, BREATH_MIN_DB, BREATH_MAX_DB)
	var target_pitch: float = lerpf(BREATH_PITCH_MIN, BREATH_PITCH_MAX, _effective_exertion)
	var smooth_delta: float = maxf(delta, BREATH_MIN_SMOOTH_DELTA)
	_breath_db = move_toward(_breath_db, _breath_target_db, BREATH_SMOOTH_DB_PER_SECOND * smooth_delta)
	_breath.volume_db = _breath_db
	_breath.pitch_scale = move_toward(_breath.pitch_scale, target_pitch, BREATH_SMOOTH_PITCH_PER_SECOND * smooth_delta)


func _poll_outside_mix() -> void:
	_outside_suited = false
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var airlock: Node = tree.get_first_node_in_group(&"airlock_system")
	if airlock == null:
		return
	var suit_worn: bool = false
	if airlock.has_method(&"is_suit_worn"):
		suit_worn = bool(airlock.call(&"is_suit_worn"))
	elif airlock.has_method(&"get_status"):
		var airlock_status: Variant = airlock.call(&"get_status")
		if airlock_status is Dictionary:
			suit_worn = bool((airlock_status as Dictionary).get("suit_worn", false))
	if not suit_worn:
		return
	var atmosphere: Node = tree.get_first_node_in_group(&"atmosphere_system")
	if atmosphere == null or not atmosphere.has_method(&"get_status"):
		return
	var atmosphere_status: Variant = atmosphere.call(&"get_status")
	if not (atmosphere_status is Dictionary):
		return
	var compartments: Variant = (atmosphere_status as Dictionary).get("compartments", {})
	if not (compartments is Dictionary):
		return
	for compartment: Variant in (compartments as Dictionary).values():
		if not (compartment is Dictionary):
			continue
		var status: Dictionary = compartment
		if int(status.get("occupants", 0)) > 0 and float(status.get("pressure_kpa", 0.0)) >= AtmosphereSystem.VACUUM_PRESSURE_KPA:
			return
	_outside_suited = true


func _hum_mix_target_db() -> float:
	return _hum_target_db + (OUTSIDE_HUM_REDUCTION_DB if _outside_suited else 0.0)


func _vitals_exertion_floor() -> float:
	var tree: SceneTree = get_tree()
	if tree == null:
		return 0.0
	var vitals: Node = tree.get_first_node_in_group(&"vitals_system")
	if vitals == null or not vitals.has_method(&"get_status"):
		return 0.0
	var status: Variant = vitals.call(&"get_status")
	if not (status is Dictionary):
		return 0.0
	return _cognition_floor(int((status as Dictionary).get("cognition_level", 0)))


func _cognition_floor(level: int) -> float:
	match clampi(level, 0, 3):
		1:
			return 0.2
		2:
			return 0.45
		3:
			return 0.7
	return 0.0


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
