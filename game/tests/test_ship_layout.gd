## M13.2 layout regression: the interior chain exists as one section body per walkable
## TubeLayout entry plus a joint body per hatch, every bulkhead hatch is walkable end to
## end, the airlock's outer opening is clear, walls block beside the port doorways, the
## swept cross-section keeps its profile at walk heights, deck and ceiling sit at their
## planes, and the cupola carries the dash and the viewport pane.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"
const XENON_MATERIAL_PATH: String = "res://src/data/materials/mat_xenon_metal.tres"
const FLOOR_MATERIAL_PATH: String = "res://src/data/materials/mat_deck_plate.tres"
const WINDOW_MATERIAL_PATH: String = "res://src/data/materials/mat_space_window.tres"
const RAY_Y: float = 1.2

var _failures: int = 0
var _geometry: Node3D


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if _find_root_child(&"EventBus") == null:
		var event_bus: Node = load("res://src/autoload/event_bus.gd").new()
		event_bus.name = &"EventBus"
		root.add_child(event_bus)
	var packed: PackedScene = load(GEOMETRY_PATH) as PackedScene
	_check(packed != null, "ship geometry scene loads")
	if packed == null:
		_finish()
		return
	_geometry = packed.instantiate() as Node3D
	_check(_geometry != null, "ship geometry instantiates as Node3D")
	if _geometry == null:
		_finish()
		return
	root.add_child(_geometry)
	await physics_frame
	await physics_frame

	_test_sections_exist()
	_test_hatches_walkable()
	_test_airlock_outer_opening()
	_test_walls_block()
	_test_section_profile()
	_test_floor_and_ceiling()
	_test_cockpit_dash()
	_test_surface_materials()

	_geometry.free()
	_finish()


## Every walkable section is a body with wall mesh, floor mesh and trimesh collision, and
## every hatched joint is a body too - the whole chain is generated, never hand-placed.
func _test_sections_exist() -> void:
	var walkable: int = 0
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		walkable += 1
		var section_name: String = String(TubeLayout.sections()[index]["name"])
		var body: Node = _geometry.get_node_or_null("Section_" + section_name)
		_check(body != null and body is StaticBody3D, "section body exists: " + section_name)
		if body == null:
			continue
		_check(body.get_node_or_null(^"WallsMesh") is MeshInstance3D, "section walls mesh: " + section_name)
		_check(body.get_node_or_null(^"FloorMesh") is MeshInstance3D, "section floor mesh: " + section_name)
		var shape: CollisionShape3D = body.get_node_or_null(^"ShellShape") as CollisionShape3D
		var solid: bool = shape != null and shape.shape is ConcavePolygonShape3D
		if solid:
			solid = (shape.shape as ConcavePolygonShape3D).get_faces().size() >= 3
		_check(solid, "section shell collision: " + section_name)
	_check(walkable >= 8, "the chain keeps at least 8 walkable sections (%d)" % walkable)
	var joints: int = 0
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		joints += 1
		var label: String = "Joint_%s_%s" % [
			String(TubeLayout.sections()[index]["name"]),
			String(TubeLayout.sections()[index + 1]["name"]),
		]
		var joint: Node = _geometry.get_node_or_null(label)
		_check(joint != null and joint is StaticBody3D and joint.get_node_or_null(^"ShellShape") is CollisionShape3D, "joint body exists: " + label)
	_check(joints >= 8, "the chain keeps at least 8 hatched joints (%d)" % joints)


## Walking the chain: a ray down the centre line from each section into the next passes the
## bulkhead's hatch. The doors themselves are world_layout's business.
func _test_hatches_walkable() -> void:
	for index: int in TubeLayout.sections().size() - 1:
		if not TubeLayout.has_hatch(index):
			continue
		var from_z: float = (TubeLayout.span(index).x + TubeLayout.span(index).y) * 0.5
		var to_z: float = (TubeLayout.span(index + 1).x + TubeLayout.span(index + 1).y) * 0.5
		var label: String = "%s_%s" % [
			String(TubeLayout.sections()[index]["name"]),
			String(TubeLayout.sections()[index + 1]["name"]),
		]
		_check(not _ray_hits(Vector3(0.0, RAY_Y, from_z), Vector3(0.0, RAY_Y, to_z)), "hatch walkable: " + label)


## The airlock's radial outer opening is clear through the inner wall, the drum and out.
func _test_airlock_outer_opening() -> void:
	var airlock: int = TubeLayout.index_of("airlock")
	_check(airlock >= 0, "airlock section exists in the table")
	if airlock < 0:
		return
	var center_z: float = (TubeLayout.span(airlock).x + TubeLayout.span(airlock).y) * 0.5
	_check(not _ray_hits(Vector3(0.0, RAY_Y, center_z), Vector3(-12.0, RAY_Y, center_z)), "airlock outer opening is clear through both walls")


## Walls block beside the port doorways: probing at a z just outside the port band, on both
## sides, every section's canted wall is solid.
func _test_walls_block() -> void:
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var section: Dictionary = TubeLayout.sections()[index]
		var radius: float = float(section["radius"])
		var bounds: Vector2 = TubeLayout.span(index)
		var center_z: float = (bounds.x + bounds.y) * 0.5
		var probe_z: float = center_z + 0.55
		for side: float in [-1.0, 1.0]:
			var target: float = side * (SectionHull.tube_half_width(radius, RAY_Y) + 0.5)
			_check(_ray_hits(Vector3(0.0, RAY_Y, probe_z), Vector3(target, RAY_Y, probe_z)), "wall blocks beside the doorway: " + String(section["name"]))


## The swept cross-section keeps its profile: at three walk heights each section (the cupola
## carries the dash instead) is clear inside its wall line and blocked just outside it.
func _test_section_profile() -> void:
	for index: int in TubeLayout.sections().size():
		if not TubeLayout.is_walkable(index):
			continue
		var section_name: String = String(TubeLayout.sections()[index]["name"])
		if section_name == "cupola":
			continue
		var radius: float = float(TubeLayout.sections()[index]["radius"])
		var bounds: Vector2 = TubeLayout.span(index)
		var center_z: float = (bounds.x + bounds.y) * 0.5
		var probe_z: float = center_z + 0.55
		for y: float in [0.3, 1.2, 2.2]:
			var half: float = SectionHull.tube_half_width(radius, y)
			_check(
				not _ray_hits(Vector3(-half + 0.06, y, probe_z), Vector3(half - 0.06, y, probe_z)),
				"%s clear inside the wall at y=%.2f" % [section_name, y]
			)
			_check(
				_ray_hits(Vector3(-half - 0.25, y, probe_z), Vector3(half + 0.25, y, probe_z)),
				"%s blocked outside the wall at y=%.2f" % [section_name, y]
			)


## Deck at the deck plane facing up, ceiling at the cove's crown facing down.
func _test_floor_and_ceiling() -> void:
	var storage: int = TubeLayout.index_of("storage")
	_check(storage >= 0, "storage section exists in the table")
	if storage < 0:
		return
	var center_z: float = (TubeLayout.span(storage).x + TubeLayout.span(storage).y) * 0.5
	var floor_hit: Dictionary = _ray_result(Vector3(0.0, 1.0, center_z), Vector3(0.0, -0.5, center_z))
	_check(not floor_hit.is_empty(), "section floor is solid")
	if not floor_hit.is_empty():
		_check(absf(float((floor_hit["position"] as Vector3).y)) < 0.02, "floor surface is at deck height")
		_check((floor_hit["normal"] as Vector3).dot(Vector3.UP) > 0.9, "floor faces up")
	var ceiling_hit: Dictionary = _ray_result(Vector3(0.0, 2.0, center_z), Vector3(0.0, 3.2, center_z))
	_check(not ceiling_hit.is_empty(), "section ceiling is solid")
	if not ceiling_hit.is_empty():
		_check(absf(float((ceiling_hit["position"] as Vector3).y) - SectionHull.TUBE_CEILING) < 0.02, "ceiling surface is at the cove crown")
		_check((ceiling_hit["normal"] as Vector3).dot(Vector3.DOWN) > 0.9, "ceiling faces down")


## The cupola's console bank and viewport: the dash panels and the window trim carry
## collision, the pane uses the space shader, and the dash blocks at console height.
func _test_cockpit_dash() -> void:
	var cupola: Node = _geometry.get_node_or_null(^"Section_cupola")
	_check(cupola != null, "cupola section exists for the dash check")
	if cupola == null:
		return
	var dash: int = 0
	var trim: int = 0
	for child: Node in cupola.get_children():
		if not (child is CollisionShape3D):
			continue
		if String(child.name).begins_with("Dash"):
			dash += 1
		elif String(child.name).begins_with("Window"):
			trim += 1
	_check(dash >= 6, "the dash has its panels (%d collision parts)" % dash)
	_check(trim >= 4, "the viewport carries its trim (%d collision parts)" % trim)
	var face_z: float = TubeLayout.span(TubeLayout.index_of("cupola")).x + 0.28
	_check(_ray_hits(Vector3(0.0, 0.9, face_z + 1.2), Vector3(0.0, 0.9, face_z - 0.2)), "the dash blocks at console height")
	var pane: MeshInstance3D = cupola.get_node_or_null(^"DressingWindowPane") as MeshInstance3D
	_check(pane != null and pane.material_override != null, "the viewport pane exists")
	if pane != null and pane.material_override != null:
		_check(pane.material_override.resource_path == WINDOW_MATERIAL_PATH, "the viewport uses the space window shader")


func _test_surface_materials() -> void:
	var cockpit: Node = _geometry.get_node_or_null(^"Section_cockpit")
	_check(cockpit != null, "cockpit section exists for the material check")
	if cockpit == null:
		return
	var walls: MeshInstance3D = cockpit.get_node_or_null(^"WallsMesh") as MeshInstance3D
	_check(walls != null and walls.material_override != null and walls.material_override.resource_path == XENON_MATERIAL_PATH, "section walls use the xenon-metal material")
	var floor: MeshInstance3D = cockpit.get_node_or_null(^"FloorMesh") as MeshInstance3D
	_check(floor != null and floor.material_override != null and floor.material_override.resource_path == FLOOR_MATERIAL_PATH, "section floor uses the deck-plate material")


func _ray_hits(from: Vector3, to: Vector3) -> bool:
	return not _ray_result(from, to).is_empty()


func _ray_result(from: Vector3, to: Vector3) -> Dictionary:
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var space_state: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	return space_state.intersect_ray(params)


func _find_root_child(node_name: StringName) -> Node:
	for child: Node in root.get_children():
		if child.name == node_name:
			return child
	return null


func _finish() -> void:
	if _failures == 0:
		print("PASS: test_ship_layout")
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
