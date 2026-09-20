## Installable module catalog. Building a module is a nanite job: the materials are paid out of
## the hold up front, the pod assembles over `ShipModule.build_hours` of ship time (longer the
## more difficult the machine), and only then is its compartment registered with the life-support
## sims. Teardown and cancellation both return the full material cost to the hold.
class_name ModuleSystem
extends ShipSystem

const REFUSAL_UNKNOWN_MODULE: StringName = &"unknown_module"
const REFUSAL_ALREADY_INSTALLED: StringName = &"already_installed"
const REFUSAL_HARDPOINT_OCCUPIED: StringName = &"hardpoint_occupied"
const REFUSAL_MISSING_MATERIALS: StringName = &"missing_materials"
const REFUSAL_NOT_INSTALLED: StringName = &"not_installed"
const REFUSAL_ALREADY_BUILDING: StringName = &"already_building"
const REFUSAL_NO_BUILD_JOB: StringName = &"no_build_job"
const COMPARTMENT_GROUPS: Array[StringName] = [&"atmosphere_system", &"thermal_system", &"hull_system"]

@export var catalog: Array[ShipModule] = []

## hardpoint_id -> module_id
var _installed: Dictionary = {}
## hardpoint_id -> {"module_id": StringName, "remaining": float, "total": float}
var _jobs: Dictionary = {}


func _ready() -> void:
	system_id = &"modules"
	add_to_group(&"module_system")
	super._ready()


func get_catalog() -> Array[ShipModule]:
	var modules: Array[ShipModule] = []
	for module: ShipModule in catalog:
		if module != null and module.module_id != &"":
			modules.append(module)
	return modules


func get_module(module_id: StringName) -> ShipModule:
	for module: ShipModule in catalog:
		if module != null and module.module_id == module_id:
			return module
	return null


func is_installed(module_id: StringName) -> bool:
	return _installed.values().has(module_id)


func get_installed_at(hardpoint_id: StringName) -> StringName:
	return StringName(_installed.get(hardpoint_id, &""))


func get_installed_modules() -> Array[StringName]:
	var ids: Array[StringName] = []
	for module_id: Variant in _installed.values():
		ids.append(StringName(module_id))
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## The nanite job running at a hardpoint, empty when there is none.
func get_job(hardpoint_id: StringName) -> Dictionary:
	return _jobs.get(hardpoint_id, {}) as Dictionary


func get_jobs() -> Dictionary:
	return _jobs.duplicate(true)


func is_building(module_id: StringName) -> bool:
	for hardpoint_id: Variant in _jobs:
		if StringName(_jobs[hardpoint_id].get("module_id", &"")) == module_id:
			return true
	return false


## Returns &"" when the module can be built, else the refusal reason.
func can_install(module_id: StringName) -> StringName:
	var module: ShipModule = get_module(module_id)
	if module == null or module.hardpoint_id == &"":
		return REFUSAL_UNKNOWN_MODULE
	if is_installed(module_id):
		return REFUSAL_ALREADY_INSTALLED
	if _installed.has(module.hardpoint_id) or _jobs.has(module.hardpoint_id):
		return REFUSAL_HARDPOINT_OCCUPIED
	var cargo: Node = _cargo_system()
	if cargo == null:
		return REFUSAL_MISSING_MATERIALS
	for kind: Variant in module.cost:
		var needed: float = float(module.cost[kind])
		if needed <= 0.0:
			continue
		if float(cargo.call(&"get_units", StringName(String(kind)))) < needed - 0.0001:
			return REFUSAL_MISSING_MATERIALS
	return &""


## Starts the nanite build: cost out of the hold now, pod standing `build_hours` later.
func start_build(module_id: StringName) -> bool:
	var refusal: StringName = can_install(module_id)
	if refusal != &"":
		emit_sim_event(&"procedure_error", {"reason": String(refusal), "module_id": String(module_id)})
		return false
	var module: ShipModule = get_module(module_id)
	if not _pay_cost(module):
		emit_sim_event(&"procedure_error", {"reason": String(REFUSAL_MISSING_MATERIALS), "module_id": String(module_id)})
		return false
	var hours: float = maxf(module.build_hours, 0.01)
	_jobs[module.hardpoint_id] = {"module_id": module.module_id, "remaining": hours, "total": hours}
	emit_sim_event(&"construction_started", {
		"module_id": String(module_id),
		"hardpoint_id": String(module.hardpoint_id),
		"hours": hours,
	})
	_emit_typed(&"construction_started", module.module_id, module.hardpoint_id)
	return true


## Abandons a running build; the hold gets the full cost back.
func cancel_build(hardpoint_id: StringName) -> bool:
	if not _jobs.has(hardpoint_id):
		emit_sim_event(&"procedure_error", {"reason": String(REFUSAL_NO_BUILD_JOB), "hardpoint_id": String(hardpoint_id)})
		return false
	var job: Dictionary = _jobs[hardpoint_id]
	_jobs.erase(hardpoint_id)
	var module: ShipModule = get_module(StringName(job.get("module_id", &"")))
	if module != null:
		_refund(module)
	emit_sim_event(&"construction_cancelled", {
		"module_id": String(job.get("module_id", &"")),
		"hardpoint_id": String(hardpoint_id),
	})
	return true


## Teardown: the pod is unbuilt and the hold gets the full cost back.
func uninstall(module_id: StringName) -> bool:
	var module: ShipModule = get_module(module_id)
	if module == null or not is_installed(module_id):
		emit_sim_event(&"module_uninstall_refused", {"module_id": String(module_id), "reason": String(REFUSAL_NOT_INSTALLED)})
		return false
	_installed.erase(module.hardpoint_id)
	_unregister_compartments(module)
	_refund(module)
	emit_sim_event(&"module_uninstalled", {"module_id": String(module_id), "hardpoint_id": String(module.hardpoint_id)})
	_emit_typed(&"module_uninstalled", module.module_id, module.hardpoint_id)
	return true


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0 or _jobs.is_empty():
		return
	var finished: Array[StringName] = []
	for hardpoint_id: StringName in _jobs:
		var job: Dictionary = _jobs[hardpoint_id]
		job["remaining"] = maxf(float(job["remaining"]) - delta_hours, 0.0)
		if float(job["remaining"]) <= 0.0:
			finished.append(hardpoint_id)
	for hardpoint_id: StringName in finished:
		_finish_job(hardpoint_id)


func get_status() -> Dictionary:
	var installed: Dictionary = {}
	for hardpoint_id: StringName in _installed:
		installed[String(hardpoint_id)] = String(_installed[hardpoint_id])
	var jobs: Dictionary = {}
	for hardpoint_id: StringName in _jobs:
		var job: Dictionary = _jobs[hardpoint_id]
		jobs[String(hardpoint_id)] = {
			"module_id": String(job.get("module_id", &"")),
			"remaining_hours": float(job.get("remaining", 0.0)),
			"total_hours": float(job.get("total", 0.0)),
		}
	return {
		"system_id": system_id,
		"installed": installed,
		"installed_count": _installed.size(),
		"jobs": jobs,
		"building_count": _jobs.size(),
	}


func save_state() -> Dictionary:
	var jobs: Dictionary = {}
	for hardpoint_id: StringName in _jobs:
		var job: Dictionary = _jobs[hardpoint_id]
		jobs[String(hardpoint_id)] = {
			"module_id": String(job.get("module_id", &"")),
			"remaining_hours": float(job.get("remaining", 0.0)),
			"total_hours": float(job.get("total", 0.0)),
		}
	return {
		"system_id": String(system_id),
		"state_version": 2,
		"installed": get_status()["installed"],
		"jobs": jobs,
	}


func load_state(state: Dictionary) -> void:
	_installed.clear()
	_jobs.clear()
	var installed: Variant = state.get("installed", {})
	if installed is Dictionary:
		for key: Variant in installed:
			var module_id: StringName = StringName(String(installed[key]))
			if get_module(module_id) != null:
				_installed[StringName(String(key))] = module_id
	var jobs: Variant = state.get("jobs", {})
	if jobs is Dictionary:
		for key: Variant in jobs:
			var entry: Variant = jobs[key]
			if not (entry is Dictionary):
				continue
			var module_id: StringName = StringName(String((entry as Dictionary).get("module_id", &"")))
			if get_module(module_id) == null or _installed.has(StringName(String(key))):
				continue
			_jobs[StringName(String(key))] = {
				"module_id": module_id,
				"remaining": maxf(float((entry as Dictionary).get("remaining_hours", 0.0)), 0.0),
				"total": maxf(float((entry as Dictionary).get("total_hours", 0.0)), 0.0),
			}
	for module_id: StringName in get_installed_modules():
		_register_compartments(get_module(module_id))
	# Re-announce restored modules so world-side mounts stand their pods up (scene load).
	for hardpoint_id: StringName in _installed:
		var module_id: StringName = StringName(_installed[hardpoint_id])
		_emit_typed(&"module_installed", module_id, hardpoint_id)


func _finish_job(hardpoint_id: StringName) -> void:
	var job: Dictionary = _jobs[hardpoint_id]
	_jobs.erase(hardpoint_id)
	var module: ShipModule = get_module(StringName(job.get("module_id", &"")))
	if module == null or _installed.has(hardpoint_id):
		return
	_installed[hardpoint_id] = module.module_id
	_register_compartments(module)
	emit_sim_event(&"construction_completed", {
		"module_id": String(module.module_id),
		"hardpoint_id": String(hardpoint_id),
	})
	_emit_typed(&"module_installed", module.module_id, hardpoint_id)


func _pay_cost(module: ShipModule) -> bool:
	var cargo: Node = _cargo_system()
	if cargo == null:
		return false
	for kind: Variant in module.cost:
		var needed: float = float(module.cost[kind])
		if needed <= 0.0:
			continue
		if not bool(cargo.call(&"consume_material", StringName(String(kind)), needed)):
			return false
	return true


func _refund(module: ShipModule) -> void:
	var cargo: Node = _cargo_system()
	if cargo == null:
		return
	for kind: Variant in module.cost:
		var units: float = float(module.cost[kind])
		if units > 0.0:
			cargo.call(&"add_material", StringName(String(kind)), units)


func _register_compartments(module: ShipModule) -> void:
	var config: CompartmentConfig = module.compartment_config
	if config == null or config.compartment_id == &"":
		return
	for group_name: StringName in COMPARTMENT_GROUPS:
		var system: Node = _system(group_name)
		if system == null or not system.has_method(&"has_compartment") or not system.has_method(&"add_compartment"):
			continue
		if bool(system.call(&"has_compartment", config.compartment_id)):
			continue
		system.call(&"add_compartment", config)


func _unregister_compartments(module: ShipModule) -> void:
	var config: CompartmentConfig = module.compartment_config
	if config == null or config.compartment_id == &"":
		return
	for group_name: StringName in COMPARTMENT_GROUPS:
		var system: Node = _system(group_name)
		if system == null or not system.has_method(&"remove_compartment"):
			continue
		system.call(&"remove_compartment", config.compartment_id)


func _cargo_system() -> Node:
	return _system(&"cargo_system")


func _system(group_name: StringName) -> Node:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(group_name)


func _emit_typed(signal_name: StringName, module_id: StringName, hardpoint_id: StringName) -> void:
	var event_bus: Node = _get_autoload(&"EventBus")
	if event_bus != null:
		event_bus.emit_signal(signal_name, module_id, hardpoint_id)
