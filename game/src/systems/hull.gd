## Deterministic hull-integrity simulator: per-compartment punctures raise leak rates pushed into the atmosphere sim.
class_name HullSystem
extends ShipSystem

@export var compartment_defs: Array[CompartmentConfig] = []
@export var hull_seed: int = 20260920
@export var wear_components: Array[WearComponent] = []
@export var wear_seed: int = 20260922

var _compartments: Dictionary = {}
var _rng: RandomNumberGenerator
var _wear_random: RandomNumberGenerator
var _condition_bucket: Dictionary = {}
var _failure_restore: Dictionary = {}
var _puncture_rate_multiplier: float = 1.0


func _ready() -> void:
	system_id = &"hull"
	add_to_group(&"hull_system")
	_ensure_rng()
	_wear_rng()
	super._ready()
	for config: CompartmentConfig in compartment_defs:
		add_compartment(config)


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		push_error("HullSystem.sim_tick: delta_hours must be finite and positive.")
		return
	_tick_wear(delta_hours)
	var atmosphere: Node = _first_node_in_group(&"atmosphere_system")
	for compartment_id: StringName in _compartments:
		var config: CompartmentConfig = _compartments[compartment_id]["config"]
		var mtbf_hours: float = config.puncture_mtbf_hours * _puncture_rate_multiplier
		if is_finite(mtbf_hours) and mtbf_hours > 0.0:
			var probability: float = minf(delta_hours / mtbf_hours, 1.0)
			if _ensure_rng().randf() < probability:
				add_puncture(compartment_id, 1.0)
		_push_leak_rate(atmosphere, compartment_id)


func add_compartment(config: CompartmentConfig) -> bool:
	if config == null or config.compartment_id == &"":
		push_error("HullSystem.add_compartment: config must be non-null with a non-empty compartment_id.")
		return false
	if _compartments.has(config.compartment_id):
		push_error("HullSystem.add_compartment: duplicate compartment_id '%s'." % String(config.compartment_id))
		return false
	var punctures: Array[float] = []
	_compartments[config.compartment_id] = {"config": config, "punctures": punctures}
	return true


func has_compartment(compartment_id: StringName) -> bool:
	return _compartments.has(compartment_id)


func add_puncture(compartment_id: StringName, severity: float) -> bool:
	var state: Dictionary = _require_state(compartment_id, "add_puncture")
	if state.is_empty():
		return false
	if not is_finite(severity) or severity <= 0.0:
		push_error("HullSystem.add_puncture: severity must be finite and positive.")
		return false
	var punctures: Array[float] = state["punctures"]
	punctures.append(severity)
	_emit_puncture(compartment_id, severity)
	return true


func get_puncture_count(compartment_id: StringName) -> int:
	var state: Dictionary = _require_state(compartment_id, "get_puncture_count")
	if state.is_empty():
		return 0
	var punctures: Array[float] = state["punctures"]
	return punctures.size()


func get_total_leak_rate(compartment_id: StringName) -> float:
	var state: Dictionary = _require_state(compartment_id, "get_total_leak_rate")
	if state.is_empty():
		return 0.0
	var config: CompartmentConfig = state["config"]
	var punctures: Array[float] = state["punctures"]
	var severity_sum: float = 0.0
	for severity: float in punctures:
		severity_sum += severity
	return config.leak_rate_per_hour + severity_sum * config.puncture_leak_per_hour


func patch_puncture(compartment_id: StringName, quality: float) -> bool:
	if not _compartments.has(compartment_id):
		push_error("HullSystem.patch_puncture: unknown compartment_id '%s'." % String(compartment_id))
		return false
	var state: Dictionary = _compartments[compartment_id]
	var punctures: Array[float] = state["punctures"]
	if punctures.is_empty():
		return false
	var largest_index: int = 0
	for i: int in punctures.size():
		if punctures[i] > punctures[largest_index]:
			largest_index = i
	punctures.remove_at(largest_index)
	var patch_quality: float = clampf(quality, 0.0, 1.0) if is_finite(quality) else 0.0
	emit_sim_event(&"hull_patched", {
		"compartment_id": compartment_id,
		"remaining": punctures.size(),
		"quality": patch_quality,
	})
	_emit_patch_repaired(compartment_id, patch_quality)
	return true


func get_status() -> Dictionary:
	var compartments: Dictionary = {}
	var punctures_total: int = 0
	for compartment_id: StringName in _compartments:
		var state: Dictionary = _compartments[compartment_id]
		var config: CompartmentConfig = state["config"]
		var punctures: Array[float] = state["punctures"]
		punctures_total += punctures.size()
		compartments[compartment_id] = {
			"compartment_id": compartment_id,
			"puncture_count": punctures.size(),
			"punctures": punctures.duplicate(),
			"base_leak_rate_per_hour": config.leak_rate_per_hour,
			"total_leak_rate_per_hour": get_total_leak_rate(compartment_id),
		}
	return {"system_id": system_id, "compartments": compartments, "punctures_total": punctures_total, "puncture_rate_multiplier": _puncture_rate_multiplier}


func repair_component(component_id: StringName, quality: float) -> bool:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null:
		push_error("HullSystem.repair_component: unknown component_id '%s'." % String(component_id))
		return false
	component.apply_repair(quality)
	if not component.is_failed():
		_restore_failure_effect(component.component_id)
	_condition_bucket[component.component_id] = _condition_bucket_for(component.condition)
	_emit_component_repaired(component.component_id, clampf(quality, 0.0, 1.0))
	return true


func get_wear_status() -> Dictionary:
	var status: Dictionary = {}
	for component: WearComponent in wear_components:
		if component == null or component.component_id == &"":
			continue
		status[String(component.component_id)] = component.get_status()
	return status


func force_failure(component_id: StringName, failure_mode_id: StringName) -> bool:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null or failure_mode_id == &"":
		push_error("HullSystem.force_failure: unknown component_id '%s' or empty failure_mode_id." % String(component_id))
		return false
	if component.is_failed():
		return false
	component.failed_mode = failure_mode_id
	_apply_failure_effect(component, failure_mode_id)
	_emit_component_failed(component.component_id, failure_mode_id)
	return true


func diagnose_component(component_id: StringName) -> StringName:
	var component: WearComponent = _find_wear_component(component_id)
	if component == null:
		push_error("HullSystem.diagnose_component: unknown component_id '%s'." % String(component_id))
		return &""
	if not component.is_failed():
		return &""
	var was_diagnosed: bool = component.diagnosed
	var failure_mode_id: StringName = component.diagnose()
	if not was_diagnosed:
		var event_bus: Node = _get_autoload(&"EventBus")
		if event_bus != null:
			event_bus.emit_signal(&"component_diagnosed", component_id, failure_mode_id)
		emit_sim_event(&"component_diagnosed", {"component_id": component_id, "failure_mode_id": failure_mode_id})
	return failure_mode_id


func get_undiagnosed_failures() -> Array[StringName]:
	var failures: Array[StringName] = []
	for component: WearComponent in wear_components:
		if component == null or component.component_id == &"":
			continue
		if component.is_failed() and not component.diagnosed:
			failures.append(component.component_id)
	return failures


func scan_system() -> Dictionary:
	var conditions: Dictionary = {}
	for component: WearComponent in wear_components:
		if component == null or component.component_id == &"":
			continue
		component.scan()
		conditions[String(component.component_id)] = component.condition
	emit_sim_event(&"components_scanned", {"system_id": String(system_id)})
	return conditions


func save_state() -> Dictionary:
	var compartments: Dictionary = {}
	for compartment_id: StringName in _compartments:
		var state: Dictionary = _compartments[compartment_id]
		var punctures: Array[float] = state["punctures"]
		compartments[String(compartment_id)] = {"punctures": punctures.duplicate()}
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"compartments": compartments,
		"hull_rng_state": str(_ensure_rng().state),
		"wear": _wear_save_entries(),
		"wear_rng_state": str(_wear_rng().state),
		"failure_restore": _failure_restore_save(),
	}


func load_state(state: Dictionary) -> void:
	var compartments: Variant = state.get("compartments", {})
	if compartments is Dictionary:
		for key: Variant in (compartments as Dictionary):
			var compartment_id: StringName = StringName(String(key))
			if not _compartments.has(compartment_id):
				continue
			var saved: Variant = (compartments as Dictionary)[key]
			if not (saved is Dictionary):
				continue
			var saved_punctures: Variant = (saved as Dictionary).get("punctures", [])
			if not (saved_punctures is Array):
				continue
			var punctures: Array[float] = []
			for severity: Variant in (saved_punctures as Array):
				var value: float = float(severity)
				if is_finite(value) and value > 0.0:
					punctures.append(value)
			_compartments[compartment_id]["punctures"] = punctures
	if state.has("hull_rng_state"):
		_ensure_rng().state = int(str(state["hull_rng_state"]))
	_load_wear(state.get("wear", []))
	_load_failure_restore(state.get("failure_restore", {}))
	if state.has("wear_rng_state"):
		_wear_rng().state = int(state.get("wear_rng_state", _wear_rng().state))
	_reapply_failed_effects()


func _require_state(compartment_id: StringName, method_name: String) -> Dictionary:
	if not _compartments.has(compartment_id):
		push_error("HullSystem.%s: unknown compartment_id '%s'." % [method_name, String(compartment_id)])
		return {}
	return _compartments[compartment_id]


func _ensure_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = hull_seed
	return _rng


func _push_leak_rate(atmosphere: Node, compartment_id: StringName) -> void:
	if atmosphere == null or not atmosphere.has_method(&"set_leak_rate"):
		return
	if atmosphere.has_method(&"has_compartment") and not bool(atmosphere.call("has_compartment", compartment_id)):
		return
	atmosphere.call("set_leak_rate", compartment_id, get_total_leak_rate(compartment_id))


func _emit_puncture(compartment_id: StringName, severity: float) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"hull_puncture", compartment_id, severity)
	emit_sim_event(&"hull_puncture", {
		"compartment_id": compartment_id,
		"severity": severity,
		"leak_rate_per_hour": get_total_leak_rate(compartment_id),
	})


func _emit_patch_repaired(compartment_id: StringName, quality: float) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_repaired", StringName("hull_" + String(compartment_id)), quality)


func _tick_wear(delta_hours: float) -> void:
	if wear_components.is_empty():
		return
	var environment: Dictionary = {
		"heat": 0.0,
		"load": 0.0,
		"vibration": 0.0,
	}
	for component: WearComponent in wear_components:
		if component == null:
			continue
		var failed_mode_id: StringName = component.tick_sim(delta_hours, environment, _wear_rng())
		if failed_mode_id != &"":
			_apply_failure_effect(component, failed_mode_id)
			_emit_component_failed(component.component_id, failed_mode_id)
		_emit_condition_crossings(component)


func _wear_rng() -> RandomNumberGenerator:
	if _wear_random == null:
		_wear_random = RandomNumberGenerator.new()
		_wear_random.seed = wear_seed
	return _wear_random


func _find_wear_component(component_id: StringName) -> WearComponent:
	for component: WearComponent in wear_components:
		if component != null and component.component_id == component_id:
			return component
	return null


func _apply_failure_effect(component: WearComponent, failure_mode_id: StringName, immediate: bool = true) -> void:
	match failure_mode_id:
		&"plating_fatigue":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "puncture_rate_multiplier", "target": "", "value": _puncture_rate_multiplier}
			_puncture_rate_multiplier = 0.5
		&"seam_split":
			if not _failure_restore.has(component.component_id):
				_failure_restore[component.component_id] = {"kind": "puncture_rate_multiplier", "target": "", "value": _puncture_rate_multiplier}
			_puncture_rate_multiplier = 0.5
			if immediate:
				for compartment_id: StringName in _compartments:
					add_puncture(compartment_id, 1.5)
		_:
			pass


func _restore_failure_effect(component_id: StringName) -> void:
	if not _failure_restore.has(component_id):
		return
	var restore: Dictionary = _failure_restore[component_id]
	match String(restore.get("kind", "")):
		"puncture_rate_multiplier":
			_puncture_rate_multiplier = maxf(float(restore.get("value", _puncture_rate_multiplier)), 0.0)
		_:
			pass
	_failure_restore.erase(component_id)


func _reapply_failed_effects() -> void:
	_puncture_rate_multiplier = 1.0
	for component: WearComponent in wear_components:
		if component != null and component.is_failed():
			_apply_failure_effect(component, component.failed_mode, false)


func _emit_component_failed(component_id: StringName, failure_mode_id: StringName) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_failed", component_id, failure_mode_id)
	emit_sim_event(&"component_failed", {"component_id": component_id, "failure_mode_id": failure_mode_id})


func _emit_component_repaired(component_id: StringName, quality: float) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_repaired", component_id, quality)
	emit_sim_event(&"component_repaired", {"component_id": component_id, "quality": quality})


func _emit_condition_crossings(component: WearComponent) -> void:
	var bucket: int = _condition_bucket_for(component.condition)
	if not _condition_bucket.has(component.component_id):
		_condition_bucket[component.component_id] = bucket
		return
	if bucket >= int(_condition_bucket[component.component_id]):
		_condition_bucket[component.component_id] = bucket
		return
	_condition_bucket[component.component_id] = bucket
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(&"component_condition_changed", component.component_id, component.condition)


func _condition_bucket_for(condition: float) -> int:
	return int(floor(clampf(condition, 0.0, 1.0) * 10.0 + 1e-9))


func _load_wear(entries: Variant) -> void:
	if not (entries is Array):
		return
	for entry: Variant in (entries as Array):
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		var component: WearComponent = _find_wear_component(StringName(String(data.get("component_id", ""))))
		if component == null:
			continue
		component.condition = clampf(float(data.get("condition", component.condition)), 0.0, 1.0)
		component.hours_operated = maxf(float(data.get("hours_operated", component.hours_operated)), 0.0)
		component.load = float(data.get("load", component.load))
		component.failed_mode = StringName(String(data.get("failed_mode", "")))
		component.diagnosed = bool(data.get("diagnosed", false))
		component.scanned = bool(data.get("scanned", false))
		_condition_bucket[component.component_id] = _condition_bucket_for(component.condition)


func _load_failure_restore(saved: Variant) -> void:
	_failure_restore.clear()
	if not (saved is Dictionary):
		return
	for key: Variant in (saved as Dictionary):
		var entry: Variant = (saved as Dictionary)[key]
		if not (entry is Dictionary):
			continue
		var data: Dictionary = entry
		_failure_restore[StringName(String(key))] = {
			"kind": String(data.get("kind", "")),
			"target": String(data.get("target", "")),
			"value": float(data.get("value", 0.0)),
		}


func _wear_save_entries() -> Array:
	var entries: Array = []
	for component: WearComponent in wear_components:
		if component == null:
			continue
		entries.append({
			"component_id": String(component.component_id),
			"condition": component.condition,
			"hours_operated": component.hours_operated,
			"load": component.load,
			"failed_mode": String(component.failed_mode),
			"diagnosed": component.diagnosed,
			"scanned": component.scanned,
		})
	return entries


func _failure_restore_save() -> Dictionary:
	var saved: Dictionary = {}
	for component_id: Variant in _failure_restore:
		var entry: Dictionary = _failure_restore[component_id]
		saved[String(component_id)] = {
			"kind": String(entry.get("kind", "")),
			"target": String(entry.get("target", "")),
			"value": float(entry.get("value", 0.0)),
		}
	return saved


func _first_node_in_group(group_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		var main_loop: MainLoop = Engine.get_main_loop()
		if main_loop is SceneTree:
			tree = main_loop as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(group_name)
