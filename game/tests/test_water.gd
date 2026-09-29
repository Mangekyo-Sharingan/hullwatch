extends SceneTree

const RECLAIMER_MODEL_PATH: String = "res://assets/models/hullwatch/machinery/hw_water_reclaimer.glb"

var _failures: int = 0
var _harness: SimHarness
var _spawned: Array[Node] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	_harness = SimHarness.new(self)
	_harness.setup_clock()

	_test_consumption_drains_potable()
	_test_reclaimer_power_gate()
	_test_reclaimer_without_power_system()
	_test_water_low_event()
	_test_depletion_and_contamination_events()
	_test_status_and_maintenance()
	_test_reclaimer_procedure()
	_test_reclaimer_no_cartridge()
	_test_save_load_round_trip()

	_finish()


func _test_consumption_drains_potable() -> void:
	_harness.clear_events()
	var config: CompartmentConfig = _harness.make_compartment(&"main")
	config.initial_occupants = 1
	var atmosphere: AtmosphereSystem = _harness.add_atmosphere([config])
	_spawned.append(atmosphere)
	var water: WaterSystem = _spawn_water(120.0, 40.0)
	water.set_reclaimer_powered(false)
	var before: float = water.potable_l
	_harness.advance(4.0)
	var after: float = water.potable_l
	var consumed: float = before - after
	_check(absf(consumed - 0.24) <= 0.5, "consumption: 1 occupant over 4 h drains the expected litres")
	_check(consumed > 0.0, "consumption: potable falls while occupied")
	_check(water.greywater_l > 40.0, "consumption: greywater accumulates from the draw")
	_despawn_all()


func _test_reclaimer_power_gate() -> void:
	_harness.clear_events()
	var power: PowerSystem = _harness.add_power([_harness.make_circuit(&"life_support", 120.0, 0)])
	_spawned.append(power)
	power.set_breaker(&"life_support", false)
	var water: WaterSystem = _spawn_water(50.0, 40.0)
	water.set_reclaimer_powered(true)
	_harness.advance(1.0)
	_check(is_equal_approx(water.greywater_l, 40.0), "gate: breaker off leaves greywater untouched")
	_check(is_equal_approx(water.potable_l, 50.0), "gate: breaker off leaves potable untouched")
	power.set_breaker(&"life_support", true)
	_harness.advance(1.0)
	_check(water.greywater_l < 39.5, "gate: breaker on recycles greywater")
	_check(water.potable_l > 50.5, "gate: breaker on returns potable")
	_check(bool(water.get_status()["reclaimer_active"]), "gate: reclaimer reports active while recycling")
	var greywater_before: float = water.greywater_l
	water.set_reclaimer_powered(false)
	_harness.advance(0.5)
	_check(is_equal_approx(water.greywater_l, greywater_before), "gate: local switch off stops recycling")
	_check(not bool(water.get_status()["reclaimer_active"]), "gate: reclaimer reports inactive on local switch off")
	_despawn_all()


func _test_reclaimer_without_power_system() -> void:
	_harness.clear_events()
	var water: WaterSystem = _spawn_water(50.0, 10.0)
	water.set_reclaimer_powered(true)
	_harness.advance(1.0)
	_check(water.greywater_l < 10.0, "no power system: circuit treated as available")
	_check(water.potable_l > 50.0, "no power system: potable recovered")
	_despawn_all()


func _test_water_low_event() -> void:
	_harness.clear_events()
	var water: WaterSystem = _spawn_water(40.0, 0.0)
	water.set_reclaimer_powered(false)
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_low").is_empty(), "low: no event above 25 percent")
	water.potable_l = 36.0
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_low").size() == 1, "low: fires once below 25 percent")
	_harness.advance(1.0)
	_check(_harness.events_named(&"water_low").size() == 1, "low: does not repeat while still low")
	water.potable_l = 50.0
	_harness.advance(0.1)
	water.potable_l = 36.0
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_low").size() == 2, "low: re-arms above 30 percent")
	_despawn_all()


func _test_depletion_and_contamination_events() -> void:
	_harness.clear_events()
	var water: WaterSystem = _spawn_water(2.0, 0.0)
	water.set_reclaimer_powered(false)
	water.potable_l = 0.0
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_depleted").size() == 1, "depleted: fires once at zero potable")
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_depleted").size() == 1, "depleted: does not repeat while empty")
	water.potable_l = 2.0
	_harness.advance(0.1)
	water.potable_l = 0.0
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_depleted").size() == 2, "depleted: re-arms above 1 L")
	water.set_reclaimer_powered(true)
	water.greywater_l = 40.0
	water.contamination = 0.499
	_harness.advance(1.0)
	_check(_harness.events_named(&"water_contaminated").size() == 1, "contaminated: fires once above 50 percent")
	_check(water.purge(), "contaminated: purge accepted")
	water.contamination = 0.52
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_contaminated").size() == 2, "contaminated: re-arms after a purge")
	_despawn_all()


func _test_status_and_maintenance() -> void:
	_harness.clear_events()
	var water: WaterSystem = _spawn_water(100.0, 20.0)
	water.contamination = 0.7
	var status: Dictionary = water.get_status()
	_check(status["system_id"] == &"water", "status: system_id is water")
	_check(is_equal_approx(float(status["potable_l"]), 100.0), "status: potable reported")
	_check(is_equal_approx(float(status["potable_capacity_l"]), 150.0), "status: capacity reported")
	_check(absf(float(status["potable_fraction"]) - (100.0 / 150.0)) < 1e-9, "status: potable fraction reported")
	_check(is_equal_approx(float(status["greywater_l"]), 20.0), "status: greywater reported")
	_check(is_equal_approx(float(status["contamination"]), 0.7), "status: contamination reported")
	_check(bool(status["reclaimer_powered"]), "status: reclaimer switch reported")
	_check(absf(float(status["efficiency"]) - 0.65 * (1.0 - 0.7)) < 1e-9, "status: efficiency scales with contamination")
	_check(water.purge(), "purge: returns true when contaminated")
	_check(is_equal_approx(water.contamination, 0.0), "purge: clears contamination")
	_check(_harness.events_named(&"water_purged").size() == 1, "purge: emits the event")
	_check(not water.purge(), "purge: returns false when already clean")
	_check(_harness.events_named(&"water_purged").size() == 1, "purge: no event when already clean")
	water.contamination = 0.6
	_check(water.install_cartridge(), "cartridge: install returns true")
	_check(absf(water.contamination - 0.1) < 1e-6, "cartridge: reduces contamination by 0.5")
	_check(_harness.events_named(&"water_cartridge_installed").size() == 1, "cartridge: emits the event")
	_despawn_all()


func _test_reclaimer_procedure() -> void:
	_harness.clear_events()
	var stores: Stores = _harness.add_stores({&"water_filter": 1})
	_spawned.append(stores)
	var water: WaterSystem = _spawn_water(100.0, 20.0)
	water.contamination = 0.8
	var reclaimer := WaterReclaimer.new()
	var model_scene: PackedScene = load(RECLAIMER_MODEL_PATH) as PackedScene
	_check(model_scene != null, "water reclaimer glTF model loads")
	if model_scene != null:
		reclaimer.add_child(model_scene.instantiate())
	root.add_child(reclaimer)
	_spawned.append(reclaimer)
	var animator: AnimationPlayer = _animation_player(reclaimer)
	_check(animator != null, "water reclaimer glTF animation player is present")

	_check(reclaimer.get_interaction_prompt() == "Drain loop", "procedure: starts idle and asks to drain")
	reclaimer.interact(null)
	_check_animation(animator, &"drain", "draining the loop plays its authored clip")
	var drain_state: Dictionary = reclaimer.save_state()
	_check(reclaimer.get_interaction_prompt() == "Replace cartridge", "procedure: drain advances to cartridge")
	reclaimer.interact(null)
	_check_animation(animator, &"replace_cartridge", "replacing the cartridge plays its authored clip")
	_check(stores.get_count(&"water_filter") == 0, "procedure: cartridge taken from stores")
	_check(reclaimer.get_interaction_prompt() == "Prime loop", "procedure: cartridge advances to prime")
	reclaimer.interact(null)
	_check_animation(animator, &"prime", "priming the loop plays its authored clip")
	_check(reclaimer.get_interaction_prompt() == "Run inspection", "procedure: prime advances to inspection")
	reclaimer.interact(null)
	_check_animation(animator, &"run_inspection", "inspection plays its authored clip")
	_check(reclaimer.get_interaction_prompt() == "Drain loop", "procedure: inspection returns to idle")
	_check(is_equal_approx(water.contamination, 0.0), "procedure: loop contamination cleared")
	_check(_harness.events_named(&"reclaimer_serviced").size() == 1, "procedure: service event emitted")

	var saved: Dictionary = reclaimer.save_state()
	_check(saved["system_id"] == "water_reclaimer", "procedure: save system_id")
	_check(int(saved["state_version"]) == 1, "procedure: save version")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	_check(parsed is Dictionary, "procedure: save state is JSON-safe")
	var idle_state: Dictionary = saved
	if parsed is Dictionary:
		idle_state = parsed
		reclaimer.load_state(idle_state)
	_check(reclaimer.get_interaction_prompt() == "Drain loop", "procedure: stage restored from JSON")
	reclaimer.load_state(drain_state)
	_check(reclaimer.get_interaction_prompt() == "Replace cartridge", "procedure: saved drain stage is restored")
	_check_animation(animator, &"drain", "restoring an in-progress drain resumes its loop")
	reclaimer.load_state(idle_state)

	reclaimer.interact(null)
	var errors: Array[Dictionary] = _harness.events_named(&"procedure_error")
	_check(errors.size() == 1, "procedure: clean loop refuses the drain")
	if errors.size() == 1:
		_check(StringName(errors[0]["payload"].get("reason", &"")) == &"clean_loop", "procedure: clean_loop reason")
	_check(reclaimer.get_interaction_prompt() == "Drain loop", "procedure: refusal does not advance")
	_despawn_all()


func _test_reclaimer_no_cartridge() -> void:
	_harness.clear_events()
	var stores: Stores = _harness.add_stores({})
	_spawned.append(stores)
	var water: WaterSystem = _spawn_water(100.0, 20.0)
	water.contamination = 0.8
	var reclaimer := WaterReclaimer.new()
	root.add_child(reclaimer)
	_spawned.append(reclaimer)

	reclaimer.interact(null)
	reclaimer.interact(null)
	var errors: Array[Dictionary] = _harness.events_named(&"procedure_error")
	_check(errors.size() == 1, "no-cartridge: one procedure error")
	if errors.size() == 1:
		_check(StringName(errors[0]["payload"].get("reason", &"")) == &"no_cartridge", "no-cartridge: reason")
	_check(reclaimer.get_interaction_prompt() == "Replace cartridge", "no-cartridge: stays on the replace step")
	_check(stores.get_count(&"water_filter") == 0, "no-cartridge: stores untouched")
	_despawn_all()


func _test_save_load_round_trip() -> void:
	_harness.clear_events()
	var water: WaterSystem = _spawn_water(36.0, 12.5)
	water.set_reclaimer_powered(false)
	water.contamination = 0.55
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_low").size() == 1, "save: low flag latched before save")
	_check(_harness.events_named(&"water_contaminated").size() == 1, "save: contamination flag latched before save")
	var saved: Dictionary = water.save_state()
	_check(saved["system_id"] == "water", "save: system_id is water")
	_check(int(saved["state_version"]) == 1, "save: state_version is 1")
	var parsed: Variant = JSON.parse_string(JSON.stringify(saved))
	_check(parsed is Dictionary, "save: JSON round trip parses to Dictionary")
	var parsed_dict: Dictionary = parsed if parsed is Dictionary else {}
	water.potable_l = 5.0
	water.greywater_l = 0.0
	water.contamination = 0.1
	water.set_reclaimer_powered(true)
	water.load_state(parsed_dict)
	_check(is_equal_approx(water.potable_l, 36.0), "save: potable restored")
	_check(is_equal_approx(water.greywater_l, 12.5), "save: greywater restored")
	_check(absf(water.contamination - 0.55) < 1e-9, "save: contamination restored")
	_check(not water.reclaimer_powered, "save: reclaimer switch restored")
	_harness.clear_events()
	_harness.advance(0.1)
	_check(_harness.events_named(&"water_low").is_empty(), "save: low re-arm flag preserved")
	_check(_harness.events_named(&"water_contaminated").is_empty(), "save: contamination re-arm flag preserved")
	_despawn_all()


func _spawn_water(potable_l: float = 120.0, greywater_l: float = 40.0) -> WaterSystem:
	var water := WaterSystem.new()
	water.potable_l = potable_l
	water.greywater_l = greywater_l
	root.add_child(water)
	_spawned.append(water)
	return water


func _animation_player(node: Node) -> AnimationPlayer:
	return node.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _check_animation(animator: AnimationPlayer, animation_name: StringName, label: String) -> void:
	_check(
		animator != null and animator.has_animation(animation_name)
			and animator.current_animation == animation_name and animator.is_playing(),
		label
	)


func _despawn_all() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_water")
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
