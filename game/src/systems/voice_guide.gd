## Modular Voice Guide System for the initial 24-hour orientation loop.
## Emits voice transmissions, synchronizes with HUD/CRT UI elements, and concludes
## after Day 1 rest, leaving subsequent problem-solving entirely to the operator.
class_name VoiceGuideSystem
extends Node

const STEPS: Array[Dictionary] = [
	{
		"id": &"status_check",
		"title": "ORIENTATION 01: STATUS READOUT",
		"objective": "VERIFY SHIP STATUS AT A STATUS PANEL",
		"voice_text": "Operator awake. Cycle zero initiated. Access a ship status panel to verify life support and power baseline.",
		"voice_audio": "res://assets/audio/voice/guide_step_0.ogg",
		"completion_event": &"status_panel_opened",
	},
	{
		"id": &"inspect_rounds",
		"title": "ORIENTATION 02: WALK ROUNDS",
		"objective": "INSPECT CRITICAL SHIP SYSTEMS",
		"voice_text": "Baseline confirmed. Walk rounds to inspect machinery. Note that life support and electrical circuits continuously degrade.",
		"voice_audio": "res://assets/audio/voice/guide_step_1.ogg",
		"completion_event": &"compartment_entered",
	},
	{
		"id": &"acquire_tools",
		"title": "ORIENTATION 03: DIAGNOSTIC GEAR",
		"objective": "ACQUIRE A DIAGNOSTIC TOOL",
		"voice_text": "Physical systems acknowledged. Diagnostic tools are stowed on tool racks. Multimeter and scanner are needed to trace hidden faults.",
		"voice_audio": "res://assets/audio/voice/guide_step_2.ogg",
		"completion_event": &"item_taken",
	},
	{
		"id": &"rest_cycle",
		"title": "ORIENTATION 04: REST CYCLE",
		"objective": "COMPLETE SHIFT DUTIES AND RETIRE TO BUNK",
		"voice_text": "Tools located. Complete necessary repairs and triage. When your work shift concludes, retire to the quarters bunk to advance the cycle.",
		"voice_audio": "res://assets/audio/voice/guide_step_3.ogg",
		"completion_event": &"slept",
	},
]

const CONCLUSION_VOICE_TEXT: String = "Twenty-four hour orientation concluded. Advisory subsystem offline. All ongoing ship diagnosis, maintenance, and triage are the sole responsibility of the operator."
const CONCLUSION_TITLE: String = "ORIENTATION COMPLETE"
const CONCLUSION_OBJECTIVE: String = "ADVISORY SUBSYSTEM OFFLINE"
const CONCLUSION_AUDIO: String = "res://assets/audio/voice/guide_conclusion.ogg"

@export var enabled: bool = true
@export var initial_delay_seconds: float = 1.0
@export var step_delay_seconds: float = 1.2
@export var voice_volume_db: float = -3.0

var current_step_index: int = 0
var is_active: bool = false
var is_completed: bool = false
var is_speaking: bool = false
var completed_steps: Array[StringName] = []

var _chime_player: AudioStreamPlayer
var _speech_player: AudioStreamPlayer
var _delay_timer: float = 0.0
var _pending_step: int = -1


func _ready() -> void:
	add_to_group(&"voice_guide_system")
	add_to_group(&"saveable")
	_ensure_audio()

	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"sim_event", _on_sim_event)

	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		if not sim_clock.is_connected(&"day_changed", _on_day_changed):
			sim_clock.connect(&"day_changed", _on_day_changed)
		if not sim_clock.is_connected(&"hour_advanced", _on_hour_advanced):
			sim_clock.connect(&"hour_advanced", _on_hour_advanced)

	if enabled and not is_completed:
		_check_day_limit()
		if not is_completed:
			_schedule_step(current_step_index, initial_delay_seconds)


func _ensure_audio() -> void:
	if _chime_player == null:
		_chime_player = AudioStreamPlayer.new()
		_chime_player.name = "VoiceChime"
		_chime_player.volume_db = voice_volume_db - 2.0
		add_child(_chime_player)

	if _speech_player == null:
		_speech_player = AudioStreamPlayer.new()
		_speech_player.name = "VoiceSpeech"
		_speech_player.volume_db = voice_volume_db
		_speech_player.finished.connect(_on_speech_finished)
		add_child(_speech_player)


func _process(delta: float) -> void:
	if _delay_timer > 0.0:
		_delay_timer -= delta
		if _delay_timer <= 0.0:
			_delay_timer = 0.0
			if _pending_step >= 0:
				var step_to_start: int = _pending_step
				_pending_step = -1
				_start_step(step_to_start)


func get_current_step() -> Dictionary:
	if current_step_index >= 0 and current_step_index < STEPS.size():
		return STEPS[current_step_index]
	return {}


func get_current_step_index() -> int:
	return current_step_index


func is_active_guide() -> bool:
	return is_active and not is_completed


func is_guide_completed() -> bool:
	return is_completed


func speak(text: String, title: String = "", objective: String = "", is_conclusion: bool = false, audio_path: String = "") -> void:
	is_speaking = true
	_ensure_audio()
	var step_id: StringName = &"conclusion" if is_conclusion else (get_current_step().get("id", &"") as StringName)

	var stream: AudioStream = null
	if not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		stream = load(audio_path) as AudioStream

	if stream == null:
		stream = ProcAudio.make_voice_stream(text)

	var stream_duration: float = stream.get_length() if stream != null else maxf(float(text.length()) * 0.065, 2.5)

	if is_inside_tree():
		_chime_player.stream = ProcAudio.make_voice_chime()
		_chime_player.play()

		_speech_player.stream = stream
		var tree: SceneTree = get_tree()
		if tree != null:
			tree.create_timer(0.35).timeout.connect(func() -> void:
				if not is_instance_valid(self) or not is_speaking:
					return
				_speech_player.play()
			)
		else:
			_speech_player.play()

	_emit_sim_event(&"voice_guide_spoken", {
		"step_id": step_id,
		"title": title,
		"text": text,
		"objective": objective,
		"is_conclusion": is_conclusion,
		"duration": stream_duration + 0.35,
	})


func advance_step() -> void:
	if is_completed or not enabled:
		return
	var current: Dictionary = get_current_step()
	var step_id: StringName = current.get("id", &"") as StringName
	if step_id != &"" and not completed_steps.has(step_id):
		completed_steps.append(step_id)

	_emit_sim_event(&"voice_guide_step_completed", {
		"step_id": step_id,
		"step_index": current_step_index,
	})

	current_step_index += 1
	if current_step_index >= STEPS.size():
		complete_guide()
	else:
		_schedule_step(current_step_index, step_delay_seconds)


func complete_guide() -> void:
	if is_completed:
		return
	is_completed = true
	is_active = false
	_pending_step = -1
	speak(CONCLUSION_VOICE_TEXT, CONCLUSION_TITLE, CONCLUSION_OBJECTIVE, true, CONCLUSION_AUDIO)
	_emit_sim_event(&"voice_guide_completed", {
		"completed_steps": completed_steps.duplicate(),
	})


func _schedule_step(step_idx: int, delay_sec: float) -> void:
	_pending_step = step_idx
	_delay_timer = maxf(delay_sec, 0.05)


func _start_step(step_idx: int) -> void:
	if is_completed or not enabled:
		return
	if step_idx < 0 or step_idx >= STEPS.size():
		complete_guide()
		return
	current_step_index = step_idx
	is_active = true
	var step: Dictionary = STEPS[step_idx]
	speak(
		String(step.get("voice_text", "")),
		String(step.get("title", "")),
		String(step.get("objective", "")),
		false,
		String(step.get("voice_audio", ""))
	)



func _on_sim_event(event_name: StringName, payload: Dictionary) -> void:
	if is_completed or not is_active or not enabled:
		return
	var step: Dictionary = get_current_step()
	if step.is_empty():
		return

	var req_event: StringName = step.get("completion_event", &"") as StringName
	match req_event:
		&"status_panel_opened":
			if event_name == &"status_panel_opened":
				advance_step()
		&"compartment_entered":
			if event_name == &"compartment_entered":
				var comp_id: StringName = StringName(payload.get("compartment_id", &""))
				if comp_id != &"cockpit" and comp_id != &"":
					advance_step()
			elif event_name in [&"breaker_toggled", &"scrubber_housing_opened", &"scrubber_power_changed"]:
				advance_step()
		&"item_taken":
			if event_name == &"item_taken" and StringName(payload.get("item_id", &"")) in [&"multimeter", &"scanner"]:
				advance_step()
		&"slept":
			if event_name == &"slept":
				advance_step()


func _on_day_changed(day: int) -> void:
	if day > 1 and not is_completed:
		complete_guide()


func _on_hour_advanced(_hour: int) -> void:
	_check_day_limit()


func _check_day_limit() -> void:
	var sim_clock: Node = _get_autoload(&"SimClock")
	if sim_clock != null:
		var hours: float = float(sim_clock.call("get_total_hours"))
		var day: int = int(sim_clock.call("get_day"))
		if (day > 1 or hours >= 24.0) and not is_completed:
			complete_guide()


func _on_speech_finished() -> void:
	is_speaking = false


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


func _emit_sim_event(event_name: StringName, payload: Dictionary = {}) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.call("emit_event", event_name, payload)


func save_state() -> Dictionary:
	return {
		"current_step_index": current_step_index,
		"is_active": is_active,
		"is_completed": is_completed,
		"completed_steps": completed_steps.duplicate(),
	}


func load_state(data: Dictionary) -> void:
	current_step_index = clampi(int(data.get("current_step_index", 0)), 0, STEPS.size())
	is_active = bool(data.get("is_active", false))
	is_completed = bool(data.get("is_completed", false))
	completed_steps.clear()
	var raw_steps: Variant = data.get("completed_steps", [])
	if raw_steps is Array:
		for s: Variant in raw_steps:
			completed_steps.append(StringName(s))

	if is_completed:
		is_active = false
		_pending_step = -1
		if _speech_player != null and _speech_player.playing:
			_speech_player.stop()
		if _chime_player != null and _chime_player.playing:
			_chime_player.stop()
	elif enabled and is_active:
		_start_step(current_step_index)
