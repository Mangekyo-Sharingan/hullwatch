## Footsteps and breath: procedural factories, player stride emission, and director exertion mix.
extends SceneTree

const MIX_RATE: float = 22050.0

var _failures: int = 0


class StubVitals:
	extends Node

	func get_status() -> Dictionary:
		return {"cognition_level": 3}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_footstep_factory()
	_test_breath_factory()
	_remove_root_child(&"AudioDirector")
	_remove_root_child(&"EventBus")
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	await _test_player_footsteps(event_bus)
	await _test_director_breath(event_bus)
	_finish()


func _test_footstep_factory() -> void:
	var streams: Array[AudioStreamWAV] = []
	for variant: int in 3:
		streams.append(ProcAudio.make_footstep(variant))
	for variant: int in 3:
		var stream: AudioStreamWAV = streams[variant]
		_check(stream != null, "footstep %d non-null" % variant)
		_check(stream.data.size() > 0, "footstep %d has pcm data" % variant)
		_check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "footstep %d is 16-bit" % variant)
		_check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "footstep %d does not loop" % variant)
		var seconds: float = float(stream.data.size()) / 2.0 / MIX_RATE
		_check(seconds >= 0.10 and seconds <= 0.16, "footstep %d is 0.10-0.16 s (%.3f)" % [variant, seconds])
	_check(streams[0].data != streams[1].data, "footstep variants 0 and 1 differ")
	_check(streams[1].data != streams[2].data, "footstep variants 1 and 2 differ")
	_check(streams[0].data != streams[2].data, "footstep variants 0 and 2 differ")
	_check(ProcAudio.make_footstep(7).data == streams[2].data, "footstep variant clamps high")
	_check(ProcAudio.make_footstep(-2).data == streams[0].data, "footstep variant clamps low")
	_check(ProcAudio.make_footstep(1).data == streams[1].data, "footstep is deterministic")


func _test_breath_factory() -> void:
	var stream: AudioStreamWAV = ProcAudio.make_breath_loop()
	_check(stream != null, "breath non-null")
	_check(stream.data.size() > 0, "breath has pcm data")
	_check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "breath is 16-bit")
	_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "breath loops forward")
	_check(stream.loop_begin == 0, "breath loop starts at 0")
	_check(stream.loop_end == int(stream.data.size() / 2.0), "breath loop spans whole sample")
	_check(stream.data.size() / 2 > MIX_RATE * 3, "breath loop is several seconds long")
	_check(ProcAudio.make_breath_loop().data == stream.data, "breath is deterministic")


func _test_player_footsteps(event_bus: Node) -> void:
	var captured: Array[Dictionary] = []
	event_bus.sim_event.connect(func(event_name: StringName, payload: Dictionary) -> void:
		if event_name == &"footstep":
			captured.append(payload)
	)
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	_check(player_scene != null, "player scene loads")
	if player_scene == null:
		return
	var player: CharacterBody3D = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var fired: int = player.advance_footsteps(3.6)
	_check(fired == 3, "advance_footsteps(3.6) fires three steps")
	_check(player.get_step_count() == 3, "step count is three")
	_check(captured.size() == 3, "three footstep events captured")
	var variants: Array[int] = []
	for payload: Dictionary in captured:
		variants.append(int(payload.get("variant", -1)))
	_check(variants.size() == 3 and variants[0] == 0 and variants[1] == 1 and variants[2] == 2, "footstep variants cycle 0,1,2")
	_check(player.advance_footsteps(0.5) == 0, "advance_footsteps(0.5) fires none")
	_check(player.get_planar_speed() >= 0.0, "planar speed is non-negative")
	player.free()


func _test_director_breath(event_bus: Node) -> void:
	var audio_director: Node = load("res://src/autoload/audio_director.gd").new()
	audio_director.name = &"AudioDirector"
	root.add_child(audio_director)
	var vitals: StubVitals = StubVitals.new()
	vitals.add_to_group(&"vitals_system")
	root.add_child(vitals)

	event_bus.call(&"emit_event", &"footstep", {"variant": 2})
	var state: Dictionary = audio_director.call(&"get_debug_state")
	_check(state["last_cue"] == &"footstep", "footstep event records the footstep cue")
	_check(int(state["cue_count"]) >= 1, "footstep event counts toward cue bookkeeping")
	_check(float(state["breath_db"]) <= -30.0, "breath starts quiet")

	for i: int in 3:
		await process_frame
	state = audio_director.call(&"get_debug_state")
	_check(float(state["breath_db"]) > -30.0, "cognition exertion lifts breath volume")
	_check(absf(float(state["exertion"]) - 0.7) < 0.001, "effective exertion reaches cognition floor")

	audio_director.call(&"set_exertion", 0.0)
	_check(float(audio_director.call(&"get_exertion")) == 0.0, "exertion clamps at zero")
	vitals.free()
	for i: int in 30:
		await process_frame
	state = audio_director.call(&"get_debug_state")
	_check(float(state["breath_db"]) < -30.0, "breath returns toward baseline")
	audio_director.free()


func _remove_root_child(node_name: StringName) -> void:
	var existing: Node = _find_root_child(node_name)
	if existing != null:
		root.remove_child(existing)
		existing.free()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_footsteps")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
