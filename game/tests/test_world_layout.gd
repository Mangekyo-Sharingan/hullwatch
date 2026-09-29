## World layout regression (tube chain): the flat tables' furniture, doors, zones and links
## all made it onto the chain. Props sit inside their own tunnel section hugged to its
## canted wall (never embedded, never across the centre line), the EVA platform kit stands
## off the airlock, joint doors ship open with their slabs stowed while the airlock's two
## hatches stay shut, each room has one occupancy volume across all its sections, and one
## atmosphere link crosses every hatched joint.
extends SceneTree

const LAYOUT_PATH: String = "res://scenes/world_layout.tscn"
const POSITION_TOLERANCE: float = 0.02

class MockPowerSystem extends Node:
	var battery_fraction: float = 0.2

	func get_status() -> Dictionary:
		return {"battery_fraction": battery_fraction, "brownout": false, "circuits": {}}

## The carried furniture (names are the contract; the tube derives their positions).
const CARRIED_PROPS: Array[String] = [
	"ScrubberUnit", "WaterReclaimer", "BreakerPanel", "StatusPanel", "MaintenanceBoard",
	"ManualBinder", "LogTerminal", "CommsTerminal", "ArchiveTerminal", "NavConsole",
	"ContactConsole", "Bunk", "HullPatch", "O2CandleRack", "MultimeterTool", "WrenchTool",
	"ScannerTool", "ProbePower", "ProbeAtmosphere", "ProbeThermal", "ProbeHull",
	"ProbeWater", "SealantCartridge1", "SealantCartridge2", "SealantCartridge3",
	"Fabricator", "CutterTool", "SampleCanister2", "SampleCanister3", "AirlockPanel",
	"SuitLocker", "ContainerProp", "ComputerProp", "PilotChair",
	"SwitchBank", "GaugeCluster", "SevenSegment", "WallComputer",
	"CrewLocker", "MessTable", "FilterRack", "ToolCart",
	"CrateStack", "ShelfUnit", "GalleyUnit",
]

## Gear that belongs on the EVA platform outside the airlock, not inside the tube.
const PLATFORM_PROPS: Array[String] = ["CargoPort", "SampleCanister1"]

const CRT_PROPS: Array[String] = [
	"StatusPanel", "MaintenanceBoard", "LogTerminal", "ArchiveTerminal", "CommsTerminal",
	"NavConsole", "ContactConsole",
]

var _failures: int = 0
var _props: Node3D
var _zones: Node3D
var _links: Node3D
var _power: MockPowerSystem


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
	_power = MockPowerSystem.new()
	_power.name = &"TestPowerSystem"
	_power.add_to_group(&"power_system")
	root.add_child(_power)

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

	var expected_total: int = CARRIED_PROPS.size() + PLATFORM_PROPS.size() + _expected_doors().size()
	_check(_props.get_child_count() == expected_total, "Props holds all %d named nodes (%d)" % [expected_total, _props.get_child_count()])

	_test_props_carry()
	_test_cockpit_instruments()
	_test_pilot_chair_clearance()
	_test_doors()
	_test_zones()
	_test_links()
	await _test_crt_props()

	layout.free()
	_finish()


## Every carried prop exists, sits inside a walkable section, and its own bounding box
## clears the section's canted wall (at the box's bottom height, where the wall is nearest)
## and leaves a walkable lane from its inboard face across to the opposite wall. Platform
## gear stands off the airlock's drum face.
func _test_props_carry() -> void:
	for prop_name: String in CARRIED_PROPS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			_check(false, "carried prop exists: " + prop_name)
			continue
		var nearest: Dictionary = _nearest_walkable(prop.position.z)
		if nearest.is_empty():
			_check(false, "carried prop sits in the chain: " + prop_name)
			continue
		var box: AABB = _world_bounds(prop)
		if box.size == Vector3.ZERO:
			_check(false, "carried prop has meshes: " + prop_name)
			continue
		var radius: float = float(nearest["radius"])
		var side: float = signf(prop.position.x) if absf(prop.position.x) > 0.01 else 1.0
		var inboard: float = box.end.x if side < 0.0 else box.position.x
		var lane: float = SectionHull.tube_half_width(radius, 1.0) + side * inboard
		_check(lane >= 0.55, "carried prop leaves a walkable lane: " + prop_name)
		var outboard: float = -box.position.x if side < 0.0 else box.end.x
		_check(outboard <= SectionHull.tube_half_width(radius, maxf(box.position.y, 0.0)) + 0.03, "carried prop clears the canted wall: " + prop_name)
		_check(box.position.y >= -0.05, "carried prop sits above the deck: " + prop_name)
	for prop_name: String in PLATFORM_PROPS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			_check(false, "platform prop exists: " + prop_name)
			continue
		var airlock: int = TubeLayout.index_of("airlock")
		var face: float = float(TubeLayout.sections()[airlock]["radius"]) + SectionHull.TUBE_BAND
		_check(prop.position.x < -face, "platform prop stands off the airlock's drum face: " + prop_name)


func _test_cockpit_instruments() -> void:
	var cupola: Vector2 = TubeLayout.span(TubeLayout.index_of("cupola"))
	var cockpit: Vector2 = TubeLayout.span(TubeLayout.index_of("cockpit"))
	var front_row: Array[String] = ["SwitchBank", "GaugeCluster", "SevenSegment"]
	var previous_x: float = -INF
	for prop_name: String in ["GaugeCluster", "SevenSegment", "SwitchBank"]:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		_check(prop != null and prop.position.z >= cupola.x and prop.position.z <= cockpit.y, "%s belongs to the cockpit" % prop_name)
		_check(prop is CockpitInstrumentPanel, "%s drives its authored live instrument" % prop_name)
	for prop_name: String in front_row:
		var panel: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if panel == null:
			continue
		_check(absf(panel.position.z - (cupola.x + 0.18)) < 0.05, "%s sits on the forward instrument row" % prop_name)
		_check(panel.position.x > previous_x, "%s follows the forward grid" % prop_name)
		previous_x = panel.position.x
	var station_rows: Array[Array] = [["LogTerminal", "ContactConsole", "NavConsole"], ["WallComputer", "ArchiveTerminal", "CommsTerminal"]]
	for side: int in station_rows.size():
		var previous_z: float = -INF
		for station_name: String in station_rows[side]:
			var station: Node3D = _props.get_node_or_null(NodePath(station_name)) as Node3D
			if station == null:
				continue
			var box: AABB = _world_bounds(station)
			var outer: float = box.end.x if side == 0 else -box.position.x
			_check(absf(SectionHull.tube_half_width(2.4, box.position.y) - outer) < 0.12, "%s mounts flush to the cockpit wall" % station_name)
			_check(absf(station.position.y - 1.25) < 0.01 and station.position.z > previous_z and station.position.z >= cupola.x and station.position.z <= cupola.y, "%s follows the cupola station grid" % station_name)
			previous_z = station.position.z
	var chair: PilotChair = _props.get_node_or_null(^"PilotChair") as PilotChair
	_check(chair != null and chair.position.z >= cupola.x and chair.position.z < cupola.y, "pilot chair mounts inside the cupola")
	_check(chair != null and absf(chair.position.x) < 0.02 and absf(chair.position.z - (cupola.x + cupola.y) * 0.5) < 0.2, "pilot chair is centered between cockpit stations")


func _test_pilot_chair_clearance() -> void:
	var chair: PilotChair = _props.get_node_or_null(^"PilotChair") as PilotChair
	if chair == null:
		return
	var seat: CollisionShape3D = chair.get_node_or_null(^"SeatShape") as CollisionShape3D
	var shape: BoxShape3D = seat.shape as BoxShape3D if seat != null else null
	_check(seat != null and seat.disabled, "folded pilot seat carries a disabled collision shape")
	_check(shape != null and SectionHull.tube_half_width(2.4, 0.58) - shape.size.x * 0.5 > 1.5, "side aisles clear the centered chair")
	_check(chair.get_exit_world_position().z < TubeLayout.span(TubeLayout.index_of("cockpit")).x, "seat exit remains inside the cupola")


## One door per hatched joint - open with the slab stowed, except the storage/airlock joint
## which the airlock's inner hatch closes - plus the airlock's outer hatch, shut.
func _test_doors() -> void:
	var expected: Array[String] = _expected_doors()
	for door_name: String in expected:
		var door: Node = _props.get_node_or_null(NodePath(door_name))
		if door == null:
			_check(false, "door exists: " + door_name)
			continue
		var slab: Node = door.get_node_or_null(^"Slab")
		var slab_shape: CollisionShape3D = door.get_node_or_null(^"SlabShape") as CollisionShape3D
		var slab_ok: bool = false
		if slab is MeshInstance3D:
			var slab_mesh: Mesh = (slab as MeshInstance3D).mesh
			slab_ok = slab_mesh != null and not (slab_mesh is BoxMesh)
		elif slab != null:
			slab_ok = slab.find_children("*", "MeshInstance3D", true, false).size() > 0
		_check(slab_ok, "door slab uses the authored leaf: " + door_name)
		_check(slab_shape != null and slab_shape.shape is BoxShape3D, "door slab collision: " + door_name)
		var frame: StaticBody3D = door.get_node_or_null(^"Frame") as StaticBody3D
		_check(frame != null and frame.collision_layer == 2 and frame.collision_mask == 0, "door keeps a sensor frame: " + door_name)
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		var aft_room: StringName = StringName(TubeLayout.sections()[index].get("room", &""))
		var fore_room: StringName = StringName(TubeLayout.sections()[index + 1].get("room", &""))
		var joint_z: float = (TubeLayout.span(index).y + TubeLayout.span(index + 1).x) * 0.5
		var airlock_joint: bool = (aft_room == &"storage" and fore_room == &"airlock") or (aft_room == &"airlock" and fore_room == &"storage")
		var door_name: String = "DoorAirlockInner" if airlock_joint else "DoorJoint_%s_%s" % [
			String(TubeLayout.sections()[index]["name"]),
			String(TubeLayout.sections()[index + 1]["name"]),
		]
		var door: Node = _props.get_node_or_null(NodePath(door_name))
		if door == null:
			_check(false, "joint door exists: " + door_name)
			continue
		var expected_open: bool = not airlock_joint
		_check(bool(door.get("starts_open")) == expected_open and bool(door.get("hide_when_open")) == expected_open, "joint door ships open with its slab stowed: " + door_name)
		var position: Vector3 = (door as Node3D).position
		_check(absf(position.z - joint_z) <= POSITION_TOLERANCE, "joint door sits at its bulkhead: " + door_name)
		if airlock_joint:
			_check(absf(position.y - TubeLayout.HATCH_HEIGHT * 0.5) <= 0.001, "airlock inner door is centred on its hatch: " + door_name)
	_check(_airlock_outer_door_ok(), "airlock outer hatch sits shut on its radial opening")


func _airlock_outer_door_ok() -> bool:
	var airlock: int = TubeLayout.index_of("airlock")
	if airlock < 0:
		return false
	var door: Node = _props.get_node_or_null(^"DoorAirlockOuter")
	if door == null or bool(door.get("starts_open")):
		return false
	var radius: float = float(TubeLayout.sections()[airlock]["radius"])
	var center_z: float = (TubeLayout.span(airlock).x + TubeLayout.span(airlock).y) * 0.5
	var position: Vector3 = (door as Node3D).position
	return absf(position.x + radius + 0.08) <= POSITION_TOLERANCE and absf(position.z - center_z) <= POSITION_TOLERANCE


## One zone per unique room: it spans all sections, including both engine-bay levels.
func _test_zones() -> void:
	var expected_zones: int = 0
	for room_value: Variant in TubeLayout.ROOM_COMPARTMENTS:
		var room: StringName = StringName(room_value)
		var sections: Array[int] = TubeLayout.sections_for_room(room)
		if sections.is_empty():
			continue
		expected_zones += 1
		var first: int = sections[0]
		var last: int = sections[-1]
		var zone_name: String = "ZoneRoom_" + String(room).replace("_", " ").capitalize().replace(" ", "")
		var zone: Node = _zones.get_node_or_null(NodePath(zone_name))
		if zone == null:
			_check(false, "zone exists: " + zone_name)
			continue
		_check(zone.get("compartment_id") == TubeLayout.ROOM_COMPARTMENTS[room], "zone compartment_id: " + zone_name)
		var shape: CollisionShape3D = zone.get_node_or_null(^"Shape") as CollisionShape3D
		if shape == null or not (shape.shape is BoxShape3D):
			_check(false, "zone has a box shape: " + zone_name)
			continue
		var bounds: Vector2 = Vector2(TubeLayout.span(first).x, TubeLayout.span(last).y)
		var box: BoxShape3D = shape.shape as BoxShape3D
		_check(absf(box.size.z - (bounds.y - bounds.x)) <= 0.05, "zone spans every section in the room: " + zone_name)
		_check(absf((zone as Node3D).position.z - (bounds.x + bounds.y) * 0.5) <= POSITION_TOLERANCE, "zone is centred on the room: " + zone_name)
		var ceiling: float = SectionHull.TUBE_CEILING
		for index: int in sections:
			ceiling = maxf(ceiling, float(TubeLayout.sections()[index].get("ceiling", SectionHull.TUBE_CEILING)))
		_check(absf(box.size.y - ceiling) <= POSITION_TOLERANCE, "zone covers both vertical levels: " + zone_name)
		_check(absf((zone as Node3D).position.y - ceiling * 0.5) <= POSITION_TOLERANCE, "zone is centred across room height: " + zone_name)
	_check(_zones.get_child_count() == expected_zones, "Zones holds one zone per room (%d)" % expected_zones)


## One atmosphere link per hatched joint, across the two rooms' compartments.
func _test_links() -> void:
	var hatches: int = 0
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		hatches += 1
		var link_name: String = "LinkJoint_%s_%s" % [
			String(TubeLayout.sections()[index]["name"]),
			String(TubeLayout.sections()[index + 1]["name"]),
		]
		var link: Node = _links.get_node_or_null(NodePath(link_name))
		if link == null:
			_check(false, "link exists: " + link_name)
			continue
		var aft_room: StringName = StringName(TubeLayout.sections()[index].get("room", &""))
		var fore_room: StringName = StringName(TubeLayout.sections()[index + 1].get("room", &""))
		var pair_a: StringName = TubeLayout.ROOM_COMPARTMENTS[aft_room]
		var pair_b: StringName = TubeLayout.ROOM_COMPARTMENTS[fore_room]
		var forward: bool = link.get("compartment_a") == pair_a and link.get("compartment_b") == pair_b
		var reverse: bool = link.get("compartment_a") == pair_b and link.get("compartment_b") == pair_a
		_check(forward or reverse, "link connects %s and %s" % [pair_a, pair_b])
	_check(_links.get_child_count() == hatches, "Links holds one link per hatched joint (%d)" % hatches)


func _test_crt_props() -> void:
	await process_frame
	for prop_name: String in CRT_PROPS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			_check(false, "crt prop exists: " + prop_name)
			continue
		var screen: MeshInstance3D = prop.find_child("Screen", true, false) as MeshInstance3D
		var model: Node3D = prop.get_node_or_null(^"Crt/Model") as Node3D
		var display: CrtScreen = prop.find_child("ScreenTint", true, false) as CrtScreen
		var terminal: ComputerTerminal = prop as ComputerTerminal
		_check(screen != null and screen.material_override != null, "crt screen mesh: " + prop_name)
		_check(display != null and display.is_bound(), "crt has a live physical readout: " + prop_name)
		_check(terminal != null and display != null and display.get_presented_lines() == terminal.build_readout(), "crt shows the current simulator readout: " + prop_name)
		_check(
			model != null and model.find_children("*", "MeshInstance3D", true, false).size() > 0,
			"crt uses the authored console: " + prop_name
		)
	var status_panel: StatusPanel = _props.get_node_or_null(^"StatusPanel") as StatusPanel
	var display: CrtScreen = status_panel.find_child("ScreenTint", true, false) as CrtScreen if status_panel != null else null
	_check(display != null and _contains_line(display.get_presented_lines(), "BATTERY 20%"), "cockpit status CRT starts with live power data")
	_power.battery_fraction = 0.47
	await create_timer(0.3).timeout
	_check(display != null and _contains_line(display.get_presented_lines(), "BATTERY 47%"), "display refresh cadence updates the physical status CRT")


func _contains_line(lines: PackedStringArray, needle: String) -> bool:
	for line: String in lines:
		if line.contains(needle):
			return true
	return false


func _expected_doors() -> Array[String]:
	var names: Array[String] = ["DoorAirlockInner", "DoorAirlockOuter"]
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		var aft_room: StringName = StringName(TubeLayout.sections()[index].get("room", &""))
		var fore_room: StringName = StringName(TubeLayout.sections()[index + 1].get("room", &""))
		var airlock_joint: bool = (aft_room == &"storage" and fore_room == &"airlock") or (aft_room == &"airlock" and fore_room == &"storage")
		if not airlock_joint:
			names.append("DoorJoint_%s_%s" % [
				String(TubeLayout.sections()[index]["name"]),
				String(TubeLayout.sections()[index + 1]["name"]),
			])
	return names


func _nearest_walkable(z: float) -> Dictionary:
	var covering: Dictionary = TubeLayout.section_at(z)
	if not covering.is_empty() and TubeLayout.is_walkable(TubeLayout.index_of(String(covering["name"]))):
		return covering
	var best: Dictionary = {}
	var best_distance: float = 1.0e9
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var bounds: Vector2 = TubeLayout.span(index)
		var distance: float = maxf(0.0, maxf(bounds.x - z, z - bounds.y))
		if distance < best_distance:
			best_distance = distance
			best = TubeLayout.sections()[index]
	return best


func _world_bounds(prop: Node3D) -> AABB:
	var aabb: AABB = AABB()
	var first: bool = true
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if first:
			aabb = box
			first = false
		else:
			aabb = aabb.merge(box)
	return aabb


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
