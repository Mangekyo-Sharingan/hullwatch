## World layout regression (tube chain): the flat tables' furniture, doors, zones and links
## all made it onto the chain. Props sit inside their own tunnel section hugged to its
## canted wall (never embedded, never across the centre line), the EVA platform kit stands
## off the airlock, joint doors ship open with their slabs stowed while the airlock's two
## hatches stay shut, each room owns one occupancy area including its service bay, and one
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

	var surround_count: int = 0
	for index: int in TubeLayout.sections().size() - 1:
		if TubeLayout.has_hatch(index):
			surround_count += 2
	var expected_total: int = CARRIED_PROPS.size() + PLATFORM_PROPS.size() + _expected_doors().size() + surround_count + 7
	_check(_props.get_child_count() == expected_total, "Props holds all %d named nodes (%d)" % [expected_total, _props.get_child_count()])

	_test_props_carry()
	await _test_service_bays()
	_test_machine_collisions()
	_test_walkway()
	_test_prefab_clearance()
	_test_cockpit_instruments()
	_test_pilot_chair_clearance()
	_test_doors()
	_test_zones()
	_test_links()
	_test_hatch_surrounds()
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
		if prop_name in ["ScrubberUnit", "WaterReclaimer", "GalleyUnit", "O2CandleRack", "StatusPanel", "MessTable", "ProbeAtmosphere"]:
			continue
		if prop_name == "ProbeThermal":
			var section_span: Vector2 = TubeLayout.span(TubeLayout.index_of(String(nearest["name"])))
			_check(box.position.z >= section_span.x and box.end.z <= section_span.y, "remapped thermal probe stays clear of the bulkhead neck")
		var radius: float = float(nearest["radius"])
		var side: float = signf(prop.position.x) if absf(prop.position.x) > 0.01 else 1.0
		var inboard: float = box.end.x if side < 0.0 else box.position.x
		var lane: float = SectionHull.tube_half_width(radius, 1.0) + side * inboard
		_check(lane >= 0.8, "carried prop leaves a walkable lane: " + prop_name)
		var outboard: float = -box.position.x if side < 0.0 else box.end.x
		_check(outboard <= SectionHull.tube_half_width(radius, maxf(box.position.y, 0.0)) + 0.03, "carried prop clears the canted wall: " + prop_name)
		_check(box.position.y >= -0.05, "carried prop sits above the deck: " + prop_name)
	var computer_prop: Node3D = _props.get_node_or_null(^"ComputerProp") as Node3D
	_check(computer_prop != null and computer_prop.get_script() == null and computer_prop.find_child("ComputerTerminal", true, false) == null, "galley computer remains passive set dressing")
	for prop_name: String in PLATFORM_PROPS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			_check(false, "platform prop exists: " + prop_name)
			continue
		var airlock: int = TubeLayout.index_of("airlock")
		var face: float = float(TubeLayout.sections()[airlock]["radius"]) + SectionHull.TUBE_BAND
		_check(prop.position.x < -face, "platform prop stands off the airlock's drum face: " + prop_name)


func _test_service_bays() -> void:
	for bay: Dictionary in TubeLayout.service_bays():
		var equipment: Array[String] = []
		if bay["name"] == "life_support_service":
			equipment.assign(["ScrubberUnit", "WaterReclaimer"])
		else:
			equipment.assign(["GalleyUnit"])
		var previous_end: float = -INF
		for prop_name: String in equipment:
			var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
			if prop == null:
				_check(false, "bay equipment exists: " + prop_name)
				continue
			var bounds: AABB = _world_bounds(prop)
			var outboard: float = bounds.end.x if float(bay["side"]) > 0.0 else bounds.position.x
			_check(absf(outboard - (float(bay["outer_x"]) - float(bay["side"]) * 0.02)) < 0.001, "equipment hugs its service bay wall: " + prop_name)
			_check(bounds.position.z >= float(bay["center_z"]) - float(bay["length"]) * 0.5 and bounds.end.z <= float(bay["center_z"]) + float(bay["length"]) * 0.5, "equipment fits its bay length: " + prop_name)
			_check(bounds.position.z > previous_end, "bay equipment has separate wall slots: " + prop_name)
			previous_end = bounds.end.z
			_check(minf(bounds.position.x * float(bay["side"]), bounds.end.x * float(bay["side"])) > absf(float(bay["inner_x"])), "bay equipment clears trunk: " + prop_name)
		var mounted_name: String = "O2CandleRack" if bay["name"] == "life_support_service" else "StatusPanel"
		var mounted: Node3D = _props.get_node(NodePath(mounted_name)) as Node3D
		var mounted_bounds: AABB = _world_bounds(mounted)
		var mounted_outboard: float = mounted_bounds.end.x if float(bay["side"]) > 0.0 else mounted_bounds.position.x
		_check(absf(mounted_outboard - (float(bay["outer_x"]) - float(bay["side"]) * 0.02)) < 0.001, "bay readout hugs outboard wall: " + mounted_name)
		for prop_name: String in equipment:
			var machine: Node3D = _props.get_node(NodePath(prop_name)) as Node3D
			_check(mounted_bounds.position.y > _world_bounds(machine).end.y, "bay readout clears floor equipment: " + mounted_name)
		if bay["name"] == "galley_service":
			var table: Node3D = _props.get_node(^"MessTable") as Node3D
			var table_bounds: AABB = _world_bounds(table)
			var counter_bounds: AABB = _world_bounds(_props.get_node(^"GalleyUnit") as Node3D)
			_check(absf(table_bounds.position.z - (float(bay["center_z"]) - float(bay["length"]) * 0.5 + 0.02)) < 0.001, "mess table fits the bay fore wall")
			_check(table_bounds.position.x > counter_bounds.end.x, "mess table remains inboard of counter without overlap")
			_check(table_bounds.end.z < float(bay["center_z"]) - 0.3, "mess table leaves bay centre service apron clear")
		var zone_name: String = "ZoneRoom_" + String(bay["room"]).replace("_", " ").capitalize().replace(" ", "")
		var zone: Area3D = _zones.get_node_or_null(NodePath(zone_name)) as Area3D
		var shape: CollisionShape3D = zone.get_node_or_null(^"ShapeServiceBay") as CollisionShape3D if zone != null else null
		_check(shape != null and shape.shape is BoxShape3D and zone.get("compartment_id") == TubeLayout.ROOM_COMPARTMENTS[bay["room"]], "bay shares its existing room occupancy owner: " + String(bay["name"]))
		if shape != null:
			var bounds: AABB = _collision_bounds(shape)
			_check(bounds.size.is_equal_approx(Vector3(absf(float(bay["outer_x"]) - float(bay["inner_x"])), float(bay["ceiling"]), float(bay["length"]))), "bay occupancy spans usable bay dimensions")
			_check(bounds.get_center().is_equal_approx(Vector3((float(bay["inner_x"]) + float(bay["outer_x"])) * 0.5, float(bay["ceiling"]) * 0.5, float(bay["center_z"]))), "bay occupancy is centred in layout space")
		var operator: CharacterBody3D = CharacterBody3D.new()
		operator.add_to_group(&"player")
		var capsule: CapsuleShape3D = CapsuleShape3D.new()
		capsule.radius = 0.2
		capsule.height = 1.6
		var body_shape: CollisionShape3D = CollisionShape3D.new()
		body_shape.shape = capsule
		operator.add_child(body_shape)
		root.add_child(operator)
		for offset: float in [-0.55, 0.0, 0.55, -0.55]:
			operator.position = Vector3(float(bay["inner_x"]) + float(bay["side"]) * offset, 0.85, float(bay["center_z"]))
			await physics_frame
			await physics_frame
			_check(zone.get_occupants() == 1, "room/bay union counts the operator once at offset %.2f: %s" % [offset, bay["name"]])
		operator.free()
		await physics_frame
		await physics_frame
		_check(zone.get_occupants() == 0, "room/bay occupancy clears after the operator leaves")


func _test_machine_collisions() -> void:
	for prop_name: String in ["ScrubberUnit", "WaterReclaimer", "Fabricator", "GalleyUnit", "Bunk", "SuitLocker", "CrewLocker", "MessTable", "ToolCart", "CrateStack", "ShelfUnit", "ManualBinder"]:
		var prop: StaticBody3D = _props.get_node_or_null(NodePath(prop_name)) as StaticBody3D
		var shape: CollisionShape3D = prop.get_node_or_null(^"Shape") as CollisionShape3D if prop != null else null
		_check(shape != null and shape.shape is BoxShape3D and not shape.disabled and prop.collision_layer == 1, "floor equipment retains solid collision: " + prop_name)
		if shape == null:
			continue
		var rendered: AABB = _world_bounds(prop)
		var solid: AABB = _collision_bounds(shape)
		_check(rendered.position.is_equal_approx(solid.position) and rendered.size.is_equal_approx(solid.size), "floor equipment collision matches its geometry: " + prop_name)


func _test_walkway() -> void:
	for prop_name: String in CARRIED_PROPS:
		var prop: Node3D = _props.get_node_or_null(NodePath(prop_name)) as Node3D
		if prop == null:
			continue
		# The cupola chair has two side aisles; its motion is checked separately.
		if prop.position.z < TubeLayout.span(TubeLayout.index_of("cockpit")).x:
			continue
		var rendered: AABB = _world_bounds(prop)
		var shape: CollisionShape3D = prop.get_node_or_null(^"Shape") as CollisionShape3D
		if shape != null and shape.shape is BoxShape3D and not shape.disabled:
			rendered = rendered.merge(_collision_bounds(shape))
		_check(rendered.end.x <= -0.4 or rendered.position.x >= 0.4, "render and collision leave a 0.8 m centre walkway: " + prop_name)
		for index: int in TubeLayout.sections().size() - 1:
			if not TubeLayout.has_hatch(index):
				continue
			var joint_z: float = (TubeLayout.span(index).y + TubeLayout.span(index + 1).x) * 0.5
			var approach: AABB = AABB(Vector3(-0.4, 0.0, joint_z - 0.8), Vector3(0.8, TubeLayout.HATCH_HEIGHT, 1.6))
			_check(not rendered.intersects(approach), "equipment clears both hatch approaches: %s / %d" % [prop_name, index])


func _collision_bounds(shape: CollisionShape3D) -> AABB:
	var size: Vector3 = (shape.shape as BoxShape3D).size
	return shape.global_transform * AABB(-size * 0.5, size)


func _test_prefab_clearance() -> void:
	var names: Array[String] = []
	var bounds: Array[AABB] = []
	for child: Node in _props.get_children():
		var prop: Node3D = child as Node3D
		if prop == null:
			continue
		var box: AABB = _world_bounds(prop)
		if box.size == Vector3.ZERO:
			continue
		names.append(String(prop.name))
		bounds.append(box)
	var overlaps: PackedStringArray = PackedStringArray()
	# ponytail: pairwise AABBs are cheap for this layout; add spatial partitioning only if prop count grows significantly.
	for first: int in bounds.size():
		for second: int in range(first + 1, bounds.size()):
			if bounds[first].intersects(bounds[second]):
				overlaps.append("%s / %s" % [names[first], names[second]])
	_check(overlaps.is_empty(), "prop prefab bounds do not overlap%s" % (": " + ", ".join(overlaps) if not overlaps.is_empty() else ""))


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
			if station_name == "CommsTerminal":
				_check(station.get_node_or_null(^"WallMountPlinth") == null, "Comms station leaves its adjacent hull-service plate exposed")
			elif station_name != "WallComputer":
				var plate: MeshInstance3D = station.get_node_or_null(^"WallMountPlinth") as MeshInstance3D
				_check(plate != null and plate.mesh is BoxMesh and plate.get_parent() == station, "%s has a wrapper-owned shallow mounting plinth" % station_name)
				if plate != null:
					var plate_bounds: AABB = _world_bounds(plate)
					var plate_outboard: float = plate_bounds.end.x if side == 0 else -plate_bounds.position.x
					_check(plate_outboard <= SectionHull.tube_half_width(2.4, maxf(plate_bounds.position.y, 0.0)) + 0.03, "%s plinth clears the wall profile" % station_name)
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
		if slab is Node3D and slab_shape != null and slab_shape.shape is BoxShape3D:
			var rendered: AABB = _world_bounds(slab as Node3D)
			var solid: AABB = _collision_bounds(slab_shape)
			_check(rendered.position.is_equal_approx(solid.position) and rendered.size.is_equal_approx(solid.size), "authored closed leaf bounds match its collider: " + door_name)
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


## One zone per unique room: it spans all sections, including both engine-bay sections.
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
		_check(absf(box.size.y - ceiling) <= POSITION_TOLERANCE, "zone covers the slim room height: " + zone_name)
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
		if mesh.mesh == null or not mesh.is_inside_tree():
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


func _test_hatch_surrounds() -> void:
	for room: StringName in TubeLayout.ROOM_COMPARTMENTS:
		var compartment: StringName = TubeLayout.ROOM_COMPARTMENTS[room]
		var patch: HullPatch = _props.get_node_or_null("HullPatch" if compartment == &"engine_bay" else "HullPatch_" + String(compartment)) as HullPatch
		_check(patch != null and patch.compartment_id == compartment, "physical patch point serves " + String(compartment))
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		for side: String in ["fore", "aft"]:
			var surround: Node3D = _props.get_node_or_null("HatchSurround_%d_%s" % [index, side]) as Node3D
			_check(surround != null, "hatch destination surround generated on " + side)
			if surround == null:
				continue
			var label: Label3D = surround.get_node_or_null("Destination") as Label3D
			_check(label != null and not label.text.is_empty() and not label.no_depth_test, "physical hatch destination remains occluded by geometry")
			var jamb: MeshInstance3D = surround.get_node_or_null("Jamb_1") as MeshInstance3D
			_check(jamb != null and jamb.position.x - (jamb.mesh as BoxMesh).size.x * 0.5 >= TubeLayout.HATCH_HALF_WIDTH - 0.001, "hatch surround preserves full passage width")


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
