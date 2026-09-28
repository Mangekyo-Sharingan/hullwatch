## Unit test suite for VoiceGuideSystem, procedural voice audio, and GuideOverlay.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var existing: Node = _find_root_child(autoload_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()

	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)

	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	_test_audio_synthesis()
	_test_step_progression(event_bus, sim_clock)
	_test_24h_cutoff(event_bus, sim_clock)
	_test_save_load_round_trip()
	_test_guide_overlay(event_bus)

	_finish()


func _test_audio_synthesis() -> void:
	var chime: AudioStreamWAV = ProcAudio.make_voice_chime()
	_check(chime != null, "voice chime stream created")
	_check(chime.get_length() > 0.2, "voice chime duration is positive (%.2f s)" % chime.get_length())

	var speech: AudioStreamWAV = ProcAudio.make_voice_stream("Operator awake. Verify ship status.")
	_check(speech != null, "voice speech stream created")
	_check(speech.get_length() > 0.5, "voice speech duration is positive (%.2f s)" % speech.get_length())
	_check(speech.mix_rate == ProcAudio.MIX_RATE, "voice speech uses standard mix rate")

	for i: int in VoiceGuideSystem.STEPS.size():
		var step: Dictionary = VoiceGuideSystem.STEPS[i]
		var audio_path: String = String(step.get("voice_audio", ""))
		_check(not audio_path.is_empty(), "step %d has voice_audio defined" % i)
		_check(ResourceLoader.exists(audio_path), "step %d voice_audio exists: %s" % [i, audio_path])
		var stream: AudioStream = load(audio_path) as AudioStream
		_check(stream != null, "step %d voice_audio loads as AudioStream" % i)
		_check(stream.get_length() > 1.0, "step %d voice_audio duration is valid (%.2f s)" % [i, stream.get_length() if stream != null else 0.0])

	var conc_audio: String = VoiceGuideSystem.CONCLUSION_AUDIO
	_check(ResourceLoader.exists(conc_audio), "conclusion voice_audio exists: %s" % conc_audio)
	var conc_stream: AudioStream = load(conc_audio) as AudioStream
	_check(conc_stream != null, "conclusion voice_audio loads as AudioStream")
	_check(conc_stream.get_length() > 1.0, "conclusion voice_audio duration is valid (%.2f s)" % (conc_stream.get_length() if conc_stream != null else 0.0))



func _test_step_progression(event_bus: Node, _sim_clock: Node) -> void:
	var guide := VoiceGuideSystem.new()
	guide.initial_delay_seconds = 0.01
	guide.step_delay_seconds = 0.01
	root.add_child(guide)

	_check(guide.get_current_step_index() == 0, "guide begins at step 0")
	var step0: Dictionary = guide.get_current_step()
	_check(step0.get("id") == &"status_check", "initial step is status_check")

	guide._process(0.1)
	_check(guide.is_active_guide(), "guide is active after initial start")

	# Complete Step 0: status_panel_opened
	event_bus.call("emit_event", &"status_panel_opened", {"compartment_id": &"cockpit"})
	_check(guide.get_current_step_index() == 1, "status panel opened advances to step 1")
	var step1: Dictionary = guide.get_current_step()
	_check(step1.get("id") == &"inspect_rounds", "step 1 is inspect_rounds")

	# Complete Step 1: compartment_entered
	event_bus.call("emit_event", &"compartment_entered", {"compartment_id": &"engine_bay"})
	_check(guide.get_current_step_index() == 2, "compartment entered advances to step 2")
	var step2: Dictionary = guide.get_current_step()
	_check(step2.get("id") == &"acquire_tools", "step 2 is acquire_tools")

	# Complete Step 2: item_taken
	event_bus.call("emit_event", &"item_taken", {"item_id": &"wrench"})
	_check(guide.get_current_step_index() == 2, "unrelated gear does not complete diagnostic step")
	event_bus.call("emit_event", &"item_taken", {"item_id": &"multimeter"})
	_check(guide.get_current_step_index() == 3, "item taken advances to step 3")
	var step3: Dictionary = guide.get_current_step()
	_check(step3.get("id") == &"rest_cycle", "step 3 is rest_cycle")

	# Complete Step 3: slept
	event_bus.call("emit_event", &"slept", {"hours": 8.0, "day": 1})
	_check(guide.is_guide_completed(), "sleeping concludes the 24-hour orientation guide")
	_check(not guide.is_active_guide(), "guide is no longer active after completion")

	# Further events must not re-advance or crash
	event_bus.call("emit_event", &"status_panel_opened", {})
	_check(guide.is_guide_completed(), "guide stays permanently completed")

	guide.free()


func _test_24h_cutoff(event_bus: Node, sim_clock: Node) -> void:
	sim_clock.call("fast_forward", 25.0)

	var guide := VoiceGuideSystem.new()
	guide.initial_delay_seconds = 0.01
	root.add_child(guide)

	_check(guide.is_guide_completed(), "clock past 24h immediately completes orientation")

	guide.free()
	# Reset clock back
	sim_clock.set("sim_seconds", 0.0)
	sim_clock.set("tick_index", 0)


func _test_save_load_round_trip() -> void:
	var guide_a := VoiceGuideSystem.new()
	guide_a.current_step_index = 2
	guide_a.is_active = true
	guide_a.is_completed = false
	guide_a.completed_steps = [&"status_check", &"inspect_rounds"]

	var saved_state: Dictionary = guide_a.save_state()
	_check(int(saved_state["current_step_index"]) == 2, "save preserves current_step_index")
	_check(bool(saved_state["is_active"]), "save preserves is_active")
	_check(not bool(saved_state["is_completed"]), "save preserves is_completed")

	var guide_b := VoiceGuideSystem.new()
	guide_b.load_state(saved_state)
	_check(guide_b.current_step_index == 2, "load restores current_step_index")
	_check(guide_b.is_active, "load restores is_active")
	_check(not guide_b.is_completed, "load restores is_completed")
	_check(guide_b.completed_steps.size() == 2, "load restores completed_steps")

	# Test completed state round-trip
	guide_a.current_step_index = 4
	guide_a.is_completed = true
	guide_a.is_active = false
	var saved_completed: Dictionary = guide_a.save_state()

	var guide_c := VoiceGuideSystem.new()
	guide_c.load_state(saved_completed)
	_check(guide_c.is_completed, "load restores completed guide state")
	_check(not guide_c.is_active, "completed guide loads inactive")

	guide_a.free()
	guide_b.free()
	guide_c.free()


func _test_guide_overlay(event_bus: Node) -> void:
	var overlay := GuideOverlay.new()
	root.add_child(overlay)

	_check(not overlay.is_overlay_visible(), "overlay starts hidden")

	event_bus.call("emit_event", &"voice_guide_spoken", {
		"step_id": &"status_check",
		"title": "ORIENTATION 01: STATUS READOUT",
		"objective": "CHECK SHIP STATUS AT A STATUS PANEL",
		"text": "Operator awake. Cycle zero initiated.",
		"is_conclusion": false,
	})

	_check(overlay.is_overlay_visible(), "overlay becomes visible when voice guide speaks")
	_check(overlay.get_objective_text().contains("CHECK SHIP STATUS"), "objective text displayed")
	_check(overlay.get_transcript_text().contains("Operator awake"), "transcript text displayed")

	event_bus.call("emit_event", &"voice_guide_step_completed", {
		"step_id": &"status_check",
		"step_index": 0,
	})

	event_bus.call("emit_event", &"voice_guide_completed", {
		"completed_steps": [&"status_check"],
	})

	overlay.free()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_voice_guide")
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


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null
