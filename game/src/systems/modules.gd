## Installable module catalog: pays material costs out of the hold and registers each built
## module's compartment with the life-support sims. Geometry and construction land in M10.2-M10.3.
class_name ModuleSystem
extends ShipSystem

const REFUSAL_UNKNOWN_MODULE: StringName = &"unknown_module"
const REFUSAL_ALREADY_INSTALLED: StringName = &"already_installed"
const REFUSAL_HARDPOINT_OCCUPIED: StringName = &"hardpoint_occupied"
const REFUSAL_MISSING_MATERIALS: StringName = &"missing_materials"
const REFUSAL_NOT_INSTALLED: StringName = &"not_installed"
const COMPARTMENT_GROUPS: Array[StringName] = [&"atmosphere_system", &"thermal_system", &"hull_system"]

@export var catalog: Array[ShipModule] = []

## hardpoint_id -> module_id
var _installed: Dictionary = {}


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


## Returns &"" when the module can be installed, else the refusal reason.
func can_install(module_id: StringName) -> StringName:
	var module: ShipModule = get_module(module_id)
	if module == null or module.hardpoint_id == &"":
		return REFUSAL_UNKNOWN_MODULE
	if is_installed(module_id):
		return REFUSAL_ALREADY_INSTALLED
	if _installed.has(module.hardpoint_id):
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


func install(module_id: StringName) -> bool:
	var refusal: StringName = can_install(module_id)
	if refusal != &"":
		emit_sim_event(&"module_install_refused", {"module_id": String(module_id), "reason": String(refusal)})
		return false
	var module: ShipModule = get_module(module_id)
	var cargo: Node = _cargo_system()
	for kind: Variant in module.cost:
		var needed: float = float(module.cost[kind])
		if needed > 0.0:
			cargo.call(&"consume_material", StringName(String(kind)), needed)
	_installed[module.hardpoint_id] = module.module_id
	_register_compartments(module)
	emit_sim_event(&"module_installed", {"module_id": String(module_id), "hardpoint_id": String(module.hardpoint_id)})
	_emit_typed(&"module_installed", module.module_id, module.hardpoint_id)
	return true


func uninstall(module_id: StringName) -> bool:
	var module: ShipModule = get_module(module_id)
	if module == null or not is_installed(module_id):
		emit_sim_event(&"module_uninstall_refused", {"module_id": String(module_id), "reason": String(REFUSAL_NOT_INSTALLED)})
		return false
	_installed.erase(module.hardpoint_id)
	_unregister_compartments(module)
	emit_sim_event(&"module_uninstalled", {"module_id": String(module_id), "hardpoint_id": String(module.hardpoint_id)})
	_emit_typed(&"module_uninstalled", module.module_id, module.hardpoint_id)
	return true


func get_status() -> Dictionary:
	var installed: Dictionary = {}
	for hardpoint_id: StringName in _installed:
		installed[String(hardpoint_id)] = String(_installed[hardpoint_id])
	return {
		"system_id": system_id,
		"installed": installed,
		"installed_count": _installed.size(),
	}


func save_state() -> Dictionary:
	return {
		"system_id": String(system_id),
		"state_version": 1,
		"installed": get_status()["installed"],
	}


func load_state(state: Dictionary) -> void:
	_installed.clear()
	var installed: Variant = state.get("installed", {})
	if installed is Dictionary:
		for key: Variant in installed:
			var module_id: StringName = StringName(String(installed[key]))
			if get_module(module_id) != null:
				_installed[StringName(String(key))] = module_id
	for module_id: StringName in get_installed_modules():
		_register_compartments(get_module(module_id))


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
