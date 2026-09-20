## Catalog validation (M10.4): the shipped module data is self-consistent and matches the ship -
## unique ids, unique compartments, hardpoints that exist, materials and circuits that exist,
## effect ids the sims understand, and no dock left without something to build.
extends SceneTree

const KNOWN_EFFECTS: Array[StringName] = [&"", &"rations", &"fabrication", &"cargo", &"power", &"recovery"]
const KNOWN_MATERIALS: Array[StringName] = [&"metal", &"ore", &"ice", &"exotic"]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var modules: Array[ShipModule] = _load_catalog()
	_check(modules.size() >= 5, "the catalog ships at least five modules")
	var ids: Dictionary = {}
	var compartments: Dictionary = {}
	var hardpoints: Dictionary = {}
	for module: ShipModule in modules:
		var label: String = String(module.module_id)
		_check(module.display_name != "", "display name set: " + label)
		_check(module.hardpoint_id != &"", "hardpoint set: " + label)
		_check(module.build_hours > 0.0, "build hours set: " + label)
		_check(module.pod_recipe == &"dock_pod", "pod recipe is the generic pod: " + label)
		_check(not ids.has(module.module_id), "module id is unique: " + label)
		ids[module.module_id] = true
		var config: CompartmentConfig = module.compartment_config
		_check(config != null, "compartment config present: " + label)
		if config != null:
			_check(not compartments.has(config.compartment_id), "compartment id is unique: " + label)
			compartments[config.compartment_id] = true
			_check(config.volume_m3 > 0.0, "compartment volume set: " + label)
		hardpoints[module.hardpoint_id] = true
		for kind: Variant in module.cost:
			_check(KNOWN_MATERIALS.has(StringName(String(kind))), "cost material exists: " + label + " / " + String(kind))
			_check(float(module.cost[kind]) > 0.0, "cost is positive: " + label + " / " + String(kind))
		_check(KNOWN_EFFECTS.has(module.effect), "effect id is known: " + label + " / " + String(module.effect))
		if module.effect != &"":
			_check(module.effect_amount > 0.0, "effect amount set: " + label)
		if module.power_load_w > 0.0:
			_check(module.circuit_id != &"", "a drawing module names its circuit: " + label)

	var docks: Array[StringName] = _dock_hardpoints()
	_check(docks.size() == 4, "the ship has its four docks")
	var built: Dictionary = {}
	for module: ShipModule in modules:
		_check(docks.has(module.hardpoint_id), "hardpoint exists on the ship: " + String(module.module_id))
		built[module.hardpoint_id] = int(built.get(module.hardpoint_id, 0)) + 1
	for dock: StringName in docks:
		_check(int(built.get(dock, 0)) > 0, "dock has something to build: " + String(dock))

	var circuits: Array[StringName] = _circuit_ids()
	var compartment_ids: Array[StringName] = _compartment_ids()
	for module: ShipModule in modules:
		if module.circuit_id != &"":
			_check(circuits.has(module.circuit_id), "circuit exists: " + String(module.module_id) + " / " + String(module.circuit_id))
		_check(compartment_ids.has(module.dock_compartment_id), "dock opens into a real room: " + String(module.module_id))

	var machines: Array[ShipMachine] = _load_machines()
	_check(machines.size() >= 5, "the machine catalog ships at least five machines")
	var machine_ids: Dictionary = {}
	var has_fixed: bool = false
	for machine: ShipMachine in machines:
		var label: String = String(machine.machine_id)
		_check(machine.display_name != "", "machine display name set: " + label)
		_check(machine.build_hours > 0.0, "machine build hours set: " + label)
		_check(machine.size_m.x > 0.0 and machine.size_m.y > 0.0 and machine.size_m.z > 0.0, "machine size set: " + label)
		_check(not machine_ids.has(machine.machine_id), "machine id is unique: " + label)
		machine_ids[machine.machine_id] = true
		_check(KNOWN_EFFECTS.has(machine.effect), "machine effect id is known: " + label)
		if machine.effect != &"":
			_check(machine.effect_amount > 0.0, "machine effect amount set: " + label)
		if machine.power_load_w > 0.0:
			_check(machine.circuit_id != &"" and circuits.has(machine.circuit_id), "machine circuit exists: " + label)
		for kind: Variant in machine.cost:
			_check(KNOWN_MATERIALS.has(StringName(String(kind))), "machine cost material exists: " + label + " / " + String(kind))
		if not machine.portable:
			has_fixed = true
	_check(has_fixed, "the catalog includes fixed (non-portable) machinery")

	if _failures == 0:
		print("PASS: test_module_catalog")
		quit(0)
	else:
		print("FAILURES: ", _failures)
		quit(1)


func _load_catalog() -> Array[ShipModule]:
	var modules: Array[ShipModule] = []
	var dir: DirAccess = DirAccess.open("res://src/data/modules")
	if dir == null:
		return modules
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if not file_name.ends_with(".tres"):
			continue
		var module: ShipModule = load("res://src/data/modules/" + file_name) as ShipModule
		_check(module != null, "module file loads: " + file_name)
		if module != null:
			modules.append(module)
	return modules


func _load_machines() -> Array[ShipMachine]:
	var machines: Array[ShipMachine] = []
	var dir: DirAccess = DirAccess.open("res://src/data/machines")
	if dir == null:
		return machines
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var machine: ShipMachine = load("res://src/data/machines/" + file_name) as ShipMachine
		_check(machine != null, "machine file loads: " + file_name)
		if machine != null:
			machines.append(machine)
	return machines


## The docks the generated hull actually carries, so catalog and ship cannot drift apart.
func _dock_hardpoints() -> Array[StringName]:
	var ids: Array[StringName] = []
	var packed: PackedScene = load("res://scenes/ship_geometry.tscn") as PackedScene
	if packed == null:
		return ids
	var ship: Node = packed.instantiate()
	root.add_child(ship)
	for node: Node in _nodes_in_group(ship, &"dock_plate"):
		var hardpoint: StringName = StringName(node.get_meta(&"hardpoint_id", &""))
		if hardpoint != &"" and not ids.has(hardpoint):
			ids.append(hardpoint)
	ship.free()
	return ids


func _circuit_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var dir: DirAccess = DirAccess.open("res://src/data/power")
	if dir == null:
		return ids
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var circuit: PowerCircuit = load("res://src/data/power/" + file_name) as PowerCircuit
		if circuit != null and circuit.circuit_id != &"":
			ids.append(circuit.circuit_id)
	return ids


func _compartment_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	var dir: DirAccess = DirAccess.open("res://src/data/atmosphere")
	if dir == null:
		return ids
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var config: CompartmentConfig = load("res://src/data/atmosphere/" + file_name) as CompartmentConfig
		if config != null and config.compartment_id != &"":
			ids.append(config.compartment_id)
	return ids


func _nodes_in_group(node: Node, group_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	if node.is_in_group(group_name):
		found.append(node)
	for child: Node in node.get_children():
		found.append_array(_nodes_in_group(child, group_name))
	return found


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures += 1
		print("FAIL: ", label)
