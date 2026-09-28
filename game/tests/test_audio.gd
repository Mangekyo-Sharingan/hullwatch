extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_test_factory_output()
	_test_determinism()
	await _test_audio_director()
	_finish()


func _test_factory_output() -> void:
	var streams: Dictionary = {
		&"hum": ProcAudio.make_hum(),
		&"fan_loop": ProcAudio.make_fan_loop(),
		&"click": ProcAudio.make_click(),
		&"thunk": ProcAudio.make_thunk(),
		&"buzz": ProcAudio.make_buzz(),
		&"alarm": ProcAudio.make_alarm(),
		&"drone": ProcAudio.make_drone(),
		&"beep": ProcAudio.make_beep(),
	}
	for stream_name: StringName in streams:
		var stream: AudioStreamWAV = streams[stream_name]
		_check(stream != null, "%s non-null" % String(stream_name))
		_check(stream.data.size() > 0, "%s has pcm data" % String(stream_name))
		_check(stream.format == AudioStreamWAV.FORMAT_16_BITS, "%s is 16-bit" % String(stream_name))

	for stream_name: StringName in [&"hum", &"fan_loop", &"alarm", &"drone"]:
		var stream: AudioStreamWAV = streams[stream_name]
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "%s loops forward" % String(stream_name))
		_check(stream.loop_begin == 0, "%s loop starts at 0" % String(stream_name))
		_check(stream.loop_end == int(stream.data.size() / 2.0), "%s loop spans whole sample" % String(stream_name))

	for stream_name: StringName in [&"click", &"thunk", &"buzz", &"beep"]:
		var stream: AudioStreamWAV = streams[stream_name]
		_check(stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "%s does not loop" % String(stream_name))


func _test_determinism() -> void:
	var first_click: AudioStreamWAV = ProcAudio.make_click()
	var second_click: AudioStreamWAV = ProcAudio.make_click()
	_check(first_click.data == second_click.data, "make_click is deterministic")
	var first_hum: AudioStreamWAV = ProcAudio.make_hum()
	var second_hum: AudioStreamWAV = ProcAudio.make_hum()
	_check(first_hum.data == second_hum.data, "make_hum is deterministic")


func _test_audio_director() -> void:
	for node_name: StringName in [&"AudioDirector", &"EventBus"]:
		var existing: Node = _find_root_child(node_name)
		if existing != null:
			root.remove_child(existing)
			existing.free()

	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)

	var audio_director: Node = load("res://src/autoload/audio_director.gd").new()
	audio_director.name = &"AudioDirector"
	root.add_child(audio_director)
	await process_frame

	_check(int(audio_director.call(&"get_sfx_pool_size")) == 4, "sfx pool has four players")
	_check(not bool(audio_director.call(&"get_debug_state")["outside_suited"]), "missing airlock and atmosphere keeps interior mix")

	audio_director.call(&"play_cue", &"relay")
	var state: Dictionary = audio_director.call(&"get_debug_state")
	_check(state["last_cue"] == &"relay", "relay cue recorded")
	_check(int(state["cue_count"]) == 1, "cue_count is 1 after relay")

	audio_director.call(&"play_cue", &"procedure_error")
	state = audio_director.call(&"get_debug_state")
	_check(int(state["cue_count"]) == 2, "cue_count is 2 after procedure_error")

	audio_director.call(&"play_cue", &"nope")
	state = audio_director.call(&"get_debug_state")
	_check(int(state["cue_count"]) == 2, "unknown cue does not count")

	event_bus.emit_signal(&"power_brownout", &"main", 1.4)
	await process_frame
	state = audio_director.call(&"get_debug_state")
	_check(float(state["hum_target_db"]) < -20.0, "brownout drops hum target")

	event_bus.emit_signal(&"power_restored", &"main")
	await process_frame
	state = audio_director.call(&"get_debug_state")
	_check(float(state["hum_target_db"]) > -20.0, "power restored lifts hum target")

	event_bus.call(&"emit_event", &"breaker_toggled", {"circuit_id": &"lighting"})
	state = audio_director.call(&"get_debug_state")
	_check(state["last_cue"] == &"relay", "breaker_toggled maps to relay")

	event_bus.call(&"emit_event", &"probe_scanned", {"system": &"power_system"})
	state = audio_director.call(&"get_debug_state")
	_check(state["last_cue"] == &"beep", "probe_scanned maps to beep")
	var cue_count_before_tether: int = int(state["cue_count"])
	event_bus.call(&"emit_event", &"tether_strained", {"ratio": 0.95})
	state = audio_director.call(&"get_debug_state")
	_check(state["last_cue"] == &"tether_warning", "tether_strained maps to warning cue")
	_check(int(state["cue_count"]) == cue_count_before_tether + 1, "tether strain produces one cue")
	_check(is_equal_approx(float(state["last_tether_ratio"]), 0.95), "tether warning reads extension ratio")
	_check(is_equal_approx((audio_director.get_node("Sfx0") as AudioStreamPlayer).volume_db, -12.0), "tether warning stays restrained")

	var atmosphere: AtmosphereSystem = AtmosphereSystem.new()
	var config: CompartmentConfig = CompartmentConfig.new()
	config.compartment_id = &"main"
	config.volume_m3 = 60.0
	var defs: Array[CompartmentConfig] = [config]
	atmosphere.compartment_defs = defs
	root.add_child(atmosphere)
	await process_frame
	await process_frame
	_check(not bool(audio_director.call(&"get_debug_state")["outside_suited"]), "missing airlock keeps atmosphere mix interior")

	var airlock: AirlockSystem = AirlockSystem.new()
	root.add_child(airlock)
	await process_frame
	_check(airlock.equip_suit(), "suit equips for exterior mix test")
	atmosphere.set_occupants(&"main", 0)

	atmosphere.set_scrubber_powered(&"main", true)
	atmosphere.set_filter_installed(&"main", true)
	await process_frame
	await process_frame
	state = audio_director.call(&"get_debug_state")
	_check(bool(state["scrubber_audible"]), "scrubber audible when powered with filter")
	_check(bool(state["outside_suited"]), "suited operator outside pressurized rooms gets exterior mix")
	_check(is_equal_approx(float(state["hum_mix_target_db"]), -24.0), "ship hum recedes outside")
	_check(is_equal_approx(float(state["scrubber_volume_db"]), -36.0), "scrubber recedes outside")
	_check(is_equal_approx(float(state["breath_target_db"]), -30.0), "breathing becomes more present outside")

	atmosphere.set_occupants(&"main", 1)
	await process_frame
	state = audio_director.call(&"get_debug_state")
	_check(not bool(state["outside_suited"]), "pressurized compartment re-entry restores interior mix")
	_check(is_equal_approx(float(state["hum_mix_target_db"]), -14.0), "ship hum returns on re-entry")
	_check(is_equal_approx(float(state["scrubber_volume_db"]), -22.0), "scrubber returns on re-entry")
	_check(is_equal_approx(float(state["breath_target_db"]), -40.0), "breathing returns to interior baseline")

	atmosphere.set_scrubber_powered(&"main", false)
	await process_frame
	await process_frame
	state = audio_director.call(&"get_debug_state")
	_check(not bool(state["scrubber_audible"]), "scrubber silent when unpowered")

	atmosphere.free()
	airlock.free()
	audio_director.free()
	event_bus.free()


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_audio")
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
