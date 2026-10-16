extends SceneTree

var _failures: int = 0
var _spawned: Array[Node] = []
var _hull_puncture_signals: int = 0
var _repaired_signals: int = 0
var _last_repaired_id: StringName = &""
var _last_repaired_quality: float = -1.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var existing_bus: Node = _find_root_child(&"EventBus")
	if existing_bus != null:
		root.remove_child(existing_bus)
		existing_bus.free()
	_check(_find_root_child(&"EventBus") == null, "EventBus absent-safe: no EventBus autoload present")

	_test_leak_rate_math()
	_test_puncture_raises_atmosphere_leak()
	_test_patch_removes_largest()
	_test_determinism()
	_test_save_load()
	await _test_procedure_end_to_end()
	_test_no_sealant_refusal()
	_test_no_puncture_refusal()
	_test_data()

	_despawn_all()
	for autoload_name: StringName in [&"EventBus", &"SimClock"]:
		var node: Node = _find_root_child(autoload_name)
		if node != null:
			root.remove_child(node)
			node.free()

	_finish()


func _test_leak_rate_math() -> void:
	var hull: HullSystem = _spawn_hull(_defs(_make_config(&"main")))
	_check(hull.get_puncture_count(&"main") == 0, "leak math: no punctures initially")
	_check(is_equal_approx(hull.get_total_leak_rate(&"main"), 0.002), "leak math: base leak only")
	_check(hull.add_puncture(&"main", 1.0), "leak math: add_puncture accepted")
	_check(hull.get_puncture_count(&"main") == 1, "leak math: puncture count incremented")
	_check(is_equal_approx(hull.get_total_leak_rate(&"main"), 0.006), "leak math: one severity-1 puncture adds puncture leak")
	_check(hull.add_puncture(&"main", 3.0), "leak math: second puncture accepted")
	_check(absf(hull.get_total_leak_rate(&"main") - (0.002 + 4.0 * 0.004)) < 1e-9, "leak math: severities sum")
	_check(not hull.add_puncture(&"main", 0.0), "leak math: zero severity rejected")
	_check(not hull.add_puncture(&"main", -1.0), "leak math: negative severity rejected")
	_check(not hull.add_puncture(&"main", NAN), "leak math: NaN severity rejected")
	_check(not hull.add_puncture(&"main", INF), "leak math: INF severity rejected")
	_check(hull.get_puncture_count(&"main") == 2, "leak math: invalid severities unchanged")
	_check(not hull.add_puncture(&"nope", 1.0), "leak math: unknown compartment rejected")
	var status: Dictionary = hull.get_status()
	_check(status["system_id"] == &"hull", "leak math: status system_id is hull")
	_check(int(status["punctures_total"]) == 2, "leak math: status totals punctures")
	_despawn_all()


func _test_puncture_raises_atmosphere_leak() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var config: CompartmentConfig = _make_config(&"main")
	var atmosphere: AtmosphereSystem = harness.add_atmosphere(_defs(config))
	var hull: HullSystem = _spawn_hull(_defs(config))
	var initial_pressure: float = float(atmosphere.get_compartment_status(&"main")["pressure_kpa"])
	_check(hull.add_puncture(&"main", 1.0), "atmosphere: puncture seeded")
	hull.sim_tick(0.1)
	var status: Dictionary = atmosphere.get_compartment_status(&"main")
	_check(absf(float(status["leak_rate_per_hour"]) - 0.006) < 1e-9, "atmosphere: hull tick pushes total leak rate")
	harness.advance(24.0)
	var later: Dictionary = atmosphere.get_compartment_status(&"main")
	_check(float(later["pressure_kpa"]) < initial_pressure - 1.0, "atmosphere: punctured leak depressurizes over 24 h")
	_check(hull.get_puncture_count(&"main") == 1, "atmosphere: huge MTBF keeps random punctures out of the test")
	_despawn_all()


func _test_patch_removes_largest() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var event_bus: Node = _find_root_child(&"EventBus")
	if event_bus != null:
		event_bus.connect(&"component_repaired", _on_component_repaired)
		event_bus.connect(&"hull_puncture", _on_hull_puncture)
	_hull_puncture_signals = 0
	_repaired_signals = 0
	_last_repaired_id = &""
	_last_repaired_quality = -1.0
	var hull: HullSystem = _spawn_hull(_defs(_make_config(&"main")))
	_check(hull.add_puncture(&"main", 1.0), "patch: small puncture added")
	_check(hull.add_puncture(&"main", 3.0), "patch: large puncture added")
	_check(hull.add_puncture(&"main", 2.0), "patch: medium puncture added")
	_check(_hull_puncture_signals == 3, "patch: typed hull_puncture signal emitted per puncture")
	var rate_before: float = hull.get_total_leak_rate(&"main")
	_check(hull.patch_puncture(&"main", 0.9), "patch: patch_puncture succeeds")
	_check(hull.get_puncture_count(&"main") == 2, "patch: one puncture removed")
	_check(absf(hull.get_total_leak_rate(&"main") - (rate_before - 3.0 * 0.004)) < 1e-9, "patch: largest severity removed")
	var patched_events: Array[Dictionary] = harness.events_named(&"hull_patched")
	_check(patched_events.size() == 1, "patch: hull_patched sim event emitted once")
	if patched_events.size() == 1:
		var payload: Dictionary = patched_events[0]["payload"]
		_check(int(payload["remaining"]) == 2, "patch: hull_patched reports remaining count")
		_check(is_equal_approx(float(payload["quality"]), 0.9), "patch: hull_patched reports quality")
	_check(_repaired_signals == 1 and _last_repaired_id == &"hull_main", "patch: component_repaired typed signal uses hull_<id>")
	_check(is_equal_approx(_last_repaired_quality, 0.9), "patch: component_repaired carries quality")
	_check(hull.patch_puncture(&"main", 1.0), "patch: second patch succeeds")
	_check(hull.patch_puncture(&"main", 1.0), "patch: third patch succeeds")
	_check(hull.get_puncture_count(&"main") == 0, "patch: all punctures cleared")
	_check(not hull.patch_puncture(&"main", 1.0), "patch: empty hull refuses patch")
	_despawn_all()


func _test_determinism() -> void:
	var config_a: CompartmentConfig = _make_config(&"main")
	config_a.puncture_mtbf_hours = 2.0
	var config_b: CompartmentConfig = _make_config(&"main")
	config_b.puncture_mtbf_hours = 2.0
	var hull_a: HullSystem = _spawn_hull(_defs(config_a), 4242)
	var hull_b: HullSystem = _spawn_hull(_defs(config_b), 4242)
	for i: int in 400:
		hull_a.sim_tick(1.0)
		hull_b.sim_tick(1.0)
	var count_a: int = hull_a.get_puncture_count(&"main")
	_check(count_a > 50, "determinism: forced MTBF produces many punctures")
	_check(count_a == hull_b.get_puncture_count(&"main"), "determinism: same seed yields identical puncture counts")
	_check(absf(hull_a.get_total_leak_rate(&"main") - hull_b.get_total_leak_rate(&"main")) < 1e-12, "determinism: identical total leak rates")
	_despawn_all()


func _test_save_load() -> void:
	var config: CompartmentConfig = _make_config(&"main")
	config.puncture_mtbf_hours = 2.0
	var hull: HullSystem = _spawn_hull(_defs(config), 777)
	for i: int in 40:
		hull.sim_tick(1.0)
	var saved: Dictionary = hull.save_state()
	_check(saved["system_id"] == "hull", "save: system_id is hull")
	_check(int(saved["state_version"]) == 1, "save: state_version is 1")
	_check(saved["hull_rng_state"] is String, "save: rng state stringified")
	var compartments: Dictionary = saved["compartments"]
	_check(compartments.has("main"), "save: punctures keyed by string id")
	var punctures: Array = compartments["main"]["punctures"]
	var count_at_save: int = hull.get_puncture_count(&"main")
	_check(punctures.size() == count_at_save, "save: puncture severities captured")
	var saved_sum: float = 0.0
	for severity: Variant in punctures:
		saved_sum += float(severity)
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	_check(parsed is Dictionary, "save: JSON round trip parses to Dictionary")
	var parsed_dict: Dictionary = {}
	if parsed is Dictionary:
		parsed_dict = parsed
	for i: int in 20:
		hull.sim_tick(1.0)
	var continued_count: int = hull.get_puncture_count(&"main")
	_check(continued_count > count_at_save, "save: continued ticks add punctures")
	var clone: HullSystem = _spawn_hull(_defs(config), 999)
	clone.load_state(parsed_dict)
	_check(clone.get_puncture_count(&"main") == count_at_save, "load: puncture count restored from JSON")
	for i: int in 20:
		clone.sim_tick(1.0)
	_check(clone.get_puncture_count(&"main") == continued_count, "load: rng state resumes identical sequence")
	hull.load_state(parsed_dict)
	_check(hull.get_puncture_count(&"main") == count_at_save, "load: original hull restored")
	var restored: Array = hull.get_status()["compartments"][&"main"]["punctures"]
	var restored_sum: float = 0.0
	for severity: Variant in restored:
		restored_sum += float(severity)
	_check(absf(restored_sum - saved_sum) < 1e-9, "load: severity sum restored")
	var int_state: Dictionary = parsed_dict.duplicate(true)
	int_state["hull_rng_state"] = int(str(int_state["hull_rng_state"]))
	var clone_int: HullSystem = _spawn_hull(_defs(config), 123)
	clone_int.load_state(int_state)
	for i: int in 20:
		clone_int.sim_tick(1.0)
	_check(clone_int.get_puncture_count(&"main") == continued_count, "load: int rng state accepted")
	_despawn_all()


func _test_procedure_end_to_end() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var hull: HullSystem = _spawn_hull(_defs(_make_config(&"main")))
	_check(hull.add_puncture(&"main", 1.0), "procedure: puncture seeded")
	var patch: HullPatch = _spawn_patch(&"main")

	var player: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_spawn(player)
	await process_frame
	var stores: Stores = harness.add_stores({})
	_spawned.append(stores)
	var cartridge: SealantCartridge = SealantCartridge.new()
	cartridge.item_id = &"sealant"
	cartridge.item_name = "Sealant cartridge"
	_spawn(cartridge)
	_check(bool(player.call("take_carriable", cartridge)), "procedure: cartridge taken")
	_check(player.call("get_carried_item_id") == &"sealant", "procedure: player carries sealant")

	_check(patch.get_interaction_prompt() == "Clean the breach", "procedure: prompt starts with clean")
	patch.interact(player)
	_check(patch.get_interaction_prompt() == "Fit the patch", "procedure: clean advances to fit")
	patch.interact(player)
	_check(patch.get_interaction_prompt() == "Apply sealant", "procedure: fit advances to seal")
	_check(player.call("has_carried_item"), "procedure: cartridge still carried before seal")
	patch.interact(player)
	_check(bool(player.call("has_carried_item")) and cartridge.get_charge_count() == 0, "procedure: seal leaves the carried shell empty")
	_check(patch.get_interaction_prompt() == "Verify seal", "procedure: seal advances to verify")
	patch.interact(player)
	_check(hull.get_puncture_count(&"main") == 0, "procedure: verify patches the puncture")
	_check(patch.get_interaction_prompt() == "Inspect patch", "procedure: completed prompt shows inspect")
	_check(harness.events_named(&"hull_patch_completed").size() == 1, "procedure: hull_patch_completed emitted")
	patch.interact(player)
	_check(harness.events_named(&"procedure_error").size() == 1, "procedure: interacting with no puncture refuses")
	_check(patch.get_interaction_prompt() == "Inspect patch", "procedure: refusal does not advance")
	_despawn_all()


func _test_no_sealant_refusal() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var hull: HullSystem = _spawn_hull(_defs(_make_config(&"main")))
	harness.add_stores({})
	_check(hull.add_puncture(&"main", 1.0), "no_sealant: puncture seeded")
	var patch: HullPatch = _spawn_patch(&"main")
	patch.interact(null)
	patch.interact(null)
	_check(patch.get_interaction_prompt() == "Apply sealant", "no_sealant: reached seal stage")
	patch.interact(null)
	var errors: Array[Dictionary] = harness.events_named(&"procedure_error")
	_check(errors.size() == 1, "no_sealant: procedure_error emitted")
	if errors.size() == 1:
		_check(StringName(errors[0]["payload"]["reason"]) == &"no_sealant", "no_sealant: reason is no_sealant")
	_check(patch.get_interaction_prompt() == "Apply sealant", "no_sealant: prompt unchanged")
	_check(hull.get_puncture_count(&"main") == 1, "no_sealant: puncture remains")
	var saved: Dictionary = patch.save_state()
	_check(saved["system_id"] == "hull_patch", "no_sealant: save system_id is hull_patch")
	_check(int(saved["state_version"]) == 1, "no_sealant: save state_version is 1")
	_check(int(saved["stage"]) == int(HullPatch.Stage.SEAL), "no_sealant: save captures stage")
	var restored: HullPatch = _spawn_patch(&"main")
	restored.load_state(saved)
	_check(restored.get_interaction_prompt() == "Apply sealant", "no_sealant: load restores stage")
	_despawn_all()


func _test_no_puncture_refusal() -> void:
	var harness := SimHarness.new(self)
	harness.setup_clock()
	var hull: HullSystem = _spawn_hull(_defs(_make_config(&"main")))
	harness.add_stores({&"sealant": 1})
	var patch: HullPatch = _spawn_patch(&"main")
	_check(patch.get_interaction_prompt() == "Inspect patch", "no_puncture: clean prompt inspects when intact")
	patch.interact(null)
	var errors: Array[Dictionary] = harness.events_named(&"procedure_error")
	_check(errors.size() == 1, "no_puncture: procedure_error emitted")
	if errors.size() == 1:
		_check(StringName(errors[0]["payload"]["reason"]) == &"no_puncture", "no_puncture: reason is no_puncture")
	_check(patch.get_interaction_prompt() == "Inspect patch", "no_puncture: stage does not advance")
	_check(hull.get_puncture_count(&"main") == 0, "no_puncture: hull still intact")
	_despawn_all()


func _test_data() -> void:
	var main_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_main.tres")
	var storage_config: CompartmentConfig = load("res://src/data/atmosphere/compartment_storage.tres")
	_check(main_config != null, "data: main compartment loads")
	_check(storage_config != null, "data: storage compartment loads")
	if main_config != null:
		_check(is_equal_approx(main_config.puncture_mtbf_hours, 6000.0), "data: main puncture MTBF default")
		_check(is_equal_approx(main_config.puncture_leak_per_hour, 0.004), "data: main puncture leak default")
	if storage_config != null:
		_check(is_equal_approx(storage_config.puncture_mtbf_hours, 9000.0), "data: storage puncture MTBF")
		_check(is_equal_approx(storage_config.puncture_leak_per_hour, 0.004), "data: storage puncture leak")


func _make_config(id: StringName) -> CompartmentConfig:
	var config := CompartmentConfig.new()
	config.compartment_id = id
	config.volume_m3 = 60.0
	config.leak_rate_per_hour = 0.002
	config.puncture_leak_per_hour = 0.004
	config.puncture_mtbf_hours = 1.0e12
	return config


func _defs(config: CompartmentConfig) -> Array[CompartmentConfig]:
	var defs: Array[CompartmentConfig] = [config]
	return defs


func _spawn_hull(configs: Array[CompartmentConfig], hull_seed: int = 20260920) -> HullSystem:
	var hull := HullSystem.new()
	hull.compartment_defs = configs
	hull.hull_seed = hull_seed
	_spawn(hull)
	return hull


func _spawn_patch(compartment_id: StringName) -> HullPatch:
	var patch := HullPatch.new()
	patch.compartment_id = compartment_id
	_spawn(patch)
	return patch


func _spawn(node: Node) -> void:
	root.add_child(node)
	_spawned.append(node)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _on_hull_puncture(_compartment_id: StringName, _severity: float) -> void:
	_hull_puncture_signals += 1


func _on_component_repaired(component_id: StringName, repair_quality: float) -> void:
	_repaired_signals += 1
	_last_repaired_id = component_id
	_last_repaired_quality = repair_quality


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_hull")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
