## World layout regression: the generated station furniture, zones, links and doors exist, sit at
## their contracted positions and fit their rooms. Guards the cramped-station layout independently
## of scenes/main.tscn, which swaps this generated scene in.
extends SceneTree

const LAYOUT_PATH: String = "res://scenes/world_layout.tscn"
const POSITION_TOLERANCE: float = 0.001

## Every named child of Props with its contracted position (all rows of the layout table:
## 11 furnished props + 3 sealant cartridges + 7 doors + 3 kit decorations).
const PROP_POSITIONS: Dictionary = {
	"ScrubberUnit": Vector3(-2.6, 0.6, -7.2),
	"WaterReclaimer": Vector3(2.2, 0.6, -2.65),
	"BreakerPanel": Vector3(0.75, 1.5, -3.5),
	"StatusPanel": Vector3(-0.75, 1.5, -8.0),
	"MaintenanceBoard": Vector3(-0.75, 1.6, -13.0),
	"ManualBinder": Vector3(4.7, 0.9, -5.0),
	"LogTerminal": Vector3(2.0, 1.2, -18.7),
	"ArchiveTerminal": Vector3(-2.0, 1.2, -18.7),
	"CommsTerminal": Vector3(3.0, 1.2, -18.7),
	"NavConsole": Vector3(0.0, 1.2, -18.7),
	"ContactConsole": Vector3(1.0, 1.2, -18.7),
	"Bunk": Vector3(-4.6, 0.25, -11.5),
	"HullPatch": Vector3(2.8, 1.2, 7.7),
	"O2CandleRack": Vector3(-1.2, 0.9, -6.8),
	"MultimeterTool": Vector3(-3.9, 0.16, -2.4),
	"WrenchTool": Vector3(-3.5, 0.16, -2.4),
	"ScannerTool": Vector3(-3.1, 0.16, -2.4),
	"ProbePower": Vector3(0.55, 0.35, -4.2),
	"ProbeAtmosphere": Vector3(-3.8, 0.35, -7.2),
	"ProbeThermal": Vector3(3.4, 0.35, 4.7),
	"ProbeHull": Vector3(1.6, 0.35, 7.6),
	"ProbeWater": Vector3(3.4, 0.35, -1.9),
	"SealantCartridge1": Vector3(-3.9, 0.16, -1.8),
	"SealantCartridge2": Vector3(-3.55, 0.16, -1.8),
	"SealantCartridge3": Vector3(-3.2, 0.16, -1.8),
	"DoorCockpit": Vector3(0.0, 1.1, -14.1),
	"DoorEngine": Vector3(0.0, 1.1, 1.5),
	"DoorQuarters": Vector3(-0.8, 1.1, -10.0),
	"DoorLifeSupport": Vector3(-0.8, 1.1, -6.0),
	"DoorStorage": Vector3(-0.8, 1.1, -1.2),
	"DoorGalley": Vector3(0.8, 1.1, -5.6),
	"DoorWaterCloset": Vector3(0.8, 1.1, -1.6),
	"DoorAirlockInner": Vector3(-4.7, 1.1, -1.0),
	"DoorAirlockOuter": Vector3(-6.9, 1.1, -1.2),
	"AirlockPanel": Vector3(-4.86, 1.3, -0.35),
	"SuitLocker": Vector3(-6.3, 1.0, -0.32),
	"ContainerProp": Vector3(-3.0, 0.0, -0.2),
	"ComputerProp": Vector3(1.6, 0.75, -7.0),
	"DisplayProp": Vector3(-2.5, 1.6, -18.7),
}

## prop -> [x_min, x_max, z_min, z_max]. Free-standing props use the strict room interior; the
## wall-mounted panels and doors sit in the wall plane, so their band is the room interior
## +/- the 0.2 m wall thickness, or the doorway gap they close.
const FIT_RECTS: Dictionary = {
	"ScrubberUnit": [-4.4, -0.9, -7.6, -5.0],
	"WaterReclaimer": [0.9, 3.5, -3.0, -0.8],
	"ManualBinder": [0.9, 4.9, -7.6, -4.0],
	"LogTerminal": [-3.4, 3.4, -18.8, -14.2],
	"ArchiveTerminal": [-3.4, 3.4, -18.8, -14.2],
	"CommsTerminal": [-3.4, 3.4, -18.8, -14.2],
	"NavConsole": [-3.4, 3.4, -18.8, -14.2],
	"ContactConsole": [-3.4, 3.4, -18.8, -14.2],
	"Bunk": [-5.4, -0.9, -12.6, -8.2],
	"HullPatch": [-3.6, 3.6, 1.6, 7.8],
	"O2CandleRack": [-4.4, -0.9, -7.6, -5.0],
	"MultimeterTool": [-4.6, -0.9, -3.0, 0.6],
	"WrenchTool": [-4.6, -0.9, -3.0, 0.6],
	"ScannerTool": [-4.6, -0.9, -3.0, 0.6],
	"ProbePower": [-0.7, 0.9, -5.0, -2.2],
	"ProbeAtmosphere": [-4.4, -0.9, -7.6, -5.0],
	"ProbeThermal": [-3.6, 3.6, 1.6, 7.8],
	"ProbeHull": [-3.6, 3.6, 1.6, 7.8],
	"ProbeWater": [0.9, 3.5, -3.0, -0.8],
	"SealantCartridge1": [-4.6, -0.9, -3.0, 0.6],
	"SealantCartridge2": [-4.6, -0.9, -3.0, 0.6],
	"SealantCartridge3": [-4.6, -0.9, -3.0, 0.6],
	"BreakerPanel": [-0.7, 0.9, -5.0, -2.2],
	"StatusPanel": [-0.9, 0.7, -9.4, -6.6],
	"MaintenanceBoard": [-0.9, 0.7, -14.2, -10.6],
	"DoorCockpit": [-0.7, 0.7, -14.2, -14.0],
	"DoorEngine": [-0.7, 0.7, 1.4, 1.6],
	"DoorQuarters": [-0.9, 0.7, -10.6, -9.4],
	"DoorLifeSupport": [-0.9, 0.7, -6.6, -5.4],
	"DoorStorage": [-0.9, 0.7, -1.8, -0.6],
	"DoorGalley": [-0.7, 0.9, -6.2, -5.0],
	"DoorWaterCloset": [-0.7, 0.9, -2.2, -1.0],
	"DoorAirlockInner": [-4.8, -4.6, -1.6, -0.4],
	"DoorAirlockOuter": [-7.0, -6.8, -1.7, -0.7],
	"AirlockPanel": [-6.8, -4.8, -2.2, -0.2],
	"SuitLocker": [-6.8, -4.8, -2.2, -0.2],
	"ContainerProp": [-4.6, -0.9, -3.0, 0.6],
	"ComputerProp": [0.9, 4.9, -7.6, -4.0],
	"DisplayProp": [-3.4, 3.4, -18.8, -14.2],
}

const EXPECTED_ZONES: Dictionary = {
	"ZoneCorridor": &"corridor",
	"ZoneCockpit": &"cockpit",
	"ZoneQuarters": &"quarters",
	"ZoneLifeSupport": &"main",
	"ZoneGalley": &"galley",
	"ZoneWaterCloset": &"water_closet",
	"ZoneStorage": &"storage",
	"ZoneAirlock": &"airlock",
	"ZoneEngineBay": &"engine_bay",
}

const EXPECTED_DOORS: Array[String] = [
	"DoorCockpit",
	"DoorEngine",
	"DoorQuarters",
	"DoorLifeSupport",
	"DoorStorage",
	"DoorGalley",
	"DoorWaterCloset",
	"DoorAirlockInner",
	"DoorAirlockOuter",
]

const EXPECTED_LINKS: Dictionary = {
	"LinkCorridorCockpit": [&"corridor", &"cockpit"],
	"LinkCorridorQuarters": [&"corridor", &"quarters"],
	"LinkCorridorMain": [&"corridor", &"main"],
	"LinkCorridorGalley": [&"corridor", &"galley"],
	"LinkCorridorWaterCloset": [&"corridor", &"water_closet"],
	"LinkCorridorStorage": [&"corridor", &"storage"],
	"LinkCorridorEngineBay": [&"corridor", &"engine_bay"],
	"LinkStorageAirlock": [&"storage", &"airlock"],
}

const CRT_PROPS: Array[String] = [
	"StatusPanel",
	"MaintenanceBoard",
	"LogTerminal",
	"ArchiveTerminal",
	"CommsTerminal",
	"NavConsole",
	"ContactConsole",
]

var _failures: int = 0
var _props: Node3D
var _zones: Node3D
var _links: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_remove_root_child(&"EventBus")
	_remove_root_child(&"SimClock")
	var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
	event_bus.name = &"EventBus"
	root.add_child(event_bus)
	var sim_clock: Node = load("res://src/autoload/sim_clock.gd").new()
	sim_clock.name = &"SimClock"
	root.add_child(sim_clock)

	var packed: PackedScene = load(LAYOUT_PATH) as PackedScene
	_check(packed != null, "world layout scene loads")
	if packed == null:
		_finish()
		return
	var layout: Node3D = packed.instantiate() as Node3D
	_check(layout != null, "world layout instantiates as Node3D")
	if layout == null:
		_finish()
		return
	root.add_child(layout)
	await physics_frame
	await physics_frame

	_check(layout.name == &"WorldLayout", "root is WorldLayout")
	_props = layout.get_node_or_null(^"Props") as Node3D
	_zones = layout.get_node_or_null(^"Zones") as Node3D
	_links = layout.get_node_or_null(^"Links") as Node3D
	_check(_props != null, "Props exists")
	_check(_zones != null, "Zones exists")
	_check(_links != null, "Links exists")
	if _props == null or _zones == null or _links == null:
		layout.free()
		_finish()
		return

	_test_props()
	_test_fit()
	_test_zones()
	_test_links()
	_test_doors()
	_test_crt_props()

	layout.free()
	_finish()


func _test_props() -> void:
	_check(_props.get_child_count() == PROP_POSITIONS.size(), "Props holds all %d named nodes" % PROP_POSITIONS.size())
	for prop_name: String in PROP_POSITIONS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			_check(false, "prop exists: " + prop_name)
			continue
		var expected: Vector3 = PROP_POSITIONS[prop_name]
		_check(prop.position.distance_to(expected) <= POSITION_TOLERANCE, "prop position: " + prop_name)


func _test_fit() -> void:
	for prop_name: String in FIT_RECTS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			_check(false, "fit target exists: " + prop_name)
			continue
		var rect: Array = FIT_RECTS[prop_name]
		var fits: bool = (
			prop.position.x >= float(rect[0]) - POSITION_TOLERANCE
			and prop.position.x <= float(rect[1]) + POSITION_TOLERANCE
			and prop.position.z >= float(rect[2]) - POSITION_TOLERANCE
			and prop.position.z <= float(rect[3]) + POSITION_TOLERANCE
		)
		_check(fits, "prop fits its room: " + prop_name)


func _test_zones() -> void:
	_check(_zones.get_child_count() == EXPECTED_ZONES.size(), "Zones holds %d zones" % EXPECTED_ZONES.size())
	for zone_name: String in EXPECTED_ZONES:
		var zone: Node = _zones.get_node_or_null(NodePath(zone_name))
		if zone == null:
			_check(false, "zone exists: " + zone_name)
			continue
		_check(zone.get("compartment_id") == EXPECTED_ZONES[zone_name], "zone compartment_id: " + zone_name)
		var shape: CollisionShape3D = zone.get_node_or_null(^"Shape") as CollisionShape3D
		_check(shape != null and shape.shape is BoxShape3D, "zone has a box shape: " + zone_name)


func _test_links() -> void:
	_check(_links.get_child_count() == EXPECTED_LINKS.size(), "Links holds %d links" % EXPECTED_LINKS.size())
	for link_name: String in EXPECTED_LINKS:
		var link: Node = _links.get_node_or_null(NodePath(link_name))
		if link == null:
			_check(false, "link exists: " + link_name)
			continue
		var pair: Array = EXPECTED_LINKS[link_name]
		var forward: bool = link.get("compartment_a") == pair[0] and link.get("compartment_b") == pair[1]
		var reverse: bool = link.get("compartment_a") == pair[1] and link.get("compartment_b") == pair[0]
		_check(forward or reverse, "link connects %s and %s" % [pair[0], pair[1]])


func _test_doors() -> void:
	var found: int = 0
	for door_name: String in EXPECTED_DOORS:
		var door: Node = _props.get_node_or_null(NodePath(door_name))
		if door == null:
			_check(false, "door exists: " + door_name)
			continue
		found += 1
		var slab: MeshInstance3D = door.get_node_or_null(^"Slab") as MeshInstance3D
		var slab_shape: CollisionShape3D = door.get_node_or_null(^"SlabShape") as CollisionShape3D
		_check(slab != null and slab.mesh is BoxMesh, "door slab mesh: " + door_name)
		_check(slab_shape != null and slab_shape.shape is BoxShape3D, "door slab collision: " + door_name)
		var frame: StaticBody3D = door.get_node_or_null(^"Frame") as StaticBody3D
		_check(frame != null and frame.collision_layer == 2 and frame.collision_mask == 0, "door keeps a sensor frame: " + door_name)
	_check(found == EXPECTED_DOORS.size(), "all %d doors found" % EXPECTED_DOORS.size())


func _test_crt_props() -> void:
	for prop_name: String in CRT_PROPS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			_check(false, "crt prop exists: " + prop_name)
			continue
		var screen: MeshInstance3D = prop.get_node_or_null(^"Crt/Screen") as MeshInstance3D
		var housing: MeshInstance3D = prop.get_node_or_null(^"Crt/Housing") as MeshInstance3D
		_check(screen != null and screen.material_override != null, "crt screen mesh: " + prop_name)
		_check(housing != null, "crt housing mesh: " + prop_name)


func _remove_root_child(node_name: StringName) -> void:
	for child: Node in root.get_children():
		if child.name == node_name:
			root.remove_child(child)
			child.free()
			return


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_world_layout")
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
