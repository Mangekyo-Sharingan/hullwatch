## M7.3 layout regression: the faceted hull exists, doorway gaps are ray-passable, the
## corridor cross-section matches the flat-bottom hexagon profile, and walls block.
extends SceneTree

const GEOMETRY_PATH: String = "res://scenes/ship_geometry.tscn"
const XENON_MATERIAL_PATH: String = "res://src/data/materials/mat_xenon_metal.tres"
const FLOOR_MATERIAL_PATH: String = "res://src/data/materials/mat_floor_grate.tres"
const WINDOW_MATERIAL_PATH: String = "res://src/data/materials/mat_space_window.tres"
const RAY_Y: float = 1.2

const EXPECTED_SPACES: Array[StringName] = [
	&"Cockpit",
	&"Corridor",
	&"Quarters",
	&"LifeSupport",
	&"Galley",
	&"WaterCloset",
	&"Storage",
	&"Airlock",
	&"EngineBay",
]

const ROOM_CENTERS: Dictionary = {
	&"Cockpit": Vector3(0.0, RAY_Y, -16.5),
	&"Corridor": Vector3(0.0, RAY_Y, -6.3),
	&"Quarters": Vector3(-4.2, RAY_Y, -10.4),
	&"LifeSupport": Vector3(-3.7, RAY_Y, -6.3),
	&"Galley": Vector3(3.95, RAY_Y, -5.8),
	&"WaterCloset": Vector3(3.25, RAY_Y, -1.9),
	&"Storage": Vector3(-3.8, RAY_Y, -1.2),
	&"Airlock": Vector3(-6.85, RAY_Y, -1.2),
	&"EngineBay": Vector3(0.0, RAY_Y, 4.7),
}

## One ray per doorway, aimed through the opening: from a point on the room side of the
## gap (0.8 m inside, at the doorway's lateral centre) to the corridor centerline. Room
## centers clip chamfered corners on diagonal doorways, so the origin is doorway-local.
const DOORWAYS: Array = [
	[Vector3(0.0, RAY_Y, -15.2), Vector3(0.0, RAY_Y, -13.5), "Cockpit"],
	[Vector3(-1.7, RAY_Y, -10.0), Vector3(0.0, RAY_Y, -10.0), "Quarters"],
	[Vector3(-1.7, RAY_Y, -6.0), Vector3(0.0, RAY_Y, -6.0), "LifeSupport"],
	[Vector3(1.7, RAY_Y, -5.6), Vector3(0.0, RAY_Y, -5.6), "Galley"],
	[Vector3(1.7, RAY_Y, -1.6), Vector3(0.0, RAY_Y, -1.6), "WaterCloset"],
	[Vector3(-1.7, RAY_Y, -1.2), Vector3(0.0, RAY_Y, -1.2), "Storage"],
	[Vector3(-3.7, RAY_Y, -1.0), Vector3(-6.3, RAY_Y, -1.0), "Airlock"],
	[Vector3(-5.6, RAY_Y, -1.2), Vector3(-7.3, RAY_Y, -1.2), "Airlock outer"],
	[Vector3(0.0, RAY_Y, 2.4), Vector3(0.0, RAY_Y, 1.0), "EngineBay"],
]

const SOLID_CONTROLS: Array = [
	[Vector3(0.0, RAY_Y, -12.0), Vector3(-1.95, RAY_Y, -12.0), "corridor west wall beside quarters"],
	[Vector3(0.0, RAY_Y, -7.5), Vector3(1.95, RAY_Y, -7.5), "corridor east wall beside galley"],
	[Vector3(-4.2, RAY_Y, -10.4), Vector3(-6.6, RAY_Y, -10.4), "quarters west wall"],
	[Vector3(-3.7, RAY_Y, -6.3), Vector3(-5.6, RAY_Y, -6.3), "life support west wall"],
	[Vector3(3.95, RAY_Y, -5.8), Vector3(6.15, RAY_Y, -5.8), "galley east wall"],
	[Vector3(3.25, RAY_Y, -1.9), Vector3(4.75, RAY_Y, -1.9), "water closet east wall"],
	[Vector3(-3.8, RAY_Y, -2.6), Vector3(-5.85, RAY_Y, -2.6), "storage west wall beside the airlock gap"],
	[Vector3(-6.85, RAY_Y, -1.8), Vector3(-8.05, RAY_Y, -1.8), "airlock west wall beside the outer gap"],
	[Vector3(0.0, RAY_Y, -16.5), Vector3(0.0, RAY_Y, -19.5), "cockpit north wall"],
	[Vector3(0.0, RAY_Y, 4.7), Vector3(0.0, RAY_Y, 8.5), "engine bay south wall"],
]

## Corridor cross-section sweeps: [y, clear half-width, blocked half-width].
const PROFILE_SWEEPS: Array = [
	[1.5, 1.55, 1.80],
	[0.2, 0.85, 1.05],
	[2.6, 0.95, 1.20],
]

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

	_test_spaces_exist()
	_test_shell_collision()
	_test_doorways_passable()
	_test_solid_walls_block()
	_test_corridor_profile()
	_test_floor_and_ceiling()
	_test_wall_planes()
	_test_cockpit_dash()
	_test_surface_materials()

	_geometry.free()
	_finish()


func _test_spaces_exist() -> void:
	for space_name: StringName in EXPECTED_SPACES:
		var space: Node = _geometry.get_node_or_null(NodePath(String(space_name)))
		_check(space != null, "space exists: %s" % space_name)


func _test_shell_collision() -> void:
	for space_name: StringName in EXPECTED_SPACES:
		var space: Node = _geometry.get_node_or_null(NodePath(String(space_name)))
		if space == null:
			continue
		var shape_node: CollisionShape3D = space.get_node_or_null(^"ShellShape") as CollisionShape3D
		if shape_node == null or not (shape_node.shape is ConcavePolygonShape3D):
			_check(false, "space has a shell collision: %s" % space_name)
			continue
		var shape: ConcavePolygonShape3D = shape_node.shape as ConcavePolygonShape3D
		_check(shape.get_faces().size() >= 3, "space shell has faces: %s" % space_name)


func _test_doorways_passable() -> void:
	for doorway: Array in DOORWAYS:
		var from: Vector3 = doorway[0]
		var to: Vector3 = doorway[1]
		var label: String = doorway[2]
		_check(not _ray_hits(from, to), "doorway %s is free of geometry" % label)


func _test_solid_walls_block() -> void:
	for control: Array in SOLID_CONTROLS:
		var from: Vector3 = control[0]
		var to: Vector3 = control[1]
		var label: String = control[2]
		_check(_ray_hits(from, to), "control: ray into %s hits" % label)


func _test_corridor_profile() -> void:
	for sweep: Array in PROFILE_SWEEPS:
		var y: float = sweep[0]
		var clear: float = sweep[1]
		var blocked: float = sweep[2]
		_check(
			not _ray_hits(Vector3(-clear, y, -5.0), Vector3(clear, y, -5.0)),
			"corridor clear across x[%.2f, %.2f] at y=%.1f" % [-clear, clear, y]
		)
		_check(
			_ray_hits(Vector3(-blocked, y, -5.0), Vector3(blocked, y, -5.0)),
			"corridor blocked across x[%.2f, %.2f] at y=%.1f" % [-blocked, blocked, y]
		)
	_check(not _ray_hits(Vector3(0.0, 0.5, -5.0), Vector3(0.0, 1.0, -5.0)), "corridor floor band is walkable")
	_check(not _ray_hits(Vector3(0.0, 2.4, -5.0), Vector3(0.0, 2.6, -5.0)), "corridor headroom exists")


func _test_floor_and_ceiling() -> void:
	var floor_hit: Dictionary = _ray_result(Vector3(0.0, 1.0, -5.0), Vector3(0.0, -0.5, -5.0))
	_check(not floor_hit.is_empty(), "corridor floor is solid")
	if not floor_hit.is_empty():
		_check(absf(float((floor_hit["position"] as Vector3).y)) < 0.02, "corridor floor surface is at deck height")
		_check((floor_hit["normal"] as Vector3).dot(Vector3.UP) > 0.9, "corridor floor faces up")
	var ceiling_hit: Dictionary = _ray_result(Vector3(0.0, 2.0, -5.0), Vector3(0.0, 3.4, -5.0))
	_check(not ceiling_hit.is_empty(), "corridor ceiling is solid")
	if not ceiling_hit.is_empty():
		_check(absf(float((ceiling_hit["position"] as Vector3).y) - 3.0) < 0.02, "corridor ceiling surface is at head height")
		_check((ceiling_hit["normal"] as Vector3).dot(Vector3.DOWN) > 0.9, "corridor ceiling faces down")
	var quarters_hit: Dictionary = _ray_result(Vector3(-4.2, 1.0, -10.4), Vector3(-4.2, -0.5, -10.4))
	_check(not quarters_hit.is_empty() and absf(float((quarters_hit["position"] as Vector3).y)) < 0.02, "quarters floor surface is at deck height")


func _test_wall_planes() -> void:
	var wall_hit: Dictionary = _ray_result(Vector3(0.0, RAY_Y, -12.0), Vector3(-1.8, RAY_Y, -12.0))
	_check(not wall_hit.is_empty(), "corridor west wall is solid")
	if not wall_hit.is_empty():
		var hit_x: float = float((wall_hit["position"] as Vector3).x)
		_check(hit_x > -1.65 and hit_x < -1.50, "corridor west wall face sits at the canted profile (x=%.3f)" % hit_x)
		_check((wall_hit["normal"] as Vector3).dot(Vector3.RIGHT) > 0.8, "corridor west wall faces into the corridor")


func _test_cockpit_dash() -> void:
	var cockpit: Node = _geometry.get_node_or_null(^"Cockpit")
	_check(cockpit != null, "cockpit exists for the dash check")
	if cockpit == null:
		return
	var panels: int = 0
	for child: Node in cockpit.get_children():
		if String(child.name).begins_with("Dash") and child is CollisionShape3D:
			panels += 1
	_check(panels >= 11, "the wraparound dash has its panels (%d collision parts)" % panels)
	var dash_hit: Dictionary = _ray_result(Vector3(0.0, 0.95, -17.4), Vector3(0.0, 0.95, -18.4))
	_check(not dash_hit.is_empty(), "the dash blocks at console height")
	var pane: MeshInstance3D = cockpit.get_node_or_null(^"DressingWindowPane") as MeshInstance3D
	_check(pane != null and pane.material_override != null, "the windshield pane exists")
	if pane != null and pane.material_override != null:
		_check(pane.material_override.resource_path == WINDOW_MATERIAL_PATH, "the windshield uses the space window shader")


func _test_surface_materials() -> void:
	var walls: MeshInstance3D = _geometry.get_node_or_null(NodePath("Cockpit/WallsMesh")) as MeshInstance3D
	_check(walls != null and walls.material_override != null and walls.material_override.resource_path == XENON_MATERIAL_PATH, "cockpit walls use the xenon-metal material")
	var floor: MeshInstance3D = _geometry.get_node_or_null(NodePath("Cockpit/FloorMesh")) as MeshInstance3D
	_check(floor != null and floor.material_override != null and floor.material_override.resource_path == FLOOR_MATERIAL_PATH, "cockpit floor uses the floor-grate material")


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
