extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_test_decay()
	_test_max_condition_gating()
	_test_determinism()
	_test_environmental_multiplier()
	_test_failure_lifecycle()
	_test_repair()
	if _failures == 0:
		print("PASS: test_wear_model")
		quit(0)
	else:
		print("FAIL: test_wear_model (%d checks failed)" % _failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		print("FAIL: ", label)


func _test_decay() -> void:
	var component := WearComponent.new()
	component.wear_rate_per_hour = 0.01
	component.load = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	component.tick_sim(10.0, {}, rng)
	_check(absf(component.condition - 0.9) < 1e-4, "decay: condition ~= 0.9")
	_check(component.hours_operated == 10.0, "decay: hours_operated == 10.0")


func _test_max_condition_gating() -> void:
	var mode := FailureMode.new()
	mode.id = &"gated"
	mode.max_condition = 0.2
	var component := WearComponent.new()
	var modes: Array[FailureMode] = [mode]
	component.failure_modes = modes
	_check(component.get_probability_per_hour(mode, {}) == 0.0, "gating: probability 0.0 while condition above max_condition")


func _test_determinism() -> void:
	var component_a := _make_deterministic_component()
	var component_b := _make_deterministic_component()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 12345
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 12345
	var first_failure_a: StringName = &""
	var first_failure_b: StringName = &""
	var failure_iteration_a: int = -1
	var failure_iteration_b: int = -1
	for i: int in 5000:
		var result_a: StringName = component_a.tick_sim(0.1, {}, rng_a)
		if result_a != &"" and first_failure_a == &"":
			first_failure_a = result_a
			failure_iteration_a = i
		var result_b: StringName = component_b.tick_sim(0.1, {}, rng_b)
		if result_b != &"" and first_failure_b == &"":
			first_failure_b = result_b
			failure_iteration_b = i
	_check(first_failure_a != &"", "determinism: component fails within 5000 ticks")
	_check(first_failure_a == first_failure_b and failure_iteration_a == failure_iteration_b, "determinism: same failure on same iteration")
	_check(component_a.condition == component_b.condition, "determinism: identical final condition")
	_check(component_a.hours_operated == component_b.hours_operated, "determinism: identical final hours")


func _test_environmental_multiplier() -> void:
	var mode := FailureMode.new()
	mode.id = &"heat_sensitive"
	mode.base_mtbf_hours = 1000.0
	mode.environmental_factors = {"heat": 2.0}
	var component := WearComponent.new()
	var modes: Array[FailureMode] = [mode]
	component.failure_modes = modes
	var p_base: float = component.get_probability_per_hour(mode, {})
	var p_hot: float = component.get_probability_per_hour(mode, {"heat": 1.0})
	_check(p_base > 0.0, "environment: baseline probability positive")
	_check(is_equal_approx(p_hot, p_base * 2.0), "environment: heat=1.0 doubles probability")


func _test_failure_lifecycle() -> void:
	var component := _make_doomed_component()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var triggered: StringName = component.tick_sim(1.0, {}, rng)
	_check(triggered == &"rupture", "lifecycle: first tick returns mode id")
	_check(component.is_failed(), "lifecycle: is_failed() true")
	_check(component.failed_mode == &"rupture", "lifecycle: failed_mode set")
	var condition_before: float = component.condition
	var hours_before: float = component.hours_operated
	var after_failure: StringName = component.tick_sim(1.0, {}, rng)
	_check(after_failure == &"", "lifecycle: subsequent tick returns empty")
	_check(component.condition == condition_before, "lifecycle: condition frozen while failed")
	_check(component.hours_operated == hours_before, "lifecycle: hours frozen while failed")


func _test_repair() -> void:
	var component := _make_doomed_component()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	component.tick_sim(1.0, {}, rng)
	component.apply_repair(1.0)
	_check(component.condition == 1.0 and not component.is_failed(), "repair: full quality restores condition and clears failure")
	component.condition = 0.5
	component.apply_repair(0.0)
	_check(component.condition == 0.5, "repair: zero quality leaves condition unchanged")
	_check(component.hours_operated == 1.0, "repair: hours_operated not reset")


func _make_deterministic_component() -> WearComponent:
	var mode := FailureMode.new()
	mode.id = &"seized"
	mode.base_mtbf_hours = 5.0
	var modes: Array[FailureMode] = [mode]
	var component := WearComponent.new()
	component.component_id = &"pump_a"
	component.wear_rate_per_hour = 0.002
	component.load = 1.0
	component.failure_modes = modes
	return component


func _make_doomed_component() -> WearComponent:
	var mode := FailureMode.new()
	mode.id = &"rupture"
	mode.base_mtbf_hours = 0.0001
	var modes: Array[FailureMode] = [mode]
	var component := WearComponent.new()
	component.failure_modes = modes
	return component
