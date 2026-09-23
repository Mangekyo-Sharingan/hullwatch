## M13.2 exterior regression: the drum hull wraps the chain, the flange collars girdle the
## joint steps, the bow cowl frames a viewport that really is a hole, the stern cap closes
## the stack, the airlock opens onto the EVA platform, and nothing intrudes into the rooms.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"
## Mirrors the generator's plate thickness: the walkway's inner edge meets the sill, and the
## mount plate's outward face is the last surface before the dock's bore.
const DOCK_PLATE_THICKNESS: float = 0.15

func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var packed: PackedScene = load(GEOMETRY_PATH) as PackedScene
	_check(packed != null, "ship geometry scene loads")
	if packed == null:
		_finish()
		return
	_geometry = packed.instantiate() as Node3D
	root.add_child(_geometry)
	await physics_frame
	await physics_frame

	_test_rooms_are_closed()
	await _test_no_sightlines_out()
	_test_hull_node()

	_test_drums()
	_test_joint_collars()
	_test_bow_and_stern()
	_test_airlock_opens_onto_the_platform()
	_test_platform_railing()
	_test_walkway()
	_test_hull_stays_out_of_rooms()
	_test_no_outboard_geometry()
	_test_hardpoints()

	_geometry.free()
	_finish()


## The rooms are closed: walking the chain in half-metre steps, every walkable z has a deck
## below, a ceiling above and walls either side - except the openings the design wants (a
## dock's doorway on the section's own side, the airlock's outer hatch on the west).
func _test_rooms_are_closed() -> void:
	var misses: PackedStringArray = PackedStringArray()
	var z: float = TubeLayout.span(0).x
	while z <= TubeLayout.span(TubeLayout.sections().size() - 1).y:
		var section: Dictionary = TubeLayout.section_at(z)
		if section.is_empty() or not TubeLayout.is_walkable(TubeLayout.index_of(String(section["name"]))):
			z += 0.5
			continue
		var index: int = TubeLayout.index_of(String(section["name"]))
		var center_z: float = (TubeLayout.span(index).x + TubeLayout.span(index).y) * 0.5
		var docked: bool = TubeLayout.port_of(index) != &""
		var port_west: bool = docked and _tube_port_is_west(index)
		var gaps: Array[Array] = []
		if docked or bool(section.get("outer_hatch", false)):
			gaps.append(["west" if port_west or bool(section.get("outer_hatch", false)) else "east", center_z - 0.5, center_z + 0.5])
		for probe: Array in [
			[Vector3(0.0, 1.4, z), Vector3(0.0, -0.6, z), "down", false],
			[Vector3(0.0, 1.4, z), Vector3(0.0, 3.6, z), "up", false],
			[Vector3(0.0, 1.4, z), Vector3(-3.6, 1.4, z), "west", true],
			[Vector3(0.0, 1.4, z), Vector3(3.6, 1.4, z), "east", true],
		]:
			var side: String = String(probe[2])
			var side_gap: bool = false
			for gap: Array in gaps:
				if String(gap[0]) == side and z >= float(gap[1]) and z <= float(gap[2]):
					side_gap = true
			if side_gap:
				continue
			if not _ray_hits(probe[0], probe[1]):
				misses.append("%s at z=%.1f" % [side, z])
		z += 0.5
	_check(misses.is_empty(), "the rooms are closed along the chain (%s)" % ("none missing" if misses.is_empty() else ", ".join(misses)))


## Every walkable room but the cupola is a closed shell: a fan of sightlines from eye height
## must all land on something. A twisted quad once opened port walls to space and only a
## ray fan catches that class of miss. The cupola is excluded because its viewport is meant
## to look out, and the airlock door comes from world_layout, which this test stands up too.
func _test_no_sightlines_out() -> void:
	var layout_packed: PackedScene = load("res://scenes/world_layout.tscn") as PackedScene
	var layout: Node3D = layout_packed.instantiate() as Node3D
	root.add_child(layout)
	await physics_frame
	await physics_frame
	var dirs: Array[Vector3] = []
	for i: int in 64:
		var t: float = (float(i) + 0.5) / 64.0
		var y: float = 1.0 - 2.0 * t
		var r: float = sqrt(maxf(1.0 - y * y, 0.0))
		var phi: float = float(i) * 2.399963
		dirs.append(Vector3(cos(phi) * r, y, sin(phi) * r))
	var escapes: PackedStringArray = PackedStringArray()
	for index: int in TubeLayout.sections().size():
		var section: Dictionary = TubeLayout.sections()[index]
		if not TubeLayout.is_walkable(index) or String(section["kind"]) == "dome":
			continue
		var center_z: float = (TubeLayout.span(index).x + TubeLayout.span(index).y) * 0.5
		for x: float in [-0.6, 0.0, 0.6]:
			var from: Vector3 = Vector3(x, 1.4, center_z)
			for dir: Vector3 in dirs:
				var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 40.0)
				params.collide_with_areas = false
				params.hit_back_faces = true
				if root.world_3d.direct_space_state.intersect_ray(params).is_empty():
					escapes.append("%s from x=%.1f to (%.2f,%.2f,%.2f)" % [String(section["name"]), x, dir.x, dir.y, dir.z])
					break
	_check(escapes.is_empty(), "no sightline escapes a room (%s)" % ("sealed" if escapes.is_empty() else ", ".join(escapes)))
	layout.free()


## Whether a section's dock opens to port (west) rather than starboard.
func _tube_port_is_west(index: int) -> bool:
	var id: String = String(TubeLayout.port_of(index)).trim_prefix("hp_")
	for dock: Dictionary in [{"id": "quarters", "outward": -1.0}, {"id": "life_support", "outward": -1.0}, {"id": "galley", "outward": 1.0}, {"id": "engine_bay", "outward": 1.0}]:
		if String(dock["id"]) == id:
			return float(dock["outward"]) < 0.0
	return false

## Fittings belong on the hull: one built at the flat layout's coordinates (the solar arrays
## and the dock throats once were) hangs in space where nobody plays, so nothing in the tube
## scene may sit outside the hull's reach, bar the EVA platform's own kit.
func _test_no_outboard_geometry() -> void:
	var reach: float = 0.0
	for drum: Dictionary in SectionHull.tube_drums():
		reach = maxf(reach, SectionHull.tube_half_width(float(drum["radius"]) + SectionHull.TUBE_BAND, SectionHull.TUBE_WALL_TOP))
	var limit: float = reach + 2.0
	var platform: Array[String] = ["TubeRailing0", "TubeRailing1", "TubeRailing2", "TetherAnchor0", "TetherAnchor1", "TetherZone"]
	var strays: PackedStringArray = PackedStringArray()
	for node: Node in _geometry.find_children("*", "Node3D", true, false):
		if String(node.name) in platform:
			continue
		var x: float = absf((node as Node3D).global_position.x)
		if x > limit:
			strays.append("%s at x=%.2f" % [String(node.name), x])
	_check(strays.is_empty(), "no fitting floats off the hull (%s)" % ("all aboard" if strays.is_empty() else ", ".join(strays)))


func _test_hull_node() -> void:
	var hull: Node = _geometry.get_node_or_null(^"HullExterior")
	_check(hull != null and hull is StaticBody3D, "HullExterior exists as a StaticBody3D")
	if hull == null:
		return
	var shape_node: CollisionShape3D = hull.get_node_or_null(^"ShellShape") as CollisionShape3D
	_check(shape_node != null and shape_node.shape is ConcavePolygonShape3D, "hull shell has trimesh collision")
	var hull_mesh: MeshInstance3D = hull.get_node_or_null(^"HullMesh") as MeshInstance3D
	_check(hull_mesh != null and hull_mesh.mesh != null, "hull shell mesh exists")


## Every drum's deck-to-cove wall is solid at the radius its section table promises, and the
## ceiling facet closes it overhead.
func _test_drums() -> void:
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var bounds: Vector2 = TubeLayout.span(index)
		var center_z: float = (bounds.x + bounds.y) * 0.5
		var radius: float = float(TubeLayout.sections()[index]["radius"]) + SectionHull.TUBE_BAND
		var beside_z: float = center_z + minf(0.7, (bounds.y - bounds.x) * 0.3)
		var out: Dictionary = _ray_result(Vector3(0.0, 1.2, beside_z), Vector3(radius + 2.5, 1.2, beside_z))
		var hit_x: float = absf(float((out["position"] as Vector3).x)) if not out.is_empty() else 999.0
		_check(not out.is_empty() and hit_x < radius + 0.35, "drum wall encloses the room: %s (x=%.3f)" % [String(TubeLayout.sections()[index]["name"]), hit_x])
		var roof: Dictionary = _ray_result(Vector3(0.0, 4.0, center_z), Vector3(0.0, 0.0, center_z))
		_check(not roof.is_empty() and float((roof["position"] as Vector3).y) > 1.9, "drum ceiling closes overhead: %s" % String(TubeLayout.sections()[index]["name"]))


## Where two sections' radii differ the joint gets a step band and a collar proud of the
## larger drum: a radial ray at the joint centre leaves through the collar, not the wall.
func _test_joint_collars() -> void:
	var joints: Array[Dictionary] = SectionHull.tube_joints()
	_check(not joints.is_empty(), "the chain has radius steps to collar")
	for joint: Dictionary in joints:
		var z: float = float(joint["z"])
		var radius: float = maxf(float(joint["radius_a"]), float(joint["radius_b"]))
		var out: Dictionary = _ray_result(Vector3(radius + 2.0, 1.2, z), Vector3(0.0, 1.2, z))
		var drum_wall: float = SectionHull.tube_half_width(radius, 1.2)
		_check(not out.is_empty() and float((out["position"] as Vector3).x) > drum_wall + 0.05, "flange collar girdles the joint at z=%.2f" % z)


func _test_bow_and_stern() -> void:
	var drum: Dictionary = SectionHull.tube_drums()[0]
	var bow: float = float(drum["z0"]) - SectionHull.PROW_DEPTH
	var cowl: Dictionary = _ray_result(Vector3(0.0, 1.2, bow - 1.0), Vector3(0.0, 1.2, bow + 0.6))
	_check(not cowl.is_empty() and absf(float((cowl["position"] as Vector3).z) - bow) < 0.05, "the bow cowl face is solid")
	var window: float = (SectionHull.TUBE_WINDOW_MIN.y + SectionHull.TUBE_WINDOW_MAX.y) * 0.5
	_check(not _ray_hits(Vector3(0.0, window, bow - 1.0), Vector3(0.0, window, float(drum["z0"]) + 0.2)), "the viewport is a hole through the cowl and the cupola face")
	var last: Dictionary = SectionHull.tube_drums()[TubeLayout.sections().size() - 1]
	var cap: Dictionary = _ray_result(Vector3(0.0, 1.2, float(last["z1"]) + 1.0), Vector3(0.0, 1.2, float(last["z1"]) - 1.0))
	_check(not cap.is_empty() and absf(float((cap["position"] as Vector3).z) - float(last["z1"])) < 0.05, "the stern cap closes the last drum")
	_check(_geometry.get_node_or_null(^"HullExterior/ArrayPanel1") != null, "the solar arrays keep their aft mount")


func _test_airlock_opens_onto_the_platform() -> void:
	_check(not _ray_hits(Vector3(0.0, 1.2, -0.65), Vector3(-12.0, 1.2, -0.65)), "outer doorway is free through both walls")
	_check(_ray_hits(Vector3(-3.6, 1.0, -0.65), Vector3(-3.6, -1.0, -0.65)), "platform deck is solid outside the door")
	_check(not _ray_hits(Vector3(-3.6, 0.5, -0.65), Vector3(-3.6, 2.5, -0.65)), "platform headroom is clear")


func _test_platform_railing() -> void:
	var airlock: int = TubeLayout.index_of("airlock")
	var center_z: float = (TubeLayout.span(airlock).x + TubeLayout.span(airlock).y) * 0.5
	var outer_x: float = -(float(TubeLayout.sections()[airlock]["radius"]) + SectionHull.TUBE_BAND) - 3.0
	var hull: Node = _geometry.get_node_or_null(^"HullExterior")
	var rails: int = 0
	if hull != null:
		for child: Node in hull.get_children():
			if String(child.name).begins_with("TubeRailing"):
				rails += 1
	_check(rails == 3 and absf(outer_x + 0.1) > 0.0, "the platform's three railings stand")


## M13.3: the truss walkway runs from the platform toward the life support dock - deck solid,
## headroom clear, rails and truss posts standing, the mount plate reachable from its end, and
## the deck stops clear of the bay a standing pod owns.
func _test_walkway() -> void:
	var target: int = TubeLayout.index_of("life_support")
	var dock_z: float = (TubeLayout.span(target).x + TubeLayout.span(target).y) * 0.5
	var dock_face: float = float(TubeLayout.sections()[target]["radius"]) + SectionHull.TUBE_BAND
	var x: float = -(dock_face + 0.5)
	var end_z: float = dock_z + 1.7
	_check(_ray_hits(Vector3(x, 0.5, -6.0), Vector3(x, -1.0, -6.0)), "walkway deck is solid along the spur")
	_check(not _ray_hits(Vector3(x, 0.5, -6.0), Vector3(x, 2.5, -6.0)), "walkway headroom is clear")
	var reach: Dictionary = _ray_result(Vector3(x, 1.0, end_z), Vector3(-dock_face - 0.075, 1.0, dock_z))
	var hit_x: float = float((reach["position"] as Vector3).x) if not reach.is_empty() else 999.0
	_check(
		not reach.is_empty() and hit_x > -(dock_face + DOCK_PLATE_THICKNESS) - 0.05 and hit_x < -dock_face + 0.05,
		"the walkway's end reaches the dock's mount plate"
	)
	_check(
		not _ray_hits(Vector3(x, 0.5, dock_z + 1.0), Vector3(x, -1.0, dock_z + 1.0)),
		"the walkway stops clear of the pod's bay"
	)
	var hull: Node = _geometry.get_node_or_null(^"HullExterior")
	var rails: int = 0
	var posts: int = 0
	if hull != null:
		for child: Node in hull.get_children():
			if String(child.name).begins_with("TubeWalkRail"):
				rails += 1
			elif String(child.name).begins_with("TubeWalkPost"):
				posts += 1
	_check(rails >= 4, "the walkway's rails stand")
	_check(posts >= 4, "the walkway carries its truss posts")


## No hull shell inside a room: a short step off each section's centre must leave the hull.
func _test_hull_stays_out_of_rooms() -> void:
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var center_z: float = (TubeLayout.span(index).x + TubeLayout.span(index).y) * 0.5
		var center: Vector3 = Vector3(0.0, 1.2, center_z)
		var result: Dictionary = _ray_result(center, center + Vector3(0.45, 0.0, 0.0))
		var blocked_by_hull: bool = false
		if not result.is_empty():
			var collider: Node = result["collider"] as Node
			if collider != null and String(collider.name) == "HullExterior":
				blocked_by_hull = true
		_check(not blocked_by_hull, "no hull shell inside the section at z=%.2f" % center_z)


func _test_hardpoints() -> void:
	var hull: Node = _geometry.get_node_or_null(^"HullExterior")
	if hull == null:
		_check(false, "hull exists for hardpoint check")
		return
	var expected: Array[String] = ["quarters", "life_support", "galley", "engine_bay"]
	var count: int = 0
	for id: String in expected:
		var plate: Node = hull.get_node_or_null(NodePath("DockPlate_" + id))
		var marker: Node = hull.get_node_or_null(NodePath("Hardpoint_" + id))
		count += 1
		_check(plate != null and plate.is_in_group(&"dock_plate"), "dock mount plate exists: " + id)
		_check(marker != null and marker.is_in_group(&"hardpoint"), "hardpoint marker exists: " + id)
		if marker != null:
			var position: Vector3 = (marker as Node3D).position
			_check(absf(position.x) > 2.3, "hardpoint sits on a drum wall: " + id)
	_check(count == 4, "four hardpoint markers exist")


func _ray_hits(from: Vector3, to: Vector3) -> bool:
	return not _ray_result(from, to).is_empty()


func _ray_result(from: Vector3, to: Vector3) -> Dictionary:
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var space_state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	return space_state.intersect_ray(params)


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_hull_exterior")
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

var _failures: int = 0
var _geometry: Node3D
