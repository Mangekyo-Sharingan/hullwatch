## GENERATED station furniture: builds the cramped-station props, doors, kit decorations, atmosphere
## zones and compartment links from the tables below into res://scenes/world_layout.tscn.
## Everything is built in memory and packed, so the layout is reproducible from this one file.
## Re-run after changing the layout:
## & ".\Engine\Godot_v4.7.2-stable_win64_console.exe" --headless --path game --script res://tools/build_world_layout.gd
extends SceneTree

const OUTPUT_PATH: String = "res://scenes/world_layout.tscn"

const MATERIAL_MACHINE_TEAL: String = "res://src/data/materials/mat_machine_teal.tres"
const MATERIAL_PANEL_SCRATCHED: String = "res://src/data/materials/mat_panel_scratched.tres"
const MATERIAL_WALL_PAINTED: String = "res://src/data/materials/mat_wall_painted.tres"
const MATERIAL_FLOOR_GRATE: String = "res://src/data/materials/mat_floor_grate.tres"
const MATERIAL_METAL_RUSTED: String = "res://src/data/materials/mat_metal_rusted.tres"
const MATERIAL_SCREEN_GLOW: String = "res://src/data/materials/mat_screen_glow.tres"

const MANUAL_BOOK: String = "res://src/data/manual/manual_book.tres"
const LOG_ENTRY: String = "res://src/data/logs/log_01.tres"
const LOG_ENTRY_2: String = "res://src/data/logs/log_02.tres"

const KIT_CONTAINER: String = "res://assets/models/kenney_space_station_kit/Models/GLB format/container.glb"
const KIT_COMPUTER: String = "res://assets/models/kenney_space_station_kit/Models/GLB format/computer-system.glb"
const KIT_DISPLAY: String = "res://assets/models/kenney_space_station_kit/Models/GLB format/display-wall.glb"

const SCRIPT_ZONE: String = "res://src/world/compartment_zone.gd"
const SCRIPT_LINK: String = "res://src/world/compartment_link.gd"

const MATERIAL_PATHS: Array[String] = [
	MATERIAL_MACHINE_TEAL,
	MATERIAL_PANEL_SCRATCHED,
	MATERIAL_WALL_PAINTED,
	MATERIAL_FLOOR_GRATE,
	MATERIAL_METAL_RUSTED,
	MATERIAL_SCREEN_GLOW,
]

const RESOURCE_PATHS: Array[String] = [MANUAL_BOOK, LOG_ENTRY, LOG_ENTRY_2]

const KIT_PATHS: Array[String] = [KIT_CONTAINER, KIT_COMPUTER, KIT_DISPLAY]

## Furnished props: StaticBody3D + Shape (CollisionShape3D/BoxShape3D) + Mesh (MeshInstance3D/BoxMesh).
## "exports" are sim-facing script properties, "resources" are resource exports resolved by path.
const PROPS: Array[Dictionary] = [
	{
		"name": "ScrubberUnit",
		"script": "res://src/interactables/scrubber_unit.gd",
		"position": Vector3(-2.6, 0.6, -7.2),
		"size": Vector3(1.0, 1.2, 0.5),
		"material": MATERIAL_MACHINE_TEAL,
		"exports": {"compartment_id": &"main", "part_id": &"filter_co2", "circuit_id": &"scrubber"},
	},
	{
		"name": "WaterReclaimer",
		"script": "res://src/interactables/water_reclaimer.gd",
		"position": Vector3(2.2, 0.6, -2.65),
		"size": Vector3(0.8, 1.2, 0.5),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {},
	},
	{
		"name": "BreakerPanel",
		"script": "res://src/interactables/breaker_panel.gd",
		"position": Vector3(0.75, 1.5, -3.5),
		"size": Vector3(0.15, 1.0, 0.7),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"circuit_id": &"lighting"},
	},
	{
		"name": "StatusPanel",
		"script": "res://src/ui/status_panel.gd",
		"position": Vector3(-0.75, 1.5, -8.0),
		"size": Vector3(0.15, 1.0, 0.7),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"compartment_id": &"main"},
	},
	{
		"name": "MaintenanceBoard",
		"script": "res://src/interactables/maintenance_board.gd",
		"position": Vector3(-0.75, 1.6, -13.0),
		"size": Vector3(0.9, 0.7, 0.1),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
	},
	{
		"name": "ManualBinder",
		"script": "res://src/interactables/manual_binder.gd",
		"position": Vector3(4.7, 0.9, -5.0),
		"size": Vector3(0.45, 0.32, 0.3),
		"material": MATERIAL_WALL_PAINTED,
		"exports": {},
		"resources": {"book": MANUAL_BOOK},
	},
	{
		"name": "LogTerminal",
		"script": "res://src/interactables/log_terminal.gd",
		"position": Vector3(2.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
		"resources": {"log_entry": LOG_ENTRY},
	},
	{
		"name": "CommsTerminal",
		"script": "res://src/interactables/comms_terminal.gd",
		"position": Vector3(3.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
	},
	{
		"name": "ArchiveTerminal",
		"script": "res://src/interactables/log_terminal.gd",
		"position": Vector3(-2.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {},
		"resources": {"log_entry": LOG_ENTRY_2},
	},
	{
		"name": "NavConsole",
		"script": "res://src/interactables/nav_console.gd",
		"position": Vector3(0.0, 1.2, -18.7),
		"size": Vector3(0.15, 0.5, 0.6),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"waypoint_id": &"relay_cache"},
	},
	{
		"name": "Bunk",
		"script": "res://src/interactables/bunk.gd",
		"position": Vector3(-4.6, 0.25, -11.5),
		"size": Vector3(1.0, 0.5, 2.0),
		"material": MATERIAL_FLOOR_GRATE,
		"exports": {"sleep_hours": 8.0},
	},
	{
		"name": "HullPatch",
		"script": "res://src/interactables/hull_patch.gd",
		"position": Vector3(2.8, 1.2, 7.7),
		"size": Vector3(0.6, 0.6, 0.12),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"compartment_id": &"main"},
	},
	{
		"name": "O2CandleRack",
		"script": "res://src/interactables/o2_candle.gd",
		"position": Vector3(-1.2, 0.9, -6.8),
		"size": Vector3(0.3, 0.2, 0.3),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"compartment_id": &"main"},
	},
	{
		"name": "MultimeterTool",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.9, 0.16, -2.4),
		"size": Vector3(0.22, 0.14, 0.3),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"item_id": &"multimeter", "item_name": "Multimeter"},
	},
	{
		"name": "WrenchTool",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.5, 0.16, -2.4),
		"size": Vector3(0.4, 0.08, 0.1),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"wrench", "item_name": "Wrench"},
	},
	{
		"name": "ScannerTool",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.1, 0.16, -2.4),
		"size": Vector3(0.26, 0.18, 0.22),
		"material": MATERIAL_PANEL_SCRATCHED,
		"exports": {"item_id": &"scanner", "item_name": "Wear scanner"},
	},
	{
		"name": "ProbePower",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(0.55, 0.35, -4.2),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"power_system"},
	},
	{
		"name": "ProbeAtmosphere",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(-3.8, 0.35, -7.2),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"atmosphere_system"},
	},
	{
		"name": "ProbeThermal",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(3.4, 0.35, 4.7),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"thermal_system"},
	},
	{
		"name": "ProbeHull",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(1.6, 0.35, 7.6),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"hull_system"},
	},
	{
		"name": "ProbeWater",
		"script": "res://src/interactables/diagnostic_probe.gd",
		"position": Vector3(3.4, 0.35, -1.9),
		"size": Vector3(0.2, 0.2, 0.2),
		"material": MATERIAL_SCREEN_GLOW,
		"exports": {"system_group": &"water_system"},
	},
	{
		"name": "SealantCartridge1",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.9, 0.16, -1.8),
		"size": Vector3(0.18, 0.32, 0.18),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"sealant", "item_name": "Sealant cartridge"},
	},
	{
		"name": "SealantCartridge2",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.55, 0.16, -1.8),
		"size": Vector3(0.18, 0.32, 0.18),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"sealant", "item_name": "Sealant cartridge"},
	},
	{
		"name": "SealantCartridge3",
		"script": "res://src/interactables/carriable.gd",
		"position": Vector3(-3.2, 0.16, -1.8),
		"size": Vector3(0.18, 0.32, 0.18),
		"material": MATERIAL_METAL_RUSTED,
		"exports": {"item_id": &"sealant", "item_name": "Sealant cartridge"},
	},
]

## Pressure doors: StaticBody3D + Slab (MeshInstance3D) + SlabShape (CollisionShape3D); the door
## script owns the open/close motion of both children.
const DOORS: Array[Dictionary] = [
	{
		"name": "DoorCockpit",
		"position": Vector3(0.0, 1.1, -14.1),
		"size": Vector3(1.4, 2.2, 0.16),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"cockpit"},
	},
	{
		"name": "DoorEngine",
		"position": Vector3(0.0, 1.1, 1.5),
		"size": Vector3(1.4, 2.2, 0.16),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"engine_bay"},
	},
	{
		"name": "DoorQuarters",
		"position": Vector3(-0.8, 1.1, -10.0),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"quarters"},
	},
	{
		"name": "DoorLifeSupport",
		"position": Vector3(-0.8, 1.1, -6.0),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"main"},
	},
	{
		"name": "DoorStorage",
		"position": Vector3(-0.8, 1.1, -1.2),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"storage"},
	},
	{
		"name": "DoorGalley",
		"position": Vector3(0.8, 1.1, -5.6),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"galley"},
	},
	{
		"name": "DoorWaterCloset",
		"position": Vector3(0.8, 1.1, -1.6),
		"size": Vector3(0.16, 2.2, 1.2),
		"exports": {"compartment_a": &"corridor", "compartment_b": &"water_closet"},
	},
]

## Kit-scene decorations: visual only, no collision added by this generator.
const KIT_PROPS: Array[Dictionary] = [
	{"name": "ContainerProp", "scene": KIT_CONTAINER, "position": Vector3(-3.0, 0.0, -0.2)},
	{"name": "ComputerProp", "scene": KIT_COMPUTER, "position": Vector3(1.6, 0.75, -7.0)},
	{"name": "DisplayProp", "scene": KIT_DISPLAY, "position": Vector3(-2.5, 1.6, -18.7)},
]

## Atmosphere occupancy zones: Area3D + script + one BoxShape3D child named Shape.
const ZONES: Array[Dictionary] = [
	{"name": "ZoneCorridor", "size": Vector3(1.4, 3.0, 15.4), "position": Vector3(0.0, 1.5, -6.3), "exports": {"compartment_id": &"corridor"}},
	{"name": "ZoneCockpit", "size": Vector3(6.8, 3.0, 4.6), "position": Vector3(0.0, 1.5, -16.5), "exports": {"compartment_id": &"cockpit"}},
	{"name": "ZoneQuarters", "size": Vector3(4.5, 3.0, 4.4), "position": Vector3(-3.15, 1.5, -10.4), "exports": {"compartment_id": &"quarters"}},
	{"name": "ZoneLifeSupport", "size": Vector3(3.5, 3.0, 2.6), "position": Vector3(-2.65, 1.5, -6.3), "exports": {"compartment_id": &"main"}},
	{"name": "ZoneGalley", "size": Vector3(4.0, 3.0, 3.6), "position": Vector3(2.9, 1.5, -5.8), "exports": {"compartment_id": &"galley"}},
	{"name": "ZoneWaterCloset", "size": Vector3(2.6, 3.0, 2.2), "position": Vector3(2.2, 1.5, -1.9), "exports": {"compartment_id": &"water_closet"}},
	{"name": "ZoneStorage", "size": Vector3(3.7, 3.0, 3.6), "position": Vector3(-2.75, 1.5, -1.2), "exports": {"compartment_id": &"storage"}},
	{"name": "ZoneEngineBay", "size": Vector3(7.2, 3.0, 6.2), "position": Vector3(0.0, 1.5, 4.7), "exports": {"compartment_id": &"engine_bay"}},
]

## Atmosphere mixing links: corridor paired with every side compartment.
const LINKS: Array[Dictionary] = [
	{"name": "LinkCorridorCockpit", "exports": {"compartment_a": &"corridor", "compartment_b": &"cockpit"}},
	{"name": "LinkCorridorQuarters", "exports": {"compartment_a": &"corridor", "compartment_b": &"quarters"}},
	{"name": "LinkCorridorMain", "exports": {"compartment_a": &"corridor", "compartment_b": &"main"}},
	{"name": "LinkCorridorGalley", "exports": {"compartment_a": &"corridor", "compartment_b": &"galley"}},
	{"name": "LinkCorridorWaterCloset", "exports": {"compartment_a": &"corridor", "compartment_b": &"water_closet"}},
	{"name": "LinkCorridorStorage", "exports": {"compartment_a": &"corridor", "compartment_b": &"storage"}},
	{"name": "LinkCorridorEngineBay", "exports": {"compartment_a": &"corridor", "compartment_b": &"engine_bay"}},
]

var _root: Node3D
var _props: Node3D
var _zones: Node3D
var _links: Node3D
var _materials: Dictionary = {}
var _resources: Dictionary = {}
var _scenes: Dictionary = {}
var _failures: int = 0


func _initialize() -> void:
	_load_assets()
	if _failures == 0:
		_build()
	_save()


func _load_assets() -> void:
	for path: String in MATERIAL_PATHS:
		var material: Material = load(path) as Material
		if material == null:
			_failures += 1
			print("FAIL: missing material ", path)
		else:
			_materials[path] = material
	for path: String in RESOURCE_PATHS:
		var resource: Resource = load(path) as Resource
		if resource == null:
			_failures += 1
			print("FAIL: missing resource ", path)
		else:
			_resources[path] = resource
	for path: String in KIT_PATHS:
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			_failures += 1
			print("FAIL: missing kit scene ", path)
		else:
			_scenes[path] = scene


func _build() -> void:
	_root = Node3D.new()
	_root.name = "WorldLayout"
	_props = _make_group("Props")
	_zones = _make_group("Zones")
	_links = _make_group("Links")
	for spec: Dictionary in PROPS:
		_build_prop(spec)
	for spec: Dictionary in DOORS:
		_build_door(spec)
	for spec: Dictionary in KIT_PROPS:
		_build_kit(spec)
	for spec: Dictionary in ZONES:
		_build_zone(spec)
	for spec: Dictionary in LINKS:
		_build_link(spec)


func _make_group(group_name: String) -> Node3D:
	var group: Node3D = Node3D.new()
	group.name = group_name
	_root.add_child(group)
	return group


func _build_prop(spec: Dictionary) -> void:
	var prop: StaticBody3D = StaticBody3D.new()
	prop.name = String(spec["name"])
	prop.position = spec["position"]
	prop.set_script(load(String(spec["script"])) as Script)
	_apply_exports(prop, spec)
	_props.add_child(prop)
	_add_box_children(prop, spec["size"], String(spec["material"]))


func _build_door(spec: Dictionary) -> void:
	var door: StaticBody3D = StaticBody3D.new()
	door.name = String(spec["name"])
	door.position = spec["position"]
	door.set_script(load("res://src/interactables/door.gd") as Script)
	_apply_exports(door, spec)
	_props.add_child(door)
	var size: Vector3 = spec["size"]
	var slab_mesh: BoxMesh = BoxMesh.new()
	slab_mesh.size = size
	var slab: MeshInstance3D = MeshInstance3D.new()
	slab.name = "Slab"
	slab.mesh = slab_mesh
	slab.material_override = _materials[MATERIAL_PANEL_SCRATCHED] as Material
	door.add_child(slab)
	var slab_box: BoxShape3D = BoxShape3D.new()
	slab_box.size = size
	var slab_shape: CollisionShape3D = CollisionShape3D.new()
	slab_shape.name = "SlabShape"
	slab_shape.shape = slab_box
	door.add_child(slab_shape)


func _build_kit(spec: Dictionary) -> void:
	var packed: PackedScene = _scenes[String(spec["scene"])] as PackedScene
	var instance: Node3D = packed.instantiate() as Node3D
	instance.name = String(spec["name"])
	instance.position = spec["position"]
	_props.add_child(instance)


func _build_zone(spec: Dictionary) -> void:
	var zone: Area3D = Area3D.new()
	zone.name = String(spec["name"])
	zone.position = spec["position"]
	zone.set_script(load(SCRIPT_ZONE) as Script)
	_apply_exports(zone, spec)
	_zones.add_child(zone)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = spec["size"]
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box
	zone.add_child(shape)


func _build_link(spec: Dictionary) -> void:
	var link: Node = Node.new()
	link.name = String(spec["name"])
	link.set_script(load(SCRIPT_LINK) as Script)
	_apply_exports(link, spec)
	_links.add_child(link)


func _add_box_children(parent: StaticBody3D, size: Vector3, material_path: String) -> void:
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = box_shape
	parent.add_child(shape)
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = box_mesh
	mesh.material_override = _materials[material_path] as Material
	parent.add_child(mesh)


func _apply_exports(node: Object, spec: Dictionary) -> void:
	var exports: Dictionary = spec.get("exports", {})
	for key: String in exports:
		node.set(key, exports[key])
	var resources: Dictionary = spec.get("resources", {})
	for key: String in resources:
		node.set(key, _resources[String(resources[key])])


func _save() -> void:
	if _failures > 0 or _root == null:
		print("FAILURES: ", _failures)
		quit(1)
		return
	_assign_owners(_root, _root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(_root)
	if pack_error != OK:
		print("FAIL: pack error ", pack_error)
		quit(1)
		return
	var save_error: Error = ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		print("FAIL: save error ", save_error)
		quit(1)
		return
	_root.free()
	_root = null
	if not _normalize_output():
		print("FAILURES: ", _failures)
		quit(1)
		return
	if not _verify():
		print("FAILURES: ", _failures)
		quit(1)
		return
	print("PASS: build_world_layout")
	quit(0)


## PackedScene.pack() assigns random per-run node unique_ids; strip them so regenerating is byte-stable.
func _normalize_output() -> bool:
	var output_path: String = ProjectSettings.globalize_path(OUTPUT_PATH)
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		_failures += 1
		print("FAIL: cannot reopen ", OUTPUT_PATH)
		return false
	var text: String = file.get_as_text()
	file.close()
	var regex: RegEx = RegEx.new()
	regex.compile(" unique_id=\\d+")
	var write_file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if write_file == null:
		_failures += 1
		print("FAIL: cannot rewrite ", OUTPUT_PATH)
		return false
	write_file.store_string(regex.sub(text, "", true))
	write_file.close()
	return true


## Instanced kit scenes keep their internal owner (the instance root); only their root is owned
## by the packed scene, so pack() records an instance reference instead of baking the geometry.
func _assign_owners(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		if child.scene_file_path != "":
			continue
		_assign_owners(child, owner)


func _verify() -> bool:
	var loaded: PackedScene = load(OUTPUT_PATH) as PackedScene
	if loaded == null:
		_failures += 1
		print("FAIL: generated scene did not load")
		return false
	var instance: Node = loaded.instantiate()
	var props: Node = instance.get_node_or_null(^"Props")
	var zones: Node = instance.get_node_or_null(^"Zones")
	var links: Node = instance.get_node_or_null(^"Links")
	if props == null or zones == null or links == null:
		_failures += 1
		print("FAIL: generated scene missing Props/Zones/Links")
		instance.free()
		return false
	_verify_props(props)
	_verify_zones(zones)
	_verify_links(links)
	print("OK: props=", props.get_child_count(), " zones=", zones.get_child_count(), " links=", links.get_child_count())
	instance.free()
	return _failures == 0


func _verify_props(props: Node) -> void:
	for spec: Dictionary in PROPS:
		var prop: Node = props.get_node_or_null(NodePath(String(spec["name"])))
		if prop == null:
			_failures += 1
			print("FAIL: missing prop ", spec["name"])
			continue
		if prop.get_node_or_null(^"Shape") == null or prop.get_node_or_null(^"Mesh") == null:
			_failures += 1
			print("FAIL: prop missing Shape/Mesh: ", spec["name"])
	for spec: Dictionary in DOORS:
		var door: Node = props.get_node_or_null(NodePath(String(spec["name"])))
		if door == null:
			_failures += 1
			print("FAIL: missing door ", spec["name"])
			continue
		if door.get_node_or_null(^"Slab") == null or door.get_node_or_null(^"SlabShape") == null:
			_failures += 1
			print("FAIL: door missing Slab/SlabShape: ", spec["name"])
	for spec: Dictionary in KIT_PROPS:
		if props.get_node_or_null(NodePath(String(spec["name"]))) == null:
			_failures += 1
			print("FAIL: missing kit prop ", spec["name"])


func _verify_zones(zones: Node) -> void:
	for spec: Dictionary in ZONES:
		var zone: Node = zones.get_node_or_null(NodePath(String(spec["name"])))
		if zone == null:
			_failures += 1
			print("FAIL: missing zone ", spec["name"])
			continue
		if zone.get_node_or_null(^"Shape") == null:
			_failures += 1
			print("FAIL: zone missing Shape: ", spec["name"])


func _verify_links(links: Node) -> void:
	for spec: Dictionary in LINKS:
		if links.get_node_or_null(NodePath(String(spec["name"]))) == null:
			_failures += 1
			print("FAIL: missing link ", spec["name"])
