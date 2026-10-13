## Installable module catalog. Building a module is a nanite job: the materials are paid out of
## the hold up front, the pod assembles over `ShipModule.build_hours` of ship time (longer the
## more difficult the machine), and only then is its compartment registered with the life-support
## sims. Teardown and cancellation both return the full material cost to the hold.
class_name ModuleSystem
extends ShipSystem

const REFUSAL_UNKNOWN_MODULE: StringName = &"unknown_module"
const REFUSAL_ALREADY_INSTALLED: StringName = &"already_installed"
const REFUSAL_HARDPOINT_OCCUPIED: StringName = &"hardpoint_occupied"
const REFUSAL_HARDPOINT_CLEARANCE: StringName = &"hardpoint_clearance"
const REFUSAL_MISSING_MATERIALS: StringName = &"missing_materials"
const REFUSAL_NOT_INSTALLED: StringName = &"not_installed"
const REFUSAL_ALREADY_BUILDING: StringName = &"already_building"
const REFUSAL_NO_BUILD_JOB: StringName = &"no_build_job"
const REFUSAL_UNKNOWN_MACHINE: StringName = &"unknown_machine"
const REFUSAL_SLOT_OCCUPIED: StringName = &"slot_occupied"
const REFUSAL_NOT_PORTABLE: StringName = &"not_portable"
const COMPARTMENT_GROUPS: Array[StringName] = [&"atmosphere_system", &"thermal_system", &"hull_system"]
const EFFECT_RATIONS: StringName = &"rations"
const EFFECT_FABRICATION: StringName = &"fabrication"
const EFFECT_CARGO: StringName = &"cargo"
const EFFECT_POWER: StringName = &"power"
const EFFECT_RECOVERY: StringName = &"recovery"
const EFFECT_SOURCE: StringName = &"modules"
# The generated pod shell is 3.6 m long along Z; these port mounts are 2.85 m apart.
const PORT_POD_CLEARANCE_CONFLICTS: Dictionary = {
	&"hp_quarters": &"hp_life_support",
	&"hp_life_support": &"hp_quarters",
}

@export var catalog: Array[ShipModule] = []
@export var machine_catalog: Array[ShipMachine] = []

## hardpoint_id -> module_id
var _installed: Dictionary = {}
## hardpoint_id -> {"module_id": StringName, "remaining": float, "total": float}
var _jobs: Dictionary = {}
## socket_id -> machine_id, fitted inside pods (slot ids are "<hardpoint>:<index>")
var _machines: Dictionary = {}
## socket_id -> {"machine_id": StringName, "remaining": float, "total": float}
var _machine_jobs: Dictionary = {}
## Circuits the installed set currently draws from, so stale draws can be cleared.
var _loaded_circuits: Array[StringName] = []
## Fractional rations waiting to be a whole one.
var _ration_hours: float = 0.0
# Only a notification snapshot; SalvageSystem owns these instances and their save state.
var _salvage_fitted: Dictionary = {}


func _ready() -> void:
	system_id = &"modules"
	add_to_group(&"module_system")
	super._ready()
	var bus: Node = _get_autoload(&"EventBus")
	if bus != null and bus.has_signal(&"salvage_changed"):
		bus.connect(&"salvage_changed", _on_salvage_changed)
	_on_salvage_changed.call_deferred("")


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
	var clearance_neighbor: StringName = StringName(PORT_POD_CLEARANCE_CONFLICTS.get(module.hardpoint_id, &""))
	if clearance_neighbor != &"" and (_installed.has(clearance_neighbor) or _jobs.has(clearance_neighbor)):
		return REFUSAL_HARDPOINT_CLEARANCE
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
	if not _teardown_fits_hold(module):
		emit_sim_event(&"procedure_error", {"reason": &"salvage_hold_full"})
		return false
	var salvage: Node = _system(&"salvage_system")
	if salvage != null and not bool(salvage.call(&"release_pod", module.hardpoint_id)):
		emit_sim_event(&"module_uninstall_refused", {"module_id": String(module_id), "reason": "hold_full"})
		return false
	_installed.erase(module.hardpoint_id)
	_release_machines(module.hardpoint_id)
	_unregister_compartments(module)
	_apply_effects()
	_refund(module)
	emit_sim_event(&"module_uninstalled", {"module_id": String(module_id), "hardpoint_id": String(module.hardpoint_id)})
	_emit_typed(&"module_uninstalled", module.module_id, module.hardpoint_id)
	return true


## A pod that comes down takes its machines with it: everything in its sockets goes back to the
## hold, and a fitting still running is cancelled and refunded.
func _teardown_fits_hold(module: ShipModule) -> bool:
	var cargo: Node = _cargo_system()
	if cargo == null:
		return false
	var capacity_lost: float = module.effect_amount if module.effect == EFFECT_CARGO else 0.0
	var returned_units: float = 0.0
	for amount: Variant in module.cost.values():
		returned_units += maxf(float(amount), 0.0)
	var prefix: String = String(module.hardpoint_id) + ":"
	var all_machines: Dictionary = get_machines()
	var salvage: Node = _system(&"salvage_system")
	for socket: String in all_machines:
		if not socket.begins_with(prefix):
			continue
		var machine: ShipMachine = get_machine(StringName(String(all_machines[socket])))
		if machine != null and machine.effect == EFFECT_CARGO:
			capacity_lost += machine.effect_amount
		if salvage != null and String(salvage.call("get_unit_at", StringName(socket))) != "":
			var definition: Resource = salvage.get("definition") as Resource
			returned_units += float(definition.get("cargo_units"))
		elif machine != null:
			for amount: Variant in machine.cost.values():
				returned_units += maxf(float(amount), 0.0)
	for socket: StringName in _machine_jobs:
		if String(socket).begins_with(prefix):
			var job: Dictionary = _machine_jobs[socket]
			var machine: ShipMachine = get_machine(StringName(job.get("machine_id", &"")))
			if machine != null:
				for amount: Variant in machine.cost.values():
					returned_units += maxf(float(amount), 0.0)
	return float(cargo.call("get_used_units")) + returned_units <= float(cargo.call("get_capacity_units")) - capacity_lost + 0.0001


func _release_machines(hardpoint_id: StringName) -> void:
	var prefix: String = String(hardpoint_id) + ":"
	for socket_id: Variant in _machines.keys():
		if not String(socket_id).begins_with(prefix):
			continue
		var machine: ShipMachine = get_machine(StringName(_machines[socket_id]))
		_machines.erase(socket_id)
		if machine != null:
			_refund_machine(machine)
	for socket_id: Variant in _machine_jobs.keys():
		if not String(socket_id).begins_with(prefix):
			continue
		var job: Dictionary = _machine_jobs[socket_id]
		var machine: ShipMachine = get_machine(StringName(job.get("machine_id", &"")))
		_machine_jobs.erase(socket_id)
		if machine != null:
			_refund_machine(machine)


func get_machine_catalog() -> Array[ShipMachine]:
	var machines: Array[ShipMachine] = []
	for machine: ShipMachine in machine_catalog:
		if machine != null and machine.machine_id != &"":
			machines.append(machine)
	return machines


func get_machine(machine_id: StringName) -> ShipMachine:
	for machine: ShipMachine in machine_catalog:
		if machine != null and machine.machine_id == machine_id:
			return machine
	var salvage: Node = _system(&"salvage_system")
	if salvage != null:
		var units: Array = salvage.call(&"get_units") as Array
		for unit: Dictionary in units:
			if StringName(String(unit.get("machine_id", ""))) == machine_id:
				return salvage.call(&"get_machine", String(unit.get("unit_id", ""))) as ShipMachine
	return null


func get_machine_at(socket_id: StringName) -> StringName:
	return StringName(String(get_machines().get(String(socket_id), "")))


func get_machine_job(socket_id: StringName) -> Dictionary:
	return _machine_jobs.get(socket_id, {}) as Dictionary


func get_machines() -> Dictionary:
	var fitted: Dictionary = {}
	for socket_id: StringName in _machines:
		fitted[String(socket_id)] = String(_machines[socket_id])
	var salvage: Node = _system(&"salvage_system")
	if salvage != null:
		fitted.merge(salvage.call(&"get_fitted_machines") as Dictionary)
	return fitted


func _on_salvage_changed(_unit_id: String) -> void:
	var salvage: Node = _system(&"salvage_system")
	var fitted: Dictionary = {}
	if salvage != null:
		fitted = (salvage.call(&"get_fitted_machines") as Dictionary).duplicate()
	var previous: Dictionary = _salvage_fitted
	_salvage_fitted = fitted
	_apply_effects()
	# Live transfers emit their own machine events; restores need the socket announcements.
	if _unit_id != "":
		return
	for socket_id: String in previous:
		if previous[socket_id] != fitted.get(socket_id, ""):
			var machine_id: StringName = StringName(String(previous[socket_id]))
			emit_sim_event(&"machine_removed", {"machine_id": String(machine_id), "socket_id": socket_id})
			_emit_typed(&"machine_removed", machine_id, StringName(socket_id))
	for socket_id: String in fitted:
		if fitted[socket_id] != previous.get(socket_id, ""):
			var machine_id: StringName = StringName(String(fitted[socket_id]))
			emit_sim_event(&"machine_fitted", {"machine_id": String(machine_id), "socket_id": socket_id})
			_emit_typed(&"machine_fitted", machine_id, StringName(socket_id))


## Returns &"" when the machine can be fitted into that socket, else the refusal reason.
func can_fit_machine(machine_id: StringName, socket_id: StringName) -> StringName:
	var machine: ShipMachine = get_machine(machine_id)
	if machine == null or socket_id == &"":
		return REFUSAL_UNKNOWN_MACHINE
	if get_machine_at(socket_id) != &"" or _machine_jobs.has(socket_id):
		return REFUSAL_SLOT_OCCUPIED
	var cargo: Node = _cargo_system()
	if cargo == null:
		return REFUSAL_MISSING_MATERIALS
	for kind: Variant in machine.cost:
		var needed: float = float(machine.cost[kind])
		if needed <= 0.0:
			continue
		if float(cargo.call(&"get_units", StringName(String(kind)))) < needed - 0.0001:
			return REFUSAL_MISSING_MATERIALS
	return &""


## Nanites fit the machine into the socket: cost now, work done over `build_hours`.
func fit_machine(machine_id: StringName, socket_id: StringName) -> bool:
	var refusal: StringName = can_fit_machine(machine_id, socket_id)
	if refusal != &"":
		emit_sim_event(&"procedure_error", {"reason": String(refusal), "machine_id": String(machine_id), "socket_id": String(socket_id)})
		return false
	var machine: ShipMachine = get_machine(machine_id)
	if not _pay_machine_cost(machine):
		emit_sim_event(&"procedure_error", {"reason": String(REFUSAL_MISSING_MATERIALS), "machine_id": String(machine_id)})
		return false
	var hours: float = maxf(machine.build_hours, 0.01)
	_machine_jobs[socket_id] = {"machine_id": machine.machine_id, "remaining": hours, "total": hours}
	emit_sim_event(&"machine_fit_started", {
		"machine_id": String(machine_id),
		"socket_id": String(socket_id),
		"hours": hours,
	})
	return true


## Takes a machine back out (full refund). Vital machinery is not portable and refuses.
func remove_machine(socket_id: StringName) -> bool:
	var salvage: Node = _system(&"salvage_system")
	if salvage != null and String(salvage.call(&"get_unit_at", socket_id)) != "":
		return bool(salvage.call(&"remove_unit", socket_id))
	var machine_id: StringName = get_machine_at(socket_id)
	var machine: ShipMachine = get_machine(machine_id)
	if machine == null:
		emit_sim_event(&"procedure_error", {"reason": String(REFUSAL_UNKNOWN_MACHINE), "socket_id": String(socket_id)})
		return false
	if not machine.portable:
		emit_sim_event(&"procedure_error", {"reason": String(REFUSAL_NOT_PORTABLE), "machine_id": String(machine_id)})
		return false
	_machines.erase(socket_id)
	_apply_effects()
	_refund_machine(machine)
	emit_sim_event(&"machine_removed", {"machine_id": String(machine_id), "socket_id": String(socket_id)})
	_emit_typed(&"machine_removed", machine.machine_id, socket_id)
	return true


func cancel_machine_fit(socket_id: StringName) -> bool:
	if not _machine_jobs.has(socket_id):
		emit_sim_event(&"procedure_error", {"reason": String(REFUSAL_NO_BUILD_JOB), "socket_id": String(socket_id)})
		return false
	var job: Dictionary = _machine_jobs[socket_id]
	_machine_jobs.erase(socket_id)
	var machine: ShipMachine = get_machine(StringName(job.get("machine_id", &"")))
	if machine != null:
		_refund_machine(machine)
	emit_sim_event(&"machine_fit_cancelled", {
		"machine_id": String(job.get("machine_id", &"")),
		"socket_id": String(socket_id),
	})
	return true


func sim_tick(delta_hours: float) -> void:
	if not is_finite(delta_hours) or delta_hours <= 0.0:
		return
	if not _jobs.is_empty() or not _machine_jobs.is_empty():
		_tick_jobs(delta_hours)
	_tick_effects(delta_hours)


## Installed hardware contributes to the systems that own the numbers: hold capacity, battery
## capacity, recovery rate, bench speed and circuit draw. Recomputed from the installed set, so
## it is idempotent across load and never drifts from the save.
func _apply_effects() -> void:
	var fabrication_fraction: float = 0.0
	var cargo_units: float = 0.0
	var power_wh: float = 0.0
	var recovery: float = 0.0
	var circuit_loads: Dictionary = {}
	for hardpoint_id: StringName in _installed:
		var module: ShipModule = get_module(StringName(_installed[hardpoint_id]))
		if module == null:
			continue
		match module.effect:
			EFFECT_FABRICATION:
				fabrication_fraction += module.effect_amount
			EFFECT_CARGO:
				cargo_units += module.effect_amount
			EFFECT_POWER:
				power_wh += module.effect_amount
			EFFECT_RECOVERY:
				recovery += module.effect_amount
		if module.circuit_id != &"" and module.power_load_w > 0.0:
			circuit_loads[module.circuit_id] = float(circuit_loads.get(module.circuit_id, 0.0)) + module.power_load_w
	for machine_id: Variant in get_machines().values():
		var machine: ShipMachine = get_machine(StringName(String(machine_id)))
		if machine == null:
			continue
		match machine.effect:
			EFFECT_FABRICATION:
				fabrication_fraction += machine.effect_amount
			EFFECT_CARGO:
				cargo_units += machine.effect_amount
			EFFECT_POWER:
				power_wh += machine.effect_amount
			EFFECT_RECOVERY:
				recovery += machine.effect_amount
		if machine.circuit_id != &"" and machine.power_load_w > 0.0:
			circuit_loads[machine.circuit_id] = float(circuit_loads.get(machine.circuit_id, 0.0)) + machine.power_load_w
	var cargo: Node = _cargo_system()
	if cargo != null and cargo.has_method(&"set_capacity_source"):
		cargo.call(&"set_capacity_source", EFFECT_SOURCE, cargo_units)
	var power: Node = _system(&"power_system")
	if power != null and power.has_method(&"set_capacity_source"):
		power.call(&"set_capacity_source", EFFECT_SOURCE, power_wh)
		for circuit_id: StringName in _loaded_circuits:
			if not circuit_loads.has(circuit_id):
				power.call(&"set_circuit_source_load", circuit_id, EFFECT_SOURCE, 0.0)
		_loaded_circuits.clear()
		for circuit_id: StringName in circuit_loads:
			power.call(&"set_circuit_source_load", circuit_id, EFFECT_SOURCE, float(circuit_loads[circuit_id]))
			_loaded_circuits.append(circuit_id)
	var vitals: Node = _system(&"vitals_system")
	if vitals != null and vitals.has_method(&"set_recovery_source"):
		vitals.call(&"set_recovery_source", EFFECT_SOURCE, recovery)
	var fabricator: Node = _system(&"fabricator_system")
	if fabricator != null:
		fabricator.set(&"job_hours_multiplier", clampf(1.0 - fabrication_fraction, 0.1, 1.0))


## The summed contribution of everything installed, for readouts and tests.
func get_effects() -> Dictionary:
	var summary: Dictionary = {
		"rations_per_day": 0.0,
		"fabrication_fraction": 0.0,
		"cargo_units": 0.0,
		"power_wh": 0.0,
		"recovery_per_hour": 0.0,
	}
	for hardpoint_id: StringName in _installed:
		var module: ShipModule = get_module(StringName(_installed[hardpoint_id]))
		if module == null:
			continue
		match module.effect:
			EFFECT_RATIONS:
				summary["rations_per_day"] = float(summary["rations_per_day"]) + module.effect_amount
			EFFECT_FABRICATION:
				summary["fabrication_fraction"] = float(summary["fabrication_fraction"]) + module.effect_amount
			EFFECT_CARGO:
				summary["cargo_units"] = float(summary["cargo_units"]) + module.effect_amount
			EFFECT_POWER:
				summary["power_wh"] = float(summary["power_wh"]) + module.effect_amount
			EFFECT_RECOVERY:
				summary["recovery_per_hour"] = float(summary["recovery_per_hour"]) + module.effect_amount
	for machine_id: Variant in get_machines().values():
		var machine: ShipMachine = get_machine(StringName(String(machine_id)))
		if machine == null:
			continue
		match machine.effect:
			EFFECT_RATIONS:
				summary["rations_per_day"] = float(summary["rations_per_day"]) + machine.effect_amount
			EFFECT_FABRICATION:
				summary["fabrication_fraction"] = float(summary["fabrication_fraction"]) + machine.effect_amount
			EFFECT_CARGO:
				summary["cargo_units"] = float(summary["cargo_units"]) + machine.effect_amount
			EFFECT_POWER:
				summary["power_wh"] = float(summary["power_wh"]) + machine.effect_amount
			EFFECT_RECOVERY:
				summary["recovery_per_hour"] = float(summary["recovery_per_hour"]) + machine.effect_amount
	return summary


## A rations pod only grows while its circuit is live.
func _module_powered(circuit_id: StringName, load_w: float) -> bool:
	if circuit_id == &"" or load_w <= 0.0:
		return true
	var power: Node = _system(&"power_system")
	if power == null:
		return false
	if power.has_method(&"is_breaker_on") and not bool(power.call(&"is_breaker_on", circuit_id)):
		return false
	if power.has_method(&"is_circuit_shed") and bool(power.call(&"is_circuit_shed", circuit_id)):
		return false
	return true


func _tick_effects(delta_hours: float) -> void:
	var stores: Node = _system(&"stores_system")
	for hardpoint_id: StringName in _installed:
		var module: ShipModule = get_module(StringName(_installed[hardpoint_id]))
		if module == null or module.effect != EFFECT_RATIONS or module.effect_amount <= 0.0:
			continue
		if not _module_powered(module.circuit_id, module.power_load_w):
			continue
		_ration_hours += module.effect_amount * delta_hours / 24.0
	for machine_id: Variant in _machines.values() + _salvage_fitted.values():
		var machine: ShipMachine = get_machine(StringName(String(machine_id)))
		if machine == null or machine.effect != EFFECT_RATIONS or machine.effect_amount <= 0.0:
			continue
		if not _module_powered(machine.circuit_id, machine.power_load_w):
			continue
		_ration_hours += machine.effect_amount * delta_hours / 24.0
	if _ration_hours < 1.0 or stores == null or not stores.has_method(&"add_part"):
		return
	var whole: int = int(floor(_ration_hours))
	_ration_hours -= float(whole)
	stores.call(&"add_part", &"food_ration", whole)


func _tick_jobs(delta_hours: float) -> void:
	var finished: Array[StringName] = []
	for hardpoint_id: StringName in _jobs:
		var job: Dictionary = _jobs[hardpoint_id]
		job["remaining"] = maxf(float(job["remaining"]) - delta_hours, 0.0)
		if float(job["remaining"]) <= 0.0:
			finished.append(hardpoint_id)
	for hardpoint_id: StringName in finished:
		_finish_job(hardpoint_id)
	var fitted: Array[StringName] = []
	for socket_id: StringName in _machine_jobs:
		var machine_job: Dictionary = _machine_jobs[socket_id]
		machine_job["remaining"] = maxf(float(machine_job["remaining"]) - delta_hours, 0.0)
		if float(machine_job["remaining"]) <= 0.0:
			fitted.append(socket_id)
	for socket_id: StringName in fitted:
		_finish_machine_job(socket_id)


func _finish_machine_job(socket_id: StringName) -> void:
	var job: Dictionary = _machine_jobs[socket_id]
	_machine_jobs.erase(socket_id)
	var machine: ShipMachine = get_machine(StringName(job.get("machine_id", &"")))
	if machine == null or _machines.has(socket_id):
		return
	_machines[socket_id] = machine.machine_id
	_apply_effects()
	emit_sim_event(&"machine_fitted", {
		"machine_id": String(machine.machine_id),
		"socket_id": String(socket_id),
	})
	_emit_typed(&"machine_fitted", machine.machine_id, socket_id)


func _pay_machine_cost(machine: ShipMachine) -> bool:
	var cargo: Node = _cargo_system()
	if cargo == null:
		return false
	for kind: Variant in machine.cost:
		var needed: float = float(machine.cost[kind])
		if needed <= 0.0:
			continue
		if not bool(cargo.call(&"consume_material", StringName(String(kind)), needed)):
			return false
	return true


func _refund_machine(machine: ShipMachine) -> void:
	var cargo: Node = _cargo_system()
	if cargo == null:
		return
	for kind: Variant in machine.cost:
		var units: float = float(machine.cost[kind])
		if units > 0.0:
			cargo.call(&"add_material", StringName(String(kind)), units)


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
		"machines": get_machines(),
		"machine_count": get_machines().size(),
		"machine_jobs": _machine_jobs.size(),
	}


func save_state() -> Dictionary:
	var built_machines: Dictionary = {}
	for socket_id: StringName in _machines:
		built_machines[String(socket_id)] = String(_machines[socket_id])
	var jobs: Dictionary = {}
	for hardpoint_id: StringName in _jobs:
		var job: Dictionary = _jobs[hardpoint_id]
		jobs[String(hardpoint_id)] = {
			"module_id": String(job.get("module_id", &"")),
			"remaining_hours": float(job.get("remaining", 0.0)),
			"total_hours": float(job.get("total", 0.0)),
		}
	var machine_jobs: Dictionary = {}
	for socket_id: StringName in _machine_jobs:
		var machine_job: Dictionary = _machine_jobs[socket_id]
		machine_jobs[String(socket_id)] = {
			"machine_id": String(machine_job.get("machine_id", &"")),
			"remaining_hours": float(machine_job.get("remaining", 0.0)),
			"total_hours": float(machine_job.get("total", 0.0)),
		}
	return {
		"system_id": String(system_id),
		"state_version": 3,
		"installed": get_status()["installed"],
		"jobs": jobs,
		"machines": built_machines,
		"machine_jobs": machine_jobs,
	}


func load_state(state: Dictionary) -> void:
	for module_id: StringName in get_installed_modules():
		_unregister_compartments(get_module(module_id))
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
	_machines.clear()
	var fitted: Variant = state.get("machines", {})
	if fitted is Dictionary:
		for key: Variant in fitted:
			var machine_id: StringName = StringName(String((fitted as Dictionary)[key]))
			if get_machine(machine_id) != null:
				_machines[StringName(String(key))] = machine_id
	_machine_jobs.clear()
	var machine_jobs: Variant = state.get("machine_jobs", {})
	if machine_jobs is Dictionary:
		for key: Variant in machine_jobs:
			var entry: Variant = (machine_jobs as Dictionary)[key]
			if not (entry is Dictionary):
				continue
			var machine_id: StringName = StringName(String((entry as Dictionary).get("machine_id", &"")))
			if get_machine(machine_id) == null or _machines.has(StringName(String(key))):
				continue
			_machine_jobs[StringName(String(key))] = {
				"machine_id": machine_id,
				"remaining": maxf(float((entry as Dictionary).get("remaining_hours", 0.0)), 0.0),
				"total": maxf(float((entry as Dictionary).get("total_hours", 0.0)), 0.0),
			}
	_apply_effects()
	emit_sim_event(&"modules_state_restored")
	# Re-announce restored modules so world-side mounts stand their pods up (scene load).
	for hardpoint_id: StringName in _installed:
		var module_id: StringName = StringName(_installed[hardpoint_id])
		_emit_typed(&"module_installed", module_id, hardpoint_id)
	# Same for machines, so sockets that were wired after the pods spawned pick them up.
	var restored_machines: Dictionary = get_machines()
	for socket_id: String in restored_machines:
		emit_sim_event(&"machine_fitted", {
			"machine_id": String(restored_machines[socket_id]),
			"socket_id": String(socket_id),
		})
		_emit_typed(&"machine_fitted", StringName(String(restored_machines[socket_id])), StringName(socket_id))


func _finish_job(hardpoint_id: StringName) -> void:
	var job: Dictionary = _jobs[hardpoint_id]
	_jobs.erase(hardpoint_id)
	var module: ShipModule = get_module(StringName(job.get("module_id", &"")))
	if module == null or _installed.has(hardpoint_id):
		return
	_installed[hardpoint_id] = module.module_id
	_register_compartments(module)
	_apply_effects()
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
